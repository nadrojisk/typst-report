-- typst-landscape.lua — Rotate a group of blocks to landscape via markdown
--
-- Wrap any block content (tables, prose, notes, images — anything) in a
-- fenced div with the `landscape` class to render that whole group on a
-- landscape-oriented page, without writing any raw Typst:
--
--   ::: {.landscape}
--   | A | B |
--   |---|---|
--   | 1 | 2 |
--
--   (a) A note that belongs with the table above, on the same
--       landscape page.
--   :::
--
-- This solves the problem where a single table's `landscape=true`
-- attribute (typst-table-colors.lua) only flips the page for that one
-- table — any table notes or other content written as a separate block
-- right after it would fall outside the flip and land on a new portrait
-- page. Wrapping both the table AND its notes in one `::: {.landscape}`
-- div keeps everything on the same landscape page.
--
-- Implementation: wraps the div's content between
-- `#set page(flipped: true)` / `#set page(flipped: false)` raw Typst
-- blocks. Each `#set page(...)` call forces a page break in Typst, so
-- content inside the div always starts on its own new landscape page and
-- resumes portrait immediately after — matching how `landscape=true`
-- already behaves for a single table.

function Div(el)
  if not el.classes:includes("landscape") then return nil end

  local result = { pandoc.RawBlock("typst", "#set page(flipped: true)") }
  for _, block in ipairs(el.content) do
    table.insert(result, block)
  end
  table.insert(result, pandoc.RawBlock("typst", "#set page(flipped: false)"))
  return result
end
