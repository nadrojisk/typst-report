-- report.lua — Entry point for the report Typst filter set
--
-- Runs every filter below, in order, as separate passes over the document.
-- The individual filter files each define top-level hooks (Header, Table,
-- Pandoc, ...) the way standalone pandoc filters do, which would clobber one
-- another if they were simply dofile()'d into the same global scope. So each
-- is loaded into its own environment and its hooks collected into a filter
-- table; pandoc runs a returned list of such tables sequentially.
--
-- Order matters: typst-secref.lua rewrites headings/cross-references first;
-- the rest only look at their own element types.

local dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)

local HOOKS = {
  "Pandoc", "Meta", "Header", "Table", "CodeBlock", "Div", "Figure", "Cite",
}

local function load_filter(name)
  local env = setmetatable({}, { __index = _G })
  local chunk, err = loadfile(dir .. "/" .. name, "t", env)
  if not chunk then error(err) end
  chunk()
  local filter = {}
  for _, hook in ipairs(HOOKS) do
    local fn = rawget(env, hook)
    if type(fn) == "function" then filter[hook] = fn end
  end
  return filter
end

-- ---- Document metadata ------------------------------------------------------
-- `date` precedence (highest to lowest):
--   1. YAML front matter (`date: "..."`) — always respected
--   2. `--metadata commit-date="..."` — lets CI supply a date without
--      overriding one an author wrote into the document
--   3. Compile-time date
local metadata = {
  Meta = function(meta)
    if meta.date == nil then
      if meta['commit-date'] ~= nil then
        meta.date = meta['commit-date']
      else
        meta.date = pandoc.MetaString(os.date("%B %d, %Y"))
      end
    end
    meta['commit-date'] = nil

    -- Pandoc wraps long author strings at ~72 chars when serializing
    -- metadata, inserting a literal newline. Author names should always be
    -- a single line regardless of length.
    if meta.author then
      local function flatten(inlines)
        local result = ""
        for _, el in ipairs(inlines) do
          if el.t == "Str" then
            result = result .. el.text
          elseif el.t == "Space" or el.t == "SoftBreak" or el.t == "LineBreak" then
            result = result .. " "
          end
        end
        return (result:gsub("%s+", " "):match("^%s*(.-)%s*$"))
      end
      local authors = pandoc.List()
      for _, author in ipairs(meta.author) do
        if type(author) == "table" and author.t == "MetaInlines"
            or pandoc.utils.type(author) == "Inlines" then
          authors:insert(pandoc.MetaInlines(pandoc.Inlines{pandoc.Str(flatten(author))}))
        else
          authors:insert(author)
        end
      end
      meta.author = authors
    end
    return meta
  end,
}

return {
  metadata,
  load_filter("typst-secref.lua"),
  load_filter("typst-appendix.lua"),
  load_filter("typst-table-colors.lua"),
  load_filter("typst-listings.lua"),
  load_filter("typst-d2.lua"),
  load_filter("typst-figures.lua"),
  load_filter("typst-callouts.lua"),
  load_filter("typst-landscape.lua"),
}
