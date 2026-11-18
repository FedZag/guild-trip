local _, ONE = ...

-- Guild Trip 0.8: ein Aussehen ("Nachtroute"), vier Farbsaetze.
-- Ein Skin tauscht nur Farben. Alle Flaechen bestehen aus weissen Texturen
-- (Textures/Skin, scripts/build_skin.py), die hier eingefaerbt werden:
--   * runde Ecken: Neun-Teile-Flaeche aus Round.tga
--   * Rand: dieselbe Flaeche in Randfarbe, 1 px groesser, darunter
--   * Tiefe: weicher Schatten (Shadow.tga) und Licht von oben (Sheen.tga)
local Skin = { surfaces = {}, listeners = {} }
ONE.Skin = Skin

local TEX = "Interface\\AddOns\\ONE_Core\\Textures\\Skin\\"
Skin.tex = {
    round = TEX .. "Round", shadow = TEX .. "Shadow", sheen = TEX .. "Sheen",
    dot = TEX .. "Dot", glow = TEX .. "Glow",
}

local function Hex(h)
    h = h:gsub("#", "")
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
local function P(t)
    local out = {}
    for k, v in pairs(t) do out[k] = (type(v) == "string" and v:sub(1, 1) == "#") and Hex(v) or v end
    return out
end
Skin.Hex = Hex

-- Rollen: top Kopfleiste, side Gildenspalte, win Fenster, panel Karte, ctl Knopf,
-- ctlText Knopfschrift, text/soft/muted Schrift, title Ueberschriften, accent Akzent,
-- onAccent Schrift auf Akzent, primary/primaryText Hauptknopf, strip Routenleiste,
-- list Liste links, frame Fensterrand, ok/warn/bad Zustaende.
local BASE = {
    ok = "#6bd999", warn = "#fabf4d", bad = "#f57373",
    npc = "#94c9ff", quest = "#ffd673", item = "#c7adff", place = "#f5ad85", portal = "#a385ff",
    hair = .09, sel = .11, hover = .06,
}
local function With(t)
    local p = P(BASE)
    for k, v in pairs(P(t)) do p[k] = v end
    p.ctlText = p.ctlText or p.text
    p.primary = p.primary or p.accent
    p.primaryText = p.primaryText or p.onAccent
    p.title = p.heading or p.text
    return p
end

Skin.palettes = {
    night = With({ name = "Nachtroute",
        top = "#0f1320", side = "#131826", win = "#171c2b", panel = "#1b2132", ctl = "#232b40",
        text = "#f5f6fb", soft = "#c0c7d9", muted = "#98a0b6", accent = "#efb24f", onAccent = "#120d05",
        strip = "#141a2b", list = "#151a29", frame = "#0a0d16" }),
    classic = With({ name = "Klassisch",
        top = "#0e0c09", side = "#12100c", win = "#0b0a08", panel = "#17140f", ctl = "#6e1210", ctlText = "#ffd100",
        text = "#ffffff", soft = "#d6cfbf", muted = "#968c7a", accent = "#ffd100", onAccent = "#1a1000",
        primary = "#8f1612", primaryText = "#ffd100", heading = "#ffd100",
        strip = "#14110b", list = "#100e0a", frame = "#5c4a22", hair = .16, sel = .10 }),
    horde = With({ name = "Horde",
        top = "#140908", side = "#190c0a", win = "#1b0f0c", panel = "#241410", ctl = "#3b1c15",
        text = "#fbf3ee", soft = "#d8c4ba", muted = "#a48a7e", accent = "#e8743b", onAccent = "#1a0802",
        strip = "#1d0d0a", list = "#170b09", frame = "#2a0f0a", hair = .10 }),
    alliance = With({ name = "Allianz",
        top = "#08101f", side = "#0c1529", win = "#0f1a31", panel = "#13213e", ctl = "#1f3159",
        text = "#f3f6ff", soft = "#c3cde6", muted = "#8e9bbb", accent = "#d9b45a", onAccent = "#120c02",
        strip = "#0b1428", list = "#0d1730", frame = "#050a16", hair = .11 }),
}
Skin.order = { "auto", "night", "classic", "horde", "alliance" }
Skin.labels = { auto = "Nach Fraktion", night = "Nachtroute", classic = "Klassisch (Blizzard)", horde = "Horde", alliance = "Allianz" }

local function Store()
    if not ONE.db then return {} end
    if type(ONE.db.theme) ~= "table" then ONE.db.theme = {} end
    return ONE.db.theme
end

function Skin:Choice()
    local s = Store().skin
    return self.palettes[s] and s or "auto"
end
function Skin:Id()
    local choice = self:Choice()
    if choice ~= "auto" then return choice end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Horde" then return "horde" end
    if faction == "Alliance" then return "alliance" end
    return "night"
end
function Skin:Palette() return self.palettes[self:Id()] end
function Skin:Set(id)
    if id ~= "auto" and not self.palettes[id] then return false end
    Store().skin = id
    self:ApplyAll()
    return true
end

-- Farbe einer Rolle; Haarlinien-Rollen (hair/sel/hover) sind Weiss mit Deckkraft.
function Skin:Color(role)
    local p = self:Palette()
    local c = p[role]
    if type(c) == "number" then return 1, 1, 1, c end
    c = c or p.text
    return c[1], c[2], c[3], 1
end
-- Deckende Mischung aus Grundfarbe und Weiss (Rand ohne Durchscheinen).
function Skin:Mix(role, amount)
    local p = self:Palette()
    local c = p[role] or p.panel
    return c[1] + (1 - c[1]) * amount, c[2] + (1 - c[2]) * amount, c[3] + (1 - c[3]) * amount, 1
end

