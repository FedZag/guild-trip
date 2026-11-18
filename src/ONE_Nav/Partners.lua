-- Guild Trip: Questpartner in der Naehe (0.7.0).
-- Ein Gildenmitglied in deiner Naehe hat dieselben offenen Quests wie du?
-- Dann kommt ein kleines Fenster: "Thrall (23) macht 3 deiner Quests – 250 m"
-- mit [Einladen] [Navi] [Flüstern]. Zusammen geht es schneller.
--  * Quelle: "Quests teilen" der anderen (QuestShare) + ihre geteilte Position.
--  * Nur ausserhalb des Kampfes, nicht fuer Leute in deiner Gruppe, je Person
--    hoechstens alle 20 Minuten (oder wenn es mehr gemeinsame Quests werden).
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local P = {range = 500, cooldown = 1200, told = {}, planAhead = 15}
nav.Partners = P

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function Clock() return type(GetTime) == "function" and GetTime() or 0 end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function InCombat() return type(InCombatLockdown) == "function" and InCombatLockdown() end
local function FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("nav.partners") end

local function InMyGroup(name)
    return Call(rawget(_G, "UnitInParty"), name) or Call(rawget(_G, "UnitInRaid"), name) and true or false
end

-- Positionen der Gilde (nur wer seine Position teilt): Kurzname -> Peer
local function Positions()
    local out = {}
    local guild = ONE.modules and ONE.modules.guild
    if guild and guild.LivePeers then
        for _, p in ipairs(Call(guild.LivePeers, guild) or {}) do out[Short(p.name)] = p end
    end
    return out
end

