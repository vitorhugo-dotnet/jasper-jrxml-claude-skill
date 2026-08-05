# Codex Skill Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and publish a validated OpenAI/Codex-compatible Agent Skill ZIP while preserving the root `SKILL.md` as the only editable source.

**Architecture:** A Bash packaging script copies an explicit allowlist into a temporary staging directory, creates a ZIP under `dist/`, and writes a SHA-256 checksum. Shell contract tests inspect the generated archive, CI runs those tests on every change, and a tag workflow uploads the same artifacts to GitHub Releases.

**Tech Stack:** Bash, Python 3 standard library, GitHub Actions, Agent Skills layout.

## Global Constraints

- Keep root `SKILL.md` as the canonical source.
- Do not add an undocumented `.codex-plugin` manifest.
- Preserve all relative paths referenced by `SKILL.md`.
- Exclude `.git/`, `.github/`, `tests/`, `dist/`, generated `.jasper` files, and private project content.
- Validate existing skill and Claude metadata before publishing release assets.

---

### Task 1: Package Contract Test

**Files:**
- Create: `tests/package-skill.Tests.sh`
- Modify: `.github/workflows/validate.yml`

**Interfaces:**
- Consumes: `scripts/package-skill.sh [output-directory]`
- Produces: a shell test that validates `jasper-jrxml-skill.zip` and `jasper-jrxml-skill.zip.sha256`

- [ ] Write a failing test that invokes the absent packaging script.
- [ ] Run it and confirm failure is caused by the missing script.
- [ ] Add the test to the validation workflow.

### Task 2: Deterministic Skill Packager

**Files:**
- Create: `scripts/package-skill.sh`
- Modify: `tests/validate-skill.sh`

**Interfaces:**
- Consumes: repository root files and optional output directory.
- Produces: `<output>/jasper-jrxml-skill.zip` and `<output>/jasper-jrxml-skill.zip.sha256`.

- [ ] Implement strict Bash argument handling and a temporary staging directory.
- [ ] Copy the explicit public-file allowlist.
- [ ] Create the ZIP with Python 3 using normalized archive paths.
- [ ] Generate a SHA-256 checksum.
- [ ] Run package and repository validation tests until green.

### Task 3: Release Automation

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: semantic-version tags matching `v*` and `scripts/package-skill.sh`.
- Produces: GitHub Release assets for the ZIP and checksum.

- [ ] Add a tag-triggered workflow with read-only default permissions and explicit `contents: write` for the release job.
- [ ] Run repository validation and package tests before release creation.
- [ ] Upload the generated ZIP and checksum with GitHub's maintained release action.

### Task 4: Codex/OpenAI Documentation

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: package artifact and standard Agent Skills installation paths.
- Produces: documented Codex direct installation, local package generation, ChatGPT/OpenAI upload steps, and limitations.

- [ ] Replace the vague Codex section with explicit direct-install and ZIP-upload paths.
- [ ] Document the package command and generated assets.
- [ ] State that no undocumented Codex manifest or global-directory submission is claimed.
- [ ] Record the feature under `Unreleased`.

### Task 5: Verification and Pull Request

**Files:**
- Verify all changed files.

**Interfaces:**
- Consumes: branch implementation.
- Produces: a reviewable pull request linked to issue #1.

- [ ] Run shell validation and inspect ZIP contents.
- [ ] Confirm no proprietary references or excluded paths are packaged.
- [ ] Review the branch diff.
- [ ] Open a pull request targeting `main` and reference issue #1.
