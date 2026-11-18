local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Guild Trip 0.7.1: Aussehen "Glas" (Nutzer-Wunsch 18.11.2026, Richtung Subnautica):
-- durchsichtig getoentes Glas ueber der Spielwelt, links die Bereiche als runde,
-- leuchtende Symbole, in der Mitte die Unterseiten des Bereichs, rechts der Inhalt.
-- Ein Skin tauscht nur drei Farben: Toenung (Glas), Leuchtfarbe (Auswahl, Ringe,
-- Balken, Knoepfe) und Ueberschrift. Die Deckkraft des Glases ist ein eigener Regler,
-- weil WoW den Hintergrund nicht weichzeichnen kann (Lesbarkeit ueber bunter Welt).
-- Alle Flaechen sind weisse Texturen (Textures/Skin, scripts/build_skin.py), die hier
-- eingefaerbt werden; ein Farbwechsel braucht deshalb kein Neuladen.
local Glass = { surfaces = {}, listeners = {} }
ONE.Glass = Glass

local TEX = "Interface\\AddOns\\ONE_Core\\Textures\\Skin\\"
Glass.tex = {
    round = TEX .. "Round", roundRing = TEX .. "RoundRing", shadow = TEX .. "Shadow", sheen = TEX .. "Sheen", glow = TEX .. "Glow",
    circle = TEX .. "Circle", ring = TEX .. "CircleRing", orb = TEX .. "Orb",
}

local function Hex(h)
    h = h:gsub("#", "")
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
Glass.Hex = Hex

-- Fertige Skins. tint = Glas, glow = Leuchtfarbe, title = Ueberschriften.
Glass.skins = {
    azeroth  = { name = "Azeroth (Gold)",  tint = Hex("0a0b0d"), glow = Hex("ffd100"), title = Hex("ffd100") },
    glas     = { name = "Glas (Blau)",     tint = Hex("091420"), glow = Hex("6fd3ff"), title = Hex("eaf5fb") },
    horde    = { name = "Horde",           tint = Hex("140909"), glow = Hex("e8743b"), title = Hex("ffc08a") },
    alliance = { name = "Allianz",         tint = Hex("07101f"), glow = Hex("5aa2ff"), title = Hex("e3c26a") },
}
Glass.order = { "azeroth", "glas", "horde", "alliance", "custom" }
Glass.DEFAULT_ALPHA = .80

local function Store()
    if not ONE.db then return {} end
    if type(ONE.db.theme) ~= "table" then ONE.db.theme = {} end
    local t = ONE.db.theme
    if type(t.glass) ~= "table" then t.glass = {} end
    local g = t.glass
    if g.skin ~= "custom" and not Glass.skins[g.skin or ""] then g.skin = "azeroth" end
    if type(g.alpha) ~= "number" or g.alpha < .4 or g.alpha > 1 then g.alpha = Glass.DEFAULT_ALPHA end
    return g
end
Glass.Store = Store

-- Aussehen: "glass" (Standard ab 0.7.1) oder "native" (Blizzard-Fenster wie 0.7.0)
function Glass:Active()
    if not ONE.db or type(ONE.db.theme) ~= "table" then return true end
    return ONE.db.theme.look ~= "native"
end

local function Clamp01(v) return math.max(0, math.min(1, tonumber(v) or 0)) end
local function Copy(c) return { Clamp01(c[1]), Clamp01(c[2]), Clamp01(c[3]) } end
-- Helligkeit (fuer lesbare Schrift auf eigener Leuchtfarbe)
local function Luma(c) return .2126 * c[1] + .7152 * c[2] + .0722 * c[3] end
Glass.Luma = Luma

