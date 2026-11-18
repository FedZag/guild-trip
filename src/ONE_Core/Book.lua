local _, ONE = ...

-- Aussehen "Altes Buch" (0.6.1): das ganze Fenster als aufgeschlagenes Buch.
--  * eigenes Bild Textures/Book/Book.tga (scripts/build_book.py): Ledereinband
--    mit Goldpraegung, zwei Pergamentseiten, Falz genau in der Mitte des Inhalts
--  * Reiter als Daumenregister: Lederreiter rechts am Buch (Textures/Book/Tab.tga)
--  * Ueberschriften in der Buchschrift (Morpheus), helle Schrift wird Tinte
--  * Seiten koennen sich als Doppelseite aufbauen (Book:Spread)
--  * Umblaettern beim Seitenwechsel
-- Wird beim Laden aufgebaut; Umschalten braucht ein Neuladen der Oberflaeche.
local Book = {}
ONE.Book = Book

Book.art = "Interface\\AddOns\\ONE_Core\\Textures\\Book\\Book.tga"
Book.sealArt = "Interface\\AddOns\\ONE_Core\\Textures\\Book\\Seal.tga"
Book.font = "Fonts\\MORPHEUS.TTF"
-- Fliesstext: IM FELL English (Igino Marini, SIL Open Font License, Fonts/OFL.txt)
Book.bodyFont = "Interface\\AddOns\\ONE_Core\\Fonts\\IMFellEnglish.ttf"
Book.bodyScale = 1.12
Book.ink = {.10, .05, .01}
Book.red = {.42, .10, .03}     -- Rubrik-Rot fuer Kopfzeilen
Book.gold = {.90, .74, .40}
Book.margin = 24               -- das Bild ragt so weit ueber das Fenster hinaus (Schatten, Einband)
-- Mitte der linken/rechten Seite in Fenster-Einheiten (Bild: scripts/build_book.py)
Book.leftCenter, Book.rightCenter = 205, 569
-- Doppelseite in Inhalts-Koordinaten (Inhalt 726 breit, Falz bei 363)
Book.left = {x = 0, width = 330}
Book.right = {x = 396, width = 330}

local function Settings()
    ONE.db.theme = type(ONE.db.theme) == "table" and ONE.db.theme or {}
    return ONE.db.theme
end

function Book:IsActive()
    return ONE.db and type(ONE.db.theme) == "table" and ONE.db.theme.selected == "book"
end

-- Doppelseite fuer Seiten, die sich aufteilen koennen; sonst nil
function Book:Spread()
    if self:IsActive() then return self.left, self.right end
end

-- Alle Schriftfarben werden zu Tinte (Stand 7: auch Rot, Gruen, Grau waren zu grell):
--  * Weiss/Grau -> dunkle Tinte bis verblasstes Braun (je heller, desto dunkler)
--  * Gold/Gelb (Blizzard-Akzent) -> Tinte mit einem Hauch Gold
--  * kraeftige Farben (Klassen, Stufe zu hoch, "passt") -> gleicher Farbton, aber
--    so dunkel wie Tinte und ins Braune gezogen
Book.soft = {.36, .25, .14}

-- ===== Gealterte Tinte (15.11.2026, Nutzer-Wunsch) =====
-- Buch und Schrift sollen wirken, als waeren sie tausende Jahre alt – trotzdem lesbar:
-- verblasstes Sepia statt frischem Schwarz, ein feiner brauner Hof (ausgelaufene Tinte)
-- und ein halbdurchsichtiges Abrieb-Bild ueber den Seiten (Textures/Book/Wear.tga,
-- scripts/build_book.py --wear). Schalter: Optionen › Darstellung › "Gealterte Tinte".
Book.wearArt = "Interface\\AddOns\\ONE_Core\\Textures\\Book\\Wear.tga"
-- 0.7.1 (Nutzer-Wunsch: Buch zu hell): Papier 15 % dunkler und etwas waermer (Book.paper),
-- dafuer fast schwarze Tinte. Gemessen (WCAG-Kontrast auf dem Pergament): Tinte ~4,0 (vorher 3,8),
-- Rubrik-Rot (nur Ueberschriften) ~3,2. Dunkler geht nicht ohne Lesbarkeit zu verlieren.
Book.agedInk = {.07, .045, .02}
Book.agedSoft = {.22, .14, .07}
Book.agedRed = {.30, .04, .01}
Book.paper = {.85, .816, .765}
function Book.Tone(tex)
    if tex and tex.SetVertexColor then tex:SetVertexColor(Book.paper[1], Book.paper[2], Book.paper[3], 1) end
end
Book.bleed = {.40, .26, .12, .22}
function Book.Aged()
    return not (ONE.db and type(ONE.db.theme) == "table" and ONE.db.theme.agedInk == false)
end
if ONE.RegisterFeature then
    ONE:RegisterFeature("core.agedInk", {label = "Gealterte Tinte (Buch-Aussehen)", reload = true,
        tooltip = "Verblasste, leicht ausgelaufene Schrift und abgegriffene Stellen – als wäre das Buch uralt. Wirkt nach dem Neuladen.",
        get = function() return Book.Aged() end,
        set = function(on)
            ONE.db.theme = type(ONE.db.theme) == "table" and ONE.db.theme or {}
            ONE.db.theme.agedInk = on and true or false
        end})
end
function Book.Ink(r, g, b)
    r, g, b = r or 1, g or 1, b or 1
    local lum = .3 * r + .59 * g + .11 * b
    if lum <= .24 then return r, g, b end
    local ink, soft = Book.ink, Book.soft
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    if mx - mn < .25 then
        local t = math.min(1, math.max(0, (1 - lum) / .5))
        return ink[1] + (soft[1] - ink[1]) * t, ink[2] + (soft[2] - ink[2]) * t, ink[3] + (soft[3] - ink[3]) * t
    end
    if r > .75 and g > .55 and b < .4 then
        return ink[1] + (r - ink[1]) * .2, ink[2] + (g - ink[2]) * .2, ink[3] + (b - ink[3]) * .2
    end
    local k = .26 / lum
    r, g, b = r * k, g * k, b * k
    return r * .8 + ink[1] * .2 + .04, g * .8 + ink[2] * .2, b * .8 + ink[3] * .2
