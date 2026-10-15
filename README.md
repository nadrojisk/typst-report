# report

Write reports in Markdown and produce a PDF with [Pandoc](https://pandoc.org/) and a native
[Typst](https://typst.app/) template. No LaTeX required.

Themed with **Pansy**, the OKLCH purple/green token set that skins daystrom (Forgejo) and the wiki, and drawn with the wiki favicon's snowflake.

## Requirements

- Pandoc 3.x
- Typst 0.15+ (a single static binary)
- Fonts: [Inter](https://rsms.me/inter/) and [JetBrains Mono](https://www.jetbrains.com/lp/mono/) are
  bundled in `fonts/` (SIL OFL), so output is the same on every machine. Override with `mainfont` /
  `codefont`. Builds from the repo root (`make`) and installed builds (`make install`, then `-d report`)
  find them automatically; to call pandoc some other way, add
  `--pdf-engine-opt=--font-path=/path/to/typst-report/fonts`.

The Docker image bundles all of it.

## Build

```bash
make                       # builds examples/*.pdf from this checkout
make install               # symlink the template + filters into ~/.local/share/pandoc
pandoc report.md -d report -o report.pdf
```

Or without installing:

```bash
pandoc report.md --defaults=report-defaults.yaml -o report.pdf
```

Docker:

```bash
make docker
docker run --rm -v "$PWD":/data -w /data typst-report input.md -o output.pdf
```

A prebuilt image is published to GHCR by `.github/workflows/image.yml` on every push to `main`
(tagged `latest`, the `VERSION` file's value, and the commit SHA) and on `v*` tags. Pull requests
build the image and render the example through it, but never push. The image is `linux/amd64`
only, since the Dockerfile downloads the x86_64 Typst binary.

```bash
docker run --rm -v "$PWD":/data -w /data ghcr.io/nadrojisk/typst-report:latest input.md -o output.pdf
```

## Front matter

```yaml
---
title: "Quiet Weather"
subtitle: "A field guide"
author: ["Jordan Sosnowski"]
date: "October 14, 2026"        # defaults to today; or pass --metadata commit-date=...
version: "0.1"
cover-style: flake              # see below
toc: true                       # also lof, lot, lol (figures / tables / listings)
numbersections: true
---
```

| Key | Effect |
| --- | --- |
| `cover-style` | One of the six covers below (default `flake`) |
| `no-cover` | Skip the cover; a compact title block opens the first page |
| `back-cover` | Add a closing page with the snowflake |
| `abstract`, `executive-summary`, `summary`, `acknowledgments` | Front-matter pages (roman numerals) |
| `acronyms`, `definitions` | Lists of `{abbr, term}` / `{term, definition}` |
| `primary-color`, `theme-color` | Accent color (hex, or a name from the palette) |
| `rule-color`, `table-rule-color`, `page-rule-color` | Rule colors; cascade down to `primary-color` |
| `rule-width`, `table-rule-width`, `page-rule-width` | Rule widths (default `1.25pt`) |
| `verbatim-color`, `verbatim-accent-color`, `verbatim-background-color`, `caption-color`, `linkcolor` | Code, caption and link colors |
| `mainfont`, `codefont`, `fontsize`, `papersize`, `columns`, `no-indent` | Typography and layout |

Named colors: `primary`, `primary-dark`, `primary-light`, `primary-mist`, `nav`, `night`, `green`,
`red`, `text`, `muted`, `surface`, `border`, `white`, `black`, plus every ramp step
(`purple-50` ... `purple-950`, `green-*`, `neutral-*`, `red-500`, `orange-500`).

The palette is the OKLCH token set (purple 285 / green 145 / neutral / error 25, all at matched
relative chroma) defined at the top of `report.typst`; edit the ramps there and everything follows.

## Covers

| `cover-style` | |
| --- | --- |
| `flake` | Deep indigo, one heavy snowflake bleeding off the lower right |
| `flake-light` | The same on off-white |
| `lattice` | Deep indigo, a lattice of tiny flakes fading toward the title |
| `lattice-light` | The same on off-white |
| `spine` | White page, indigo spine with a single mark and vertical metadata |
| `band` | Indigo header band with a ghosted flake, title on white below |

Rendered samples are in `previews/`.

## Markdown extras

All implemented by the Lua filters in `filters/` (loaded together through `filters/report.lua`).

- **Cross-references**: `@sec:name`, `@tbl:name`, `@fig:name`, `@lst:name`, `@d2:name`. Give the
  target the matching id, e.g. `# Intro {#sec:intro}` or `![Caption](img.png){#fig:cat}`.
- **Tables**: booktabs-style rules by default. Attributes on the caption line:
  `color=true` (filled header, zebra stripes), `cell-colorize=true` (tint and mark cells matching
  `green="Yes|OK" red="No"`; each gets a small shape so it reads in greyscale), `header-color`, `stripe-color`, `rule-color`, `landscape=true`, and `widths=source` (keep the
  column proportions from the markdown separator row, blended halfway toward equal widths, for
  tables with one long-text column).
- **Listings**: ` ```{#lst:id .python caption="Title"} ` gives a numbered, referenceable listing.
- **Figures**: `border-color=...`, `landscape=true` on the image.
- **Diagrams**: ` ```d2 ` blocks render with [D2](https://d2lang.com) natively, via the
  `@preview/tiago` Typst package (no `d2` binary; downloaded on first use, vendored in the Docker
  image). The default blue theme is recolored to the report palette. Add
  `{.d2 #d2:name caption="..."}` for a numbered, referenceable figure, and `engine="elk"` (or
  `dagre`, `railway`), `width=`, `height=` to tune it.
- **Callouts**: GitHub-style alerts (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`,
  `[!CAUTION]`) or fenced divs (`::: {.note title="Heads up"}`) become tinted boxes with a colored
  bar and label. Note uses the neutral ramp, tip the secondary green, important the primary purple, and
  warning an orange, and caution the error red. Each also has its own drawn glyph
  (circle "i", check, diamond, triangle, hexagon), so the type survives greyscale printing.
- **Appendices**: add `{.appendix}` to a level-1 heading; they're lettered A, B, ... with their own
  page numbering.
- **Landscape pages**: wrap content in `::: {.landscape}` ... `:::`.
- **Raw Typst**: ` ```{=typst} ` blocks can call the template's `snowflake(size, paint, thickness: ..)`
  and use the `report-*` colors.

## Layout

```
fonts/                    Bundled Inter and JetBrains Mono, with licenses
report.typst              Pandoc template (front matter -> Typst; covers, page style)
report-defaults.yaml      Pandoc defaults (template, filter, cross-ref prefixes)
filters/                  Lua filters; report.lua runs them all in order
examples/                 example.md (everything), nocover.md
previews/                 rendered covers
Dockerfile, Makefile
```

## License

The template, filters, build files and documentation are under the [MIT License](LICENSE).

Not covered by it:

- `fonts/`: Inter and JetBrains Mono, each under the SIL Open Font License (the licenses are in that folder).
- `examples/pixel-art.svg`: pixel art of a Nintendo character, included only to demonstrate SVG support. It is
  third-party artwork and is not licensed under this repository's license. Remove it if you reuse the examples.
