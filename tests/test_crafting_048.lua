-- Offline-Test: Berufe-Probe (0.4.8b). Echte Daten nur im Spiel.
local root = arg[1] or "src"
local printed, frames = {}, {}
CreateFrame = function()
    local f = {events = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end
GetServerTime = function() return 1 end
UnitLevel = function() return 19 end
GetProfessions = function() return 1, 2, nil, nil, 3 end
GetProfessionInfo = function(i) return ({"Bergbau", "Kräuterkunde", "Kochkunst"})[i], 136248, 55, 75 end
GetNumSkillLines = function() return 2 end
GetSkillLineInfo = function(i) return i == 1 and "Berufe" or "Bergbau", i == 1, nil, 55, nil, nil, 75 end
C_TradeSkillUI = {
    GetTradeSkillLine = function() return 186, "Bergbau", 55, 75 end,
    GetBaseProfessionInfo = function() error("gibt es nicht") end,
    GetAllRecipeIDs = function() return {2657, 2659} end,
    GetRecipeInfo = function(id) return {recipeID = id, name = "Kupfer verhütten", learned = true, icon = 1} end,
    GetRecipeItemLink = function() return "|cffffffff|Hitem:2840|h[Kupferbarren]|h|r" end,
}
local ONE = {db = {}, slash = {}}
function ONE:Print(m) printed[#printed + 1] = m end
function ONE:IsEnabled() return true end
function ONE:RegisterSlash(n, fn) self.slash[n] = fn end
function ONE:RegisterModule(_, def) def.Initialize(def) end
_G.ProjectONE = ONE
local c = {}
local toc = assert(io.open(root .. "/ONE_Crafting/ONE_Crafting.toc")):read("*a")
assert(toc:find("## Interface: 16001", 1, true))
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Crafting/" .. name))("ONE_Crafting", c) end
assert(not toc:find("Diagnostics", 1, true), "Testwerkzeug liegt in ONE_Dev")
local before = #frames
assert(loadfile(root .. "/ONE_Dev/CraftDiag.lua"))("ONE_Dev", {})
-- Die Rahmen des Testwerkzeugs entstehen erst beim Laden von ONE_Dev
local diagFrames = {}
for i = before + 1, #frames do diagFrames[#diagFrames + 1] = frames[i] end
ONE.slash.berufediag("")
local r = ONE.db.craftDiag.run
assert(r.professions[1].info[1] == "Bergbau" and r.professions[3].index == 3 and #r.professions == 3)
assert(r.apis["C_TradeSkillUI.GetAllRecipeIDs"] and not r.apis["GetNumTradeSkills"])
assert(#r.professions.skillLines == 2)
-- Berufsfenster oeffnet sich
assert(diagFrames[1].events.TRADE_SKILL_SHOW)
diagFrames[1].handler(diagFrames[1], "TRADE_SKILL_SHOW")
local w = ONE.db.craftDiag.windows[1]
assert(w.recipeCount == 2 and w.samples[1].info.name == "Kupfer verhütten" and w.samples[1].link:find("Kupferbarren", 1, true))
assert(w.base == "FEHLT" and w.samples[1].output == "FEHLT", "fehlende Schnittstellen ohne Absturz")
assert(printed[#printed]:find("2 Rezepte", 1, true))
-- Lehrer (Waffenmeister)
UnitName = function() return "Sayoc" end
GetZoneText = function() return "Orgrimmar" end
GetSubZoneText = function() return "Tal der Ehre" end
GetNumTrainerServices = function() return 2 end
GetTrainerServiceInfo = function(i) return ({"Bögen", "Dolche"})[i], "", i == 1 and "available" or "unavailable" end
GetTrainerServiceCost = function() return 1000 end
GetTrainerServiceLevelReq = function() return 1 end
GetTrainerServiceSkillReq = function() return nil end
assert(diagFrames[2] and diagFrames[2].events.TRAINER_SHOW)
diagFrames[2].handler(diagFrames[2], "TRAINER_SHOW")
local t = ONE.db.craftDiag.trainers[1]
assert(t.npc == "Sayoc" and t.count == 2 and t.services[1].name == "Bögen" and t.services[2].kind == "unavailable" and t.services[1].cost == 1000)
print("OK: 0.4.8b - Berufe-Probe: Berufe, Schnittstellen, Berufsfenster")
