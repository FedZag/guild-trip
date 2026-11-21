-- Offline-Test 0.5.5: Zauberdaten freiwillig an den Guild-Trip-Entwickler teilen.
local root = arg[1] or "src"
local frames = {}
CreateFrame = function()
    local f = {events = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end
local queue = {}
C_Timer = {After = function(_, fn) queue[#queue + 1] = fn end, NewTicker = function() end}
local function RunTimers() while #queue > 0 do table.remove(queue, 1)() end end
local sent = {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel, target) sent[#sent + 1] = {prefix, msg, channel, target} return true end,
}
UnitName = function() return "Hordi" end
GetNormalizedRealmName = function() return "Forever" end
UnitClass = function() return "Priester", "PRIEST" end
local level = 20
UnitLevel = function() return level end
GetLocale = function() return "deDE" end
GetBuildInfo = function() return "1.60.1" end
IsInGuild = function() return true end
local spells = {[589] = {"Schattenwort: Schmerz", "Rang 1", "Ein Wort der Dunkelheit, das 24 Sek. lang |cffffffff19|r Schaden zufügt; a=b {x} 50%"},
    [8092] = {"Gedankenschlag", "Rang 1", "Überzieht das Ziel mit 12 bis 14 Punkt(en) Schattenschaden."}}
C_Spell = {
    GetSpellInfo = function(id) return spells[id] and {name = spells[id][1], iconID = id, castTime = 1500, maxRange = 30} end,
    GetSpellDescription = function(id) return spells[id] and spells[id][3] or "" end,
    GetSpellPowerCost = function() return {{cost = 25}} end,
}
Enum = {SpellBookSpellBank = {Player = 0}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = 2} end,
    GetSpellBookItemInfo = function(i) local id = ({589, 8092})[i]; return {spellID = id, name = spells[id][1], subName = spells[id][2]} end,
}

local ONE = {db = {}, version = "test"}
local printed = {}
function ONE:Print(m) printed[#printed + 1] = m end
_G.ProjectONE = ONE
local c = {}
for _, f in ipairs({"Data.lua", "Player.lua", "Share.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
local S = c.Share

-- 1) Verpacken und Entpacken
local sample = {a = 1, b = -2.5, s = "|cffff0000rot|r a=b; {x} 50% \n zwei", t = true, f = false,
    list = {{id = 1, name = "x"}, {id = 2}}, [7] = "sieben"}
local text = S.Serialize(sample)
assert(not text:find("|", 1, true) and not text:find("\n", 1, true), "keine Steuerzeichen im Text")
local back = S.Deserialize(text)
assert(back.a == 1 and back.b == -2.5 and back.s == sample.s and back.t == true and back.f == false)
assert(back.list[1].name == "x" and back.list[2].id == 2 and back[7] == "sieben", "verschachtelt")
assert(S.Serialize(back) == text, "gleiche Daten = gleicher Text")
assert(S.Deserialize("{kaputt") == nil, "kaputte Daten ohne Absturz")

-- 2) Sammeln: kein Name, nur Spieldaten
S:Initialize()
local data = S:Collect()
assert(data.class == "PRIEST" and data.level == 20 and #data.spells == 2 and data.spells[1].rank == "Rang 1")
assert(data.spells[1].desc:find("24 Sek", 1, true) and data.spells[1].cost == 25)
assert(not S.Serialize(data):find("Hordi", 1, true), "kein Charaktername")

-- 3) Ohne Haekchen: nichts schicken, Entwickler nur merken
S:Receive("ONECLS1", "HELLO", "GUILD", "Entwickler-Forever")
assert(S:DevOnline() == "Entwickler-Forever" and #sent == 0, "ohne Haekchen kein Versand")

-- 4) Mit Haekchen: Kopf + Pakete per Fluestern an den Entwickler
S:SetEnabled(true)
RunTimers()
assert(#sent >= 2 and sent[1][2]:match("^H:%x+:%d+$") and sent[1][3] == "WHISPER" and sent[1][4] == "Entwickler-Forever")
for i = 2, #sent do assert(#sent[i][2] <= 255, "Addon-Nachricht hoechstens 255 Zeichen") end
assert(printed[#printed]:find("Danke"))
assert(ONE.db.classGuide.share["Hordi-Forever"] == true, "Zustimmung je Charakter")
local count = #sent
-- 5) Nichts Neues: kein zweiter Versand; neue Stufe: wieder schicken
S:Receive("ONECLS1", "HELLO", "GUILD", "Entwickler-Forever")
RunTimers()
assert(#sent == count, "unveraenderte Daten nicht doppelt")
level = 21
S:Receive("ONECLS1", "HELLO", "GUILD", "Entwickler-Forever")
RunTimers()
assert(#sent > count, "neue Stufe wird geschickt")

-- 6) Entwickler-Seite: zusammensetzen, pruefen, ohne Namen speichern
ONE.ns = {classes = c}
local devdb = {}
function ONE:DevDB() return devdb end
date = os.date
assert(loadfile(root .. "/ONE_Dev/DevShare.lua"))("ONE_Dev", {})
local D = ONE.DevShare
for i = count + 1, #sent do D:Receive(sent[i][1], sent[i][2], "WHISPER", "Hordi-Forever") end
local got = devdb.guildSpells and devdb.guildSpells["PRIEST-21"]
assert(got and #got.spells == 2 and got.spells[1].desc:find("|cffffffff19|r", 1, true), "Daten heil angekommen")
assert(not S.Serialize(devdb):find("Hordi", 1, true), "Absendername nicht gespeichert")
assert(printed[#printed]:find("Zauberdaten erhalten: PRIEST Stufe 21", 1, true))
-- kaputtes Paket: verworfen
D:Receive("ONECLS1", "H:deadbeef:1", "WHISPER", "X")
D:Receive("ONECLS1", "C:deadbeef:1:{sx=", "WHISPER", "X")
assert(printed[#printed]:find("unvollständig"))
-- Gildennachrichten (nicht gefluestert) werden nicht angenommen
local before = #printed
D:Receive("ONECLS1", sent[count + 1][2], "GUILD", "Y")
assert(#printed == before)

-- 7) Haekchen aus: kein Versand mehr
S:SetEnabled(false)
level = 22
local n = #sent
S:Receive("ONECLS1", "HELLO", "GUILD", "Entwickler-Forever")
RunTimers()
assert(#sent == n and ONE.db.classGuide.share["Hordi-Forever"] == nil)
-- 8) Realm nach dem Einloggen leer (Spielbild 21.11.): Haekchen bleibt sichtbar an
S:SetEnabled(true)
GetNormalizedRealmName = function() return nil end
GetRealmName = function() return "Forever" end
assert(S:CharKey() == "Hordi-Forever" and S:IsEnabled())
GetRealmName = function() return nil end
assert(S:CharKey() == "Hordi-" and S:IsEnabled(), "Realm leer: alte Zustimmung muss gelten")
-- alter leerer Eintrag aus frueheren Versionen zaehlt auch, wenn der Realm wieder da ist
ONE.db.classGuide.share = {["Hordi-"] = true}
GetNormalizedRealmName = function() return "Forever" end
assert(S:IsEnabled())
S:SetEnabled(true)
assert(ONE.db.classGuide.share["Hordi-Forever"] and ONE.db.classGuide.share["Hordi-"] == nil)
-- Ausschalten loescht alle Eintraege des Namens, anderer Name bleibt
ONE.db.classGuide.share = {["Hordi-"] = true, ["Hordi-Forever"] = true, ["Hordine-Forever"] = true}
S:SetEnabled(false)
assert(not S:IsEnabled() and ONE.db.classGuide.share["Hordine-Forever"])
print("OK test_share_056")
