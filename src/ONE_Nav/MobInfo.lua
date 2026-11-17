-- Guild Trip: Questgegner erkennen (0.7.0) – Tooltip und Namensplakette.
-- Fahr mit der Maus ueber einen Gegner:
--   Guild Trip: Wolfsjagd – Wolf getötet: 3/10
--               Bob 7/10 · Thrall fertig          (Gruppe/Gilde mit "Quests teilen")
-- Ueber Gegnern, die du fuer eine offene Quest brauchst, steht ein kleines gelbes
-- Symbol an der Namensplakette (blau, wenn nur jemand aus deiner Gruppe ihn braucht).
-- Quelle: Questdatenbank (Ziele je Quest = Gegner-Nummern) + dein Questlog + QuestShare.
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local M = {maxPeers = 3, icon = "Interface\\GossipFrame\\AvailableQuestIcon"}
nav.MobInfo = M

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, s = pcall(issecretvalue, v)
    return ok and s == true
end
local function FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("nav.mobInfo") end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end

-- Gegner-Nummer aus der GUID ("Creature-0-…-npcID-…")
function M.NpcID(guid)
    if type(guid) ~= "string" or IsSecret(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- Index: Gegner -> Quests (nur Quests, die du oder jemand Bekanntes offen hat)
local function Clock() return type(GetTime) == "function" and GetTime() or 0 end
M.maxAge = 15 -- Gilden-Stand kommt laufend: Index hoechstens so alt

function M:Index()
    if not self.byNpc or Clock() - (self.builtAt or 0) > self.maxAge then self:Rebuild() end
    return self.byNpc
end

function M:Rebuild()
    local Q = rawget(_G, "GuildTripQuestDB")
    self.byNpc = {}
    self.builtAt = Clock()
    if not (Q and Q.q) then return end
    local wanted = {}
    self.mine = {}
    for _, q in ipairs(nav.Quests and nav.Quests:Log() or {}) do
        if q.complete then
            self.mine[q.id] = false
        else
            wanted[q.id] = {title = q.title}
            local parts = {}
            for _, o in ipairs(q.objectives or {}) do
                if not o.finished and type(o.text) == "string" and o.text ~= "" then parts[#parts + 1] = o.text end
            end
            self.mine[q.id] = parts
        end
    end
    for _, peer in ipairs(nav.QuestShare and nav.QuestShare:Peers() or {}) do
        for id, e in pairs(peer.quests or {}) do if not e.done then wanted[id] = wanted[id] or {} end end
    end
    for id in pairs(wanted) do
        local e = Q.q[id]
        for _, nr in ipairs(e and e[8] or {}) do
            if nr > 0 and nr < 9000000 then
                self.byNpc[nr] = self.byNpc[nr] or {}
                table.insert(self.byNpc[nr], id)
            end
        end
    end
    self.titles = wanted
end

local function Title(id)
    local Q = rawget(_G, "GuildTripQuestDB")
    local t = M.titles and M.titles[id] and M.titles[id].title
    return t or (Q and Q.titles and Q.titles[id]) or ("#" .. id)
end

-- Meine offenen Ziele dieser Quest als Text ("Wolf getötet: 3/10"); false = fertig, nil = nicht in meinem Log
-- (beim Neuaufbau einmal aus dem Questlog gelesen, nicht je Plakette)
local function MyObjectives(id)
    M:Index()
    return M.mine and M.mine[id]
end

-- Wer aus Gruppe/Gilde braucht die Quest noch? "Bob 7/10"
local function PeerText(id)
    local parts = {}
    for _, h in ipairs(nav.QuestShare and nav.QuestShare:Holders(id) or {}) do
        if #parts >= M.maxPeers then parts[#parts + 1] = "…" break end
        parts[#parts + 1] = h.name .. " " .. (h.done and T("fertig") or (h.r > 0 and ("%d/%d"):format(h.f, h.r) or ""))
    end
    return table.concat(parts, " · "), #parts
end

-- Zeilen fuer den Tooltip: {{text, r, g, b}, …}; leer, wenn niemand den Gegner braucht
function M:Lines(npcID)
    local out = {}
    if not npcID or not FeatureOn() then return out end
    for _, id in ipairs(self:Index()[npcID] or {}) do
        local mine = MyObjectives(id)
        local peers, n = PeerText(id)
        if mine ~= false and (mine or n > 0) then
            local head = "Guild Trip: " .. Title(id)
            if mine and #mine > 0 then head = head .. " – " .. table.concat(mine, ", ") end
            out[#out + 1] = {head, 1, .82, 0}
            if n > 0 then out[#out + 1] = {"   " .. peers, .55, .8, 1} end
        end
    end
    return out
end

-- Brauche ICH den Gegner (gelb) oder nur andere (blau)? nil = niemand
function M:Need(npcID)
    if not npcID or not FeatureOn() then return nil end
    local other
    for _, id in ipairs(self:Index()[npcID] or {}) do
        local mine = MyObjectives(id)
        if mine and #mine > 0 then return "me" end
        if mine == nil and select(2, PeerText(id)) > 0 then other = true end
    end
    return other and "other" or nil
end

-- ===== Tooltip =====
function M:OnTooltip(tooltip)
    if not (tooltip and tooltip.GetUnit and tooltip.AddLine) then return end
    local _, unit = tooltip:GetUnit()
    if not unit or Call(rawget(_G, "UnitIsPlayer"), unit) then return end
    local lines = self:Lines(M.NpcID(Call(rawget(_G, "UnitGUID"), unit)))
    for _, l in ipairs(lines) do tooltip:AddLine(l[1], l[2], l[3], l[4], true) end
    if #lines > 0 and tooltip.Show then tooltip:Show() end
end

-- ===== Namensplaketten =====
function M:Plate(unit)
    local np = rawget(_G, "C_NamePlate")
    local plate = np and Call(np.GetNamePlateForUnit, unit)
    if type(plate) ~= "table" or not plate.CreateTexture then return end
    local need = not Call(rawget(_G, "UnitIsPlayer"), unit) and self:Need(M.NpcID(Call(rawget(_G, "UnitGUID"), unit)))
    local icon = plate.guildTripQuest
    if not need then if icon then icon:Hide() end return end
    if not icon then
        icon = plate:CreateTexture(nil, "OVERLAY")
        icon:SetSize(16, 16)
        icon:SetPoint("BOTTOM", plate, "TOP", 0, -2)
        icon:SetTexture(self.icon)
        plate.guildTripQuest = icon
    end
    if icon.SetVertexColor then
        if need == "me" then icon:SetVertexColor(1, 1, 1) else icon:SetVertexColor(.4, .7, 1) end
    end
    icon:Show()
end

function M:RefreshPlates()
    for i = 1, 40 do self:Plate("nameplate" .. i) end
end

function M:Initialize()
    local function Hook(tt) pcall(M.OnTooltip, M, tt) end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) if tt == GameTooltip then Hook(tt) end end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetUnit", Hook)
    end
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "NAME_PLATE_UNIT_ADDED"}) do pcall(f.RegisterEvent, f, ev) end
    local pending = false
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then M:Plate(unit) return end
        if pending then return end
        pending = true
        local function Go() pending = false M:Rebuild() M:RefreshPlates() end
        if C_Timer and C_Timer.After then C_Timer.After(1, Go) else Go() end
    end)
    self.events = f
end
