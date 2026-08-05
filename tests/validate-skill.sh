#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

mode="${1:-all}"
case "$mode" in
  compiler|claude|codex|all) ;;
  *)
    echo "usage: $0 [compiler|claude|codex|all]" >&2
    exit 64
    ;;
esac

fail() {
  printf 'validation failed: %s\n' "$1" >&2
  exit 1
}

require_files() {
  local path
  for path in "$@"; do
    [[ -f "$path" ]] || fail "missing $path"
  done
}

validate_common() {
  require_files \
    SKILL.md \
    README.md \
    PRIVACY.md \
    CHANGELOG.md \
    LICENSE \
    .gitignore \
    references/legacy-jrxml-layout.md \
    references/project-integration.md \
    references/official-report-sources.md \
    docs/report/README.md \
    .github/workflows/validate.yml \
    .github/workflows/release.yml

  grep -q '^name: jasper-jrxml$' SKILL.md || fail 'invalid skill name'
  grep -q '^description: .*iReport.*JasperReports' SKILL.md || fail 'description does not target legacy iReport/JasperReports'
  grep -q '^license: MIT$' SKILL.md || fail 'skill license frontmatter is missing'
  if grep -q '^metadata:[[:space:]]*$' SKILL.md; then
    fail 'SKILL.md must not contain metadata; use agents/openai.yaml for interface settings'
  fi
  grep -q 'JasperReports 2\.0\.4' SKILL.md || fail 'legacy 2.0.4 scope is missing'
  grep -q 'docs/report/' SKILL.md || fail 'project learning path is missing'
  grep -q 'portalsinan\.saude\.gov\.br' references/official-report-sources.md || fail 'official SINAN source is missing'
  grep -q 'jasperreports\.sourceforge\.net' references/official-report-sources.md || fail 'official JasperReports samples are missing'
  grep -q 'scripts/compile-jrxml\.ps1' SKILL.md || fail 'compiler script is not linked'
  grep -q '\.agents/skills' README.md || fail 'cross-agent installation path is missing'
  grep -q 'MIT License' LICENSE || fail 'MIT license is missing'
  grep -q '^\*\.jasper$' .gitignore || fail 'generated Jasper binaries are not ignored'
  grep -q '^dist/$' .gitignore || fail 'generated distribution directory is not ignored'
  grep -q 'does not collect, transmit, or store' PRIVACY.md || fail 'privacy statement is incomplete'

  local ref
  for ref in references/legacy-jrxml-layout.md references/project-integration.md references/official-report-sources.md; do
    grep -q "$ref" SKILL.md || fail "$ref is not linked from SKILL.md"
  done

  if rg -n -i 'Apollo|JC Sistemas|jcUtil|SinanFaces|ApolloAlpha|C:\\web\\Apollo' \
    SKILL.md references docs/report README.md PRIVACY.md CHANGELOG.md 2>/dev/null; then
    fail 'proprietary reference detected'
  fi
}

validate_compiler() {
  require_files scripts/compile-jrxml.ps1 tests/compile-jrxml.Tests.ps1

  grep -q '\[string\]\$Jrxml' scripts/compile-jrxml.ps1 || fail 'Jrxml parameter is missing'
  grep -q '\[string\]\$ProjectRoot' scripts/compile-jrxml.ps1 || fail 'ProjectRoot parameter is missing'
  grep -q '\[string\]\$LibDirectory' scripts/compile-jrxml.ps1 || fail 'LibDirectory parameter is missing'
  grep -q '\[string\]\$DeployDirectory' scripts/compile-jrxml.ps1 || fail 'DeployDirectory parameter is missing'
  grep -q '\[string\]\$JdkHome' scripts/compile-jrxml.ps1 || fail 'JdkHome parameter is missing'
  grep -q 'JRJdk13Compiler' scripts/compile-jrxml.ps1 || fail 'legacy compiler selection is missing'

  printf 'compiler script validation passed\n'
}