-- ===== Neun-Teile-Flaeche =====
-- corner: Eckgroesse auf dem Bildschirm; src: Eckanteil in der Textur (0..0.5)
local NINE = {
    { "TOPLEFT", 0, 1, 0, 1 }, { "TOP", 1, 2, 0, 1 }, { "TOPRIGHT", 2, 3, 0, 1 },
    { "LEFT", 0, 1, 1, 2 }, { "CENTER", 1, 2, 1, 2 }, { "RIGHT", 2, 3, 1, 2 },
    { "BOTTOMLEFT", 0, 1, 2, 3 }, { "BOTTOM", 1, 2, 2, 3 }, { "BOTTOMRIGHT", 2, 3, 2, 3 },
}
local Nine = {}
Nine.__index = Nine
function Skin:Nine(frame, texture, src, layer, sub)
    local n = setmetatable({ frame = frame, pieces = {}, src = src }, Nine)
    local stops = { 0, src, 1 - src, 1 }
    for i, d in ipairs(NINE) do
        local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        t:SetTexture(texture)
        if t.SetTexCoord then t:SetTexCoord(stops[d[2] + 1], stops[d[3] + 1], stops[d[4] + 1], stops[d[5] + 1]) end
        n.pieces[i] = t
    end
    return n
end
-- Legt die Teile um 'anchor' (Standard: frame), nach aussen erweitert um 'out' (oder -innen).
function Nine:Place(corner, out, anchor, dy)
    local a, p, o, y = anchor or self.frame, self.pieces, out or 0, dy or 0
    for _, t in ipairs(p) do t:ClearAllPoints() end
    p[1]:SetPoint("TOPLEFT", a, "TOPLEFT", -o, o + y) p[1]:SetSize(corner, corner)
    p[3]:SetPoint("TOPRIGHT", a, "TOPRIGHT", o, o + y) p[3]:SetSize(corner, corner)
    p[7]:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", -o, -o + y) p[7]:SetSize(corner, corner)
    p[9]:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", o, -o + y) p[9]:SetSize(corner, corner)
    p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT") p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
    p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT") p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
    p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT") p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
    p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT") p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
    p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT") p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT")
    return self
end
function Nine:SetColor(r, g, b, a)
    for _, t in ipairs(self.pieces) do t:SetVertexColor(r, g, b, a or 1) end
end
function Nine:SetShown(on)
    for _, t in ipairs(self.pieces) do if on then t:Show() else t:Hide() end end
end

-- ===== Flaechen =====
-- opts: fill (Rolle, Standard "panel"), alpha, radius (Standard 6), border (true),
-- shadow (true = Karte, "window" = Fenster, false), sheen (true), inset (Flaeche
-- um n px nach innen), flat (keine Rundung: Kopfleiste, Spalten).
function Skin:Surface(frame, opts)
    if not (frame and frame.CreateTexture) then return nil end
    opts = opts or {}
    local s = { frame = frame, opts = opts }
    local r = opts.flat and 0 or (opts.radius or 6)
    if opts.shadow ~= false and opts.shadow ~= nil then
        local big = opts.shadow == "window"
        s.shadow = self:Nine(frame, self.tex.shadow, .375, "BACKGROUND", -8)
        s.shadow:Place(big and 30 or 18, big and 14 or 8, nil, big and -6 or -3)
    end
    if r > 0 then
        if opts.border ~= false then s.edge = self:Nine(frame, self.tex.round, .25, "BACKGROUND", -7):Place(r + 1, 1 - (opts.inset or 0)) end
        s.fill = self:Nine(frame, self.tex.round, .25, "BACKGROUND", -6):Place(r, -(opts.inset or 0))
    else
        s.flatFill = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        s.flatFill:SetAllPoints(frame)
    end
    if opts.sheen ~= false then
        s.sheen = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        s.sheen:SetTexture(self.tex.sheen)
        s.sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", math.max(1, r), -1)
        s.sheen:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -math.max(1, r), -1)
        s.sheen:SetHeight(opts.sheenHeight or 28)
    end
    self.surfaces[#self.surfaces + 1] = s
    self:Paint(s)
    return s
end

function Skin:Paint(s)
    local o = s.opts
    local role = o.fill or "panel"
    local r, g, b = self:Color(role)
    local a = o.alpha or 1
    if s.fill then s.fill:SetColor(r, g, b, a) end
    if s.flatFill then s.flatFill:SetColorTexture(r, g, b, a) end
    if s.edge then
        local p = self:Palette()
        local er, eg, eb = self:Mix(role, (o.borderRole == "accent") and 0 or (p.hair or .09))
        if o.borderRole == "accent" then er, eg, eb = self:Color("accent") end
        s.edge:SetColor(er, eg, eb, a)
    end
    if s.shadow then s.shadow:SetColor(0, 0, .02, o.shadow == "window" and .7 or .5) end
    if s.sheen then s.sheen:SetVertexColor(1, 1, 1, o.sheenAlpha or .05) end
end

-- Spaeter Farbwechsel (z. B. Knopf hover / Auswahl)
function Skin:Refill(s, role, alpha)
    if not s then return end
    s.opts.fill, s.opts.alpha = role, alpha or s.opts.alpha
    self:Paint(s)
end

function Skin:OnChange(fn) self.listeners[#self.listeners + 1] = fn end

function Skin:ApplyAll()
    for _, s in ipairs(self.surfaces) do self:Paint(s) end
    for _, fn in ipairs(self.listeners) do pcall(fn) end
    if ONE.Themes and ONE.Themes.ApplyAll then ONE.Themes:ApplyAll() end
end

-- Farbiger Text in WoW-Schreibweise: Skin:Wrap("accent", "Text")
function Skin:Wrap(role, text)
    local r, g, b = self:Color(role)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5), text or "")
end
