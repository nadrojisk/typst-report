-- typst-callouts.lua — Callout boxes: note, tip, important, warning, caution
--
-- Two equivalent ways to write one:
--
--   GitHub-style alert (needs pandoc's `alerts` extension, enabled by
--   report-defaults.yaml):
--     > [!WARNING]
--     > Urgent information.
--
--   Fenced div, with an optional title override:
--     ::: {.note title="Heads up"}
--     Useful information.
--     :::
--
-- Either becomes `#callout(kind, title)[...]`, defined in report.typst; the
-- box colors come from the palette there.

local script_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local common = dofile(script_dir .. "/typst-common.lua")

local KINDS = { "note", "tip", "important", "warning", "caution" }

local function kind_of(el)
  for _, k in ipairs(KINDS) do
    if el.classes:includes(k) then return k end
  end
end

function Div(el)
  local kind = kind_of(el)
  if not kind then return nil end

  local title = el.attributes["title"]
  local content = {}
  for _, block in ipairs(el.content) do
    -- pandoc's alerts extension puts the type name in a leading `.title` div
    if block.t == "Div" and block.classes:includes("title") then
      title = title or pandoc.utils.stringify(block)
    else
      content[#content + 1] = block
    end
  end
  title = title or (kind:sub(1, 1):upper() .. kind:sub(2))

  local result = {
    pandoc.RawBlock("typst", string.format(
      '#callout("%s", "%s")[', kind, common.escape_typst_caption(title))),
  }
  for _, block in ipairs(content) do result[#result + 1] = block end
  result[#result + 1] = pandoc.RawBlock("typst", "]")
  return result
end
