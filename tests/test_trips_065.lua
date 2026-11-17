-- Offline-Test: Gildenausfluege (anlegen, empfangen, anmelden, absagen).
local root = arg[1] or "src"
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel) sent[#sent + 1] = {prefix, msg, channel} return true end}
C_Timer = {After = function(_, fn) fn() end, NewTicker = function() return {} end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local now = 1800000000
GetServerTime = function() return now end
date, time = os.date, os.time
UnitName = function() return "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitLevel = function() return 20 end
UnitClass = function() return "Priester", "PRIEST" end
UnitFactionGroup = function() return "Horde" end
IsInGuild = function() return true end
GetZoneText = function() return "Orgrimmar" end
GetSubZoneText = function() return "Tal der Stärke" end
C_Map = {GetBestMapForUnit = function() return 1454 end,
    GetPlayerMapPosition = function() return {GetXY = function() return .5, .25 end} end}
local ONE = {db = {}}
function ONE:Print() end
_G.ProjectONE = ONE
local d = {}
for _, f in ipairs({"QuestData", "Catalog", "Model", "Share", "Trips"}) do assert(loadfile(root .. "/ONE_Dungeons/" .. f .. ".lua"))("ONE_Dungeons", d) end
local told = {}
d.Share.Tell = function(_, text) told[#told + 1] = text end
local Tr, S = d.Trips, d.Share
local function Last() return sent[#sent] and sent[#sent][2] end
local function Recv(msg, from) S:Receive(S.prefix, msg, "GUILD", from) end

-- 1) Eigener Ausflug: TA + eigene Zusage gehen raus
local start = now + 3600
local trip = Tr:Create("wc", start, Tr:HereMeet())
S:Flush(10)
assert(trip and trip.meet.mapID == 1454 and trip.meet.name == "Tal der Stärke")
local ta, ts = sent[#sent - 1][2], sent[#sent][2]
assert(ta:find("^TA|" .. trip.id .. "|wc|" .. start .. "|1454|5000|2500|Tal der Stärke|$"), ta) -- 9. Feld Titel leer
assert(ts == "TS|" .. trip.id .. "|yes|D|20|PRIEST", ts)
assert(Tr:Counts(trip).yes == 1 and Tr:Counts(trip).D == 1)

-- 2) Ein anderer meldet sich an -> Leiter bekommt Hinweis
Recv("TS|" .. trip.id .. "|yes|T|21|WARRIOR", "Thrall-Forever")
assert(Tr:Counts(trip).T == 1 and told[#told]:find("Thrall"))
Recv("TS|" .. trip.id .. "|maybe|H|19|SHAMAN", "Rehgar")
assert(Tr:Counts(trip).maybe == 1 and #Tr:Signups(trip) == 3 and Tr:Signups(trip)[3].status == "maybe")
Recv("TS|" .. trip.id .. "|no|H|19|SHAMAN", "Rehgar")
assert(Tr:Counts(trip).maybe == 0 and #Tr:Signups(trip) == 2)
Recv("TS|" .. trip.id .. "|kaputt|H|19|SHAMAN", "Rehgar")
assert(#Tr:Signups(trip) == 2, "ungueltiger Status wird ignoriert")

-- 3) Fremder Ausflug: Anmeldung kommt VOR dem Ausflug an (Platzhalter)
Recv("TS|X1|yes|H|30|PRIEST", "Garrosh")
assert(#Tr:List() == 1, "Platzhalter nicht sichtbar")
Recv("TA|X1|sfk|" .. (now + 7200) .. "|1454|1000|2000|Tor", "Garrosh")
local other = Tr:Get("X1")
assert(other and other.leader == "Garrosh" and other.meet.x == .1 and Tr:Counts(other).H == 1)
assert(#Tr:List() == 2 and Tr:List()[1] == trip, "nach Startzeit sortiert")
assert(told[#told]:find("Neuer Gildenausflug"))
-- nur der Leiter darf aendern/absagen
Recv("TA|X1|rfc|" .. now .. "|0|0|0|", "Boeser")
assert(Tr:Get("X1").key == "sfk")
Recv("TC|X1", "Boeser")
assert(Tr:Get("X1"))
-- ich melde mich an, dann sagt der Leiter ab
assert(Tr:SignUp("X1", "maybe") and Tr:Mine(other).status == "maybe")
Recv("TC|X1", "Garrosh")
assert(not Tr:Get("X1") and #Tr:List() == 1)

-- 4) Anfrage (REQ): Eigenes wird wiederholt
sent = {}
Recv("REQ", "Neuling")
S:Flush(20)
local hasTA, hasTS = false, false
for _, m in ipairs(sent) do
    if m[2]:find("^TA|" .. trip.id) then hasTA = true end
    if m[2]:find("^TS|" .. trip.id .. "|yes") then hasTS = true end
end
assert(hasTA and hasTS, "Ausflug und Anmeldung wiederholt")

-- 5) Eigene Absage
assert(Tr:Cancel(trip.id) and not Tr:Get(trip.id))
S:Flush(5)
assert(Last() == "TC|" .. trip.id)

-- 6) Aufraeumen 4 Stunden nach dem Start
Recv("TA|Y1|wc|" .. (now - 5 * 3600) .. "|0|0|0|", "Alt")
assert(#Tr:List() == 0 and Tr:Store().Y1 == nil)

-- 7) Zeit-Hilfen
assert(Tr:When(now + 60):find("^heute"))
assert(#Tr:DayOptions() == 7 and #Tr:TimeOptions() == 28)
local s2 = Tr:StartFrom(1, 20 * 60)
assert(os.date("*t", s2).hour == 20 and s2 > now)
print("OK: Gildenausfluege")

-- 8) Reisevorbereitung: Traeger, holen, Vorquest fehlt
do
    local quests = Tr:Quests("wc")
    assert(#quests >= 3, "Hoehlen des Wehklagens hat Quests")
    -- eigener Stand: alles annehmbar (keine Questlog-API im Test)
    C_QuestLog = {IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end}
    local mine = Tr:MyCodes("wc")
    assert(#mine == #quests and not mine:find("[^dlox%-]"), mine)
    local trip2 = Tr:Create("wc", now + 600, {})
    -- Thrall hat Quest 1 im Log, Quest 2 erledigt, bei 3 fehlt die Vorquest
    local codes = {}
    for i = 1, #quests do codes[i] = "o" end
    codes[1], codes[2], codes[3] = "l", "d", "x"
    Recv("TS|" .. trip2.id .. "|yes|T|21|WARRIOR", "Thrall")
    Recv("TQ|" .. trip2.id .. "|" .. #quests .. "|" .. table.concat(codes), "Thrall")
    Recv("TQ|" .. trip2.id .. "|3|lll", "Thrall") -- falsche Laenge: ignoriert
    Recv("TS|" .. trip2.id .. "|maybe|H|20|SHAMAN", "Rehgar") -- teilt keinen Fortschritt
    local rows, unknown = Tr:Prep(trip2)
    assert(#unknown == 1 and unknown[1] == "Rehgar")
    local byIndex = {}
    for _, r in ipairs(rows) do byIndex[r.index] = r end
    assert(byIndex[1].state == "carried" and byIndex[1].carriers[1] == "Thrall", "Thrall traegt Quest 1")
    -- Quest 2 hat Thrall erledigt: zaehlt nur noch, was Hordi selbst braucht
    assert(not byIndex[2] or (byIndex[2].state ~= "carried" and #byIndex[2].open + #byIndex[2].locked <= 1), "Quest 2 nur Hordi")
    assert(#byIndex[3].locked == 1 and Tr:PrepText(byIndex[3]):find("Vorquest fehlt: Thrall"))
    assert(rows[1].state == "fetch" or rows[1].state == "locked", "Offenes zuerst")
    -- ohne Haekchen "Fortschritt teilen" geht kein TQ raus
    S:Flush(50) sent = {}
    Tr:SendPrep(trip2) S:Flush(5)
    assert(#sent == 0)
    S:Settings().shareChars["Hordi"] = true
    Tr:SendPrep(trip2) S:Flush(5)
    assert(sent[1] and sent[1][2] == "TQ|" .. trip2.id .. "|" .. #quests .. "|" .. mine)
end
print("OK: Reisevorbereitung")

-- Eigenes Ziel (15.11.2026): Titel statt Dungeon, geht in der Gilde mit (9. Feld)
do
    S:Flush(50) sent = {}
    assert(Tr:Create(Tr.FREE, now + 7200, Tr:HereMeet(), "   ") == nil, "eigenes Ziel ohne Titel geht nicht")
    local free = Tr:Create(Tr.FREE, now + 7200, Tr:HereMeet(), "  HDW Questrun ")
    S:Flush(10)
    assert(free and free.title == "HDW Questrun" and Tr:Name(free) == "HDW Questrun" and Tr.IsFree(free))
    local msg
    for _, m in ipairs(sent) do if m[2]:find("^TA|" .. free.id) then msg = m[2] end end
    assert(msg and msg:find("|free|") and msg:find("|HDW Questrun$"), tostring(msg))
    assert(#Tr:Quests(free.key) == 0, "keine Dungeon-Quests")
    -- Empfang bei einem anderen Mitglied
    Tr:Store()[free.id] = nil
    Recv(msg, "Thrall-Forever")
    local got = Tr:Get(free.id)
    assert(got and got.title == "HDW Questrun" and Tr:Name(got) == "HDW Questrun")
    -- aeltere Nachricht ohne Titelfeld: Dungeon-Name wie bisher
    Recv("TA|alt1|wc|" .. (now + 3600) .. "|0|0|0|Tor", "Alt")
    assert(Tr:Name(Tr:Get("alt1")) ~= "" and Tr:Get("alt1").title == nil)
    -- Kalender bekommt den Titel
    ONE.modules = nil
end
print("OK: Ausflug mit eigenem Ziel")
