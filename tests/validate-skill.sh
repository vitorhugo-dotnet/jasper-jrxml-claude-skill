#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

generated_plugin="$(mktemp -d)"
cleanup() {
  rm -rf "$generated_plugin"
}
trap cleanup EXIT

fail() {
  printf 'validation failed: %s\n' "$1" >&2
  exit 1
}

required_files=(
  SKILL.md
  scripts/compile-jrxml.ps1
  scripts/package-skill.sh
  scripts/sync-codex-plugin.py
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
  packaging/codex/plugin.json
  .agents/plugins/marketplace.json
  plugins/legacy-jrxml-toolkit/.codex-plugin/plugin.json
  plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/SKILL.md
  plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/scripts/compile-jrxml.ps1
  plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/references/legacy-jrxml-layout.md
  plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/references/project-integration.md
  plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/references/official-report-sources.md
  plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/docs/report/README.md
  tests/package-skill.Tests.sh
  .github/workflows/validate.yml
  .github/workflows/release.yml
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
grep -q 'legacy-jrxml-toolkit@jasper-jrxml-plugins' README.md || fail 'plugin installation identity is missing'
grep -q 'codex plugin marketplace add vitorhugo-dotnet/jasper-jrxml-claude-skill' README.md || fail 'Codex marketplace installation is missing'
grep -q 'codex plugin add legacy-jrxml-toolkit@jasper-jrxml-plugins' README.md || fail 'Codex plugin installation is missing'
grep -q 'legacy-jrxml-toolkit-codex-plugin\.zip' README.md || fail 'Codex plugin release artifact is undocumented'
grep -q 'jasper-jrxml-skill\.zip' README.md || fail 'portable skill artifact is undocumented'
grep -q 'MIT License' LICENSE || fail 'MIT license is missing'
grep -q '^\*\.jasper$' .gitignore || fail 'generated Jasper binaries are not ignored'
grep -q '^dist/$' .gitignore || fail 'generated distribution directory is not ignored'
grep -q 'does not collect, transmit, or store' PRIVACY.md || fail 'privacy statement is incomplete'
grep -q 'Claude Code and Codex' PRIVACY.md || fail 'privacy statement does not cover both plugin hosts'

for ref in references/legacy-jrxml-layout.md references/project-integration.md references/official-report-sources.md; do
  grep -q "$ref" SKILL.md || fail "$ref is not linked from SKILL.md"
done

if rg -n -i 'Apollo|JC Sistemas|jcUtil|SinanFaces|ApolloAlpha|C:\\web\\Apollo' \
  SKILL.md scripts references docs/report README.md PRIVACY.md CHANGELOG.md \
  .claude-plugin packaging plugins .agents 2>/dev/null; then
  fail 'proprietary reference detected'
fi

grep -q '\[string\]\$Jrxml' scripts/compile-jrxml.ps1 || fail 'Jrxml parameter is missing'
grep -q '\[string\]\$ProjectRoot' scripts/compile-jrxml.ps1 || fail 'ProjectRoot parameter is missing'
grep -q '\[string\]\$LibDirectory' scripts/compile-jrxml.ps1 || fail 'LibDirectory parameter is missing'
grep -q '\[string\]\$DeployDirectory' scripts/compile-jrxml.ps1 || fail 'DeployDirectory parameter is missing'
grep -q '\[string\]\$JdkHome' scripts/compile-jrxml.ps1 || fail 'JdkHome parameter is missing'
grep -q 'JRJdk13Compiler' scripts/compile-jrxml.ps1 || fail 'legacy compiler selection is missing'

bash -n scripts/package-skill.sh
bash -n tests/package-skill.Tests.sh
python3 -m py_compile scripts/sync-codex-plugin.py
python3 scripts/sync-codex-plugin.py "$generated_plugin"
diff -ru plugins/legacy-jrxml-toolkit "$generated_plugin" || fail 'generated Codex plugin is stale'

python3 - <<'PY'
import json
import re
from pathlib import Path

claude_plugin = json.loads(Path('.claude-plugin/plugin.json').read_text(encoding='utf-8'))
claude_marketplace = json.loads(Path('.claude-plugin/marketplace.json').read_text(encoding='utf-8'))
codex_source = json.loads(Path('packaging/codex/plugin.json').read_text(encoding='utf-8'))
codex_generated = json.loads(
    Path('plugins/legacy-jrxml-toolkit/.codex-plugin/plugin.json').read_text(encoding='utf-8')
)
codex_marketplace = json.loads(Path('.agents/plugins/marketplace.json').read_text(encoding='utf-8'))
skill = Path('SKILL.md').read_text(encoding='utf-8')

version_match = re.search(r'^\s*version:\s*["\']?([^"\'\n]+)', skill, re.MULTILINE)
if not version_match:
    raise SystemExit('validation failed: SKILL.md version metadata is missing')
skill_version = version_match.group(1).strip()

expected_claude = {
    'name': 'legacy-jrxml-toolkit',
    'displayName': 'Legacy JRXML Toolkit',
    'version': skill_version,
    'license': 'MIT',
    'skills': ['./'],
}
for key, expected in expected_claude.items():
    if claude_plugin.get(key) != expected:
        raise SystemExit(f'validation failed: Claude plugin {key!r} must be {expected!r}')

if claude_plugin.get('$schema') != 'https://json.schemastore.org/claude-code-plugin-manifest.json':
    raise SystemExit('validation failed: Claude plugin schema URL is invalid')
if claude_plugin.get('repository') != 'https://github.com/vitorhugo-dotnet/jasper-jrxml-claude-skill':
    raise SystemExit('validation failed: Claude plugin repository URL is invalid')

if claude_marketplace.get('$schema') != 'https://anthropic.com/claude-code/marketplace.schema.json':
    raise SystemExit('validation failed: Claude marketplace schema URL is invalid')
if claude_marketplace.get('name') != 'jasper-jrxml-plugins':
    raise SystemExit('validation failed: Claude marketplace name is invalid')

claude_entries = claude_marketplace.get('plugins')
if not isinstance(claude_entries, list) or len(claude_entries) != 1:
    raise SystemExit('validation failed: Claude marketplace must expose exactly one plugin')
claude_entry = claude_entries[0]
if claude_entry.get('name') != claude_plugin['name']:
    raise SystemExit('validation failed: Claude marketplace and plugin names differ')
if claude_entry.get('displayName') != claude_plugin['displayName']:
    raise SystemExit('validation failed: Claude marketplace and plugin display names differ')
if claude_entry.get('source') != './':
    raise SystemExit('validation failed: Claude marketplace source must preserve repository root')
if claude_entry.get('strict') is not True:
    raise SystemExit('validation failed: Claude marketplace must use strict plugin manifest mode')
if claude_entry.get('version') != claude_plugin['version']:
    raise SystemExit('validation failed: Claude marketplace and plugin versions differ')

if codex_source != codex_generated:
    raise SystemExit('validation failed: generated Codex manifest differs from its source')
expected_codex = {
    'name': 'legacy-jrxml-toolkit',
    'version': skill_version,
    'description': 'Build, compile, and validate complex legacy iReport and JasperReports 2.x JRXML reports.',
    'license': 'MIT',
    'skills': './skills/',
}
for key, expected in expected_codex.items():
    if codex_source.get(key) != expected:
        raise SystemExit(f'validation failed: Codex plugin {key!r} must be {expected!r}')

interface = codex_source.get('interface')
required_interface = {
    'displayName',
    'shortDescription',
    'longDescription',
    'developerName',
    'category',
    'capabilities',
    'websiteURL',
    'privacyPolicyURL',
    'defaultPrompt',
}
if not isinstance(interface, dict) or not required_interface <= interface.keys():
    raise SystemExit('validation failed: Codex plugin interface metadata is incomplete')
if interface.get('displayName') != 'Legacy JRXML Toolkit':
    raise SystemExit('validation failed: Codex display name is invalid')
if interface.get('category') != 'Developer Tools':
    raise SystemExit('validation failed: Codex category is invalid')
prompts = interface.get('defaultPrompt')
if not isinstance(prompts, list) or not 1 <= len(prompts) <= 3:
    raise SystemExit('validation failed: Codex defaultPrompt must contain 1 to 3 entries')
if any(not isinstance(prompt, str) or len(prompt) > 128 for prompt in prompts):
    raise SystemExit('validation failed: Codex defaultPrompt entries must be <= 128 characters')

if codex_marketplace.get('name') != 'jasper-jrxml-plugins':
    raise SystemExit('validation failed: Codex marketplace name is invalid')
if codex_marketplace.get('interface', {}).get('displayName') != 'Jasper JRXML Plugins':
    raise SystemExit('validation failed: Codex marketplace display name is invalid')
codex_entries = codex_marketplace.get('plugins')
if not isinstance(codex_entries, list) or len(codex_entries) != 1:
    raise SystemExit('validation failed: Codex marketplace must expose exactly one plugin')
codex_entry = codex_entries[0]
if codex_entry.get('name') != codex_source['name']:
    raise SystemExit('validation failed: Codex marketplace and plugin names differ')
if codex_entry.get('source') != {
    'source': 'local',
    'path': './plugins/legacy-jrxml-toolkit',
}:
    raise SystemExit('validation failed: Codex marketplace source is invalid')
if codex_entry.get('policy') != {
    'installation': 'AVAILABLE',
    'authentication': 'ON_INSTALL',
}:
    raise SystemExit('validation failed: Codex marketplace policy is invalid')
if codex_entry.get('category') != 'Developer Tools':
    raise SystemExit('validation failed: Codex marketplace category is invalid')

canonical_skill = Path('SKILL.md').read_bytes()
generated_skill = Path(
    'plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/SKILL.md'
).read_bytes()
if canonical_skill != generated_skill:
    raise SystemExit('validation failed: generated Codex skill differs from canonical SKILL.md')
PY

printf 'skill, Claude plugin, and Codex plugin validation passed\n'
