---
title: "Quiet Weather"
subtitle: "A field guide to the report template"
author:
  - "Jordan Sosnowski"
date: "October 14, 2026"
version: "0.1"
toc: true
lof: true
lot: true
numbersections: true
abstract: |
  A short abstract. It lives in the roman-numeral front matter, after the cover.
acronyms:
  - { abbr: "PDF", term: "Portable Document Format" }
  - { abbr: "CSS", term: "Cascading Style Sheets" }
---

# Introduction {#sec:intro}

This template borrows its palette from the Pansy theme that skins daystrom: a deep
indigo navbar, a purple accent, and a restrained green. See @sec:tables for tables and
@fig:cat for a figure.

Inline `code` picks up the surface tint. A second paragraph follows, indented the
way a book would, with a [link](https://example.com) in the accent color.

> A block quote gets a quiet accent bar rather than a box.

## Callouts {#sec:callouts}

> [!NOTE]
> Useful information that readers should know, even when skimming.

> [!TIP]
> Optional advice that makes things easier.

> [!IMPORTANT]
> Crucial information necessary for success.

::: {.warning title="Heads up"}
Fenced divs work too, with an optional **title**, and can hold lists:

- anything block-level
- including code
:::

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.

## Lists

- First item
- Second item
  - Nested item
- Third item

1. One
2. Two
3. Three

## Code {#sec:code}

```python {#lst:hello caption="A captioned listing"}
def greet(name: str) -> str:
    return f"hello, {name}"
```

# Tables {#sec:tables}

| Service   | Status   | Owner    |
|-----------|----------|----------|
| daystrom  | Up       | Jordan   |
| wiki      | Up       | Jordan   |
| spare     | Down     | —        |

: Plain booktabs-style table {#tbl:plain}

| Service   | Status   | Owner    |
|-----------|----------|----------|
| daystrom  | Yes      | Jordan   |
| wiki      | Yes      | Jordan   |
| spare     | No       | —        |

: Header fill, zebra stripes, tinted cells {#tbl:color color=true cell-colorize=true}

# Figures

![A tuxedo cat mid-blep](cat.jpg){#fig:cat width=50%}

# Diagrams {#sec:diagrams}

Diagrams are written in [D2](https://d2lang.com) and drawn in the report palette (@d2:flow).

```{.d2 #d2:flow caption="Request path" engine="elk"}
direction: right
client -> traefik: HTTPS
traefik -> daystrom
traefik -> wiki
daystrom -> db
wiki -> db
traefik: Traefik { style.fill: "#624ad3"; style.font-color: "#ffffff" }
db: Postgres { shape: cylinder }
```

Raw Typst works too — for example a small snowflake:

```{=typst}
#align(center, snowflake(0.9in, report-primary, thickness: 1pt))
```

# Notes {.appendix}

Appendices are lettered and restart page numbering.

# More notes {.appendix}

A second appendix.