-- Kandidaten: {name, level, class, quests = {{id, title}}, dist, peer}
-- Nur offene (nicht fertige) Quests auf beiden Seiten zaehlen.
function P:Candidates()
    local Q, QS = nav.Quests, nav.QuestShare
    if not (Q and QS) then return {} end
    local mine, planned = {}, {}
    for _, q in ipairs(Q:Log()) do
        if not q.complete then mine[q.id] = q.title end
    end
    -- 0.7.1: auch Quests, die dir die Quest-Fuehrung als Naechstes zum Annehmen vorschlaegt
    local lev = ONE.ns and ONE.ns.leveling
    local plan = lev and lev.Guide and lev.Guide.plan
    for i, st in ipairs(plan and plan.steps or {}) do
        if i > self.planAhead then break end
        for _, a in ipairs(st.actions or {}) do
            if a.kind == "accept" and not mine[a.id] then
                mine[a.id] = lev.Guide.Title and lev.Guide.Title(a.id) or ("#" .. a.id)
                planned[a.id] = true
            end
        end
    end
    local where = Positions()
    local navi = ONE.modules and ONE.modules.nav
    local out = {}
    for _, peer in ipairs(QS:Peers()) do
        local name = Short(peer.name)
        if not InMyGroup(name) then
            local shared = {}
            for id, e in pairs(peer.quests or {}) do
                if mine[id] and not e.done then shared[#shared + 1] = {id = id, title = mine[id], planned = planned[id]} end
            end
            local pos = where[name]
            local dist = pos and navi and navi.DistanceTo and Call(navi.DistanceTo, navi, pos.mapID, pos.x, pos.y)
            if #shared > 0 and dist and dist <= self.range then
                table.sort(shared, function(a, b) return a.title < b.title end)
                out[#out + 1] = {name = name, full = peer.name, level = peer.level, class = peer.class,
                    quests = shared, dist = dist, pos = pos}
            end
        end
    end
    table.sort(out, function(a, b)
        if #a.quests ~= #b.quests then return #a.quests > #b.quests end
        return a.dist < b.dist
    end)
    return out
end

-- Wen jetzt melden? Je Person nur nach Ablauf der Pause oder bei mehr gemeinsamen Quests.
function P:Check()
    if InCombat() or not FeatureOn() then return nil end
    local now = Clock()
    for _, c in ipairs(self:Candidates()) do
        local t = self.told[c.name]
        if not t or now - t.at >= self.cooldown or #c.quests > t.count then
            self.told[c.name] = {at = now, count = #c.quests}
            self:Show(c)
            return c
        end
    end
end


-- Fenster im aktiven Aussehen (Blizzard-Rahmen bzw. Pergamentblatt im Buch) und Texte in Theme-Farben
-- Im Buch-Aussehen: helle Farbcodes als lesbare Tinte auf Pergament
local function Ink(text)
    local book = ONE.Book
    if book and book.IsActive and book:IsActive() and book.InkCodes then return book.InkCodes(text) end
    return text
end
local function Themed(frame, bg, title, texts)
    local th = ONE.Themes
    if not th then return end
    if th.RegisterWindow then pcall(th.RegisterWindow, th, frame, bg, title) end
    for fs, role in pairs(texts or {}) do if th.RegisterText then pcall(th.RegisterText, th, fs, role) end end
end

-- ===== Fenster =====
function P:Text(c)
    local head = #c.quests == 1 and T("%s (%d) macht deine Quest „%s“ – %d m entfernt.", c.name, c.level or 0, c.quests[1].title, math.floor(c.dist + .5))
        or T("%s (%d) macht %d deiner Quests – %d m entfernt.", c.name, c.level or 0, #c.quests, math.floor(c.dist + .5))
    return head
end

function P:WhisperText(c)
    if #c.quests == 1 then return T("Hey, wollen wir „%s“ zusammen machen?", c.quests[1].title) end
    return T("Hey, wir haben %d gleiche Quests – zusammen machen?", #c.quests)
end

local function Button(parent, label, width)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(width, 22)
    b:SetText(label)
    return b
end

function P:Frame()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "GuildTripQuestPartner", UIParent)
    f:SetSize(330, 96)
    f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    if f.SetMovable then f:SetMovable(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then bg:SetColorTexture(0, 0, 0, .8) end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.title:SetText(T("Questpartner in der Nähe"))
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
    f.text:SetWidth(310)
    if f.text.SetJustifyH then f.text:SetJustifyH("LEFT") end
    f.invite = Button(f, T("Einladen"), 90)
    f.invite:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.navi = Button(f, T("Navi"), 70)
    f.navi:SetPoint("LEFT", f.invite, "RIGHT", 6, 0)
    f.whisper = Button(f, T("Flüstern"), 90)
    f.whisper:SetPoint("LEFT", f.navi, "RIGHT", 6, 0)
    f.close = Button(f, "×", 24)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    f.invite:SetScript("OnClick", function() P:Invite() end)
    f.navi:SetScript("OnClick", function() P:Navi() end)
    f.whisper:SetScript("OnClick", function() P:Whisper() end)
    f.close:SetScript("OnClick", function() P:Hide() end)
    Themed(f, bg, f.title, {[f.text] = "text"})
    -- Tooltip: welche Quests gemeinsam sind
    f:SetScript("OnEnter", function(self)
        local c = P.current
        if not (GameTooltip and c) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Gemeinsame Quests"))
        for _, q in ipairs(c.quests) do
            if GameTooltip.AddLine then GameTooltip:AddLine(q.title .. (q.planned and (" |cff9d9d9d" .. T("(als Nächstes im Plan)") .. "|r") or ""), 1, 1, 1) end
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f:Hide()
    self.frame = f
    return f
end

function P:Show(c)
    self.current = c
    local f = self:Frame()
    f.text:SetText(self:Text(c))
    f:Show()
    if ONE.Notify then ONE:Notify(self:Text(c), {source = T("Questpartner"), toast = false, sound = "notify"}) end
    -- Nach einer Minute von selbst weg
    if C_Timer and C_Timer.After then
        local shown = c
        C_Timer.After(60, function() if P.current == shown then P:Hide() end end)
    end
end

function P:Hide()
    if self.frame then self.frame:Hide() end
    self.current = nil
end

function P:Invite()
    local c = self.current
    if not c then return end
    if C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then Call(C_PartyInfo.InviteUnit, c.full or c.name)
    else Call(rawget(_G, "InviteUnit"), c.full or c.name) end
    self:Hide()
end

function P:Navi()
    local c, navi = self.current, ONE.modules and ONE.modules.nav
    if c and navi and navi.StartTo then Call(navi.StartTo, navi, c.pos and c.pos.name or c.name) end
    self:Hide()
end

function P:Whisper()
    local c = self.current
    if not c then return end
    if type(ChatFrame_OpenChat) == "function" then Call(ChatFrame_OpenChat, "/w " .. (c.full or c.name) .. " " .. self:WhisperText(c)) end
    self:Hide()
end

function P:Initialize()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(20, function() P:Check() end)
    end
end
