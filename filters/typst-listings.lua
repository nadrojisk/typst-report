-- typst-listings.lua — Convert captioned code blocks into Typst figures
--
-- Pandoc natively parses fenced code blocks like:
--   ```{#lst:hello .python caption="My caption"}
--   print("hi")
--   ```
-- into a CodeBlock with identifier "lst:hello", classes {"python"}, and
-- attribute caption="My caption" — no pandoc-crossref needed.
--
-- This filter converts any CodeBlock with an id starting "lst:" (see
-- typst-common.lua for the shared prefix constant) and a caption
-- attribute into a Typst figure with kind: "listing" so it:
--   • Gets proper "Listing N." caption formatting (numbered by Typst itself)
--   • Is referenceable via @lst:id → Typst native label/ref ("Listing N")
--   • Can appear in a List of Listings (lol: true)
--   • Still gets the report code block styling (accent bar, tinted background)
--     since the CodeBlock itself is preserved and styled by report.typst.

local script_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local common = dofile(script_dir .. "/typst-common.lua")

function CodeBlock(el)
  local id = el.identifier
  if not id or not id:match("^" .. common.PREFIX.LISTING) then return nil end

  local caption_str = el.attributes["caption"]
  if not caption_str then return nil end

  -- Escape quotes/backslashes for the Typst string literal in caption: [...]
  caption_str = common.escape_typst_caption(caption_str)

  -- Drop the caption attribute and identifier from the CodeBlock itself so
  -- they don't leak into the Typst raw() call, but keep the label for the
  -- figure wrapper below.
  el.attributes["caption"] = nil
  el.identifier = ""

  local before = pandoc.RawBlock("typst", string.format(
    '#figure(caption: [%s], kind: "listing", {', caption_str))
  local after = pandoc.RawBlock("typst", string.format('}) <%s>', id))

  return { before, el, after }
end