end

-- Farbcodes im Text (|cffRRGGBB) ebenfalls zu Tinte
local function Hex(v) return math.floor(math.max(0, math.min(1, v)) * 255 + .5) end
-- Benannte Farben (|cnIQ4: …) – neuere Spielstrings nutzen sie statt |cffRRGGBB, z. B. Gegenstandslinks
local NAMED = {IQ0 = {.62, .62, .62}, IQ1 = {.1, .05, .01}, IQ2 = {.1, .5, .1}, IQ3 = {.1, .3, .75}, IQ4 = {.5, .2, .7},
    IQ5 = {.8, .4, .0}, IQ6 = {.7, .6, .35}, IQ7 = {.0, .55, .7}, IQ8 = {.0, .55, .7}}
function Book.InkCodes(text)
    if type(text) ~= "string" or not text:find("|c", 1, true) then return text end
    text = text:gsub("|cn([%w_]+):", function(name)
        local c = NAMED[name]
        if c then local r, g, b = Book.Ink(c[1], c[2], c[3]) return string.format("|cfe%02x%02x%02x", Hex(r), Hex(g), Hex(b)) end
        return string.format("|cfe%02x%02x%02x", Hex(Book.ink[1]), Hex(Book.ink[2]), Hex(Book.ink[3]))
    end)
    return (text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, rr, gg, bb)
        if a == "fe" then return nil end -- schon fuer Pergament gewaehlt (z. B. Klassenfarben im Chat)
        local r, g, b = Book.Ink(tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255)
        return string.format("|c%s%02x%02x%02x", a, Hex(r), Hex(g), Hex(b))
    end))
end

-- Farbflaechen auf Pergament: Gold-Markierungen werden Rubrik-Rot, weisse
-- Schleier braune Tinte (heller Schleier wuerde das Pergament nur aufhellen).
function Book.Paint(tex, r, g, b, a)
    if not tex then return end
    if Book:IsActive() and .3 * r + .59 * g + .11 * b > .5 then
        local red, ink = Book.red, {.30, .18, .06}
        if r > .7 and b < .4 then r, g, b, a = red[1], red[2], red[3], math.min(1, (a or 1) * 1.15)
        else r, g, b, a = ink[1], ink[2], ink[3], math.min(1, (a or 1) * 1.6) end
    end
    tex:SetColorTexture(r, g, b, a)
end

local function Hide(obj) if type(obj) == "table" and obj.Hide then pcall(obj.Hide, obj) end end

-- Blizzard-Fensterteile ausblenden (Namen je nach Spielversion verschieden)
local function HideChrome(frame)
    for _, key in ipairs({"NineSlice", "Bg", "TopTileStreaks", "TitleBg", "Background", "TitleContainer", "TitleText"}) do Hide(frame[key]) end
end

-- ===== Einband und Seiten: ein Bild =====
local function BuildArt(self, ui)
    local frame = ui.frame
    HideChrome(frame)
    HideChrome(ui.inset)
    local art = CreateFrame("Frame", nil, frame)
    local m = self.margin
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", -m, m)
    art:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", m, -m)
    if art.SetFrameLevel and frame.GetFrameLevel then art:SetFrameLevel(frame:GetFrameLevel()) end
    local tex = art:CreateTexture(nil, "BACKGROUND", nil, -8)
    tex:SetAllPoints(art)
    tex:SetTexture(self.art)
    Book.Tone(tex)
    -- Schatten, der beim Umblaettern ueber die Seiten wandert
    local sweep = CreateFrame("Frame", nil, art)
    sweep:SetSize(70, 10)
    sweep:SetPoint("TOPRIGHT", ui.inset, "TOPRIGHT", 0, 0)
    sweep:SetPoint("BOTTOMRIGHT", ui.inset, "BOTTOMRIGHT", 0, 0)
    local shade = sweep:CreateTexture(nil, "ARTWORK")
    shade:SetAllPoints(sweep)
    shade:SetColorTexture(.18, .09, .02, .22)
    sweep:Hide()
    -- Abrieb ueber allen Seiten (liegt ueber Text und Symbolen, faengt keine Klicks ab)
    if Book.Aged() then
        local wear = CreateFrame("Frame", nil, frame)
        wear:SetAllPoints(art)
        if wear.SetFrameLevel and frame.GetFrameLevel then wear:SetFrameLevel(frame:GetFrameLevel() + 80) end
        if wear.EnableMouse then wear:EnableMouse(false) end
        local wt = wear:CreateTexture(nil, "OVERLAY")
        wt:SetAllPoints(wear)
        wt:SetTexture(self.wearArt)
        self.wear = wear
    end
    self.frame, self.texture, self.sweep, self.inset = art, tex, sweep, ui.inset
end

-- Schrift auf Pergament: ohne den schwarzen Spiel-Schatten (macht Buchstaben unscharf)
function Book.Crisp(fs)
    -- gealterte Tinte: statt keinem Schatten ein zarter brauner Hof (Tinte leicht verlaufen)
    if Book.Aged() then
        local c = Book.bleed
        if fs and fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
        if fs and fs.SetShadowColor then fs:SetShadowColor(c[1], c[2], c[3], c[4]) end
        return
    end
    if fs and fs.SetShadowOffset then fs:SetShadowOffset(0, 0) end
    if fs and fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0) end
end

local function HeadFont(fs, size, color)
    if fs.SetFont then pcall(fs.SetFont, fs, Book.font, size, "") end
    Book.Crisp(fs)
    if fs.SetTextColor then fs:SetTextColor(color[1], color[2], color[3]) end
    if fs.SetJustifyH then fs:SetJustifyH("CENTER") end
end

