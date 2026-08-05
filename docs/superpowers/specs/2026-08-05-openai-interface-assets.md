# OpenAI Plugin Interface Assets

## Problem

The OpenAI plugin upload validator accepted the manifest-bearing ZIP but rejected the plugin because `interface.composerIcon`, `interface.logo`, and the skill-level `agents/openai.yaml` interface configuration were missing.

## Design

- Reuse the exact square SVG already published by the Jasper JRXML landing page.
- Reference that asset from the plugin manifest as both composer icon and logo.
- Place OpenAI skill UI metadata in `agents/openai.yaml` and include the icon assets inside the skill directory.
- Keep the canonical files at the repository root and generate the packaged plugin tree through `scripts/sync-codex-plugin.py`.
- Validate source files and the final release ZIP against the portal requirements.

## Verification

The final ZIP must resolve both manifest images and both `agents/openai.yaml` image references to square SVG files contained in the archive.