-- Aktuelle Farben. Eigene Farben: Toenung wird gedeckelt, damit weisse Schrift lesbar bleibt.
function Glass:Palette()
    local g = Store()
    local p
    if g.skin == "custom" then
        local tint = type(g.tint) == "table" and Copy(g.tint) or Copy(self.skins.azeroth.tint)
        local glow = type(g.glow) == "table" and Copy(g.glow) or Copy(self.skins.azeroth.glow)
        local l = Luma(tint)
        if l > .22 then local k = .22 / l tint = { tint[1] * k, tint[2] * k, tint[3] * k } end
        -- Ueberschrift: Leuchtfarbe, bei sehr dunkler Leuchtfarbe aufgehellt
        local title = glow
        if Luma(glow) < .45 then title = { glow[1] + (1 - glow[1]) * .5, glow[2] + (1 - glow[2]) * .5, glow[3] + (1 - glow[3]) * .5 } end
        p = { name = T("Eigene Farben"), tint = tint, glow = glow, title = title }
    else
        p = self.skins[g.skin]
    end
    p.alpha = g.alpha
    -- Schrift auf Leuchtfarbe (Hauptknopf): dunkel auf hellem Licht, sonst weiss
    p.onGlow = Luma(p.glow) > .5 and { .07, .06, .03 } or { 1, 1, 1 }
    return p
end
function Glass:SkinId() return Store().skin end
function Glass:SetSkin(id)
    if id ~= "custom" and not self.skins[id] then return false end
    local g = Store()
    if id == "custom" and type(g.tint) ~= "table" then
        -- eigene Farben starten beim gerade gewaehlten Skin
        local base = self.skins[g.skin] or self.skins.azeroth
        g.tint, g.glow = Copy(base.tint), Copy(base.glow)
    end
    g.skin = id
    self:ApplyAll()
    return true
end
function Glass:SetCustom(key, r, g, b)
    if key ~= "tint" and key ~= "glow" then return false end
    local s = Store()
    if s.skin ~= "custom" then self:SetSkin("custom") end
    s[key] = { Clamp01(r), Clamp01(g), Clamp01(b) }
    self:ApplyAll()
    return true
end
function Glass:SetAlpha(a)
    Store().alpha = math.max(.4, math.min(1, tonumber(a) or self.DEFAULT_ALPHA))
    self:ApplyAll()
end
function Glass:Reset()
    local g = Store()
    g.skin, g.tint, g.glow, g.alpha = "azeroth", nil, nil, self.DEFAULT_ALPHA
    self:ApplyAll()
end

-- Farbe als WoW-Textfarbe
function Glass:Wrap(c, text)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255 + .5), math.floor(c[2] * 255 + .5), math.floor(c[3] * 255 + .5), text or "")
end

-- ===== Neun-Teile-Flaeche (runde Ecken) =====
local NINE = {
    { 0, 1, 0, 1 }, { 1, 2, 0, 1 }, { 2, 3, 0, 1 },
    { 0, 1, 1, 2 }, { 1, 2, 1, 2 }, { 2, 3, 1, 2 },
    { 0, 1, 2, 3 }, { 1, 2, 2, 3 }, { 2, 3, 2, 3 },
}
local Nine = {}
Nine.__index = Nine
function Glass:Nine(frame, texture, src, layer, sub)
    local n = setmetatable({ frame = frame, pieces = {} }, Nine)
    local stops = { 0, src, 1 - src, 1 }
    for i, d in ipairs(NINE) do
        local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        t:SetTexture(texture)
        if t.SetTexCoord then t:SetTexCoord(stops[d[1] + 1], stops[d[2] + 1], stops[d[3] + 1], stops[d[4] + 1]) end
        n.pieces[i] = t
    end
    return n
end
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
function Nine:SetColor(r, g, b, a) for _, t in ipairs(self.pieces) do t:SetVertexColor(r, g, b, a or 1) end end
function Nine:SetShown(on) for _, t in ipairs(self.pieces) do if on then t:Show() else t:Hide() end end end

