-- Guild Trip Quest-Fuehrung: Kasten "Quest-Fuehrung" (0.6.9) – die naechsten Schritte als Liste
-- (Jetzt / Danach / Dann …) mit Zielfortschritt, Navi-Pfeil, Zahnrad fuer die Einstellungen.
-- Wahlweise ersetzt er die WoW-Questliste (rechts unter der Minimap): die WoW-Liste wird dann nur in ein
-- unsichtbares Fenster gehaengt (wie beim Chat) und beim Ausschalten zurueckgesetzt; weitere Quests aus
-- dem Questlog stehen dann unten im Kasten, damit nichts verloren geht.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Tr = {lines = {}, saved = {}}
lev.Tracker = Tr
local G = lev.Guide

Tr.WIDTH = 280            -- Standardgroesse (in Kasten-Einheiten, vor der Schriftgroesse)
Tr.HEIGHT = 220
Tr.MIN_W, Tr.MAX_W, Tr.MIN_H, Tr.MAX_H = 200, 520, 90, 700
Tr.SCALE, Tr.MIN_SCALE, Tr.MAX_SCALE = 1.15, .8, 1.6
Tr.MAX_NEXT = 25
-- WoW-Questliste (je nach Client heisst sie anders)
Tr.BLIZZARD = {"ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame"}

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

function Tr:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "GuildTripLevelingTracker", UIParent)
    local db = G:DB()
    f:SetSize(db.trackerWidth or Tr.WIDTH, db.trackerHeight or Tr.HEIGHT)
    f:SetScale(db.trackerScale or Tr.SCALE)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(Tr.MIN_W, Tr.MIN_H, Tr.MAX_W, Tr.MAX_H)
    elseif f.SetMinResize then f:SetMinResize(Tr.MIN_W, Tr.MIN_H) f:SetMaxResize(Tr.MAX_W, Tr.MAX_H) end
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Tr:SavePos()
    end)
    -- Ziehgriff unten rechts: groesser ziehen = mehr Schritte (Kasten haengt links oben fest)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    grip.icon = grip:CreateTexture(nil, "OVERLAY")
    grip.icon:SetAllPoints(grip)
    grip.icon:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function()
        Tr:SavePos() -- links oben festhalten
        Tr:Place()
        Tr.sizing = true
        f:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        Tr.sizing = false
        local d = G:DB()
        d.trackerWidth, d.trackerHeight = math.floor(f:GetWidth() + .5), math.floor(f:GetHeight() + .5)
        Tr:SavePos()
        Tr:Update(G.plan)
    end)
    grip:SetScript("OnEnter", function(self)
        Tr:Frame(true)
        if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:AddLine(T("Ziehen: Kasten größer/kleiner – mehr oder weniger Schritte"), 1, 1, 1) GameTooltip:Show() end
    end)
    grip:SetScript("OnLeave", function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end)
    f.grip = grip
    local pendingSize = false
    f:SetScript("OnSizeChanged", function()
        if not Tr.sizing or pendingSize then return end
        pendingSize = true
        local function Go() pendingSize = false Tr:Update(G.plan, true) end
        if C_Timer and C_Timer.After then C_Timer.After(.05, Go) else Go() end
    end)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetColorTexture(0, 0, 0, .72)
    f.border = {}
    for i, side in ipairs({{"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"}}) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], f, side[1], 0, 0)
        t:SetPoint(side[2], f, side[2], 0, 0)
        t:SetHeight(2)
        t:SetColorTexture(.36, .32, .25, 1)
        f.border[i] = t
    end
    f.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    f.head:SetText(T("QUEST-FÜHRUNG"))
    -- Zahnrad: Einstellungen
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(14, 14)
    gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -5)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetAllPoints(gear)
    gear.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function() lev.Settings:Toggle() end)
    gear:SetScript("OnEnter", function(self)
        Tr:Frame(true)
        if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:AddLine(T("Einstellungen der Quest-Führung"), 1, .82, 0) GameTooltip:Show() end
    end)
    gear:SetScript("OnLeave", function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end)
    f.gear = gear
    f.arrow = ONE.Widgets:NaviArrow(f, 18, "TOPRIGHT", -28, -3, function() if Tr.step then G:Navi(Tr.step) end end,
        function() return T("Navi zum nächsten Schritt"), Tr.step and G:StepText(Tr.step, true) or "" end)
    f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.dist:SetPoint("RIGHT", f.arrow, "LEFT", -4, 0)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and ONE.UI then ONE.UI:Show() ONE.UI:OpenLink("leveling") end
    end)
    f:SetScript("OnEnter", function(self)
        Tr:Frame(true)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(T("Guild Trip: Quest-Führung"), 1, .82, 0)
            GameTooltip:AddLine(T("Ziehen = verschieben, Rechtsklick = Quest-Seite, Pfeil = Navi, Zahnrad = Einstellungen."), 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end)
    f:Hide()
    self.frame = f
    self:Place()
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < 2 then return end
        acc = 0
        Tr:Distance()
    end)
    return f
