# Codex Skill Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the canonical Agent Skill as an installable Codex skill-only plugin, independent Git marketplace, and validated release artifact.

**Architecture:** Root `SKILL.md` and public support files remain canonical. A Python synchronizer generates the committed Codex plugin tree, a Bash packager creates portable and Codex ZIPs, CI rejects drift or invalid metadata, and tagged releases attach both formats with checksums.

**Tech Stack:** Bash, Python 3 standard library, JSON, GitHub Actions, Agent Skills, Codex plugin marketplace layout.

## Global Constraints

- Keep root `SKILL.md` as the only editable skill source.
- Use the official `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` formats.
- Generate committed Codex copies and reject manual drift.
- Preserve all relative paths referenced by `SKILL.md`.
- Exclude `.git/`, `.github/`, `tests/`, `dist/`, generated `.jasper` files, and private project content from archives.
- Validate existing skill and Claude metadata before publishing release assets.

---

### Task 1: Distribution Contract Tests

- [x] Define portable Agent Skill ZIP requirements.
- [x] Define official Codex plugin ZIP requirements.
- [x] Validate checksums, safe paths, local links, canonical skill equality, and privacy boundaries.
- [x] Run the package contract in CI.

### Task 2: Official Codex Plugin and Marketplace

- [x] Add `packaging/codex/plugin.json` as the Codex manifest source.
- [x] Add `.agents/plugins/marketplace.json` with install policy and category.
- [x] Generate `plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/` from canonical files.
- [x] Reject stale generated copies.

### Task 3: Deterministic Packaging

- [x] Stage the portable skill from an explicit public-file allowlist.
- [x] Regenerate and compare the Codex plugin tree before packaging.
- [x] Produce both ZIP formats with normalized paths and timestamps.
- [x] Produce SHA-256 checksums.

### Task 4: Repository Validation

- [x] Require all Codex source, generated, marketplace, package, and release files.
- [x] Validate Codex JSON metadata and version consistency.
- [x] Verify the generated plugin matches canonical files.
- [x] Extend proprietary-reference scans to Codex paths.

### Task 5: Release Automation

- [x] Trigger on semantic-version tags.
- [x] Validate skill and Codex manifest versions against the tag.
- [x] Run repository and package validation before publishing.
- [x] Attach both ZIPs and both SHA-256 checksum files.

### Task 6: Documentation

- [x] Document remote Codex marketplace installation.
- [x] Document direct `$CODEX_HOME/skills` installation.
- [x] Document generation, packages, release assets, and canonical-source rules.
- [x] Cover Codex in privacy and changelog material.

### Task 7: Verification and Pull Request

- [x] Run repository and package validation in GitHub Actions.
- [x] Review the complete pull-request file set.
- [x] Confirm manifest, package, and PowerShell checks pass.
- [x] Update issue #1 with the current official Codex format.
- [x] Prepare pull request #3 for integration into `main`.
