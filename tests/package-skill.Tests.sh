#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$(mktemp -d)"
trap 'rm -rf "$output_dir"' EXIT

"$repo_dir/scripts/package-skill.sh" "$output_dir"

archive="$output_dir/jasper-jrxml-skill.zip"
checksum="$archive.sha256"

[[ -f "$archive" ]] || {
  echo "package test failed: archive was not created" >&2
  exit 1
}

[[ -f "$checksum" ]] || {
  echo "package test failed: checksum was not created" >&2
  exit 1
}

(
  cd "$output_dir"
  sha256sum --check "$(basename "$checksum")"
)

python3 - "$archive" <<'PY'
import re
import sys
import zipfile
from pathlib import PurePosixPath

archive_path = sys.argv[1]
required = {
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
forbidden_prefixes = ('.git/', '.github/', 'tests/', 'dist/')
forbidden_terms = (
    'Apollo',
    'JC Sistemas',
    'jcUtil',
    'SinanFaces',
    'ApolloAlpha',
    r'C:\\web\\Apollo',
)

with zipfile.ZipFile(archive_path) as archive:
    names = set(archive.namelist())
    missing = sorted(required - names)
    if missing:
        raise SystemExit(f'package test failed: missing required entries: {missing}')

    for name in sorted(names):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts:
            raise SystemExit(f'package test failed: unsafe archive path: {name}')
        if name.startswith(forbidden_prefixes):
            raise SystemExit(f'package test failed: forbidden path included: {name}')
        if name.endswith('.jasper'):
            raise SystemExit(f'package test failed: generated Jasper binary included: {name}')

    skill = archive.read('SKILL.md').decode('utf-8')
    local_links = re.findall(r'\[[^\]]+\]\((?!https?://|#)([^)]+)\)', skill)
    for target in local_links:
        normalized = str(PurePosixPath(target))
        if normalized not in names:
            raise SystemExit(
                f'package test failed: SKILL.md link target is missing: {target}'
            )

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

print('Codex/OpenAI skill package validation passed')
PY
