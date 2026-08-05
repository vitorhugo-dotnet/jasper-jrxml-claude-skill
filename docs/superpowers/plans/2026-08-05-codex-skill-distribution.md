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

**Files:**
- Create: `tests/package-skill.Tests.sh`
- Modify: `.github/workflows/validate.yml`

- [x] Define portable Agent Skill ZIP requirements.
- [x] Define official Codex plugin ZIP requirements.
- [x] Validate checksums, safe paths, local links, canonical skill equality, and privacy boundaries.
- [x] Run the package contract in CI.

### Task 2: Official Codex Plugin and Marketplace

**Files:**
- Create: `packaging/codex/plugin.json`
- Create: `.agents/plugins/marketplace.json`
- Create: `scripts/sync-codex-plugin.py`
- Generate: `plugins/legacy-jrxml-toolkit/**`

- [x] Add the skill-only plugin manifest with interface metadata.
- [x] Add the Git-hosted marketplace catalog and installation policy.
- [x] Generate `skills/jasper-jrxml/` from root canonical files.
- [x] Add a generated-file notice and drift validation.

### Task 3: Deterministic Packaging

**Files:**
- Create: `scripts/package-skill.sh`
- Modify: `.gitignore`

- [x] Stage the portable skill from an explicit public-file allowlist.
- [x] Regenerate and compare the Codex plugin tree before packaging.
- [x] Produce both ZIP formats with normalized paths and timestamps.
- [x] Produce SHA-256 checksums.

### Task 4: Repository Validation

**Files:**
- Modify: `tests/validate-skill.sh`

- [ ] Require all Codex source, generated, marketplace, package, and release files.
- [ ] Validate Codex JSON metadata and version consistency.
- [ ] Verify the generated plugin matches canonical files.
- [ ] Extend proprietary-reference scans to Codex paths.

### Task 5: Release Automation

**Files:**
- Create: `.github/workflows/release.yml`

- [x] Trigger on semantic-version tags.
- [x] Validate skill and Codex manifest versions against the tag.
- [x] Run repository and package validation before publishing.
- [x] Attach both ZIPs and both SHA-256 checksum files.

### Task 6: Documentation

**Files:**
- Modify: `README.md`
- Modify: `PRIVACY.md`
- Modify: `CHANGELOG.md`

- [x] Document remote Codex marketplace installation.
- [x] Document direct `$CODEX_HOME/skills` installation.
- [x] Document generation, packages, release assets, and canonical-source rules.
- [x] Cover Codex in privacy and changelog material.

### Task 7: Verification and Pull Request

- [ ] Run repository and package validation.
- [ ] Review the complete pull-request diff.
- [ ] Confirm CI status.
- [ ] Update issue #1 with the current official Codex format.
- [ ] Mark pull request #3 ready for review.
