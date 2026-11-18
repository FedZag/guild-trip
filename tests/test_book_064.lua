-- Offline-Test 0.6.1: Aussehen "Altes Buch" – Einband, Seite, Lesezeichen,
-- Tinte, Umblaettern, Umschalten mit Neuladen.
local root = arg[1] or "src"
local made, played = {}, {}
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, level = 1, regions = {}, children = {}}
    made[#made + 1] = r
    if parent and parent.children then
        if kind == "Texture" or kind == "FontString" then parent.regions[#parent.regions + 1] = r
        else parent.children[#parent.children + 1] = r end
    end
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetTexture(t) self.texture = t end
    function r:SetColorTexture(a, b, c) self.color = {a, b, c} end
    function r:SetFrameLevel(l) self.level = l end
    function r:GetFrameLevel() return self.level end
    function r:GetWidth() return 90 end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:GetObjectType() return kind end
    function r:GetRegions() return unpack(self.regions) end
    function r:GetChildren() return unpack(self.children) end
    function r:SetTextColor(a, b, c) self.textColor = {a, b, c} end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetPoint(...) self.point = {...} end
    function r:SetScript(e, fn) self["scripts_" .. e] = fn end
    function r:GetFont() return self.font or "Fonts\\FRIZQT__.TTF", self.fontSize or 12 end
    function r:SetFont(f, size) self.font, self.fontSize = f, size end
    function r:GetTextColor() return unpack(self.textColor or {1, 1, 1}) end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    function r:CreateAnimationGroup()
        local g = Region("AnimGroup", nil)
        g.owner = self
        function g:CreateAnimation() return Region("Anim", nil) end
        function g:Play() played[#played + 1] = self.owner end
        return g
    end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
local sounds = {}
PlaySound = function(id) sounds[#sounds + 1] = id end
SOUNDKIT = {IG_ABILITY_PAGE_TURN = 836}
local reloadAsked
local ONE = {db = {theme = {selected = "book", uiSounds = true}}}
_G.ProjectONE = ONE
assert(loadfile(root .. "/ONE_Core/Themes.lua"))("ONE_Core", ONE)
assert(loadfile(root .. "/ONE_Core/Book.lua"))("ONE_Core", ONE)
assert(loadfile(root .. "/ONE_Core/Sound.lua"))("ONE_Core", ONE)
local toc = assert(io.open(root .. "/ONE_Core/ONE_Core.toc")):read("*a")
assert(toc:find("UI.lua\nBook.lua", 1, true), "Book.lua nach UI.lua in der TOC")

-- Auswahl bleibt nach dem Neuladen erhalten, fruehere Designs werden nativ
ONE.Themes:Initialize()
assert(ONE.db.theme.selected == "book" and not ONE.Themes:IsNative())
assert(ONE.Themes:Current().text[1] < .3, "dunkle Tinte")
ONE.db.theme.selected = "midnight"
ONE.Themes:Initialize()
assert(ONE.db.theme.selected == "native")

-- Tinte: helle Farben werden dunkel, dunkle bleiben
local r, g, b = ONE.Book.Ink(1, 1, 1)
assert(r < .5 and g < .5 and b < .5, "Weiss wird Tinte")
r, g, b = ONE.Book.Ink(1, .82, 0)
assert(r > g and g > b and r < .5, "Gold bleibt goldbraun")
r = ONE.Book.Ink(.1, .1, .1)
assert(r == .1)

-- Im Blizzard-Aussehen baut das Buch nichts
local function NewUI()
    local frame = Region("Frame")
    local ui = {frame = frame, inset = Region("Frame", frame), tabs = {}, views = {}, sidebarButtons = {}, tabIds = {}}
    ui.pathLabel = Region("FontString", frame)
    ui.backButton, ui.forwardButton = Region("Button", frame), Region("Button", frame)
    ui.closeButton = Region("Button", frame)
    return ui
end
local plain = NewUI()
ONE.Book:Attach(plain)
assert(not ONE.Book.frame, "kein Buch im Blizzard-Aussehen")

-- Buch: Einband, Seite (Bild 3), Seiten darueber, Lesezeichen, Tinte
ONE.db.theme.selected = "book"
local ui = NewUI()
local page = Region("Frame", ui.frame)
local line = Region("FontString", page)
line:SetTextColor(1, 1, 1)
-- roter Blizzard-Knopf (Left/Middle/Right) mit Goldschrift
local blizzButton = Region("Button", page)
blizzButton.Left = Region("Texture", blizzButton)
local buttonText = Region("FontString", blizzButton)
buttonText:SetTextColor(1, .82, 0)
-- Listenzeile (Knopf ohne Blizzard-Bilder): Text wird Tinte
local row = Region("Button", page)
local rowText = Region("FontString", row)
rowText:SetTextColor(1, 1, 1)
-- Haekchen: eigene Beschriftung als Tinte
local check = Region("CheckButton", page)
local checkLabel = Region("FontString", check)
checkLabel:SetTextColor(1, 1, 1)
ui.tabs.home = {panel = page}
local tab = Region("Button", ui.frame)
tab.GetFontString = function() return Region("FontString") end
local oldTabTexture = Region("Texture", tab)
ui.sidebarButtons.home, ui.tabIds, ui.activeTab = tab, {"home"}, "home"
ONE.Book:Attach(ui)
assert(ONE.Book.frame and ONE.Book.texture.texture == ONE.Book.art, "eigenes Buchbild")
local f = io.open(root .. "/ONE_Core/Textures/Book/Book.tga", "rb")
assert(f, "Book.tga fehlt (scripts/build_book.py)") f:close()
for _, name in ipairs({"Tab.tga", "Seal.tga"}) do
    f = io.open(root .. "/ONE_Core/Textures/Book/" .. name, "rb")
    assert(f, name .. " fehlt") f:close()
end
assert(page.level == ONE.Book.frame.level + 2)
-- Gealterte Tinte (Standard an): Abrieb-Bild ueber den Seiten, Sepia-Tinte, brauner Hof
assert(ONE.Book.Aged(), "gealterte Tinte ist Standard")
assert(ONE.Book.wear and ONE.Book.wear.level > page.level + 20, "Abrieb liegt ueber den Seiten")
f = io.open(root .. "/ONE_Core/Textures/Book/Wear.tga", "rb")
assert(f, "Wear.tga fehlt (scripts/build_book.py --wear)") f:close()
assert(ONE.Book.ink == ONE.Book.agedInk and ONE.Book.ink[1] > .2, "Sepia statt fast schwarz")
do
    local fs = {}
    function fs:SetShadowOffset(x, y) self.off = {x, y} end
    function fs:SetShadowColor(r, g, b, a) self.shadow = {r, g, b, a} end
    ONE.Book.Crisp(fs)
    assert(fs.off[1] == 1 and fs.shadow[4] > 0 and fs.shadow[4] < .4, "zarter brauner Hof")
    ONE.db.theme.agedInk = false
    ONE.Book.Crisp(fs)
    assert(fs.off[1] == 0 and fs.shadow[4] == 0, "ausgeschaltet: scharfe Schrift wie vorher")
    ONE.db.theme.agedInk = nil
end
assert(tab.__oneTab and not oldTabTexture.shown, "Lederreiter statt Blizzard-Reiter")
assert(tab.__oneTab.leather.texture == ONE.Book.tabArt)
assert(tab.point and tab.point[2] == ui.frame and tab.point[3] == "TOPRIGHT" and tab.point[4] == ONE.Book.tab.out,
    "Reiter beginnt knapp unter dem Einband")
-- Variante A+: Goldsymbol, aktiver Reiter breiter, Maus laesst ihn mit Namen herausgleiten
do
    local r = tab.__oneTab
    assert(r.icon.texture == ONE.Book.tabIcons, "Symbolblatt")
    for _, name in ipairs({"TabWorn.tga", "TabIcons.tga"}) do
        local fh = io.open(root .. "/ONE_Core/Textures/Book/" .. name, "rb")
        assert(fh, name .. " fehlt (scripts/build_book.py --tabs)") fh:close()
    end
    assert(r.selected and tab.w == ONE.Book.tab.active, "aufgeschlagener Reiter ist breiter")
    function tab:SetWidth(w) self.w = w end
    function r.label:SetAlpha(a) self.alpha = a end
    r.hover = true
    r.anim.scripts_OnUpdate(r.anim, 1)
    assert(tab.w == ONE.Book.tab.hover and r.label.alpha == 1, "Maus: Reiter gleitet heraus, Name sichtbar")
    r.hover = false
    r.anim.scripts_OnUpdate(r.anim, 1)
    assert(tab.w == ONE.Book.tab.active and r.label.alpha == 0, "zurueck, Name wieder weg")
    -- WoW-Beschriftung bleibt unsichtbar, auch nach Auffrischen; Breite wird zurueckgeholt
    local blizzText = Region("FontString", tab)
    function blizzText:SetAlpha(a) self.alpha = a end
    ONE.Book:UpdateTab(tab, true, 1)
    assert(blizzText.alpha == 0, "WoW-Text des Reiters unsichtbar")
    blizzText.alpha = 1
    r.anim.scripts_OnUpdate(r.anim, .016) -- Mock: GetWidth liefert 90 (WoW hat angepasst)
    assert(tab.w == ONE.Book.tab.active and blizzText.alpha == 0, "Breite zurueck, Text wieder weg")
end
assert(line.textColor[1] < .5, "Seitentext in Tinte")
assert(buttonText.textColor[1] == 1, "Blizzard-Knopf behaelt Goldschrift")
assert(rowText.textColor[1] < .5, "Listenzeile in Tinte")
assert(checkLabel.textColor[1] < .5, "Haekchen-Beschriftung in Tinte")
-- Doppelseite: links und rechts trennen sich an der Falz
local L, R = ONE.Book:Spread()
assert(L and R and L.x + L.width < 363 and R.x > 363 and R.x + R.width <= 726)
-- spaeter gesetzte helle Farbe wird ebenfalls Tinte
line:SetTextColor(.85, .85, .85)
assert(line.textColor[1] < .5)

-- alte Druckschrift fuer Seitentext (Morpheus-Ueberschriften bleiben)
assert(line.font == ONE.Book.bodyFont and line.fontSize > 12, "Seitentext in IM FELL English")
local fontFile = io.open(root .. "/ONE_Core/Fonts/IMFellEnglish.ttf", "rb")
assert(fontFile, "Schriftdatei fehlt") fontFile:close()
assert(io.open(root .. "/ONE_Core/Fonts/OFL.txt", "r"), "Lizenz der Schrift fehlt")

-- Kopfzeilen und "zurueck": Knoepfe weg, Link nur auf Unterseiten
assert(ONE.Book.leftHead and ONE.Book.leftHead.text:find("Guild Trip", 1, true), "Kopfzeile links")
assert(not ui.backButton.shown, "kein Zurueck-Knopf im Buch")
assert(not ui.closeButton.shown and ONE.Book.closeLink, "Tinten-Kreuz statt rotem Knopf")
ui.frame.shown = true
ONE.Book.closeLink.scripts_OnClick()
assert(not ui.frame.shown, "Kreuz schliesst das Buch")
assert(not ONE.Book.backLink.shown, "Hauptseite: kein zurueck")
ui.views.sharing = {panel = Region("Frame", ui.frame)}
ui.activeTab = "sharing"
ui.CanGoBack = function() return true end
ONE.Book:UpdateBack(ui)
assert(ONE.Book.backLink.shown, "Unterseite: zurueck sichtbar")
ui.activeTab = "home"
ONE.Book:UpdateBack(ui)
assert(not ONE.Book.backLink.shown)

-- Startseite: Inhaltsverzeichnis aus den Kacheln, Klick fuehrt die Kachel-Aktion aus
local clicked
ONE.T = function(t) return t end
ONE.Kit = {tilesVersion = 1,
    Tiles = function() return {{id = "termine", title = "TERMINE", build = function(_, body)
        local fs = body:Text("lade ...")
        body:Action("Kalender öffnen", function() clicked = true end)
        return function() fs:SetText("Heute keine Termine") end
    end}} end,
    Stack = function() return {Text = function(_, t) local fs = Region("FontString") fs.text = t return fs end} end}
UnitName = function() return "Testheld" end
local home = Region("Frame", ui.frame)
local refreshHome = ONE.Book:BuildHome(home)
refreshHome()
local found = {}
local function Collect(f) for _, r2 in ipairs(f.regions) do if r2.text then found[r2.text] = r2 end end
    for _, c in ipairs(f.children) do Collect(c) end end
Collect(home)
assert(found["W"] and found["illkommen zurück,"] and found["Testheld!"], "Initiale und Name")
assert(found["Inhalt"] and found["I."] and found["Termine"], "Inhaltsverzeichnis")
assert(found["Heute keine Termine"], "Zeile aus der Kachel")
local rowButton = found["Termine"].parent
rowButton.scripts_OnClick()
assert(clicked, "Klick fuehrt die Kachel-Aktion aus")

-- Umblaettern mit Geraeusch
ONE.Book:TurnPage(page)
assert(#played == 2 and sounds[1] == 836)


-- Umschalten fragt nach Neuladen
ONE.UI = {AskReload = function(_, look) reloadAsked = look end}
ONE.Book:SetEnabled(false)
assert(ONE.db.theme.selected == "native" and reloadAsked == true)
assert(ONE.Book:Spread() == nil, "keine Doppelseite im Blizzard-Aussehen")
print("OK test_book_064")
