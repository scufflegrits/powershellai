# Prompt: Create a PowerShell Script

Use this prompt together with [prompt-common.md](prompt-common.md).

## Task details

- **Requested capability:** `<what the script should do>`
- **Inputs:** `<parameters, files, pipeline objects, or external sources>`
- **Expected outputs:** `<objects, files, messages, or exit behavior>`
- **Acceptance criteria:** `<observable conditions that define success>`
- **Supported PowerShell versions:** `<for example, PowerShell 7.4+ or Windows PowerShell 5.1 and PowerShell 7+>`
- **Supported operating systems:** `<list targets>`
- **Dependencies and permissions:** `<modules, native tools, credentials, or required privileges>`
- **Destination path:** `<where the script and related files should be created>`
- **Additional constraints:** `<performance, compatibility, or integration requirements>`

## Objective

Design and implement a maintainable PowerShell script that satisfies the task and repository conventions. Use the current best-practices guide and available testing tools. Do not guess at consequential behavior, required permissions, or destructive defaults; inspect repository context and ask a focused question if those requirements cannot be inferred.

## Creation workflow

1. Apply all shared instructions in `prompt-common.md`.
2. Inspect the repository for existing commands, modules, conventions, dependencies, and test patterns that should be reused.
3. Propose a concise design and identify inputs, outputs, errors, side effects, and compatibility constraints before implementing when the task has meaningful complexity.
4. Implement the smallest complete solution. Include comment-based help, typed and validated parameters, clear output behavior, and `ShouldProcess` for operations where preview or confirmation adds safety.
5. Add focused Pester tests for success, boundary cases, failure paths, and side-effect guards. Use mocks and `$TestDrive` to keep tests isolated.
6. Run PSScriptAnalyzer and the repository guide-check script where available; fix relevant findings rather than suppressing them broadly.
7. Use a Mermaid flowchart for complex control flow as described in `prompt-common.md`.
8. Verify the completed implementation and tests using the workflow tier chosen in `prompt-common.md`. Resolve findings and repeat verification after changes.
9. Review the final diff and report files created, behavior, checks run, results, and limitations.

## Creation checklist

- [ ] Task and acceptance criteria are explicit
- [ ] Existing repository capabilities and conventions were inspected
- [ ] Inputs, outputs, errors, side effects, and compatibility were designed
- [ ] Script and function help and plain-language comments are accurate
- [ ] Parameters are validated and outputs are intentional
- [ ] Security and side effects are handled safely
- [ ] Focused Pester tests were added where appropriate
- [ ] PSScriptAnalyzer and guide checks were run where available
- [ ] Final changes were verified as the chosen workflow tier requires
- [ ] Final diff, results, assumptions, and limitations were reported

Mark items complete only after doing them. Mark non-applicable items `N/A` with a brief reason, or blocked items `Blocked` with what is needed.
