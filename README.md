# Jasper JRXML Legacy Skill

Portable Agent Skill for complex **legacy iReport/JasperReports 2.x** reports, especially JasperReports 2.0.4, old DTD-based JRXML, dense official forms, absolute layouts, subreports, and headless `.jrxml` → `.jasper` validation.

It preserves legacy syntax instead of “helpfully” upgrading a 2007 report into a 2026 incident report.

## What it provides

- high-fidelity patterns for numbered fields, boxes, dividers, rotated sidebars, and rounded boxes with an open top;
- an evidence-based workflow for reproducing multi-page official forms;
- a configurable PowerShell/JDK 8 compiler harness using the consuming project's JasperReports 2.x jars;
- official SINAN form and JasperReports reference sources;
- local project learning under `docs/report/`, without leaking proprietary conventions into the shared skill.

## Install

The repository is both a portable Agent Skill and a Claude Code plugin marketplace. `SKILL.md` remains the canonical source at the repository root.

### Claude Code marketplace

Add this GitHub repository as a marketplace:

```text
/plugin marketplace add vitorhugo-dotnet/jasper-jrxml-claude-skill
```

Install the plugin:

```text
/plugin install legacy-jrxml-toolkit@jasper-jrxml-plugins
```

The plugin exposes the skill under the Claude Code namespace:

```text
/legacy-jrxml-toolkit:jasper-jrxml
```

Equivalent non-interactive CLI commands:

```bash
claude plugin marketplace add vitorhugo-dotnet/jasper-jrxml-claude-skill
claude plugin install legacy-jrxml-toolkit@jasper-jrxml-plugins
```

### Claude Code direct checkout

For local development without registering the marketplace, clone the repository and load it as a plugin:

```bash
git clone https://github.com/vitorhugo-dotnet/jasper-jrxml-claude-skill.git
claude --plugin-dir ./jasper-jrxml-claude-skill
```

Inside that session, invoke `/legacy-jrxml-toolkit:jasper-jrxml`. For project-scoped distribution, prefer marketplace installation instead of maintaining another copy.

### Cross-agent path

Clone into the open Agent Skills directory:

```bash
git clone https://github.com/vitorhugo-dotnet/jasper-jrxml-claude-skill.git \
  ~/.agents/skills/jasper-jrxml
```

Clients that support the [Agent Skills specification](https://agentskills.io/specification) can discover it there or through their configured skill catalog.

### Codex

Use the cross-agent `~/.agents/skills/jasper-jrxml` location when supported by your Codex environment, or register/clone the folder in the Codex skills directory configured by that environment.

Do not keep multiple editable copies. Prefer one clone plus symlinks when the operating system and client support them.

## Usage

Ask the agent to create, edit, inspect, compile, or validate a legacy JRXML report, or invoke `jasper-jrxml` explicitly when the client supports direct skill invocation.

Compile a report with the bundled harness:

```powershell
pwsh -NoProfile -File scripts/compile-jrxml.ps1 `
  -Jrxml "reports/complex-form.jrxml" `
  -ProjectRoot "C:\path\to\consumer-project" `
  -LibDirectory "target\app\WEB-INF\lib" `
  -DeployDirectory "src\main\webapp\WEB-INF\reports"
```

Requirements:

- JDK 8;
- the consuming project's JasperReports 2.x and transitive jars;
- PowerShell;
- a real application fill/PDF comparison for visual validation.

## Compatibility boundary

This skill intentionally targets old iReport/JasperReports. Current [JasperReports samples](https://jasperreports.sourceforge.net/sample.reference/README.html) are conceptual references only. Never introduce modern syntax into a JasperReports 2.x template without compiling it against the project's exact legacy dependencies.

Official complex-form sources are listed in [`references/official-report-sources.md`](references/official-report-sources.md), including the [SINAN portal](https://portalsinan.saude.gov.br/).

## Project-specific learning

When a correction is confirmed, the agent writes a focused Markdown lesson in the **consuming repository's** `docs/report/`. The distributed skill is not silently modified and private project details are not promoted upstream. See [`docs/report/README.md`](docs/report/README.md).

## Validate this repository

Validate the portable skill and Claude plugin metadata:

```bash
bash tests/validate-skill.sh
```

Validate with Claude Code itself:

```bash
claude plugin validate . --strict
claude --plugin-dir .
```

Inside that Claude Code session, invoke:

```text
/legacy-jrxml-toolkit:jasper-jrxml
```

If PowerShell is installed:

```powershell
pwsh -NoProfile -File tests/compile-jrxml.Tests.ps1
```

## Privacy and releases

- [Privacy statement](PRIVACY.md)
- [Changelog](CHANGELOG.md)
- [Support and bug reports](https://github.com/vitorhugo-dotnet/jasper-jrxml-claude-skill/issues)

## License

[MIT](LICENSE)
