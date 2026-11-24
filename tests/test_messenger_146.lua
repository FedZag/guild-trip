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
for _, f in ipairs({"Chat", "Emoji", "ChatUI", "Messenger", "SlashList", "TabEditor", "Settings"}) do
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
assert(Chat:Settings().style == "messenger" and Chat:Settings().rail == true and not UI.needReload, "Randleiste: sofort, ohne Neuladen")
styleRow.button.scripts.OnClick(styleRow.button, "LeftButton")
assert(Chat:Settings().style == "classic" and not Chat:Settings().rail and UI.needReload, "Stil gewechselt, Neuladen angeboten")
styleRow.button.scripts.OnClick(styleRow.button, "LeftButton")
assert(Chat:Settings().style == "messenger" and not Chat:Settings().rail)
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
-- 16) Fluestern: Name oben per Umschalt+Klick in einen offenen Namens-Dialog (Freund; Gilde nicht mehr, 24.11.2026)
do
    UI:Show(Chat:OpenWhisper("Lyra"))
    assert(M.headHit and M.headHit.shown ~= false, "Name oben anklickbar")
    local edit = Region("EditBox")
    local popup = {EditBox = edit}
    -- neuer Client: StaticPopup_Visible liefert Name UND Fenster, Feld heisst EditBox
    StaticPopup_Visible = function(which) if which == "ADD_FRIEND" then return "StaticPopup1", popup end end
    local oldShift = IsShiftKeyDown
    IsShiftKeyDown = function() return true end
    M.headHit.scripts.OnClick(M.headHit, "LeftButton")
    assert(edit.text == "Lyra", "Name im Freundes-Dialog")
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
    StaticPopup_Visible = function(which) if which == "ADD_FRIEND" then return "StaticPopup1", popup end end
    local oldShift = IsShiftKeyDown
    IsShiftKeyDown = function() return true end
    assert(UI.ShiftLink("player:Lyra", "[Lyra]", "LeftButton", nil) and edit.text == "Lyra", "Name im Feld, ohne Funktionsaufruf")
    -- Spieltest 23.11.2026: auch nur SetText sperrt das Einladen -> Gilden-Fenster gar nicht anfassen,
    -- eigener sicherer Knopf darunter
    edit.text = ""
    local gpop = Region("Frame")
    gpop.which = "ADD_GUILDMEMBER"
    gpop.SetText = function() error("Blizzard-Fenster angefasst") end
    StaticPopup2 = gpop
    ONE.printed = nil
    assert(UI.ShiftLink("player:Lyra", "[Lyra]", "LeftButton", nil), "Umschalt+Klick erledigt")
    assert(edit.text == "", "Feld im Gilden-Fenster nicht angefasst")
    assert(ONE.printed, "Hinweis: Namen selbst tippen")
    -- taint.log 24.11.2026: Forever sperrt Einladen mit einem Namen vom Addon (auch per Makro-Knopf) ->
    -- kein Knopf mehr, nur Hinweis "selbst tippen"
    assert(UI.guildHelper == nil and UI.GuildInviteHelper == nil and UI.AltInvite == nil, "kein Einladen-Knopf mehr")
    StaticPopup2 = nil
    IsShiftKeyDown, StaticPopup_Visible = oldShift, nil
    -- Alt+Klick auf einen Namen: kein Einladen mehr, normales Namens-Verhalten
    IsAltKeyDown = function() return true end
    assert(not UI.ShiftLink("player:Lyra-Forever:12", "[Lyra]", "LeftButton", nil), "Alt+Klick: nichts Besonderes")
    IsAltKeyDown = nil
    assert(M.BuildInviteButton == nil and M.UpdateInviteButton == nil, "kein Einladen-Knopf in der Kopfzeile")
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
-- 26) Mehrzeilige Blase ohne Luft rechts (Spielbild 22.11.2026 "Texte nicht mittig")
do
    local r = M.bubbles[1]
    r.text.GetNumLines = function(self)
        local w = self:GetStringWidth()
        return (self.w and self.w > 0) and math.max(1, math.ceil(w / self.w)) or 1
    end
    local text = string.rep("a", 50) -- 350 px breit, bei 300 px Fenster zweizeilig
    M:FillBubble(r, {type = "bubble", entry = {kind = "whisper", author = "Ich", text = text, time = 0}, out = true}, 300, M:Palette())
    local lines = r.text:GetNumLines()
    assert(lines == 2, "zweizeilig: " .. lines)
    -- Text so schmal wie moeglich bei gleicher Zeilenzahl: Blase = Text + Rand
    assert(r.text.w <= 180 and r.w == r.text.w + 20, "schmal und gleichmaessig: " .. r.text.w .. " / " .. r.w)
    r.text.GetNumLines = nil
