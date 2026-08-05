#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if (( $# > 1 )); then
  echo "usage: $0 [output-directory]" >&2
  exit 64
fi

output_dir="${1:-$repo_dir/dist}"
staging_root="$(mktemp -d)"
portable_stage="$staging_root/portable"
plugin_stage="$staging_root/plugin"

cleanup() {
  rm -rf "$staging_root"
}
trap cleanup EXIT

portable_paths=(
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

for relative_path in "${portable_paths[@]}"; do
  source_path="$repo_dir/$relative_path"
  if [[ ! -f "$source_path" ]]; then
    echo "package failed: missing required file $relative_path" >&2
    exit 1
  fi

  destination_path="$portable_stage/$relative_path"
  mkdir -p "$(dirname "$destination_path")"
  cp "$source_path" "$destination_path"
done

python3 "$repo_dir/scripts/sync-codex-plugin.py" "$plugin_stage"

if ! diff -ru "$repo_dir/plugins/legacy-jrxml-toolkit" "$plugin_stage"; then
  echo "package failed: committed Codex plugin is stale" >&2
  echo "run: python3 scripts/sync-codex-plugin.py" >&2
  exit 1
fi

mkdir -p "$output_dir"

create_archive() {
  local source_dir="$1"
  local archive_name="$2"
  local archive_path="$output_dir/$archive_name"

  rm -f "$archive_path" "$archive_path.sha256"

  python3 - "$source_dir" "$archive_path" <<'PY'
import sys
import zipfile
from pathlib import Path

source_dir = Path(sys.argv[1])
archive_path = Path(sys.argv[2])

with zipfile.ZipFile(
    archive_path,
    mode='w',
    compression=zipfile.ZIP_DEFLATED,
    compresslevel=9,
) as archive:
    for source_path in sorted(path for path in source_dir.rglob('*') if path.is_file()):
        relative_path = source_path.relative_to(source_dir).as_posix()
        info = zipfile.ZipInfo(relative_path, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.create_system = 3
        mode = 0o755 if source_path.suffix in {'.sh', '.py'} else 0o644
        info.external_attr = mode << 16
        archive.writestr(info, source_path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
PY

  (
    cd "$output_dir"
    sha256sum "$archive_name" > "$archive_name.sha256"
  )

  printf 'created %s\n' "$archive_path"
  printf 'created %s\n' "$archive_path.sha256"
}

create_archive "$portable_stage" "legacy-jrxml-toolkit-agent-skill.zip"
create_archive "$plugin_stage" "legacy-jrxml-toolkit-chatgpt-codex-plugin.zip"
