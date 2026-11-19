-- Berufslehrer: angebotene Rezepte (Gegenstand, Mindestfertigkeit, Preis) werden still gemerkt (0.7.1).
local root = arg[1] or "src"
local ONE = {db = {}}
_G.ProjectONE = ONE
local crafting = {}
UnitName = function(u) if u == "npc" then return "Schneidergesellin Ada" end return "Brakka" end
UnitFactionGroup = function() return "Horde" end
GetZoneText = function() return "Orgrimmar" end
local services = {
    {"Schneiderei", "Geselle", "available"},
    {"Gürtel des Novizen-Arkanisten", "", "available", "|cff0070dd|Hitem:253885::::::::|h[x]|h|r", 50, 2500},
    {"Grobe Leinenhose", "", "used", "|cffffffff|Hitem:2569::::|h[y]|h|r", 1, 50},
    {"Kategorie", "", "header"},
}
GetNumTrainerServices = function() return #services end
GetTrainerServiceInfo = function(i) local s = services[i] return s[1], s[2], s[3] end
GetTrainerServiceItemLink = function(i) return services[i][4] end
GetTrainerServiceSkillReq = function(i) return "Schneiderei", services[i][5] or 0, true end
GetTrainerServiceCost = function(i) return services[i][6] or 0 end
GetTrainerServiceLevelReq = function() return 10 end
for _, f in ipairs({"Recipes", "Trainers"}) do assert(loadfile(root .. "/ONE_Crafting/" .. f .. ".lua"))("ONE_Crafting", crafting) end
local e = crafting.Trainers:CaptureNow()
assert(e and e.recipes, "Rezepte gemerkt")
assert(e.recipes[253885].skill == 50 and e.recipes[253885].cost == 2500 and e.recipes[253885].level == 10)
assert(e.recipes[2569] and e.recipes[2569].skill == 1, "auch schon gelernte Rezepte")
local n = 0 for _ in pairs(e.recipes) do n = n + 1 end
assert(n == 2, "Ueberschriften und Eintraege ohne Gegenstand nicht")
assert(crafting.Trainers:Store()["Schneidergesellin Ada"] == e)
print("OK test_trainerrecipes_122")
