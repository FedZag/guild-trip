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
-- Aussehen (Nutzer 22.11.2026, Regel fuer alle Zusatzfenster): Zahnrad = eigene Optionen des Kastens –
-- Stil-Vorlage, Farben (vor allem Questgeber-Namen), Hintergrund. Gemeinsamer Baustein: ONE_Core/WindowLook.lua.
-- Vorlagen sind eigene Gestaltung (nichts von anderen Addons uebernommen); jede schlaegt einen Hintergrund vor.
Tr.PRESETS = {
    guildtrip = {maxNext = 3, bg = "dark"},
    -- wie die WoW-Questverfolgung: ohne Kasten, ohne Ueberschriften und Bloecke, Ziele eingerueckt
    wow = {maxNext = 3, bg = "none", noLabels = true, noBlocks = true, nextLines = {nxTitle = true, nxWho = true},
        style = {now = {"GameFontNormal", 17, 10}, who = {"GameFontHighlightSmall", 14, 22}, where = {"GameFontHighlightSmall", 13, 22},
            eta = {"GameFontHighlightSmall", 13, 22}, obj = {"GameFontHighlightSmall", 14, 22}, obj2 = {"GameFontHighlightSmall", 14, 22},
            nxTitle = {"GameFontNormal", 16, 10}, nxWho = {"GameFontHighlightSmall", 13, 22}, nxGap = {"GameFontHighlightSmall", 6, 10},
            gap = {"GameFontHighlightSmall", 10, 10}}},
    -- dicht: kleinere Schrift, mehr naechste Schritte (nur der Name je Schritt)
    compact = {maxNext = 6, bg = "glassLight", nextLines = {nxTitle = true},
        style = {now = {"GameFontNormal", 16, 14}, who = {"GameFontHighlightSmall", 13, 14}, where = {"GameFontHighlightSmall", 12, 14},
            eta = {"GameFontHighlightSmall", 13, 14}, label = {"GameFontNormalSmall", 13, 10}, zone = {"GameFontNormalSmall", 13, 10},
            zoneSub = {"GameFontHighlightSmall", 12, 10}, nxTitle = {"GameFontHighlightSmall", 14, 14}, nxGap = {"GameFontHighlightSmall", 1, 10},
            obj = {"GameFontHighlightSmall", 13, 24}, obj2 = {"GameFontHighlightSmall", 14, 14}, gap = {"GameFontHighlightSmall", 4, 10}}},
    -- nur der naechste Schritt und seine Ziele, kein Kasten
    minimal = {maxNext = 0, bg = "none", noLabels = true, noBlocks = true, noZone = true,
        style = {now = {"GameFontNormal", 17, 6}, who = {"GameFontHighlightSmall", 14, 6}, where = {"GameFontHighlightSmall", 13, 6},
            eta = {"GameFontHighlightSmall", 13, 6}, obj = {"GameFontHighlightSmall", 14, 14}, obj2 = {"GameFontHighlightSmall", 14, 6}}},
}
Tr.LOOK = {
    id = "tracker", title = "Quest-Führung: Aussehen", key = "trackerLook",
    store = function() return G:DB() end,
    presets = {
        {value = "guildtrip", bg = "dark", text = "Guild Trip", tooltip = "Blöcke JETZT und ALS NÄCHSTES mit Gebiet, Ort und Zeit."},
        {value = "wow", bg = "none", text = "WoW-Look", tooltip = "Wie die Questverfolgung von WoW: ohne Kasten, Ziele eingerückt."},
        {value = "compact", bg = "glassLight", text = "Kompakt", tooltip = "Kleiner und dichter, bis zu 6 nächste Schritte als Liste."},
        {value = "minimal", bg = "none", text = "Minimal", tooltip = "Nur der nächste Schritt mit seinen Zielen, ohne Kasten."},
    },
    defaultPreset = "guildtrip",
    defaultBg = function()
        if G:DB().trackerBare then return "none" end
        local pr = Tr.PRESETS[Tr.Preset()]
        return pr and pr.bg or "dark"
    end,
    roles = {
        {key = "giver", label = "Questgeber-Namen", default = {.45, .8, 1}},
        {key = "title", label = "Questnamen", default = {1, .82, 0}},
        {key = "head", label = "Überschriften", default = {1, .82, 0}},
        {key = "text", label = "Text", default = {1, 1, 1}},
        {key = "place", label = "Orte", default = {.85, .85, .85}},
        {key = "dist", label = "Entfernung und Zeit", default = {.85, .85, .85}},
        {key = "hint", label = "Hinweise", default = {.62, .62, .62}},
    },
    scale = {get = function() return G:DB().trackerScale or Tr.SCALE end, set = function(v) Tr:SetScale(v) end, step = .05},
    extra = {{label = "Weitere Einstellungen der Quest-Führung …", onClick = function() lev.Settings:Open() end}},
    onChange = function()
        local db = G:DB()
        local WL = ONE.WindowLook
        if WL then db.trackerBare = WL.Bg(Tr.LOOK) == "none" end
        Tr:Update(G.plan)
    end,
}
function Tr.Preset()
    local look = G:DB().trackerLook
    local v = type(look) == "table" and look.preset
    return Tr.PRESETS[v] and v or "guildtrip"
end
function Tr.PresetDef() return Tr.PRESETS[Tr.Preset()] or Tr.PRESETS.guildtrip end
function Tr:Bare()
    local WL = ONE.WindowLook
    if WL then return WL.Bg(Tr.LOOK) == "none" end
    return G:DB().trackerBare and true or false
end
-- Farbe einer Rolle (WindowLook) bzw. Farbcode fuer Text
function Tr.RoleColor(role)
    local WL = ONE.WindowLook
    if WL then return WL.Color(Tr.LOOK, role) end
    for _, r in ipairs(Tr.LOOK.roles) do if r.key == role then return r.default[1], r.default[2], r.default[3] end end
    return 1, 1, 1
end
function Tr.Code(role)
    local r, g, b = Tr.RoleColor(role)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5))
end
function Tr.Giver(name)
    if not name or name == "" then return name end
    return Tr.Code("giver") .. name .. "|r"
end

