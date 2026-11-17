-- Prueft alle Talentplaene gegen den Forever-Baum: Nummern im Baum, Raenge <= max,
-- Reihen-Freischaltung (5 Punkte je Reihe im selben Baum), Summe 51.
-- Aufruf: SV=<Pfad zu ONE_Dev.lua> lua5.1 scripts/check_talent_plans.lua
local classes = {}
_G.ProjectONE = {}
assert(loadfile("src/ONE_Classes/Data.lua"))(nil, classes)
assert(loadfile("src/ONE_Classes/DataClasses.lua"))(nil, classes)
dofile(assert(os.getenv("SV")))
local scan = GuildTripDevDB.spellScan
local function Group(x) return x < 4000 and 1 or x < 8000 and 2 or 3 end
local problems = 0
for cls, def in pairs(classes.Data.classes) do
  local s = scan[cls]
  if not s then print(cls, "keine Auslese") else
    print(cls, "Baeume:", #s.talents)
    local bySpell, ys = {}, {{}, {}, {}}
    for _, tree in ipairs(s.talents) do for _, t in ipairs(tree.talents or {}) do
      if t.spell and (t.x or 0) < 20000 and (t.y or 0) < 10000 then
        if bySpell[t.spell] and bySpell[t.spell].node ~= t.node then print("  doppelte Nummer", t.spell, t.name) end
        bySpell[t.spell] = t
        ys[Group(t.x)][t.y] = true
      end
    end end
    for spec, b in ipairs(def.build) do
      local plan = b.talents
      if not plan then print("  ", spec, "kein Plan") else
        local spent, have, total, notes = {0,0,0}, {}, 0, {}
        for i, step in ipairs(plan) do
          local t = bySpell[step[1]]
          if not t then notes[#notes+1] = ("Schritt %d: %d nicht im Baum"):format(i, step[1])
          else
            local g, row = Group(t.x), math.floor((t.y - 2130 + 300) / 600)
            local cur = have[step[1]] or 0
            if step[2] <= cur then notes[#notes+1] = ("Schritt %d: %s schon auf %d (Plan %d)"):format(i, t.name, cur, step[2]) end
            if step[2] > (t.maxRanks or 0) then notes[#notes+1] = ("Schritt %d: %s max %d, Plan %d"):format(i, t.name, t.maxRanks or 0, step[2]) end
            for r = cur + 1, math.min(step[2], t.maxRanks or 0) do
              if spent[g] < 5 * row then notes[#notes+1] = ("Schritt %d: %s Reihe %d braucht %d Punkte im Baum, erst %d"):format(i, t.name, row + 1, 5 * row, spent[g]) break end
              spent[g], total = spent[g] + 1, total + 1
            end
            have[step[1]] = math.max(cur, math.min(step[2], t.maxRanks or 0))
          end
        end
        print(("   %s %d (%s): %d Punkte  [%d/%d/%d]"):format(cls, spec, def.specs[spec], total, spent[1], spent[2], spent[3]))
        if total ~= 51 then notes[#notes+1] = "Summe " .. total .. " statt 51" end
        for _, n in ipairs(notes) do print("      ! " .. n) problems = problems + 1 end
      end
    end
  end
end
print("Probleme:", problems)
