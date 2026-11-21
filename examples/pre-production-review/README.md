# Review a test-environment script before production

You have copied a script from your test environment into `input/`. What happens
next? **Nothing starts automatically.** PowerShellAI supplies standards, AI review
prompts, and executable checks. You ask an AI assistant to apply them to the named
script. It is not a folder watcher, deployment service, or automatic production approval.

This walkthrough uses `input/YourScript.ps1` as a placeholder. Replace it with your
actual filename. It describes a workflow, not a completed review of a real script.

## 1. Identify the candidate and its requirements

Keep the imported script unchanged for the first review. Record where it came
from, its source revision if available, and a hash of the copy:

```powershell
Get-FileHash -LiteralPath ./input/YourScript.ps1 -Algorithm SHA256
```

Give the reviewer enough context to judge correctness:

| Information | What to provide |
|---|---|
| Purpose | What successful execution should accomplish and how you will check it. |
| Invocation | Actual parameter names, example values with secrets removed, and whether a person or scheduler runs it. |
| Runtime | Production operating system, PowerShell edition/version, required modules and native tools. |
| Identity | Execution account and required permissions; supply descriptions, not passwords or tokens. |
| Dependencies | Called scripts, configuration structure, sample input/output, and existing tests. |
| Side effects | Files, accounts, services, databases, or remote systems it can change. |
| Operational expectations | Failure handling, logging, reruns, partial completion, and recovery requirements. |
| Environment differences | Differences between test and production, including permissions, paths, data volume, and connectivity. |

If this context is missing, the AI can inspect code and report concerns, but it
cannot determine whether the business behavior or production assumptions are correct.

Files beneath `input/` are ignored by Git. They are not uploaded by an ordinary
push and are therefore absent from GitHub CI. Ignoring files does not redact their
contents or prevent an AI service from receiving material you give it. Remove
unnecessary secrets and use your organization's approved review environment.

## 2. Request an initial review

Open your AI coding assistant in the PowerShellAI repository. Supply the following
request, replacing every angle-bracket placeholder. The first pass inspects source
and runs static checks; it does not execute the candidate or its tests.

```text
Use prompt-common.md and prompt-review.md to review input/YourScript.ps1
against powershell-best-practices.md and the testing/analyzer guides.

Goal: <what the script must accomplish before promotion>
Acceptance criteria: <observable success and failure behavior>
Production runtime: <OS, PowerShell edition/version, module/tool versions>
Invocation and identity: <parameters, scheduler/manual use, execution permissions>
Related files and tests: <explicit paths, or state what is unavailable>
Production differences and constraints: <list them>

Review only. Preserve the imported source. Do not execute, dot-source, or import
the candidate, run its tests, or connect to external systems during this pass.
Static parsing and the guide checker are allowed.

Choose and explain the workflow tier. Inspect the named script and its callers
or dependencies where available. Do not assume every file under input/ is in scope.
Report confirmed defects separately from risks, style suggestions, and questions.
For each finding, give severity, file/line evidence, impact, and a proposed fix.

Save the report to input/review-YourScript/review.md. Include the candidate's
SHA-256 hash, requirements, exact checks and results, untested assumptions,
and a proposed lab verification plan. Do not approve or perform deployment.
```

The AI reads the source, traces inputs and outputs, reviews error and cleanup
paths, and checks parameter contracts, compatibility, secrets handling, and side
effects. It applies the task-size rules in the shared prompt. Complex control
flow may warrant a diagram; a short script may not.

One mechanical check, run from the repository root, is:

```powershell
pwsh -NoProfile -NonInteractive -File ./Invoke-PowerShellGuideCheck.ps1 -Path ./input/YourScript.ps1
```

This analyzes the named source without invoking the candidate. Errors and warnings
produce exit code `1`; a passing check returns `0`. The repository's analyzer
settings apply by default. If the source project has approved settings, identify
them and pass their path with `-Settings`; explain meaningful policy differences.
Include `-Severity Error,Warning,Information` to request informational findings too.