validate_claude() {
  validate_common
  require_files \
    .claude-plugin/plugin.json \
    .claude-plugin/marketplace.json \
    packaging/codex/plugin.json \
    scripts/validate-claude-version.mjs \
    tests/validate-claude-version.test.mjs

  grep -q 'plugin marketplace add vitorhugo-dotnet/jasper-jrxml-claude-skill' README.md || fail 'Claude marketplace installation is missing'
  grep -q 'Claude Code and Codex' PRIVACY.md || fail 'privacy statement does not cover both plugin hosts'

  python3 - <<'PY'
import json
from pathlib import Path

canonical = json.loads(Path('packaging/codex/plugin.json').read_text(encoding='utf-8'))
plugin = json.loads(Path('.claude-plugin/plugin.json').read_text(encoding='utf-8'))
marketplace = json.loads(Path('.claude-plugin/marketplace.json').read_text(encoding='utf-8'))
canonical_version = canonical.get('version')
if not canonical_version:
    raise SystemExit('validation failed: canonical plugin version is missing')

expected = {
    'name': 'legacy-jrxml-toolkit',
    'displayName': 'Legacy JRXML Toolkit',
    'version': canonical_version,
    'license': 'MIT',
    'skills': ['./'],
}
for key, value in expected.items():
    if plugin.get(key) != value:
        raise SystemExit(f'validation failed: Claude plugin {key!r} must be {value!r}')

if plugin.get('$schema') != 'https://json.schemastore.org/claude-code-plugin-manifest.json':
    raise SystemExit('validation failed: Claude plugin schema URL is invalid')
if plugin.get('repository') != 'https://github.com/vitorhugo-dotnet/jasper-jrxml-claude-skill':
    raise SystemExit('validation failed: Claude plugin repository URL is invalid')
if marketplace.get('$schema') != 'https://anthropic.com/claude-code/marketplace.schema.json':
    raise SystemExit('validation failed: Claude marketplace schema URL is invalid')
if marketplace.get('name') != 'jasper-jrxml-plugins':
    raise SystemExit('validation failed: Claude marketplace name is invalid')

entries = marketplace.get('plugins')
if not isinstance(entries, list) or len(entries) != 1:
    raise SystemExit('validation failed: Claude marketplace must expose exactly one plugin')
entry = entries[0]
if entry.get('name') != plugin['name'] or entry.get('displayName') != plugin['displayName']:
    raise SystemExit('validation failed: Claude marketplace identity differs from plugin manifest')
if entry.get('source') != './' or entry.get('strict') is not True:
    raise SystemExit('validation failed: Claude marketplace source or strict mode is invalid')
if entry.get('version') != canonical_version:
    raise SystemExit('validation failed: Claude marketplace and canonical plugin versions differ')
PY

  printf 'Claude plugin validation passed\n'
}

