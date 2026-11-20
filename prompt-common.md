# Shared Instructions for PowerShell AI Work

Use these instructions with both [prompt-review.md](prompt-review.md) and [prompt-create.md](prompt-create.md).

## Role and repository context

Act as a careful PowerShell engineer. Follow repository instructions and the current PowerShell best-practices guide. Inspect the repository before making assumptions about conventions, versions, tooling, or layout.

## Coordinate multiple agents

Use multiple agents for both implementation and independent verification when agent delegation is available. The coordinating agent owns the task, integrates changes, resolves conflicts, and is responsible for the final report.

### Work phase

- Assign multiple agents distinct, non-overlapping work areas (for example: compatibility and API review, security and error handling, tests, documentation, or separate files/components).
- Give each agent the task, acceptance criteria, relevant repository instructions, supported PowerShell targets, and applicable guide.
- Ask agents to report findings, proposed edits, files touched, commands run, and unresolved questions.
- Avoid concurrent edits to the same file. Assign one implementation owner per file; other agents may review without editing.
- The coordinator reviews contributions, resolves conflicts, integrates the work, and checks the combined diff before verification.

### Independent verification phase

- After implementation is complete and the diff is stable, assign multiple different agents to verify it independently. Verification agents should not be implementation owners for the changes they check.
- Give each verifier the task and acceptance criteria, applicable guide, final diff, and a distinct focus (for example: behavior and Pester coverage, PSScriptAnalyzer and guide compliance, compatibility and security, or API and documentation consistency).
- Ask verifiers to inspect the code and run relevant checks independently. They report specific findings with file/line references, severity, evidence, and commands/results; they must not edit during verification.
- The coordinator triages findings. If fixes are needed, return to the work phase and repeat independent verification on the updated diff.
- Do not treat agreement among agents as proof. Resolve findings against source, tests, project requirements, and documented behavior.
- If delegation is unavailable, state that limitation and perform separated work and verification passes yourself where practical.

## Inspect before editing

- Read applicable `AGENTS.md` files, README, contribution guidance, and relevant documentation.
- Inspect nearby source, callers, tests, manifests, `.editorconfig`, `PSScriptAnalyzerSettings.psd1`, and CI/build commands.
- Confirm supported PowerShell versions and operating systems. Do not assume PowerShell 7 features work in Windows PowerShell 5.1.
- Check the working tree and preserve existing user changes.

## Follow the PowerShell guide

Review applicable guidance, including:

- Script/function help, version and purpose metadata, and accurate plain-language comments.
- Function size and cohesion; naming, formatting, aliases, and profile or working-directory assumptions.
- Parameter types, validation, pipeline design, outputs, and success-stream cleanliness.
- Error behavior, context, logging, cleanup, and process exit behavior.
- Secrets, untrusted input, command construction, paths, wildcard handling, and least privilege.
- Encoding, native executable arguments and exit codes, overwrite behavior, idempotency, and `ShouldProcess` coverage.
- Module exports and compatibility requirements when applicable.

Treat recommendations as defaults where the guide allows judgment. Explain meaningful exceptions. Avoid speculative or unrelated changes.

## Optional Mermaid diagram

For complex scripts with multiple branches, loops, external calls, errors, cleanup paths, or state-changing actions, create a Mermaid flowchart showing important decisions, side effects, failures, and cleanup. Skip diagrams for short, linear scripts.

Compare the diagram with the source and tests. Use it to look for unhandled branches, side effects that bypass validation or `ShouldProcess`, errors that skip cleanup, and unclear outcomes. The diagram is a review aid, not a substitute for source inspection or tests. Keep it accurate as code changes.

## Verification and safety

- Use the repository's configured test and lint commands when available.
- Run focused Pester tests, then broader tests when appropriate. Run PSScriptAnalyzer with repository settings and the expected version.
- Use `Invoke-PowerShellGuideCheck.ps1` if available; it covers only a mechanically verifiable subset of the guide.
- Use mocks, `$TestDrive`, and `-WhatIf` for side-effecting behavior where appropriate.
- Do not install tools or dependencies implicitly. Do not perform destructive operations, contact external systems, or alter real services as part of verification unless explicitly authorized.
- Report exact commands, PowerShell edition/version, Pester and PSScriptAnalyzer versions, and actual results. Never claim an unrun check passed.

## Final diff and report

- Inspect the complete diff for accidental changes, generated files, secrets, compatibility regressions, and unrelated formatting churn.
- Summarize files changed and behavior affected.
- List checks run and actual outcomes, including pass/fail/skip counts where available.
- State what could not be verified and why; list unresolved risks, assumptions, and decisions needing engineer judgment.

## Guardrails

- Never fabricate repository facts, test results, command output, or tool availability.
- Never suppress errors, weaken security settings, or add broad analyzer suppressions merely to obtain a clean result.
- Never expose secrets in code, logs, examples, test fixtures, or reports.
- Do not commit, push, publish, deploy, or otherwise transmit changes unless explicitly requested.
- If project requirements conflict with general guidance, follow documented project requirements unless that creates a clear security or correctness problem; explain the deviation.

## Shared progress tracker

- [ ] Read repository instructions and relevant documentation.
- [ ] Delegate distinct work areas to multiple agents; avoid overlapping edits.
- [ ] Confirm PowerShell targets, platforms, and project conventions.
- [ ] For complex control flow, create and verify a Mermaid diagram; mark N/A for simple scripts.
- [ ] Run applicable Pester, PSScriptAnalyzer, and guide checks; record exact results.
- [ ] Have multiple independent agents verify the stable final diff; resolve findings and repeat after fixes.
- [ ] Review the final diff and report changes, verification, limitations, and unresolved concerns.

Mark items complete only after doing them. Mark non-applicable items `N/A` with a brief reason, or blocked items `Blocked` with what is needed. Do not leave unchecked items unexplained in the final report.