function Book.TitleText()
    local guildName = type(GetGuildInfo) == "function" and GetGuildInfo("player")
    if type(guildName) == "string" and guildName ~= "" then return "Guild Trip  ·  " .. guildName end
    return "Guild Trip"
end

-- Kopfzeilen wie in einem Buch: links der Buchtitel, rechts der Seitenname;
-- unten links die Version wie eine Seitenzahl, unten rechts "zurueck" (nur Unterseiten)
local function StyleHeader(self, ui)
    local frame = ui.frame
    local keep = {}
    for _, fs in ipairs({ui.pathLabel, ui.themeStatus}) do if fs then keep[fs] = true end end
    local texts = ONE.Themes and ONE.Themes.texts or {}
    for i = #texts, 1, -1 do if keep[texts[i].font] then table.remove(texts, i) end end
    local left = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    left:SetPoint("CENTER", frame, "TOPLEFT", self.leftCenter, -53)
    left:SetWidth(300)
    HeadFont(left, 15, self.red)
    left:SetText(self.TitleText())
    if frame.HookScript then frame:HookScript("OnShow", function() left:SetText(Book.TitleText()) end) end
    self.leftHead = left
    if ui.pathLabel then
        local p = ui.pathLabel
        p:ClearAllPoints()
        p:SetPoint("CENTER", frame, "TOPLEFT", self.rightCenter, -53)
        p:SetWidth(300)
        HeadFont(p, 15, self.red)
    end
    if ui.themeStatus then
        local v = ui.themeStatus
        v:ClearAllPoints()
        v:SetPoint("BOTTOM", frame, "BOTTOMLEFT", self.leftCenter, 18)
        v:SetWidth(200)
        HeadFont(v, 11, {.30, .20, .10})
        pcall(v.SetFont, v, self.bodyFont, 13, "")
    end
    -- GT-Zeichen weg (im Buch ueberfluessig)
    for _, key in ipairs({"PortraitContainer", "portrait", "Portrait", "PortraitFrame"}) do Hide(frame[key]) end
    Hide(ui.portraitIcon)
    -- Schliessen: kleines Tinten-Kreuz oben rechts auf der Seite statt rotem Knopf
    Hide(ui.closeButton)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(24, 24)
    -- mittig in der dunklen, abgeknickten Ecke (Bild: Ecke 726..762 x 38..74)
    close:SetPoint("CENTER", frame, "TOPLEFT", 751, -49)
    local x = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetAllPoints(close)
    if x.SetFont then pcall(x.SetFont, x, self.bodyFont, 26, "") end
    Book.Crisp(x)
    x:SetText("×")
    x:SetTextColor(self.ink[1] + .15, self.ink[2] + .1, self.ink[3] + .05)
    close:SetScript("OnClick", function() frame:Hide() end)
    close:SetScript("OnEnter", function()
        x:SetTextColor(.7, .12, .04)
        if GameTooltip then GameTooltip:SetOwner(close, "ANCHOR_LEFT") GameTooltip:SetText(ONE.T and ONE.T("Buch schließen") or "Buch schließen") GameTooltip:Show() end
    end)
    close:SetScript("OnLeave", function()
        x:SetTextColor(Book.ink[1] + .15, Book.ink[2] + .1, Book.ink[3] + .05)
        if GameTooltip then GameTooltip:Hide() end
    end)
    self.closeLink = close
    -- Vor/Zurueck-Knoepfe weg; auf Unterseiten ein Tintenlink
    Hide(ui.backButton) Hide(ui.forwardButton)
    local link = CreateFrame("Button", nil, frame)
    -- unten links auf der linken Seite (zurueck = nach links blaettern), mit Unterstrich
    link:SetSize(150, 24)
    link:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 44, 30)
    local text = link:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetAllPoints(link)
    HeadFont(text, 18, self.red)
    local under = link:CreateTexture(nil, "ARTWORK")
    under:SetHeight(1)
    under:SetPoint("BOTTOMLEFT", link, "BOTTOMLEFT", 0, 1)
    under:SetWidth(96)
    under:SetColorTexture(self.red[1], self.red[2], self.red[3], .7)
    text:SetJustifyH("LEFT")
    text:SetText("‹ " .. (ONE.T and ONE.T("zurück") or "zurück"))
    link:SetScript("OnClick", function() ui:GoBack() end)
    if link.SetScript then
        link:SetScript("OnEnter", function() text:SetTextColor(.7, .2, .05) end)
        link:SetScript("OnLeave", function() text:SetTextColor(Book.red[1], Book.red[2], Book.red[3]) end)
    end
    link:Hide()
    self.backLink = link
end

-- Zurueck nur auf Unterseiten (Optionen › Teilen, Alle Mitglieder ...) oder wenn eine Seite selbst zurueck kann
function Book:UpdateBack(ui)
    if not (self:IsActive() and self.backLink) then return end
    Hide(ui.backButton) Hide(ui.forwardButton)
    local handler = ui.backHandlers and ui.backHandlers[ui.activeTab]
    local sub = (ui.views and ui.views[ui.activeTab]) or (handler and handler.canBack())
    if sub and ui:CanGoBack() then self.backLink:Show() else self.backLink:Hide() end
end

-- ===== Daumenregister: Lederreiter rechts am Buch =====
-- Seit 15.11.2026 (Nutzer-Wunsch, Variante "A+"): kleine, abgegriffene Lederreiter mit
-- gepraegtem Goldsymbol statt Text (TabWorn.tga, TabIcons.tga aus scripts/build_book.py
-- --tabs). Beim Drueberfahren gleitet der Reiter heraus und zeigt den Namen; der
-- aufgeschlagene Reiter ist heller und ragt etwas weiter heraus.
Book.tabArt = "Interface\\AddOns\\ONE_Core\\Textures\\Book\\TabWorn.tga"
Book.tabIcons = "Interface\\AddOns\\ONE_Core\\Textures\\Book\\TabIcons.tga"
Book.tabIconIndex = {home = 0, guild = 1, calendar = 2, dungeons = 3, groups = 3, crafting = 4, classes = 5,
    quests = 6, nav = 7, options = 8, leveling = 10}
