#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$(mktemp -d)"
trap 'rm -rf "$output_dir"' EXIT

"$repo_dir/scripts/package-skill.sh" "$output_dir"

agent_archive="$output_dir/legacy-jrxml-toolkit-agent-skill.zip"
submission_archive="$output_dir/legacy-jrxml-toolkit-chatgpt-codex-plugin.zip"

for archive in "$agent_archive" "$submission_archive"; do
  [[ -f "$archive" ]] || {
    echo "package test failed: archive was not created: $archive" >&2
    exit 1
  }
  [[ -f "$archive.sha256" ]] || {
    echo "package test failed: checksum was not created: $archive.sha256" >&2
    exit 1
  }
  (cd "$output_dir" && sha256sum --check "$(basename "$archive.sha256")")
done

python3 - "$agent_archive" "$submission_archive" <<'PY'
import json
import re
import sys
import zipfile
from pathlib import PurePosixPath
from urllib.parse import urlparse

agent_archive_path, submission_archive_path = sys.argv[1:]
agent_required = {
    'SKILL.md', 'LICENSE', 'README.md', 'PRIVACY.md', 'CHANGELOG.md',
    'agents/openai.yaml',
    'assets/legacy-jrxml-toolkit-composer.svg',
    'assets/legacy-jrxml-toolkit-logo.svg',
    'scripts/compile-jrxml.ps1',
    'references/legacy-jrxml-layout.md',
    'references/project-integration.md',
    'references/official-report-sources.md',
    'docs/report/README.md',
}
submission_required = {
    '.codex-plugin/plugin.json', 'LICENSE', 'README.md', 'PRIVACY.md', 'CHANGELOG.md',
    'skills/jasper-jrxml/SKILL.md',
    'skills/jasper-jrxml/agents/openai.yaml',
    'skills/jasper-jrxml/assets/legacy-jrxml-toolkit-composer.svg',
    'skills/jasper-jrxml/assets/legacy-jrxml-toolkit-logo.svg',
    'skills/jasper-jrxml/scripts/compile-jrxml.ps1',
    'skills/jasper-jrxml/references/legacy-jrxml-layout.md',
    'skills/jasper-jrxml/references/project-integration.md',
    'skills/jasper-jrxml/references/official-report-sources.md',
    'skills/jasper-jrxml/docs/report/README.md',
}
forbidden_prefixes = ('.git/', '.github/', 'tests/', 'dist/')
forbidden_terms = ('Apollo', 'JC Sistemas', 'jcUtil', 'SinanFaces', 'ApolloAlpha', r'C:\\web\\Apollo')


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
            raise SystemExit(f'package test failed: SKILL.md link target is missing: {target}')


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
                raise SystemExit(f'package test failed: proprietary reference {term!r} found in {name}')


def validate_skill_frontmatter(skill: str, source: str) -> None:
    if re.search(r'^metadata:\s*$', skill, re.MULTILINE):
        raise SystemExit(f'package test failed: {source} must not contain metadata; use agents/openai.yaml')
    if not re.search(r'^name:\s*jasper-jrxml\s*$', skill, re.MULTILINE):
        raise SystemExit(f'package test failed: {source} has an invalid skill name')


with zipfile.ZipFile(agent_archive_path) as agent:
    agent_names = set(agent.namelist())
    missing = sorted(agent_required - agent_names)
    if missing:
        raise SystemExit(f'package test failed: Agent Skill archive missing: {missing}')
    validate_paths(agent_names)
    canonical_skill = agent.read('SKILL.md').decode('utf-8')
    validate_skill_frontmatter(canonical_skill, 'Agent Skill SKILL.md')
    validate_links(canonical_skill, agent_names)
    validate_privacy(agent, agent_names)

with zipfile.ZipFile(submission_archive_path) as submission:
    submission_names = set(submission.namelist())
    if '.codex-plugin/plugin.json' not in submission_names:
        raise SystemExit('package test failed: ChatGPT/Codex bundle must contain .codex-plugin/plugin.json at the ZIP root')
    missing = sorted(submission_required - submission_names)
    if missing:
        raise SystemExit(f'package test failed: ChatGPT/Codex bundle missing: {missing}')
    validate_paths(submission_names)

    submission_skill = submission.read('skills/jasper-jrxml/SKILL.md').decode('utf-8')
    if submission_skill != canonical_skill:
        raise SystemExit('package test failed: submitted skill differs from canonical SKILL.md')
    validate_skill_frontmatter(submission_skill, 'submitted SKILL.md')
    validate_links(submission_skill, submission_names, 'skills/jasper-jrxml')
    validate_privacy(submission, submission_names)

    manifest = json.loads(submission.read('.codex-plugin/plugin.json'))
    if manifest.get('name') != 'legacy-jrxml-toolkit':
        raise SystemExit('package test failed: invalid Codex plugin name')
    if manifest.get('skills') != './skills/':
        raise SystemExit('package test failed: Codex plugin skills path must be ./skills/')
    version = manifest.get('version')
    if not isinstance(version, str) or not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('package test failed: plugin version must use MAJOR.MINOR.PATCH')

    interface = manifest.get('interface')
    required_interface = {
        'displayName', 'shortDescription', 'longDescription', 'developerName',
        'category', 'capabilities', 'defaultPrompt', 'composerIcon', 'logo',
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

print('Agent Skill and ChatGPT/Codex plugin bundle validation passed')
PY