end

-- Lage: eigene (verschoben) > Platz der WoW-Questliste > unter der Minimap
function Tr:Place()
    local f = self.frame
    if not f then return end
    f:ClearAllPoints()
    local pos = G:DB().trackerPos
    local scale = (f.GetScale and f:GetScale()) or 1
    if type(pos) == "table" and pos.left then
        -- linke obere Ecke in Bildschirm-Einheiten (unabhaengig von der Schriftgroesse)
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.left / scale, pos.top / scale)
    elseif type(pos) == "table" and pos.right then
        f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", pos.right / scale, pos.top / scale)
    elseif type(pos) == "table" and pos[1] then
        f:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    elseif MinimapCluster then
        f:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", -10, -10)
    else
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -240)
    end
end

-- Lage merken: linke obere Ecke (bleibt beim Groesserziehen und bei anderer Schriftgroesse stehen)
function Tr:SavePos()
    local f = self.frame
    if not (f and f.GetRight) then return end
    local l, t = f:GetLeft(), f:GetTop()
    if not (l and t) then return end
    local scale = f:GetScale() or 1
    G:DB().trackerPos = {left = l * scale, top = t * scale}
end

-- Schriftgroesse (ganzer Kasten wird skaliert, die Lage bleibt)
function Tr:SetScale(scale)
    local db = G:DB()
    scale = math.max(Tr.MIN_SCALE, math.min(Tr.MAX_SCALE, math.floor(scale * 20 + .5) / 20))
    if self.frame then self:SavePos() end
    db.trackerScale = scale
    if self.frame then self.frame:SetScale(scale) self:Place() end
    return scale
end

-- Zeile aus dem Vorrat (Schrift, Einrueckung, Farbe)
function Tr:Line(i)
    local fs = self.lines[i]
    if not fs then
        fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) fs:SetShadowColor(0, 0, 0, 1) end
        self.lines[i] = fs
    end
    return fs
end

-- Rahmen zeigen? (immer, ausser "nur Text" – dann nur beim Drueberfahren)
function Tr:Frame(hover)
    local f = self.frame
    if not f then return end
    local show = not G:DB().trackerBare or hover
    f.bg:SetShown(show)
    for _, t in ipairs(f.border) do t:SetShown(show) end
end

function Tr:Distance()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    local d = G:Distance(self.step)
    f.dist:SetText(d and (math.floor(d + .5) .. " " .. T("m")) or "")
end

function Tr:Enabled()
    local db = G:DB()
    return db.tracker and not (ONE.IsEnabled and not ONE:IsEnabled("leveling"))
end

