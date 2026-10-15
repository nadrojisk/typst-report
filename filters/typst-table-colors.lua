-- typst-table-colors.lua — Native Typst table coloring
--
-- Native Typst table coloring: clean Typst
-- attribute injection via pandoc's typst:prop mechanism (pandoc 3.1.8+).
--
-- Supported table attributes (pandoc typst:prop attributes):
--
--   color=true
--     Color the header row in primary color (default: the theme primary),
--     white header text, and zebra-stripe body rows in the surface tint.
--
--   cell-colorize=true
--     Content-based per-cell coloring (implies color=true for the header).
--     Cells matching green/red/yellow terms get pastel tint fills.
--
--   header-color=<name>    (default: primarycolor)
--   header-text-color=<name>  (default: white)
--   stripe-color=<name>    (default: surface)
--
--   green="Yes|Approved"   pipe-separated exact-match terms → green fill
--   red="No|Blocked"       pipe-separated exact-match terms → red fill
--   yellow="Yes|No"        pipe-separated substring-match terms → yellow fill
--
-- Implementation strategy:
--   Typst's table(fill: (x, y) => ...) function receives column (x) and
--   row (y) indices. We set this as a typst:fill attribute on the table
--   so pandoc emits it as a parameter to the #table() call.
--
--   For cell-colorize, per-cell content is not available at the Typst
--   fill-function level, so we set typst:fill on each individual
--   table.cell element instead, overriding the row-level fill.
--
--   Column widths: Typst's `columns: auto` gives natural widths (no
--   stretching). For wide tables we use `1fr` per column (equal share,
--   fills page width)..

-- ---- Color name → Typst color expression ------------------------------------
-- Resolves a named color (or hex string) to a Typst color expression.
--
-- Does NOT maintain its own hardcoded hex table — that used to duplicate
-- report.typst's report-named-colors table, and the two silently drifted apart
-- once (see the "primarycolor" theme-color bug fixed earlier). Instead this
-- defers to report.typst's own resolve-color(name, fallback) function at
-- Typst render time, so there is exactly one source of truth for every
-- named color.
--
-- "primarycolor" is a special case: it must resolve to whatever
-- primary-color/theme-color the document actually set (via report.typst's
-- theme-primary state), not a value baked in at pandoc-filter time —
-- otherwise every color=true table (and any header-color=primarycolor)
-- would always render the literal default accent regardless of the document's theme.
-- resolve-color() itself already special-cases "primarycolor" the same
-- way, but we still need PRIMARY_PLACEHOLDER for the `rule_color` case
-- below (a bare identifier substitution, not a function call).
local PRIMARY_PLACEHOLDER = "__report_theme_primary__"

