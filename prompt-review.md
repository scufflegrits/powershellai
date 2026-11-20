# Prompt: Review a PowerShell Script

Use this prompt together with [prompt-common.md](prompt-common.md).

## Task details

- **Input directory:** `input/`
- **Script or module to review:** `<path, or identify the intended file in input/>`
- **Requested review or update:** `<describe the goal>`
- **Acceptance criteria:** `<list required behavior>`
- **Supported PowerShell versions:** `<for example, PowerShell 7.4+ or Windows PowerShell 5.1 and PowerShell 7+>`
- **Supported operating systems:** `<list targets>`
- **Additional constraints:** `<compatibility, dependencies, output contract, or other constraints>`

## Objective

Review the supplied existing PowerShell script against the repository's current best-practices guide. Explain findings and their impact. Make updates only to the extent authorized by the requested task; if the request is review-only, do not modify the source.

## Review workflow

1. Apply all shared instructions in `prompt-common.md`.
2. Inspect `input/` and identify the intended script. Do not assume every file in that directory is in scope.
3. Trace callers and related tests before proposing interface or behavior changes.
4. Report findings by severity and include file/line references, evidence, and a practical recommendation.
5. Separate confirmed defects from risks, style suggestions, and questions requiring engineer judgment.
6. If updating is authorized, make a focused patch, add or update tests as appropriate, and verify it using the shared workflow.
7. If the script already follows the relevant guidance, say so; do not invent changes to justify the review.

## Review checklist

- [ ] Correctness and acceptance criteria
- [ ] Public parameters, parameter sets, pipeline behavior, and output contract
- [ ] Help headers, plain-language comments, naming, and function cohesion
- [ ] Errors, cleanup, exit codes, and observability
- [ ] Security, secrets, untrusted inputs, paths, and external commands
- [ ] Side effects, idempotency, overwrite safeguards, and `ShouldProcess`
- [ ] PowerShell-version and platform compatibility
- [ ] Pester coverage, PSScriptAnalyzer findings, and final diff

Use `N/A` with a short reason where an item does not apply.
