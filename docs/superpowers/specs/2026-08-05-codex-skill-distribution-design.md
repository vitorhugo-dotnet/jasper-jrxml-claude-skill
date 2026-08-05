# Codex Skill Distribution Design

## Goal

Publish the existing portable Agent Skill as an installable Codex skill-only plugin and independent Git marketplace while preserving root `SKILL.md` as the single editable source.

## Official format

Current Codex supports plugins with a required `.codex-plugin/plugin.json`, skills under `skills/`, and marketplace catalogs under `.agents/plugins/marketplace.json`. The repository therefore exposes:

```text
.agents/plugins/marketplace.json
plugins/legacy-jrxml-toolkit/
├── .codex-plugin/plugin.json
└── skills/jasper-jrxml/
    ├── SKILL.md
    ├── references/
    ├── scripts/
    └── docs/
```

## Canonical-source decision

The repository root remains canonical. `packaging/codex/plugin.json` stores Codex-specific metadata, while `scripts/sync-codex-plugin.py` generates `plugins/legacy-jrxml-toolkit/` from root `SKILL.md`, public references, scripts, documentation, license, changelog, and privacy statement.

Generated copies are committed so a Git-hosted marketplace can install the plugin directly, but validation rejects any drift from canonical root files. Contributors edit the root files and regeneration source, never the generated plugin tree.

## Distribution artifacts

`scripts/package-skill.sh` produces two deterministic archives and SHA-256 checksums:

- `jasper-jrxml-skill.zip`: portable Agent Skill layout;
- `legacy-jrxml-toolkit-codex-plugin.zip`: official Codex plugin layout.

Tagged releases publish both archive formats.

## Installation

Codex users add the repository as a Git marketplace and install the plugin by marketplace identity:

```bash
codex plugin marketplace add vitorhugo-dotnet/jasper-jrxml-claude-skill
codex plugin add legacy-jrxml-toolkit@jasper-jrxml-plugins
```

A direct skill checkout under `$CODEX_HOME/skills` remains available for clients or environments that do not use the plugin marketplace.

## Validation

CI verifies:

- root Agent Skill and Claude plugin metadata;
- Codex manifest shape, version consistency, and interface metadata;
- Codex marketplace path, policy, and plugin identity;
- generated-tree equality with canonical files;
- portable and Codex archive contents, checksums, safe paths, and relative links;
- absence of generated `.jasper` files and proprietary references;
- release tag and manifest version consistency.

## Constraints

- Root `SKILL.md` remains the single editable skill source.
- Relative paths referenced by `SKILL.md` remain valid in both archive layouts.
- Generated Codex files must be reproducible through `scripts/sync-codex-plugin.py`.
- Packages exclude `.git/`, `.github/`, `tests/`, `dist/`, generated `.jasper` files, and private project content.
- The repository may be installed as an independent marketplace, but it does not claim automatic inclusion in an OpenAI-operated curated directory.
