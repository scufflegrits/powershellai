# PowerShell Engineering Guides and Tools

This repository helps people and AI assistants write PowerShell that is safe, readable, and tested. PowerShell scripts often change real systems, such as files, services, and user accounts, so a small mistake can cause real damage. The repository gives you three things:

- **Guides**: written standards that say what good PowerShell looks like and why.
- **AI prompts**: ready-made instructions that make an AI assistant follow those guides when it reviews or writes a script, and show its evidence instead of only claiming that the work is correct.
- **Automated checks**: a script that finds the mistakes a computer can detect on its own. GitHub runs it on every change.

The automated checks find only some problems. Whether a script does the right thing still needs tests and review by a person or an AI.

## Table of contents

- [Ways to use this project](#ways-to-use-this-project)
- [Words used in this README](#words-used-in-this-readme)
- [How the pieces fit together](#how-the-pieces-fit-together)
- [Start here](#start-here)
- [Guides and tools](#guides-and-tools)
- [Requirements](#requirements)
- [Check your code with the linter](#check-your-code-with-the-linter)
- [Run the tests](#run-the-tests)
- [Use in other repositories](#use-in-other-repositories)
- [Repository layout](#repository-layout)
- [Guide versions](#guide-versions)
- [Appendix: Acronyms and key terms](#appendix-acronyms-and-key-terms)
  - [Acronyms and abbreviations](#acronyms-and-abbreviations)
  - [Key terms](#key-terms)

## Ways to use this project

Choose the parts that fit your task. You can read the guides, run the automated checks, or combine them with an AI assistant. Reading the guides requires no tool installation. Running checks requires the [listed tools](#requirements); AI-assisted work requires an assistant that you supply.

| What you want to do | How to use the project | What you get |
|---|---|---|
| Learn to write better PowerShell | Read the [best-practices guide](powershell-best-practices.md) and follow the [worked review](examples/worked-review/README.md). | Practical rules and an example showing how tests expose problems that linting misses. |
| Review an existing script | Put a copy in `input/`, then give your AI assistant [the shared instructions](prompt-common.md) and [review prompt](prompt-review.md), with the exact filename and expected behavior. | Findings with evidence, proposed fixes, and an explanation of what was and was not verified. |
| Create a new script | Give your AI assistant [the shared instructions](prompt-common.md) and [creation prompt](prompt-create.md), filled in with inputs, outputs, target environment, and acceptance criteria. | A script and appropriate tests, followed by verification against your requirements. |
| Check code on your own machine | Install the [requirements](#requirements) and run the [guide checker](#check-your-code-with-the-linter) against a named file or folder. | Automated findings for analyzer rules and supplemental checks, with an exit code suitable for automation. |
| Review a script before production | Follow the [pre-production walkthrough](examples/pre-production-review/README.md): preserve the original, request a review, authorize any fixes, and verify the correction in a suitable lab. | A review record and tested candidate to take through your normal production approval process. |
| Adopt shared standards in another project | Copy the [agent-instruction template](templates/AGENTS-powershell.md) and call the [reusable workflow](#use-in-other-repositories), keeping their release references aligned. | Consistent AI instructions and local/CI checks without copying this entire repository. |

Copying a script into `input/` does not start a review automatically. You must request the review or run the checker. Tests must exercise your script's required behavior; this repository's own passing tests do not establish that your script is ready for production.

## Words used in this README

- **Module**: a packaged set of PowerShell commands that can be installed and shared, such as Pester.
- **Linter (static analysis)**: a tool that reads code without running it and flags likely mistakes. PSScriptAnalyzer is the standard linter for PowerShell.
- **Pester**: PowerShell's testing framework. A test runs code and checks that the result is what you expected.
- **CI (continuous integration)**: checks that run automatically on GitHub every time someone pushes a change. This repository uses GitHub Actions for CI.
- **AI agent**: an AI assistant, such as Claude or GitHub Copilot, that can read files and run commands in a repository.
- **Release tag**: a fixed name, such as `v1.1.0`, for one exact version of this repository. A tag never changes, so anything that refers to it gets the same files every time.
- **Mermaid**: a text format for diagrams. GitHub draws Mermaid text as a picture, which is how the diagrams below appear.

## How the pieces fit together

Read this diagram from top to bottom. The guides at the top define the rules; everything below them uses those rules.

```mermaid
---
config:
  # The only built-in theme meant to be customized.
  theme: base
  # Pin classic shapes so class styles target stable elements.
  look: classic
  # dagre: GitHub's default flowchart engine; ELK support there is undocumented.
  layout: dagre
  # Quoted hex: these values feed Mermaid's color calculations.
  themeVariables:
    darkMode: false
    background: "#ffffff"
    primaryTextColor: "#191970"
    lineColor: "#475569"
    edgeLabelBackground: "#ffffff"
  flowchart:
    # Labels break only at <br/>; the ~200px default split file names mid-word.
    wrappingWidth: 300
---
%% How the repository's parts relate, from standards at the top to consumers at the bottom.
flowchart TD
  subgraph SG_CARD[" "]
    %% dagre lays a subgraph out left to right unless told otherwise.
    direction TD
    GUIDES["Best-practices, Pester,<br/>and PSScriptAnalyzer guides"]
    PROMPTS["AI prompts<br/>prompt-common + review / create"]
    SETTINGS["PSScriptAnalyzerSettings.psd1"]
    CHECKER["Invoke-PowerShellGuideCheck.ps1"]
    TESTS["Pester tests"]
    REUSABLE["Reusable workflow<br/>powershell-guide-check.yml"]
    TEMPLATE["templates/AGENTS-powershell.md"]
    THIS_CI["This repository's CI<br/>powershell.yml"]
    OTHER_REPOS["Other repositories<br/>pinned to a release tag"]

    GUIDES -->|"mechanical subset"| CHECKER
    GUIDES -->|"standards for"| PROMPTS
    GUIDES -->|"linked at a tag by"| TEMPLATE
    SETTINGS -->|"rules for"| CHECKER
    TESTS -->|"verify"| CHECKER
    CHECKER -->|"runs in"| REUSABLE
    REUSABLE -->|"called by"| THIS_CI
    REUSABLE -->|"called by"| OTHER_REPOS
    TEMPLATE -->|"copied into"| OTHER_REPOS
  end

  classDef nodeDoc fill:aliceblue,stroke:steelblue,color:midnightblue
  classDef nodeTool fill:honeydew,stroke:seagreen,color:darkgreen
  classDef nodeExternal fill:lavender,stroke:slateblue,color:midnightblue
  classDef groupWrapper fill:white,stroke:none

  class GUIDES,PROMPTS,TEMPLATE nodeDoc
  class SETTINGS,CHECKER,TESTS,REUSABLE,THIS_CI nodeTool
  class OTHER_REPOS nodeExternal
  class SG_CARD groupWrapper
```

Colors are the same in every diagram: blue for documents and prompts, green for scripts, settings, and CI steps, purple for other repositories, yellow for decisions, and red for failure paths.

## Start here

Pick the path that matches what you are doing:

- **Seeing a complete example first.** Follow the [worked script review](examples/worked-review/README.md): inspect a small script, read the findings, compare the correction, and run the same tests against both versions.
- **Reviewing a test-environment script before production.** Follow the [pre-production review workflow](examples/pre-production-review/README.md) after placing a copy in `input/`. It explains what to ask the AI, which checks run, what the report should contain, and how to verify a correction before promotion.
- **Writing or reviewing PowerShell yourself.** Read [PowerShell Best Practices](powershell-best-practices.md) first. It is the standard everything else in this repository is built on. Read the [Pester testing guide](powershell-pester-testing.md) when you add tests, and the [PSScriptAnalyzer guide](powershell-psscriptanalyzer.md) when you set up automated checks.
- **Asking an AI to review or write a script.** Give the AI [prompt-common.md](prompt-common.md) together with either [prompt-review.md](prompt-review.md) or [prompt-create.md](prompt-create.md). First replace the placeholders in angle brackets, such as `<what the script should do>`: the prompts are templates, and the AI cannot guess your requirements. The review prompt does not change your script unless you ask it to.
- **Changing this repository.** Install the [requirements](#requirements), then run the [checks](#check-your-code-with-the-linter) and [tests](#run-the-tests) before you push.

When an AI follows the prompts, it works like this. It first judges how big the task is. A small task gets one careful pass followed by a separate check. A large task gets several AI agents, with different agents checking the work, because an agent tends to miss its own mistakes. Every path ends with real checks, because an AI saying a script works is not proof that it does.

```mermaid
---
config:
  # The only built-in theme meant to be customized.
  theme: base
  # Pin classic shapes so class styles target stable elements.
  look: classic
  # dagre: GitHub's default flowchart engine; ELK support there is undocumented.
  layout: dagre
  # Quoted hex: these values feed Mermaid's color calculations.
  themeVariables:
    darkMode: false
    background: "#ffffff"
    primaryTextColor: "#191970"
    lineColor: "#475569"
    edgeLabelBackground: "#ffffff"
  flowchart:
    # Labels break only at <br/>; the ~200px default split file names mid-word.
    wrappingWidth: 300
---
%% How an AI agent uses the prompts. Tiers come from prompt-common.md.
flowchart TD
  subgraph SG_CARD[" "]
    %% dagre lays a subgraph out left to right unless told otherwise.
    direction TD
    TASK["PowerShell task"]
    TASK_TYPE{"Review or create?"}
    REVIEW["prompt-review.md<br/>script in input/"]
    CREATE["prompt-create.md<br/>requirements"]
    COMMON["prompt-common.md<br/>plus guide §13 rules"]
    TIER{"Task size?"}
    TIER_SMALL["Small: work alone,<br/>then a separate verification pass"]
    TIER_MEDIUM["Medium: one independent verifier"]
    TIER_LARGE["Large: multiple agents<br/>for work and verification"]
    CHECKS["Run Pester, PSScriptAnalyzer,<br/>and the guide checker"]
    FINDINGS{"Findings to fix?"}
    REPORT["Report changes, results,<br/>and limitations"]

    TASK --> TASK_TYPE
    TASK_TYPE -->|"review"| REVIEW
    TASK_TYPE -->|"create"| CREATE
    REVIEW --> COMMON
    CREATE --> COMMON
    COMMON --> TIER
    TIER -->|"small"| TIER_SMALL
    TIER -->|"medium"| TIER_MEDIUM
    TIER -->|"large"| TIER_LARGE
    TIER_SMALL --> CHECKS
    TIER_MEDIUM --> CHECKS
    TIER_LARGE --> CHECKS
    CHECKS --> FINDINGS
    FINDINGS -->|"yes: fix and re-verify"| TIER
    FINDINGS -->|"no"| REPORT
  end

  classDef nodeDoc fill:aliceblue,stroke:steelblue,color:midnightblue
  classDef nodeTool fill:honeydew,stroke:seagreen,color:darkgreen
  classDef nodeDecision fill:lemonchiffon,stroke:darkgoldenrod,color:saddlebrown
  classDef groupWrapper fill:white,stroke:none

  class TASK,REVIEW,CREATE,COMMON,TIER_SMALL,TIER_MEDIUM,TIER_LARGE,REPORT nodeDoc
  class CHECKS nodeTool
  class TASK_TYPE,TIER,FINDINGS nodeDecision
  class SG_CARD groupWrapper
```

## Guides and tools

- [PowerShell Best Practices](powershell-best-practices.md): the main standard. It covers naming, parameters, error handling, security, previewing changes with `-WhatIf`, testing, and rules for AI agents. Shared rules make scripts predictable and easier to review, and they give an AI a concrete standard to follow instead of its own habits.
- [Pester testing guide](powershell-pester-testing.md): how to write and run tests with Pester. Tests show that a script does what it should and keeps doing it after later changes. Scripts that change systems need them most.
- [PSScriptAnalyzer guide](powershell-psscriptanalyzer.md): how to set up and use the linter. A linter catches common mistakes automatically, before anyone spends time reviewing the code.
- [PSScriptAnalyzer documentation](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules) (Microsoft): the official reference, for when you need details about a rule that the guide does not cover.
- [Guide check script](Invoke-PowerShellGuideCheck.ps1) (`Invoke-PowerShellGuideCheck.ps1`): runs PSScriptAnalyzer plus a few extra checks for guide rules that PSScriptAnalyzer does not cover, such as code that cannot be parsed and arrays grown inside loops, which is slow. It gives you one command for every automated check, and it runs the same way on your computer and on GitHub.
- [Shared AI prompt](prompt-common.md): rules for every AI task. It sets how much checking a task needs, how to verify the work, and how to report results honestly. Without these rules, an AI may skip tests or claim that checks passed when it never ran them. It builds on the "Rules for AI agents" section of the best-practices guide.
- [AI script review prompt](prompt-review.md): asks the AI to review an existing script, usually one you put in `input/`. The AI reports findings by severity with evidence, and keeps real bugs separate from style suggestions.
- [AI script creation prompt](prompt-create.md): asks the AI to design and write a new script from your requirements, including tests, instead of producing code with no plan or tests.
- [Mermaid conventions](reference/mermaid-best-practices.md): how AI agents draw, render, and check flowcharts of PowerShell scripts. When every diagram follows the same rules, unhandled branches, skipped cleanup, and changes that bypass `-WhatIf` are easier to spot during review. This README's diagrams follow them too.

## Requirements

- **PowerShell 7 or later.** The check script uses features of PowerShell 7. The scripts you write may still target Windows PowerShell 5.1; the best-practices guide covers the differences.
- **PSScriptAnalyzer 1.24.0** for the linter and the check script.
- **Pester 5.7.1** for this repository's tests.

Use these exact versions. New versions of PSScriptAnalyzer and Pester can add or change rules, and these are the versions GitHub's checks use (`.github/workflows/powershell-guide-check.yml`), so matching them means you get the same results locally as on GitHub. To install them for your user account from the PowerShell Gallery, run in `pwsh`:

```powershell
Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.24.0 -Scope CurrentUser -Repository PSGallery
Install-Module -Name Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck
```

PowerShell will warn that you are installing from an untrusted repository. That is PowerShell's default setting for the public PowerShell Gallery, not a problem with these modules; answer `Y`. `-SkipPublisherCheck` is needed on Windows, where an older Pester 3.4 signed by Microsoft ships with Windows PowerShell; it is harmless elsewhere. Confirm the installed versions with:

```powershell
Get-Module -ListAvailable PSScriptAnalyzer, Pester | Select-Object Name, Version
```

If your organization uses an internal repository or another approved setup method, use that instead. When you change a pinned version, update both this section and the workflow. The check script never installs modules for you.

## Check your code with the linter

The check script reads every `.ps1`, `.psm1`, and `.psd1` file without running it and reports likely problems. Run it first: it is the quickest and cheapest way to catch mistakes. From the repository root, run:

```powershell
./Invoke-PowerShellGuideCheck.ps1 -Path .
```

Each finding is one line: `file:line:column: [Severity] Rule: message`.

- **Errors and warnings** make the check fail (exit code 1). Fix them before you push.
- **Information** findings are worth reading but do not make the check fail.

Which rules apply comes from `PSScriptAnalyzerSettings.psd1`. The script uses the nearest one, searching upward from the folder you check to the repository root, unless you name a file with `-Settings`.

The array-append check keeps variable names separate across functions to avoid confusing an array with an unrelated counter. It does not track runtime types or control flow.

The check cannot tell whether your script does what you intended, or whether it is safe in your environment. That still needs tests and review.

```mermaid
---
config:
  # The only built-in theme meant to be customized.
  theme: base
  # Pin classic shapes so class styles target stable elements.
  look: classic
  # dagre: GitHub's default flowchart engine; ELK support there is undocumented.
  layout: dagre
  # Quoted hex: these values feed Mermaid's color calculations.
  themeVariables:
    darkMode: false
    background: "#ffffff"
    primaryTextColor: "#191970"
    lineColor: "#475569"
    edgeLabelBackground: "#ffffff"
  flowchart:
    # Labels break only at <br/>; the ~200px default split file names mid-word.
    wrappingWidth: 300
---
%% What Invoke-PowerShellGuideCheck.ps1 does, including its exit codes.
flowchart TD
  subgraph SG_CARD[" "]
    %% dagre lays a subgraph out left to right unless told otherwise.
    direction TD
    INPUT_PATH["-Path: a file or folder"]
    COLLECT["Collect .ps1, .psm1, and .psd1 files"]
    ANY_FILES{"Any files?"}
    NO_FILES["Warn and exit 0"]
    SETTINGS_GIVEN{"-Settings passed?"}
    FIND_SETTINGS["Search upward to the repository root<br/>for PSScriptAnalyzerSettings.psd1"]
    ANALYZE["Run PSScriptAnalyzer on each file"]
    GUIDE_CHECKS["Add parse errors and<br/>array += inside loops"]
    FILTER["Keep the requested severities<br/>parse errors always kept"]
    ANY_FAILURES{"Any errors or warnings?"}
    EXIT_FAIL["Print findings, exit 1"]
    EXIT_PASS["Exit 0"]

    INPUT_PATH --> COLLECT
    COLLECT --> ANY_FILES
    ANY_FILES -->|"no"| NO_FILES
    ANY_FILES -->|"yes"| SETTINGS_GIVEN
    SETTINGS_GIVEN -->|"no"| FIND_SETTINGS
    SETTINGS_GIVEN -->|"yes"| ANALYZE
    FIND_SETTINGS -->|"found or defaults"| ANALYZE
    ANALYZE --> GUIDE_CHECKS
    GUIDE_CHECKS --> FILTER
    FILTER --> ANY_FAILURES
    ANY_FAILURES -->|"yes"| EXIT_FAIL
    ANY_FAILURES -->|"no"| EXIT_PASS
  end

  classDef nodeTool fill:honeydew,stroke:seagreen,color:darkgreen
  classDef nodeDecision fill:lemonchiffon,stroke:darkgoldenrod,color:saddlebrown
  classDef nodeOutcomeFail fill:mistyrose,stroke:firebrick,color:maroon
  classDef groupWrapper fill:white,stroke:none

  class INPUT_PATH,COLLECT,FIND_SETTINGS,ANALYZE,GUIDE_CHECKS,FILTER,NO_FILES,EXIT_PASS nodeTool
  class ANY_FILES,SETTINGS_GIVEN,ANY_FAILURES nodeDecision
  class EXIT_FAIL nodeOutcomeFail
  class SG_CARD groupWrapper
```

## Run the tests

The tests in `Tests/` check this repository's own check script. They make sure it still catches the problems it should; if it had a bug, it could report a clean result for bad code. The [worked example](examples/worked-review/README.md) has a separate test suite for its corrected script. Neither suite tests your own scripts; write Pester tests for them as the [Pester testing guide](powershell-pester-testing.md) describes.

From the repository root:

```powershell
Invoke-Pester -Path . -Output Detailed
```

The tests run the check script in a separate `pwsh` process, so PSScriptAnalyzer must be installed for that process too.

GitHub Actions runs the check script and these tests automatically on both Ubuntu and Windows for every push and pull request, so a change that breaks either platform is caught before anyone relies on it. The tool versions are pinned, so a new release of PSScriptAnalyzer or Pester cannot silently change the results. This repository's CI uses the same reusable workflow that other repositories use (see below), so every push here also tests that workflow.

A separate Ubuntu job runs the Mermaid audit tool's unit tests with Python 3.13 and PyYAML 6.0.4. These tests check the diagram tooling without installing a browser or rendering diagrams. See the [audit scripts README](reference/scripts/README.md) for setup and the command to run them locally.

## Use in other repositories

Another PowerShell repository can use these standards and checks without copying this whole repository.

**Always refer to a release tag**, such as `v1.1.0`, not to the `master` branch. A tag never changes, so your project keeps the exact rules it was tested with until you choose to upgrade. `master` changes whenever this repository changes, and a new rule could suddenly make your checks fail.

**AI agent instructions.** Many AI coding assistants automatically read a file named `AGENTS.md` or `CLAUDE.md` when they start working in a repository. Copy the section in [templates/AGENTS-powershell.md](templates/AGENTS-powershell.md) into that file in the other repository. It points the AI to these guides at a fixed tag and tells it which checks to run, so the AI follows the same standards there.

**Local checks.** The template includes copy-and-run PowerShell commands that download the checker from the same release as CI into a temporary directory, run it with the pinned analyzer, and optionally run Pester with failing exit codes. Running PSScriptAnalyzer alone skips the checker's supplemental rules. Use the same paths, settings, and severities locally as in your workflow.

**CI.** A reusable workflow is a GitHub Actions workflow that other repositories can call instead of writing their own. To run the check script, and optionally Pester, on every push in another repository, add a workflow file there like this:

```yaml
name: PowerShell

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  powershell:
    uses: scufflegrits/powershellai/.github/workflows/powershell-guide-check.yml@v1.1.0
    with:
      pester-path: ./Tests   # omit to skip Pester
```

Optional inputs: `path` (default `.`), `settings` (default: nearest `PSScriptAnalyzerSettings.psd1`, otherwise PSScriptAnalyzer defaults), `severity` (default `Error,Warning`), and `os` (JSON array, default `["ubuntu-latest", "windows-latest"]`). The workflow uses the check script and tool versions from the tag you pin. To apply this repository's analyzer rules there too, copy [PSScriptAnalyzerSettings.psd1](PSScriptAnalyzerSettings.psd1) into the other repository's root.

Each job of the reusable workflow runs these steps once for every operating system in `os`:

```mermaid
---
config:
  # The only built-in theme meant to be customized.
  theme: base
  # Pin classic shapes so class styles target stable elements.
  look: classic
  # dagre: GitHub's default flowchart engine; ELK support there is undocumented.
  layout: dagre
  # Quoted hex: these values feed Mermaid's color calculations.
  themeVariables:
    darkMode: false
    background: "#ffffff"
    primaryTextColor: "#191970"
    lineColor: "#475569"
    edgeLabelBackground: "#ffffff"
  flowchart:
    # Labels break only at <br/>; the ~200px default split file names mid-word.
    wrappingWidth: 300
---
%% One job of powershell-guide-check.yml; it runs once per operating system in the os input.
flowchart TD
  subgraph SG_CARD[" "]
    %% dagre lays a subgraph out left to right unless told otherwise.
    direction TD
    CALLER["Workflow in another repository<br/>pinned to @vX.Y.Z"]
    CHECKOUT_CALLER["Check out the caller's repository"]
    CHECKOUT_TOOLS["Check out the checker from the same<br/>commit as the workflow: job.workflow_sha"]
    INSTALL["Install PSScriptAnalyzer 1.24.0<br/>and Pester 5.7.1"]
    RUN_CHECK["Run the guide checker<br/>with path, settings, severity"]
    CHECK_OK{"Errors or warnings?"}
    PESTER_SET{"pester-path set?"}
    RUN_PESTER["Run Pester tests"]
    JOB_DONE["Job passes"]
    JOB_FAIL["Job fails"]

    CALLER --> CHECKOUT_CALLER
    CHECKOUT_CALLER --> CHECKOUT_TOOLS
    CHECKOUT_TOOLS --> INSTALL
    INSTALL --> RUN_CHECK
    RUN_CHECK --> CHECK_OK
    CHECK_OK -->|"no"| PESTER_SET
    CHECK_OK -->|"yes"| JOB_FAIL
    PESTER_SET -->|"no"| JOB_DONE
    PESTER_SET -->|"yes"| RUN_PESTER
    RUN_PESTER -->|"all pass"| JOB_DONE
    RUN_PESTER -->|"any fail"| JOB_FAIL
  end

  classDef nodeTool fill:honeydew,stroke:seagreen,color:darkgreen
  classDef nodeDecision fill:lemonchiffon,stroke:darkgoldenrod,color:saddlebrown
  classDef nodeExternal fill:lavender,stroke:slateblue,color:midnightblue
  classDef nodeOutcomeFail fill:mistyrose,stroke:firebrick,color:maroon
  classDef groupWrapper fill:white,stroke:none

  class CALLER nodeExternal
  class CHECKOUT_CALLER,CHECKOUT_TOOLS,INSTALL,RUN_CHECK,RUN_PESTER,JOB_DONE nodeTool
  class CHECK_OK,PESTER_SET nodeDecision
  class JOB_FAIL nodeOutcomeFail
  class SG_CARD groupWrapper
```

## Repository layout

- `.github/workflows/`: the automated checks GitHub runs. `powershell-guide-check.yml` is the reusable workflow that other repositories call; `powershell.yml` runs it for this repository.
- `templates/`: text to copy into other repositories, so they can use these guides without copying this whole repository.
- `reference/`: supporting material for AI-assisted code review. The Mermaid conventions make agents diagram a script the same way every time: one node per decision, side effect, or exit path, with every branch labeled, and each diagram rendered and checked before it is delivered. A reviewer can then compare the diagram with the code to find paths the code doesn't handle. The diagram is a review aid, not a substitute for tests. `reference/scripts/` holds an optional tool that audits these diagrams.
- `input/`: put a script here when you ask an AI to review it with the review prompt, so the AI knows which file to look at. Git ignores everything in this folder, because a script under review may contain internal names or secrets that must not reach this public repository.
- `Tests/`: Pester tests for the check script (not for your scripts).
- `examples/worked-review/`: a complete review walkthrough with original and corrected scripts and shared behavior tests.
- `examples/pre-production-review/`: instructions for taking a script from `input/` through an AI review, authorized fixes, lab verification, and a production handoff.
- `PSScriptAnalyzerSettings.psd1`: which analyzer rules this repository enforces, such as consistent indentation and brace placement. Copy it to another repository to apply the same rules there.
- `CHANGELOG.md`: what changed in each version, so you can see what an upgrade brings before you take it.
- `RELEASING.md`: maintainer steps for publishing a new version safely.
- `HANDOFF.md`: notes for a maintainer resuming work, possibly on another machine: how to check the current state, the owner's working rules, and setup tips. You don't need it to use the guides.

## Guide versions

Each guide shows its version near the top, for example `**Guide version:** 1.1.0`. The version goes up whenever the guide changes, so you can tell whether two people are working from the same rules. Filenames never change, so links to a guide keep working.

To see what changed, read [CHANGELOG.md](CHANGELOG.md). To see an earlier version of a guide, check out a release tag or run `git log -- <guide>.md`. Maintainers publishing a new version should follow [RELEASING.md](RELEASING.md).

## Appendix: Acronyms and key terms

### Acronyms and abbreviations

| Acronym or abbreviation | Full form | Meaning in this document |
|---|---|---|
| AI | Artificial intelligence | Assistants that use the guides and prompts to write or review PowerShell. |
| CI | Continuous integration | Automated checks that GitHub Actions runs when changes are pushed or proposed. |
| ELK | Eclipse Layout Kernel | A diagram layout engine mentioned in the Mermaid source comments; this README uses dagre instead. |
| JSON | JavaScript Object Notation | The format used for the workflow's operating-system list, such as `["ubuntu-latest", "windows-latest"]`. |
| OS | Operating system | A platform on which checks run, such as Ubuntu or Windows; `os` is a workflow input. |
| SVG | Scalable Vector Graphics | A vector image format produced by diagram tools and handled by the audit tool's background helper. |
| TD | Top-down | The Mermaid direction setting that arranges a flowchart from top to bottom. |
| YAML | YAML Ain't Markup Language | The configuration format used by GitHub Actions workflows and the Mermaid configuration blocks. |

### Key terms

| Term | Plain-language definition | How it applies here |
|---|---|---|
| AI agent | An AI assistant that can read files and use tools to carry out a task. | Follows the guides, uses the review or creation prompt, and reports evidence from checks. |
| Array | An ordered collection of values. | The checker can flag arrays grown with `+=` inside loops, a pattern that can cause repeated copying. |
| Commit | A recorded set of changes in Git, identified by a unique identifier. | A release tag points to a commit so consumers can select a particular version of the guides and tools. |
| Consumer repository | Another project that uses shared material from this repository. | Copies the agent-instruction template and calls the reusable workflow at a pinned release. |
| Exit code | A number a process returns to indicate its result. | The guide checker returns `1` for errors or warnings and `0` when no failing findings remain. |
| Finding | A reported problem or item that needs review. | Includes a file location, severity, rule name, and explanation. |
| Git | A tool that records and tracks changes to files. | Keeps the repository's history and release tags and ignores local review scripts in `input/`. |
| GitHub Actions | GitHub's service for running automated workflows. | Runs the checker, Pester tests, and Mermaid unit tests on designated runners. |
| Job | A group of workflow steps executed on a runner. | The PowerShell checks run for each selected operating system; Mermaid unit tests have a separate Ubuntu job. |
| Linter / static analysis | A tool or method that examines code without executing it to find likely mistakes. | PSScriptAnalyzer checks PowerShell rules; it cannot prove that a script behaves correctly. |
| Mermaid | A text format for describing diagrams. | Draws the flowcharts that explain how the guides, prompts, checker, and workflows fit together. |
| Module | A package of PowerShell commands that can be installed and shared. | PSScriptAnalyzer and Pester are the modules required for analysis and testing. |
| Parser error | A syntax problem that prevents code from being read as a valid program. | The guide checker always reports PowerShell parser errors, regardless of the requested severities. |
| Pester | A testing framework for PowerShell. | Tests the checker and worked example here; consumers write their own Pester tests for their scripts. |
| Pinned version | A deliberately selected version rather than whichever version happens to be newest. | Release references and module versions keep checks consistent until an intentional upgrade. |
| PowerShell Gallery | A public repository of PowerShell modules and scripts. | Supplies the pinned PSScriptAnalyzer and Pester modules through the documented install commands. |
| Prompt | Instructions and task details given to an AI assistant. | The shared prompt supplies workflow rules; the review and creation prompts define the requested work. |
| PSScriptAnalyzer | A static-analysis module for PowerShell. | Supplies most automated rules, with repository settings controlling which rules apply. |
| Pull request | A proposed set of repository changes submitted for review. | Triggers CI so problems can be found before the changes are merged. |
| `pwsh` | The command used to start PowerShell 7. | Runs local commands and the separate processes used by the checker tests. |
| Release tag | A named Git reference identifying a published version. | Consumers use tags such as `v1.1.0`; this project's release policy forbids moving a published tag. |
| Repository | A project's files together with their recorded Git history. | Holds the guides, prompts, scripts, tests, and workflow configuration. |
| Repository root | The top-level folder of a repository. | The starting location for documented commands and the boundary for automatic settings discovery. |
| Reusable workflow | A GitHub Actions workflow that other workflows can call. | Lets this repository and consumers run the same PowerShell checker and optional Pester tests. |
| Runner | The machine or environment that executes a GitHub Actions job. | Provides the Ubuntu or Windows environment used for automated checks. |
| Scope | The context in which a variable name is used. | Array-append detection distinguishes script-level variables from variables in separate functions. |
| Severity | The importance assigned to a finding. | Errors and warnings fail the check; informational findings are review items that do not fail it. |
| Supplemental check | An additional check beyond the analyzer's rules. | The guide checker adds parser-error reporting and an array-append check. |
| Unit test | An automated test focused on a small part of a tool's behavior. | The Mermaid tests check the audit tool's source checks and SVG background helper without rendering diagrams. |
| `-WhatIf` | A PowerShell option that previews supported changes without making them. | The guides promote it for safe operations, and review diagrams help reveal paths that bypass its protection. |
| Workflow | A configuration describing automated jobs and when they run. | Files in `.github/workflows/` define this repository's CI and the checks consumers can reuse. |
