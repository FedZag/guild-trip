-- Offline-Test: Dungeon-Eingaenge (Quellen-Rangfolge, selbst merken, Gilde, Spiel-Abfrage).
local root = arg[1] or "src"
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(_, msg) sent[#sent + 1] = msg return true end}
C_Timer = {After = function(_, fn) fn() end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local clock = 100
GetTime = function() return clock end
UnitName = function() return "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitLevel = function() return 20 end
UnitClass = function() return "Priester", "PRIEST" end
UnitFactionGroup = function() return "Horde" end
IsInGuild = function() return true end
local inside, instName = false, nil
IsInInstance = function() return inside, inside and "party" or "none" end
GetInstanceInfo = function() return instName end
local here = {1413, .461, .359}
C_Map = {GetBestMapForUnit = function() return here[1] end,
    GetPlayerMapPosition = function() return {x = here[2], y = here[3]} end}
local ONE = {db = {}, modules = {}}
function ONE:Print() end
_G.ProjectONE = ONE
local d = {}
for _, f in ipairs({"QuestData", "Catalog", "Model", "Share", "Entrances"}) do assert(loadfile(root .. "/ONE_Dungeons/" .. f .. ".lua"))("ONE_Dungeons", d) end
local E, S = d.Entrances, d.Share

-- 1) Startwert vorhanden, neue Forever-Dungeons ohne
assert(E:Get("wc").source == "seed" and E:Get("thanes") == nil)
-- 2) Namen erkennen (deutsch/englisch/Teilwort), Stratholme nach Naehe
assert(E.Match("Höhlen des Wehklagens")[1].key == "wc" and E.Match("Wailing Caverns")[1].key == "wc")
assert(E.Closest(E.Match("Stratholme"), 1423, .44, .19).key == "stratud")
assert(E.Closest(E.Match("Stratholme"), 1423, .27, .12).key == "stratlive")

-- 3) Selbst merken: draussen laufen, dann Dungeon betreten
E:TrackOutside()
inside, instName = true, "Höhlen des Wehklagens"
E:OnEnterWorld()
local e = E:Get("wc")
assert(e.source == "self" and e.x == .461, "selbst gemerkt")
assert(#sent == 0, "ohne Teilen-Haekchen nichts senden")
-- zu alt -> nicht merken
inside = false here = {1440, .14, .14} E:TrackOutside()
clock = clock + 500 inside, instName = true, "Blackfathom-Tiefe" E:OnEnterWorld()
assert(E:Get("bfd").source == "seed", "alte Position verworfen")

-- 4) Gilde: schlechter als eigener Fund, besser als Startwert; unbekannter Schluessel ignoriert
S:Receive(S.prefix, "DE|wc|1413|100|100", "GUILD", "Thrall")
assert(E:Get("wc").source == "self")
S:Receive(S.prefix, "DE|thanes|1411|500|600", "GUILD", "Thrall")
assert(E:Get("thanes").source == "guild" and E:Get("thanes").x == .5)
S:Receive(S.prefix, "DE|quatsch|1411|500|600", "GUILD", "Thrall")
assert(E:Store().quatsch == nil)
-- 5) Mit Teilen: eigener Fund geht raus
S:SetSharing(true) sent = {}
inside = false here = {1421, .45, .68} clock = clock + 1 E:TrackOutside()
inside, instName = true, "Shadowfang Keep" E:OnEnterWorld()
S:Flush(20)
local found = false
for _, m in ipairs(sent) do if m == "DE|sfk|1421|450|680" then found = true end end
assert(found, table.concat(sent, "\n"))
-- 6) Spiel-Abfrage schlaegt alles
C_EncounterJournal = {GetDungeonEntrancesForMap = function(map)
    if map == 1413 then return {{name = "Höhlen des Wehklagens", position = {x = .47, y = .37}}} end
    return {} end}
E.scanned = nil
assert(E:Get("wc").source == "game" and E:Get("wc").x == .47)
print("OK test_entrances_074")