Book.tab = {width = 46, active = 56, hover = 160, height = 40, gap = 10, top = -64, out = -6}

-- WoWs Reiter-Logik setzt Schrift/Farbe (normal, Maus, ausgewaehlt) und Breite immer
-- wieder neu. Deshalb: unsichtbare Schrift fuer alle Zustaende, Blizzard-Texte laufend
-- ausblenden und die eigene Breite laufend halten (Nutzer-Screenshot 15.11.2026).
local hiddenFont
local function HiddenFont()
    if not hiddenFont and type(CreateFont) == "function" then
        hiddenFont = CreateFont("GuildTripTabHiddenFont")
        if hiddenFont.SetFontObject and GameFontNormalSmall then hiddenFont:SetFontObject(GameFontNormalSmall) end
        if hiddenFont.SetTextColor then hiddenFont:SetTextColor(0, 0, 0, 0) end
    end
    return hiddenFont
end
local function HideBlizzText(tab)
    local r = tab.__oneTab
    if tab.GetRegions then
        for _, region in ipairs({tab:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "FontString" and region ~= (r and r.label) then
                if region.SetAlpha then region:SetAlpha(0) end
            end
        end
    end
    local fs = tab.GetFontString and tab:GetFontString()
    if fs and fs ~= (r and r.label) and fs.SetAlpha then fs:SetAlpha(0) end
    local text = rawget(tab, "Text")
    if type(text) == "table" and text ~= (r and r.label) and text.SetAlpha then text:SetAlpha(0) end
end

local function TabTarget(r)
    local t = Book.tab
    return r.hover and t.hover or r.selected and t.active or t.width
end

-- Weiches Herausgleiten (Breite und Namens-Deckkraft je Bild nachziehen)
local function TabStep(tab, elapsed)
    local r = tab.__oneTab
    if not r then return end
    local target = TabTarget(r)
    local cur = r.width or target
    -- WoW hat die Breite veraendert (Reiter an Text angepasst)? Zurueck auf unsere.
    local actual = tab.GetWidth and tab:GetWidth()
    if cur == target and actual and math.abs(actual - cur) < .5 then return end
    cur = cur + (target - cur) * math.min(1, (elapsed or .016) * 14)
    if math.abs(target - cur) < .5 then cur = target end
    r.width = cur
    tab:SetWidth(cur)
    HideBlizzText(tab)
    if r.label.SetAlpha then r.label:SetAlpha(math.max(0, math.min(1, (cur - 80) / 50))) end
end

function Book:StyleTab(tab, id)
    if not (self:IsActive() and tab) or tab.__oneTab then return end
    local leather = tab:CreateTexture(nil, "BACKGROUND", nil, -8)
    leather:SetAllPoints(tab)
    leather:SetTexture(self.tabArt)
    leather.__oneBook = true
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon.__oneBook = true
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", tab, "LEFT", 16, 0)
    icon:SetTexture(self.tabIcons)
    local idx = self.tabIconIndex[id or ""] or 9
    local col, row = idx % 4, math.floor(idx / 4)
    if icon.SetTexCoord then icon:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4) end
    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    if label.SetFont then pcall(label.SetFont, label, self.bodyFont, 15, "") end
    if label.SetShadowOffset then label:SetShadowOffset(1, -1) end
    if label.SetShadowColor then label:SetShadowColor(.1, .05, .02, .9) end
    label:SetTextColor(.86, .71, .40)
    label:SetAlpha(0)
    label.__oneOldPrint = true
    -- Blizzard-Beschriftung bleibt (Name, Klick), ist aber in jedem Zustand unsichtbar
    local font = HiddenFont()
    if font then
        for _, setter in ipairs({"SetNormalFontObject", "SetHighlightFontObject", "SetDisabledFontObject"}) do
            if tab[setter] then pcall(tab[setter], tab, font) end
        end
    end
    -- laufender Waechter: Herausgleiten, Breite halten, Blizzard-Text weg (sehr billig)
    local anim = CreateFrame("Frame", nil, tab)
    anim:SetScript("OnUpdate", function(_, e) TabStep(tab, e) end)
    local r = {leather = leather, icon = icon, label = label, anim = anim}
    tab.__oneTab = r
    HideBlizzText(tab)
    if tab.HookScript then
        tab:HookScript("OnEnter", function() r.hover = true HideBlizzText(tab) end)
        tab:HookScript("OnLeave", function() r.hover = false HideBlizzText(tab) end)
    end
end

function Book:UpdateTab(tab, selected, index)
    local r = tab and tab.__oneTab
    if not r then return end
    -- alle Blizzard-Reiterbilder aus (Blizzard zeigt sie beim Auswaehlen wieder an)
    if tab.GetRegions then
        for _, region in ipairs({tab:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "Texture" and not region.__oneBook then region:Hide() end
        end
    end
    local t = self.tab
    r.selected = selected and true or false
    -- Name aus der (unsichtbaren) Blizzard-Beschriftung, damit die Sprache stimmt
    local fs = tab.GetFontString and tab:GetFontString()
    local name = (fs and fs.GetText and fs:GetText()) or (tab.GetText and tab:GetText())
    if name and name ~= "" and r.label.SetText then r.label:SetText(name) end
    HideBlizzText(tab)
    if not r.width then r.width = TabTarget(r) end
    tab:SetSize(r.width, t.height)
    if index and tab.ClearAllPoints and self.ui then
        tab:ClearAllPoints()
        -- Reiter beginnen knapp unter dem Einband; der aufgeschlagene ist breiter
        tab:SetPoint("TOPLEFT", self.ui.frame, "TOPRIGHT", t.out, t.top - (index - 1) * (t.height + t.gap))
    end
    local k = selected and 1 or .68
    if r.leather.SetVertexColor then r.leather:SetVertexColor(k, k * .97, k * .94) end
    local g = selected and 1 or .78
    if r.icon.SetVertexColor then r.icon:SetVertexColor(g, g, g) end
end

function Book:UpdateTabs(ui)
    if not self:IsActive() then return end
    for i, id in ipairs(ui.tabIds or {}) do
        local tab = ui.sidebarButtons[id]
        self:StyleTab(tab, id)
        self:UpdateTab(tab, id == ui.activeTab, i)
    end
end

-- ===== Tinte: helle Schrift auf den Seiten dunkel machen =====
-- Blizzard-Knoepfe (rot mit Goldschrift) und Auswahlfelder behalten ihre Farben.
local function IsBlizzardButton(f)
    return type(f.Left) == "table" or type(f.Middle) == "table" or (f.GetNormalTexture and f:GetNormalTexture() ~= nil)
end

local function SkipFrame(f)
    if f.__oneDropdown then return true end
    local kind = f.GetObjectType and f:GetObjectType()
    if kind == "DropdownButton" then return true end
    if kind == "Button" and IsBlizzardButton(f) then return true end
    return false
end

-- Text ausserhalb der Kit-Schriftstufen bekommt die alte Druckschrift direkt
-- (Ueberschriften in Morpheus bleiben)
function Book.OldPrint(fs)
    if not (fs and fs.GetFont and fs.SetFont) or fs.__oneKitLevel or fs.__oneOldPrint then return end
    local file, size = fs:GetFont()
    if type(file) == "string" and (file:upper():find("MORPHEUS", 1, true) or file == Book.bodyFont) then return end
    fs.__oneOldPrint = true
    pcall(fs.SetFont, fs, Book.bodyFont, (size or 12) * Book.bodyScale, "")
end

local function InkFont(fs)
    if fs.__oneInk or not fs.SetTextColor then return end
    fs.__oneInk = true
    Book.Crisp(fs)
    Book.OldPrint(fs)
    local original = fs.SetTextColor
    fs.SetTextColor = function(self, r, g, b, a)
        local ir, ig, ib = Book.Ink(r, g, b)
        return original(self, ir, ig, ib, a)
    end
    if fs.GetTextColor then fs:SetTextColor(fs:GetTextColor()) end
    if fs.SetText then
        local setText = fs.SetText
        fs.SetText = function(self, text, ...) return setText(self, Book.InkCodes(text), ...) end
        if fs.GetText then local t = fs:GetText() if t then fs:SetText(t) end end
    end
end
Book.InkFont = InkFont

-- Unterstreichung wie eine mit Feder gezogene Linie (fuer Eingabefelder und Auswahl)
local function Underline(frame, inset)
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset or 0, 1)
    line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset or 0), 1)
    line:SetColorTexture(Book.red[1], Book.red[2], Book.red[3], .6)
    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    tint:SetAllPoints(frame)
    tint:SetColorTexture(.30, .18, .06, .07)
    return line