-- Table rule color placeholder — resolves to theme-table-rule.get() at
-- Typst render time (see report.typst's theme-table-rule state), which
-- itself already cascaded through table-rule-color/rule-color/
-- primary-color/theme-color in conf(). Used for every table's stroke
-- (plain and color=true alike), so ALL tables must be wrapped in the
-- #context block below — not just wants_color ones — for this
-- placeholder to resolve.
local TABLE_RULE_PLACEHOLDER = "__report_theme_table_rule__"

-- Bare Typst color keywords that don't need a resolve-color() lookup.
local CSS_KEYWORDS = {
  white = true, black = true, red = true,
  blue = true, green = true, yellow = true,
}

local function typst_color(name)
  if not name then return nil end
  if name == "primarycolor" then return PRIMARY_PLACEHOLDER end
  if CSS_KEYWORDS[name] then return name end
  -- Hex string passthrough
  if name:match("^#?%x%x%x%x%x%x$") then
    local hex = name:match("^#") and name or ("#" .. name)
    return 'rgb("' .. hex .. '")'
  end
  -- Any other name: defer to report.typst's
  -- resolve-color(), which looks it up in report-named-colors at Typst
  -- render time — the single source of truth for the whole palette.
  return string.format('resolve-color("%s", black)', name)
end

-- Pastel cell-colorize fills (35% tint). Reference report.typst's own color
-- variables by name (not hex literals) so these track the single source
-- of truth palette too.
local CELL_COLOR_GREEN  = 'color.mix((report-green, 35%), (white, 65%))'
local CELL_COLOR_RED    = 'color.mix((report-red, 35%), (white, 65%))'
local CELL_COLOR_YELLOW = 'color.mix((yellow, 35%), (white, 65%))'

-- ---- Parse pipe-separated terms -------------------------------------------
local function parse_terms(s)
  local terms = {}
  for t in s:gmatch("[^|]+") do
    local trimmed = t:match("^%s*(.-)%s*$")
    if trimmed ~= "" then table.insert(terms, trimmed:lower()) end
  end
  return terms
end

-- ---- Cell text extraction --------------------------------------------------
local function cell_text(cell)
  local text = ""
  for _, block in ipairs(cell.contents) do
    text = text .. pandoc.utils.stringify(block)
  end
  return text:match("^%s*(.-)%s*$")
end

-- ---- Determine cell-colorize fill for a cell's content --------------------
-- Returns the fill and the cell-mark kind (report.typst) for a cell's content. The mark
-- is a small shape drawn before the text so the status survives greyscale printing.
local function cell_colorize_fill(text, green_terms, red_terms, yellow_terms)
  local lower = text:lower()
  for _, t in ipairs(green_terms) do
    if lower == t then return CELL_COLOR_GREEN, "tip" end
  end
  for _, t in ipairs(red_terms) do
    if lower == t then return CELL_COLOR_RED, "caution" end
  end
  for _, t in ipairs(yellow_terms) do
    if lower:find(t, 1, true) then return CELL_COLOR_YELLOW, "warning" end
  end
  return nil
end

-- ---- Main Table filter ----------------------------------------------------
function Table(el)
  -- Force every column to Typst auto-sizing (columns: N) instead of
  -- pandoc's computed percentage widths. Pandoc derives ColWidth from the
  -- ratio of dashes in each column's markdown separator row (e.g.
  -- `| --------- |`) once the row exceeds ~80 chars total — a purely
  -- cosmetic detail that markdown formatters/editors routinely rewrite to
  -- the minimum width needed for the header text (many editors "tidy"
  -- tables to use exactly enough dashes/spaces to fit the content). That
  -- silently starves narrow-but-real-word headers like "Ownership" of any
  -- padding, so the rendered text overflows into the next column. Typst's
  -- own auto-sizing measures actual rendered text width and always gives
  -- every column enough room, independent of how the source table happens
  -- to be formatted.
  -- Opt-in `widths=source`: keep the column proportions the markdown source expresses (pandoc
  -- derives them from the dash counts of the separator row once a row exceeds the line width),
  -- blended halfway toward equal widths so a narrow column is never crushed. Without it, or when
  -- pandoc computed no widths, every column is auto-sized as described above.
  local source_widths = el.attributes["widths"] == "source"
  el.attributes["widths"] = nil
  local blended = nil
  if source_widths then
    local n = #el.colspecs
    local all_numeric = n > 0
    for _, spec in ipairs(el.colspecs) do
      if type(spec[2]) ~= "number" then all_numeric = false end
    end
    if all_numeric then
      blended = {}
      for i, spec in ipairs(el.colspecs) do
        blended[i] = 0.5 * spec[2] + 0.5 * (1 / n)
      end
    end
  end
  for i, spec in ipairs(el.colspecs) do
    el.colspecs[i] = {spec[1], blended and blended[i] or pandoc.ColWidthDefault}
  end

  -- Fix alignment: pandoc emits align: (auto,auto,...) per column which
  -- overrides the global set table(align: left). Rewrite AlignDefault
  -- columns to AlignLeft so Typst renders left-aligned text in all cells
  -- unless the author explicitly set a different alignment in the markdown.
  for i, spec in ipairs(el.colspecs) do
    if spec[1] == pandoc.AlignDefault then
      el.colspecs[i] = {pandoc.AlignLeft, spec[2]}
    end
  end

  -- Booktabs-style rules: top rule, midrule after header, bottom rule.
  -- Count rows so we can place table.hline(y: N) for the bottom rule.
  local header_rows = #el.head.rows
  local body_rows = 0
  for _, body in ipairs(el.bodies) do
    body_rows = body_rows + #body.body
  end
  local total_rows = header_rows + body_rows

  local is_colored      = el.attributes["color"]         == "true"
  local is_cell_colored = el.attributes["cell-colorize"] == "true"
  local wants_color     = is_colored or is_cell_colored

  -- Rule color cascade (most specific wins): this table's own rule-color
  -- attribute → the document's resolved table-rule color (theme-table-rule
  -- state, itself already cascaded through table-rule-color/rule-color/
  -- primary-color/theme-color in conf()). No more hardcoded 'black' for
  -- plain tables — every table (colored or not) now tracks the document's
  -- resolved table-rule color unless it sets its own rule-color attribute.
  local rule_color_attr = el.attributes["rule-color"]
  local rule_color = rule_color_attr and typst_color(rule_color_attr) or TABLE_RULE_PLACEHOLDER
  el.attributes["rule-color"] = nil

  -- Stroke function handles all three rules within the table boundary (no bleed):
  -- top rule (top of header), midrule (bottom of header = top of first body row),
  -- bottom rule (bottom of last row). All constrained to table width.
  -- Build stroke function. When header_rows == total_rows - 1 (single body row),
  -- the midrule and bottom rule fall on the same y — combine them.
  local last_row = total_rows - 1
  local stroke_fn
  if header_rows == last_row then
    -- Single body row: combine midrule + bottom rule on same y
    stroke_fn = string.format(
      "(_, y) => if y == 0 { (top: report-rule-width + %s, bottom: report-rule-width + %s) } " ..
      "else if y == %d { (top: report-rule-width + %s, bottom: report-rule-width + %s) } else { (:) }",
      rule_color, rule_color,
      header_rows, rule_color, rule_color
    )
  else
    stroke_fn = string.format(
      "(_, y) => if y == 0 { (top: report-rule-width + %s, bottom: report-rule-width + %s) } " ..
      "else if y == %d { (top: report-rule-width + %s) } " ..
      "else if y == %d { (bottom: report-rule-width + %s) } else { (:) }",
      rule_color, rule_color,
      header_rows, rule_color,
      last_row, rule_color
    )
  end
  el.attributes["typst:stroke"] = stroke_fn

  -- Remove header cell inset override — use global table inset
  if #el.head.rows > 0 then
    for _, row in ipairs(el.head.rows) do
      for i, cell in ipairs(row.cells) do
        cell.attributes = cell.attributes or {}
        cell.attributes["typst:inset"] = nil
        row.cells[i] = cell
      end
    end
  end

  -- ---- color=true / cell-colorize: header fill + zebra stripes ------------
  if wants_color then
    -- Resolve colors. header-color defaults to the theme's primary color
    -- (not a hardcoded color literal) so color=true tables respect any
    -- primary-color/theme-color override, matching section headings.
    -- typst_color() always returns a usable Typst expression now (it falls
    -- through to resolve-color(name, black) for anything unrecognized), so
    -- no `or <literal>` fallback is needed here.
    local hdr_color  = typst_color(el.attributes["header-color"] or "primarycolor")
    local hdr_text   = typst_color(el.attributes["header-text-color"] or "white")
    local stripe_col = typst_color(el.attributes["stripe-color"]      or "surface")

    -- ---- Build the Typst fill function expression -------------------------
    --
    -- For color=true (no cell-colorize):
    --   (x, y) => if y == 0 { hdr_color } else if calc.odd(y) { stripe_col } else { none }
    --
    -- For cell-colorize=true:
    --   We still set the row-level fill the same way, then override per-cell
    --   via table.cell(fill: ...) attributes set on individual cells below.

    local fill_fn = string.format(
      "(x, y) => if y == 0 { %s } else if calc.odd(y) { %s } else { none }",
      hdr_color, stripe_col
    )
    el.attributes["typst:fill"] = fill_fn

    -- Header text color: wrap header cells in a text() call via typst:text:fill
    -- on each header cell. We use typst:text:fill on every header cell.
    for _, row in ipairs(el.head.rows) do
      for i, cell in ipairs(row.cells) do
        cell.attributes = cell.attributes or {}
        cell.attributes["typst:text:fill"]   = hdr_text
        cell.attributes["typst:text:weight"] = '"bold"'
        cell.attributes["typst:align"]       = "left"
        -- Pull header fill upward by half stroke width to cover top rule bleed
        cell.attributes["typst:inset"] = "(top: 9pt - report-rule-width / 2, bottom: 9pt, x: 6pt)"
        row.cells[i] = cell
      end
    end

    -- ---- Cell-colorize: set fill on individual body cells -----------------
    if is_cell_colored then
      local green_terms  = parse_terms(el.attributes["green"]  or "Yes")
      local red_terms    = parse_terms(el.attributes["red"]    or "No")
      local yellow_terms = parse_terms(el.attributes["yellow"] or "Yes|No")

      for _, body in ipairs(el.bodies) do
        for row_idx, row in ipairs(body.body) do
          for i, cell in ipairs(row.cells) do
            local text = cell_text(cell)
            local fill, mark = cell_colorize_fill(text, green_terms, red_terms, yellow_terms)
            if fill then
              cell.attributes = cell.attributes or {}
              cell.attributes["typst:fill"] = fill
              local first = cell.contents[1]
              if first and (first.t == "Plain" or first.t == "Para") then
                first.content:insert(1, pandoc.RawInline("typst",
                  string.format('#cell-mark("%s")#h(4pt)', mark)))
              end
              row.cells[i] = cell
            end
          end
        end
      end
    end
  end

  -- Remove our custom attributes so they don't leak into the output
  el.attributes["color"]         = nil
  el.attributes["cell-colorize"] = nil
  el.attributes["header-color"]  = nil
  el.attributes["header-text-color"] = nil
  el.attributes["stripe-color"]  = nil
  el.attributes["green"]         = nil
  el.attributes["red"]           = nil
  el.attributes["yellow"]        = nil

  -- Landscape: wrap the table in a flipped page context
  local is_landscape = el.attributes["landscape"] == "true"
  el.attributes["landscape"] = nil

  -- Every table's table.hline() calls (used inside table content, e.g.
  -- `table.hline(),` after the header row) must use this table's own
  -- resolved rule color, not whatever #set table.hline is currently in
  -- scope from conf()'s global default or a sibling table's override.
  -- rule_color may itself be TABLE_RULE_PLACEHOLDER, which must resolve
  -- to the bare `table-rule` identifier (not a string literal) BEFORE
  -- being embedded in this raw Typst block — unlike typst:stroke/
  -- typst:fill (pandoc attribute strings, substituted further below),
  -- this text is emitted verbatim with no second substitution pass.
  local hline_color = rule_color:gsub(TABLE_RULE_PLACEHOLDER, "table-rule")
  local hline_set = pandoc.RawBlock("typst",
    string.format('#set table.hline(stroke: report-rule-width + %s)', hline_color))
  local hline_restore = pandoc.RawBlock("typst",
    '#set table.hline(stroke: report-rule-width + table-rule)')

  local result
  if is_landscape then
    result = {
      pandoc.RawBlock("typst", '#set page(flipped: true)'),
      hline_set,
      el,
      hline_restore,
      pandoc.RawBlock("typst", '#set page(flipped: false)'),
    }
  else
    result = { hline_set, el, hline_restore }
  end

  -- Every table (plain or color=true) builds typst:stroke using
  -- TABLE_RULE_PLACEHOLDER (and typst:fill using PRIMARY_PLACEHOLDER, for
  -- wants_color tables) as literal strings — plus hline_set/hline_restore
  -- above, which reference bare `table-rule` identifiers. Wrap the whole
  -- table+hline output in one #context block that resolves the document's
  -- actual theme-primary/theme-table-rule state into local variables at
  -- Typst render time — this is what makes rule colors (and
  -- header-color=primarycolor) respect primary-color/theme-color/
  -- rule-color/table-rule-color overrides instead of always rendering
  -- the literal default accent/black.
  if el.attributes["typst:stroke"] then
    el.attributes["typst:stroke"] = el.attributes["typst:stroke"]
      :gsub(PRIMARY_PLACEHOLDER, "primary")
      :gsub(TABLE_RULE_PLACEHOLDER, "table-rule")
  end
  if el.attributes["typst:fill"] then
    el.attributes["typst:fill"] = el.attributes["typst:fill"]:gsub(PRIMARY_PLACEHOLDER, "primary")
  end

  local final = {
    pandoc.RawBlock("typst", "#context ["),
    pandoc.RawBlock("typst", "#let primary = theme-primary.get()"),
    pandoc.RawBlock("typst", "#let table-rule = theme-table-rule.get()"),
  }
  for _, item in ipairs(result) do
    table.insert(final, item)
  end
  table.insert(final, pandoc.RawBlock("typst", "]"))
  return final
end