-- Ziele einer Quest im Log: {"Raptor getötet: 3/8", …} (erledigte grau)
function Tr.Objectives(id)
    local out = {}
    local list = Try(C_QuestLog and C_QuestLog.GetQuestObjectives, id)
    for _, o in ipairs(type(list) == "table" and list or {}) do
        local text = o.text or ""
        if text == "" or text:match("^%s*:") then text = T("Ziel") .. ": " .. ("%d/%d"):format(o.numFulfilled or 0, o.numRequired or 0) end
        out[#out + 1] = {text = text, done = o.finished}
    end
    return out
end

-- Weitere Quests im Log, die nicht in den gezeigten Schritten vorkommen: {{id, title, complete}}
function Tr.OtherLogQuests(shown)
    local out = {}
    local n = Try(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or 0
    for i = 1, n do
        local info = Try(C_QuestLog.GetInfo, i)
        if type(info) == "table" and not info.isHeader and not info.isHidden and info.questID and not shown[info.questID] then
            local QL = ONE.ns and ONE.ns.nav and ONE.ns.nav.QuestLevels
            out[#out + 1] = {id = info.questID, title = (QL and QL.Prefix(info.questID, info.level) or "") .. (info.title or G.Title(info.questID)),
                complete = Try(C_QuestLog.IsComplete, info.questID) == true}
        end
    end
    return out
end

-- Fortschritt einer Quest in Kurzform: "0/1", "2/3 Ziele", "fertig"
function Tr.Progress(id, complete)
    if complete then return "|cff40ff40" .. T("fertig") .. "|r" end
    local objs = Tr.Objectives(id)
    if #objs == 1 then
        local list = Try(C_QuestLog and C_QuestLog.GetQuestObjectives, id)
        local o = type(list) == "table" and list[1]
        if o and o.numRequired and o.numRequired > 0 then return ("%d/%d"):format(o.numFulfilled or 0, o.numRequired) end
    end
    if #objs > 1 then
        local done = 0
        for _, o in ipairs(objs) do if o.done then done = done + 1 end end
        return T("%d/%d Ziele", done, #objs)
    end
    return ""
end

-- Inhalt als Zeilen {text, kind, right, nav, tip} – nach Quests aufgeteilt (Nutzer 17.11.2026):
--   JETZT          der eine Schritt, gross, darunter bei wem/was + Fortschritt
--   NOCH ANNEHMEN  neue Quests mit NPC rechts – fuellt den Platz beim Groesserziehen
--   DEINE QUESTS   jede Quest aus dem Log einmal, in Plan-Reihenfolge, Fortschritt rechts;
--                  fertige gruen "fertig bei wem", nicht eingeplante grau unten (einklappbar)
function Tr:Rows(plan, budget)
    local db = G:DB()
    local rows = {}
    local s1 = plan.steps[1]
    if s1 then
        rows[#rows + 1] = {text = T("JETZT"), kind = "label"}
        rows[#rows + 1] = {text = G:StepText(s1, false, true), kind = "now", nav = {step = s1}}
        local who = G:StepWho(s1)
        if who then rows[#rows + 1] = {text = who, kind = "who"} end
        if s1.kind == "obj" then
            for _, o in ipairs(Tr.Objectives(s1.actions[1].id)) do
                rows[#rows + 1] = {text = (o.done and "|cff808080" or "") .. o.text .. (o.done and "|r" or ""), kind = "obj"}
            end
        end
    else
        -- keine passenden Quests: Monster hauen (bestes Lager)
        local advice = G:Grind(plan)
        local c = advice and advice.camps[1]
        if c then
            rows[#rows + 1] = {text = T("JETZT"), kind = "label"}
            rows[#rows + 1] = {text = T("Monster hauen: %s", c.name), kind = "now", nav = {step = G.CampStep(c)}}
            rows[#rows + 1] = {text = G.CampText(c) .. "  ·  " .. T("~%d EP/Min", math.floor(c.epm + .5)), kind = "who"}
        end
    end
    -- Reihenfolge je Quest im Plan (erster Schritt, in dem sie vorkommt) + Schritt dazu
    local order, firstStep = {}, {}
    for i, st in ipairs(plan.steps) do
        for _, a in ipairs(st.actions) do if not order[a.id] then order[a.id], firstStep[a.id] = i, st end end
        for _, id in ipairs(st.kind == "dungeon" and st.ids or {}) do if not order[id] then order[id], firstStep[id] = i, st end end
    end
    -- NOCH ANNEHMEN: Annehmen-Schritte nach dem jetzigen, je Quest eine Zeile
    local accepts, seen = {}, {}
    if s1 then for _, a in ipairs(s1.actions) do seen[a.id] = true end end
    for i = 2, #plan.steps do
        local st = plan.steps[i]
        for _, a in ipairs(st.actions) do
            if a.kind == "accept" and not seen[a.id] then
                seen[a.id] = true
                accepts[#accepts + 1] = {id = a.id, step = st}
            end
        end
        if #accepts >= Tr.MAX_NEXT then break end
    end
    local acceptAt = #rows + 1
    -- DEINE QUESTS: alles aus dem Log
    local mine = Tr.OtherLogQuests({})
    for _, q in ipairs(mine) do q.order = order[q.id] or (10000 + q.id) end
    table.sort(mine, function(a, b) return a.order < b.order end)
    if #mine > 0 then
        rows[#rows + 1] = {kind = "gap"}
        local open = db.trackerLogOpen ~= false
        rows[#rows + 1] = {text = (open and "− " or "+ ") .. T("DEINE QUESTS (%d)", #mine), kind = "label", toggle = true}
        if open then
            for _, q in ipairs(mine) do
                local planned = order[q.id] ~= nil
                local o = plan.info[q.id]
                local icon, right, kind = G.ICON.obj, Tr.Progress(q.id, false), "log"
                if q.complete then
                    icon = G.ICON.turnin
                    local who = o and o.ender and G.NodeName(o.ender.nr)
                    right = "|cff40ff40" .. T("fertig") .. "|r" .. (who and ("  |cffa0a0a0" .. T("bei %s", who) .. "|r") or "") -- kein "→": fehlt in der WoW-Schrift
                elseif not planned then
                    icon, kind = "|cff808080·|r", "dim"
                end
                local tip
                if not planned and o and o.skip then tip = T("Nicht eingeplant: %s", lev.Planner.SkipText(o, plan, T) or "") end
                if not planned and not tip then tip = T("Nicht eingeplant – lohnt sich laut Führung gerade nicht.") end
                rows[#rows + 1] = {text = icon .. " " .. q.title, right = right, kind = kind, nav = {step = firstStep[q.id], qid = q.id, title = q.title}, tip = tip}
            end
        end
    end
    local n, minutes = G:ToNextLevel()
    if n then
        rows[#rows + 1] = {kind = "gap"}
        local m = math.max(1, math.floor(minutes + .5))
        rows[#rows + 1] = {text = (n == 0 and T("Bis Stufe %d: ~%d min", plan.level + 1, m))
            or (n == 1 and T("Bis Stufe %d: 1 Abgabe · ~%d min", plan.level + 1, m))
            or T("Bis Stufe %d: %d Abgaben · ~%d min", plan.level + 1, n, m), kind = "foot"}
    end
    -- NOCH ANNEHMEN: so viele, wie in die Hoehe passen (mindestens eine)
    local used = 0
    for _, r in ipairs(rows) do used = used + (Tr.STYLE[r.kind] or Tr.STYLE.next)[5] end
    local fit = #accepts
    if budget then
        local head = Tr.STYLE.gap[5] + Tr.STYLE.label[5]
        fit = math.max(1, math.floor((budget - used - head) / Tr.STYLE.next[5]))
    end
    fit = math.min(fit, #accepts)
    if fit > 0 then
        local ins = {{kind = "gap"}, {text = T("NOCH ANNEHMEN"), kind = "label"}}
        for k = 1, fit do
            local a = accepts[k]
            ins[#ins + 1] = {text = G.ICON.accept .. " " .. G.LevelTitle(a.id), right = G.NodeName(a.step.nr) or "", kind = "next", nav = {step = a.step}}
        end
        for k = #ins, 1, -1 do table.insert(rows, acceptAt, ins[k]) end
    end
    return rows, fit
end

-- Schrift, Farbe, Zeilenhoehe, Einrueckung
Tr.STYLE = {
    now = {"GameFontHighlight", 1, 1, 1, 17, 10},
    who = {"GameFontHighlightSmall", .65, .65, .65, 14, 28},
    obj = {"GameFontHighlightSmall", .85, .85, .85, 14, 28},
    next = {"GameFontHighlightSmall", .8, .8, .8, 15, 10},
    label = {"GameFontNormalSmall", 1, .82, 0, 15, 10},
    log = {"GameFontHighlightSmall", .9, .9, .9, 15, 10},
    dim = {"GameFontHighlightSmall", .55, .55, .55, 15, 10},
    foot = {"GameFontDisableSmall", .55, .55, .55, 14, 10},
    gap = {"GameFontHighlightSmall", 0, 0, 0, 6, 10},
}

-- rechte Spalte (Fortschritt im Questlog)
function Tr:Right(i)
    self.rights = self.rights or {}
    local fs = self.rights[i]
    if not fs then
        fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("RIGHT")
        if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) fs:SetShadowColor(0, 0, 0, 1) end
        self.rights[i] = fs
    end
    return fs
end

-- Klickflaeche je Zeile: Navi zur Quest/zum Schritt, Tooltip; Ziehen verschiebt weiter den Kasten
function Tr.NaviTo(nav)
    if not nav then return end
    if nav.step then return G:Navi(nav.step) end
    local nv = ONE.ns and ONE.ns.nav
    if nav.qid and nv and nv.Quests and nv.Quests.Navi then return nv.Quests:Navi({id = nav.qid, title = nav.title or G.Title(nav.qid)}) end
end

function Tr:Hit(i, r, st, y, W)
    self.hits = self.hits or {}
    local b = self.hits[i]
    if not (r.nav or r.tip) then if b then b:Hide() end return end
    if not b then
        b = CreateFrame("Button", nil, self.frame)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function() Tr.frame:StartMoving() end)
        b:SetScript("OnDragStop", function() Tr.frame:StopMovingOrSizing() Tr:SavePos() end)
        b:SetScript("OnClick", function(self) Tr.NaviTo(self.nav) end)
        b:SetScript("OnEnter", function(self)
            Tr:Frame(true)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(self.title or "", 1, .82, 0)
            if self.tip then GameTooltip:AddLine(self.tip, 1, 1, 1, true) end
            if self.nav then GameTooltip:AddLine(T("Klick: Navi dorthin"), .6, .6, .6) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end)
        self.hits[i] = b
    end
    b.nav, b.tip = r.nav, r.tip
    b.title = r.nav and r.nav.qid and G.Title(r.nav.qid) or (r.nav and r.nav.step and G:StepText(r.nav.step, true, true)) or ""
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, y + 1)
    b:SetSize(W - 8, st[5])
    b:Show()
end

function Tr:Update(plan, resizing)
    local f = self:Create()
    self:ApplyReplace()
    if not self:Enabled() or not plan then
        self.step = nil
        f:Hide()
        return
    end
    self.step = plan.steps[1]
    local W = (f.GetWidth and f:GetWidth()) or G:DB().trackerWidth or Tr.WIDTH
    local H = (f.GetHeight and f:GetHeight()) or G:DB().trackerHeight or Tr.HEIGHT
    if type(W) ~= "number" or W <= 0 then W = G:DB().trackerWidth or Tr.WIDTH end
    if type(H) ~= "number" or H <= 0 then H = G:DB().trackerHeight or Tr.HEIGHT end
    local rows = self:Rows(plan, H - 24 - 10)
    local y = -24
    if self.toggle then self.toggle:Hide() end
    for i, r in ipairs(rows) do
        local fs = self:Line(i)
        local right = self:Right(i)
        local st = Tr.STYLE[r.kind] or Tr.STYLE.next
        if fs.SetFontObject and _G[st[1]] then fs:SetFontObject(_G[st[1]]) end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", st[6], y)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, y)
        -- rechte Spalte: so breit wie noetig, hoechstens 45 %
        local rw = 0
        if r.right and r.right ~= "" then
            right:SetText(r.right)
            local sw = right.GetStringWidth and right:GetStringWidth()
            rw = math.min(math.floor(W * .45), (type(sw) == "number" and sw > 0) and (sw + 8) or 60)
            right:SetWidth(rw)
        end
        fs:SetWidth(W - st[6] - 10 - rw)
        fs:SetTextColor(st[2], st[3], st[4])
        fs:SetText(r.text or "")
        fs:Show()
        right:SetText(r.right or "")
        if rw > 0 then right:Show() else right:Hide() end
        self:Hit(i, r, st, y, W)
        if r.toggle then
            -- Klick auf "DEINE QUESTS" klappt ein/aus
            if not self.toggle then
                self.toggle = CreateFrame("Button", nil, f)
                self.toggle:SetScript("OnClick", function()
                    local db = G:DB()
                    db.trackerLogOpen = db.trackerLogOpen == false
                    Tr:Update(G.plan)
                end)
            end
            self.toggle:ClearAllPoints()
            self.toggle:SetPoint("TOPLEFT", f, "TOPLEFT", 6, y + 2)
            self.toggle:SetSize(W - 12, st[5])
            self.toggle:Show()
        end
        y = y - st[5]
    end
    for i = #rows + 1, #self.lines do self.lines[i]:Hide() end
    for i = #rows + 1, #(self.rights or {}) do self.rights[i]:Hide() end
    for i = #rows + 1, #(self.hits or {}) do self.hits[i]:Hide() end
    -- nie Inhalt abschneiden: reicht die gezogene Hoehe nicht, waechst der Kasten (nicht waehrend des Ziehens)
    if not resizing and -y + 8 > H then f:SetHeight(-y + 8) end
    if self.step and self.step.mapID then f.arrow:Enable() else f.arrow:Disable() end
    self:Frame(false)
    f:Show()
    self:Distance()
end

-- ===== WoW-Questliste ersetzen =====
function Tr:Replacing() return G:DB().replaceBlizzard == true and self:Enabled() end

function Tr:ApplyReplace()
    if InCombatLockdown and InCombatLockdown() then self.wantReplace = true return end
    local on = self:Replacing()
    if on and not self.holder then
        self.holder = CreateFrame("Frame", "GuildTripHiddenQuestTracker", UIParent)
        self.holder:Hide()
    end
    for _, name in ipairs(Tr.BLIZZARD) do
        local w = rawget(_G, name)
        if type(w) == "table" and w.SetParent and w.GetParent then
            if on and not self.saved[name] then
                self.saved[name] = w:GetParent() or UIParent
                w:SetParent(self.holder)
            elseif not on and self.saved[name] then
                w:SetParent(self.saved[name])
                self.saved[name] = nil
            end
        end
    end
end

function Tr:Initialize()
    G:OnChange(function(plan) Tr:Update(plan) end)
    -- Fortschritt (Ziele) ohne Neuplanung auffrischen; nach dem Kampf ggf. WoW-Liste umhaengen
    local ev = CreateFrame("Frame")
    for _, e in ipairs({"QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED"}) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and Tr.wantReplace then Tr.wantReplace = nil Tr:ApplyReplace() end
        if G.plan then Tr:Update(G.plan) end
    end)
end
