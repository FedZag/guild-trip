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
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
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
    -- meine offenen Ziele je Gegner (Nutzer 22.11.2026: "Niere gesammelt – Ausrufezeichen ueber den Schreitern
    -- sollten weg sein"): mineNpc[npc][quest] = true nur fuer Gegner eines noch OFFENEN Ziels
    self.mineNpc = {}
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
            for _, nr in ipairs(M.OpenTargets(Q, q.id, q.objectives)) do
                self.mineNpc[nr] = self.mineNpc[nr] or {}
                self.mineNpc[nr][q.id] = true
            end
        end
    end
    for _, peer in ipairs(nav.QuestShare and nav.QuestShare:Peers() or {}) do
        if M.InGroup(peer.name) then
            for id, e in pairs(peer.quests or {}) do if not e.done then wanted[id] = wanted[id] or {} end end
        end
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

-- Gegner/Objekte der noch offenen Ziele einer Quest. Ziele je Art in Spielreihenfolge (monster/item/object) ->
-- Q.obj[id].m/.i/.o. Offenes Ziel ohne Zuordnung (unbekannte Art, fehlende Daten): alle Ziel-Gegner der Quest ausser
-- denen der schon erledigten Ziele (Spieltest 22.11.2026: Loewen und Ebenenschreiter fertig, Ausrufezeichen blieben –
-- ein einziges unbekanntes offenes Ziel holte frueher ALLE Gegner zurueck)
local KIND = {monster = "m", item = "i", object = "o"}
function M.OpenTargets(Q, id, objectives)
    local e = Q and Q.q and Q.q[id]
    local all = e and type(e[8]) == "table" and e[8] or {}
    local od = Q and Q.obj and Q.obj[id]
    if not od then return all end
    local out, seen, closed, idx, unknown = {}, {}, {}, {m = 0, i = 0, o = 0}, false
    for _, o in ipairs(objectives or {}) do
        local kind = KIND[o.type or ""]
        local group
        if kind then
            idx[kind] = idx[kind] + 1
            group = od[kind] and od[kind][idx[kind]]
        end
        if group and #group > 0 then
            for _, nr in ipairs(group) do
                if o.finished then closed[nr] = true
                elseif not seen[nr] then seen[nr] = true out[#out + 1] = nr end
            end
        elseif not o.finished then
            unknown = true
        end
    end
    if unknown then
        for _, nr in ipairs(all) do
            if not seen[nr] and not closed[nr] then seen[nr] = true out[#out + 1] = nr end
        end
    end
    return out
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
-- Nur Leute in meiner Gruppe zaehlen (Nutzer 22.11.2026: "brauche ich nur, wenn ich mit der Person in einer Gruppe
-- bin, sonst interessiert mich das nicht")
function M.InGroup(name)
    local short = type(name) == "string" and (name:match("^[^-]+") or name) or nil
    if not short then return false end
    local raid = (Call(rawget(_G, "IsInRaid")) and true) or false
    local prefix, n = raid and "raid" or "party", raid and 40 or 4
    for i = 1, n do
        local un = Call(rawget(_G, "UnitName"), prefix .. i)
        if un and (un:match("^[^-]+") or un) == short then return true end
    end
    return false
end
-- Text der Gruppenmitglieder mit dieser Quest und wie viele sie noch brauchen (nicht fertig)
local function PeerText(id)
    local parts, open = {}, 0
    for _, h in ipairs(nav.QuestShare and nav.QuestShare:Holders(id) or {}) do
        if M.InGroup(h.name) then
            if not h.done then open = open + 1 end
            if #parts < M.maxPeers then
                parts[#parts + 1] = h.name .. " " .. (h.done and T("fertig") or (h.r > 0 and ("%d/%d"):format(h.f, h.r) or ""))
            elseif parts[#parts] ~= "…" then parts[#parts + 1] = "…" end
        end
    end
    return table.concat(parts, " · "), open
end

-- Zeilen fuer den Tooltip: {{text, r, g, b}, …}; leer, wenn niemand den Gegner braucht
function M:Lines(npcID)
    local out = {}
    if not npcID or not FeatureOn() then return out end
    for _, id in ipairs(self:Index()[npcID] or {}) do
        local mine = MyObjectives(id)
        local peers, n = PeerText(id)
        -- eigene Quest, aber dieser Gegner gehoert zu keinem offenen Ziel mehr: nur noch, was die Gruppe braucht
        if mine and not M.MineFor(npcID, id) then mine = nil end
        if mine ~= false and (mine or n > 0) then
            local head = "Guild Trip: " .. Title(id)
            if mine and #mine > 0 then head = head .. " – " .. table.concat(mine, ", ") end
            out[#out + 1] = {head, 1, .82, 0}
            if n > 0 then out[#out + 1] = {"   " .. peers, .55, .8, 1} end
        end
    end
    return out
end

-- Gehoert der Gegner zu einem meiner offenen Ziele dieser Quest?
function M.MineFor(npcID, id)
    local t = M.mineNpc and M.mineNpc[npcID]
    return t and t[id] or false
end

-- Brauche ICH den Gegner (gelb) oder nur andere (blau)? nil = niemand
function M:Need(npcID)
    if not npcID or not FeatureOn() then return nil end
    local other
    for _, id in ipairs(self:Index()[npcID] or {}) do
        local mine = MyObjectives(id)
        if mine and #mine > 0 and M.MineFor(npcID, id) then return "me" end
        -- Gruppenmitglieder brauchen ihn noch (auch wenn mein Ziel schon erledigt ist): blau
        if (mine == nil or not M.MineFor(npcID, id)) and select(2, PeerText(id)) > 0 then other = true end
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
    for _, ev in ipairs({"QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "GROUP_ROSTER_UPDATE", "NAME_PLATE_UNIT_ADDED"}) do pcall(f.RegisterEvent, f, ev) end
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
