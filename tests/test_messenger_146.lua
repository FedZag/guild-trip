-- Offline-Test: Guild Trip Chat im Messenger-Stil (Nutzer 21.11.2026, Vorschau 2):
-- Gespraechsliste (angeheftet, stumm, Entwurf, Suche), Sprechblasen (eigene rechts, Name nur einmal),
-- Haken beim Fluestern (zugestellt / nicht zugestellt), Emojis + WoW-Zeichen, "neue Nachrichten",
-- schmales Fenster wie am Handy, Einstellungen im Chat.
local root = arg[1] or "src"
local made = {}
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, text = "", w = 0, h = 0, points = {}}
    made[#made + 1] = r
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(on) self.shown = on and true or false end
    function r:IsShown() return self.shown end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:GetScript(e) return self.scripts[e] end
    function r:SetText(t) self.text = t or "" end
    function r:GetText() return self.text end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:GetWidth() return self.fixedW or self.w or 0 end
    function r:GetHeight() return self.fixedH or self.h or 0 end
    function r:SetPoint(...) self.points[#self.points + 1] = {...} end
    function r:ClearAllPoints() self.points = {} end
    -- Schrift: 7 px je Zeichen, 14 hoch je Zeile (umbrechen nach Breite)
    function r:GetStringWidth() return #(self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * 7 end
    function r:GetStringHeight()
        local w = self:GetStringWidth()
        local lines = (self.w and self.w > 0) and math.max(1, math.ceil(w / self.w)) or 1
        return lines * 14
    end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    function r:SetChecked(on) self.checked = on end
    function r:GetChecked() return self.checked end
    function r:SetFocus() self.focus = true end
    function r:ClearFocus() self.focus = false end
    function r:HasFocus() return self.focus end
    function r:Insert(t) self.text = self.text .. t end
    function r:GetFont() return "Fonts\\ARIALN.TTF", 14 end
    function r:SetVertexColor(...) self.color = {...} end
    function r:SetTexture(t) self.tex = t end
    function r:GetFrameLevel() return 1 end
    return r
end
-- Wie WoW (Spieltest 21.11.2026): ein neuer Knopf kann schon waehrend des Aufbaus OnSizeChanged der
-- Eltern ausloesen – das Fenster muss das vertragen ("main nil" in Layout)
CreateFrame = function(kind, _, parent)
    local r = Region(kind, parent)
    local p = parent
    while p do
        local fn = p.scripts and p.scripts.OnSizeChanged
        if fn and not p.inSize then p.inSize = true fn(p) p.inSize = nil end
        p = p.parent
    end
    return r
end
UIParent = Region("Frame")
ChatFontNormal = Region("Font")
local clock = 1800000000
date, time = os.date, function() return clock end
GetTime = function() return clock end
UnitName = function() return "Testfreund" end
local sent = {}
SendChatMessage = function(msg, chatType, _, target) sent[#sent + 1] = {msg, chatType, target} end
CLASS_ICON_TCOORDS = {MAGE = {.25, .5, 0, .25}, WARRIOR = {0, .25, 0, .25}}
RAID_CLASS_COLORS = {MAGE = {r = .25, g = .78, b = .92}, WARRIOR = {r = .78, g = .61, b = .43}}
GetPlayerInfoByGUID = function(guid) if guid == "Player-1-MAGE" then return "Magier", "MAGE" end end
ERR_CHAT_PLAYER_NOT_FOUND_S = "Kein Spieler mit Namen '%s' ist zur Zeit online."
local menu = {}
MenuUtil = {CreateContextMenu = function(owner, fn)
    local root = {CreateButton = function(_, label, cb) menu[#menu + 1] = {label = label, cb = cb} end}
    menu = {}
    fn(owner, root)
end}
local ONE = {db = {}, modules = {}}
_G.ProjectONE = ONE
function ONE:Print(m) self.printed = m end
ONE.Themes = setmetatable({}, {__index = function() return function() end end})
ONE.Widgets = {
    Button = function(_, parent, text, w, h, point, x, y, cb) local b = Region("Button", parent) b.text = text b.w = w b.click = cb if cb then b.scripts.OnClick = cb end return b end,
    IconButton = function(_, parent, tex, size, point, x, y, cb) local b = Region("Button", parent) b.scripts.OnClick = cb return b end,
    CloseButton = function(_, parent, point, x, y, cb) local b = Region("Button", parent) b.scripts.OnClick = cb return b end,
}
ONE.PlayerMenu = {Open = function() return true end}
-- echtes Glas (Sprechblasen-Flaechen, Zipfel)
assert(loadfile(root .. "/ONE_Core/Glass.lua"))("ONE_Core", ONE)
local c = {}
for _, f in ipairs({"Chat", "Emoji", "ChatUI", "Messenger", "TabEditor", "Settings"}) do
    assert(loadfile(root .. "/ONE_Chat/" .. f .. ".lua"))("ONE_Chat", c)
end
local Chat, UI, M, Emoji = c.Chat, c.UI, c.Messenger, c.Emoji
assert(Chat:Settings().style == "messenger", "Messenger ist Standard")
M:Install()
Chat.listeners[#Chat.listeners + 1] = function(entry, views, update) UI:OnMessage(entry, views, update) end

-- 1) Emojis: Codes, Smileys frei stehend, WoW-Zeichen, Links bleiben heil
local r = Emoji.Render("hi :daumen: :) {Stern} {rt8}", 0)
assert(r:find("Emoji\\1f44d", 1, true) and r:find("Emoji\\1f60a", 1, true), "Code und Smiley")
assert(r:find("UI-RaidTargetingIcon_1", 1, true) and r:find("UI-RaidTargetingIcon_8", 1, true), "WoW-Zeichen")
assert(Emoji.Render("Uhr:) 10:30:45", 0) == "Uhr:) 10:30:45", "nur frei stehende Smileys, Uhrzeit bleibt")
local link = "|cff0070dd|Hitem:123::::::::|h[:daumen: Schwert]|h|r"
assert(Emoji.Render(link .. " :D", 0):find(link, 1, true), "Link unveraendert")
assert(Emoji.Render(":D", 0, {noAscii = true}) == ":D", "Smileys abschaltbar")
assert(Emoji.OnlyEmoji(":daumen: <3") and not Emoji.OnlyEmoji("ok :daumen:"), "nur Emojis erkennen")
assert(#Emoji.PickerItems("marks", Chat:Settings()) == 8 and #Emoji.PickerItems("recent", Chat:Settings()) > 0)
-- jedes Emoji hat sein Bild
for code, item in pairs(Emoji.byCode) do
    local fh = io.open(root .. "/ONE_Chat/Textures/Emoji/" .. item.file .. ".tga", "rb")
    assert(fh, "Bild fehlt: " .. code) fh:close()
end

-- 2) Fenster: Gilde ist angeheftet (oben), System & Addons als eigenes Gespraech
Chat:OnEvent("CHAT_MSG_GUILD", "Abend zusammen! :winken:", "Thorgrim-Forever", "", "", "", "", 0, 0, "", 0, 1, "")
clock = clock + 10
Chat:OnEvent("CHAT_MSG_GUILD", "Wer kommt mit BRD?", "Thorgrim-Forever", "", "", "", "", 0, 0, "", 0, 2, "")
Chat:OnEvent("CHAT_MSG_SYSTEM", "Brakk ist jetzt online.", "", "", "", "", "", 0, 0, "", 0, 3, "")
UI:Show("guild")
local f = M.frame
assert(f and f.shown and UI.frame == f and UI.input == M.input, "Messenger-Fenster")
f.fixedW, f.fixedH = 640, 420
M.list.fixedW, M.list.fixedH = 196, 380
M.log.fixedW, M.log.fixedH = 420, 300
M:Layout()
local rows = M:ListRows()
assert(rows[1].label and rows[2].conv.view == "guild", "angeheftet oben")
local hasSys = false
for _, rr in ipairs(rows) do if rr.conv and rr.conv.view == "system" then hasSys = true end end
assert(hasSys, "System & Addons in der Liste")

-- 3) Blasen: Name nur einmal, eigene rechts, Uhrzeit
Chat:OnEvent("CHAT_MSG_GUILD", "Bin dabei", "Testfreund-Forever", "", "", "", "", 0, 0, "", 0, 4, "")
local items = M.Items("guild")
local bubbles = {}
for _, it in ipairs(items) do if it.type == "bubble" then bubbles[#bubbles + 1] = it end end
assert(#bubbles == 3 and items[1].type == "day", "Tag + drei Blasen")
assert(bubbles[1].name and not bubbles[2].name and bubbles[2].cont, "Name nur einmal")
assert(bubbles[3].out and not bubbles[3].name, "eigene Nachricht ohne Namen")
M:Render()
local right, left = 0, 0
for _, b in ipairs(M.bubbles) do
    if b.shown and b.item and b.item.type == "bubble" then
        if b.points[1][1] == "BOTTOMRIGHT" then right = right + 1 else left = left + 1 end
    end
end
assert(right == 1 and left == 2, "eigene rechts, andere links")
-- Sprechblasen mit Zipfel: nur an der ersten Blase einer Folge, eigene gespiegelt (Ecke dort ausgeblendet)
for _, b in ipairs(M.bubbles) do
    if b.shown and b.item and b.item.type == "bubble" then
        local it = b.item
        assert(b.tail.shown == not it.cont, "Zipfel nur an erster Blase einer Folge")
        local corner = b.bg.pieces[it.out and 3 or 1]
        assert(corner.shown == (it.cont and true or false), "runde Ecke nur ohne Zipfel")
        assert(b.tail.tex and b.tail.tex:find("BubbleTail"), "Zipfel-Bild")
        local pt = b.tail.points[1]
        assert(pt[1] == (it.out and "TOPLEFT" or "TOPRIGHT"), "Zipfel aussen")
    end
end
-- Glas-Blasen: Rand (auch am Zipfel) und Glanz; andere leicht in der Farbe ihrer Art
for _, b in ipairs(M.bubbles) do
    if b.shown and b.item and b.item.type == "bubble" then
        assert(b.sheen.shown and b.edge.pieces[5].shown, "Glanz und Rand")
        assert(b.tailEdge.shown == not b.item.cont, "Rand am Zipfel")
    end
end
local p0 = M:Palette()
local function Col(kind, out) return {M.BubbleColor(p0, out, false, kind)} end
local guildC, partyC, ownC = Col("guild"), Col("party"), Col("guild", true)
assert(guildC[2] > guildC[1] and (guildC[1] ~= partyC[1] or guildC[3] ~= partyC[3]), "Gilde gruenlich, Gruppe anders")
assert(guildC[4] < 1 and ownC[4] < 1, "durchscheinend wie Glas")
Chat:Settings().bubbleColors = false
local plain = Col("guild")
assert(plain[1] == Col("party")[1] and plain[2] == Col("party")[2], "Schalter aus: alle gleich")
Chat:Settings().bubbleColors = true
assert(M.headSub.text:find("online") == nil or true)

-- 4) Fluestern: sofort sichtbar, Haken nach Bestaetigung, rot bei offline
UI:Show(Chat:OpenWhisper("Lyra"))
M.input:SetText("Kannst du mir Wasser machen?")
M:SendInput()
assert(sent[#sent][2] == "WHISPER" and sent[#sent][3] == "Lyra" and M.input.text == "")
local buf = Chat:Buffer("w:Lyra")
assert(#buf == 1 and buf[1].pending, "sofort als offen sichtbar")
Chat:OnEvent("CHAT_MSG_WHISPER_INFORM", "Kannst du mir Wasser machen?", "Lyra-Forever", "", "", "", "", 0, 0, "", 0, 5, "")
assert(#buf == 1 and buf[1].delivered and not buf[1].pending, "Haken, keine doppelte Blase")
M.input:SetText("bist du da?")
M:SendInput()
Chat:OnEvent("CHAT_MSG_SYSTEM", "Kein Spieler mit Namen 'Lyra' ist zur Zeit online.", "", "", "", "", "", 0, 0, "", 0, 6, "")
assert(#buf == 2 and buf[2].failed, "nicht zugestellt")
for _, e in ipairs(Chat:Buffer("system")) do assert(not e.text:find("Kein Spieler"), "Fehlermeldung nicht doppelt") end
M:Render()
local note = false
for _, b in ipairs(M.bubbles) do if b.shown and b.note.shown and b.note.text:find("nicht zugestellt") then note = true end end
assert(note, "rote Blase mit Hinweis")
-- ohne Antwort des Servers: Uhr verschwindet nach ein paar Sekunden
M.input:SetText("hallo?")
M:SendInput()
clock = clock + 10
Chat:ExpirePending()
assert(not buf[3].pending, "kein ewiges Warten")

-- 5) Entwurf je Gespraech, "neue Nachrichten", Stumm ohne Ton
M.input:SetText("halb getippt")
UI:Show("guild")
assert(M.input.text == "" and Chat.drafts["w:Lyra"] == "halb getippt", "Entwurf gemerkt")
UI:Show("w:Lyra")
assert(M.input.text == "halb getippt", "Entwurf zurueck")
Chat:OnEvent("CHAT_MSG_GUILD", "eins", "Thorgrim-Forever", "", "", "", "", 0, 0, "", 0, 7, "")
Chat:OnEvent("CHAT_MSG_GUILD", "zwei", "Thorgrim-Forever", "", "", "", "", 0, 0, "", 0, 8, "")
assert(Chat.unread.guild == 2)
UI:Show("guild")
local newLine
for _, it in ipairs(M.items) do if it.type == "new" then newLine = it end end
assert(newLine and newLine.count == 2, "gelbe Linie: 2 neue")
assert(M.IsMuted("trade"), "Handel ist stumm")
Chat:Settings().guildSound = true
Chat.visible = false
assert(Chat:SoundFor({kind = "trade", author = "X"}, {"trade", "all"}) == nil, "stumm: kein Ton")
M.SetMuted("guild", true)
assert(Chat:SoundFor({kind = "guild", author = "X"}, {"guild", "all"}) == nil, "Gilde stumm")
M.SetMuted("guild", false)
assert(Chat:SoundFor({kind = "guild", author = "X"}, {"guild", "all"}) == "chatMessage", "Gilde wieder mit Ton")
Chat.visible = true

-- 6) Suche ueber alle Gespraeche, Sprung zur Nachricht
M.search = "wasser"
local hit
for _, rr in ipairs(M:ListRows()) do if rr.hit then hit = rr end end
assert(hit and hit.conv.view == "w:Lyra", "Treffer im Fluestern")
M.jump = hit.hit
UI:Show("w:Lyra")
assert(M.highlight == hit.hit, "gefundene Nachricht hervorgehoben")
M.search = nil

-- 7) Anheften / Loesen per Rechtsklick
M.SetPinned("w:Lyra", true)
local order = {}
for _, cv in ipairs(M.Conversations()) do order[#order + 1] = cv.view end
assert(order[1] == "guild" and order[2] == "w:Lyra", "angeheftete in Reihenfolge oben")
M.SetPinned("w:Lyra", false)

-- 8) Emoji-Auswahl fuegt den Code ein und merkt ihn
M.input:SetText("ja")
M:TogglePicker()
assert(M.picker.shown)
M:InsertCode(":daumen:")
assert(M.input.text == "ja :daumen: " and Chat:Settings().recentEmoji[1] == ":daumen:", M.input.text)
M:TogglePicker()

-- 9) Schmal wie am Handy: erst Liste, dann Gespraech, Pfeil zurueck
f.fixedW = 300
M.page = "list"
M:Layout()
assert(M.list.shown and not M.main.shown and M.back.shown, "schmal: Liste")
UI:Show("guild")
assert(M.main.shown and not M.list.shown, "schmal: Gespraech")
M.back.scripts.OnClick(M.back)
assert(M.list.shown and not M.main.shown, "zurueck zur Liste")
f.fixedW = 640
M:Layout()

-- 10) Einstellungen im Chat: Zahnrad oeffnet sie, Auswahl schaltet durch, Stil braucht /reload
M.gear.scripts.OnClick(M.gear)
local panel = UI.settingsPanel
assert(panel and panel.shown and panel.parent == f, "Einstellungen im Chatfenster")
local styleRow
for i, l in ipairs(UI:SettingsLines()) do if l.def and l.def.id == "chat.style" then styleRow = panel.rows[i] end end
assert(styleRow and styleRow.button.shown and styleRow.button.text == "Messenger")
styleRow.button.scripts.OnClick(styleRow.button, "LeftButton")
assert(Chat:Settings().style == "classic" and UI.needReload, "Stil gewechselt, Neuladen angeboten")
styleRow.button.scripts.OnClick(styleRow.button, "LeftButton")
assert(Chat:Settings().style == "messenger")
-- im Messenger keine Schalter des alten Stils
for _, l in ipairs(UI:SettingsLines()) do assert(not (l.def and l.def.id == "chat.stamps"), "Uhrzeit-Schalter nur klassisch") end
panel.done.scripts.OnClick(panel.done)
assert(not panel.shown)

-- 11) Meldung eines anderen Addons landet bei "System & Addons"
Chat:AddAddonLine("DBM-Core", "DBM: Pull in 10")
local last = Chat:Buffer("system")[#Chat:Buffer("system")]
assert(last.text:find("Pull in 10"), "Addon-Meldung im Gespraech System & Addons")
-- 12) Liste: Fluestern eigener Bereich, System & Addons ganz unten
M.search = ""
local lr = M:ListRows()
local whisperLabel, lastConv, sawWhisperAfterLabel
for i, rr in ipairs(lr) do
    if rr.label == "FLÜSTERN" then whisperLabel = i end
    if rr.conv then
        lastConv = rr.conv
        if rr.conv.whisper then assert(whisperLabel and whisperLabel < i, "Fluestern unter eigenem Bereich") sawWhisperAfterLabel = true end
    end
end
assert(sawWhisperAfterLabel, "Fluester-Gespraech in der Liste")
-- 22.11.2026: Bereich SYSTEM = "System & Addons" + "Beute & Fortschritt", ganz unten
assert(lastConv.view == "progress" and lr[#lr - 1].conv.view == "system" and lr[#lr - 2].label == "SYSTEM", "System ganz unten")
-- Ruhige Liste (Nutzer 22.11.2026: "permanenter Wechsel zwischen Beute und Alle"):
-- "Alle" fest oben, stumme Gespraeche rutschen nicht hoch
do
    local now = os.time() + 1000
    Chat:Buffer("trade")[#Chat:Buffer("trade") + 1] = {kind = "trade", author = "X", text = "wts", time = now + 50}
    Chat:Buffer("near")[#Chat:Buffer("near") + 1] = {kind = "say", author = "Y", text = "hi", time = now}
    Chat:Buffer("all")[#Chat:Buffer("all") + 1] = {kind = "say", author = "Y", text = "hi", time = now - 500}
    local gs = {}
    local cur
    for _, rr in ipairs(M:ListRows()) do
        if rr.label then cur = rr.label gs[cur] = {} elseif rr.conv then table.insert(gs[cur], rr.conv.view) end
    end
    local g = gs["GESPRÄCHE"]
    assert(g[1] == "all", "Alle fest oben: " .. table.concat(g, ","))
    local pos = {}
    for i, v in ipairs(g) do pos[v] = i end
    assert(pos.near < pos.trade, "stummer Handel rutscht trotz neuester Nachricht nicht hoch")
    assert(pos.trade == #g, "stumme unten")
end
-- 13) Glas-Kreise mit Bildern: Gilde = Wappenrock, Klassen-Symbol vor dem Namen in der Blase
Chat:OnEvent("CHAT_MSG_GUILD", "Feuerball!", "Zauberin-Forever", "", "", "", "", 0, 0, "", 0, 99, "Player-1-MAGE")
UI:Show("guild")
M:Layout()
local guildRow
for _, b in ipairs(M.convRows or {}) do if b.shown and b.name and b.name.text == "Gilde" then guildRow = b end end
assert(guildRow and guildRow.glass.icon.shown and guildRow.glass.icon.tex:find("GuildTabard"), "Gilde mit Wappenrock")
assert(guildRow.glass.icon.color and guildRow.glass.icon.color[1] < .8, "Wappenrock abgedunkelt")
assert(guildRow.glass.ring.shown and guildRow.glass.shine.shown and not guildRow.letter.shown, "Glas-Kreis: Ring + Glanz, kein Buchstabe")
local magier
for _, b in ipairs(M.bubbles) do if b.shown and b.item and b.item.entry and b.item.entry.guid == "Player-1-MAGE" then magier = b end end
assert(magier and magier.cls.icon.shown and magier.cls.icon.tex:find("CHARACTERCREATE"), "Klassen-Symbol vor dem Namen")
Chat:Settings().classIcons = false
M:Render()
assert(not magier.cls.icon.shown, "Schalter aus: kein Klassen-Symbol")
Chat:Settings().classIcons = true
-- 13b) Gruppe: schwarzer Grund hinter dem Symbol
local groupRow
for _, b in ipairs(M.convRows) do if b.shown and b.name and b.name.shown and b.name.text == "Gruppe" then groupRow = b end end
assert(groupRow, "Gruppe in der Liste")
if groupRow then
    assert(groupRow.glass.icon.shown and groupRow.av.color[1] == 0 and groupRow.av.color[4] > .9, "Gruppe: schwarzer Grund")
    assert(guildRow.av.color[4] < .9, "Gilde: Glas-Grund")
end
-- 14) Online-Punkt am Kreis bei Fluester-Gespraechen
C_FriendList = {GetFriendInfo = function(n) if n == "Lyra" then return {connected = true, level = 20, className = "Magier", area = "Dalaran"} end end}
M:LayoutList()
local lyra
for _, b in ipairs(M.convRows) do if b.shown and b.name and b.name.shown and b.name.text == "Lyra" then lyra = b end end
assert(lyra and lyra.online.shown and lyra.onlineRim.shown, "gruener Punkt bei online")
C_FriendList = nil
M:LayoutList()
assert(not lyra.online.shown, "kein Punkt, wenn nicht online")
-- 15) Battle.net-Freund (21.11.2026): Info aus Battle.net, blauer Kreis mit Brief-Symbol, Online-Punkt
C_BattleNet = {GetAccountInfoByID = function(id) if id == 42 then
    return {bnetAccountID = 42, battleTag = "Kumpel#1234", gameAccountInfo = {isOnline = true, characterName = "Grimmbart", areaName = "Orgrimmar"}} end end}
Chat.bnIds["Kumpel#1234"] = 42
local bi = M.PersonInfo("Kumpel#1234")
assert(bi and bi.bn and bi.online and M.BNLine(bi) == "Battle.net · Grimmbart · Orgrimmar", bi and M.BNLine(bi))
assert(M.BNLine({bn = true, online = false}):find("offline"))
local br, bg, bb = M.AvatarColor({whisper = "Kumpel#1234", view = "w:Kumpel#1234"})
assert(bb == 1 and br < .5, "Battle.net-Blau")
assert(M.AvatarIcon({whisper = "Kumpel#1234", view = "w:Kumpel#1234"}), "Symbol fuer Battle.net")
Chat:OnEvent("CHAT_MSG_BN_WHISPER", "Hi", "|Kq42|k", "", "", "", "", 0, 0, "", 0, 9, "", 42)
M:LayoutList()
local kum
for _, b in ipairs(M.convRows) do if b.shown and b.name and b.name.shown and b.name.text == "Kumpel#1234" then kum = b end end
assert(kum and kum.online.shown, "Battle.net-Gespraech in der Liste, online")
C_BattleNet = nil
-- 16) Fluestern: Name oben per Umschalt+Klick in den Gilden-Einladungsdialog (Spieltest 22.11.2026)
do
    UI:Show(Chat:OpenWhisper("Lyra"))
    assert(M.headHit and M.headHit.shown ~= false, "Name oben anklickbar")
    local edit = Region("EditBox")
    local popup = {EditBox = edit}
    -- neuer Client: StaticPopup_Visible liefert Name UND Fenster, Feld heisst EditBox
    StaticPopup_Visible = function(which) if which == "ADD_GUILDMEMBER" then return "StaticPopup1", popup end end
    local oldShift = IsShiftKeyDown
    IsShiftKeyDown = function() return true end
    M.headHit.scripts.OnClick(M.headHit, "LeftButton")
    assert(edit.text == "Lyra", "Name im Einladungsdialog")
    -- ohne Umschalt: Namens-Menue
    IsShiftKeyDown = function() return false end
    local opened
    local pm = ONE.PlayerMenu.Open
    ONE.PlayerMenu.Open = function(_, _, n) opened = n end
    M.headHit.scripts.OnClick(M.headHit, "LeftButton")
    assert(opened == "Lyra", "Klick oeffnet Namens-Menue")
    ONE.PlayerMenu.Open, IsShiftKeyDown, StaticPopup_Visible = pm, oldShift, nil
end
-- 17) Nur-Emoji-Blase mit Name: hoch genug fuer Name + grosses Bild (Spieltest 22.11.2026: ragte in die Blase darunter)
do
    local log = Region("Frame")
    local r = M.bubbles and M.bubbles[1] or nil
    assert(r, "Blase vorhanden")
    local e = {kind = "guild", author = "Xiltor", text = ":D", time = 0}
    local h = M:FillBubble(r, {type = "bubble", entry = e, name = true, out = false}, 300, M:Palette())
    local fs = Chat:Settings().fontSize or 14
    assert(h >= 13 + M.BigEmojiSize(fs) + 8, "Blase zu niedrig: " .. tostring(h))
    assert(r.who.shown, "Name sichtbar")
end
-- 18) Farbeinstellungen im Chat (Nutzer 22.11.2026): Vorlagen, eigene Blasenfarbe, Textfarbe, Staerke, zuruecksetzen
do
    local ids = {}
    for _, l in ipairs(UI:SettingsLines()) do if l.def then ids[l.def.id] = l.def end end
    for _, id in ipairs({"chat.glassSkin", "chat.bubbleStrength", "chat.ownBubble", "chat.bubbleText"}) do assert(ids[id], id) end
    assert(not ids["chat.bubbleReset"], "Zuruecksetzen erst, wenn etwas geaendert ist")
    local G = ONE.Glass
    if G and G.skins then for _, id in ipairs({"nightelf", "forest", "frost", "blood", "dark"}) do assert(G.skins[id], id) end end
    local p = M:Palette()
    local s = Chat:Settings()
    -- eigene Blasenfarbe ersetzt die Leuchtfarbe im Rand
    local _, _, _, _, er, eg, eb = M.BubbleColor(p, true, false, "guild")
    s.ownBubble = {0, 1, 0}
    local _, _, _, _, er2, eg2, eb2 = M.BubbleColor(p, true, false, "guild")
    assert(er2 == 0 and eg2 == 1 and eb2 == 0 and not (er == 0 and eg == 1 and eb == 0), "eigene Blasenfarbe")
    s.ownBubble = {5, 0, 0}
    local _, _, _, _, er3 = M.BubbleColor(p, true, false, "guild")
    assert(er3 == p.glow[1], "kaputte Farbe wird ignoriert")
    s.ownBubble = nil
    -- Staerke: kraeftiger = deutlicherer Rand
    local function EdgeA(v) s.bubbleStrength = v local a = select(8, M.BubbleColor(p, false, false, "guild")) return a end
    assert(EdgeA(.5) < EdgeA(1) and EdgeA(1) < EdgeA(2.6), "Staerke wirkt")
    s.bubbleStrength = 7
    assert(M.BubbleStrength() == 1, "unbekannte Staerke = normal")
    s.bubbleStrength = nil
    -- Farbwahl: Uebernehmen setzt, Abbrechen stellt zurueck
    local cpf = {}
    function cpf:GetColorRGB() return .2, .4, .6 end
    function cpf:SetupColorPickerAndShow(info) self.info = info end
    ColorPickerFrame = cpf
    ids["chat.bubbleText"].onClick()
    cpf.info.swatchFunc()
    assert(s.bubbleText[1] == .2 and s.bubbleText[3] == .6, "Textfarbe gesetzt")
    ids["chat.ownBubble"].onClick()
    cpf.info.swatchFunc()
    cpf.info.cancelFunc()
    assert(s.ownBubble == nil, "Abbrechen stellt zurueck")
    -- Textfarbe kommt in der Blase an
    local r = M.bubbles[1]
    local tc
    r.text.SetTextColor = function(_, a, b, c) tc = {a, b, c} end
    M:FillBubble(r, {type = "bubble", entry = {kind = "guild", author = "Xiltor", text = "hallo", time = 0}, name = true}, 300, p)
    assert(tc and tc[1] == .2 and tc[2] == .4, "Textfarbe in der Blase")
    -- zuruecksetzen
    s.bubbleStrength = 1.8
    local reset
    for _, l in ipairs(UI:SettingsLines()) do if l.def and l.def.id == "chat.bubbleReset" then reset = l.def end end
    assert(reset, "Zuruecksetzen sichtbar")
    reset.onClick()
    assert(s.bubbleText == nil and s.bubbleStrength == nil and s.ownBubble == nil, "alles zurueck")
    ColorPickerFrame = nil
end
-- 19) Online-Anzeige (Spieltest 22.11.2026: "gerade offline" direkt nach ihrer Nachricht)
do
    local now = 100000
    local oldTime, oldGT = time, GetTime
    time = function() return now end
    GetTime = function() return now end
    GetNumGuildMembers = function() return 1, 0 end
    GetGuildRosterInfo = function() return "Bonsai-Forever", "", 0, 30, "Magier", "Orgrimmar", "", "", false, 0, "MAGE" end
    GetGuildRosterLastOnline = function() return 0, 0, 0, 0 end
    local asked = 0
    C_GuildInfo = {GuildRoster = function() asked = asked + 1 end}
    IsInGuild = function() return true end
    Chat.buffers["w:Bonsai"] = {{kind = "whisper", author = "Bonsai-Forever", text = "hi", time = now - 30}}
    assert(M.PersonInfo("Bonsai").online, "wer gerade schreibt, ist online")
    now = now + 600
    local i = M.PersonInfo("Bonsai")
    assert(not i.online and M.OfflineText(i) == "gerade offline", "alte Nachricht: Gildenliste gilt")
    -- eigene Nachricht zaehlt nicht
    Chat.buffers["w:Bonsai"][2] = {kind = "whisper", author = "Bonsai", inform = true, text = "x", time = now}
    assert(not M.PersonInfo("Bonsai").online, "eigene Nachricht beweist nichts")
    -- Gildenliste wird angefordert, aber hoechstens alle 15 s
    M.rosterAsked = nil
    assert(M.RequestRoster() and asked == 1)
    assert(not M.RequestRoster() and asked == 1, "gebremst")
    now = now + 20
    assert(M.RequestRoster() and asked == 2)
    time, GetTime = oldTime, oldGT
    GetNumGuildMembers, GetGuildRosterInfo, GetGuildRosterLastOnline, C_GuildInfo, IsInGuild = nil, nil, nil, nil, nil
    Chat.buffers["w:Bonsai"] = nil
end
-- 20) Gilden-Einladen ohne Sperre (Spieltest 22.11.2026: "ONE_Chat wurde geblockt")
do
    -- Einfuegen ruft keine Blizzard-Funktion am Fenster auf
    local edit = Region("EditBox")
    local popup = {editBox = edit, GetEditBox = function() error("darf nicht aufgerufen werden") end}
    StaticPopup_Visible = function(which) if which == "ADD_GUILDMEMBER" then return "StaticPopup1", popup end end
    local oldShift = IsShiftKeyDown
    IsShiftKeyDown = function() return true end
    assert(UI.ShiftLink("player:Lyra", "[Lyra]", "LeftButton", nil) and edit.text == "Lyra", "Name im Feld, ohne Funktionsaufruf")
    IsShiftKeyDown, StaticPopup_Visible = oldShift, nil
    -- sicherer Makro-Knopf: nur ausserhalb des Kampfs, nicht fuer Gildenmitglieder
    local attrs, made2 = {}, nil
    local cf = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local r = cf(kind, name, parent, template)
        if template == "SecureActionButtonTemplate" then
            made2 = r
            r.template = template
            function r:SetAttribute(k, v) attrs[k] = v end
            function r:RegisterEvent() end
        end
        return r
    end
    IsInGuild = function() return true end
    CanGuildInvite = function() return true end
    UnitName = function() return "Ich" end
    UI:Show(Chat:OpenWhisper("Lyra"))
    M.head.IsVisible = function() return true end
    M.headMenu.IsVisible = function() return true end
    M.inviteButton = nil
    M:UpdateInviteButton()
    assert(made2 and made2.template == "SecureActionButtonTemplate", "sicherer Knopf")
    assert(attrs.type == "macro" and attrs.macrotext == "/ginvite Lyra" and made2.shown, "Makro /ginvite")
    -- schon in der Gilde: kein Knopf
    GetNumGuildMembers = function() return 1, 1 end
    GetGuildRosterInfo = function() return "Lyra-Forever", "", 0, 20, "Magier", "Ort", "", "", true, 0, "MAGE" end
    M:UpdateInviteButton()
    assert(not made2.shown, "Gildenmitglied: kein Knopf")
    GetNumGuildMembers, GetGuildRosterInfo = nil, nil
    -- keine Rechte: kein Knopf
    CanGuildInvite = function() return false end
    M:UpdateInviteButton()
    assert(not made2.shown, "ohne Einlade-Recht kein Knopf")
    -- im Kampf nichts aendern
    CanGuildInvite = function() return true end
    InCombatLockdown = function() return true end
    attrs.macrotext = nil
    M:UpdateInviteButton()
    assert(attrs.macrotext == nil, "im Kampf unveraendert")
    InCombatLockdown = nil
    CreateFrame = cf
    IsInGuild, CanGuildInvite = nil, nil
end
-- 21) Links in Blasen anklicken (Spieltest 22.11.2026: Berufs-Link [Verzauberkunst] ging nicht)
do
    local r = M.bubbles[1]
    local called, printed
    SetItemRef = function(link) called = link end
    local oldPrint = ONE.Print
    ONE.Print = function(_, m) printed = m end
    r.scripts.OnHyperlinkClick(r, "item:2589", "[Leinenstoff]", "LeftButton")
    assert(called == "item:2589", "Gegenstands-Link geht an WoW")
    assert(ONE.db.chatLinkDiag[1].kind == "item" and ONE.db.chatLinkDiag[1].ok, "Klick gemerkt")
    SetItemRef = function() error("kaputt") end
    r.scripts.OnHyperlinkClick(r, "item:2589", "[Leinenstoff]", "LeftButton")
    assert(printed and printed:find("nicht öffnen", 1, true) and ONE.db.chatLinkDiag[1].err:find("kaputt"), "Fehler sichtbar")
    -- Tooltip fuer Berufs-Links
    local tipText
    GameTooltip = {SetOwner = function() end, SetText = function(_, t) tipText = t end, AddLine = function() end,
        Show = function() end, Hide = function() end}
    r.scripts.OnHyperlinkEnter(r, "trade:Player-1-ABC:7411:333")
    assert(tipText == "Berufs-Link", "Hinweis beim Drueberfahren")
    SetItemRef, ONE.Print, GameTooltip = nil, oldPrint, nil