-- WoW-Questliste (je nach Client heisst sie anders)
Tr.BLIZZARD = {"ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame"}

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
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
    gear:SetScript("OnClick", function()
        if ONE.WindowLook then ONE.WindowLook:Toggle(Tr.LOOK, f) else lev.Settings:Toggle() end
    end)
    gear:SetScript("OnEnter", function(self)
        Tr:Frame(true)
        if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:AddLine(T("Aussehen und Einstellungen"), 1, .82, 0) GameTooltip:Show() end
    end)
    gear:SetScript("OnLeave", function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end)
    f.gear = gear
    f.arrow = ONE.Widgets:NaviArrow(f, 18, "TOPRIGHT", -28, -3, function() if Tr.step then G:Navi(Tr.step) end end,
        function() return T("Navi zum nächsten Schritt"), Tr.step and G:StepText(Tr.step, true) or "" end)
    f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.dist:SetPoint("RIGHT", f.arrow, "LEFT", -4, 0)
    -- Zahnrad nur beim Drueberfahren; Rechtsklick -> Menue (Quest-Seite, Einstellungen, Aussehen) – 22.11.2026
    if ONE.WindowLook and ONE.WindowLook.Attach then
        ONE.WindowLook:Attach(f, gear, {def = Tr.LOOK, frameClick = true, title = "Quest-Führung", category = "leveling",
            settings = {"lev.trackerBare", "lev.replaceBlizzard", "lev.autoNavi", "lev.autoQuest", "lev.autoQuestAll", "lev.gearQuests",
                "lev.recFirst", "lev.journal", "lev.tracker"}, menu = function()
            return {
                {text = "Quest-Seite öffnen", func = function() if ONE.UI then ONE.UI:Show() ONE.UI:OpenLink("leveling") end end},
                {text = "Einstellungen der Quest-Führung", func = function() lev.Settings:Toggle() end},
            }
        end})
    else
        f:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" and ONE.UI then ONE.UI:Show() ONE.UI:OpenLink("leveling") end
        end)
    end
    f:SetScript("OnEnter", function(self)
        Tr:Frame(true)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(T("Guild Trip: Quest-Führung"), 1, .82, 0)
            GameTooltip:AddLine(T("Ziehen = verschieben, Rechtsklick = Menü (Quest-Seite, Einstellungen, Aussehen), Pfeil = Navi."), 1, 1, 1, true)
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
        -- einzeilig, notfalls etwas enger; voller Text im Tooltip der Zeile (Tr:Hit)
        if ONE.Fit then ONE.Fit:Line(fs, false) end
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
    local on = self:Bare()
    for _, fs in ipairs(self.lines or {}) do self:Stroke(fs, on) end
    for _, fs in ipairs(self.rights or {}) do self:Stroke(fs, on) end
    if f.head then self:Stroke(f.head, on) end
    if f.dist then self:Stroke(f.dist, on) end
end

-- Rahmen zeigen? (immer, ausser "nur Text" – dann nur beim Drueberfahren)
function Tr:Frame(hover)
    local f = self.frame
    if not f then return end
    if ONE.WindowLook then ONE.WindowLook.ApplyBg(Tr.LOOK, f.bg, f.border, hover) return end
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
        local eta = self:EtaText(self.stepPlan, self.step) or ""
        if self.etaNarrow then eta = self.etaNarrow .. (eta ~= "" and ("  ·  " .. eta) or "") end
        fs:SetText(eta)
    end
    self:StrokeAll()
end

-- leicht getoenter Hintergrund mit farbiger Kante links: JETZT gold, ALS NAECHSTES silbergrau
Tr.MAX_OFF = 5 -- so viele Quests unter NICHT IM PLAN, dann "(+n)"
Tr.BLOCK_COLOR = {now = {1, .82, 0}, next = {.75, .75, .75}}
function Tr:Blocks(list)
    local f = self.frame
    if not f.CreateTexture then return end
    if Tr.PresetDef().noBlocks then list = {} end
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

-- Gegenstandsname (kommt evtl. erst vom Server nach)
function Tr.ItemName(id)
    local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and GetItemInfo(id))
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return name or ("#" .. id)
end

-- Inhalt als Zeilen {text, kind, right, nav, tip} – nach Quests aufgeteilt (Nutzer 17.11.2026):
--   JETZT          der eine Schritt, gross: Name, was/bei wem, Gebiet/Ort, Entfernung/Zeit
--   ALS NAECHSTES  die naechsten (hoechstens 3) Schritte, NPC rechts
--   (DEINE QUESTS entfallen 18.11.2026: alle Quests mit L im Spiel; Fortschritt der aktuellen unter JETZT)
-- Neue Forever-Gebiete ohne Questdaten (Nutzer 23.11.2026: "du darfst in diesen faellen gerne auf fehlende daten
-- hinweisen"). Karten-IDs: Zephras 2521, Flussauen 2548, Dunkelspeerinseln 2524, Shen'dralas 2652 – weder Questie
-- noch andere Quellen haben dort bisher Quests oder Questgeber.
Tr.NO_DATA = {[2521] = "zephras", [2548] = true, [2524] = true, [2652] = true}
function Tr.NoDataMap(mapID)
    local seen = 0
    while type(mapID) == "number" and seen < 6 do
        if Tr.NO_DATA[mapID] then return mapID end
        local ok, info = pcall(function() return C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID) end)
        mapID = ok and type(info) == "table" and info.parentMapID or nil
        seen = seen + 1
    end
end
function Tr.NoDataHint(mapID, faction)
    local m = Tr.NoDataMap(mapID)
    if not m then return nil end
    if Tr.NO_DATA[m] == "zephras" then
        if faction == "Horde" then
            return T("Für Zephras hat Guild Trip noch keine Questdaten. Danach geht es mit dem Zeppelin nach Donnerfels weiter.")
        end
        return T("Für Zephras hat Guild Trip noch keine Questdaten. Danach geht es mit dem Luftschiff aufs Festland weiter.")
    end
    return T("Für dieses Gebiet hat Guild Trip noch keine Questdaten.")
end
function Tr.PlayerMap()
    local ok, m = pcall(function() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end)
    return ok and m or nil
