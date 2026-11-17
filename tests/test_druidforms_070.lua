-- Offline-Test: Druiden-Gestaltleisten (Katze 73-84, Baer 97-108), Krieger-Haltungen bleiben unberuehrt.
local root = arg[1] or "src"
local ONE = {db = {}}
function ONE:Print() end
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Classes/Data.lua"))("ONE_Classes", c)
assert(loadfile(root .. "/ONE_Classes/DataClasses.lua"))("ONE_Classes", c)
c.Player = {SpellInfo = function(id) return "S" .. id end, Path = function() return nil end}
assert(loadfile(root .. "/ONE_Classes/Bars.lua"))("ONE_Classes", c)
local D, B = c.Data, c.Bars
local function Has(list, slot) for _, s in ipairs(list) do if s == slot then return true end end return false end

-- 1) Krieger: Haltungsleisten (73-84, 97-108) werden nie verwaltet
local warrior = D:Build(D.classes.WARRIOR, 1, "solo")
local m = B:ManagedSlots(warrior)
assert(not Has(m, 73) and not Has(m, 97) and Has(m, 1) and Has(m, 61), "Krieger-Haltungen tabu")
assert(not Has(B:ManagedSlots(nil), 73))

-- 2) Druide: alle drei Ausrichtungen haben Katze (7) und Baer (9)
for spec = 1, 3 do
    local build = D:Build(D.classes.DRUID, spec, "solo")
    assert(build.forms and build.forms[1].bar == 7 and build.forms[2].bar == 9, "Gestalten fehlen " .. spec)
    m = B:ManagedSlots(build)
    assert(Has(m, 73) and Has(m, 84) and Has(m, 97) and Has(m, 108) and not Has(m, 85))
    for _, form in ipairs(build.forms) do
        local fixed, talent = 0, 0
        for _, step in ipairs(form.slots) do if step.talent then talent = talent + 1 else assert(talent == 0) fixed = fixed + 1 end end
        assert(fixed + talent <= 12, "Gestaltleiste zu voll")
        -- Platz-Nummern stehen am Anfang eines Schritts (z. B. "7 bei 4–5 Punkten und 70 Energie")
        for step in (form.flow .. " · "):gmatch("(.-)%s*·%s*") do
            local n = step:match("^(%d+)")
            if n then assert(tonumber(n) <= fixed + talent, form.title .. ": Ablauf zeigt auf Platz " .. n) end
        end
    end
end

-- 3) Plan: Katzenzauber auf 73.., Baer auf 97..; Talent-Plaetze nur wenn gelernt
local p = {Spell = function(_, id) if type(id) == "table" then id = id[1] end return {id = id, name = "S" .. id, known = id ~= 1238122} end}
local plan = B:Plan(p, D:Build(D.classes.DRUID, 2, "solo"))
local at = {}
for _, e in ipairs(plan) do at[e.slot] = e end
assert(at[73] and at[73].spellID == 5215 and at[73].bar == 7, "Schleichen auf 73")
assert(at[97] and at[97].spellID == 6795, "Spott auf 97")
assert(not at[105] or at[105].spellID ~= 1238122, "nicht gelernte Talent-Faehigkeit erscheint nicht")
assert(at[1] and at[1].bar == 1, "normale Leiste 1 bleibt")
print("OK test_druidforms_070")
