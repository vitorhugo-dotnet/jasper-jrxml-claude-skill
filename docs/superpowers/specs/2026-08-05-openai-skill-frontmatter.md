# OpenAI Skill Frontmatter Compatibility

## Problem

The OpenAI plugin upload validator rejects the skill because `SKILL.md` still contains a `metadata` mapping. OpenAI skill interface settings belong under `interface` in `agents/openai.yaml`, not in `SKILL.md` metadata.

## Design

- Keep only portable Agent Skills frontmatter fields in `SKILL.md`: `name`, `description`, and `license`.
- Use `packaging/codex/plugin.json` as the canonical release version source.
- Keep Claude and generated Codex manifests synchronized with that canonical version.
- Update release, packaging, and validation scripts so none read version information from `SKILL.md`.
- Add a regression test that rejects any `metadata:` mapping in canonical or packaged `SKILL.md` files.
