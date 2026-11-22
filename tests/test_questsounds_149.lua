-- Offline-Test: Questklaenge (Nutzer 22.11.2026: "Geld-Klingeln beim Questgeber passt nicht").
-- Ankunft je Ziel-Art eigener Klang; eigene Questklaenge ersetzen die WoW-Klaenge (Standard aus, nie doppelt).
local root = arg[1] or "src"
local played, muted = {}, {}
PlaySoundFile = function(path, channel) played[#played + 1] = path return true end
MuteSoundFile = function(id) muted[id] = true end
UnmuteSoundFile = function(id) muted[id] = nil end
local handler, events = nil, {}
CreateFrame = function()
    return {RegisterEvent = function(_, e) events[e] = true end, SetScript = function(_, _, fn) handler = fn end}
end
local log = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return {questID = log[i].id} end,
    IsComplete = function(id) for _, q in ipairs(log) do if q.id == id then return q.done end end return false end,
}
local feats = {}
local ONE = {db = {features = {}}}
function ONE:Print() end
function ONE:RegisterFeature(id, def) feats[id] = def end
assert(loadfile(root .. "/ONE_Core/Sound.lua"))("ONE_Core", ONE)
local S = ONE.Sound
-- Klangdateien vorhanden (test_sounds_084 prueft alle), Schalter Standard aus
assert(feats["core.questSounds"] and feats["core.questSounds"].get() == false, "Standard aus")
-- Login mit Schalter aus: WoW-Klaenge bleiben an, kein eigener Klang
log = {{id = 1, done = false}}
handler(nil, "PLAYER_LOGIN")
assert(next(muted) == nil and events.QUEST_ACCEPTED and events.QUEST_TURNED_IN and events.QUEST_LOG_UPDATE)
handler(nil, "QUEST_ACCEPTED")
assert(#played == 0, "aus: nichts doppelt")
-- einschalten: WoW-Dateien stumm, eigene Klaenge
feats["core.questSounds"].set(true)
for _, id in ipairs(S.questFiles) do assert(muted[id], "stumm: " .. id) end
handler(nil, "QUEST_ACCEPTED")
assert(played[#played]:find("QuestAngenommen%.ogg$"))
log[1].done = true
handler(nil, "QUEST_LOG_UPDATE")
assert(played[#played]:find("QuestZiele%.ogg$"), "Ziele erfuellt")
local n = #played
handler(nil, "QUEST_LOG_UPDATE")
assert(#played == n, "nur einmal")
-- schon fertig angenommen (Gegenstaende im Gepaeck): kein Ziele-Klang
log[2] = {id = 2, done = true}
handler(nil, "QUEST_LOG_UPDATE")
assert(#played == n)
handler(nil, "QUEST_TURNED_IN")
assert(played[#played]:find("QuestAbgegeben%.ogg$"))
-- ausschalten: WoW-Klaenge wieder an
feats["core.questSounds"].set(false)
assert(next(muted) == nil, "WoW-Klaenge zurueck")

-- Ankunft je Ziel-Art
local nav = {}
_G.ProjectONE = ONE
ONE.modules, ONE.ns = {}, {}
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
GetLocale = function() return "deDE" end
assert(loadfile(root .. "/ONE_Nav/Arrow.lua"))("ONE_Nav", nav)
local A = nav.Arrow
assert(A.ArriveSound({arrive = "accept"}) == "arriveGiver")
assert(A.ArriveSound({arrive = "turnin"}) == "arriveTurnin")
assert(A.ArriveSound({arrive = "obj"}) == "arriveArea")
assert(A.ArriveSound({area = {}}) == "arriveArea")
assert(A.ArriveSound({service = true}) == "arriveService")
assert(A.ArriveSound(nil) == "arriveService")
for _, k in ipairs({"arriveGiver", "arriveTurnin", "arriveArea", "arriveService"}) do
    local found
    for _, a in ipairs(S.alerts) do if a.key == k then found = true end end
    assert(found, "Klang fehlt: " .. k)
end
-- kein Muenz-Klingeln mehr bei Ankunft
local f = assert(io.open(root .. "/ONE_Nav/Arrow.lua")) local src = f:read("*a") f:close()
assert(not src:find('"seal"'), "Ankunft ohne Muenzklang")
print("OK test_questsounds_149")
