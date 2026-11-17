-- Offline-Test: Navi › Lehrer – Filter nach Lehrer-Art und Beruf (gemerkt in ONE.db.nav).
local root = arg[1] or "src"
UnitClass = function() return "Priester", "PRIEST" end
local trainers = {
    {npc = "A", kind = "class", what = "Priester", map = 1, x = .1, y = .1},
    {npc = "B", kind = "class", what = "Krieger", map = 1, x = .1, y = .1},
    {npc = "C", kind = "profession", what = "Alchemie", map = 1, x = .1, y = .1},
    {npc = "D", kind = "profession", what = "Bergbau", map = 1, x = .1, y = .1},
    {npc = "E", kind = "weapon", what = "Waffenmeister", map = 1, x = .1, y = .1},
    {npc = "F", kind = "other", what = "Tierausbilder", map = 1, x = .1, y = .1},
}
local ONE = {db = {}, modules = {crafting = {AllTrainers = function() return trainers end}}}
_G.ProjectONE = ONE
local nav = {Travel = {PlayerWorld = function() return nil end, World = function() return nil end}}
assert(loadfile(root .. "/ONE_Nav/Page.lua"))("ONE_Nav", nav)
local Page = nav.Page
local function Names(filter)
    Page:SetTrainerFilter(filter)
    local out = {}
    for _, it in ipairs(Page:Targets("trainers")) do out[#out + 1] = it.name end
    table.sort(out)
    return table.concat(out)
end
assert(Page:TrainerFilter() == "all")
assert(Names("all") == "ACDEF", Names("all"))          -- fremde Klassenlehrer nie
assert(Names("class") == "A")
assert(Names("profession") == "CD")
assert(Names("p:Bergbau") == "D")
assert(Names("weapon") == "E")
assert(Names("other") == "F")
assert(ONE.db.nav.trainerFilter == "other", "Wahl wird gemerkt")
-- Stufen-Filter: nur Lehrer, die die Stufe nachweislich lehren
trainers[3].teaches = {Geselle = true, Experte = true}
assert(Names("r:Experte") == "C" and Names("r:Fachmann") == "" and Names("r:Geselle") == "C")
local values = {}
for _, o in ipairs(Page:TrainerFilterOptions()) do values[#values + 1] = o.value end
assert(table.concat(values, " ") == "all class weapon profession p:Alchemie p:Bergbau r:Geselle r:Experte r:Fachmann other", table.concat(values, " "))
print("OK test_trainerfilter_072")
