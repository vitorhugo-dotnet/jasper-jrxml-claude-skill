#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

python3 - <<'PY'
from pathlib import Path
import re

workflow_path = Path('.github/workflows/validate.yml')
package_path = Path('scripts/package-skill.sh')
workflow = workflow_path.read_text(encoding='utf-8')
package_script = package_path.read_text(encoding='utf-8')


def fail(message: str) -> None:
    raise SystemExit(f'workflow structure test failed: {message}')


def job_block(name: str) -> str:
    match = re.search(
        rf'^  {re.escape(name)}:\n(?P<body>(?:^(?!  [A-Za-z0-9_-]+:\n).*(?:\n|$))*)',
        workflow,
        re.MULTILINE,
    )
    if not match:
        fail(f'missing job {name!r}')
    return match.group(0)


validate = job_block('validate')
validate_claude = job_block('validate-claude')
validate_codex = job_block('validate-codex')
release_codex = job_block('release-codex')

if 'tests/compile-jrxml.Tests.ps1' not in validate:
    fail('validate must run the PowerShell compiler contract tests')
if 'tests/validate-skill.sh compiler' not in validate:
    fail('validate must run compiler-only static validation')
for forbidden in (
    'validate-claude-version',
    'tests/validate-skill.sh claude',
    'tests/validate-skill.sh codex',
    'tests/package-skill.Tests.sh',
    'gh release',
):
    if forbidden in validate:
        fail(f'validate contains non-compiler responsibility: {forbidden}')

if not re.search(r'^    needs: validate$', validate_claude, re.MULTILINE):
    fail('validate-claude must depend on validate')
for required in (
    'tests/validate-claude-version.test.mjs',
    'scripts/validate-claude-version.mjs',
    'tests/validate-skill.sh claude',
):
    if required not in validate_claude:
        fail(f'validate-claude is missing {required}')
if 'tests/package-skill.Tests.sh' in validate_claude:
    fail('validate-claude must not validate Codex packages')

if not re.search(r'^    needs: validate$', validate_codex, re.MULTILINE):
    fail('validate-codex must depend on validate')
for required in (
    'tests/validate-skill.sh codex',
    'tests/package-skill.Tests.sh',
    'tests/workflow-structure.Tests.sh',
):
    if required not in validate_codex:
        fail(f'validate-codex is missing {required}')
if 'validate-claude-version' in validate_codex:
    fail('validate-codex must not validate Claude versioning')

if not re.search(r'^    needs: validate-codex$', release_codex, re.MULTILINE):
    fail('release-codex must depend only on validate-codex')
if "github.event_name == 'push'" not in release_codex:
    fail('release-codex must be restricted to push events')
if "github.ref == 'refs/heads/main'" not in release_codex:
    fail('release-codex must be restricted to main')
for required in (
    'bash scripts/package-skill.sh dist',
    'chatgpt-codex-v',
    'legacy-jrxml-toolkit-chatgpt-codex-skill.zip',
    'legacy-jrxml-toolkit-chatgpt-codex-skill.zip.sha256',
    'git tag --force "$RELEASE_TAG" "$GITHUB_SHA"',
    'git push origin "refs/tags/$RELEASE_TAG" --force',
    'gh release',
):
    if required not in release_codex:
        fail(f'release-codex is missing {required}')

explicit_archive = 'legacy-jrxml-toolkit-chatgpt-codex-skill.zip'
if explicit_archive not in package_script:
    fail(f'package script must create {explicit_archive}')
if 'create_archive "$portable_stage" "jasper-jrxml-skill.zip"' in package_script:
    fail('legacy ambiguous portable archive name is still generated')

print('workflow structure validation passed')
PY
