-- typst-common.lua — Shared helpers for the Report Typst filter set
--
-- Standardizes two things across filters/typst-{table-colors,listings,d2}.lua
-- and report.typst's image/figure handling:
--
--   1. Cross-reference ID prefixes — every referenceable element (table,
--      figure, listing, d2 diagram, section) uses a consistent
--      "kind:name" identifier scheme, e.g. #tbl:sales, #fig:sunset,
--      #lst:hello, #d2:flow, #sec:intro. typst-secref.lua resolves all of
--      these to native Typst refs/links.
--
--   2. Typst string-literal escaping — any user-supplied text (captions,
--      code source, attribute values) that gets spliced into a Typst
--      string literal (double-quoted "...") must escape backslashes and
--      double quotes at minimum; escape_typst_string() additionally
--      normalizes line endings and escapes newlines for callers (like
--      d2 diagrams) that need the value to survive as a single-line string.
--
-- Returned as a plain table (not a filter with its own top-level hooks) so
-- other filters can `local common = dofile(dir .. "/typst-common.lua")` and
-- call these functions directly.

local M = {}

-- ---- Cross-reference ID prefixes ------------------------------------------
-- Keep in sync with typst-secref.lua's recognized prefixes and with
-- report-defaults.yaml's tblPrefix/figPrefix/secPrefix/lstPrefix keys.
M.PREFIX = {
  SECTION = "sec:",
  TABLE   = "tbl:",
  FIGURE  = "fig:",
  LISTING = "lst:",
  DIAGRAM = "d2:",
}

-- Returns true if `id` starts with any of the recognized reference prefixes.
function M.has_known_prefix(id)
  if not id then return false end
  for _, prefix in pairs(M.PREFIX) do
    if id:match("^" .. prefix) then return true end
  end
  return false
end

-- ---- Typst string-literal escaping ----------------------------------------
-- Minimal escaping for text embedded in a Typst string literal via markup
-- context, e.g. `caption: [#raw_text]` or `caption: "text"`. Escapes
-- backslashes and double quotes only — safe for single-line captions.
function M.escape_typst_caption(s)
  if not s then return s end
  return s:gsub("\\", "\\\\"):gsub('"', '\\"')
end

-- Fuller escaping for multi-line source text embedded as a single-line
-- Typst string literal (e.g. d2 diagram source passed to a function
-- call as `d2-diagram("...")`). Also normalizes CRLF and escapes newlines.
function M.escape_typst_string(s)
  if not s then return s end
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\r\n", "\n")
  s = s:gsub("\n", "\\n")
  return s
end

return M
