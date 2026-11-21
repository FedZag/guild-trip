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
Tr.MIN_W, Tr.MAX_W, Tr.MIN_H, Tr.MAX_H = 170, 520, 90, 700
Tr.NARROW = 260          -- schmaler als das: NPC-Spalte bei "Noch annehmen" nur im Tooltip
Tr.SCALE, Tr.MIN_SCALE, Tr.MAX_SCALE = 1.15, .8, 1.6
Tr.MAX_NEXT = 25
Tr.MAX_NEXT = 3          -- "Als nächstes": hoechstens so viele Schritte (Nutzer 18.11.2026)
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
    -- Groesse aendern an jeder Kante und Ecke (mehr Platz = mehr Schritte); Griff unten rechts als Zeichen
    local function StopSizing()
        Tr.sizing = false
        local d = G:DB()
        local w, h = f:GetWidth(), f:GetHeight()
        if type(w) == "number" and type(h) == "number" then
            d.trackerWidth, d.trackerHeight = math.floor(w + .5), math.floor(h + .5)
        end
        Tr:SavePos()
        Tr:Place()
        Tr:Update(G.plan)
    end
    f.resize = ONE.Widgets.ResizeHandles and ONE.Widgets:ResizeHandles(f, {size = 6,
        onStart = function() Tr.sizing = true end, onStop = StopSizing,
        onEnter = function(self)
            Tr:Frame(true)
            if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_CURSOR") GameTooltip:AddLine(T("Ziehen: Kasten größer/kleiner – mehr oder weniger Schritte"), 1, 1, 1) GameTooltip:Show() end
        end,
        onLeave = function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end})
    local grip = f:CreateTexture(nil, "OVERLAY")
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
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

-- Ohne Rahmen liegt die Schrift direkt auf der Spielwelt. Scharfer schwarzer Rand aus 8 schwarzen Kopien,
-- je 1 Pixel versetzt (wie ein Aufkleber-Umriss): auf jedem Boden lesbar, ohne Hintergrund. Der eingebaute
-- OUTLINE wirkte bei kleiner Schrift verschwommen (Nutzer 19.11.2026)
Tr.STROKE = {{-1, 0}, {1, 0}, {0, 1}, {0, -1}, {-1, 1}, {1, 1}, {-1, -1}, {1, -1}}