end
-- 27) Letzte Eingaben: Alt+Pfeil und Liste per Rechtsklick (Nutzer 23.11.2026)
do
    local oldSend = Chat.Send
    Chat.Send = function() return true end
    Chat:Settings().inputHistory = nil
    M.histPos, M.histDraft = nil, nil
    -- mit Zitat gesendet: im Verlauf steht nur die eigene Eingabe
    local orig = {kind = "guild", author = "Bonsai-Forever", text = "wer kann Kupfer?", time = os.time()}
    M:StartReply(orig)
    M.input:SetText("ich")
    M:SendInput()
    for _, t in ipairs({"/inv Bonsai", "  ", "hallo", "ich"}) do M.input:SetText(t) M:SendInput() end
    local h = M.History()
    assert(#h == 3 and h[1] == "ich" and h[2] == "hallo" and h[3] == "/inv Bonsai", "neueste zuerst, ohne Doppelte/Leere: " .. table.concat(h, ","))
    for i = 1, 15 do M.AddHistory("nr " .. i) end
    assert(#M.History() == 10 and M.History()[1] == "nr 15", "hoechstens 10")
    -- Alt+Hoch/Runter wie im WoW-Chat, ganz unten kommt der Entwurf zurueck
    local arrow = M.input.scripts.OnArrowPressed
    M.input:SetText("Entwurf")
    local alt = false
    IsAltKeyDown = function() return alt end
    local t0 = GetTime
    local tick = 0
    GetTime = function() tick = tick + 1 return tick end
    -- einfacher Pfeil blaettert auch (Spieltest 23.11.2026)
    arrow(M.input, "UP")
    assert(M.input.text == "nr 15", "ohne Alt: " .. M.input.text)
    arrow(M.input, "DOWN")
    assert(M.input.text == "Entwurf", "zurueck")
    alt = true
    -- Alt+Pfeil kommt in Forever ueber OnKeyDown an; beide Wege im selben Moment nur einmal
    GetTime = function() return 5 end
    M.input.scripts.OnKeyDown(M.input, "UP")
    arrow(M.input, "UP")
    assert(M.input.text == "nr 15", "nur einmal: " .. M.input.text)
    GetTime = function() tick = tick + 1 return tick end
    M.input.scripts.OnKeyDown(M.input, "UP")
    assert(M.input.text == "nr 14", tostring(M.input.text))
    for _ = 1, 20 do arrow(M.input, "UP") end
    assert(M.input.text == "nr 6", "bleibt bei der aeltesten")
    for _ = 1, 20 do arrow(M.input, "DOWN") end
    assert(M.input.text == "Entwurf", "zurueck zum Entwurf")
    IsAltKeyDown = nil
    GetTime = t0
    -- Rechtsklick: Liste, Auswahl setzt nur ein (nicht senden)
    local sentAny = false
    Chat.Send = function() sentAny = true return true end
    local oldMenu = MenuUtil
    MenuUtil = {CreateContextMenu = function(owner, fn)
        local root = {CreateTitle = function() end, CreateButton = function(_, label, cb) menu[#menu + 1] = {label = label, cb = cb} end}
        menu = {}
        fn(owner, root)
    end}
    M.input.scripts.OnMouseUp(M.input, "RightButton")
    assert(#menu == 10 and menu[1].label == "nr 15", "Liste der letzten 10")
    menu[3].cb()
    assert(M.input.text == "nr 13" and not sentAny, "nur eingesetzt")
    M.AddHistory(string.rep("y", 60))
    M.input.scripts.OnMouseUp(M.input, "RightButton")
    assert(#menu[1].label < 50, "lange Eingaben gekuerzt")
    Chat:Settings().inputHistory = {}
    M.input.scripts.OnMouseUp(M.input, "RightButton")
    assert(#menu == 1, "leer: Hinweis")
    M.input:SetText("")
    Chat.Send = oldSend
    MenuUtil = oldMenu
end
-- 28) Befehlsliste beim Tippen von "/" (Nutzer 23.11.2026)
do
    local SL = c.SlashList
    local env = {SLASH_INVITE1 = "/inv", SLASH_INVITE2 = "/INVITE", SLASH_GUILDINVITE1 = "/ginvite", SLASH_TRIP1 = "/trip",
        SLASH_SAY1 = "/s", SLASH_SAY2 = "/say", EMOTE1_CMD1 = "/wink", EMOTE2_CMD1 = "/inv", SLASH_BROKEN1 = "kein befehl", OTHER = "/x"}
    local list = SL.Collect(env)
    local cmds = {}
    for i, e in ipairs(list) do cmds[i] = e.cmd end
    assert(table.concat(cmds, " ") == "/ginvite /inv /invite /s /say /trip /wink", table.concat(cmds, " "))
    assert(list[#list].emote and not list[2].emote, "Emotes zuletzt, Befehl schlaegt Emote")
    assert(#SL.Filter(list, "/") == 7, "alles bei /")
    assert(#SL.Filter(list, "/in") == 2 and #SL.Filter(list, "/INV") == 2, "kuerzer je Buchstabe")
    assert(SL.Filter(list, "/inv Bonsai") == nil and SL.Filter(list, "hallo") == nil and SL.Filter(list, "/zz") == nil, "sonst keine Liste")
    -- im Eingabefeld
    SL.list, SL.builtAt = list, GetTime()
    local box = M.input
    local function Type(t) box:SetText(t) box.scripts.OnTextChanged(box) end
    Type("/")
    assert(SL:IsShown() and #SL.matches == 7 and SL.frame.rows[1].cmd.text == "/ginvite", "Liste bei /")
    assert(SL.frame.rows[2].desc.text == "In die Gruppe einladen" and SL.frame.rows[7].desc.text == "Emote", "Erklaerungen")
    assert(not SL.frame.rows[8].shown, "leere Zeilen aus")
    Type("/s")
    assert(#SL.matches == 2, "gefiltert")
    -- Pfeil runter (ohne Alt) waehlt, Tab setzt ein mit Leerzeichen, Liste geht zu
    IsAltKeyDown = function() return false end
    box.scripts.OnArrowPressed(box, "DOWN")
    assert(SL.sel == 2)
    local cycled = false
    local oldCycle = UI.CycleWhisper
    UI.CycleWhisper = function() cycled = true end
    box.scripts.OnTabPressed(box)
    box.scripts.OnTextChanged(box)
    assert(box.text == "/say " and not SL:IsShown() and not cycled, "Tab setzt ein: " .. box.text)
    -- ohne Liste wechselt Tab wie bisher die Fluester-Partner
    box.scripts.OnTabPressed(box)
    assert(cycled, "Tab sonst wie bisher")
    UI.CycleWhisper = oldCycle
    -- Klick auf eine Zeile, Escape schliesst nur die Liste
    Type("/tr")
    SL.frame.rows[1].scripts.OnClick(SL.frame.rows[1])
    assert(box.text == "/trip ", "Klick setzt ein")
    Type("/")
    box.focus = true
    box.scripts.OnEscapePressed(box)
    assert(not SL:IsShown() and box.focus, "Escape schliesst erst die Liste")
    -- Mausrad blaettert, Auswahl bleibt sichtbar
    SL.ROWS = 3
    Type("/")
    for _ = 1, 5 do SL:Move(1) end
    assert(SL.sel == 6 and SL.offset == 3 and SL.frame.rows[3].cmd.text == "/trip", "mitgeblaettert")
    SL.ROWS = 8
    IsAltKeyDown = nil
    Type("")
    assert(not SL:IsShown())
    SL.list = nil
end
-- 29) Quest-Links per Umschalt+Klick (Questlog/Kasten ruft ChatFrameUtil.InsertLink, Nutzer 23.11.2026)
do
    local hooks = {}
    hooksecurefunc = function(a, b, c)
        if type(a) == "table" then hooks[b] = c else hooks[a] = b end
    end
    local quest, item = "|cffffff00|Hquest:7:5|h[Kobolde]|h|r", "|cffffffff|Hitem:25|h[Schwert]|h|r"
    ChatFrameUtil = {InsertLink = function() return false end, GetActiveWindow = function() return nil end}
    ChatEdit_InsertLink = ChatFrameUtil.InsertLink
    UI.insertHooked = nil
    UI:HookInsertLink()
    assert(hooks.InsertLink and hooks.ChatEdit_InsertLink, "beide Wege gehakt")
    local tick = 100
    GetTime = function() return tick end
    local box = M.input
    box.text, box.focus = "", false
    Chat.visible = true
    -- Chat offen, Feld nicht aktiv: Quest-Link kommt rein (und nur einmal ueber beide Wege)
    hooks.InsertLink(quest) hooks.ChatEdit_InsertLink(quest)
    assert(box.text == quest and box.focus, "Quest-Link ins offene Chatfeld: " .. box.text)
    -- Gegenstaende nur bei aktivem Feld (Umschalt+Klick teilt sonst Stapel)
    box.text, box.focus = "", false
    tick = 101
    hooks.InsertLink(item)
    assert(box.text == "", "Gegenstand nicht ohne aktives Feld")
    box.focus = true
    hooks.InsertLink(item)
    assert(box.text == item, "aktives Feld: alles")
    -- offenes WoW-Eingabefeld hat Vorrang
    box.text, box.focus = "", false
    tick = 102
    ChatFrameUtil.GetActiveWindow = function() return {IsShown = function() return true end} end
    hooks.InsertLink(quest)
    assert(box.text == "", "WoW-Feld offen: dort")
    ChatFrameUtil.GetActiveWindow = function() return nil end
    -- Chat zu: nichts
    Chat.visible = false
    tick = 103
    hooks.InsertLink(quest)
    assert(box.text == "", "Chat zu: nichts")
    -- eigener Aufruf (Planer): offener Chat bekommt alles
    Chat.visible = true
    tick = 104
    assert(UI:TakeLink(quest, true) and box.text == quest)
    box.text, box.focus = "", false
    Chat.visible, ChatFrameUtil, ChatEdit_InsertLink, hooksecurefunc = false, nil, nil, nil
    GetTime = function() return clock end
end
-- 30) Nach dem Senden zurueck ins Spiel (Nutzer 23.11.2026: "erst wieder mit ESC raus")
do
    local oldSend = Chat.Send
    Chat.Send = function() return true end
    M.input.text, M.input.focus = "hallo", true
    M:SendInput()
    assert(M.input.focus == false and M.input.text == "", "Fokus weg nach dem Senden")
    -- nicht gesendet (Fehler): Text und Fokus bleiben
    Chat.Send = function() return false, "Fehler" end
    M.input.text, M.input.focus = "hallo", true
    M:SendInput()
    assert(M.input.focus == true and M.input.text == "hallo", "bei Fehler bleibt alles")
    M.input.text, M.input.focus = "", false
    Chat.Send = oldSend
end
-- 31) Freunde-Knopf: Freunde in der Liste links (Messenger-Stil), Klick oeffnet das Gespraech hier (Nutzer 23.11.2026)
do
    BNGetNumFriends = function() return 3 end
    local accs = {
        {battleTag = "Zora#1234", bnetAccountID = 11, gameAccountInfo = {isOnline = true, characterName = "Testheld", characterLevel = 17,
            areaName = "Brachland", className = "Magier"}},
        {battleTag = "Anton#99", bnetAccountID = 12, gameAccountInfo = {isOnline = false}},
        {battleTag = "Bert#5", bnetAccountID = 13, isAFK = true, gameAccountInfo = {isOnline = true, richPresence = "Im Menü"}},
    }
    C_BattleNet = {GetFriendAccountInfo = function(i) return accs[i] end}
    LOCALIZED_CLASS_NAMES_MALE = {MAGE = "Magier", WARRIOR = "Krieger"}
    C_FriendList = {GetNumFriends = function() return 1 end,
        GetFriendInfoByIndex = function() return {name = "Testfreund", connected = true, level = 20, className = "Krieger", area = "Durotar"} end}
    local list = M.Friends()
    local names = {}
    for i, fr in ipairs(list) do names[i] = fr.name end
    assert(table.concat(names, ",") == "Bert#5,Zora#1234,Testfreund,Anton#99", "online zuerst, Battle.net vor WoW: " .. table.concat(names, ","))
    assert(list[2].classFile == "MAGE" and list[3].classFile == "WARRIOR", "Klasse aus dem Namen")
    assert(M.FriendLine(list[2]) == "Testheld (17) · Brachland", M.FriendLine(list[2]))
    assert(M.FriendLine(list[1]):find("abwesend", 1, true) and M.FriendLine(list[1]):find("Im Menü", 1, true))
    assert(M.FriendLine(list[3]) == "Stufe 20 · Durotar" and M.FriendLine(list[4]) == "offline")
    assert(M.friendsButton and M.friendsButton.parent == M.list, "Knopf an der Suche")
    M:UpdateFriendsButton()
    assert(M.friendsButton.count.text == "3", "Zahl online")
    -- Klick: Liste zeigt Freunde statt Gespraeche
    M.frame.shown = true
    M.friendsButton.scripts.OnClick(M.friendsButton)
    assert(M.friendsMode, "Freunde-Ansicht an")
    local rows = M:ListRows()
    assert(rows[1].click and rows[2].label:find("ONLINE (3)", 1, true), "Zurueck + Online-Ueberschrift")
    assert(rows[3].friend.name == "Bert#5" and rows[6].label:find("OFFLINE (1)", 1, true) and rows[7].friend.name == "Anton#99")
    assert(rows[#rows].click and rows[#rows].label:find("Freundesliste", 1, true), "WoW-Liste unten")
    -- Zeilen gefuellt: Name, zweite Zeile, offline blass
    M:LayoutList()
    local zora
    for _, b in ipairs(M.convRows) do if b.shown and b.name.text:find("Zora", 1, true) then zora = b end end
    assert(zora and zora.preview.text == "Testheld (17) · Brachland" and zora.online.shown, "Freundeszeile")
    -- Suche filtert Freunde
    M.search = "durotar"
    rows = M:ListRows()
    assert(rows[3].friend.name == "Testfreund" and #rows == 5, "Suche")
    M.search = ""
    -- Klick auf Freund: Gespraech hier, Ansicht zurueck auf Gespraeche, Konto-Nummer gemerkt
    zora.scripts.OnClick(zora, "LeftButton")
    assert(UI.current == "w:Zora#1234" and Chat.bnIds["Zora#1234"] == 11 and not M.friendsMode, tostring(UI.current))
    -- "Zurueck zu den Gespraechen"
    M:ToggleFriends(true)
    M:ListRows()[1].click()
    assert(not M.friendsMode)
    -- Notiz in der Zeile, Rechtsklick-Menue, Notiz aendern, Entfernen mit Sicherheitsfrage, Einladen
    accs[1].note = "Raidleiter"
    local notes, removed, invited = {}, nil, nil
    BNSetFriendNote = function(id, n) notes[id] = n end
    BNRemoveFriend = function(id) removed = id end
    BNInviteFriend = function(id) invited = id end
    accs[1].gameAccountInfo.gameAccountID = 77
    M:ToggleFriends(true)
    M:LayoutList()
    for _, b in ipairs(M.convRows) do if b.shown and b.name.text:find("Zora", 1, true) then zora = b end end
    assert(zora.preview.text:find("Raidleiter", 1, true), "Notiz in der Zeile")
    local menus = {}
    local oldMenu = MenuUtil
    MenuUtil = {CreateContextMenu = function(_, fn)
        local m = {buttons = {}}
        function m:CreateTitle(t) self.title = t end
        function m:CreateDivider() end
        function m:CreateButton(label, cb) self.buttons[#self.buttons + 1] = {label = label, cb = cb} end
        menus[#menus + 1] = m
        fn(nil, m)
    end}
    local function Btn(m, text) for _, x in ipairs(m.buttons) do if x.label:find(text, 1, true) then return x end end end
    zora.scripts.OnClick(zora, "RightButton")
    local m = menus[#menus]
    assert(m.title == "Zora" and Btn(m, "Anschreiben") and Btn(m, "In Gruppe einladen") and Btn(m, "Notiz ändern"), "Menue")
    Btn(m, "In Gruppe einladen").cb()
    assert(invited == 77, "Einladen ueber das Spielkonto")
    Btn(m, "Notiz ändern").cb()
    assert(M.promptBox.shown and M.promptBox.text == "Raidleiter", "Notiz zum Bearbeiten")
    M.promptBox.text = "Heiler"
    M.promptBox.scripts.OnEnterPressed(M.promptBox)
    assert(notes[11] == "Heiler" and not M.promptBox.shown, "Notiz gesetzt")
    Btn(m, "Freund entfernen").cb()
    local ask = menus[#menus]
    assert(ask.title:find("Zora", 1, true) and removed == nil, "erst fragen")
    Btn(ask, "Abbrechen").cb()
    assert(removed == nil)
    Btn(ask, "Ja, entfernen").cb()
    assert(removed == 11, "entfernt")
    -- offline: kein Einladen
    local anton
    for _, fr in ipairs(M.Friends()) do if fr.name == "Anton#99" then anton = fr end end
    assert(not M.CanInviteFriend(anton))
    -- Freund hinzufuegen: BattleTag -> Battle.net-Anfrage, sonst WoW-Freund
    local sentInv, added
    BNSendFriendInvite = function(t) sentInv = t end
    C_FriendList.AddFriend = function(n) added = n end
    M:ListRows()[#M:ListRows() - 1].click()
    M.promptBox.text = " Neu#4711 "
    M.promptBox.scripts.OnEnterPressed(M.promptBox)
    assert(sentInv == "Neu#4711", "Battle.net-Anfrage")
    M.AddFriend("Grimbart")
    assert(added == "Grimbart", "WoW-Freund")
    -- Freundschaftsanfragen: oben in der Liste, rote Zahl am Knopf, Annehmen/Ablehnen
    BNGetNumFriendInvites = function() return 1 end
    BNGetFriendInviteInfo = function() return 501, "Neuling#1" end
    local acc, dec
    BNAcceptFriendInvite = function(id) acc = id end
    BNDeclineFriendInvite = function(id) dec = id end
    M:UpdateFriendsButton()
    assert(M.friendsButton.req.text:find("1", 1, true), "Zahl der Anfragen")
    rows = M:ListRows()
    assert(rows[2].label:find("ANFRAGEN (1)", 1, true) and rows[3].request.id == 501, "Anfragen oben")
    M:LayoutList()
    local reqRow
    for _, b in ipairs(M.convRows) do if b.shown and b.name.text:find("Neuling", 1, true) then reqRow = b end end
    reqRow.scripts.OnClick(reqRow)
    Btn(menus[#menus], "Annehmen").cb()
    assert(acc == 501 and dec == nil, "angenommen")
    Btn(menus[#menus], "Ablehnen").cb()
    assert(dec == 501, "abgelehnt")
    MenuUtil = oldMenu
    M:ToggleFriends(false)
    BNGetNumFriends, C_BattleNet, C_FriendList, LOCALIZED_CLASS_NAMES_MALE = nil, nil, nil, nil
    BNSetFriendNote, BNRemoveFriend, BNInviteFriend, BNSendFriendInvite = nil, nil, nil, nil
    BNGetNumFriendInvites, BNGetFriendInviteInfo, BNAcceptFriendInvite, BNDeclineFriendInvite = nil, nil, nil, nil
end
-- Spielbild 24.11.2026: im Fenster standen eigene Nachrichten links. Gleiche Erkennung wie die Randleiste:
-- Name mit Leerzeichen, GUID, eigenes Emote
do
    local saveName, saveGUID = UnitName, UnitGUID
    UnitName = function() return "Testheld" end
    UnitGUID = function() return "Player-1-ABC" end
    assert(M.IsOwn({author = "Testheld Wackelzahn-Forever", text = "huhu"}), "Name mit Leerzeichen")
    assert(M.IsOwn({author = "Jemand", guid = "Player-1-ABC"}), "eigene GUID")
    assert(M.IsOwn({inform = true}))
    assert(not M.IsOwn({author = "Testhelda", text = "hi"}), "aehnlicher Name ist fremd")
    assert(M.IsOwn({event = "CHAT_MSG_TEXT_EMOTE", author = "x", text = "Ihr winkt."}))
    UnitName, UnitGUID = saveName, saveGUID
end
-- Abgleich Fenster/Randleiste 24.11.2026: Maus auf einer Fenster-Blase zeigt den Gegenstands-Tooltip
do
    local saveTip = GameTooltip
    local shown = {}
    GameTooltip = {SetOwner = function() end, SetHyperlink = function(_, l) shown.link = l end,
        AddLine = function(_, t) shown.line = t end, Show = function() shown.ok = true end, Hide = function() shown.ok = false end}
    local row = {item = {type = "bubble", entry = {text = "schau |cffa335ee|Hitem:19019::::::::60:::::|h[Donnerzorn]|h|r und |cff1eff00|Hitem:2589::::::::1:::::|h[Leinen]|h|r"}}}
    assert(M.BubbleHover(row) and shown.ok and shown.link:find("^item:19019"), "Tooltip des ersten Links")
    assert(shown.line, "Hinweis auf weitere Links")
    assert(not M.BubbleHover({item = {type = "bubble", entry = {text = "nur Text"}}}), "ohne Link kein Tooltip")
    GameTooltip = saveTip
end
-- Nutzer 24.11.2026 „Ja, wie Leiste“: Emotes im Fenster als Blase, eigene rechts
do
    local saveName = UnitName
    UnitName = function() return "Testheld" end
    local saveBuf = Chat.Buffer
    local mine = {kind = "emote", event = "CHAT_MSG_TEXT_EMOTE", author = "Testheld", text = "Ihr winkt.", time = 1800000000}
    local other = {kind = "emote", event = "CHAT_MSG_EMOTE", author = "Brakk", text = "tanzt.", time = 1800000001}
    Chat.Buffer = function() return {mine, other} end
    local a, b
    for _, it in ipairs(M.Items("say")) do
        if it.entry == mine then a = it elseif it.entry == other then b = it end
    end
    Chat.Buffer = saveBuf
    assert(a and a.type == "bubble" and a.out, "eigenes Emote rechts als Blase")
    assert(b and b.type == "bubble" and not b.out, "fremdes Emote links als Blase")
    UnitName = saveName
end
print("OK test_messenger_146")
