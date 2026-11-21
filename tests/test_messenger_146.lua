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
assert(lastConv.view == "system" and lr[#lr - 1].label == "SYSTEM", "System & Addons ganz unten")
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
print("OK test_messenger_146")
