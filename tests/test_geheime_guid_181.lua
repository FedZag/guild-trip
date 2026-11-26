-- Lua-Fehler 26.11.2026 (Spieltest): QuestGivers.lua:64 „attempt to index local 'guid' (a secret string value)“.
-- Forever gibt UnitGUID/UnitName des NPCs manchmal als geheimen Wert zurueck. Die Hilfsfunktionen
-- (QuestGivers, Haendler, Auto-Quest, Beute) machen daraus nil; KeyFromGUID faellt dann auf den Namen zurueck.
local root = arg[1] or "src"
local secret = setmetatable({}, {__index = function() error("attempt to index a secret string value") end})
issecretvalue = function(v) return v == secret end
UnitGUID = function() return secret end
local plainName = "Gorm"
UnitName = function() return plainName end
_G.ProjectONE = {features = {}, ns = {}, db = {nav = {}}}
local ONE = _G.ProjectONE
local nav = {Travel = {PlayerMapPosition = function() return 1411, .5, .5 end}}
assert(loadfile(root .. "/ONE_Nav/QuestGivers.lua"))("ONE_Nav", nav)
local G = nav.QuestGivers
assert(G.KeyFromGUID(secret, "Gorm") == "nGorm", "geheime GUID: Name als Schluessel")
assert(G.KeyFromGUID(secret, nil) == nil)
G.Offered = function() return {{id = 5, level = 3, title = "Test"}} end
G.Share = function() end
UnitFactionGroup = function() return "Horde" end
local ok, err = pcall(G.OnEvent, G, "GOSSIP_SHOW") assert(ok, tostring(err))
assert(G:Store()["nGorm"], "Fund trotzdem gemerkt")
plainName = secret
assert(pcall(G.OnEvent, G, "GOSSIP_SHOW"), "auch geheimer Name: kein Fehler")
-- dieselbe Absicherung in allen Hilfsfunktionen, die NPC-GUIDs lesen
for _, f in ipairs({"/ONE_Nav/QuestGivers.lua", "/ONE_Nav/Merchants.lua", "/ONE_Leveling/AutoQuest.lua", "/ONE_Classes/Loot.lua"}) do
    local s = assert(io.open(root .. f)):read("*a")
    assert(s:find("pcall(issecretvalue, r[i])", 1, true), f .. ": geheime Werte nicht abgefangen")
end
print("OK test_geheime_guid_181")
