-- Offline-Test 0.7.3: Chat schmal ziehen (Nutzer 19.11.2026, Vorschau C): Reiter oben als Tabs
-- (schmal nur Kaestchen, zu viele -> Menue "»"), Fluestern links als Wappen-Leiste (zu viele -> "…"),
-- kleinste Breite 280, "An:" gekuerzt. Dazu: eigenes Aussehen und eigene Glas-Farben nur fuer den Chat.
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, lines = {}, text = "", points = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(on) self.shown = on and true or false end
    function r:IsShown() return self.shown end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:GetScript(e) return self.scripts[e] end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetWidth(w) self.w = w end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:GetHeight() return self.h or 300 end
    function r:GetWidth() return self.w or 600 end
    function r:SetResizeBounds(a, b) self.minW, self.minH = a, b end
    function r:SetPoint(...) self.points[#self.points + 1] = {...} end
    function r:ClearAllPoints() self.points = {} end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    function r:CreateAnimationGroup()
        local g = Region("AnimGroup", self)
        function g:CreateAnimation() return Region("Anim", g) end
        function g:Play() self.playing = true end
        function g:Stop() self.playing = false end
        function g:IsPlaying() return self.playing end
        return g
    end
    function r:AddMessage(t) self.lines[#self.lines + 1] = t end
    function r:Clear() self.lines = {} end
    function r:SetFocus() self.focus = true end
    function r:GetFont() return "Fonts\\ARIALN.TTF", 14 end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
date, time = os.date, function() return 1800000000 end
SendChatMessage = function() end
local shift = false
IsShiftKeyDown = function() return shift end
local menu
MenuUtil = {CreateContextMenu = function(owner, fn)
    menu = {}
    fn(nil, {CreateButton = function(_, text, cb) menu[#menu + 1] = {text = text, cb = cb} end})
end}

local ONE = {db = {theme = {look = "native"}}, modules = {}}
_G.ProjectONE = ONE
function ONE:Print(m) self.printed = m end
-- Themes wie im Spiel: im Glas-Aussehen Glas-Flaechen fuer Fenster und Karten
ONE.Themes = setmetatable({
    RegisterWindow = function(_, f) if ONE.Glass:Active() then ONE.Glass:Surface(f, "window") end end,
    RegisterPanel = function(_, f) if ONE.Glass:Active() then ONE.Glass:Surface(f, "card") end end,
}, {__index = function() return function() end end})
ONE.Widgets = {
    Button = function(_, parent, text, w, h, point, x, y, cb) local b = Region("Button", parent) b.text = text b.click = cb b.w = w return b end,
    CloseButton = function(_, parent) return Region("Button", parent) end,
}
-- echtes Glas-Modul (Farben, Ablagen)
assert(loadfile(root .. "/ONE_Core/Glass.lua"))("ONE_Core", ONE)
local G = ONE.Glass
assert(not G:Active(), "Hauptfenster: Blizzard")

local c = {}
for _, f in ipairs({"Chat", "ChatUI", "TabEditor", "Settings"}) do assert(loadfile(root .. "/ONE_Chat/" .. f .. ".lua"))("ONE_Chat", c) end
local Chat, UI = c.Chat, c.UI
Chat.listeners[#Chat.listeners + 1] = function(entry, views) UI:OnMessage(entry, views) end

-- 1) Eigenes Aussehen nur fuer den Chat: Glas, obwohl das Hauptfenster Blizzard ist
assert(UI.LookSetting() == "auto" and Chat:Look() == "native", "Standard: wie das Hauptfenster")
UI.SetLook("glass")
assert(Chat:Look() == "glass" and Chat:Settings().look == "glass")
local surfacesBefore = #G.surfaces
UI:Show("all")
assert(UI.glass and not UI.modern, "Chat im Glas-Aussehen")
assert(G.forceLook == nil and not G:Active(), "Umschalten nur waehrend des Aufbaus")
assert(#G.surfaces > surfacesBefore, "Glas-Flaechen im Chat")
for i = surfacesBefore + 1, #G.surfaces do assert(type(G.surfaces[i].store) == "function", "Chat-Flaeche nutzt Chat-Farben") end
assert(UI.frame.minW == 280, "kleinste Breite 280 (vorher 440)")

-- 2) Eigene Glas-Farben: Hauptfenster bleibt unberuehrt
assert(UI.GlassSkinSetting() == "main")
UI.SetGlassSkin("horde")
assert(Chat:GlassStore().skin == "horde" and G.Store().skin == "azeroth", "nur der Chat ist Horde")
assert(G:Palette(Chat:GlassStore()).glow[1] > .8 and G:Palette().glow[2] > .8, "zwei Paletten")
Chat:GlassStore().alpha = .5
assert(G:Palette(Chat:GlassStore()).alpha == .5 and G:Palette().alpha == G.DEFAULT_ALPHA, "Deckkraft getrennt")
assert(G.skins.horde.alpha == nil, "Skin-Vorlage wird nicht veraendert")
G:SetCustom("glow", 0, 1, 0, UI.ChatGlass())
assert(Chat:GlassStore().skin == "custom" and Chat:GlassStore().glow[2] == 1 and G.Store().skin == "azeroth")
assert(UI:Palette().glow[2] == 1, "Chatfenster nutzt die eigene Leuchtfarbe")
UI.SetGlassSkin("main")
assert(Chat:GlassStore() == nil, "zurueck: wie das Hauptfenster")
-- alter Schalter "schlicht" wird als Auswahl gezeigt und beim Wechsel aufgeraeumt
Chat:Settings().look, Chat:Settings().flat = nil, true
assert(UI.LookSetting() == "flat" and Chat:Look() == "flat")
UI.SetLook("auto")
assert(Chat:Settings().flat == nil and Chat:Settings().look == nil and Chat:Look() == "native")
UI.SetLook("glass")

-- 3) Breit: alle Reiter mit Namen, kein Menue
UI.frame.w, UI.tabBar.w = 700, 676
UI:Refresh()
assert(UI.tabsNamed, "breit: Namen")
for i = 1, 5 do assert(UI.tabButtons[i].shown and UI.tabButtons[i].text.shown, "Reiter " .. i) end
assert(not UI.tabMore.shown and UI.tabAdd.shown)
assert(UI.toButton.w == 110)

-- 4) Schmal (300): nur Kaestchen, der gewaehlte mit Namen; alle fuenf erreichbar
UI.frame.w, UI.tabBar.w = 300, 276
UI:Show("guild")
assert(not UI.tabsNamed, "schmal: Kaestchen")
for i, b in ipairs(UI.tabButtons) do
    if i <= 5 then
        assert(b.shown, "Reiter " .. i .. " sichtbar")
        assert(b.text.shown == (b.entry.view == "guild"), "nur der gewaehlte mit Namen")
    end
end
assert(not UI.tabMore.shown, "fuenf Reiter passen ohne Menue")
assert(UI.toButton.w == 74 and UI.toButton.text == "An: Gilde", UI.toButton.text)
UI.tabButtons[3].scripts.OnClick(UI.tabButtons[3], "LeftButton")
assert(UI.current == "group", "Klick auf Kaestchen wechselt")

-- 5) Viele eigene Reiter: Rest im Menue "»", gewaehlter bleibt sichtbar, Zaehler am "»"
for i = 1, 8 do Chat:SaveTab({label = "Eigen" .. i, kinds = {guild = true}}) end
local last = Chat:Tabs()[#Chat:Tabs()]
UI:Show(last.id)
assert(UI.tabMore.shown and #UI.tabMore.hidden > 0, "Menue fuer den Rest")
local lastBtn
for _, b in ipairs(UI.tabButtons) do if b.entry and b.entry.view == last.id then lastBtn = b end end
assert(lastBtn and lastBtn.shown, "gewaehlter Reiter bleibt sichtbar")
local seen = {}
for _, b in ipairs(UI.tabButtons) do if b.shown then seen[b.entry.view] = true end end
for _, h in ipairs(UI.tabMore.hidden) do seen[h.view] = true end
for _, t in ipairs(Chat:Tabs()) do assert(seen[t.id], "Reiter erreichbar: " .. t.label) end
UI.tabMore.scripts.OnClick(UI.tabMore)
assert(menu and #menu == #UI.tabMore.hidden)
menu[1].cb()
assert(UI.current == UI.tabMore.hidden[1].view or seen[UI.current])
-- Rechtsklick auf eigenen Reiter: bearbeiten
local realEdit, edited = UI.EditTab, nil
UI.EditTab = function(_, t) edited = t end
lastBtn.scripts.OnClick(lastBtn, "RightButton")
assert(edited == last, "Rechtsklick bearbeitet den Reiter")
UI.EditTab = realEdit
for i = #Chat:Tabs(), 6, -1 do Chat:RemoveTab(Chat:Tabs()[i].id) end
UI:Show("all")

-- 6) Fluestern: Wappen mit Anfangsbuchstabe, Zahl, Umschalt+Klick schliesst
Chat:OnEvent("CHAT_MSG_WHISPER", "Hallo", "Thrall-Forever", "", "", "", "", 0, 0, "", 0, 9, "")
Chat:OnEvent("CHAT_MSG_WHISPER", "Moin", "Ärgon", "", "", "", "", 0, 0, "", 0, 10, "")
local thrall, aergon
for _, r in ipairs(UI.rows) do
    if r.entry and r.entry.whisper == "Thrall" then thrall = r end
    if r.entry and r.entry.whisper == "Ärgon" then aergon = r end
end
assert(thrall and thrall.shown and thrall.letter.text:find("T") and thrall.badge.text:find("1"), "Wappen mit Zahl")
assert(aergon and aergon.letter.text:find("Ä"), "Umlaut als Anfangsbuchstabe")
assert(UI.rowAdd.shown, "+ fuer neues Gespraech")
thrall.scripts.OnClick(thrall, "LeftButton")
assert(UI.current == "w:Thrall" and UI.headClose.shown and UI.headMenu.shown)
UI.headClose.click()
assert(UI.current == "all", "Kopfzeile x schliesst")
local still = false
for _, w in ipairs(Chat.whispers) do if w.name == "Thrall" then still = true end end
assert(not still)
shift = true
aergon.scripts.OnClick(aergon, "LeftButton")
shift = false
assert(#Chat.whispers == 0, "Umschalt+Klick schliesst")

-- 7) Viele Gespraeche bei kleiner Hoehe: Rest unter "…"
for i = 1, 9 do Chat:OnEvent("CHAT_MSG_WHISPER", "hi", "Name" .. i, "", "", "", "", 0, 0, "", 0, 20 + i, "") end
UI.list.h = 150
UI:Refresh()
assert(UI.rowMore.shown and #UI.rowMore.hidden > 0, "Rest im Menue …")
local shown = 0
for _, r in ipairs(UI.rows) do if r.shown then shown = shown + 1 end end
assert(shown + #UI.rowMore.hidden == #Chat.whispers, "jedes Gespraech erreichbar")
UI.rowMore.scripts.OnClick(UI.rowMore)
menu[#menu].cb()
assert(UI.current == UI.rowMore.hidden[#UI.rowMore.hidden].view)

-- 8) Optionen › Chat: Aussehen-Auswahl, Glas-Farben nur im Glas sichtbar
local reg = {}
Chat:Settings().style = "classic" -- "Aussehen des Chats" gibt es nur im alten Stil
for _, o in ipairs(UI:SettingDefs()) do reg[o.id] = o end
assert(reg["chat.look"] and reg["chat.glassSkin"] and reg["chat.glassGlow"] and reg["chat.glassTint"])
assert(not reg["chat.flat"], "alter Schalter ersetzt")
assert(reg["chat.look"].get() == "glass" and reg["chat.glassSkin"].visible())
reg["chat.look"].set("native")
assert(not reg["chat.glassSkin"].visible(), "Glas-Farben nur bei Glas")
reg["chat.look"].onChange()
assert(ONE.printed:find("/reload"))
-- ESC schliesst den Chat nicht (Nutzer 19.11.2026): Fenster steht nicht in UISpecialFrames
do
    local src = assert(io.open(root .. "/ONE_Chat/ChatUI.lua")):read("*a"):gsub("%-%-[^\n]*", "")
    assert(not src:find('UISpecialFrames, "GuildTripChatWindow"', 1, true), "Chat darf nicht per ESC schliessen")
end
-- 9) Umschalt+Klick auf Namen: in den Gilden-Einladungsdialog bzw. ins Eingabefeld (Nutzer 19.11.2026)
do
    local edit = Region("EditBox")
    _G.StaticPopup1 = {editBox = edit}
    StaticPopup_Visible = function(which) return which == "ADD_GUILDMEMBER" and "StaticPopup1" or nil end
    shift = true
    UI.log.scripts.OnHyperlinkClick(UI.log, "player:Thrall-Forever:9", "[Thrall]", "LeftButton")
    assert(edit.text == "Thrall-Forever", "Name im Einladungsdialog")
    StaticPopup_Visible = function() return nil end
    function UI.input:HasFocus() return true end
    function UI.input:Insert(t) self.text = (self.text or "") .. t end
    UI.input.text = "Hallo "
    UI.log.scripts.OnHyperlinkClick(UI.log, "player:Jaina:3", "[Jaina]", "LeftButton")
    assert(UI.input.text == "Hallo Jaina", "Name ins Eingabefeld")
    UI.log.scripts.OnHyperlinkClick(UI.log, "item:1234", "|cff|Hitem:1234|h[Schwert]|h|r", "LeftButton")
    assert(UI.input.text:find("Schwert", 1, true), "Gegenstand ins Eingabefeld")
    shift = false
    menu = nil
    UI.input.HasFocus = function() return false end
    StaticPopup_Visible, _G.StaticPopup1 = nil, nil
end
-- 10) Glas: Eingabefeld hat eine Glas-Flaeche mit Chat-Farben
assert(UI.inputGlass and type(UI.inputGlass.store) == "function", "Eingabefeld aus Glas")
-- 11) Pruefung /trip chatdiag liefert Zeilen
local diag = UI:Diag()
assert(#diag >= 5 and diag[1]:find("^look"), "Chat-Pruefung")
-- 12) Glas bleibt durchsichtig: "Hintergrund" (SetAlpha) fasst die Glas-Teile nicht an,
-- sondern wirkt ueber die Farbe; Glas-Teile werden beim Oeffnen neu eingefaerbt
do
    local glassTex = 0
    for t in pairs(UI.glassTex) do glassTex = glassTex + 1 end
    assert(glassTex > 0, "Glas-Teile bekannt")
    for _, part in ipairs(UI:BackgroundParts()) do assert(not UI.glassTex[part], "Glas-Teil nicht per SetAlpha") end
    local sf
    for _, x in ipairs(UI.glassSurfaces) do if x.kind == "window" then sf = x end end
    local seen
    local piece = sf.fill.pieces[5]
    piece.SetVertexColor = function(_, r, g, b, a) seen = a end
    local touched = false
    local realParts = UI.BackgroundParts
    local fake = {SetAlpha = function() touched = true end}
    UI.BackgroundParts = function() return {fake} end
    Chat:Settings().opacity = .5
    UI:ApplyLook()
    UI.BackgroundParts = realParts
    assert(not touched, "Glas: kein SetAlpha auf Hintergrund (Grundflaeche wuerde dunkel)")
    assert(seen and math.abs(seen - G:Palette(Chat:GlassStore()).alpha * .5) < .001, "Deckkraft ueber die Farbe")
    Chat:Settings().opacity = 1
end
print("OK test_chatnarrow_127")