This command does not perform the AI review or create the report. It cannot prove
business correctness, correct privileges, or successful production execution.

## 3. Turn the report into a verified correction

Read the findings and resolve questions about consequential behavior. A useful
report provides the following, rather than just saying the script "looks good":

| Deliverable | What it tells you |
|---|---|
| Findings with evidence | Which defects are demonstrated and which concerns still need investigation. |
| Proposed changes | The smallest correction and any effects on parameters, output, or callers. |
| Verification record | Commands, tool versions, actual outcomes, and checks that were not run. |
| Remaining questions | Missing requirements, environment assumptions, or unresolved operational risks. |
| Lab plan | Which tests can use mocks or temporary files and which need authorized integration testing. |

If fixes are warranted, explicitly authorize a separate correction and tests. For example:

```text
Implement the agreed fixes from input/review-YourScript/review.md.
Keep input/YourScript.ps1 unchanged. Save the corrected script to
input/review-YourScript/after/YourScript.ps1 and its Pester tests to
input/review-YourScript/Tests/.
Preserve the agreed public parameters and output properties.
Use mocks and temporary fixtures for isolated tests. Do not execute against
production. Update the report with the diff, exact test results, and limitations.
```

Inspect tests before running them: tests can execute the candidate and contact
real systems if they are not isolated. After approving the isolated test scope,
run its focused suite with Pester 5.7.1 and analyze the corrected script again.
Fix findings and repeat verification after changes. The reviewer also checks the
stable final diff in the separate verification pass required by the shared prompt.

For a checked delivery, follow the shared instructions for the checked header:
complete the agreed checks, add the actual PowerShellAI version/commit and report
reference to the corrected copy, recheck its final form, and record its SHA-256
in the report and an adjacent `.sha256` file. Omit the stamp if required checks
remain incomplete. The [README comparison commands](../../README.md#check-whether-a-stamped-script-has-changed)
let the recipient detect subsequent edits against a trusted saved fingerprint.

The [worked log-summary review](../worked-review/README.md) demonstrates this
part with runnable scripts: the original passes static checks but fails four
behavior tests, while the correction passes all eight.

## 4. Verify in the lab, then prepare the production handoff

Test the corrected candidate in an authorized environment using the intended
PowerShell version, account, dependencies, and representative data. A Debian VM
can verify Linux behavior; it cannot establish Windows-specific behavior or prove
that production permissions and services match. Record those remaining checks.

For scripts that change state, test previews, normal execution, failures, cleanup,
reruns, and recovery as applicable. Inspect `ShouldProcess` guards before relying
on `-WhatIf`: the switch only protects actions that actually honor it.

Keep the report tied to the exact corrected file and its hash. If the candidate
changes after testing, review and verify the updated version. Resolve blocking
findings or record an explicit owner decision about outstanding risks.

Keep the last checked file and fingerprint as your reference. If you edit a
separate lab copy, mark its previous check as historical, say that re-review is
required, and add dated header notes explaining the changes and lab findings.
Give the AI those notes, the edited file, and the previous checked source (or Git
revision) and report so it can compare the actual changes. A new successful review
produces a new stamped copy and fingerprint, followed by another lab pass. If no
script edit is needed, record lab results outside the script so its hash stays
unchanged. The [README lab-change workflow](../../README.md#after-lab-testing-record-changes-and-ask-for-another-review)
includes a header example and a message you can send to the AI.

Move the reviewed changes and appropriate tests into the script's owning project
through its normal review process, with internal reports kept in an approved
location. Run that project's CI on the actual candidate; this public repository's
own green CI does not validate your ignored `input/` files. Include execution
instructions, required permissions, verification results, and recovery steps in
the handoff. Production approval and deployment remain explicit owner actions.

Useful additions as this process grows are a repeatable sanitized test dataset,
an environment comparison checklist, and a standard report format with candidate
hashes. Automatic intake or report generation would require additional tooling;
the current repository does not implement them.