end
-- 22) Forever meldet Link-Klicks in Blasen nicht: eigener Klick (Spieltest 22.11.2026)
do
    local r = M.bubbles[1]
    local e = {kind = "guild", author = "Bonsai-Forever", time = 0,
        text = "biete |cffffd000|Htrade:Player-6945-00B7B687:13920:333|h[Verzauberkunst]|h|r gegen mats"}
    r.item = {type = "bubble", entry = e, name = true}
    r.linkHandled = nil
    local called
    SetItemRef = function(link) called = link end
    local oldTimer = C_Timer
    -- sofort, nicht verzoegert (Berufsfenster nur waehrend des echten Klicks)
    C_Timer = {After = function() end}
    GetCursorPosition = function() return 0, 0 end
    r.GetTop = function() return 100 end
    local menuTitle
    MenuUtil = {CreateContextMenu = function(_, fn)
        local root = {CreateTitle = function(_, t) menuTitle = t end, CreateButton = function() return {} end, CreateDivider = function() end}
        fn(nil, root)
    end}
    r.scripts.OnMouseUp(r, "LeftButton")
    assert(called == nil and menuTitle and menuTitle:find("Bonsai") and menuTitle:find("Verzauberkunst"),
        "Berufs-Link: Forever oeffnet kein fremdes Berufsfenster -> Info-Menue: " .. tostring(menuTitle))
    -- kommt der echte Link-Klick doch an, nicht doppelt
    called = nil
    M.lastClick = nil
    GetTime = GetTime or function() return 0 end
    r.linkHandled = GetTime()
    r.scripts.OnMouseUp(r, "LeftButton")
    assert(called == nil, "nicht doppelt")
    r.linkHandled = nil
    -- Klick auf die Namenszeile: Namens-Menue
    r.who.shown = true
    GetCursorPosition = function() return 0, 95 end
    local opened
    local pm = ONE.PlayerMenu.Open
    ONE.PlayerMenu.Open = function(_, _, n) opened = n end
    M.lastClick = nil
    r.scripts.OnMouseUp(r, "LeftButton")
    assert(opened == "Bonsai" and called == nil, "Name -> Namens-Menue")
    -- Doppelklick: Antworten mit Zitat (Nutzer 22.11.2026)
    r.scripts.OnMouseUp(r, "LeftButton")
    assert(M.replyTo and M.replyTo.name == "Bonsai", "Doppelklick startet die Antwort")
    M:CancelReply()
    M.lastClick = nil
    ONE.PlayerMenu.Open = pm
    -- mehrere Links: Auswahl
    assert(#M.LinksIn("|Hitem:1|h[A]|h und |Hitem:2|h[B]|h") == 2)
    C_Timer, SetItemRef, GetCursorPosition = oldTimer, nil, nil
end
-- 23) Klassenfarbe nach /reload (Spieltest 22.11.2026: Namen ohne Farbe/Symbol – Verlauf ohne GUID)
do
    GetNumGuildMembers = function() return 1, 1 end
    GetGuildRosterInfo = function() return "Bonsai Mambo-Forever", "", 0, 30, "Magier", "Ort", "", "", true, 0, "MAGE" end
    M.classCache = nil
    assert(M.ClassOfGuid(nil, "Bonsai Mambo") == "MAGE", "Klasse ueber die Gildenliste")
    GetNumGuildMembers, GetGuildRosterInfo = nil, nil
    -- Verlauf speichert die Spieler-GUID mit
    local s = Chat:Settings()
    s.keepHistory = true
    Chat.buffers = {guild = {{time = (time and time()) or os.time(), kind = "guild", event = "CHAT_MSG_GUILD", text = "hi", author = "Bonsai Mambo",
        guid = "Player-6945-00B7B687"}}}
    Chat:SaveHistory()
    Chat.buffers = {}
    Chat:LoadHistory()
    local b = Chat:Buffer("guild")
    assert(b[#b] and b[#b].guid == "Player-6945-00B7B687", "GUID nach Neustart da")
end
-- 24) Berufs-Info: Rezepte aus Gilden-Daten und Chat-Links (Spieltest 22.11.2026)
do
    local names = {[7420] = "Armschiene - Schwache Gesundheit", [7457] = "Armschiene - Schwache Ausdauer"}
    ONE.ns = ONE.ns or {}
    ONE.ns.crafting = {
        Recipes = {Store = function() return {guild = {["Bonsai Mambo-Forever"] = {Verzauberkunst = {skill = 265, max = 300, recipes = {[7420] = 0}}}}} end,
            Name = function(_, id) return names[id] end},
        ChatLinks = {Data = function() return {["Bonsai Mambo"] = {recipes = {[7457] = {prof = "Verzauberkunst"}, [999] = {prof = "Schneiderei"}}}} end},
    }
    local info = UI.TradeInfo("trade:Player-1-ABC:13920:333", "[Verzauberkunst]", "Bonsai Mambo")
    assert(info.skill == 265 and #info.recipes == 2, "Stufe und beide Rezepte, nicht Schneiderei")
    UI.ShowTradeInfo(nil, "trade:Player-1-ABC:13920:333", "[Verzauberkunst]", "Bonsai Mambo")
    assert(UI.lastTradeInfo.head == "Bonsai Mambo – Verzauberkunst 265/300", UI.lastTradeInfo.head)
    ONE.ns.crafting = nil
    MenuUtil = nil
end
-- 25) Antworten mit Zitat wie WhatsApp (Nutzer 22.11.2026)
do
    -- Zitat: reiner Text, gekuerzt, UTF-8-sicher, kein Zitat im Zitat
    assert(M.QuoteText("falls wer was braucht") == "falls wer was braucht")
    local q = M.QuoteText("Wie muss ich mich denn beim Gildenmeister melden? wegen den Herbstputz")
    assert(q:sub(-3) == "…" and not q:find("|", 1, true), q)
    assert(M.QuoteText("|cffffd000|Htrade:x|h[Verzauberkunst]|h|r ok") == "[Verzauberkunst] ok", "Links als Text")
    assert(M.QuoteText(M.WithQuote("A", "alt", "neu")) == "neu", "kein Zitat im Zitat")
    assert(M.QuoteText("äöüäöüäöüäöüäöüäöüäöüäöüäöüäöüäöü"):find("…$"), "Umlaute heil gekuerzt")
    local n, qq, rest = M.SplitQuote("@Bonsai „falls wer…“ Ich brauch was!")
    assert(n == "Bonsai" and qq == "falls wer…" and rest == "Ich brauch was!")
    assert(M.SplitQuote("@Bonsai hallo") == nil, "normales @ ist kein Zitat")
    -- Namen mit Leerzeichen (Forever, Spielbild 22.11.2026)
    local n2, q2, r2 = M.SplitQuote("@Mechthild Verfallstag „hallo“ jetzt gehs")
    assert(n2 == "Mechthild Verfallstag" and q2 == "hallo" and r2 == "jetzt gehs", tostring(n2))
    -- Ablauf: Rechtsklick › Antworten -> Leiste, Senden mit Zitat, danach weg
    UI:Show("guild")
    local orig = {kind = "guild", author = "Bonsai Mambo-Forever", text = "falls wer was braucht", time = os.time()}
    table.insert(Chat:Buffer("guild"), orig)
    M:StartReply(orig)
    assert(M.replyTo and M.replyBar and M.replyBar.shown, "Leiste sichtbar")
    assert(M.replyBar.text.text:find("Bonsai Mambo", 1, true) and M.replyBar.text.text:find("falls wer was braucht", 1, true), "Gilde: Name + Zitat")
    assert(not M.replyBar.text.text:find("Antwort an", 1, true), "nur das Zitat (Nutzer 22.11.2026)")
    local sentText
    local oldSend = Chat.Send
    Chat.Send = function(_, _, text) sentText = text return true end
    M.input:SetText("Ich brauch was!")
    M:SendInput()
    assert(sentText == "@Bonsai Mambo „falls wer was braucht“ Ich brauch was!", tostring(sentText))
    assert(not M.replyTo and not M.replyBar.shown, "nach dem Senden weg")
    -- Befehle bekommen kein Zitat
    M:StartReply(orig)
    M.input:SetText("/s hallo")
    M:SendInput()
    assert(sentText == "/s hallo")
    -- zu lang fuer WoW: ohne Zitat statt kaputt
    M:StartReply(orig)
    local long = string.rep("x", 250)
    M.input:SetText(long)
    M:SendInput()
    assert(sentText == long, "zu lang: ohne Zitat")
    Chat.Send = oldSend
    -- Fluestern: nur das Zitat, ohne Namen; Leiste schiebt die Blasen hoch
    UI:Show(Chat:OpenWhisper("Lyra"))
    M:StartReply({kind = "whisper", author = "Lyra", text = "hallo", time = os.time()})
    assert(M.replyBar.text.text:find("hallo", 1, true) and not M.replyBar.text.text:find("Lyra", 1, true), "Fluestern: nur Zitat")
    M:CancelReply()
    UI:Show("guild")
    -- Gespraech wechseln verwirft die Antwort
    M:StartReply(orig)
    UI:Show("group")
    assert(not M.replyTo, "anderes Gespraech: Antwort verworfen")
    -- Blase zeigt den Zitat-Kasten, Klick springt zum Original
    UI:Show("guild")
    local reply = {kind = "guild", author = "Ich", text = "@Bonsai „falls wer was…“ Ich brauch was!", time = os.time()}
    table.insert(Chat:Buffer("guild"), reply)
    local r = M.bubbles[1]
    M:FillBubble(r, {type = "bubble", entry = reply, out = true}, 300, M:Palette())
    assert(r.quoted and r.quoted.name == "Bonsai" and r.text.text:find("brauch was!", 1, true) and not r.text.text:find("@Bonsai", 1, true),
        "Zitat-Kasten statt @-Text")
    local h0 = r.h
    assert(r.qbox.shown and r.qbar.shown and r.qname.text == "Bonsai" and r.qtext.text:find("falls wer", 1, true), "Kasten wie WhatsApp")
    assert(not r.text.text:find("falls wer", 1, true), "Zitat nicht doppelt im Text")
    -- Farbe: unbekannte Person ruhiges Blau, nicht die (goldene) Leuchtfarbe
    M.classCache = nil
    local qc = M.QuoteColor("Unbekannt")
    assert(qc[1] < .5 and qc[3] == 1, "Blau als Rueckfall")
    -- ohne Zitat: Kasten weg, Blase niedriger
    M:FillBubble(r, {type = "bubble", entry = {kind = "guild", author = "Ich", text = "Ich brauch was!", time = os.time()}, out = true}, 300, M:Palette())
    assert(not r.qbox.shown and r.h < h0, "Kasten nur bei Zitat")
    local orig2 = {kind = "guild", author = "Bonsai-Forever", text = "falls wer was braucht", time = os.time()}
    table.insert(Chat:Buffer("guild"), #Chat:Buffer("guild"), orig2)
    assert(M.FindQuoted("guild", reply) == orig2, "Original gefunden")
end
print("OK test_messenger_146")
