# Codex Skill Distribution Design

## Goal

Publish the existing portable Agent Skill for Codex/OpenAI-compatible installation without introducing a second editable copy of `SKILL.md` or an undocumented Codex manifest.

## Decision

The repository root remains the canonical skill source. A deterministic packaging script creates `dist/jasper-jrxml-skill.zip` from an explicit allowlist containing `SKILL.md`, `references/`, `scripts/`, `docs/`, `LICENSE`, `README.md`, `PRIVACY.md`, and `CHANGELOG.md`.

No `.codex-plugin` manifest will be added until OpenAI publishes and documents a stable schema. Codex users may install from the repository through the Agent Skills directory, while ChatGPT/OpenAI skill upload uses the generated ZIP artifact.

## Components

- `scripts/package-skill.sh`: builds the ZIP from a clean staging directory and produces a SHA-256 checksum.
- `tests/package-skill.Tests.sh`: validates archive contents, exclusions, relative paths, and reproducibility-oriented behavior.
- `.github/workflows/validate.yml`: runs the package contract test on every push and pull request.
- `.github/workflows/release.yml`: builds and attaches the ZIP and checksum to semantic-version tags.
- `README.md`: documents direct Codex installation, ZIP creation, and OpenAI upload steps.
- `CHANGELOG.md`: records the new distribution support.

## Validation

The package test must fail when the packaging script is absent, then pass only when the archive contains the required portable files and excludes repository metadata, CI files, generated artifacts, and proprietary references.

Release automation must run the existing repository validation before publishing assets.

## Constraints

- `SKILL.md` remains the single source of truth.
- Relative paths referenced by `SKILL.md` must remain valid inside the ZIP.
- The package must not include `.git/`, `.github/`, `tests/`, `dist/`, generated `.jasper` files, or private project content.
- The implementation must not claim a global Codex marketplace submission path that is not publicly documented.
