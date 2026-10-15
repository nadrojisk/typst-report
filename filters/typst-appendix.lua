-- typst-appendix.lua — {.appendix} level-1 headings for Typst output
--
-- The appendix heading show rule below overrides report.typst's regular
-- level-1 heading show rule (Typst uses the last-registered show rule for
-- a given selector), so it renders through report-h1(), the same helper
-- the regular rule uses, keeping appendix headings identical in style to
-- body headings (theme colors included).

local appendix_started = false

function Header(el)
  if el.level == 1 and el.classes:includes("appendix") then
    local result = {}

    if not appendix_started then
      appendix_started = true
      table.insert(result, pandoc.RawBlock("typst",
        -- Switch heading numbering to lettered appendix style:
        -- A / A.1 / A.1.1 / A.1.1.1
        '#let appendix-section-numbering(..nums) = {\n' ..
        '  let n = nums.pos()\n' ..
        '  if n.len() == 1 { "Appendix " + numbering("A", n.at(0)) }\n' ..
        '  else { numbering("A", n.at(0)) + "." + n.slice(1).map(str).join(".") }\n' ..
        '}\n' ..
        '#set heading(numbering: appendix-section-numbering)\n' ..
        '#counter(heading).update(0)\n' ..
        '#show figure.where(kind: image): set figure(numbering: n => {\n' ..
        '  numbering("A", counter(heading).get().first()) + "." + str(n)\n' ..
        '})\n' ..
        '#show figure.where(kind: table): set figure(numbering: n => {\n' ..
        '  numbering("A", counter(heading).get().first()) + "." + str(n)\n' ..
        '})\n' ..
        -- Page numbering function: reads heading counter for the letter
        '#let appendix-numbering(..nums) = {\n' ..
        '  let h = numbering("A", counter(heading).get().first())\n' ..
        '  h + "." + str(nums.pos().first())\n' ..
        '}\n' ..
        '#set page(numbering: appendix-numbering)\n' ..
        -- Show rule: pagebreak first, then reset page to 1, then render heading.
        -- The counter reset is INSIDE the show rule so it fires on the new page.
        '#show heading.where(level: 1): it => {\n' ..
        '  let num = counter(heading).display(appendix-section-numbering)\n' ..
        '  current-section.update(plain-text(it.body))\n' ..
        '  report-h1([#num #sym.dash.en #it.body])\n' ..
        '}'))
    end

    -- Every appendix starts on a fresh page numbered A.1/B.1/..., with its
    -- own figure and table numbering. These resets must come BEFORE the
    -- heading (not inside its show rule) so the heading's location — and
    -- therefore its page number in the table of contents — is already on
    -- the new page, after the counter reset.
    table.insert(result, pandoc.RawBlock("typst",
      '#pagebreak(weak: true)\n' ..
      '#counter(page).update(1)\n' ..
      '#counter(figure.where(kind: image)).update(0)\n' ..
      '#counter(figure.where(kind: table)).update(0)'))

    -- Strip the .appendix class
    local new_classes = pandoc.List()
    for _, c in ipairs(el.classes) do
      if c ~= "appendix" then new_classes:insert(c) end
    end
    el.classes = new_classes

    table.insert(result, el)
    return result
  end
end
