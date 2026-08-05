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
  LICENSE
  .gitignore
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
grep -q 'MIT License' LICENSE || fail 'MIT license is missing'
grep -q '^\*\.jasper$' .gitignore || fail 'generated Jasper binaries are not ignored'

for ref in references/legacy-jrxml-layout.md references/project-integration.md references/official-report-sources.md; do
  grep -q "$ref" SKILL.md || fail "$ref is not linked from SKILL.md"
done

if rg -n -i 'Apollo|JC Sistemas|jcUtil|SinanFaces|ApolloAlpha|C:\\web\\Apollo' \
  SKILL.md scripts references docs/report README.md 2>/dev/null; then
  fail 'proprietary reference detected'
fi

grep -q '\[string\]\$Jrxml' scripts/compile-jrxml.ps1 || fail 'Jrxml parameter is missing'
grep -q '\[string\]\$ProjectRoot' scripts/compile-jrxml.ps1 || fail 'ProjectRoot parameter is missing'
grep -q '\[string\]\$LibDirectory' scripts/compile-jrxml.ps1 || fail 'LibDirectory parameter is missing'
grep -q '\[string\]\$DeployDirectory' scripts/compile-jrxml.ps1 || fail 'DeployDirectory parameter is missing'
grep -q '\[string\]\$JdkHome' scripts/compile-jrxml.ps1 || fail 'JdkHome parameter is missing'
grep -q 'JRJdk13Compiler' scripts/compile-jrxml.ps1 || fail 'legacy compiler selection is missing'

printf 'skill validation passed\n'
