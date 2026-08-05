#!/usr/bin/env python3
"""Validate OpenAI plugin and skill interface assets in source and release ZIP."""

from __future__ import annotations

import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parent.parent
PLUGIN_ARCHIVE = "legacy-jrxml-toolkit-chatgpt-codex-plugin.zip"
COMPOSER_ICON = "./assets/legacy-jrxml-toolkit-composer.svg"
LOGO = "./assets/legacy-jrxml-toolkit-logo.svg"
REQUIRED_YAML_FIELDS = (
    "display_name",
    "short_description",
    "icon_small",
    "icon_large",
    "brand_color",
    "default_prompt",
)


def fail(message: str) -> None:
    raise SystemExit(f"OpenAI interface test failed: {message}")


def assert_square_svg(data: bytes, source: str) -> None:
    try:
        root = ElementTree.fromstring(data)
    except ElementTree.ParseError as error:
        fail(f"{source} is not valid SVG/XML: {error}")

    if not root.tag.endswith("svg"):
        fail(f"{source} is not an SVG")

    view_box = root.attrib.get("viewBox", "").split()
    if len(view_box) == 4:
        try:
            width = float(view_box[2])
            height = float(view_box[3])
        except ValueError:
            fail(f"{source} has an invalid viewBox")
        if width <= 0 or height <= 0 or width != height:
            fail(f"{source} must use a square viewBox")
        return

    width = re.sub(r"[^0-9.]", "", root.attrib.get("width", ""))
    height = re.sub(r"[^0-9.]", "", root.attrib.get("height", ""))
    if not width or not height or float(width) != float(height):
        fail(f"{source} must declare square dimensions")


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def parse_openai_interface(text: str, source: str) -> dict[str, str]:
    if not re.search(r"^interface:\s*$", text, re.MULTILINE):
        fail(f"{source} must contain an interface mapping")

    values: dict[str, str] = {}
    for key in REQUIRED_YAML_FIELDS:
        match = re.search(
            rf"^  {re.escape(key)}:\s*(.+?)\s*$",
            text,
            re.MULTILINE,
        )
        if match is None:
            fail(f"{source} is missing interface.{key}")
        values[key] = unquote(match.group(1))
    return values


def zip_join(base: str, reference: str) -> str:
    return str(PurePosixPath(base) / PurePosixPath(reference.removeprefix("./")))


def validate_source() -> None:
    manifest = json.loads(
        (ROOT / "packaging/codex/plugin.json").read_text(encoding="utf-8")
    )
    interface = manifest.get("interface")
    if not isinstance(interface, dict):
        fail("plugin manifest interface is missing")

    expected = {"composerIcon": COMPOSER_ICON, "logo": LOGO}
    for field, reference in expected.items():
        if interface.get(field) != reference:
            fail(f"plugin manifest interface.{field} must be {reference}")
        asset = ROOT / reference.removeprefix("./")
        if not asset.is_file():
            fail(f"plugin manifest asset is missing: {reference}")
        assert_square_svg(asset.read_bytes(), str(asset.relative_to(ROOT)))

    openai_path = ROOT / "agents/openai.yaml"
    if not openai_path.is_file():
        fail("agents/openai.yaml is missing")
    skill_interface = parse_openai_interface(
        openai_path.read_text(encoding="utf-8"), "agents/openai.yaml"
    )
    if skill_interface["brand_color"].upper() != "#F97316":
        fail("agents/openai.yaml interface.brand_color must be #F97316")
    if "$jasper-jrxml" not in skill_interface["default_prompt"]:
        fail("agents/openai.yaml default_prompt must reference $jasper-jrxml")

    for field in ("icon_small", "icon_large"):
        asset = ROOT / skill_interface[field].removeprefix("./")
        if not asset.is_file():
            fail(f"skill interface asset is missing: {skill_interface[field]}")
        assert_square_svg(asset.read_bytes(), str(asset.relative_to(ROOT)))


def validate_release_zip() -> None:
    with tempfile.TemporaryDirectory() as output:
        subprocess.run(
            ["bash", "scripts/package-skill.sh", output],
            cwd=ROOT,
            check=True,
        )
        archive_path = Path(output) / PLUGIN_ARCHIVE
        if not archive_path.is_file():
            fail(f"release archive was not created: {PLUGIN_ARCHIVE}")

        with zipfile.ZipFile(archive_path) as archive:
            names = set(archive.namelist())
            manifest_name = ".codex-plugin/plugin.json"
            if manifest_name not in names:
                fail("release ZIP is missing .codex-plugin/plugin.json at its root")

            manifest = json.loads(archive.read(manifest_name))
            interface = manifest.get("interface")
            if not isinstance(interface, dict):
                fail("release manifest interface is missing")

            for field in ("composerIcon", "logo"):
                reference = interface.get(field)
                if not isinstance(reference, str):
                    fail(f"release manifest interface.{field} is missing")
                asset_name = reference.removeprefix("./")
                if asset_name not in names:
                    fail(f"release manifest references missing asset: {reference}")
                assert_square_svg(archive.read(asset_name), asset_name)

            openai_name = "skills/jasper-jrxml/agents/openai.yaml"
            if openai_name not in names:
                fail("release ZIP is missing skills/jasper-jrxml/agents/openai.yaml")
            skill_interface = parse_openai_interface(
                archive.read(openai_name).decode("utf-8"), openai_name
            )
            for field in ("icon_small", "icon_large"):
                asset_name = zip_join("skills/jasper-jrxml", skill_interface[field])
                if asset_name not in names:
                    fail(f"skill interface references missing ZIP asset: {asset_name}")
                assert_square_svg(archive.read(asset_name), asset_name)


if __name__ == "__main__":
    validate_source()
    validate_release_zip()
    print("OpenAI plugin and skill interface validation passed")
