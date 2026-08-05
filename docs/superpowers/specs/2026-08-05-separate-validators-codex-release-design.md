# Separate Validators and ChatGPT/Codex Release Design

## Goal

Split the GitHub Actions validation graph by responsibility and publish a dedicated ChatGPT/Codex skill bundle to GitHub Releases only after the relevant validation jobs succeed.

## Workflow graph

The `Validate` workflow will contain four jobs:

1. `validate`: validates only the bundled JRXML compiler script and runs its PowerShell contract tests.
2. `validate-claude`: depends on `validate` and validates Claude Code versioning and plugin metadata.
3. `validate-codex`: depends on `validate` and validates Codex/OpenAI metadata, generated plugin consistency, and distribution packages.
4. `release-codex`: depends on `validate-codex`, runs only for successful pushes to `main`, builds the skill bundle, and publishes it to the GitHub Releases page.

The Codex release path is independent from the Claude validator after the common compiler-script validation. A Claude-only validation failure must not prevent a valid ChatGPT/Codex bundle from being published.

## Distribution naming

The portable skill archive will be renamed to:

`legacy-jrxml-toolkit-chatgpt-codex-skill.zip`

Its checksum will use the same name with `.sha256` appended. The existing full Codex marketplace plugin archive remains independently named `legacy-jrxml-toolkit-codex-plugin.zip`.

## Release behavior

The release job derives the version from canonical `SKILL.md` metadata and uses the release tag `chatgpt-codex-v<version>`. It creates the release on first publication and replaces the two ChatGPT/Codex skill assets when the same release already exists, keeping the workflow idempotent for reruns.

## Validation boundaries

`tests/validate-skill.sh` will expose explicit modes:

- `compiler`
- `claude`
- `codex`
- `all` as the default for local full validation

This preserves one entry point for local development while allowing each GitHub Actions node to run only its own checks.

## Testing

A workflow-structure regression test will assert job boundaries, dependencies, publication conditions, package commands, and explicit artifact names. Existing package and metadata tests will be updated for the renamed archive and synchronized version metadata.
