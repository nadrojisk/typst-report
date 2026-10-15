-- typst-figures.lua — Standardized attribute handling for image figures
--
-- Mirrors the attribute-passing conventions used by tables
-- (typst-table-colors.lua) and code listings/d2 diagrams (typst-listings.lua,
-- typst-d2.lua): a fenced/inline element can carry custom
-- attributes in its {...} attribute block, and this filter consumes the
-- ones it recognizes and converts them into Typst markup.
--
-- Pandoc represents a standalone captioned image as:
--   Figure(id, classes, kv-attrs)
--     Caption(...)
--     Plain[ Image(alt, classes, kv-attrs)[inlines](src, title) ]
-- Pandoc puts width/height/custom attrs on the inner Image node (not the
-- outer Figure), so that's where this filter reads/strips them.
--
-- Supported attributes:
--
--   landscape=true
--     Rotate the page to landscape for this one figure, same semantics as
--     tables' landscape=true. For multiple images/tables + surrounding
--     prose that all need to share one landscape page, use a
--     `::: {.landscape}` fenced div instead (see typst-landscape.lua)
--     rather than repeating this attribute on every element.
--
--   border-color=<name>
--     Draws a 1pt border around the image in the given named color
--     (see report.typst's report-named-colors table) or a hex string. Since
--     Typst's `image()` has no built-in stroke, this wraps the image in
--     `box(stroke: ...)` — requires regenerating the figure as a raw
--     Typst block (pandoc's default image(...) call has no hook for
--     custom color names).

local script_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local common = dofile(script_dir .. "/typst-common.lua")

local function find_image(inlines)
  for _, inline in ipairs(inlines) do
    if inline.t == "Image" then return inline end
  end
  return nil
end

function Figure(el)
  -- Locate the inner Image inline (pandoc wraps it in a Plain block).
  local image = nil
  for _, block in ipairs(el.content) do
    if block.t == "Plain" or block.t == "Para" then
      image = find_image(block.content)
      if image then break end
    end
  end
  if not image then return nil end

  local is_landscape = image.attributes["landscape"] == "true"
  local border_color = image.attributes["border-color"]

  if not is_landscape and not border_color then
    -- Nothing for us to do — let pandoc's default Figure/Image handling
    -- (and any width/height attrs already on the Image) pass through.
    return nil
  end

  -- Strip our custom attributes so pandoc's default image(...) writer
  -- (used for the non-border-color path) doesn't choke on unknown attrs.
  image.attributes["landscape"] = nil
  image.attributes["border-color"] = nil

  local result = el

  if border_color then
    -- Regenerate the figure as a raw Typst block: pandoc's default
    -- image(...) writer has no hook for a custom stroke color, so we
    -- build the #box(stroke: ...)[#image(...)] call ourselves.
    --
    -- Wrapped in #context because resolve-color("primarycolor", ...) reads
    -- theme-primary.get() (a state), which requires the call site to be
    -- inside a context — see report.typst's resolve-color()/theme-primary
    -- for why border-color=primarycolor can't be resolved to a literal
    -- here at pandoc-filter time (it must track the document's actual
    -- primary-color/theme-color override, same as table headers).
    local width = image.attributes["width"]
    local id = el.identifier
    local caption_str = common.escape_typst_caption(pandoc.utils.stringify(el.caption.long))
    local src = image.src
    local width_arg = width and string.format(", width: %s", width) or ""
    local typst_src = string.format(
      '#context [\n' ..
      '#figure(\n' ..
      '  box(stroke: 1pt + resolve-color("%s", black), inset: 4pt,\n' ..
      '    image("%s"%s)),\n' ..
      '  caption: [%s],\n' ..
      ')%s\n' ..
      ']',
      border_color, src, width_arg, caption_str,
      id ~= "" and (" <" .. id .. ">") or ""
    )
    result = pandoc.RawBlock("typst", typst_src)
  end

  if is_landscape then
    return {
      pandoc.RawBlock("typst", "#set page(flipped: true)"),
      result,
      pandoc.RawBlock("typst", "#set page(flipped: false)"),
    }
  end

  return result
end
