#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

fail() {
  printf 'validation failed: %s\n' "$1" >&2
  exit 1
}

required_files=(
  SKILL.md
  scripts/compile-jrxml.ps1
  references/legacy-jrxml-layout.md
  references/project-integration.md
  references/official-report-sources.md
  docs/report/README.md
  README.md
  PRIVACY.md
  CHANGELOG.md
  LICENSE
  .gitignore
  .claude-plugin/plugin.json
  .claude-plugin/marketplace.json
  .github/workflows/validate.yml
)

for path in "${required_files[@]}"; do
  [[ -f "$path" ]] || fail "missing $path"
done

grep -q '^name: jasper-jrxml$' SKILL.md || fail 'invalid skill name'
grep -q '^description: .*iReport.*JasperReports' SKILL.md || fail 'description does not target legacy iReport/JasperReports'
grep -q 'JasperReports 2\.0\.4' SKILL.md || fail 'legacy 2.0.4 scope is missing'
grep -q 'docs/report/' SKILL.md || fail 'project learning path is missing'
grep -q 'portalsinan\.saude\.gov\.br' references/official-report-sources.md || fail 'official SINAN source is missing'
grep -q 'jasperreports\.sourceforge\.net' references/official-report-sources.md || fail 'official JasperReports samples are missing'
grep -q 'scripts/compile-jrxml\.ps1' SKILL.md || fail 'compiler script is not linked'
grep -q '\.agents/skills' README.md || fail 'cross-agent installation path is missing'
grep -q 'plugin marketplace add vitorhugo-dotnet/jasper-jrxml-claude-skill' README.md || fail 'Claude marketplace installation is missing'
grep -q 'jasper-jrxml-legacy@jasper-jrxml-plugins' README.md || fail 'Claude plugin installation is missing'
grep -q 'MIT License' LICENSE || fail 'MIT license is missing'
grep -q '^\*\.jasper$' .gitignore || fail 'generated Jasper binaries are not ignored'
grep -q 'does not collect, transmit, or store' PRIVACY.md || fail 'privacy statement is incomplete'

for ref in references/legacy-jrxml-layout.md references/project-integration.md references/official-report-sources.md; do
  grep -q "$ref" SKILL.md || fail "$ref is not linked from SKILL.md"
done

if rg -n -i 'Apollo|JC Sistemas|jcUtil|SinanFaces|ApolloAlpha|C:\\web\\Apollo' \
  SKILL.md scripts references docs/report README.md PRIVACY.md CHANGELOG.md .claude-plugin 2>/dev/null; then
  fail 'proprietary reference detected'
fi

grep -q '\[string\]\$Jrxml' scripts/compile-jrxml.ps1 || fail 'Jrxml parameter is missing'
grep -q '\[string\]\$ProjectRoot' scripts/compile-jrxml.ps1 || fail 'ProjectRoot parameter is missing'
grep -q '\[string\]\$LibDirectory' scripts/compile-jrxml.ps1 || fail 'LibDirectory parameter is missing'
grep -q '\[string\]\$DeployDirectory' scripts/compile-jrxml.ps1 || fail 'DeployDirectory parameter is missing'
grep -q '\[string\]\$JdkHome' scripts/compile-jrxml.ps1 || fail 'JdkHome parameter is missing'
grep -q 'JRJdk13Compiler' scripts/compile-jrxml.ps1 || fail 'legacy compiler selection is missing'

python3 - <<'PY'
import json
import re
from pathlib import Path

plugin = json.loads(Path('.claude-plugin/plugin.json').read_text(encoding='utf-8'))
marketplace = json.loads(Path('.claude-plugin/marketplace.json').read_text(encoding='utf-8'))
skill = Path('SKILL.md').read_text(encoding='utf-8')

version_match = re.search(r'^\s*version:\s*["\']?([^"\'\n]+)', skill, re.MULTILINE)
if not version_match:
    raise SystemExit('validation failed: SKILL.md version metadata is missing')
skill_version = version_match.group(1).strip()

expected_plugin = {
    'name': 'jasper-jrxml-legacy',
    'displayName': 'Jasper JRXML Legacy',
    'version': skill_version,
    'license': 'MIT',
    'skills': ['./'],
}
for key, expected in expected_plugin.items():
    if plugin.get(key) != expected:
        raise SystemExit(f'validation failed: plugin.json {key!r} must be {expected!r}')

if plugin.get('$schema') != 'https://json.schemastore.org/claude-code-plugin-manifest.json':
    raise SystemExit('validation failed: plugin.json schema URL is invalid')
if plugin.get('repository') != 'https://github.com/vitorhugo-dotnet/jasper-jrxml-claude-skill':
    raise SystemExit('validation failed: plugin repository URL is invalid')

if marketplace.get('$schema') != 'https://anthropic.com/claude-code/marketplace.schema.json':
    raise SystemExit('validation failed: marketplace schema URL is invalid')
if marketplace.get('name') != 'jasper-jrxml-plugins':
    raise SystemExit('validation failed: marketplace name is invalid')

plugins = marketplace.get('plugins')
if not isinstance(plugins, list) or len(plugins) != 1:
    raise SystemExit('validation failed: marketplace must expose exactly one plugin')
entry = plugins[0]
if entry.get('name') != plugin['name']:
    raise SystemExit('validation failed: marketplace and plugin names differ')
if entry.get('source') != './':
    raise SystemExit('validation failed: marketplace source must preserve the repository root')
if entry.get('strict') is not True:
    raise SystemExit('validation failed: marketplace must use strict plugin manifest mode')
if entry.get('version') != plugin['version']:
    raise SystemExit('validation failed: marketplace and plugin versions differ')
PY

printf 'skill and Claude plugin validation passed\n'