validate_codex() {
  validate_common
  require_files \
    scripts/package-skill.sh \
    scripts/sync-codex-plugin.py \
    tests/package-skill.Tests.sh \
    tests/workflow-structure.Tests.sh \
    packaging/codex/plugin.json \
    .claude-plugin/plugin.json \
    .agents/plugins/marketplace.json \
    plugins/legacy-jrxml-toolkit/.codex-plugin/plugin.json \
    plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/SKILL.md \
    plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/agents/openai.yaml \
    plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/scripts/compile-jrxml.ps1 \
    plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/references/legacy-jrxml-layout.md \
    plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/references/project-integration.md \
    plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/references/official-report-sources.md \
    plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/docs/report/README.md

  grep -q 'codex plugin marketplace add vitorhugo-dotnet/jasper-jrxml-claude-skill' README.md || fail 'Codex marketplace installation is missing'
  grep -q 'codex plugin add legacy-jrxml-toolkit@jasper-jrxml-plugins' README.md || fail 'Codex plugin installation is missing'
  grep -q 'legacy-jrxml-toolkit-agent-skill\.zip' README.md || fail 'portable Agent Skill release artifact is undocumented'
  grep -q 'legacy-jrxml-toolkit-chatgpt-codex-plugin\.zip' README.md || fail 'ChatGPT/Codex plugin release artifact is undocumented'

  bash -n scripts/package-skill.sh
  bash -n tests/package-skill.Tests.sh
  bash -n tests/workflow-structure.Tests.sh
  python3 -m py_compile scripts/sync-codex-plugin.py

  generated_plugin="$(mktemp -d)"
  trap 'rm -rf "$generated_plugin"' RETURN
  python3 scripts/sync-codex-plugin.py "$generated_plugin"
  diff -ru plugins/legacy-jrxml-toolkit "$generated_plugin" || fail 'generated Codex plugin is stale'
  rm -rf "$generated_plugin"
  trap - RETURN

  python3 - <<'PY'
import json
import re
from pathlib import Path

source = json.loads(Path('packaging/codex/plugin.json').read_text(encoding='utf-8'))
generated = json.loads(Path('plugins/legacy-jrxml-toolkit/.codex-plugin/plugin.json').read_text(encoding='utf-8'))
claude = json.loads(Path('.claude-plugin/plugin.json').read_text(encoding='utf-8'))
marketplace = json.loads(Path('.agents/plugins/marketplace.json').read_text(encoding='utf-8'))

if source != generated:
    raise SystemExit('validation failed: generated Codex manifest differs from its source')
plugin_version = source.get('version')
if not isinstance(plugin_version, str) or not re.fullmatch(r'\d+\.\d+\.\d+', plugin_version):
    raise SystemExit('validation failed: canonical plugin version must use MAJOR.MINOR.PATCH')
if claude.get('version') != plugin_version:
    raise SystemExit('validation failed: Claude and Codex plugin versions differ')

expected = {
    'name': 'legacy-jrxml-toolkit',
    'version': plugin_version,
    'description': 'Build, compile, and validate complex legacy iReport and JasperReports 2.x JRXML reports.',
    'license': 'MIT',
    'skills': './skills/',
}
for key, value in expected.items():
    if source.get(key) != value:
        raise SystemExit(f'validation failed: Codex plugin {key!r} must be {value!r}')

interface = source.get('interface')
required = {
    'displayName', 'shortDescription', 'longDescription', 'developerName',
    'category', 'capabilities', 'websiteURL', 'privacyPolicyURL', 'defaultPrompt',
    'composerIcon', 'logo',
}
if not isinstance(interface, dict) or not required <= interface.keys():
    raise SystemExit('validation failed: Codex plugin interface metadata is incomplete')
if interface.get('displayName') != 'Legacy JRXML Toolkit' or interface.get('category') != 'Developer Tools':
    raise SystemExit('validation failed: Codex display metadata is invalid')

if marketplace.get('name') != 'jasper-jrxml-plugins':
    raise SystemExit('validation failed: Codex marketplace name is invalid')
entries = marketplace.get('plugins')
if not isinstance(entries, list) or len(entries) != 1:
    raise SystemExit('validation failed: Codex marketplace must expose exactly one plugin')
entry = entries[0]
if entry.get('name') != source['name']:
    raise SystemExit('validation failed: Codex marketplace and plugin names differ')
if entry.get('source') != {'source': 'local', 'path': './plugins/legacy-jrxml-toolkit'}:
    raise SystemExit('validation failed: Codex marketplace source is invalid')
if entry.get('policy') != {'installation': 'AVAILABLE', 'authentication': 'ON_INSTALL'}:
    raise SystemExit('validation failed: Codex marketplace policy is invalid')

canonical_skill = Path('SKILL.md').read_text(encoding='utf-8')
generated_skill = Path('plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/SKILL.md').read_text(encoding='utf-8')
if canonical_skill != generated_skill:
    raise SystemExit('validation failed: generated Codex skill differs from canonical SKILL.md')
if re.search(r'^metadata:\s*$', canonical_skill, re.MULTILINE):
    raise SystemExit('validation failed: SKILL.md metadata must move to agents/openai.yaml')
PY

  printf 'Codex plugin validation passed\n'
}

case "$mode" in
  compiler) validate_compiler ;;
  claude) validate_claude ;;
  codex) validate_codex ;;
  all)
    validate_compiler
    validate_claude
    validate_codex
    ;;
esac
