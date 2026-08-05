# Separate Validators and ChatGPT/Codex Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate compiler, Claude, and Codex validation jobs and publish an explicitly named ChatGPT/Codex bundle to GitHub Releases after successful validation.

**Architecture:** Keep `tests/validate-skill.sh` as the single local validation entry point but add platform-specific modes. Split the GitHub Actions workflow into dependent jobs and add an idempotent `release-codex` job that publishes only on successful pushes to `main`.

**Tech Stack:** GitHub Actions YAML, Bash, Python 3 standard library, Node.js 24, PowerShell, GitHub CLI.

## Global Constraints

- The `validate` job tests only the JRXML compiler script.
- Claude and Codex validation run as separate jobs after `validate`.
- Codex release publication is independent from Claude validation.
- The portable bundle must be named `legacy-jrxml-toolkit-chatgpt-codex-skill.zip`.
- Releases are published only for pushes to `main`.
- Root `SKILL.md` remains canonical and generated Codex files must stay synchronized.

---

### Task 1: Add workflow regression coverage

**Files:**
- Create: `tests/workflow-structure.Tests.sh`

- [ ] Write assertions for the four workflow jobs, job dependencies, validation boundaries, main-only release condition, package command, and explicit artifact name.
- [ ] Run the test against the current workflow and confirm it fails because the jobs are not yet separated.
- [ ] Commit the failing regression test.

### Task 2: Split validation responsibilities

**Files:**
- Modify: `tests/validate-skill.sh`
- Modify: `.github/workflows/validate.yml`

- [ ] Add `compiler`, `claude`, `codex`, and default `all` modes to the validation script.
- [ ] Move compiler static checks and PowerShell tests into the `validate` job.
- [ ] Create `validate-claude` with Node.js version validation and Claude metadata checks.
- [ ] Create `validate-codex` with Codex metadata, generated-tree, and package checks.
- [ ] Make both platform jobs depend on `validate`.

### Task 3: Rename and publish the ChatGPT/Codex bundle

**Files:**
- Modify: `scripts/package-skill.sh`
- Modify: `tests/package-skill.Tests.sh`
- Modify: `.github/workflows/validate.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `README.md`

- [ ] Rename the portable archive and checksum to the explicit ChatGPT/Codex names.
- [ ] Add `release-codex`, dependent on `validate-codex`, restricted to successful pushes to `main`.
- [ ] Derive the release tag from `SKILL.md` and create or update the release using `gh`.
- [ ] Update manual release assets and documentation to use the new names.

### Task 4: Synchronize version metadata

**Files:**
- Modify: `SKILL.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `packaging/codex/plugin.json`
- Modify: `plugins/legacy-jrxml-toolkit/.codex-plugin/plugin.json`
- Modify: `plugins/legacy-jrxml-toolkit/skills/jasper-jrxml/SKILL.md`
- Modify: `CHANGELOG.md`

- [ ] Increment the synchronized version to `1.0.2`.
- [ ] Regenerate or exactly synchronize the committed Codex plugin tree.
- [ ] Record the CI and release changes in the changelog.

### Task 5: Verify and publish

- [ ] Run the workflow-structure test.
- [ ] Run compiler, Claude, Codex, and package validation commands.
- [ ] Confirm all GitHub Actions jobs are green.
- [ ] Confirm the `chatgpt-codex-v1.0.2` release contains `legacy-jrxml-toolkit-chatgpt-codex-skill.zip` and its checksum.
