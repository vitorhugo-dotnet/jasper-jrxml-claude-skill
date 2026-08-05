# ChatGPT/Codex Plugin Bundle Fix

## Problem

The release asset named for ChatGPT/Codex currently contains the portable Agent Skill layout, whose ZIP root starts with `SKILL.md`. The OpenAI plugin submission portal rejects it because it requires `.codex-plugin/plugin.json`, `.agent-plugin/plugin.json`, or `.claude-plugin/plugin.json` at the ZIP root or inside the ZIP's only top-level directory.

## Design

- Keep a clearly named portable Agent Skill archive for cross-agent/manual installations.
- Generate the OpenAI submission archive from the existing Codex plugin staging tree so `.codex-plugin/plugin.json` is at the ZIP root and `skills/jasper-jrxml/` contains the canonical skill.
- Publish only the manifest-bearing plugin archive from the automatic ChatGPT/Codex release node.
- Validate the exact portal requirement in `tests/package-skill.Tests.sh` and the release artifact name in `tests/workflow-structure.Tests.sh`.
- Bump all synchronized public manifests and the canonical skill to version `1.0.3`.

## Resulting artifacts

- `legacy-jrxml-toolkit-agent-skill.zip`: portable Agent Skill, not for the OpenAI plugin submission portal.
- `legacy-jrxml-toolkit-chatgpt-codex-plugin.zip`: OpenAI submission bundle with `.codex-plugin/plugin.json` at the ZIP root.
