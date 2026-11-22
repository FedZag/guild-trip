-- Guild Trip Quest-Fuehrung: Quests automatisch annehmen und abgeben (0.6.9).
-- Vorbild Questie (Modules/Auto/AutoQuesting.lua, Bedienung): Shift gedrueckt = fuer dieses Gespraech
-- keine Automatik; keine Begleitquests annehmen; Ruf-/Spenden-NPCs (wiederholbar) bleiben unberuehrt.
-- Eigene Regeln: angenommen wird nur, was die Fuehrung eingeplant hat (wahlweise alle nicht-grauen,
-- nicht wiederholbaren Quests); abgegeben nur Quests aus dem eigenen Questlog. Bei mehreren Belohnungen
-- entscheidest immer du (Nutzer 17.11.2026) – das Fenster bleibt offen.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local A = {}
lev.AutoQuest = A
local G = lev.Guide

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

function A:On(key)
    local db = G:DB()
    if ONE.IsEnabled and not ONE:IsEnabled("leveling") then return false end
    -- Standard: aus (Nutzer 17.11.2026)
    return db[key] == true
end

-- Shift gedrueckt: Automatik fuer dieses Gespraech aus (bis alle Questfenster zu sind)
function A:Paused()
    if Try(IsShiftKeyDown) then self.paused = true end
    return self.paused == true
end
function A:Closed()
    local stamp = {}
    self.closing = stamp
    local function Reset() if self.closing == stamp then self.paused = nil end end
    if C_Timer and C_Timer.After then C_Timer.After(.6, Reset) else Reset() end
end

local function InLog(id)
    local i = Try(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, id)
    return type(i) == "number" and i > 0
end

-- Soll diese Quest angenommen werden? (eingeplant – oder "alle" an und weder grau noch wiederholbar)
function A:Wanted(id, title, trivial, repeatable)
    local plan = G.plan
    if id and plan and plan.chosen[id] then return true end
    if not id and title and plan then
        for qid in pairs(plan.chosen) do if G.Title(qid) == title then return true end end
    end
    if self:On("autoQuestAll") and not trivial and not repeatable then return true end
    return false
end

-- Ruf-/Spenden-NPCs (wiederholbare Abgaben, Kriegsanstrengungen) – wie bei Questie nie automatisch
A.BLOCK_NPC = {[15176] = true, [15458] = true, [15701] = true, [15539] = true, [15700] = true,
    [15764] = true, [15762] = true, [15766] = true, [15763] = true, [15768] = true, [15765] = true,
    [15767] = true, [15761] = true, [15731] = true, [15737] = true, [15735] = true, [15739] = true,
    [15736] = true, [15734] = true, [15738] = true, [15733] = true}
function A.NpcAllowed()
    local guid = Try(UnitGUID, "npc")
    if type(guid) ~= "string" then return true end
    if not strsplit then return true end
    local kind, _, _, _, _, id = strsplit("-", guid) -- Creature-0-Server-Instanz-Zone-NPC-Spawn
    if kind == "Creature" and A.BLOCK_NPC[tonumber(id) or 0] then return false end
    return true
end

local function Escort(id)
    local tag = Try(C_QuestLog and C_QuestLog.GetQuestTagInfo, id)
    -- Enum.QuestTag.Escort = 84 (auch als Tabelle {tagID = …})
    local tid = type(tag) == "table" and tag.tagID or tag
    return tid == 84
end

function A:Ready()
    return self:On("autoQuest") and not self:Paused() and A.NpcAllowed()
end

-- ===== Ereignisse =====
function A:OnGossip()
    if not self:Ready() then return end
    local G2 = C_GossipInfo
    if not G2 then return end
    for _, q in ipairs(Try(G2.GetActiveQuests) or {}) do
        if q.isComplete and q.questID and InLog(q.questID) then return Try(G2.SelectActiveQuest, q.questID) end
    end
    for _, q in ipairs(Try(G2.GetAvailableQuests) or {}) do
        if q.questID and self:Wanted(q.questID, q.title, q.isTrivial, q.repeatable) and not Escort(q.questID) then
            return Try(G2.SelectAvailableQuest, q.questID)
        end
    end
end

-- Alte Begruessung (QUEST_GREETING): Titel statt Nummern
function A:OnGreeting()
    if not self:Ready() then return end
    for i = 1, (Try(GetNumActiveQuests) or 0) do
        local title, complete = Try(GetActiveTitle, i)
        local id = Try(GetActiveQuestID, i)
        if complete and (not id or InLog(id)) then return Try(SelectActiveQuest, i) end
    end
    for i = 1, (Try(GetNumAvailableQuests) or 0) do
        local title = Try(GetAvailableTitle, i)
        local trivial, _, repeatable = Try(GetAvailableQuestInfo, i)
        if self:Wanted(nil, title, trivial, repeatable) then return Try(SelectAvailableQuest, i) end
    end
end

function A:OnDetail()
    if not self:Ready() then return end
    local id = Try(GetQuestID)
    if not id or id == 0 then return end
    if self:Wanted(id, Try(GetTitleText)) and not Escort(id) then
        Try(AcceptQuest)
    end
end

function A:OnProgress()
    if not self:Ready() then return end
    local id = Try(GetQuestID)
    if id and InLog(id) and Try(IsQuestCompletable) then Try(CompleteQuest) end
end

-- Nur eine (oder keine) Belohnung: abgeben. Mehrere: du waehlst selbst.
function A:OnComplete()
    if not self:Ready() then return end
    local id = Try(GetQuestID)
    if not (id and InLog(id)) then return end
    if (Try(GetNumQuestChoices) or 0) <= 1 then Try(GetQuestReward, 1) end
end

function A:Initialize()
    local f = CreateFrame("Frame")
    local map = {GOSSIP_SHOW = "OnGossip", QUEST_GREETING = "OnGreeting", QUEST_DETAIL = "OnDetail",
        QUEST_PROGRESS = "OnProgress", QUEST_COMPLETE = "OnComplete"}
    for e in pairs(map) do pcall(f.RegisterEvent, f, e) end
    for _, e in ipairs({"GOSSIP_CLOSED", "QUEST_FINISHED"}) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then A:Closed() return end
        A.closing = nil
        local fn = A[map[event]]
        if fn then pcall(fn, A) end
    end)
end
