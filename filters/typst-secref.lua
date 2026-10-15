-- typst-secref.lua — cross-references for Typst output
--
-- Handles @sec:, @tbl:, @fig:, @lst:, and @d2: cite nodes, rewriting them
-- to native Typst #ref(<label>) calls. This replaces pandoc-crossref
-- entirely for the Typst backend — Typst resolves labels natively in a
-- single pass. Prefixes are defined once in typst-common.lua so every
-- filter and this file agree on the same "kind:name" ID scheme.
--
-- @sec: refs display the heading text as link text.
-- @tbl:, @fig:, @lst:, @d2: refs are passed to #ref() which Typst renders
-- as "Table 1", "Figure 2", "Listing 3", "Figure 4" etc. using its own
-- counter (d2 diagrams render as kind: image, so they share the
-- Figure counter/supplement with regular images).

local script_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local common = dofile(script_dir .. "/typst-common.lua")

local function slugify(inlines)
  local text = pandoc.utils.stringify(inlines)
  text = text:lower()
  text = text:gsub("[%s%p]+", "-")
  text = text:gsub("[^%a%d%-]", "")
  text = text:gsub("^%-+", ""):gsub("%-+$", "")
  text = text:gsub("%-%-+", "-")
  return common.PREFIX.SECTION .. text
end

local sec_ids      = {}
local sec_labels   = {}
local sec_headings = {}
local slug_counts  = {}

local function collect_header_ids(blocks)
  pandoc.walk_block(pandoc.Div(blocks), {
    Header = function(el)
      local id
      if el.identifier and el.identifier:match("^" .. common.PREFIX.SECTION) then
        id = el.identifier
      else
        id = slugify(el.content)
      end
      if sec_labels[id] then
        slug_counts[id] = (slug_counts[id] or 1) + 1
        id = id .. "-" .. slug_counts[id]
      else
        slug_counts[id] = 1
      end
      sec_ids[el.identifier ~= "" and el.identifier or id] = id
      sec_labels[id] = true
      sec_headings[id] = pandoc.utils.stringify(el.content)
    end
  })
end

local function rewrite_header(el)
  local slug    = slugify(el.content)
  local sec_id  = sec_ids[el.identifier ~= "" and el.identifier or slug] or slug
  el.identifier = sec_id
  -- Inject a pagebreak before every level-1 body heading.
  -- Done here in the filter (not in the Typst show rule) so the pagebreak is a
  -- top-level block element and is never inside a container context.
  if el.level == 1 then
    return {
      pandoc.RawBlock("typst", "#pagebreak(weak: true)"),
      el,
    }
  end
  return el
end

local function replace_cite(el)
  if el.t ~= "Cite" then return end
  local cites = el.citations
  if #cites ~= 1 then return end
  local id = cites[1].id

  if id:match("^" .. common.PREFIX.SECTION) then
    -- Section reference: display heading text as link
    local text = sec_headings[id] or id:gsub("^" .. common.PREFIX.SECTION, ""):gsub("-", " ")
    text = text:gsub("^%l", string.upper)
    return pandoc.RawInline("typst", "#link(<" .. id .. ">)[" .. text .. "]")
  elseif id:match("^" .. common.PREFIX.TABLE) or id:match("^" .. common.PREFIX.FIGURE)
      or id:match("^" .. common.PREFIX.LISTING) or id:match("^" .. common.PREFIX.DIAGRAM) then
    -- Table/figure/listing/diagram reference: let Typst render
    -- "Table N" / "Figure N" / "Listing N" via its own counter+supplement.
    return pandoc.RawInline("typst", "@" .. id)
  end
end

function Pandoc(doc)
  collect_header_ids(doc.blocks)
  local new_blocks = pandoc.walk_block(
    pandoc.Div(doc.blocks),
    { Header = rewrite_header, Cite = replace_cite }
  ).content
  return pandoc.Pandoc(new_blocks, doc.meta)
end