end

-- Suchfeld: Blizzards dunkler Kasten weg, nur Lupe, Tinte und Unterstrich
function Book:StyleEditBox(box)
    if not self:IsActive() or not box or box.__oneBookEdit then return end
    box.__oneBookEdit = true
    for _, key in ipairs({"Left", "Right", "Middle", "Mid", "LeftBorder", "RightBorder", "MiddleBorder"}) do Hide(box[key]) end
    if box.searchIcon and box.searchIcon.SetVertexColor then box.searchIcon:SetVertexColor(.45, .25, .1) end
    if box.SetFont then pcall(box.SetFont, box, self.bodyFont, 14, "") end
    if box.SetTextColor then box:SetTextColor(self.ink[1], self.ink[2], self.ink[3]) end
    if box.Instructions then
        local i = box.Instructions
        if i.SetFont then pcall(i.SetFont, i, self.bodyFont, 14, "") end
        Book.Crisp(i)
        i.__oneInk = true
        if i.SetTextColor then i:SetTextColor(.42, .30, .17) end
    end
    if box.SetShadowOffset then box:SetShadowOffset(0, 0) end
    Underline(box, 0)
end

-- Auswahlfeld: kein schwarzer Kasten, Tintenschrift mit Unterstrich, brauner Pfeil
function Book:StyleDropdown(frame)
    if not self:IsActive() or not frame or frame.__oneBookDrop then return end
    frame.__oneBookDrop = true
    local arrow = frame.Arrow or frame.Button
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            local kind = region.GetObjectType and region:GetObjectType()
            if kind == "Texture" and region ~= arrow then region:Hide() region.Show = function() end end
        end
    end
    if arrow and arrow.SetVertexColor then arrow:SetVertexColor(.55, .30, .12) end
    local text = frame.Text or (frame.GetName and frame:GetName() and _G[frame:GetName() .. "Text"])
    if text then
        if text.SetFont then pcall(text.SetFont, text, self.bodyFont, 14, "") end
        text.__oneInk = nil
        InkFont(text)
        text.__oneOldPrint = true
        if text.SetTextColor then text:SetTextColor(1, 1, 1) end
    end
    Underline(frame, frame.Arrow and 2 or 18)
end

function Book:InkTree(frame, depth)
    -- nur im Buch-Aussehen! (Fehler bis 0.6.2: Seitenwechsel faerbte auch das
    -- Blizzard-Aussehen in Tinte – Schrift war dort kaum lesbar)
    if not self:IsActive() then return end
    if not frame or (depth or 0) > 12 then return end
    -- Beschriftung eines Knopfes (auch Haekchen) bleibt, wie der Knopf sie zeichnet
    local own = frame.GetFontString and frame:GetFontString()
    if own then own.__oneInk = true end
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then InkFont(region) end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            local kind = child.GetObjectType and child:GetObjectType()
            if kind == "EditBox" then
                self:StyleEditBox(child)
                if child.SetTextColor and not child.__oneInk then child.__oneInk = true child:SetTextColor(Book.ink[1], Book.ink[2], Book.ink[3]) end
            elseif not SkipFrame(child) then
                self:InkTree(child, (depth or 0) + 1)
            end
        end
    end
