#!/usr/bin/env python3
"""Generate the Codex plugin tree from the canonical root Agent Skill."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

PLUGIN_NAME = "legacy-jrxml-toolkit"
SKILL_NAME = "jasper-jrxml"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate the Codex plugin directory from canonical repository files."
    )
    parser.add_argument(
        "output",
        nargs="?",
        help="Output plugin directory (default: plugins/legacy-jrxml-toolkit)",
    )
    return parser.parse_args()


def copy_file(repo_root: Path, plugin_root: Path, source: str, destination: str) -> None:
    source_path = repo_root / source
    if not source_path.is_file():
        raise SystemExit(f"Codex plugin generation failed: missing {source}")

    destination_path = plugin_root / destination
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, destination_path)


def read_skill_version(skill_path: Path) -> str:
    contents = skill_path.read_text(encoding="utf-8")
    match = re.search(r'^\s*version:\s*["\']?([^"\'\n]+)', contents, re.MULTILINE)
    if match is None:
        raise SystemExit("Codex plugin generation failed: SKILL.md version is missing")
    return match.group(1).strip()


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent.parent
    plugin_root = (
        Path(args.output).expanduser().resolve()
        if args.output
        else repo_root / "plugins" / PLUGIN_NAME
    )

    manifest_source = repo_root / "packaging" / "codex" / "plugin.json"
    manifest = json.loads(manifest_source.read_text(encoding="utf-8"))
    skill_version = read_skill_version(repo_root / "SKILL.md")

    if manifest.get("name") != PLUGIN_NAME:
        raise SystemExit(
            f"Codex plugin generation failed: manifest name must be {PLUGIN_NAME}"
        )
    if manifest.get("version") != skill_version:
        raise SystemExit(
            "Codex plugin generation failed: plugin and SKILL.md versions differ"
        )
    if manifest.get("skills") != "./skills/":
        raise SystemExit(
            "Codex plugin generation failed: manifest skills path must be ./skills/"
        )

    if plugin_root.exists():
        shutil.rmtree(plugin_root)
    plugin_root.mkdir(parents=True)

    files = {
        "packaging/codex/plugin.json": ".codex-plugin/plugin.json",
        "SKILL.md": f"skills/{SKILL_NAME}/SKILL.md",
        "scripts/compile-jrxml.ps1": f"skills/{SKILL_NAME}/scripts/compile-jrxml.ps1",
        "references/legacy-jrxml-layout.md": f"skills/{SKILL_NAME}/references/legacy-jrxml-layout.md",
        "references/project-integration.md": f"skills/{SKILL_NAME}/references/project-integration.md",
        "references/official-report-sources.md": f"skills/{SKILL_NAME}/references/official-report-sources.md",
        "docs/report/README.md": f"skills/{SKILL_NAME}/docs/report/README.md",
        "LICENSE": "LICENSE",
        "README.md": "README.md",
        "PRIVACY.md": "PRIVACY.md",
        "CHANGELOG.md": "CHANGELOG.md",
    }
    for source, destination in files.items():
        copy_file(repo_root, plugin_root, source, destination)

    generated_notice = (
        "# Generated Codex plugin\n\n"
        "This directory is generated from the canonical files at the repository root.\n"
        "Run `python3 scripts/sync-codex-plugin.py` after changing the skill, metadata, "
        "references, scripts, or public documentation. Do not edit generated copies directly.\n"
    )
    (plugin_root / "GENERATED.md").write_text(generated_notice, encoding="utf-8")

    print(f"generated Codex plugin: {plugin_root}")


if __name__ == "__main__":
    main()