-- Text fuer die schwarzen Kopien: Farbcodes raus, Symbole als schwarze Silhouette (gleiche Groesse)
function Tr.StrokeText(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T([^:|]+):(%d+):(%d+)[^|]*|t", "|T%1:%2:%3:0:0:64:64:0:64:0:64:0:0:0|t")
    return text
end

Tr.strokes = setmetatable({}, {__mode = "k"})
function Tr:Stroke(fs, on)
    local s = Tr.strokes[fs]
    on = on and fs.IsShown and fs:IsShown() and (fs.GetText and fs:GetText() or "") ~= ""
    if not on then
        if s then for _, c in ipairs(s) do c:Hide() end end
        return
    end
    if not s then
        s = {}
        for k in ipairs(Tr.STROKE) do
            local c = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            if c.SetDrawLayer then c:SetDrawLayer("ARTWORK", 7) end
            if c.SetShadowOffset then c:SetShadowOffset(0, 0) end
            if c.SetWordWrap then c:SetWordWrap(false) end
            if c.SetMaxLines then c:SetMaxLines(1) end
            s[k] = c
        end
        Tr.strokes[fs] = s
    end
    local path, size, flags
    if fs.GetFont then path, size, flags = fs:GetFont() end
    local text = Tr.StrokeText(fs:GetText())
    local just = fs.GetJustifyH and fs:GetJustifyH() or "LEFT"
    for k, c in ipairs(s) do
        local o = Tr.STROKE[k]
        if path and c.SetFont then c:SetFont(path, size, flags) end
        c:SetJustifyH(just)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", fs, "TOPLEFT", o[1], o[2])
        c:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", o[1], o[2])
        c:SetTextColor(0, 0, 0, 1)
        c:SetText(text)
        c:Show()
    end
end

-- alle Zeilen, Kopf und Entfernung: Rand nur ohne Rahmen
function Tr:StrokeAll()
    local f = self.frame
    if not f then return end
    local on = G:DB().trackerBare and true or false
    for _, fs in ipairs(self.lines or {}) do self:Stroke(fs, on) end
    for _, fs in ipairs(self.rights or {}) do self:Stroke(fs, on) end
    if f.head then self:Stroke(f.head, on) end
    if f.dist then self:Stroke(f.dist, on) end
end

-- Rahmen zeigen? (immer, ausser "nur Text" – dann nur beim Drueberfahren)
function Tr:Frame(hover)
    local f = self.frame
    if not f then return end
    local show = not G:DB().trackerBare or hover
    f.bg:SetShown(show)
    for _, t in ipairs(f.border) do t:SetShown(show) end
end

-- Entfernung steht jetzt im JETZT-Block (alle 2 s neu); Kopf bleibt frei
function Tr:Distance()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    f.dist:SetText("")
    local fs = self.etaLine and self.lines[self.etaLine]
    if fs and self.step then
        local eta = self:NowEta(self.step) or ""
        if self.etaNarrow then eta = self.etaNarrow .. (eta ~= "" and ("  ·  " .. eta) or "") end
        fs:SetText(eta)
    end
    self:StrokeAll()
end

-- leicht getoenter Hintergrund mit farbiger Kante links: JETZT gold, ALS NAECHSTES silbergrau
Tr.BLOCK_COLOR = {now = {1, .82, 0}, next = {.75, .75, .75}}
function Tr:Blocks(list)
    local f = self.frame
    if not f.CreateTexture then return end
    self.blockTex = self.blockTex or {}
    for k, b in ipairs(list) do
        local t = self.blockTex[k]
        if not t then
            t = {bg = f:CreateTexture(nil, "BORDER"), bar = f:CreateTexture(nil, "ARTWORK")}
            t.bar:SetWidth(2)
            self.blockTex[k] = t
        end
        local c = Tr.BLOCK_COLOR[b.color] or Tr.BLOCK_COLOR.now
        t.bg:SetColorTexture(c[1], c[2], c[3], b.color == "now" and .08 or .05)
        t.bar:SetColorTexture(c[1], c[2], c[3], b.color == "now" and .85 or .6)
        t.bg:ClearAllPoints()
        t.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 4, b.top + 2)
        t.bg:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -4, b.bottom - 1)
        t.bar:ClearAllPoints()
        t.bar:SetPoint("TOPLEFT", t.bg, "TOPLEFT", 0, 0)
        t.bar:SetPoint("BOTTOMLEFT", t.bg, "BOTTOMLEFT", 0, 0)
        t.bg:Show() t.bar:Show()
    end
    for k = #list + 1, #self.blockTex do self.blockTex[k].bg:Hide() self.blockTex[k].bar:Hide() end
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