end

function Book:InkPages(ui, force)
    if not self:IsActive() then return end
    local now = type(GetTime) == "function" and GetTime() or 0
    if not force and self.lastInk and now - self.lastInk < 2 then return end
    self.lastInk = now
    for _, list in ipairs({ui.tabs or {}, ui.views or {}}) do
        for _, entry in pairs(list) do if entry.panel then self:InkTree(entry.panel, 0) end end
    end
end

-- ===== Loses Blatt: eigene Fenster ausserhalb des Buchs =====
-- Eigenes Pergamentblatt (scripts/build_book.py: Sheet.tga fuer den Tagesueberblick,
-- Strip.tga fuer schmale Hinweisfenster) mit zerfasertem Rand; der Schatten ist
-- dasselbe Bild in Schwarz, leicht versetzt.
Book.sheetArt = "Interface\\AddOns\\ONE_Core\\Textures\\Book\\Sheet.tga"
Book.stripArt = "Interface\\AddOns\\ONE_Core\\Textures\\Book\\Strip.tga"
function Book:Sheet(entry)
    local frame, bg, label = entry.frame, entry.background, entry.label
    if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0, 0, 0, 0) end
    if not (bg and bg.SetTexture) then return end
    local fw = frame.GetWidth and frame:GetWidth() or 400
    local fh = frame.GetHeight and frame:GetHeight() or 300
    local art = (fw / math.max(1, fh) > 2.5) and self.stripArt or self.sheetArt
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)
    bg:SetTexture(art)
    if bg.SetTexCoord then bg:SetTexCoord(0, 1, 0, 1) end
    Book.Tone(bg)
    if not frame.__oneSheet then
        frame.__oneSheet = true
        local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        shadow:SetTexture(art)
        shadow:SetPoint("TOPLEFT", bg, "TOPLEFT", 4, -6)
        shadow:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 7, -9)
        if shadow.SetVertexColor then shadow:SetVertexColor(0, 0, 0, .55) end
        if label then
            if label.SetFont then pcall(label.SetFont, label, self.font, 15, "") end
            Book.Crisp(label)
            label.__oneInk = true
            if label.SetTextColor then label:SetTextColor(self.red[1], self.red[2], self.red[3]) end
        end
        self:InkTree(frame, 0)
        if frame.HookScript then frame:HookScript("OnShow", function() Book:InkTree(frame, 0) end) end
    end
end

-- ===== Auswahlfeld und Menue im Buchstil =====
-- Feld: Tintentext mit Unterstrich und kleinem Pfeil. Menue: Pergamentblatt mit einer
-- Zeile je Wert, die aktuelle Wahl rot mit Merkzeichen; Klick daneben oder Esc schliesst.
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"
function Book:MenuButton(parent, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 24)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", b, "LEFT", 4, 0)
    fs:SetPoint("RIGHT", b, "RIGHT", -22, 0)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetFont then pcall(fs.SetFont, fs, self.bodyFont, 14, "") end
    Book.Crisp(fs)
    fs.__oneInk, fs.__oneOldPrint = true, true
    fs:SetTextColor(self.ink[1], self.ink[2], self.ink[3])
    local arrow = b:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    arrow:SetTexture(ARROW)
    if arrow.SetRotation then arrow:SetRotation(-math.pi / 2) end
    if arrow.SetVertexColor then arrow:SetVertexColor(self.red[1], self.red[2], self.red[3]) end
    Underline(b, 0)
    b:SetScript("OnEnter", function() fs:SetTextColor(.7, .14, .04) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(Book.ink[1], Book.ink[2], Book.ink[3]) end)
    function b:SetLabel(text) fs:SetText(text or "") end
    b.__oneDropdown = true
    return b
end

