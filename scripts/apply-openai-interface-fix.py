#!/usr/bin/env python3
"""One-time repository migration for OpenAI plugin interface compliance."""

from __future__ import annotations

import json
import re
from pathlib import Path

VERSION = "1.0.4"
ROOT = Path(__file__).resolve().parent.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    if old not in content:
        raise SystemExit(f"expected text not found in {path}: {old!r}")
    write(path, content.replace(old, new, 1))


def update_versions() -> None:
    skill = read("SKILL.md")
    skill, count = re.subn(
        r'(^metadata:\n  version: ")[^"]+("$)',
        rf'\g<1>{VERSION}\g<2>',
        skill,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit("could not update SKILL.md metadata.version")
    write("SKILL.md", skill)

    for path in (".claude-plugin/plugin.json", "packaging/codex/plugin.json"):
        document = json.loads(read(path))
        document["version"] = VERSION
        if path == "packaging/codex/plugin.json":
            interface = document.setdefault("interface", {})
            interface["composerIcon"] = "./assets/legacy-jrxml-toolkit-composer.svg"
            interface["logo"] = "./assets/legacy-jrxml-toolkit-logo.svg"
        write(path, json.dumps(document, indent=2, ensure_ascii=False) + "\n")

    marketplace = json.loads(read(".claude-plugin/marketplace.json"))
    for plugin in marketplace.get("plugins", []):
        if plugin.get("name") == "legacy-jrxml-toolkit":
            plugin["version"] = VERSION
    write(
        ".claude-plugin/marketplace.json",
        json.dumps(marketplace, indent=2, ensure_ascii=False) + "\n",
    )


def update_generation() -> None:
    replace_once(
        "scripts/sync-codex-plugin.py",
        '        "packaging/codex/plugin.json": ".codex-plugin/plugin.json",\n'
        '        "SKILL.md": f"skills/{SKILL_NAME}/SKILL.md",',
        '        "packaging/codex/plugin.json": ".codex-plugin/plugin.json",\n'
        '        "assets/legacy-jrxml-toolkit-composer.svg": "assets/legacy-jrxml-toolkit-composer.svg",\n'
        '        "assets/legacy-jrxml-toolkit-logo.svg": "assets/legacy-jrxml-toolkit-logo.svg",\n'
        '        "SKILL.md": f"skills/{SKILL_NAME}/SKILL.md",\n'
        '        "agents/openai.yaml": f"skills/{SKILL_NAME}/agents/openai.yaml",',
    )
    replace_once(
        "scripts/sync-codex-plugin.py",
        '    for source, destination in files.items():\n'
        '        copy_file(repo_root, plugin_root, source, destination)\n\n'
        '    generated_notice = (',
        '    for source, destination in files.items():\n'
        '        copy_file(repo_root, plugin_root, source, destination)\n\n'
        '    for asset_name in (\n'
        '        "legacy-jrxml-toolkit-composer.svg",\n'
        '        "legacy-jrxml-toolkit-logo.svg",\n'
        '    ):\n'
        '        copy_file(\n'
        '            repo_root,\n'
        '            plugin_root,\n'
        '            f"assets/{asset_name}",\n'
        '            f"skills/{SKILL_NAME}/assets/{asset_name}",\n'
        '        )\n\n'
        '    generated_notice = (',
    )
    replace_once(
        "scripts/package-skill.sh",
        '  CHANGELOG.md\n'
        '  scripts/compile-jrxml.ps1',
        '  CHANGELOG.md\n'
        '  agents/openai.yaml\n'
        '  assets/legacy-jrxml-toolkit-composer.svg\n'
        '  assets/legacy-jrxml-toolkit-logo.svg\n'
        '  scripts/compile-jrxml.ps1',
    )


def update_validation_and_docs() -> None:
    replace_once(
        ".github/workflows/validate.yml",
        '      - name: Validate ChatGPT and Codex distribution package\n'
        '        run: bash tests/package-skill.Tests.sh\n',
        '      - name: Validate ChatGPT and Codex distribution package\n'
        '        run: bash tests/package-skill.Tests.sh\n\n'
        '      - name: Validate OpenAI plugin and skill interface\n'
        '        run: python3 tests/openai-interface.Tests.py\n',
    )
    replace_once(
        "README.md",
        'Use `legacy-jrxml-toolkit-chatgpt-codex-plugin.zip` in the OpenAI plugin submission portal. It contains `.codex-plugin/plugin.json` at the ZIP root and the skill under `skills/jasper-jrxml/`, which is the structure the portal validates.\n',
        'Use `legacy-jrxml-toolkit-chatgpt-codex-plugin.zip` in the OpenAI plugin submission portal. It contains `.codex-plugin/plugin.json` at the ZIP root and the skill under `skills/jasper-jrxml/`, which is the structure the portal validates. The manifest references the square landing-page icon through `interface.composerIcon` and `interface.logo`, while skill-specific interface settings live in `skills/jasper-jrxml/agents/openai.yaml`.\n',
    )

    changelog = read("CHANGELOG.md")
    heading = "# Changelog\n"
    entry = (
        "\n## 1.0.4 - 2026-08-05\n\n"
        "- Added the square landing-page SVG as the OpenAI composer icon and plugin logo.\n"
        "- Added `agents/openai.yaml` for skill display metadata, icons, brand color, and default prompt.\n"
        "- Added source and release-ZIP tests for OpenAI plugin directory compliance.\n"
    )
    if heading not in changelog:
        raise SystemExit("CHANGELOG.md heading not found")
    write("CHANGELOG.md", changelog.replace(heading, heading + entry, 1))


def cleanup() -> None:
    for path in (
        ".github/workflows/apply-openai-interface-fix.yml",
        "scripts/apply-openai-interface-fix.py",
    ):
        target = ROOT / path
        if target.exists():
            target.unlink()


def main() -> None:
    update_versions()
    update_generation()
    update_validation_and_docs()
    cleanup()


if __name__ == "__main__":
    main()
