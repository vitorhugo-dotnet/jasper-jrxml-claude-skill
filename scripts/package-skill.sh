#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if (( $# > 1 )); then
  echo "usage: $0 [output-directory]" >&2
  exit 64
fi

output_dir="${1:-$repo_dir/dist}"
archive_name="jasper-jrxml-skill.zip"
archive_path="$output_dir/$archive_name"
checksum_path="$archive_path.sha256"
staging_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$staging_dir"
}
trap cleanup EXIT

required_paths=(
  SKILL.md
  LICENSE
  README.md
  PRIVACY.md
  CHANGELOG.md
  scripts/compile-jrxml.ps1
  references/legacy-jrxml-layout.md
  references/project-integration.md
  references/official-report-sources.md
  docs/report/README.md
)

for relative_path in "${required_paths[@]}"; do
  source_path="$repo_dir/$relative_path"
  if [[ ! -f "$source_path" ]]; then
    echo "package failed: missing required file $relative_path" >&2
    exit 1
  fi

  destination_path="$staging_dir/$relative_path"
  mkdir -p "$(dirname "$destination_path")"
  cp "$source_path" "$destination_path"
done

mkdir -p "$output_dir"
rm -f "$archive_path" "$checksum_path"

python3 - "$staging_dir" "$archive_path" <<'PY'
import sys
import zipfile
from pathlib import Path

staging_dir = Path(sys.argv[1])
archive_path = Path(sys.argv[2])

with zipfile.ZipFile(
    archive_path,
    mode='w',
    compression=zipfile.ZIP_DEFLATED,
    compresslevel=9,
) as archive:
    for source_path in sorted(path for path in staging_dir.rglob('*') if path.is_file()):
        relative_path = source_path.relative_to(staging_dir).as_posix()
        info = zipfile.ZipInfo(relative_path, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.create_system = 3
        mode = 0o755 if source_path.suffix == '.sh' else 0o644
        info.external_attr = mode << 16
        archive.writestr(info, source_path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
PY

(
  cd "$output_dir"
  sha256sum "$archive_name" > "$archive_name.sha256"
)

printf 'created %s\n' "$archive_path"
printf 'created %s\n' "$checksum_path"
