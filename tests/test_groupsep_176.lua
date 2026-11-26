-- Offline-Test 25.11.2026: Trennzeilen im Gruppen-Reiter (Nutzer: "der gruppenchat war mir zu unübersichtlich")
-- Neue Gruppe / Gruppe verlassen als schlichte Zeile im Gruppen-Reiter, ohne Zaehler und ohne Ton.
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
local frames = {}
CreateFrame = function(kind)
    local f = {kind = kind, events = {}, scripts = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:Hide() end
    frames[#frames + 1] = f
    return f
end
local inGroup, raid, members = false, false, {}
IsInGroup = function() return inGroup end
IsInRaid = function() return raid end
GetNumGroupMembers = function() return inGroup and (#members + 1) or 0 end
UnitName = function(unit)
    if unit == "player" then return "Testheld" end
    local i = tonumber(unit:match("%d+"))
    if raid then return i == 1 and "Testheld" or members[i - 1] end
    return members[i]
end
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat
Chat:Settings()
local heard = {}
Chat.listeners[#Chat.listeners + 1] = function(entry, views) heard[#heard + 1] = {entry, views} end

Chat:WatchGroup()
local watch = Chat.groupWatch
assert(watch and watch.events.GROUP_JOINED and watch.events.GROUP_LEFT and watch.events.GROUP_FORMED, "Ereignisse angemeldet")
local function Fire(e) watch.scripts.OnEvent(watch, e) end

-- 1) Beitritt: Zeile mit den Namen, im Gruppen-Reiter, schlicht, ohne Zaehler/Ton
inGroup, members = true, {"Brakk", "Mira"}
Fire("GROUP_JOINED")
local e = heard[#heard][1]
assert(e.event == "GROUPSEP" and e.kind == "group" and e.text:find("Neue Gruppe: Brakk, Mira", 1, true), tostring(e.text))
local inGroupTab = false
for _, v in ipairs(heard[#heard][2]) do if v == "group" then inGroupTab = true end end
assert(inGroupTab, "steht im Gruppen-Reiter")
assert(Chat.IsPlain(e), "schlichte Zeile (Fenster: Mitte, Klassisch: ohne Namen)")
assert((Chat.unread.group or 0) == 0, "kein Zaehler")
Chat:Settings().groupSound = true
assert(Chat:SoundFor(e, {"group"}) == nil, "kein Ton")
assert(not Chat:Format(e):find("|Hplayer:", 1, true), "Klassisch: kein Absender")
-- 2) GROUP_FORMED kurz danach: keine zweite Zeile
local n = #heard
Fire("GROUP_FORMED")
assert(#heard == n, "nur eine Zeile je Gruppe")
-- 3) Verlassen/aufgeloest
inGroup, members = false, {}
Fire("GROUP_LEFT")
assert(heard[#heard][1].text:find("Gruppe verlassen", 1, true), "Verlassen-Zeile")
Fire("GROUP_LEFT")
assert(#heard == n + 1, "doppeltes Verlassen: nur einmal")
-- 4) Schlachtzug: Anzahl statt Namen; viele Namen gekuerzt
inGroup, raid, members = true, true, {"A1", "A2", "A3", "A4", "A5", "A6", "A7"}
Fire("GROUP_JOINED")
assert(heard[#heard][1].text:find("Neuer Schlachtzug (8 Mitglieder)", 1, true), heard[#heard][1].text)
Fire("GROUP_LEFT")
inGroup, raid, members = true, false, {"Brakk", "Mira", "Thorgrim", "Lyra"}
Fire("GROUP_JOINED")
assert(heard[#heard][1].text:find("Brakk, Mira, Thorgrim, Lyra", 1, true), "Gruppe: alle Namen")
-- 5) Beim Einloggen schon in einer Gruppe: keine Zeile
Chat.groupWatch = nil
n = #heard
Chat:WatchGroup()
assert(#heard == n and Chat.groupState == "in", "Neuladen in der Gruppe: still")
print("OK test_groupsep_176")