-- Inhalt als Zeilen {text, kind, right, nav, tip} – nach Quests aufgeteilt (Nutzer 17.11.2026):
--   JETZT          der eine Schritt, gross: Name, was/bei wem, Gebiet/Ort, Entfernung/Zeit
--   ALS NAECHSTES  die naechsten (hoechstens 3) Schritte, NPC rechts
--   (DEINE QUESTS entfallen 18.11.2026: alle Quests mit L im Spiel; Fortschritt der aktuellen unter JETZT)
function Tr:Rows(plan, budget)
    local db = G:DB()
    local rows = {}
    local s1 = plan.steps[1]
    -- UEBER ALLEM (Nutzer 18.11.2026): Gebiet · Quests im Plan · Zeit · Stufe beim Verlassen,
    -- darunter die naechste Stufe (stand frueher unten)
    local zone, sub = Tr.ZoneLine(plan)
    if zone then
        rows[#rows + 1] = {text = zone, kind = "zone"}
        if sub then rows[#rows + 1] = {text = sub, kind = "zoneSub"} end
        rows[#rows + 1] = {kind = "nxGap"}
    end
    -- Frage zur sehr empfohlenen Reihe (Schlafsack): jetzt mit Vorrang oder weiter schnell leveln?
    local rq = G.RecQuestion and G:RecQuestion(plan)
    if rq then
        rows[#rows + 1] = {text = "|cffffd100" .. T("Sehr empfohlen: %s.", T(rq.reason)) .. "|r", kind = "who", block = "ask"}
        rows[#rows + 1] = {text = T("Questreihe jetzt erledigen oder weiter schnell leveln?"), kind = "who", block = "ask"}
        rows[#rows + 1] = {text = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " .. T("Jetzt erledigen (hat Vorrang)"), kind = "who", block = "ask",
            click = function() G:SetRecChoice(rq.key, "now") end, tip = T("Die Schritte der Reihe kommen zuerst. Ändern: Optionen › Leveln.")}
        rows[#rows + 1] = {text = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:12:12|t " .. T("Später – weiter schnell leveln"), kind = "who", block = "ask",
            click = function() G:SetRecChoice(rq.key, "later") end, tip = T("Die Reihe läuft ohne Vorrang mit. Ändern: Optionen › Leveln.")}
        rows[#rows + 1] = {kind = "nxGap"}
    end
    if s1 then
        -- grosser Block (Nutzer 18.11.2026): Name gross, darunter was/bei wem, wo, wie weit/wie lange
        rows[#rows + 1] = {text = T("JETZT"), kind = "label", block = "now"}
        rows[#rows + 1] = {text = Tr.NowTitle(s1), kind = "now", nav = {step = s1}, block = "now", tip = Tr.StepTip(plan, 1)}
        local who = Tr.NowWho(s1)
        if who then rows[#rows + 1] = {text = who, kind = "who", block = "now"} end
        local where = Tr.NowWhere(s1)
        if where then rows[#rows + 1] = {text = where, kind = "where", block = "now"} end
        rows[#rows + 1] = {text = Tr:NowEta(s1) or "", kind = "eta", block = "now"}
        local warn = Tr.Warning(s1)
        if warn then rows[#rows + 1] = {text = warn, kind = "who", block = "now"} end
        -- Abkuerzungen: Ruhestein benutzen/setzen, Geistheiler (Hearth.lua)
        if lev.Hearth then
            local ok, lines = pcall(lev.Hearth.Lines, lev.Hearth, plan)
            for _, l in ipairs(ok and lines or {}) do
                rows[#rows + 1] = {text = "|cffffd100" .. l .. "|r", kind = "who", block = "now"}
            end
        end
        -- Quests im Log, die nicht mehr lohnen (nur Hinweis, nie automatisch)
        local ab = plan.abandon or {}
        if #ab > 0 then
            local names = {}
            for i = 1, math.min(2, #ab) do names[#names + 1] = G.Title(ab[i].id) end
            local more = #ab > 2 and (" " .. T("(+%d)", #ab - 2)) or ""
            local abIDs = {}
            for _, o in ipairs(ab) do abIDs[#abIDs + 1] = o.id end
            rows[#rows + 1] = {text = "|cff9d9d9d" .. T("Abbrechen lohnt: %s", table.concat(names, ", ")) .. more .. "|r", kind = "who", block = "now",
                tip = T("Bringt kaum noch etwas (grau, nur mit Gruppe oder sehr viel Aufwand). Klicken: abbrechen – mit Rückfrage, Guild Trip bricht nie von selbst ab."),
                click = function() G:AskAbandon(abIDs) end}
        end
        if s1.kind == "obj" then
            for _, o in ipairs(Tr.Objectives(s1.actions[1].id)) do
                rows[#rows + 1] = {text = (o.done and "|cff808080" or "") .. o.text .. (o.done and "|r" or ""), kind = "obj"}
            end
        end
    end
    -- ALS NAECHSTES (Nutzer 18.11.2026, statt "Noch annehmen"): die naechsten hoechstens MAX_NEXT
    -- Schritte der Fuehrung, wie sie kommen – aktualisiert sich mit dem Plan.
    local nexts = {}
    for i = 2, math.min(#plan.steps, 1 + Tr.MAX_NEXT) do nexts[#nexts + 1] = plan.steps[i] end
    -- ALS NAECHSTES: so viele, wie in die Hoehe passen (mindestens einer); je Schritt ein kleiner Block
    -- wie JETZT (Name, was/bei wem, Ort · Zeit), blau statt gold (Nutzer 18.11.2026)
    local used = 0
    for _, r in ipairs(rows) do used = used + (Tr.STYLE[r.kind] or Tr.STYLE.next)[5] end
    local per = Tr.STYLE.nxTitle[5] + Tr.STYLE.nxWho[5] + Tr.STYLE.nxWhere[5] + Tr.STYLE.nxGap[5]
    local fit = #nexts
    if budget then
        local head = Tr.STYLE.gap[5] + Tr.STYLE.label[5]
        fit = math.max(1, math.floor((budget - used - head) / per))
    end
    fit = math.min(fit, #nexts)
    if fit > 0 then
        local ins = {{kind = "gap"}, {text = T("ALS NÄCHSTES"), kind = "label"}}
        for k = 1, fit do
            local st = nexts[k]
            local id = "next" .. k
            if k > 1 then ins[#ins + 1] = {kind = "nxGap"} end
            ins[#ins + 1] = {text = Tr.NowTitle(st), kind = "nxTitle", nav = {step = st}, block = id, blockColor = "next", tip = Tr.StepTip(plan, k + 1)}
            local who = Tr.NowWho(st)
            if who then ins[#ins + 1] = {text = who, kind = "nxWho", block = id, blockColor = "next"} end
            local where = Tr.NextWhere(st)
            if where then ins[#ins + 1] = {text = where, kind = "nxWhere", block = id, blockColor = "next"} end
        end
        for _, r in ipairs(ins) do rows[#rows + 1] = r end
    end
    return rows, fit
end

-- Erklaerung nur im Mouseover (Nutzer 20.11.2026: "Kasten nur der naechste Schritt, Erklaerung im Mouseover"):
-- in welcher Runde (Schleife um einen Stuetzpunkt) der Schritt steht, was in der Runde noch kommt, wo abgegeben wird
function Tr.StepTip(plan, i)
    local step = plan and plan.steps[i]
    if not step then return nil end
    local lines = {}
    if step.kind == "grind" and step.hub then
        lines[#lines + 1] = T("Mit Stufe %d gibt es hier neue Quests – kurz Monster hauen spart den Weg hierher zurück.", step.lvl or 0)
    elseif step.kind == "grind" then
        lines[#lines + 1] = T("Die nächsten lohnenden Quests brauchen Stufe %d.", step.lvl or 0)
    elseif step.kind == "vendor" then
        lines[#lines + 1] = T("Taschen fast voll – der Händler liegt am Weg. Verkaufen machst du selbst (oder der Plunder-Verkauf von Guild Trip).")
    end
    if step.onWay then
        lines[#lines + 1] = T("Liegt am Weg – jetzt mitnehmen spart später den Rückweg.")
    end
    local loop = step.loop
    if loop and loop > 0 then
        local objs, turnins, last = 0, 0, nil
        for k = i, #plan.steps do
            local st = plan.steps[k]
            if st.loop ~= loop and st.kind ~= "travel" then break end
            if st.kind == "obj" then objs = objs + 1 end
            for _, a in ipairs(st.actions or {}) do if a.kind == "turnin" then turnins = turnins + 1 last = st end end
        end
        local where = last and last.mapID and last.x and Tr.NearName(last.mapID, last.x, last.y)
        local text
        if objs > 0 and turnins > 0 then
            text = where and T("Runde %d: noch %d Ziele, dann %d Abgaben bei %s.", loop, objs, turnins, where)
                or T("Runde %d: noch %d Ziele, dann %d Abgaben.", loop, objs, turnins)
        elseif turnins > 0 then
            text = T("Runde %d: noch %d Abgaben, dann geht es weiter.", loop, turnins)
        elseif objs > 0 then
            text = T("Runde %d: noch %d Ziele.", loop, objs)
        end
        if text then lines[#lines + 1] = text end
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

-- ===== JETZT-Block =====
-- Zeile 1: nur Questname(n), gross
-- Sehr empfohlene Reihen: Gefahr auf dem Weg (umkaempft, Gebiet der anderen Fraktion, hohe Gegner)
function Tr.Warning(step)
    local P = lev.Planner
    if not (P and P.RecHint) then return nil end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, a in ipairs(step.actions or {}) do
        local h = P.RecHint(a.id, faction)
        if h then return "|cffff9a2e" .. T("Achtung: %s", T(h)) .. "|r" end
    end
end

function Tr.NowTitle(step)
    if step.kind == "travel" or step.kind == "dungeon" or #(step.actions or {}) == 0 then return G:StepText(step, false, true) end
    local icon, names = nil, {}
    for _, a in ipairs(step.actions or {}) do
        icon = icon or G.ICON[a.kind] or G.ICON.obj
        names[#names + 1] = G.LevelTitle(a.id)
    end
    return (icon and (icon .. " ") or "") .. table.concat(names, "  ·  ")
end

-- Zeile 2: was zu tun ist und bei wem ("annehmen bei Tonga Runetotem")
Tr.VERB = {accept = "annehmen", turnin = "abgeben", obj = "erledigen"}
-- zweite Zeile + Hinweis, wenn dieser Schritt den Aufstieg bringt (Nutzer 20.11.2026)
function Tr.NowWho(step)
    local who = Tr.NowWhoBase(step)
    -- Dungeonquest: warum sie im Log landet (Dungeon selbst ueber den Dungeon-Finder, Nutzer 20.11.2026)
    if step and step.dungeon then
        local c = G.Catalog and G.Catalog(step.dungeon)
        local d = T("Dungeonquest – %s", c and c.name or step.dungeon)
        who = who and (who .. " · " .. d) or d
    end
    if step and step.levelUp and step.kind ~= "grind" then
        local up = T("danach Stufe %d", step.levelUp)
        return who and (who .. " · " .. up) or up
    end
    return who
end
function Tr.NowWhoBase(step)
    if step.kind ~= "accept" and step.kind ~= "turnin" and step.kind ~= "obj" then return G:StepWho(step) end
    local verbs, seen = {}, {}
    for _, a in ipairs(step.actions or {}) do
        local v = Tr.VERB[a.kind]
        if v and not seen[v] then seen[v] = true verbs[#verbs + 1] = T(v) end
    end
    local verb = table.concat(verbs, " + ")
    local who = G.NodeName(step.nr)
    if step.kind == "obj" then return who and T("Ziel: %s", who) or (verb ~= "" and verb or nil) end
    if not who then return verb ~= "" and verb or nil end
    return verb .. " " .. T("bei %s", who)
end

-- naechster bekannter Ortsname (Flugpunkt/Stadt) zu einem Kartenpunkt; WoW nennt Ortsnamen
-- nur fuer die eigene Stelle, darum "nahe …"
Tr.NEAR = 900   -- Yards
function Tr.NearName(mapID, x, y)
    local nv = ONE.ns and ONE.ns.nav
    local tr, F = nv and nv.Travel, nv and nv.Flights
    if not (tr and tr.World and F and F.Nodes) then return nil end
    local c, wx, wy = tr.World(mapID, x, y)
    if not c then return nil end
    -- nur Orte im selben Gebiet (Spieltest 20.11.2026: Brachland-Ort als "nahe Brackenwall" – liegt in den
    -- Duestermarschen). Gebiet je Flugpunkt aus ONE_Leveling/FlightMasters.lua (7. Wert).
    local function SameZone(n)
        local zone, zd
        for _, f in ipairs(lev.FLIGHTMASTERS or {}) do
            if f[2] == c then
                local d = math.sqrt((f[3] - n.x) ^ 2 + (f[4] - n.y) ^ 2)
                if d < 80 and (not zd or d < zd) then zone, zd = f[7], d end
            end
        end
        return zone == nil or zone == mapID
    end
    local best, bd
    local ok, nodes = pcall(F.Nodes, F)
    for _, n in pairs(ok and nodes or {}) do
        if type(n) == "table" and n.continent == c and type(n.x) == "number" then
            local d = math.sqrt((n.x - wx) ^ 2 + (n.y - wy) ^ 2)
            if d <= Tr.NEAR and (not bd or d < bd) and SameZone(n) then best, bd = n, d end
        end
    end
    return best and tr.ShortName and tr.ShortName(best.name) or (best and best.name)
end

-- Zeile 3: Gebiet · nahe Ort (x, y)
function Tr.NowWhere(step)
    if not (step.mapID and step.x) then return nil end
    local zone = G.ZoneName(step.mapID)
    local near = Tr.NearName(step.mapID, step.x, step.y)
    local coord = ("(%d, %d)"):format(math.floor(step.x * 100 + .5), math.floor(step.y * 100 + .5))
    return zone .. (near and ("  ·  " .. T("nahe %s", near)) or "") .. "  " .. coord
end

-- Kopfzeile: "BRACHLAND · 12 Quests · ca. 1 h 40 min · bis Stufe 17" + "nächste Stufe: 6 Abgaben · ~40 min"
local function Minutes(m)
    m = math.max(1, math.floor(m + .5))
    if m < 60 then return T("ca. %d min", m) end
    return T("ca. %d h %d min", math.floor(m / 60), m % 60)
end
function Tr.ZoneLine(plan)
    local s1 = plan.steps[1]
    local b = s1 and plan.blocks and s1.block and plan.blocks[s1.block]
    if not (b and b.mapID) then return nil end
    local ids, n = {}, 0
    for i = b.first, b.last do
        local st = plan.steps[i]
        for _, a in ipairs(st.actions or {}) do if not ids[a.id] then ids[a.id] = true n = n + 1 end end
        for _, id in ipairs(st.kind == "dungeon" and st.ids or {}) do if not ids[id] then ids[id] = true n = n + 1 end end
    end
    local parts = {}
    local name = G.ZoneName(b.mapID) or ""
    if name ~= "" then parts[1] = name:upper() end
    parts[#parts + 1] = n == 1 and T("1 Quest") or T("%d Quests", n)
    parts[#parts + 1] = Minutes(b.minutes or 0)
    local max = (UnitXPMax and UnitXPMax("player")) or 0
    if plan.level and max > 0 then
        local out = lev.Planner.LevelAfter(plan.level, (UnitXP and UnitXP("player")) or 0, max, b.xp or 0)
        if out > plan.level then parts[#parts + 1] = T("bis Stufe %d", out) end
    end
    local sub
    local k, minutes = G:ToNextLevel()
    if k and k > 0 then
        sub = (k == 1 and T("nächste Stufe: 1 Abgabe") or T("nächste Stufe: %d Abgaben", k)) .. "  ·  ~" .. math.max(1, math.floor(minutes + .5)) .. " " .. T("min")
    end
    return table.concat(parts, "  ·  "), sub
end

-- ALS NAECHSTES, Zeile 3: nur Gebiet (· nahe Ort) – ohne Weg, Koordinaten und Zeit (Nutzer 18.11.2026)
function Tr.NextWhere(step)
    if not step.mapID then return nil end
    local near = step.x and Tr.NearName(step.mapID, step.x, step.y)
    return G.ZoneName(step.mapID) .. (near and ("  ·  " .. T("nahe %s", near)) or "")
end

-- Zeile 4: Entfernung · ca. Zeit (zu Fuss / reitend / mit Flug oder Schiff laut Plan)
function Tr:NowEta(step)
    local d = G:Distance(step)
    local parts = {}
    if d then parts[#parts + 1] = math.floor(d + .5) .. " " .. T("m") end
    local via = step.via
    if via and via.kind == "hearth" and via.port and via.port ~= "hearth" then
        return T("ca. %d min mit %s", math.max(1, math.floor((step.walk or 0) + .5)), via.name or "?")
    end
    if via and via.kind == "hearth" then
        return T("ca. %d min mit Ruhestein", math.max(1, math.floor((step.walk or 0) + .5)))
    end
    if step.kind == "grind" and step.toXP then
        local now = type(UnitXP) == "function" and UnitXP("player") or nil
        local target = math.min(step.toXP, step.maxXP or step.toXP)
        if now then return T("noch %d EP", math.max(0, target - now)) end
    end
    if step.kind == "grind" then
        return T("ca. %d min", math.max(1, math.floor((step.work or 0) + .5)))
    end
    if via and via.kind == "flight" and step.walk then
        local S = ONE.ns and ONE.ns.nav and ONE.ns.nav.Travel and ONE.ns.nav.Travel.ShortName or function(n) return n end
        parts[#parts + 1] = T("ca. %d min mit Flug ab %s", math.max(1, math.floor(step.walk + .5)), S(via.from and via.from.name or "?"))
    elseif via and step.walk then
        parts[#parts + 1] = T("ca. %d min mit Schiff", math.max(1, math.floor(step.walk + .5)))
    elseif d then
        local mounted = IsMounted and IsMounted()
        local min = d / (mounted and 11 or 7) / 60
        parts[#parts + 1] = min < 1 and T("unter 1 min") or T(mounted and "ca. %d min reitend" or "ca. %d min zu Fuß", math.floor(min + .5))
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "  ·  ")
end

-- Schrift, Farbe, Zeilenhoehe, Einrueckung – Farben wie in WoW selbst: Namen/Ueberschriften gold, Angaben
-- weiss/hellgrau. Lesbar auf hellem Boden ohne Rahmen durch den schwarzen Rand (Tr:Stroke), nicht durch
-- Sonderfarben (Nutzer 19.11.2026: keine Farbe passt zum Spiel)
Tr.STYLE = {
    now = {"GameFontNormalLarge", 1, .82, 0, 21, 14},
    who = {"GameFontHighlight", 1, 1, 1, 16, 14},
    where = {"GameFontHighlightSmall", .85, .85, .85, 14, 14},
    eta = {"GameFontHighlightSmall", .85, .85, .85, 15, 14},
    zone = {"GameFontNormalSmall", 1, .82, 0, 14, 10},
    zoneSub = {"GameFontHighlightSmall", .8, .8, .8, 13, 10},
    nxTitle = {"GameFontHighlight", 1, .82, 0, 16, 14},
    nxWho = {"GameFontHighlightSmall", .9, .9, .9, 13, 14},
    nxWhere = {"GameFontHighlightSmall", .75, .75, .75, 14, 14},
    nxGap = {"GameFontHighlightSmall", 0, 0, 0, 4, 10},
    obj = {"GameFontHighlightSmall", .9, .9, .9, 14, 28},
    next = {"GameFontHighlightSmall", .9, .9, .9, 15, 10},
    label = {"GameFontNormalSmall", 1, .82, 0, 15, 10},
    log = {"GameFontHighlightSmall", .9, .9, .9, 15, 10},
    dim = {"GameFontHighlightSmall", .6, .6, .6, 15, 10},
    foot = {"GameFontDisableSmall", .6, .6, .6, 14, 10},
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

-- Quests einer Zeile (zum Abwaehlen)
function Tr.QuestIDs(nav)
    local out = {}
    if not nav then return out end
    if nav.qid then out[1] = nav.qid end
    for _, a in ipairs(nav.step and nav.step.actions or {}) do if a.id then out[#out + 1] = a.id end end
    return out
end

function Tr:Hit(i, r, st, y, W)
    self.hits = self.hits or {}
    local b = self.hits[i]
    if not (r.nav or r.tip or r.click) then if b then b:Hide() end return end
    if not b then
        b = CreateFrame("Button", nil, self.frame)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function() Tr.frame:StartMoving() end)
        b:SetScript("OnDragStop", function() Tr.frame:StopMovingOrSizing() Tr:SavePos() end)
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                -- Quest(s) dieser Zeile abwaehlen (mit Rueckfrage); ohne Quest: Quest-Seite wie am Rand
                local ids = Tr.QuestIDs(self.nav)
                if #ids > 0 then G:AskSkip(ids) elseif ONE.UI then ONE.UI:Show() ONE.UI:OpenLink("leveling") end
                return
            end
            if self.click then self.click() else Tr.NaviTo(self.nav) end
        end)
        b:SetScript("OnEnter", function(self)
            Tr:Frame(true)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(self.title or "", 1, .82, 0)
            if self.tip then GameTooltip:AddLine(self.tip, 1, 1, 1, true) end
            if self.nav then GameTooltip:AddLine(T("Klick: Navi dorthin"), .6, .6, .6) end
            if #Tr.QuestIDs(self.nav) > 0 then GameTooltip:AddLine(T("Rechtsklick: Quest abwählen"), .6, .6, .6) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end)
        self.hits[i] = b
    end
    b.nav, b.tip, b.click = r.nav, r.tip, r.click
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
    -- Kopfzeile: Titel kuerzen, damit er im schmalen Kasten nicht unter Entfernung/Pfeil/Zahnrad laeuft
    if f.head.SetWidth then f.head:SetWidth(math.max(40, W - 110)) end
    if f.head.SetWordWrap then f.head:SetWordWrap(false) end
    local rows = self:Rows(plan, H - 24 - 10)
    -- schmaler Kasten: Ort und Entfernung in eine Zeile
    if W < Tr.NARROW then
        for i, r in ipairs(rows) do
            if r.kind == "where" and rows[i + 1] and rows[i + 1].kind == "eta" then
                local zone = G.ZoneName(plan.steps[1].mapID)
                r.text, r.kind = zone, "eta"
                table.remove(rows, i + 1)
                r.narrow = true
                break
            end
        end
    end
    local y = -24
    local blocks, lastBlock = {}, nil
    self.etaLine, self.etaNarrow = nil, nil
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
        -- rechte Spalte: einzeilig, notfalls mit "…" gekuerzt; im schmalen Kasten faellt die NPC-Spalte
        -- bei "Noch annehmen" weg (steht dann im Tooltip) – nie umbrechen/ueberlappen (Nutzer 18.11.2026)
        local rw = 0
        if right.SetWordWrap then right:SetWordWrap(false) end
        if right.SetMaxLines then right:SetMaxLines(1) end
        local showRight = r.right and r.right ~= "" and not (r.kind == "next" and W < Tr.NARROW)
        if showRight then
            right:SetWidth(0)
            right:SetText(r.right)
            local sw = right.GetStringWidth and right:GetStringWidth()
            rw = math.min(math.floor(W * (r.kind == "next" and .4 or .45)), (type(sw) == "number" and sw > 0) and (sw + 8) or 60)
            right:SetWidth(rw)
        elseif r.right and r.right ~= "" and r.kind == "next" then
            r.tip = r.tip or (T("bei %s", r.right))
        end
        fs:SetWidth(W - st[6] - 10 - rw)
        if fs.SetMaxLines then fs:SetMaxLines(1) end
        fs:SetTextColor(st[2], st[3], st[4])
        fs:SetText(r.text or "")
        fs:Show()
        if rw > 0 then right:Show() else right:SetText("") right:Hide() end
        self:Hit(i, r, st, y, W)
        if r.block then
            if r.block ~= lastBlock then blocks[#blocks + 1] = {top = y, color = r.blockColor or "now"} lastBlock = r.block end
            blocks[#blocks].bottom = y - st[5]
        else lastBlock = nil end
        if r.kind == "eta" then self.etaLine, self.etaNarrow = i, r.narrow and r.text or nil end
        y = y - st[5]
    end
    self:Blocks(blocks)
    for i = #rows + 1, #self.lines do self.lines[i]:Hide() end
    for i = #rows + 1, #(self.rights or {}) do self.rights[i]:Hide() end
    for i = #rows + 1, #(self.hits or {}) do self.hits[i]:Hide() end
    -- nie Inhalt abschneiden: reicht die gezogene Hoehe nicht, waechst der Kasten (nicht waehrend des Ziehens)
    if not resizing and -y + 8 > H then f:SetHeight(-y + 8) end
    if self.step and self.step.mapID then f.arrow:Enable() else f.arrow:Disable() end
    self:Frame(false)
    f:Show()
    self:Distance()
    self:StrokeAll()
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
            -- WoW haengt die Liste spaeter (z. B. nach /reload) wieder ein: jedes Mal pruefen
            -- (Spieltest 19.11.2026), Original-Eltern nur beim ersten Mal merken
            if on and w:GetParent() ~= self.holder then
                if not self.saved[name] then self.saved[name] = w:GetParent() or UIParent end
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
    for _, e in ipairs({"QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD"}) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function(_, event)
        if (event == "PLAYER_REGEN_ENABLED" and Tr.wantReplace) or event == "PLAYER_ENTERING_WORLD" then Tr.wantReplace = nil Tr:ApplyReplace() end
        if G.plan then Tr:Update(G.plan) end
    end)
end