-- ===== Flaechen =====
-- kind: "window" (Glas, Schatten, Lichtkante), "card" (heller, Rand in Leuchtfarbe),
-- "column" (ganz leicht dunkler/heller), "button", "primary", "select" (Auswahl)
local SHAPE = {
    window = { r = 16, edge = .30, shadow = { 30, 14, -6, .65 } },
    card = { r = 10, edge = .20 },
    column = { r = 12, edge = 0 },
    button = { r = 8, edge = .38 },
    primary = { r = 8, edge = .0 },
    select = { r = 10, edge = .42 },
}
function Glass:Surface(frame, kind, anchor)
    if not (frame and frame.CreateTexture) then return nil end
    local shape = SHAPE[kind] or SHAPE.card
    local s = { frame = frame, kind = kind, anchor = anchor or frame }
    local a = s.anchor
    if shape.shadow then
        s.shadow = self:Nine(frame, self.tex.shadow, .375, "BACKGROUND", -8):Place(shape.shadow[1], shape.shadow[2], a, shape.shadow[3])
    end
    s.fill = self:Nine(frame, self.tex.round, .25, "BACKGROUND", -7):Place(shape.r, 0, a)
    -- Rand: echter Umriss ueber der Flaeche (durchsichtiges Glas zeigt sonst die Randfarbe innen)
    if shape.edge > 0 then s.edge = self:Nine(frame, self.tex.roundRing, .25, "BACKGROUND", -6):Place(shape.r, 0, a) end
    if kind == "window" or kind == "primary" then
        s.sheen = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        s.sheen:SetTexture(self.tex.sheen)
        s.sheen:SetPoint("TOPLEFT", a, "TOPLEFT", shape.r, -1)
        s.sheen:SetPoint("TOPRIGHT", a, "TOPRIGHT", -shape.r, -1)
        s.sheen:SetHeight(kind == "window" and 36 or 12)
    end
    self.surfaces[#self.surfaces + 1] = s
    self:Paint(s)
    return s
end
local function Lift(c, k) return c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k end
function Glass:Paint(s)
    local p = self:Palette()
    local t, g, a = p.tint, p.glow, p.alpha
    local k = s.kind
    if k == "window" then
        s.fill:SetColor(t[1], t[2], t[3], a)
        s.edge:SetColor(g[1], g[2], g[3], .30)
        s.shadow:SetColor(0, 0, .02, .65)
        s.sheen:SetVertexColor(1, 1, 1, .06)
    elseif k == "column" then
        s.fill:SetColor(0, 0, 0, .18)
    elseif k == "card" then
        local r, gg, b = Lift(t, .06)
        s.fill:SetColor(r, gg, b, math.min(1, a * .75))
        s.edge:SetColor(g[1], g[2], g[3], .20)
    elseif k == "button" then
        local r, gg, b = Lift(t, .10)
        s.fill:SetColor(r, gg, b, math.min(1, a + .05))
        s.edge:SetColor(g[1], g[2], g[3], s.hover and .75 or .38)
    elseif k == "primary" then
        local m = s.hover and .18 or 0
        s.fill:SetColor(g[1] + (1 - g[1]) * m, g[2] + (1 - g[2]) * m, g[3] + (1 - g[3]) * m, 1)
        s.sheen:SetVertexColor(1, 1, 1, .35)
    elseif k == "select" then
        s.fill:SetColor(g[1], g[2], g[3], s.on and .16 or (s.hover and .07 or 0))
        s.edge:SetColor(g[1], g[2], g[3], s.on and .45 or 0)
    end
    if s.onPaint then pcall(s.onPaint, s, p) end
end
function Glass:OnChange(fn) self.listeners[#self.listeners + 1] = fn end
function Glass:ApplyAll()
    for _, s in ipairs(self.surfaces) do self:Paint(s) end
    for _, fn in ipairs(self.listeners) do pcall(fn) end
    if ONE.Themes and ONE.Themes.ApplyAll then ONE.Themes:ApplyAll() end
end

-- Farben fuer Themes (Textrollen): accent = Ueberschrift des Skins
function Glass:ThemePreset()
    local p = self:Palette()
    return {
        name = "Glas", skin = "glass", accent = p.title, text = { 1, 1, 1 }, soft = { .80, .80, .80 },
        border = p.glow, background = p.tint, surface = p.tint, button = p.tint,
        light = p.title, softBorder = p.glow,
    }
end

-- ===== Knoepfe =====
-- Ersetzt die rote Blizzard-Vorlage: Pille aus Glas mit Rand in Leuchtfarbe.
-- primary = Hauptknopf in Leuchtfarbe.
function Glass:StyleButton(button, variant)
    if not button or button.__oneGlass then return button end
    button.__oneGlass = true
    local kind = (variant == "primary") and "primary" or "button"
    local s = self:Surface(button, kind)
    button.__oneGlassSurface = s
    local fs = button.GetFontString and button:GetFontString()
    s.onPaint = function(_, p)
        local f = button.GetFontString and button:GetFontString()
        if not (f and f.SetTextColor) then return end
        local on = not button.IsEnabled or button:IsEnabled()
        if not on then f:SetTextColor(.5, .5, .5)
        elseif kind == "primary" then f:SetTextColor(p.onGlow[1], p.onGlow[2], p.onGlow[3])
        else f:SetTextColor(1, 1, 1) end
    end
    local function Hover(on) s.hover = on Glass:Paint(s) end
    if button.HookScript then
        button:HookScript("OnEnter", function() Hover(true) end)
        button:HookScript("OnLeave", function() Hover(false) end)
        button:HookScript("OnEnable", function() Glass:Paint(s) end)
        button:HookScript("OnDisable", function() Glass:Paint(s) end)
        button:HookScript("OnMouseDown", function() if fs and fs.SetPoint then fs:SetPoint("LEFT", button, "LEFT", 12, -1) end end)
        button:HookScript("OnMouseUp", function() if fs and fs.SetPoint then fs:SetPoint("LEFT", button, "LEFT", 11, 0) end end)
    end
    self:Paint(s)
    return button
end

-- ===== Runde Symbole =====
-- Kugel mit Symbol (Spielsymbol oder Atlas-Ausschnitt), Ring in Leuchtfarbe, Leuchten bei Auswahl.
function Glass:Orb(parent, size)
    local o = CreateFrame("Frame", nil, parent)
    o:SetSize(size, size)
    o.glow = o:CreateTexture(nil, "BACKGROUND", nil, -2)
    o.glow:SetTexture(self.tex.glow)
    o.glow:SetPoint("CENTER")
    o.glow:SetSize(size * 2.1, size * 2.1)
    if o.glow.SetBlendMode then o.glow:SetBlendMode("ADD") end
    o.base = o:CreateTexture(nil, "BORDER")
    o.base:SetTexture(self.tex.circle)
    o.base:SetAllPoints(o)
    o.icon = o:CreateTexture(nil, "ARTWORK")
    o.icon:SetPoint("CENTER")
    o.icon:SetSize(size * .66, size * .66)
    o.shine = o:CreateTexture(nil, "ARTWORK", nil, 2)
    o.shine:SetTexture(self.tex.orb)
    o.shine:SetAllPoints(o)
    o.ring = o:CreateTexture(nil, "OVERLAY")
    o.ring:SetTexture(self.tex.ring)
    o.ring:SetAllPoints(o)
    o.SetOn = function(self2, on) self2.on = on Glass:PaintOrb(self2) end
    -- Spielsymbol rund: Maske, wenn der Client sie kann; sonst eckig ohne Rand
    o.SetIconTexture = function(self2, tex, full)
        self2.icon:SetTexture(tex)
        if full then
            self2.icon:SetSize(size - 4, size - 4)
            if self2.icon.SetTexCoord then self2.icon:SetTexCoord(.08, .92, .08, .92) end
            if not self2.mask and self2.CreateMaskTexture and self2.icon.AddMaskTexture then
                local ok, m = pcall(self2.CreateMaskTexture, self2)
                if ok and m then
                    m:SetTexture(Glass.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                    m:SetAllPoints(self2.icon)
                    pcall(self2.icon.AddMaskTexture, self2.icon, m)
                    self2.mask = m
                end
            end
        end
    end
    self.orbs = self.orbs or {}
    self.orbs[#self.orbs + 1] = o
    self:PaintOrb(o)
    return o
end
function Glass:PaintOrb(o)
    local p = self:Palette()
    local g, t = p.glow, p.tint
    local r, gg, b = Lift(t, .14)
    o.base:SetVertexColor(r, gg, b, 1)
    o.shine:SetVertexColor(1, 1, 1, o.on and .55 or .3)
    o.ring:SetVertexColor(g[1], g[2], g[3], o.on and 1 or .35)
    o.glow:SetVertexColor(g[1], g[2], g[3], o.on and .55 or 0)
    o.icon:SetVertexColor(1, 1, 1, o.on and 1 or .82)
end
Glass:OnChange(function() for _, o in ipairs(Glass.orbs or {}) do Glass:PaintOrb(o) end end)

-- ===== Fenster =====
-- Masse im Glas: Spalte 1 (Bereiche) 150, Spalte 2 (Unterseiten) 176, rechts Inhalt 726.
Glass.WINDOW = { width = 1100, height = 540, col1X = 10, col1W = 150, col2X = 166, col2W = 176,
    contentX = 360, contentY = 72, insetTop = 60, insetBottom = 12, navH = 36, navGap = 2,
    sideX = 10, sideWidth = 150 }

local function FS(parent, font, layer)
    local f = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
    f:SetJustifyH("LEFT")
    if f.SetWordWrap then f:SetWordWrap(false) end
    return f
end

-- Baut den Rahmen des Hauptfensters. ui = ONE.UI. Liefert die Spalten-Frames.
function Glass:BuildWindow(ui, frame)
    local W = self.WINDOW
    self.frame = frame
    self:Surface(frame, "window")
    -- feine Lichtlinie oben in Leuchtfarbe
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetTexture(self.tex.glow)
    line:SetPoint("TOPLEFT", frame, "TOPLEFT", 120, 1)
    line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -120, 1)
    line:SetHeight(3)
    self:OnChange(function() local g = Glass:Palette().glow line:SetVertexColor(g[1], g[2], g[3], .7) end)
    local g0 = self:Palette().glow
    line:SetVertexColor(g0[1], g0[2], g0[3], .7)

    -- Spalte 1: Marke und Bereiche
    local col1 = CreateFrame("Frame", nil, frame)
    col1:SetPoint("TOPLEFT", frame, "TOPLEFT", W.col1X, -10)
    col1:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", W.col1X, 10)
    col1:SetWidth(W.col1W)
    self:Surface(col1, "column")
    local brand = CreateFrame("Frame", nil, col1)
    brand:SetPoint("TOPLEFT", col1, "TOPLEFT", 8, -8)
    brand:SetSize(W.col1W - 16, 36)
    local emblem = brand:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture("Interface\\AddOns\\ONE_Core\\Textures\\Common\\Emblem.tga")
    emblem:SetSize(30, 30)
    emblem:SetPoint("LEFT", brand, "LEFT", 0, 0)
    local name = FS(brand, "GameFontNormalLarge")
    name:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
    name:SetText(T("Guild Trip"))
    self.brandLabel = name
    -- Spalte 2: Seite, Unterseiten, Gilde online
    local col2 = CreateFrame("Frame", nil, frame)
    col2:SetPoint("TOPLEFT", frame, "TOPLEFT", W.col2X, -10)
    col2:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", W.col2X, 10)
    col2:SetWidth(W.col2W)
    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", W.contentX - 10, -18)
    divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", W.contentX - 10, 18)
    divider:SetWidth(1)
    self:OnChange(function() local g = Glass:Palette().glow divider:SetColorTexture(g[1], g[2], g[3], .16) end)
    divider:SetColorTexture(g0[1], g0[2], g0[3], .16)
    local head = FS(col2, "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", col2, "TOPLEFT", 8, -12)
    head:SetWidth(W.col2W - 16)
    local sub = FS(col2, "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(W.col2W - 16)
    self.col1, self.col2, self.colHead, self.colSub = col1, col2, head, sub
    self.viewRows, self.guildRows = {}, {}
    self:OnChange(function() Glass:PaintTitles() end)
    self:PaintTitles()
    return col1, col2
end
function Glass:PaintTitles()
    local p = self:Palette()
    for _, f in ipairs({ self.brandLabel, self.colHead, ONE.UI and ONE.UI.pathLabel }) do
        if f and f.SetTextColor then f:SetTextColor(p.title[1], p.title[2], p.title[3]) end
    end
end

-- Bereichsknopf in Spalte 1: runde Kugel mit Goldsymbol, Name rechts daneben
function Glass:NavButton(parent, id, label, atlas, coords)
    local W = self.WINDOW
    local b = CreateFrame("Button", "ProjectONEMainWindowTab" .. id, parent)
    b:SetSize(W.col1W - 12, W.navH)
    local sel = self:Surface(b, "select")
    local orb = self:Orb(b, 26)
    orb:SetPoint("LEFT", b, "LEFT", 6, 0)
    orb.icon:SetTexture(atlas)
    if orb.icon.SetTexCoord and coords then orb.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
    orb.icon:SetSize(18, 18)
    local fs = FS(b, "GameFontHighlight")
    fs:SetPoint("LEFT", orb, "RIGHT", 10, 0)
    fs:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.SetText = function(_, text) fs:SetText(text) end
    b.GetText = function() return fs:GetText() end
    b.__oneGlassNav = { sel = sel, orb = orb, label = fs }
    b:SetScript("OnEnter", function() sel.hover = true Glass:Paint(sel) end)
    b:SetScript("OnLeave", function() sel.hover = false Glass:Paint(sel) end)
    b:SetText(label)
    return b
end
function Glass:StyleNav(b, selected)
    local r = b and b.__oneGlassNav
    if not r then return false end
    r.sel.on = selected
    self:Paint(r.sel)
    r.orb:SetOn(selected)
    if selected then r.label:SetTextColor(1, 1, 1) else r.label:SetTextColor(.78, .78, .78) end
    return true
end

-- Zeile in Spalte 2 (Unterseite oder Gildenmitglied)
local function Row(parent, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(h)
    b.sel = Glass:Surface(b, "select")
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetTexture(Glass.tex.ring)
    b.dot:SetSize(14, 14)
    b.dot:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.label = FS(b, "GameFontHighlight")
    b.label:SetPoint("LEFT", b.dot, "RIGHT", 10, 0)
    b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b:SetScript("OnEnter", function(self) self.sel.hover = true Glass:Paint(self.sel) end)
    b:SetScript("OnLeave", function(self) self.sel.hover = false Glass:Paint(self.sel) end)
    return b
end

-- Unterseiten der offenen Seite als Liste (statt Knoepfe in der Kopfzeile)
function Glass:ShowViews(ui, set, title, context)
    local col2 = self.col2
    if not col2 then return end
    self.colHead:SetText(title or "")
    self.colSub:SetText(context or "")
    local items = set and set.items or {}
    local y = -58
    local p = self:Palette()
    local step = #items > 7 and 27 or 36
    for i, it in ipairs(items) do
        local b = self.viewRows[i]
        if not b then
            b = Row(col2, 34)
            b:SetPoint("LEFT", col2, "LEFT", 4, 0)
            b:SetPoint("RIGHT", col2, "RIGHT", -4, 0)
            self.viewRows[i] = b
        end
        b:SetPoint("TOP", col2, "TOP", 0, y)
        b:SetHeight(step - 2)
        b.label:SetText(T(it.label))
        local on = (it.key == set.active)
        b.sel.on = on
        self:Paint(b.sel)
        b.dot:SetVertexColor(p.glow[1], p.glow[2], p.glow[3], on and 1 or .4)
        b.label:SetTextColor(on and 1 or .8, on and 1 or .8, on and 1 or .8)
        b:SetScript("OnClick", function()
            set.active = it.key
            if it.onClick then it.onClick(it.key) end
            ui:UpdateViews()
        end)
        b:Show()
        y = y - step
    end
    for i = #items + 1, #self.viewRows do self.viewRows[i]:Hide() end
    self:ShowGuild(y - 10)
end

-- Gilde online (unten in Spalte 2): wer gerade da ist, ein Klick fluestert an
function Glass:ShowGuild(top)
    local col2 = self.col2
    if not self.guildHead then
        self.guildHead = FS(col2, "GameFontDisableSmall")
        self.guildHead:SetWidth(self.WINDOW.col2W - 20)
    end
    local online = {}
    if type(IsInGuild) == "function" and IsInGuild() and type(GetNumGuildMembers) == "function" and type(GetGuildRosterInfo) == "function" then
        local me = type(UnitName) == "function" and UnitName("player")
        local n = GetNumGuildMembers() or 0
        for i = 1, n do
            local name, _, _, level, _, zone, _, _, isOnline, _, class = GetGuildRosterInfo(i)
            if name and isOnline then
                local short = name:match("^[^%-]+") or name
                if short ~= me then online[#online + 1] = { name = name, short = short, level = level, zone = zone, class = class } end
            end
        end
        table.sort(online, function(a, b) return (a.level or 0) > (b.level or 0) end)
    end
    local room = math.floor(((self.WINDOW.height - 20) + top - 30) / 22)
    room = math.max(0, math.min(room, 12))
    self.guildHead:SetPoint("TOP", col2, "TOP", 0, top)
    self.guildHead:SetPoint("LEFT", col2, "LEFT", 10, 0)
    self.guildHead:SetText((#online > 0 and T("GILDE ONLINE · %d", #online)) or T("GILDE ONLINE"))
    local y = top - 16
    for i = 1, math.max(room, #self.guildRows) do
        local m = online[i]
        local r = self.guildRows[i]
        if m and i <= room then
            if not r then
                r = Row(col2, 22)
                r:SetPoint("LEFT", col2, "LEFT", 4, 0)
                r:SetPoint("RIGHT", col2, "RIGHT", -4, 0)
                r.dot:SetTexture(Glass.tex.circle)
                r.dot:SetSize(7, 7)
                r.label:SetFontObject("GameFontHighlightSmall")
                self.guildRows[i] = r
            end
            r:SetPoint("TOP", col2, "TOP", 0, y)
            local cc = m.class and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
            r.label:SetText(("%s |cff999999%s|r"):format(m.short, m.level or ""))
            if cc then r.label:SetTextColor(cc.r, cc.g, cc.b) else r.label:SetTextColor(1, 1, 1) end
            r.dot:SetVertexColor(.12, 1, .35, 1)
            r:SetScript("OnClick", function()
                if type(ChatFrame_OpenChat) == "function" then ChatFrame_OpenChat("/w " .. m.name .. " ") end
            end)
            r:SetScript("OnEnter", function(self2)
                self2.sel.hover = true Glass:Paint(self2.sel)
                if GameTooltip then
                    GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
                    GameTooltip:SetText(m.short)
                    if m.zone then GameTooltip:AddLine(m.zone, .8, .8, .8) end
                    GameTooltip:AddLine(T("Klicken zum Anflüstern"), .6, .6, .6)
                    GameTooltip:Show()
                end
            end)
            r:SetScript("OnLeave", function(self2)
                self2.sel.hover = false Glass:Paint(self2.sel)
                if GameTooltip then GameTooltip:Hide() end
            end)
            r:Show()
            y = y - 22
        elseif r then
            r:Hide()
        end
    end
    if #online == 0 and not self.guildEmpty then
        self.guildEmpty = FS(col2, "GameFontDisableSmall")
        self.guildEmpty:SetWidth(self.WINDOW.col2W - 20)
    end
    if self.guildEmpty then
        self.guildEmpty:SetPoint("TOPLEFT", self.guildHead, "BOTTOMLEFT", 0, -6)
        self.guildEmpty:SetText(#online == 0 and T("Gerade niemand da.") or "")
    end
end

-- ===== Einstellungen (Optionen › Darstellung) =====
function Glass:RegisterSettings(ui)
    local function Set(o) o.category, o.section = "look", "Aussehen" ui:AddSetting(o) end
    Set({ id = "glassLook", kind = "dropdown", label = "Aussehen", order = 1, width = 220,
        tooltip = "Glas: durchsichtig mit drei Spalten. Blizzard: Fenster wie im Spiel (wie 0.7.0). Wechsel lädt die Oberfläche neu.",
        options = function() return { { value = "glass", text = T("Glas (neu)") }, { value = "native", text = T("Blizzard (wie 0.7.0)") } } end,
        get = function() return Glass:Active() and "glass" or "native" end,
        set = function(v) ONE.db.theme.look = v end,
        onChange = function() ui:AskReload(true) end })
    Set({ id = "glassSkin", kind = "dropdown", label = "Farben", order = 2, width = 220,
        visible = function() return Glass:Active() end,
        options = function()
            local list = {}
            for _, id in ipairs(Glass.order) do
                list[#list + 1] = { value = id, text = id == "custom" and T("Eigene Farben") or T(Glass.skins[id].name) }
            end
            return list
        end,
        get = function() return Glass:SkinId() end,
        set = function(v) Glass:SetSkin(v) end })
    Set({ id = "glassAlpha", kind = "custom", order = 3, visible = function() return Glass:Active() end,
        build = function(row, w) return Glass:AlphaControl(row, w) end })
    Set({ id = "glassGlow", kind = "button", label = "Leuchtfarbe wählen …", order = 4,
        visible = function() return Glass:Active() end,
        tooltip = "Farbe für Auswahl, Ringe, Balken und Knöpfe. Schaltet auf eigene Farben um.",
        onClick = function() Glass:PickColor("glow") end })
    Set({ id = "glassTint", kind = "button", label = "Glasfarbe wählen …", order = 5,
        visible = function() return Glass:Active() end,
        tooltip = "Tönung des Glases. Sehr helle Farben werden abgedunkelt, damit die Schrift lesbar bleibt.",
        onClick = function() Glass:PickColor("tint") end })
    Set({ id = "glassReset", kind = "button", label = "Farben zurücksetzen", order = 6,
        visible = function() return Glass:Active() end,
        onClick = function() Glass:Reset() end })
end

function Glass:AlphaControl(row, w)
    local sw = math.min(w - 80, 300)
    local label = FS(row, "GameFontHighlight")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2)
    label:SetText(T("Deckkraft des Glases"))
    local value = FS(row, "GameFontHighlight")
    value:SetPoint("TOPLEFT", row, "TOPLEFT", sw - 56, -2)
    value:SetWidth(60)
    value:SetJustifyH("RIGHT")
    local ok, slider = pcall(CreateFrame, "Slider", nil, row, "OptionsSliderTemplate")
    if not ok or not slider then slider = CreateFrame("Slider", nil, row) end
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -22)
    slider:SetWidth(sw)
    if slider.SetHeight then slider:SetHeight(16) end
    if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
    slider:SetMinMaxValues(40, 100)
    slider:SetValueStep(5)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    for _, key in ipairs({ "Low", "High", "Text" }) do
        local fs = slider[key]
        if type(fs) == "table" and fs.SetText then fs:SetText("") end
    end
    slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor((v or 80) / 5 + .5) * 5
        value:SetText(v .. " %")
        if math.abs(Store().alpha * 100 - v) > .5 then Glass:SetAlpha(v / 100) end
    end)
    return function()
        local a = math.floor(Store().alpha * 100 + .5)
        value:SetText(a .. " %")
        if slider.SetValue then slider:SetValue(a) end
    end, 48
end

-- Farbwaehler des Spiels; Abbrechen stellt die alte Farbe wieder her
function Glass:PickColor(key)
    local p = self:Palette()
    local start = Copy(key == "tint" and p.tint or p.glow)
    local cpf = _G.ColorPickerFrame
    if not cpf then return false end
    local function Current()
        local r, g, b = cpf:GetColorRGB()
        Glass:SetCustom(key, r, g, b)
    end
    local function Cancel() Glass:SetCustom(key, start[1], start[2], start[3]) end
    if cpf.SetupColorPickerAndShow then
        cpf:SetupColorPickerAndShow({ r = start[1], g = start[2], b = start[3], hasOpacity = false,
            swatchFunc = Current, cancelFunc = Cancel })
    else
        cpf.func, cpf.cancelFunc, cpf.hasOpacity = Current, Cancel, false
        if cpf.SetColorRGB then cpf:SetColorRGB(start[1], start[2], start[3]) end
        if ShowUIPanel then ShowUIPanel(cpf) else cpf:Show() end
    end
    return true
end

return Glass