end
function Tr:Rows(plan, budget)
    local db = G:DB()
    local rows = {}
    local s1 = plan.steps[1]
    -- UEBER ALLEM (Nutzer 18.11.2026): Gebiet · Quests im Plan · Zeit · Stufe beim Verlassen,
    -- darunter die naechste Stufe (stand frueher unten)
    local zone, sub = Tr.ZoneLine(plan)
    local preset = Tr.PresetDef()
    if zone and not preset.noZone then
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
    local fok, fac = pcall(UnitFactionGroup, "player")
    local nd = Tr.NoDataHint(Tr.PlayerMap(), fok and fac or nil)
    if nd then
        rows[#rows + 1] = {text = Tr.Code("hint") .. nd .. "|r", kind = "who", block = "now",
            tip = T("Guild Trip zeigt hier Quests, sobald es Daten dafür gibt.")}
        rows[#rows + 1] = {kind = "nxGap"}
    end
    local bundle, bundleIdx, bundleLast = Tr.Bundle(plan)
    if not s1 then
        -- kein Schritt: Hinweis statt eines leeren Kastens mit nur der Ueberschrift (Spieltest 26.11.2026)
        rows[#rows + 1] = {text = T("Gerade kein nächster Schritt."), kind = "now", block = "now",
            tip = T("Die Führung findet hier gerade nichts Passendes. Sie rechnet nach jeder Quest, jeder neuen Stufe und jedem Gebietswechsel neu – sofort mit /reload.")}
        local hz = plan.hub and plan.hub.zone and G.ZoneName(plan.hub.zone)
        if hz then rows[#rows + 1] = {text = T("Questgebiet: %s", hz), kind = "who", block = "now"} end
    end
    if s1 then
        -- grosser Block (Nutzer 18.11.2026): Name gross, darunter was/bei wem, wo, wie weit/wie lange
        if not preset.noLabels then rows[#rows + 1] = {text = T("JETZT"), kind = "label", block = "now"} end
        local multi = s1.kind == "obj" and #(s1.actions or {}) > 1
        if multi then
            -- mehrere Quests an einem Ort (Nutzer 21.11.2026: ein Schritt = ein Ort). Nach Quest gruppiert
            -- (Nutzer 22.11.2026 "nicht uebersichtlich": Quest rechts wiederholt, Ziele abgeschnitten): je Quest
            -- der Name einmal in Questnamen-Farbe, darunter ihre Teilziele eingerueckt in voller Breite
            local tip = Tr.StepTip(plan, 1)
            for _, a in ipairs(s1.actions) do
                local nav = {step = s1, qid = a.id}
                rows[#rows + 1] = {text = Tr.Code("title") .. G.Title(a.id) .. "|r", kind = "obj2", nav = nav, block = "now", tip = tip}
                for _, o in ipairs(Tr.Objectives(a.id)) do
                    rows[#rows + 1] = {text = (o.done and "|cff808080" or "") .. o.text .. (o.done and "|r" or ""), kind = "obj",
                        nav = nav, block = "now", tip = tip}
                end
            end
            if s1.levelUp then rows[#rows + 1] = {text = T("danach Stufe %d", s1.levelUp), kind = "who", block = "now"} end
        else
            rows[#rows + 1] = {text = Tr.NowTitle(s1), kind = "now", nav = {step = s1}, block = "now", tip = Tr.StepTip(plan, 1)}
            local who = Tr.NowWho(s1)
            if who then rows[#rows + 1] = {text = who, kind = "who", block = "now"} end
        end
        local where = Tr.NowWhere(s1)
        if where then rows[#rows + 1] = {text = where, kind = "where", block = "now"} end
        rows[#rows + 1] = {text = Tr:EtaText(plan, s1) or "", kind = "eta", block = "now"}
        -- Fortschritt der Quest direkt unter der Quest (Nutzer 22.11.2026), Hinweise erst danach
        if s1.kind == "obj" and not multi then
            for _, a in ipairs(s1.actions) do
                for _, o in ipairs(Tr.Objectives(a.id)) do
                    rows[#rows + 1] = {text = (o.done and "|cff808080" or "") .. o.text .. (o.done and "|r" or ""), kind = "obj"}
                end
            end
        end
        -- Quests in derselben Gegend, die direkt danach kommen (Nutzer 23.11.2026: "gemeinsam im Kasten", wie die
        -- erste Quest, nur ohne Weg und Zeit – die Zeit steht fuer alle zusammen oben)
        for _, st in ipairs(bundle) do
            local tip
            for i, x in ipairs(plan.steps) do if x == st then tip = Tr.StepTip(plan, i) break end end
            rows[#rows + 1] = {kind = "nxGap", block = "now"}
            rows[#rows + 1] = {text = Tr.NowTitle(st), kind = "now", nav = {step = st}, block = "now", tip = tip}
            local who = Tr.NowWho(st)
            if who then rows[#rows + 1] = {text = who, kind = "who", block = "now"} end
            for _, a in ipairs(st.actions or {}) do
                for _, o in ipairs(Tr.Objectives(a.id)) do
                    rows[#rows + 1] = {text = (o.done and "|cff808080" or "") .. o.text .. (o.done and "|r" or ""), kind = "obj", block = "now"}
                end
            end
        end
        local warn = Tr.Warning(s1)
        if warn then rows[#rows + 1] = {text = warn, kind = "who", block = "now"} end
        -- Elite-Quests (Nutzer 24.11.2026): "Gruppe" und Knopf "Spaeter" – erstes Mal ans Ende der Runde, zweites Mal
        -- faellt sie aus dem Plan
        if plan.route and G.IsElite then
            local seen = {}
            for _, st in ipairs({s1, unpack(bundle)}) do
                for _, a in ipairs(st.actions or {}) do
                    if a.id and not seen[a.id] and a.kind ~= "turnin" and G.IsElite(a.id) then
                        seen[a.id] = true
                        local again = (G:LaterTable()[a.id] or 0) >= 1
                        rows[#rows + 1] = {text = "|cffff5a4a" .. T("GRUPPE") .. "|r " .. T("%s – keine Gruppe? Klick: später", G.Title(a.id)),
                            kind = "who", block = "now", click = function() G:LaterQuest(a.id) end,
                            tip = again and T("Schon einmal verschoben: noch ein Klick, dann fällt die Quest aus dem Plan.")
                                or T("Elite-Quest: allein schwer. Klick schiebt sie ans Ende der Runde; wird sie dann wieder nicht gemacht, fällt sie aus dem Plan.")}
                    end
                end
            end
        end
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
            rows[#rows + 1] = {text = Tr.Code("hint") .. T("Abbrechen lohnt: %s", table.concat(names, ", ")) .. more .. "|r", kind = "who", block = "now",
                tip = T("Bringt kaum noch etwas (grau, nur mit Gruppe oder sehr viel Aufwand). Klicken: abbrechen – mit Rückfrage, Guild Trip bricht nie von selbst ab."),
                click = function() G:AskAbandon(abIDs) end}
        end
        -- feste Route: neue Zauber beim Lehrer nur als Hinweis (kein Routen-Schritt), Klick = Navi zum Lehrer
        local th = plan.trainHint
        if th then
            local spot = th.spots and th.spots[1]
            rows[#rows + 1] = {text = Tr.Code("hint") .. T("Neue Zauber beim Lehrer (%d)", th.n) .. "|r", kind = "who", block = "now",
                tip = T("Kein Teil der Route – lerne sie, wenn du ohnehin in der Stadt bist. Klicken: Navi zum Lehrer."),
                click = spot and function()
                    local nav = ONE.modules and ONE.modules.nav
                    if nav and nav.PointTo then nav:PointTo(spot.name or T("Lehrer"), spot.mapID, spot.x, spot.y) end
                end or nil}
        end
        local vh = plan.vendorHint
        if vh then
            -- Taschen voll / fast voll / Haendler am Weg (Planer: kleinster Umweg zum naechsten Schritt, Nutzer 23.11.2026)
            local name = vh.name or "?"
            local text = vh.kind == "full" and T("Taschen voll – Händler: %s", name)
                or vh.kind == "way" and T("Händler am Weg: %s – Taschen leeren", name)
                or T("Taschen fast voll – Händler: %s", name)
            if (vh.detour or 0) >= 1 then text = text .. " " .. T("(+%d min)", math.floor(vh.detour + .5)) end
            rows[#rows + 1] = {text = Tr.Code("hint") .. text .. "|r", kind = "who", block = "now",
                tip = T("Verkaufen machst du selbst (oder der Plunder-Verkauf von Guild Trip). Klicken: Navi zum Händler."),
                click = function()
                    local nav = ONE.modules and ONE.modules.nav
                    if nav and nav.PointTo then nav:PointTo(vh.name or T("Händler"), vh.mapID, vh.x, vh.y) end
                end}
        end
        -- Dungeon-Quest oder Vorquest dorthin am Weg (Nutzer 23.11.2026): nur Hinweis, Klick = Navi zum Questgeber
        local dh = plan.dungeonHint
        if dh then
            local c = dh.dungeon and G.Catalog and G.Catalog(dh.dungeon)
            local text = c and c.name and T("Für %s am Weg: %s", c.name, G.Title(dh.id)) or T("Dungeon-Quest am Weg: %s", G.Title(dh.id))
            if (dh.more or 0) > 0 then text = text .. " " .. T("(+%d)", dh.more) end
            rows[#rows + 1] = {text = Tr.Code("hint") .. text .. "|r", kind = "who", block = "now",
                tip = T("Nicht in der Route – Dungeons planst du selbst (Dungeon-Seite). Liegt hier am Weg, falls du später hingehst. Klicken: Navi zum Questgeber."),
                click = function()
                    local nav = ONE.modules and ONE.modules.nav
                    if nav and nav.PointTo then nav:PointTo(G.Title(dh.id), dh.mapID, dh.x, dh.y) end
                end}
        end
        -- frueher ausgelassene Annahme am Weg (Nutzer 23.11.2026): nicht zurueckgeschickt, nur Hinweis, Klick = Navi
        local mh = plan.missedHint
        if mh then
            local text = T("Am Weg, früher ausgelassen: %s", G.Title(mh.id))
            if (mh.more or 0) > 0 then text = text .. " " .. T("(+%d)", mh.more) end
            rows[#rows + 1] = {text = Tr.Code("hint") .. text .. "|r", kind = "who", block = "now",
                tip = T("Gehört zu einem früheren Teil der Route. Du wirst nicht mehr dorthin zurückgeschickt – der Questgeber steht aber gerade am Weg. Klicken: Navi zum Questgeber."),
                click = function()
                    local nav = ONE.modules and ONE.modules.nav
                    if nav and nav.PointTo then nav:PointTo(G.Title(mh.id), mh.mapID, mh.x, mh.y) end
                end}
        end
        -- bessere Ausruestung aus einer Quest ausserhalb der Route (Nutzer 22.11.2026), Klick = Navi zum Questgeber
        local gh = plan.gearHint
        if gh and gh[1] then
            local h = gh[1]
            local more = #gh > 1 and (" " .. T("(+%d)", #gh - 1)) or ""
            local tip = {T("Nicht in der Route – lohnt sich, wenn du in der Nähe bist. Klicken: Navi zum Questgeber.")}
            for _, x in ipairs(gh) do
                tip[#tip + 1] = "• " .. T("%s: %s – %s", T(x.slot and x.slot.name or "?"), Tr.ItemName(x.item.id),
                    lev.Way and lev.Way.SourceText(x.src, true) or "") .. " (" .. (x.plus >= 100 and T("neu") or ("+" .. x.plus .. " %")) .. ")"
            end
            rows[#rows + 1] = {text = Tr.Code("hint") .. T("Besser für dich: %s", Tr.ItemName(h.item.id)) .. more .. "|r", kind = "who", block = "now",
                tip = table.concat(tip, "\n"),
                click = function() if lev.Way then lev.Way:Get(h.src, h.item.id) end end}
        end
    end
    -- ALS NAECHSTES (Nutzer 18.11.2026, statt "Noch annehmen"): die naechsten hoechstens MAX_NEXT
    -- Schritte der Fuehrung, wie sie kommen – aktualisiert sich mit dem Plan.
    local nexts = {}
    local nextIdx = {}
    for i = 2, #plan.steps do
        if #nexts >= (preset.maxNext or Tr.MAX_NEXT) then break end
        if not bundleIdx[i] then
            local st, prev = plan.steps[i], nexts[#nexts]
            if prev and Tr.SameNpc(prev, st) and nextIdx[#nexts] and i - nextIdx[#nexts] > 1 then
                -- zwei Besuche beim selben Questgeber direkt hintereinander (was dazwischen lag, steht im
                -- JETZT-Buendel): eine Zeile mit allen Quests (Nutzer 23.11.2026)
                local merged = setmetatable({actions = {}}, {__index = prev})
                for _, a in ipairs(prev.actions or {}) do merged.actions[#merged.actions + 1] = a end
                for _, a in ipairs(st.actions or {}) do merged.actions[#merged.actions + 1] = a end
                nexts[#nexts] = merged
                nextIdx[#nexts] = i
            else
                nexts[#nexts + 1] = st
                nextIdx[#nexts] = i
            end
        end
    end
    -- ALS NAECHSTES: so viele, wie in die Hoehe passen (mindestens einer); je Schritt ein kleiner Block
    -- wie JETZT (Name, was/bei wem, Ort · Zeit), blau statt gold (Nutzer 18.11.2026)
    -- NICHT IM PLAN (Nutzer 23.11.2026: "ganz runter als separate Spalte"): eigener Abschnitt unten, je
    -- angenommener Quest ausserhalb der Route eine Zeile. Klick = Abstecher (mit Rueckfrage), Rechtsklick = Menue
    local offRows = {}
    local off = (s1 and preset.maxNext ~= 0) and plan.offRoute or {}
    if #off > 0 then
        offRows[1] = {kind = "gap"}
        if not preset.noLabels then offRows[2] = {text = T("NICHT IM PLAN"), kind = "label", block = "off", blockColor = "next"} end
        local tip = T("Gehört nicht zur Route – du kannst sie nebenbei machen. Klick: Abstecher dorthin (mit Rückfrage), danach führt der Pfeil zurück zum Plan. Rechtsklick: Menü (Navi oder abbrechen, beides mit Rückfrage).")
        for i, o in ipairs(off) do
            if i > Tr.MAX_OFF and #off > Tr.MAX_OFF + 1 then
                offRows[#offRows + 1] = {text = Tr.Code("hint") .. T("(+%d)", #off - Tr.MAX_OFF) .. "|r", kind = "nxWho", block = "off", blockColor = "next", tip = tip}
                break
            end
            local id = o.id
            offRows[#offRows + 1] = {text = Tr.Code("hint") .. G.Title(id) .. "|r", kind = "nxWho", block = "off", blockColor = "next", off = id,
                tip = tip, click = function() Tr:AskDetour(id) end, menu = function(owner) Tr:OffMenu(owner, {id}) end}
        end
    end
    -- SPAETER (Stuetzpunkt-Fuehrung 26.11.2026): Quests im Log, die mit Absicht warten – zu hoch oder Ziel in einem
    -- anderen Gebiet. Eine Zeile, Gruende im Mouseover (kein Abbrechen-Vorschlag: sie kommen von selbst dran)
    local wait = (preset.maxNext ~= 0) and plan.waiting or {}
    if #wait > 0 then
        if #offRows == 0 then offRows[1] = {kind = "gap"} end
        local lines = {T("Angenommen, kommt später dran:")}
        for i, w in ipairs(wait) do
            if i > 12 then lines[#lines + 1] = T("(+%d)", #wait - 12) break end
            lines[#lines + 1] = G.Title(w.id) .. " – " .. Tr.WaitText(w, plan)
        end
        offRows[#offRows + 1] = {text = Tr.Code("hint") .. (#wait == 1 and T("Später: 1 Quest") or T("Später: %d Quests", #wait)) .. "|r",
            kind = "nxWho", block = "off", blockColor = "next", tip = table.concat(lines, "\n")}
    end
    local used = 0
    for _, r in ipairs(offRows) do used = used + Tr.St(r.kind)[5] end
    for _, r in ipairs(rows) do used = used + Tr.St(r.kind)[5] end
    local nl = preset.nextLines
    local per = Tr.St("nxTitle")[5] + ((not nl or nl.nxWho) and Tr.St("nxWho")[5] or 0)
        + ((not nl or nl.nxWhere) and Tr.St("nxWhere")[5] or 0) + Tr.St("nxGap")[5]
    local fit = #nexts
    if budget then
        local head = Tr.St("gap")[5] + (preset.noLabels and 0 or Tr.St("label")[5])
        fit = math.max(1, math.floor((budget - used - head) / per))
    end
    fit = math.min(fit, #nexts)
    if fit > 0 then
        local ins = {{kind = "gap"}}
        if not preset.noLabels then ins[2] = {text = T("ALS NÄCHSTES"), kind = "label"} end
        for k = 1, fit do
            local st = nexts[k]
            local id = "next" .. k
            if k > 1 then ins[#ins + 1] = {kind = "nxGap"} end
            ins[#ins + 1] = {text = Tr.NowTitle(st), kind = "nxTitle", nav = {step = st}, block = id, blockColor = "next", tip = Tr.StepTip(plan, nextIdx[k])}
            local who = Tr.NowWho(st)
            if who and (not nl or nl.nxWho) then ins[#ins + 1] = {text = who, kind = "nxWho", block = id, blockColor = "next"} end
            local where = Tr.NextWhere(st)
            if where and (not nl or nl.nxWhere) then ins[#ins + 1] = {text = where, kind = "nxWhere", block = id, blockColor = "next"} end
        end
        for _, r in ipairs(ins) do rows[#rows + 1] = r end
    end
    for _, r in ipairs(offRows) do rows[#rows + 1] = r end
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
    local hub = plan.hub
    if hub and hub.zone then
        local at = hub.at and Tr.NearName(hub.at[1], hub.at[2], hub.at[3])
        local zn = G.ZoneName(hub.zone)
        lines[#lines + 1] = at and T("Stützpunkt: %s (%s)", at, zn) or T("Gebiet: %s", zn)
        local normal = (lev.Hubs and lev.Hubs.AHEAD) or 2
        if (hub.ahead or normal) > normal then
            lines[#lines + 1] = T("Hier gibt es gerade nichts bis %d Stufen über dir – ausnahmsweise bis %d Stufen drüber.", normal, hub.ahead)
        end
    end
    local loop = step.loop
    if loop and loop > 0 then
        local objs, turnins, last = 0, 0, nil
        for k = i, #plan.steps do
            local st = plan.steps[k]
            if st.loop ~= loop and st.kind ~= "travel" then break end
            if st.kind == "obj" then objs = objs + math.max(1, #(st.actions or {})) end
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

-- mehrere Abgaben/Annahmen beim selben NPC: "Abgeben bei X", die Quests in Zeile 2 (Nutzer 21.11.2026)
function Tr.AtNPC(step)
    if not (step.kind == "accept" or step.kind == "turnin") or #(step.actions or {}) < 2 then return nil end
    local who = G.NodeName(step.nr)
    if not who then return nil end
    local acc, tin = false, false
    for _, a in ipairs(step.actions) do
        if a.kind == "accept" then acc = true elseif a.kind == "turnin" then tin = true end
    end
    -- Name zuerst (Spieltest 22.11.2026: am Ende abgeschnitten, die Questgeber-Farbe war nicht zu sehen)
    who = Tr.Giver(who)
    if acc and tin then return G.ICON.turnin .. " " .. T("%s: abgeben + annehmen", who) end
    if tin then return G.ICON.turnin .. " " .. T("%s: abgeben", who) end
    return G.ICON.accept .. " " .. T("%s: annehmen", who)
end
function Tr.NowTitle(step)
    if step.kind == "travel" or step.kind == "dungeon" or #(step.actions or {}) == 0 then return G:StepText(step, false, true) end
    local at = Tr.AtNPC(step)
    if at then return at end
    local icon, names = nil, {}
    for _, a in ipairs(step.actions or {}) do
        icon = icon or G.ICON[a.kind] or G.ICON.obj
        names[#names + 1] = G.LevelTitle(a.id)
    end
    return (icon and (icon .. " ") or "") .. table.concat(names, "  ·  ")
end

-- Start durch einen Gegenstand an festen Stellen (Questdaten Feld 16 = Gegenstand, Geber = die Fundstellen)
function Tr.PickupStart(id)
    local Q = rawget(_G, "GuildTripQuestDB")
    local e = Q and Q.q and Q.q[id]
    return e and e[16] and type(e[6]) == "table" and #e[6] > 0 or false
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
    if Tr.AtNPC(step) then
        local names = {}
        -- Questnamen in ihrer eigenen Farbe (Nutzer 22.11.2026), Trenner in Textfarbe
        for _, a in ipairs(step.actions) do names[#names + 1] = Tr.Code("title") .. G.Title(a.id) .. "|r" end
        return table.concat(names, " · ")
    end
    local verbs, seen = {}, {}
    for _, a in ipairs(step.actions or {}) do
        local v = Tr.VERB[a.kind]
        if v and not seen[v] then seen[v] = true verbs[#verbs + 1] = T(v) end
    end
    local verb = table.concat(verbs, " + ")
    local who = G.NodeName(step.nr)
    -- Quest beginnt mit einem Gegenstand, der dort liegt (z. B. Chens leeres Faesschen im Brachland, Nutzer 22.11.2026):
    -- aufheben, dann im Rucksack anklicken
    if step.kind == "accept" and who and #(step.actions or {}) == 1 and Tr.PickupStart(step.actions[1].id) then
        return T("%s aufheben, im Rucksack anklicken", who)
    end
    if step.kind == "obj" then return who and T("Ziel: %s", who) or (verb ~= "" and verb or nil) end
    if not who then return verb ~= "" and verb or nil end
    return verb .. " " .. T("bei %s", Tr.Giver(who))
end

-- naechster bekannter Ortsname (Flugpunkt/Stadt) zu einem Kartenpunkt; WoW nennt Ortsnamen
-- nur fuer die eigene Stelle, darum "nahe …"
Tr.NEAR = 900   -- Yards
-- Grund, warum eine angenommene Quest wartet (Stuetzpunkt-Fuehrung)
function Tr.WaitText(w, plan)
    local Q = rawget(_G, "GuildTripQuestDB")
    local e = Q and Q.q and Q.q[w.id]
    if w.why == "high" and e then return T("ab Stufe %d", math.max(1, (e[1] or 0) - ((plan.hub and plan.hub.ahead) or 1))) end
    if w.why == "zone" then return T("Ziel in einem anderen Gebiet") end
    if w.why == "turnin" then return T("Abgabe in einem anderen Gebiet") end
    if w.why == "class" then return T("Klassenquest – machst du selbst") end
    if w.why == "dungeon" then return T("Dungeon-Quest – nicht in der Führung") end
    return T("nächste Runde")
end
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
-- Buendel (Nutzer 23.11.2026): Ziel-Schritte (toeten/sammeln) der naechsten Schritte in derselben Gegend (hoechstens
-- BUNDLE_YD vom ersten Ziel). Abgaben/Annahmen dazwischen in der Gegend bleiben unter ALS NAECHSTES und beenden das
-- Buendel nicht (Spieltest: "Vrangs Spiel" abgeben lag zwischen zwei Zielen). Reise, Monster hauen u. a. beenden es.
-- Rueckgabe: Liste der Schritte, Menge der Indizes, letzter Index
Tr.BUNDLE_YD, Tr.BUNDLE_MAX, Tr.BUNDLE_LOOK = 350, 4, 8
function Tr.Bundle(plan)
    local out, idx, last = {}, {}, 1
    local steps = plan and plan.steps or {}
    local s1 = steps[1]
    local p1 = s1 and s1.pos
    -- auch wenn gerade eine Abgabe/Annahme dran ist (Spieltest 23.11.2026: "dann sollte ich die direkt abgeben,
    -- seitdem ist nichts mehr gebuendelt")
    if not (s1 and p1 and (s1.kind == "obj" or s1.kind == "turnin" or s1.kind == "accept")) then return out, idx, last end
    local function Near(c, x, y) return c == p1[1] and (x - p1[2]) ^ 2 + (y - p1[3]) ^ 2 <= Tr.BUNDLE_YD * Tr.BUNDLE_YD end
    local seen = {}
    for _, a in ipairs(s1.actions or {}) do if a.id then seen[a.id] = true end end
    local accepted = {}
    for i = 2, math.min(#steps, 1 + Tr.BUNDLE_LOOK) do
        local st = steps[i]
        local p = st.pos
        for _, a in ipairs(st.actions or {}) do if a.kind == "accept" and a.id then accepted[a.id] = true end end
        if #out >= Tr.BUNDLE_MAX or st.via or not p or p[1] ~= p1[1]
            or not (st.kind == "obj" or st.kind == "turnin" or st.kind == "accept")
            or (p[2] - p1[2]) ^ 2 + (p[3] - p1[3]) ^ 2 > Tr.BUNDLE_YD * Tr.BUNDLE_YD then break end
        if st.kind == "obj" then
            -- nur Quests, die schon im Log sind: wird sie vorher im Plan erst angenommen, gehoert sie nicht in JETZT
            -- (Spieltest 23.11.2026: "Aerger im Tal" stand in JETZT, obwohl Walton sie erst noch vergibt)
            local again = false
            for _, a in ipairs(st.actions or {}) do if a.id and (seen[a.id] or accepted[a.id]) then again = true end end
            if not again then
                for _, a in ipairs(st.actions or {}) do if a.id then seen[a.id] = true end end
                out[#out + 1], idx[i], last = st, true, i
            end
        end
    end
    -- Quests im Log, die der Plan erst spaeter vorsieht, deren Gegner aber hier stehen (Spieltest 23.11.2026:
    -- "Raptorhoerner" – Raptoren genau hier, Plan erst kurz vor Ratschet): mit in JETZT; erledigt faellt der
    -- spaetere Schritt dann von selbst weg
    local acceptedBefore = {}
    for i = 2, #steps do
        if #out >= Tr.BUNDLE_MAX then break end
        local st = steps[i]
        if st.kind == "obj" and not idx[i] then
            local fresh = true
            for _, a in ipairs(st.actions or {}) do
                if not a.id or seen[a.id] or acceptedBefore[a.id] or not Tr.LevelOK(a.id) then fresh = false end
            end
            local near = fresh and st.pos and Near(st.pos[1], st.pos[2], st.pos[3])
            if fresh and not near then
                for _, q in ipairs(st.area or {}) do if Near(q[1], q[2], q[3]) then near = true break end end
            end
            if near then
                for _, a in ipairs(st.actions or {}) do seen[a.id] = true end
                out[#out + 1], idx[i] = st, true
            end
        end
        for _, a in ipairs(st.actions or {}) do if a.kind == "accept" and a.id then acceptedBefore[a.id] = true end end
    end
    return out, idx, last
end
-- Gegner nicht zu stark (wie der Planer: Queststufe hoechstens OBJ_AHEAD ueber der eigenen)
function Tr.LevelOK(id)
    local q = GuildTripQuestDB and GuildTripQuestDB.q and GuildTripQuestDB.q[id]
    local me = type(UnitLevel) == "function" and UnitLevel("player") or nil
    if not (q and type(q[1]) == "number" and type(me) == "number") then return true end
    local P = lev.Planner
    return q[1] <= me + (P and P.OBJ_AHEAD or 2)
end
-- gleicher Questgeber, beides nur Abgeben/Annehmen (kein Ziel, keine Reise dazwischen)
function Tr.SameNpc(a, b)
    if not (a and b and a.nr and a.nr == b.nr) or b.via then return false end
    local ok = {turnin = true, accept = true}
    return ok[a.kind] and ok[b.kind] and true or false
end
-- Zeile Entfernung/Zeit unter JETZT: mit Buendel eine Zeit fuer alle, sonst wie bisher (auch beim 2-s-Auffrischen)
function Tr:EtaText(plan, s1)
    local text
    if plan and plan.steps and plan.steps[1] == s1 then
        local bundle, idx, last = Tr.Bundle(plan)
        if #bundle > 0 then text = self:BundleEta(plan, s1, idx, last) end
    end
    text = text or self:NowEta(s1)
    local timer = Tr.TimerText(s1)
    if timer then text = timer .. (text and text ~= "" and ("  ·  " .. text) or "") end
    return text
end
-- Zeitquest (23.11.2026): Restzeit vorn in der Zeile, unter 5 min rot – frisch aus dem Spiel bei jedem Auffrischen
function Tr.TimerText(step, timers)
    if not step then return nil end
    timers = timers or (G.QuestTimers and G.QuestTimers()) or {}
    local left
    for _, a in ipairs(step.actions or {}) do
        local t = a.id and timers[a.id]
        if t and (not left or t < left) then left = t end
    end
    if not left then return nil end
    local m = math.floor(left / 60)
    local text = m >= 1 and T("Zeitlimit: noch %d min", m) or T("Zeitlimit: noch %d s", math.floor(left))
    return (left < 300 and "|cffff3030" or "|cffffd100") .. text .. "|r"
end
-- Zeit fuer alle Quests im Buendel: Weg zum ersten Ziel + Wege dazwischen + Toeten/Sammeln (aus dem Plan)
function Tr:BundleEta(plan, s1, bundleIdx, last)
    local d = G:Distance(s1)
    local mounted = IsMounted and IsMounted()
    local min = d and d / (mounted and 11 or 7) / 60 or 0
    local P, info = lev.Planner, plan.info or {}
    local kill = P and P.KILL_SEC or 22
    local n = 0
    for k = 1, last or 1 do
        local st = plan.steps[k]
        if k > 1 then min = min + (st.walk or 0) end
        for _, a in ipairs(st.actions or {}) do
            local o = info[a.id]
            if a.kind == "obj" and (k == 1 or bundleIdx[k]) then n = n + 1 if o and o.work then min = min + o.work * kill / 60 end end
            if a.kind ~= "obj" then min = min + (P and P.TALK_MIN or 0) end
        end
    end
    -- spaeter geplante, hier mitgenommene Quests: nur ihre Zeit fuer Toeten/Sammeln
    for k in pairs(bundleIdx) do
        if k > (last or 1) then
            for _, a in ipairs(plan.steps[k].actions or {}) do
                local o = info[a.id]
                if a.kind == "obj" then n = n + 1 if o and o.work then min = min + o.work * kill / 60 end end
            end
        end
    end
    local parts = {}
    if d then parts[1] = math.floor(d + .5) .. " " .. T("m") end
    parts[#parts + 1] = T("ca. %d min für alle %d Quests", math.max(1, math.floor(min + .5)), n)
    return table.concat(parts, "  ·  ")
end
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
    obj2 = {"GameFontHighlight", 1, 1, 1, 16, 14},
    next = {"GameFontHighlightSmall", .9, .9, .9, 15, 10},
    label = {"GameFontNormalSmall", 1, .82, 0, 15, 10},
    log = {"GameFontHighlightSmall", .9, .9, .9, 15, 10},
    dim = {"GameFontHighlightSmall", .6, .6, .6, 15, 10},
    foot = {"GameFontDisableSmall", .6, .6, .6, 14, 10},
    gap = {"GameFontHighlightSmall", 0, 0, 0, 6, 10},
}

-- Farbe je Zeilenart (Rollen in Tr.LOOK, frei waehlbar ueber das Zahnrad)
Tr.KIND_ROLE = {now = "title", nxTitle = "title", who = "text", nxWho = "text", obj = "text", obj2 = "text", next = "text",
    log = "text", where = "place", nxWhere = "place", eta = "dist", zone = "head", label = "head", zoneSub = "hint", dim = "hint", foot = "hint"}
-- Schrift/Hoehe/Einrueckung einer Zeilenart: Vorlage ueberschreibt {Schrift, Hoehe, Einrueckung}
function Tr.St(kind)
    local base = Tr.STYLE[kind] or Tr.STYLE.next
    local o = Tr.PresetDef().style
    o = o and o[kind]
    if not o then return base end
    return {o[1], base[2], base[3], base[4], o[2], o[3]}
end

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

-- ===== Abstecher zu einer Quest ausserhalb des Plans (Nutzer 22.11.2026) =====
-- Pfeil zur Quest (offene Ziele, fertig: Abgabe); ist sie abgegeben oder abgebrochen, zurueck zum Plan.
-- Der Plan selbst bleibt unveraendert.
local function InLog(id)
    local QL = C_QuestLog
    if QL and type(QL.GetLogIndexForQuestID) == "function" then
        local ok, idx = pcall(QL.GetLogIndexForQuestID, id)
        return ok and type(idx) == "number" and idx > 0
    end
    return true
end
local function Complete(id)
    local QL = C_QuestLog
    if QL and type(QL.IsComplete) == "function" then local ok, v = pcall(QL.IsComplete, id) return ok and v == true end
    return false
end
function Tr:Detour(id)
    if not id then return false end
    local nv = ONE.ns and ONE.ns.nav
    if not (nv and nv.Quests and nv.Quests.Navi) then return false end
    local title = G.Title(id)
    local done = Complete(id)
    local ok = nv.Quests:Navi({id = id, title = title, complete = done})
    if ok then
        local A = nv.Arrow
        self.detour = {id = id, complete = done, label = A and A.target or title}
        ONE:Print(T("Abstecher: %s – danach führt der Pfeil zurück zum Plan.", title))
    end
    return ok
end
-- mit Rueckfrage (Nutzer 22.11.2026: "vor dem Abstecher auch eine Rueckfrage"); ohne Rueckfrage-Fenster direkt
function Tr:AskDetour(id)
    if not id then return false end
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return self:Detour(id) end
    StaticPopupDialogs.GUILDTRIP_DETOUR = {
        text = T("Abstecher zu „%s“?", G.Title(id)) .. "\n\n" .. T("Der Plan bleibt, wie er ist. Wenn du die Quest abgegeben hast, führt der Pfeil zurück zum Plan."),
        button1 = T("Ja"), button2 = T("Nein"),
        OnAccept = function() Tr:Detour(id) end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }
    StaticPopup_Show("GUILDTRIP_DETOUR")
    return true
end
-- bei jedem Neuplanen: Abstecher weiterfuehren (fertig -> zur Abgabe) oder beenden (abgegeben -> zurueck zum Plan)
function Tr:CheckDetour(plan)
    local d = self.detour
    if not d then return end
    local nv = ONE.ns and ONE.ns.nav
    local A = nv and nv.Arrow
    -- Spieler hat inzwischen selbst ein anderes Ziel gewaehlt: Abstecher vergessen
    if A and A.active and A.target ~= d.label then self.detour = nil return end
    if not InLog(d.id) then
        self.detour = nil
        local s1 = plan and plan.steps and plan.steps[1]
        if s1 then
            G.autoKey = nil
            G:Navi(s1, true)
            ONE:Print(T("Abstecher erledigt – weiter mit dem Plan."))
        end
        return "back"
    end
    if not d.complete and Complete(d.id) then
        d.complete = true
        if nv.Quests and nv.Quests.Navi and nv.Quests:Navi({id = d.id, title = G.Title(d.id), complete = true}) then
            d.label = A and A.target or d.label
        end
        return "turnin"
    end
end
-- Rechtsklick-Menue: je Quest "Navi hierhin" und "Abbrechen …" (Abbrechen immer mit Rueckfrage)
function Tr:OffMenu(owner, ids)
    if type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
            if root.CreateTitle then root:CreateTitle(T("Nicht im Plan")) end
            for _, id in ipairs(ids) do
                local title = G.Title(id)
                root:CreateButton(T("Navi hierhin: %s", title), function() Tr:AskDetour(id) end)
                root:CreateButton(T("Abbrechen: %s …", title), function() G:AskAbandon({id}) end)
            end
        end)
        if ok then return true end
    end
    -- ohne Menue: wie bisher abbrechen mit Rueckfrage
    return G:AskAbandon(ids)
end

-- Quests einer Zeile (zum Abwaehlen)
function Tr.QuestIDs(nav)
    local out = {}
    if not nav then return out end
    -- Zeile einer einzelnen Quest (Teilziel bei mehreren Quests an einem Ort): nur diese
    if nav.qid then out[1] = nav.qid return out end
    for _, a in ipairs(nav.step and nav.step.actions or {}) do if a.id then out[#out + 1] = a.id end end
    return out
end

-- Questtext aus dem Questlog fuer den Tooltip (Nutzer 25.11.2026: "beim drueberfahren den kompletten text",
-- statt das Questlog zu oeffnen). Forever: GetQuestLogQuestText(index) liefert Beschreibung und Questziel ohne
-- Auswahl im Questlog. Nur fuer angenommene Quests – vorher gibt WoW den Text nicht heraus.
Tr.qtextCache = {}
function Tr.QuestText(id)
    if type(id) ~= "number" then return nil end
    local c = Tr.qtextCache[id]
    if c then return c[1], c[2] end
    local QL, get = rawget(_G, "C_QuestLog"), rawget(_G, "GetQuestLogQuestText")
    if not (QL and type(QL.GetLogIndexForQuestID) == "function" and type(get) == "function") then return nil end
    local ok, idx = pcall(QL.GetLogIndexForQuestID, id)
    if not ok or type(idx) ~= "number" or idx <= 0 then return nil end
    local ok2, desc, obj = pcall(get, idx)
    if not ok2 then return nil end
    desc = type(desc) == "string" and desc:gsub("^%s+", ""):gsub("%s+$", "") or ""
    obj = type(obj) == "string" and obj:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if desc == "" and obj == "" then return nil end
    Tr.qtextCache[id] = {desc, obj}
    return desc, obj
end
-- Zeilen, die eine Quest benennen (Titel), bekommen den Questtext in den Tooltip
Tr.QTEXT_KIND = {now = true, nxTitle = true, obj2 = true}
function Tr.TextQuests(r)
    if r.off then return {r.off} end
    if not Tr.QTEXT_KIND[r.kind] then return {} end
    return Tr.QuestIDs(r.nav)
end
function Tr.AddQuestText(tt, ids)
    local shown = 0
    for _, id in ipairs(ids or {}) do
        local desc, obj = Tr.QuestText(id)
        if desc and shown < 3 then
            shown = shown + 1
            tt:AddLine(" ")
            if #ids > 1 then tt:AddLine(G.Title(id), 1, .82, 0) end
            if obj ~= "" then
                tt:AddLine(T("Questziel"), 1, .82, 0)
                tt:AddLine(obj, 1, 1, 1, true)
            end
            if desc ~= "" then
                tt:AddLine(T("Beschreibung"), 1, .82, 0)
                tt:AddLine(desc, .85, .85, .85, true)
            end
        end
    end
    return shown
end

function Tr:Hit(i, r, st, y, W)
    self.hits = self.hits or {}
    local b = self.hits[i]
    -- gekuerzte Zeile: Flaeche fuer den Tooltip mit dem ganzen Text (22.11.2026: nichts abgeschnitten lassen)
    local fs, right = self.lines[i], self.rights and self.rights[i]
    local Cut = ONE.Fit and ONE.Fit.Truncated
    local cut = Cut and ((fs and fs:IsShown() and Cut(fs)) or (right and right:IsShown() and Cut(right)))
    if not (r.nav or r.tip or r.click or cut) then if b then b:Hide() end return end
    if not b then
        b = CreateFrame("Button", nil, self.frame)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function() Tr.frame:StartMoving() end)
        b:SetScript("OnDragStop", function() Tr.frame:StopMovingOrSizing() Tr:SavePos() end)
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if self.menu then self.menu(self) return end
                -- Quest(s) dieser Zeile abwaehlen (mit Rueckfrage); ohne Quest: Quest-Seite wie am Rand
                local ids = Tr.QuestIDs(self.nav)
                if #ids > 0 then G:AskSkip(ids) elseif ONE.UI then ONE.UI:Show() ONE.UI:OpenLink("leveling") end
                return
            end
            -- Umschalt+Klick: Quest(s) der Zeile in den Chat (Nutzer 23.11.2026)
            if ONE.ChatLinkClick and ONE:ChatLinkClick() and G.LinkQuests and G.LinkQuests(Tr.QuestIDs(self.nav)) then return end
            if self.click then self.click() else Tr.NaviTo(self.nav) end
        end)
        b:SetScript("OnEnter", function(self)
            Tr:Frame(true)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            if (self.title or "") ~= "" then GameTooltip:AddLine(self.title, 1, .82, 0) end
            if self.tip then GameTooltip:AddLine(self.tip, 1, 1, 1, true) end
            if Tr.AddQuestText(GameTooltip, self.qids) > 0 then GameTooltip:AddLine(" ") end
            if self.nav then GameTooltip:AddLine(T("Klick: Navi dorthin"), .6, .6, .6) end
            if #Tr.QuestIDs(self.nav) > 0 then GameTooltip:AddLine(T("Umschalt+Klick: Quest in den Chat"), .6, .6, .6) end
            if #Tr.QuestIDs(self.nav) > 0 then GameTooltip:AddLine(T("Rechtsklick: Quest abwählen"), .6, .6, .6) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() Tr:Frame(false) if GameTooltip then GameTooltip:Hide() end end)
        self.hits[i] = b
    end
    b.nav, b.tip, b.click, b.menu = r.nav, r.tip, r.click, r.menu
    b.qids = Tr.TextQuests(r)
    if ONE.Fit then
        b.__fitTexts = {fs, right}
        if not b.__fitHooked then ONE.Fit:Line(fs, b) end
    end
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
    self.step, self.stepPlan = plan.steps[1], plan
    if not resizing then pcall(self.CheckDetour, self, plan) end
    local W = (f.GetWidth and f:GetWidth()) or G:DB().trackerWidth or Tr.WIDTH
    local H = (f.GetHeight and f:GetHeight()) or G:DB().trackerHeight or Tr.HEIGHT
    if type(W) ~= "number" or W <= 0 then W = G:DB().trackerWidth or Tr.WIDTH end
    if type(H) ~= "number" or H <= 0 then H = G:DB().trackerHeight or Tr.HEIGHT end
    -- Kopfzeile: Titel kuerzen, damit er im schmalen Kasten nicht unter Entfernung/Pfeil/Zahnrad laeuft
    if f.head.SetWidth then f.head:SetWidth(math.max(40, W - 110)) end
    if ONE.Fit and not f.head.__fitLine then ONE.Fit:Line(f.head, false) end
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
        local st = Tr.St(r.kind)
        if fs.SetFontObject and _G[st[1]] then fs:SetFontObject(_G[st[1]]) end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", st[6], y)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, y)
        -- rechte Spalte: so breit wie noetig, hoechstens 45 %
        -- rechte Spalte: einzeilig, notfalls mit "…" gekuerzt; im schmalen Kasten faellt die NPC-Spalte
        -- bei "Noch annehmen" weg (steht dann im Tooltip) – nie umbrechen/ueberlappen (Nutzer 18.11.2026)
        local rw = 0
        if ONE.Fit and not right.__fitLine then ONE.Fit:Line(right, false) end
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
        local role = Tr.KIND_ROLE[r.kind]
        if role then fs:SetTextColor(Tr.RoleColor(role)) else fs:SetTextColor(st[2], st[3], st[4]) end
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
    -- Klickflaechen gibt es nur fuer Zeilen mit Klick/Tooltip (Luecken): nie per # zaehlen (Spieltest 24.11.2026,
    -- Lua-Fehler "attempt to index field '?'")
    for _, list in ipairs({self.lines, self.rights or {}, self.hits or {}}) do
        for i, w in pairs(list) do if type(i) == "number" and i > #rows and w.Hide then w:Hide() end end
    end
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