function Book:OpenMenu(owner, list, current, onSelect)
    local m = self.menu
    if not m then
        -- Fangflaeche: Klick neben das Menue schliesst es
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:SetScript("OnClick", function() Book.menu:Hide() end)
        m = CreateFrame("Frame", "GuildTripBookMenu", UIParent)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        if m.SetFrameLevel and catcher.GetFrameLevel then m:SetFrameLevel(catcher:GetFrameLevel() + 5) end
        m:EnableMouse(true)
        m:SetClampedToScreen(true)
        local shadow = m:CreateTexture(nil, "BACKGROUND", nil, -8)
        shadow:SetTexture(self.sheetArt)
        shadow:SetPoint("TOPLEFT", m, "TOPLEFT", -2, -2)
        shadow:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 7, -9)
        if shadow.SetVertexColor then shadow:SetVertexColor(0, 0, 0, .55) end
        local bg = m:CreateTexture(nil, "BACKGROUND", nil, -7)
        bg:SetTexture(self.sheetArt)
        Book.Tone(bg)
        bg:SetPoint("TOPLEFT", m, "TOPLEFT", -6, 6)
        bg:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 6, -6)
        m.rows, m.catcher = {}, catcher
        m:SetScript("OnHide", function() catcher:Hide() end)
        m:SetScript("OnShow", function() catcher:Show() end)
        if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripBookMenu") end
        m:Hide() catcher:Hide()
        self.menu = m
    end
    local width = math.max(owner.GetWidth and owner:GetWidth() or 180, 180)
    for i, o in ipairs(list) do
        local row = m.rows[i]
        if not row then
            row = CreateFrame("Button", nil, m)
            row:SetHeight(22)
            row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.mark:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetPoint("LEFT", row, "LEFT", 24, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.text:SetJustifyH("LEFT")
            for _, fs in ipairs({row.mark, row.text}) do
                if fs.SetFont then pcall(fs.SetFont, fs, self.bodyFont, 14, "") end
                Book.Crisp(fs)
                fs.__oneInk, fs.__oneOldPrint = true, true
            end
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(row)
            hl:SetColorTexture(self.red[1], self.red[2], self.red[3], .12)
            m.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -8 - (i - 1) * 22)
        row:SetPoint("RIGHT", m, "RIGHT", -4, 0)
        local chosen = o.value == current
        row.mark:SetText(chosen and "›" or "")
        local c = chosen and self.red or self.ink
        row.mark:SetTextColor(self.red[1], self.red[2], self.red[3])
        row.text:SetTextColor(c[1], c[2], c[3])
        row.text:SetText(o.text)
        row:SetScript("OnClick", function() m:Hide() onSelect(o.value) end)
        -- Erklaerung je Eintrag beim Drueberfahren (z. B. Vor-/Nachteile eines Spielstils)
        row:SetScript("OnEnter", function(self)
            if not (o.tooltip and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(o.text, 1, .82, 0)
            GameTooltip:AddLine(o.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        row:Show()
    end
    for i = #list + 1, #m.rows do m.rows[i]:Hide() end
    m:SetSize(width, 16 + #list * 22)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    m:Show()
    if ONE.Sound then ONE.Sound:Play("menu") end
end

-- Schliessen-Kreuz aus Tinte (Buch statt rotem Blizzard-Knopf)
function Book:InkClose(parent, point, x, y, onClick)
    local close = CreateFrame("Button", nil, parent)
    close:SetSize(24, 24)
    close:SetPoint(point or "TOPRIGHT", parent, point or "TOPRIGHT", x or 0, y or 0)
    local glyph = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    glyph:SetAllPoints(close)
    if glyph.SetFont then pcall(glyph.SetFont, glyph, self.bodyFont, 26, "") end
    Book.Crisp(glyph)
    glyph.__oneInk, glyph.__oneOldPrint = true, true
    local function Rest() glyph:SetTextColor(Book.ink[1] + .15, Book.ink[2] + .1, Book.ink[3] + .05) end
    glyph:SetText("×")
    Rest()
    if onClick then close:SetScript("OnClick", onClick) end
    close:SetScript("OnEnter", function() glyph:SetTextColor(.7, .12, .04) end)
    close:SetScript("OnLeave", Rest)
    return close
end

-- ===== Aufbau =====
function Book:Attach(ui)
    if self.frame or not (ui and ui.frame and ui.inset) or not self:IsActive() then return end
    self.ui = ui
    -- gealterte Tinte: Farben vor dem ersten Einfaerben umstellen
    if Book.Aged() then Book.ink, Book.soft, Book.red = Book.agedInk, Book.agedSoft, Book.agedRed end
    BuildArt(self, ui)
    StyleHeader(self, ui)
    self:Raise()
    self:UpdateTabs(ui)
    self:InkPages(ui, true)
    self:UpdateBack(ui)
    -- Klang beim Auf- und Zuklappen des Buchs
    if ui.frame.HookScript then
        ui.frame:HookScript("OnShow", function() if ONE.Sound then ONE.Sound:Play("open") end end)
        ui.frame:HookScript("OnHide", function() if ONE.Sound then ONE.Sound:Play("close") end end)
    end
end

-- Seiten ueber das Buchbild heben
function Book:Raise()
    if not (self.frame and self.ui) then return end
    local level = self.frame.GetFrameLevel and self.frame:GetFrameLevel() or 0
    for _, list in ipairs({self.ui.tabs or {}, self.ui.views or {}}) do
        for _, entry in pairs(list) do
            if entry.panel and entry.panel.SetFrameLevel then entry.panel:SetFrameLevel(level + 2) end
        end
    end
end

-- Neuer Reiter/Unterseite nach dem Aufbau (Module laden spaeter)
function Book:PanelAdded(ui)
    if not (self:IsActive() and self.frame) then return end
    self:Raise()
    self:UpdateTabs(ui)
end

-- Seitenwechsel: Seite blendet ein, ein Schatten zieht von rechts nach links, Blaettergeraeusch
function Book:TurnPage(panel)
    if not (self:IsActive() and self.frame and panel) then return end
    if panel.SetFrameLevel and self.frame.GetFrameLevel then panel:SetFrameLevel(self.frame:GetFrameLevel() + 2) end
    if type(panel.CreateAnimationGroup) == "function" then
        if not panel.__oneTurn then
            local g = panel:CreateAnimationGroup()
            local a = g:CreateAnimation("Alpha")
            a:SetFromAlpha(0) a:SetToAlpha(1) a:SetDuration(.25)
            panel.__oneTurn = g
        end
        panel.__oneTurn:Stop() panel.__oneTurn:Play()
    end
    local sweep = self.sweep
    if sweep and type(sweep.CreateAnimationGroup) == "function" then
        if not sweep.__oneMove then
            local g = sweep:CreateAnimationGroup()
            local m = g:CreateAnimation("Translation")
            local width = self.inset and self.inset.GetWidth and self.inset:GetWidth() or 700
            m:SetOffset(-(width - 70), 0) m:SetDuration(.3)
            if m.SetSmoothing then m:SetSmoothing("IN") end
            g:SetScript("OnFinished", function() sweep:Hide() end)
            sweep.__oneMove = g
        end
        sweep:Show()
        sweep.__oneMove:Stop() sweep.__oneMove:Play()
    end
    if ONE.Sound then ONE.Sound:Play("page") end
end

-- Aussehen umschalten: "native" (Blizzard) oder "book" – wirkt nach dem Neuladen
function Book:SetEnabled(on)
    local want = on and "book" or "native"
    if Settings().selected == want then return end
    Settings().selected = want
    if ONE.UI and ONE.UI.AskReload then ONE.UI:AskReload(true) end
end

-- ===== Startseite als Doppelseite =====
-- links: Initiale, Begruessung, Siegel-Link; rechts: Inhaltsverzeichnis aus den
-- Startseiten-Kacheln der Module (Kit:RegisterTile). Die Kacheln werden unsichtbar
-- aufgebaut; ihre erste Zeile wird zur Zeile im Verzeichnis, ihre Aktion zum Klick.
local ROMAN = {"I.", "II.", "III.", "IV.", "V.", "VI.", "VII.", "VIII.", "IX."}

local function Print(parent, size, color, wrap)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if fs.SetFont then pcall(fs.SetFont, fs, Book.bodyFont, size, "") end
    Book.Crisp(fs)
    fs.__oneOldPrint, fs.__oneInk = true, true
    fs:SetTextColor(color[1], color[2], color[3])
    if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
    if fs.SetWordWrap then fs:SetWordWrap(wrap and true or false) end
    return fs
end

function Book:BuildHome(panel)
    local T = function(text, ...) if ONE.T then return ONE.T(text, ...) end return text end
    local L, R = self.left, self.right
    local ink, red, soft = self.ink, self.red, {.30, .19, .09}
    -- links: Initiale + Begruessung
    local welcome = T("Willkommen zurück,")
    local initial = Print(panel, 64, red)
    initial:SetPoint("TOPLEFT", panel, "TOPLEFT", L.x, -6)
    initial:SetText(welcome:sub(1, 1))
    local rest = Print(panel, 24, ink)
    rest:SetPoint("TOPLEFT", panel, "TOPLEFT", L.x + 50, -20)
    rest:SetText(welcome:sub(2))
    local name = Print(panel, 24, red)
    name:SetPoint("TOPLEFT", panel, "TOPLEFT", L.x + 50, -50)
    local text = Print(panel, 16, soft, true)
    text:SetPoint("TOPLEFT", panel, "TOPLEFT", L.x, -104)
    text:SetWidth(L.width - 10)
    text:SetText(T("Dein Gildenalltag in diesem Buche: Termine, Gefährten und Wege – alles übersichtlich an einem Ort."))
    -- Siegel-Link: Hauptaktion
    local action = CreateFrame("Button", nil, panel)
    action:SetSize(L.width - 40, 56)
    action:SetPoint("TOPLEFT", panel, "TOPLEFT", L.x + 30, -196)
    local wax = action:CreateTexture(nil, "ARTWORK")
    wax:SetSize(54, 54)
    wax:SetPoint("LEFT", action, "LEFT", 0, 0)
    wax:SetTexture(self.sealArt)
    local label = Print(action, 17, red)
    label:SetPoint("LEFT", wax, "RIGHT", 10, 2)
    label:SetText(T("Heutige Termine ansehen"))
    local line = action:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    line:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -2)
    line:SetHeight(1)
    line:SetColorTexture(red[1], red[2], red[3], .8)
    action:SetScript("OnClick", function() if ONE.Sound then ONE.Sound:Play("seal") end ONE.UI:OpenLink("today") end)
    action:SetScript("OnEnter", function() label:SetTextColor(.7, .14, .04) end)
    action:SetScript("OnLeave", function() label:SetTextColor(red[1], red[2], red[3]) end)

    -- rechts: Inhalt
    local head = Print(panel, 24, red)
    head:SetPoint("TOP", panel, "TOPLEFT", R.x + R.width / 2, -8)
    if head.SetJustifyH then head:SetJustifyH("CENTER") end
    head:SetText(T("Inhalt"))
    local rows, built, ghost = {}, nil, nil
    local function Build()
        if not ONE.Kit or built == ONE.Kit.tilesVersion then return end
        for _, row in ipairs(rows) do row.button:Hide() end
        rows = {}
        ghost = CreateFrame("Frame", nil, panel)
        ghost:SetSize(160, 166)
        ghost:Hide()
        for i, def in ipairs(ONE.Kit:Tiles()) do
            if i > 6 then break end
            local row = {texts = {}}
            local b = CreateFrame("Button", nil, panel)
            b:SetSize(R.width, 58)
            b:SetPoint("TOPLEFT", panel, "TOPLEFT", R.x, -48 - (i - 1) * 64)
            local num = Print(b, 18, red)
            num:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            num:SetText(ROMAN[i])
            local title = Print(b, 19, ink)
            title:SetPoint("TOPLEFT", b, "TOPLEFT", 36, 0)
            local t = T(def.title or def.id or "")
            title:SetText(t:sub(1, 1) .. t:sub(2):lower())
            local arrow = Print(b, 20, red)
            arrow:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, 1)
            arrow:SetText("›")
            local dots = Print(b, 16, soft)
            dots:SetPoint("LEFT", title, "RIGHT", 6, -2)
            dots:SetPoint("RIGHT", arrow, "LEFT", -6, -2)
            dots:SetText(string.rep(".  ", 40))
            local status = Print(b, 15, soft)
            status:SetPoint("TOPLEFT", b, "TOPLEFT", 36, -25)
            status:SetWidth(R.width - 40)
            -- Kachel unsichtbar aufbauen: erste Zeile und Aktion abgreifen
            local body = ONE.Kit:Stack(ghost, 0, 0, 160, 4)
            local plain = body.Text
            body.Text = function(selfStack, ...)
                local fs = plain(selfStack, ...)
                row.texts[#row.texts + 1] = fs
                return fs
            end
            body.Action = function(_, _, handler)
                row.handler = handler
                return CreateFrame("Button", nil, ghost)
            end
            local ok, refresh = pcall(def.build, ghost, body, 160)
            row.refresh = ok and refresh or nil
            b:SetScript("OnClick", function() if row.handler then row.handler() end end)
            b:SetScript("OnEnter", function() title:SetTextColor(red[1], red[2], red[3]) end)
            b:SetScript("OnLeave", function() title:SetTextColor(ink[1], ink[2], ink[3]) end)
            row.button, row.status = b, status
            rows[#rows + 1] = row
        end
        built = ONE.Kit.tilesVersion
    end
    return function()
        name:SetText(((UnitName and UnitName("player")) or "") .. "!")
        Build()
        for _, row in ipairs(rows) do
            if row.refresh then pcall(row.refresh) end
            local first = row.texts[1]
            local line1 = first and first.GetText and first:GetText() or ""
            row.status:SetText(line1)
        end
    end
end
