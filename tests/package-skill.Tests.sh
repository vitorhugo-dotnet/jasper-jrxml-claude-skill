#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$(mktemp -d)"
trap 'rm -rf "$output_dir"' EXIT

"$repo_dir/scripts/package-skill.sh" "$output_dir"

skill_archive="$output_dir/jasper-jrxml-skill.zip"
plugin_archive="$output_dir/legacy-jrxml-toolkit-codex-plugin.zip"

for archive in "$skill_archive" "$plugin_archive"; do
  [[ -f "$archive" ]] || {
    echo "package test failed: archive was not created: $archive" >&2
    exit 1
  }

  [[ -f "$archive.sha256" ]] || {
    echo "package test failed: checksum was not created: $archive.sha256" >&2
    exit 1
  }

  (
    cd "$output_dir"
    sha256sum --check "$(basename "$archive.sha256")"
  )
done

python3 - "$skill_archive" "$plugin_archive" <<'PY'
import json
import re
import sys
import zipfile
from pathlib import PurePosixPath
from urllib.parse import urlparse

skill_archive_path, plugin_archive_path = sys.argv[1:]
portable_required = {
    'SKILL.md',
    'LICENSE',
    'README.md',
    'PRIVACY.md',
    'CHANGELOG.md',
    'scripts/compile-jrxml.ps1',
    'references/legacy-jrxml-layout.md',
    'references/project-integration.md',
    'references/official-report-sources.md',
    'docs/report/README.md',
}
plugin_required = {
    '.codex-plugin/plugin.json',
    'LICENSE',
    'README.md',
    'PRIVACY.md',
    'CHANGELOG.md',
    'skills/jasper-jrxml/SKILL.md',
    'skills/jasper-jrxml/scripts/compile-jrxml.ps1',
    'skills/jasper-jrxml/references/legacy-jrxml-layout.md',
    'skills/jasper-jrxml/references/project-integration.md',
    'skills/jasper-jrxml/references/official-report-sources.md',
    'skills/jasper-jrxml/docs/report/README.md',
}
forbidden_prefixes = ('.git/', '.github/', 'tests/', 'dist/')
forbidden_terms = (
    'Apollo',
    'JC Sistemas',
    'jcUtil',
    'SinanFaces',
    'ApolloAlpha',
    r'C:\\web\\Apollo',
)


def validate_paths(names: set[str]) -> None:
    for name in sorted(names):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts:
            raise SystemExit(f'package test failed: unsafe archive path: {name}')
        if name.startswith(forbidden_prefixes):
            raise SystemExit(f'package test failed: forbidden path included: {name}')
        if name.endswith('.jasper'):
            raise SystemExit(f'package test failed: generated Jasper binary included: {name}')


def validate_links(skill: str, names: set[str], prefix: str = '') -> None:
    local_links = re.findall(r'\[[^\]]+\]\((?!https?://|#)([^)]+)\)', skill)
    for target in local_links:
        normalized = str(PurePosixPath(prefix) / PurePosixPath(target))
        if normalized not in names:
            raise SystemExit(
                f'package test failed: SKILL.md link target is missing: {target}'
            )


def validate_privacy(archive: zipfile.ZipFile, names: set[str]) -> None:
    for name in sorted(names):
        if name.endswith('/'):
            continue
        try:
            text = archive.read(name).decode('utf-8')
        except UnicodeDecodeError:
            continue
        for term in forbidden_terms:
            if term in text:
                raise SystemExit(
                    f'package test failed: proprietary reference {term!r} found in {name}'
                )


with zipfile.ZipFile(skill_archive_path) as portable:
    portable_names = set(portable.namelist())
    missing = sorted(portable_required - portable_names)
    if missing:
        raise SystemExit(f'package test failed: portable archive missing: {missing}')
    validate_paths(portable_names)
    portable_skill = portable.read('SKILL.md').decode('utf-8')
    validate_links(portable_skill, portable_names)
    validate_privacy(portable, portable_names)

with zipfile.ZipFile(plugin_archive_path) as plugin:
    plugin_names = set(plugin.namelist())
    missing = sorted(plugin_required - plugin_names)
    if missing:
        raise SystemExit(f'package test failed: Codex plugin archive missing: {missing}')
    validate_paths(plugin_names)
    plugin_skill = plugin.read('skills/jasper-jrxml/SKILL.md').decode('utf-8')
    if plugin_skill != portable_skill:
        raise SystemExit('package test failed: Codex skill differs from canonical SKILL.md')
    validate_links(plugin_skill, plugin_names, 'skills/jasper-jrxml')
    validate_privacy(plugin, plugin_names)

    manifest = json.loads(plugin.read('.codex-plugin/plugin.json'))
    if manifest.get('name') != 'legacy-jrxml-toolkit':
        raise SystemExit('package test failed: invalid Codex plugin name')
    if manifest.get('skills') != './skills/':
        raise SystemExit('package test failed: Codex plugin skills path must be ./skills/')
    if manifest.get('version') != '1.0.0':
        raise SystemExit('package test failed: Codex plugin version must match SKILL.md')

    interface = manifest.get('interface')
    required_interface = {
        'displayName',
        'shortDescription',
        'longDescription',
        'developerName',
        'category',
        'capabilities',
        'defaultPrompt',
    }
    if not isinstance(interface, dict) or not required_interface <= interface.keys():
        raise SystemExit('package test failed: incomplete Codex plugin interface metadata')
    prompts = interface['defaultPrompt']
    if not isinstance(prompts, list) or not 1 <= len(prompts) <= 3:
        raise SystemExit('package test failed: defaultPrompt must contain 1 to 3 prompts')
    if any(not isinstance(prompt, str) or len(prompt) > 128 for prompt in prompts):
        raise SystemExit('package test failed: defaultPrompt entries must be <= 128 characters')
    for field in ('websiteURL', 'privacyPolicyURL'):
        value = interface.get(field)
        parsed = urlparse(value) if isinstance(value, str) else None
        if parsed is None or parsed.scheme != 'https' or not parsed.netloc:
            raise SystemExit(f'package test failed: {field} must be an absolute HTTPS URL')

print('portable skill and Codex plugin package validation passed')
PY
