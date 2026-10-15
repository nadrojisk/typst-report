-- typst-d2.lua — Render fenced ```d2 code blocks natively in Typst
--
-- Uses the `tiago` Typst package (the Diago D2 engine compiled to WASM), so no
-- `d2` binary is needed. Typst downloads the package on first use; the Docker
-- image vendors it so builds need no network access. The import and helper are
-- only injected into documents that actually contain a d2 block, so every other
-- document builds fully offline.
--
-- Usage in markdown:
--   ```d2
--   direction: right
--   client -> server: HTTPS
--   ```
--
-- With a caption/label, wrap it as a numbered figure. Use the #d2:name ID
-- prefix (not #fig:) — diagrams get their own cross-reference namespace
-- (typst-common.lua / typst-secref.lua), though they render with kind: image
-- so they still appear in the List of Figures alongside regular images:
--   ```{.d2 #d2:flow caption="My flow"}
--   a -> b
--   ```
--
-- Attributes (values are inserted verbatim as Typst code, so use Typst syntax):
--   width="60%"  height="4cm"   size the diagram; by default it keeps its natural
--                               size, shrinking only if wider than the text column
--   engine="elk" layout engine: dagre (default), elk, or railway
--
-- D2's default blue theme is recolored to the report palette (following the
-- document's primary-color); an explicit style in the diagram source — e.g.
-- `a.style.fill: "#fff"` — still takes effect for fills that D2 emits inline.

local script_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local common = dofile(script_dir .. "/typst-common.lua")

local SIZE_PATTERN = "^%d+%.?%d*%%?$"          -- 60%, 4.5, 100
local LENGTH_PATTERN = "^%d+%.?%d*%a+$"        -- 4cm, 300pt, 2in, 1.5em
local ENGINES = { dagre = true, elk = true, railway = true }

local function is_valid_size(v)
  return v:match(SIZE_PATTERN) or v:match(LENGTH_PATTERN)
end

-- Builds the extra `d2-diagram(...)` arguments from width/height/engine.
local function build_args(attrs)
  local args = {}
  for _, key in ipairs({ "width", "height" }) do
    local v = attrs[key]
    if v then
      if is_valid_size(v) then
        args[#args + 1] = string.format("%s: %s", key, v)
      else
        io.stderr:write(string.format(
          "typst-d2.lua: ignoring invalid %s value %q (expected e.g. 60%%, 4cm)\n", key, v))
      end
    end
  end
  local engine = attrs["engine"]
  if engine then
    if ENGINES[engine] then
      args[#args + 1] = string.format('engine: "%s"', engine)
    else
      io.stderr:write(string.format(
        "typst-d2.lua: ignoring unknown engine %q (expected dagre, elk or railway)\n", engine))
    end
  end
  return table.concat(args, ", ")
end

local uses_d2 = false

function CodeBlock(el)
  if not el.classes:includes("d2") then return nil end
  uses_d2 = true

  local src = common.escape_typst_string(el.text)
  local id = el.identifier
  local caption_str = el.attributes["caption"]
  local extra = build_args(el.attributes)
  local call = string.format('d2-diagram("%s"%s)', src, extra ~= "" and (", " .. extra) or "")

  if caption_str and id ~= "" then
    caption_str = common.escape_typst_caption(caption_str)
    return pandoc.RawBlock("typst", string.format(
      '#figure(caption: [%s], kind: image, %s) <%s>', caption_str, call, id))
  end
  return pandoc.RawBlock("typst", "#" .. call)
end

-- The helper recolors D2's default theme (a fixed set of hex colors in the SVG)
-- to the report palette. It runs in a #context so it follows primary-color, and
-- reads the palette from report.typst so the two cannot drift apart.
local HELPER = [[
#import "@preview/tiago:0.1.0": render-svg
#let d2-diagram(source, engine: none, width: auto, height: auto) = context {
  let primary = theme-primary.get()
  let map = (
    "#0D32B2": primary.to-hex(),                      // strokes, links
    "#4A6FF3": report-primary-light.to-hex(),
    "#E3E9FD": report-primary-mist.to-hex(),          // fills
    "#EDF0FD": color.mix((primary, 8%), (white, 92%)).to-hex(),
    "#F7F8FE": report-surface.to-hex(),
    "#0A0F25": report-text.to-hex(),                  // text
    "#676C7E": report-muted.to-hex(),
    "#9499AB": report-muted.to-hex(),
    "#CFD2DD": report-border.to-hex(),
    "#DEE1EB": report-border.to-hex(),
    "#EEF1F8": report-surface.to-hex(),
  )
  let svg = str(render-svg(source, engine: engine))
  for (from, to) in map { svg = svg.replace(from, to).replace(lower(from), to) }
  let data = bytes(svg)
  align(center, layout(size => {
    let natural = image(data, format: "svg")
    if width == auto and height == auto {
      if measure(natural).width > size.width { image(data, format: "svg", width: 100%) } else { natural }
    } else {
      image(data, format: "svg", width: width, height: height)
    }
  }))
}
]]

function Pandoc(doc)
  if uses_d2 then
    table.insert(doc.blocks, 1, pandoc.RawBlock("typst", HELPER))
    return doc
  end
end
