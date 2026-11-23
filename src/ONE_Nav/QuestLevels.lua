-- Guild Trip: Questlevel vor Questnamen (0.7.1) – "[12] Die Volksmiliz".
-- * In Quest-Links im Chat (nur deine Anzeige – es wird nichts gesendet oder veraendert, was andere sehen).
--   Gilt fuer den WoW-Chat und den Guild-Trip-Chat (der wendet dieselben Nachrichtenfilter an).
-- * Die Quest-Fuehrung (Plan, Kasten) fragt QL.Prefix(id) und setzt die Stufe davor.
-- Abschaltbar: Optionen › Navi › "Questlevel vor Questnamen".
local _, nav = ...
local ONE = _G.ProjectONE

local QL = {}
nav.QuestLevels = QL

function QL.FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("nav.questLevels") end

-- Stufe einer Quest: aus dem Questlog, sonst aus der Questdatenbank; nil = unbekannt
function QL.Level(id)
    local CQ = rawget(_G, "C_QuestLog")
    if CQ and type(CQ.GetLogIndexForQuestID) == "function" and type(CQ.GetInfo) == "function" then
        local okI, index = pcall(CQ.GetLogIndexForQuestID, id)
        if okI and index then
            local okInfo, info = pcall(CQ.GetInfo, index)
            if okInfo and type(info) == "table" and (info.level or 0) > 0 then return info.level end
        end
    end
    local d = rawget(_G, "GuildTripQuestDB")
    local e = d and d.q and d.q[id]
    if e and (e[1] or 0) > 0 then return e[1] end
end

-- ===== Quest-EP (Gesamtpruefung 23.11.2026, Idee wie "Quest XP Tracker") =====
-- EP, die du JETZT fuer die Quest bekommst: zuerst der Wert vom Spiel (Quest im Log), sonst Grund-EP
-- (gemessen bei einer frueheren Abgabe, ONE.db.questXP, sonst Questdatenbank) mit Abzug nach Stufenabstand –
-- dieselbe Tabelle wie Planner.QuestXP der Quest-Fuehrung. Rueckgabe: ep, geschaetzt (true/false); nil auf Stufe 60.
function QL.QuestXP(base, qlvl, plvl)
    local d = plvl - (qlvl or plvl)
    local f = d <= 5 and 1 or d == 6 and .8 or d == 7 and .6 or d == 8 and .4 or d == 9 and .2 or .1
    return math.floor((base or 0) * f / 5 + .5) * 5
end
function QL.XP(id)
    local level = rawget(_G, "UnitLevel")
    local plvl = type(level) == "function" and tonumber((level("player"))) or nil
    if not plvl or plvl >= 60 or not id then return nil end
    local fromGame = rawget(_G, "GetQuestLogRewardXP")
    if type(fromGame) == "function" then
        local ok, xp = pcall(fromGame, id)
        if ok and type(xp) == "number" and xp > 0 then return xp, false end
    end
    local measured = ONE.db and type(ONE.db.questXP) == "table" and ONE.db.questXP[id]
    local d = rawget(_G, "GuildTripQuestDB")
    local e = d and d.q and d.q[id]
    local base = type(measured) == "table" and measured.b or (e and e[11])
    if type(base) ~= "number" or base <= 0 then return nil end
    local qlvl = QL.Level(id) or plvl
    return QL.QuestXP(base, qlvl, plvl), true
end
-- "1.250 EP" / "~1.250 EP"; mit share=true dazu "(12 % der Stufe)"
function QL.XPText(id, share)
    local xp, guess = QL.XP(id)
    if not xp then return nil end
    local T = ONE.T or function(t, ...) return t:format(...) end
    local n = tostring(xp):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    if ONE.Language and ONE:Language() == "en" then n = n:gsub("%.", ",") end
    local text = (guess and "~" or "") .. T("%s EP", n)
    local maxXP = rawget(_G, "UnitXPMax")
    local max = share and type(maxXP) == "function" and tonumber((maxXP("player"))) or nil
    if max and max > 0 then text = text .. " " .. T("(%d %% der Stufe)", math.floor(xp * 100 / max + .5)) end
    return text, xp
end

-- "[12] " oder "" (abgeschaltet / Stufe unbekannt)
function QL.Prefix(id, level)
    if not QL.FeatureOn() then return "" end
    level = level or QL.Level(id)
    if type(level) ~= "number" or level <= 0 then return "" end
    return "[" .. level .. "] "
end

-- Chat: |Hquest:ID:STUFE|h[Titel]|h  ->  |Hquest:ID:STUFE|h[[12] Titel]|h
function QL.Rewrite(msg)
    if type(msg) ~= "string" or not msg:find("|Hquest:", 1, true) then return msg end
    return (msg:gsub("(|Hquest:(%d+):(%-?%d+)[^|]*|h)%[([^%]]*)%]|h", function(head, id, level, title)
        level = tonumber(level)
        if not level or level <= 0 then level = QL.Level(tonumber(id)) end
        if not level or title:match("^%[%d+%]") then return nil end
        return head .. "[[" .. level .. "] " .. title .. "]|h"
    end))
end

QL.EVENTS = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM"}

function QL.Filter(_, _, msg, ...)
    if not QL.FeatureOn() then return false end
    local new = QL.Rewrite(msg)
    if new ~= msg then return false, new, ... end
    return false
end

function QL:Initialize()
    local add = rawget(_G, "ChatFrame_AddMessageEventFilter")
    if type(add) ~= "function" then return false end
    for _, ev in ipairs(self.EVENTS) do pcall(add, ev, QL.Filter) end
    return true
end
