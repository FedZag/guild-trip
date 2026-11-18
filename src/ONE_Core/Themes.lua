local _, ONE = ...

-- Guild Trip 0.8: ein einziges Aussehen ("Nachtroute"), gezeichnet von Skin.lua.
-- Buch- und Blizzard-Look sind entfallen. Dieses Modul bleibt die Schnittstelle,
-- ueber die Module Texte, Linien, Karten und kleine Fenster anmelden; die Farben
-- kommen aus dem gewaehlten Skin (Nachtroute, Klassisch, Horde, Allianz).
local Themes = { windows = {}, panels = {}, texts = {}, rules = {} }
ONE.Themes = Themes

local function Skin() return ONE.Skin end

function Themes:Initialize()
    if type(ONE.db.theme) ~= "table" then ONE.db.theme = {} end
    local t = ONE.db.theme
    -- fruehere Auswahl (native/book) gibt es nicht mehr
    t.selected = nil
    if type(t.uiSounds) ~= "boolean" then t.uiSounds = true end
    if t.skin ~= nil and not (Skin().palettes[t.skin] or t.skin == "auto") then t.skin = nil end
end

-- Palette in den alten Rollennamen, damit bestehende Aufrufer weiter funktionieren.
function Themes:Current()
    local p = Skin():Palette()
    local hair = p.hair or .09
    local function mix(c, a) return { c[1] + (1 - c[1]) * a, c[2] + (1 - c[2]) * a, c[3] + (1 - c[3]) * a } end
    return {
        name = p.name, skin = "night",
        text = p.text, soft = p.soft, muted = p.muted, title = p.title,
        accent = p.accent, light = p.accent, onAccent = p.onAccent,
        border = mix(p.win, hair * 1.6), softBorder = mix(p.win, hair),
        background = p.win, surface = p.panel, button = p.ctl,
        ok = p.ok, warn = p.warn, bad = p.bad,
    }
end
Themes.Get = Themes.Current
function Themes:IsNative() return false end
function Themes:SetActive(id) return Skin():Set(id) end

local function Fill(tex, c, a)
    if tex and tex.SetColorTexture and c then tex:SetColorTexture(c[1], c[2], c[3], a or 1) end
end

function Themes:RegisterRule(tex, role)
    self.rules[#self.rules + 1] = { tex = tex, role = role or "border" }
    self:ApplyRule(self.rules[#self.rules])
end
function Themes:ApplyRule(entry)
    local p = self:Current()
    Fill(entry.tex, p[entry.role] or p.border)
end

function Themes:RegisterText(font, role)
    if not font then return end
    if ONE.Kit then ONE.Kit:Upgrade(font) end
    self.texts[#self.texts + 1] = { font = font, role = role or "text" }
    self:ApplyText(self.texts[#self.texts])
end
function Themes:ApplyText(entry)
    local p = self:Current()
    local c = ONE.Kit and ONE.Kit:TextColor(p, entry.role) or p[entry.role] or p.text
    if entry.font.SetTextColor and c then entry.font:SetTextColor(c[1], c[2], c[3]) end
end

function Themes:PlaySound(kind, _, explicitPreview)
    if not explicitPreview and (not ONE.db or not ONE.db.theme or not ONE.db.theme.uiSounds) then return false end
    if not PlaySound or not SOUNDKIT then return false end
    local sound = (kind == "click") and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_CHARACTER_INFO_TAB"
    local soundID = SOUNDKIT[sound] or SOUNDKIT.IG_MAINMENU_OPEN
    if not soundID then return false end
    PlaySound(soundID, "SFX")
    return true
end

-- Kleine Fenster (Hinweise, Was ist neu, Buff-Liste ...): runde Flaeche mit Schatten,
-- feine Akzentlinie oben, Titel in Ueberschriftfarbe.
function Themes:RegisterWindow(frame, background, label)
    if not frame then return end
    local entry = { frame = frame, background = background, label = label }
    if frame.SetBackdrop then pcall(frame.SetBackdrop, frame, nil) end
    entry.surface = Skin():Surface(frame, { fill = "win", radius = 8, shadow = "window", sheenHeight = 34 })
    local rim = frame:CreateTexture(nil, "BORDER")
    rim:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, 0)
    rim:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, 0)
    rim:SetHeight(1)
    entry.rim = rim
    self.windows[#self.windows + 1] = entry
    self:ApplyWindow(entry)
end
function Themes:ApplyWindow(entry)
    local p = Skin():Palette()
    -- eigener Hintergrund des Fensters wird von der runden Flaeche ersetzt
    if entry.background and entry.background.SetColorTexture then entry.background:SetColorTexture(0, 0, 0, 0) end
    if entry.frame.SetBackdropColor then entry.frame:SetBackdropColor(0, 0, 0, 0) end
    if entry.frame.SetBackdropBorderColor then entry.frame:SetBackdropBorderColor(0, 0, 0, 0) end
    Fill(entry.rim, p.accent, .7)
    if entry.label and entry.label.SetTextColor and not entry.label.__oneOwnColor then
        entry.label:SetTextColor(p.title[1], p.title[2], p.title[3])
    end
end

-- Karten: runde, leicht angehobene Flaeche mit Rand und Schatten.
function Themes:RegisterPanel(frame, opts)
    if not frame then return end
    local entry = { frame = frame }
    entry.surface = Skin():Surface(frame, opts or { fill = "panel", radius = 6, shadow = "card" })
    self.panels[#self.panels + 1] = entry
    -- alter Rueckgabewert: Hintergrundtextur (manche Aufrufer faerben sie); bleibt unsichtbar
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0, 0, 0, 0)
    return bg
end
function Themes:ApplyPanel() end
function Themes:PanelTitle() end

-- Knoepfe zeichnet Widgets:Button selbst.
function Themes:StyleButton() end
function Themes:ApplyButton() end
function Themes:StyleTree() end

function Themes:ApplyAll()
    for _, e in ipairs(self.windows) do self:ApplyWindow(e) end
    for _, e in ipairs(self.texts) do self:ApplyText(e) end
    for _, e in ipairs(self.rules) do self:ApplyRule(e) end
end
