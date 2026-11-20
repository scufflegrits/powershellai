# Mermaid audit scripts

Tools that support the [Mermaid conventions](../mermaid-best-practices.md). They are
optional: nothing in this repository's CI runs them, and the conventions can be
followed with `mmdc` alone.

| File | Purpose |
| --- | --- |
| `audit_mermaid.py` | Audits every Mermaid block in one or more Markdown files: YAML front matter, Mermaid's parser, an offline render in Chromium, source lint, `themeCSS` and class-style checks, text contrast on light and dark hosts, and unrecognized settings. Writes `audit.md`, `audit.json`, and per-block SVG/PNG files. With `--engines`, also renders dagre and ELK copies and records which layout modules loaded. |
| `mermaid_audit_browser.js` | Browser-side checks that `audit_mermaid.py` loads. Not run on its own. |
| `opaque_svg.py` | Adds a background rectangle, sized to the `viewBox`, behind an exported SVG so it stays opaque on any page. The diagram itself is unchanged. |
| `test_mermaid_audit.py` | Unit tests for the audit's source checks and for `opaque_svg.py`. No browser needed. |
| `fixtures/` | Probe diagrams with known results, used to check that the audit still detects problems (see below). |

## Requirements

- Python 3.9 or later (verified with 3.13) with PyYAML and Playwright, plus Playwright's Chromium:

  ```bash
  python -m pip install pyyaml playwright
  python -m playwright install chromium
  ```

- A local Mermaid build. The audit loads it from disk and blocks all network
  requests. Either install `mermaid` with npm, or use the copy bundled with
  `@mermaid-js/mermaid-cli`:

  ```bash
  MERMAID_DIST="$(npm root -g)/@mermaid-js/mermaid-cli/node_modules/mermaid/dist"
  ```

The unit tests need only PyYAML.

## Usage

Run from the repository root. Use a separate output folder, outside the repository.

```bash
# Audit this repository's diagrams, including dagre and ELK copies.
python -B reference/scripts/audit_mermaid.py README.md RELEASING.md \
  --mermaid-dist "$MERMAID_DIST" --output /tmp/mermaid-audit --engines

# Make an exported SVG opaque.
python -B reference/scripts/opaque_svg.py diagram.svg --output diagram-opaque.svg --color white

# Unit tests.
cd reference/scripts && python -B -m unittest test_mermaid_audit
```

Add `--no-sandbox` to the audit only if Chromium cannot start otherwise, for example
as root in a container. `--browser-executable` selects a different Chromium.

The audit exits 1 if any block fails parsing, rendering, lint, or a CSS check. It
records visual review, GitHub, and VS Code previews as **NOT TESTED**: open the PNGs
yourself before calling a diagram correct.

## Fixtures and expected results

Run the audit on `fixtures/*.md` after changing the scripts or upgrading Mermaid. If
these results change, the audit or Mermaid's behavior has changed.

| Fixture | Expected result |
| --- | --- |
| `class-colors.md` | All checks pass: named and hex `classDef` colors apply. |
| `css-layout-helper.md` | All checks pass: every `themeCSS` rule is kept and applies. |
| `color-probes.md` | Lint fails for the `named` and `unquoted` blocks; the other three pass. |
| `root-probes.md` | CSS checks fail for all three blocks. This is the expected result: `svg`, `:root`, and `&` selectors in `themeCSS` do not paint the root background (see the conventions' "What paints the background"). |

Last verified on 2026-11-20 with Python 3.13, Mermaid 12.2.0, Playwright 1.64.0, and Chromium 156.
