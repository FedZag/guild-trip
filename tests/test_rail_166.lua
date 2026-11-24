-- Offline-Test: Randleiste statt Fenster (Nutzerwunsch 23.11.2026): Symbole, Aufklappen (Maus / Klick / von selbst zu),
-- schwebende Blasen nur fuer das aktive Gespraech (+ Fluestern), Enter = nur Eingabezeile mit Emojis, Transparenz bis 0 %.
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
    function r:SetParent(p) self.parent = p end
    function r:SetAlpha(a) self.alpha = a end
    function r:IsMouseOver() return self.mouse == true end
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
for _, f in ipairs({"Chat", "Emoji", "ChatUI", "Messenger", "SlashList", "Rail", "TabEditor", "Settings", "Launcher"}) do
    assert(loadfile(root .. "/ONE_Chat/" .. f .. ".lua"))("ONE_Chat", c)
end
local Chat, UI, M, Emoji = c.Chat, c.UI, c.Messenger, c.Emoji
assert(Chat:Settings().style == "messenger", "Messenger ist Standard")
M:Install()
Chat.listeners[#Chat.listeners + 1] = function(entry, views, update) UI:OnMessage(entry, views, update) end
local R = c.Rail
assert(R, "Rail geladen")
local function Guild(text, who)
    clock = clock + 1
    Chat:OnEvent("CHAT_MSG_GUILD", text, (who or "Thorgrim") .. "-Forever", "", "", "", "", 0, 0, "", 0, clock, "")
end

-- 1) Standard aus: keine Leiste, Enter oeffnet wie bisher das Fenster
assert(not R.Active(), "Randleiste ist Standard aus")
R:Apply()
assert(not R.frame, "ohne Schalter nichts gebaut")
UI:OpenInput()
assert(M.frame.shown and M.input.focus, "ohne Randleiste: Fenster + Fokus")
M:Hide()
M.input:ClearFocus()

-- 2) Einschalten: Leiste mit Symbolen, leere Gruppen fallen weg
Chat:Settings().rail = true
assert(R.Active())
-- Spieltest 23.11.2026: nach dem Einloggen war nie ein Fenster offen -> kein aktives Gespraech, keine Blasen
UI.current = nil
R:Apply()
assert(R.frame and R.frame.shown, "Leiste sichtbar")
assert(UI.current == "guild" and R.ActiveView() == "guild", "aktiv ohne Fenster: Gilde")
Guild("Abend zusammen!")
assert(#R.bubbles == 1, "Blase kommt von selbst, ohne dass das Fenster je offen war")
R:Update()
local shownIcons = 0
for _, b in ipairs(R.icons) do if b.shown then shownIcons = shownIcons + 1 end end
assert(shownIcons == #M.Conversations(), "ein Symbol je Gespraech: " .. shownIcons)
local groups = R.Groups()
assert(#groups.pinned >= 1 and groups.pinned[1].view == "guild", "Gilde angeheftet")

-- 3) Blasen: nur aktives Gespraech, Fluestern immer (abschaltbar), hoechstens 4, verblassen
R:ClearBubbles()
Guild("Wer kommt mit BRD?")
assert(#R.bubbles == 1 and R.bubbles[1].view == "guild", "Gildenblase")
assert(R.bubbles[1].name.text == "Thorgrim", "Name in der Blase: " .. R.bubbles[1].name.text)
assert(R.bubbles[1].text.text:find("BRD", 1, true), "Text in der Blase")
-- Sprechblase wie im Fenster: durchscheinend, Zipfel zur Leiste (Spieltest 23.11.2026)
local bb = R.bubbles[1]
assert(bb.bg and bb.edge and bb.tail and bb.tail.shown ~= false, "Glas-Blase mit Zipfel")
assert(bb.alphaFill and bb.alphaFill < .6, "durchscheinend: " .. tostring(bb.alphaFill))
assert(not bb.bg.pieces[1].shown, "Zipfel statt runder Ecke oben links")
clock = clock + 1
Chat:OnEvent("CHAT_MSG_SAY", "Hallo Leute", "Fremder-Forever", "", "", "", "", 0, 0, "", 0, clock, "")
assert(#R.bubbles == 1, "Sagen ist nicht aktiv: keine Blase")
clock = clock + 1
Chat:OnEvent("CHAT_MSG_WHISPER", "psst", "Brakk-Forever", "", "", "", "", 0, 0, "", 0, clock, "")
assert(#R.bubbles == 2 and R.bubbles[2].view:sub(1, 2) == "w:", "Fluestern als Blase")
assert(R.bubbles[2].name.text:find("Brakk", 1, true), "Fluesterer genannt")
Chat:Settings().railWhisper = false
clock = clock + 1
Chat:OnEvent("CHAT_MSG_WHISPER", "noch was", "Mira-Forever", "", "", "", "", 0, 0, "", 0, clock, "")
assert(#R.bubbles == 2, "Fluester-Blasen abschaltbar")
Chat:Settings().railWhisper = nil
for i = 1, 5 do Guild("Zeile " .. i) end
assert(#R.bubbles == R.BUBBLE_MAX, "hoechstens " .. R.BUBBLE_MAX .. " Blasen")
assert(R.bubbles[#R.bubbles].text.text:find("Zeile 5", 1, true), "neueste zuletzt")
-- unten die neueste, darueber die aelteren; oben blasser
local low, high = R.bubbles[#R.bubbles], R.bubbles[1]
assert((low.rise or 0) < (high.rise or 0), "aeltere weiter oben")
assert(R.RiseAlpha(low.rise, low:GetHeight()) > R.RiseAlpha(high.rise, high:GetHeight()), "oben blasser")
for i = 2, #R.bubbles do
    local a, b = R.bubbles[i], R.bubbles[i - 1]
    assert(b.rise >= a.rise + a:GetHeight(), "Blasen ueberlappen nicht")
end
-- steigen mit der Zeit
local r0 = low.rise
R:Tick(.25)
assert(low.rise > r0, "Blase steigt")
-- Maus drueber: alle halten an
low.mouse = true
local r1 = low.rise
R:Tick(.25)
assert(low.rise == r1, "Maus haelt an")
low.mouse = false
-- nach "Blasen sichtbar" Sekunden sind alle oben verschwunden
for _ = 1, math.ceil(R.BubbleTime() / .1) + 10 do R:Tick(.1) end
assert(#R.bubbles == 0, "alle oben verblasst")
-- stummes aktives Gespraech: keine Blase
M.SetMuted("guild", true)
Guild("leise")
assert(#R.bubbles == 0, "stumm = keine Blase")
M.SetMuted("guild", false)

-- 3a) Spieltest 23.11.2026: Abstand zur Leiste, langsamer blasser, Klick zeigt die letzten wieder
local hp = R.host.points[1]
assert(hp[4] >= 24, "Blasen mit Abstand zur Leiste")
assert(R.RiseAlpha(0, 40) == 1 and R.RiseAlpha(R.RISE_H * .5 - 41, 40) == 1, "untere Haelfte voll sichtbar")
assert(R.RiseAlpha(R.RISE_H * .75 - 40, 40) > .4, "erst oben blasser")
assert(R.BubbleTime() == 20, "Standard 20 Sekunden")
for i = 1, 6 do Guild("Verlauf " .. i) end
R:ClearBubbles()
local gIcon
R:Update()
for _, b in ipairs(R.icons) do if b.shown and b.conv and b.conv.view == "guild" then gIcon = b end end
-- Nutzer 23.11.2026: Klick = nur aktiv (keine Blasen), Doppelklick = oeffnen
R:SetActive("say")
gIcon.scripts.OnClick(gIcon, "LeftButton")
assert(R.ActiveView() == "guild" and not R.openView and #R.bubbles == 0, "Klick: nur aktiv")
gIcon.scripts.OnDoubleClick(gIcon, "LeftButton")
assert(#R.bubbles == R.REPLAY and R.openView == "guild" and R.bubbles[1].static, "Klick: letzte " .. R.REPLAY .. " Nachrichten stehen da")
assert(R.bubbles[#R.bubbles].text.text:find("Verlauf 6", 1, true) and R.bubbles[#R.bubbles - 5].text.text:find("Verlauf 1", 1, true), "in Reihenfolge, neueste unten")
assert((Chat.unread.guild or 0) == 0, "gilt als gelesen")
R:CloseTab()
R:ClearBubbles()

-- 3b) Ziehen verschiebt die Leiste (auch an einem Symbol); Loslassen ist kein Klick
R.icons[1].scripts.OnDragStart()
assert(R.dragging, "Ziehen am Symbol")
R.icons[1].scripts.OnDragStop()
R.icons[1].scripts.OnClick(R.icons[1], "LeftButton")
assert(not R.docked, "Loslassen nach Ziehen ist kein Klick")
clock = clock + 1

-- 4) Jedes Gespraech ein Symbol, Gruppen mit Abstand + Linie; Klick = aktiv, nochmal = schreiben, Rechtsklick = Menue
Chat:OpenWhisper("Brakk")
R:Update()
local convs = M.Conversations()
local shown = {}
for _, b in ipairs(R.icons) do if b.shown then shown[#shown + 1] = b end end
assert(#shown == #convs, "ein Symbol je Gespraech: " .. #shown .. " / " .. #convs)
assert(shown[1].conv.view == "guild", "Angeheftet zuerst")
local lines = 0
for _, t in ipairs(R.lines) do if t.shown then lines = lines + 1 end end
local used = 0
for _, g in pairs(R.Groups()) do if #g > 0 then used = used + 1 end end
assert(lines == used, "Linie zwischen den Gruppen und vor dem Fenster-Knopf: " .. lines .. " / " .. used)
-- Abstand: zwischen Gruppen groesser als zwischen zwei Symbolen derselben Gruppe
local function Y(b) return -b.points[#b.points][5] end
local gapSame, gapGroup
for k = 2, #shown do
    local d = Y(shown[k]) - Y(shown[k - 1])
    if R.GroupOf(shown[k].conv) == R.GroupOf(shown[k - 1].conv) then gapSame = d else gapGroup = d end
end
assert(gapSame and gapGroup and gapGroup > gapSame, "Abstand zwischen den Gruppen")
assert(shown[1].sel.shown, "aktives Gespraech leuchtet")
-- Nutzer 24.11.2026: statt Ring Leuchtstrich aussen, aktiv groesser, andere leicht abgedunkelt
local act = shown[1]
assert(act.sel.w == R.MARK_W and act.sel.h == R.MARK_LEN and act.sel.points[1][1] == "RIGHT", "Strich links aussen")
assert(act.w == R.ICON + 4 and act.alpha == 1, "aktiv groesser, voll")
local other
for _, b in ipairs(shown) do if b ~= act and not b.sel.shown and (b.conv.unread or 0) == 0 and not b.conv.muted then other = b end end
if other then assert(other.w == R.ICON and other.alpha == R.DIM, "andere normal gross, abgedunkelt") end
-- Klick auf Fluestern: wird aktiv (Blasen von dort), Fenster bleibt zu
local brakk
for _, b in ipairs(shown) do if b.conv.view == "w:Brakk" then brakk = b end end
brakk.scripts.OnClick(brakk, "LeftButton")
assert(UI.current == "w:Brakk" and R.ActiveView() == "w:Brakk" and not M.frame.shown, "Klick macht aktiv")
brakk.scripts.OnDoubleClick(brakk, "LeftButton")
assert(R.openView == "w:Brakk", "Doppelklick oeffnet")
R:ClearBubbles()
Guild("Gilde, jetzt nicht aktiv")
assert(#R.bubbles == 0, "Gilde nicht mehr aktiv: keine Blase")
-- geoeffneter Reiter: neue Nachricht bleibt stehen (wandert nicht, verblasst nicht), gilt als gelesen
clock = clock + 1
Chat:OnEvent("CHAT_MSG_WHISPER", "bleib stehen", "Brakk-Forever", "", "", "", "", 0, 0, "", 0, clock, "")
local st = R.bubbles[#R.bubbles]
assert(st.static and st.text.text:find("bleib stehen", 1, true), "Blase des offenen Reiters steht")
for _ = 1, 400 do R:Tick(.1) end
assert(st.shown and st.rise == 0 and st.alpha == 1, "steht still und bleibt voll sichtbar")
assert((Chat.unread["w:Brakk"] or 0) == 0, "offen = gelesen")
-- eigene rechts ohne Namen, empfangene links (Nutzer 23.11.2026)
clock = clock + 1
Chat:OnEvent("CHAT_MSG_WHISPER_INFORM", "mach ich", "Brakk-Forever", "", "", "", "", 0, 0, "", 0, clock, "")
local own = R.bubbles[#R.bubbles]
assert(own.static and own.out and own.points[#own.points][1] == "BOTTOMRIGHT", "eigene rechts")
assert(not own.name.shown, "eigene im offenen Reiter ohne Namenszeile")
assert(own.bg.pieces[1].shown ~= false and own.bg.pieces[3].shown == false, "Zipfel rechts")
assert(st.points[#st.points][1] == "BOTTOMLEFT" and st.name.shown, "empfangene links mit Namen")
-- Drueberfahren zeigt den Gegenstand (Nutzer 23.11.2026), Mausrad blaettert bei mehreren
local shownLink, lines = nil, {}
GameTooltip = {SetOwner = function() end, SetHyperlink = function(_, l) shownLink = l end, SetText = function(_, t) lines[#lines + 1] = t end,
    AddLine = function(_, t) lines[#lines + 1] = t end, Show = function() end, Hide = function() end}
local gear = "|cff1eff00|Hitem:15284::::::::|h[Stachelige Keule der Eule]|h|r und |cff0070dd|Hitem:6448::::::::|h[Schwanzspitze]|h|r, |Hplayer:Brakk|h[Brakk]|h"
local ib = R:AddBubble({kind = "whisper", author = "Brakk", text = gear, time = clock}, "w:Brakk", true)
assert(#ib.links == 2, "zwei Gegenstaende, Spieler-Link zaehlt nicht")
ib.scripts.OnEnter(ib)
assert(shownLink == "item:15284::::::::", "Tooltip des ersten Gegenstands: " .. tostring(shownLink))
ib.scripts.OnMouseWheel(ib, -1)
assert(shownLink == "item:6448::::::::", "Mausrad: naechster")
ib.scripts.OnMouseWheel(ib, -1)
assert(shownLink == "item:15284::::::::", "rundherum")
shownLink = nil
local nb = R:AddBubble({kind = "guild", author = "Thorgrim", text = "ohne Link", time = clock}, "guild", false)
nb.scripts.OnEnter(nb)
assert(not shownLink, "ohne Link: nur der Hinweis")
-- Alt+Klick auf eine Blase: Absender einladen (sicherer Knopf), Fenster geht nicht auf
local asked
local oldAlt = UI.AltInvite
UI.AltInvite = function(_, n) asked = n return true end
nb.scripts.OnClick(nb, "LeftButton")
assert(asked == "Thorgrim" and not M.frame.shown, "Alt+Klick: Einladen statt Fenster")
UI.AltInvite = oldAlt
R:DropBubble(ib) R:DropBubble(nb)
GameTooltip = nil
-- eigene Emotes rechts (auch automatische), fremde links
assert(R.IsOwn({kind = "emote", event = "CHAT_MSG_TEXT_EMOTE", author = "Testheld Wackelzahn", text = "Ihr winkt Testfreund Rabe zu."}), "eigenes Emote")
assert(not R.IsOwn({kind = "emote", event = "CHAT_MSG_TEXT_EMOTE", author = "Brakk", text = "Brakk winkt Euch zu."}), "fremdes Emote")
local eb = R:AddBubble({kind = "emote", event = "CHAT_MSG_TEXT_EMOTE", author = "Testheld", text = "Ihr winkt Testfreund Rabe zu.", time = clock}, "all", true)
assert(eb.out and eb.points[#eb.points][1] == "BOTTOMRIGHT", "eigenes Emote rechts")
assert(eb.time.text == os.date("%H:%M", clock), "Uhrzeit in der Blase: " .. eb.time.text)
assert(R.TimeText(clock - 3 * 86400):find("%d%d%.%d%d%. %d%d:%d%d"), "aeltere mit Datum")
R:DropBubble(eb)
-- Meldungen ohne Absender: Art statt Reitername (Spielbild "[System] Alle")
local hn = R.BubbleHead({kind = "system", text = "Ihr werdet nicht mehr mit 'AFK' angezeigt."}, "all")
assert(hn ~= "Alle" and not hn:find("Alle", 1, true) and hn:find("System", 1, true), "System-Meldung: " .. hn)
-- lange Nachricht: im offenen Reiter ganz, aufsteigend gekuerzt
local long = string.rep("Vermisst du das alte WoW? ", 20)
local lb = R:AddBubble({kind = "whisper", author = "Brakk", text = long, time = clock}, "w:Brakk", true)
local lf = R:AddBubble({kind = "guild", author = "Thorgrim", text = long, time = clock}, "guild", false)
assert(lb:GetHeight() > lf:GetHeight(), "offener Reiter zeigt mehr Zeilen")
R:DropBubble(lb) R:DropBubble(lf)
-- andere Gespraeche steigen darueber auf und verblassen (Fluestern von jemand anderem)
clock = clock + 1
Chat:OnEvent("CHAT_MSG_WHISPER", "hallo", "Mira-Forever", "", "", "", "", 0, 0, "", 0, clock, "")
local fl = R.bubbles[#R.bubbles]
assert(not fl.static, "anderes Gespraech: steigt")
local function Bottom(b) return b.points[#b.points][5] end
assert(Bottom(fl) > Bottom(st), "steigende ueber den stehenden")
-- fliessend: Teilschritte, kein Runden auf ganze Pixel (Spieltest "sehr ruckelig")
R:Tick(1 / 60)
assert(Bottom(fl) ~= math.floor(Bottom(fl)), "Position ohne Runden")
for _ = 1, 400 do R:Tick(.1) end
assert(not fl.shown and st.shown, "steigende weg, stehende bleibt")
-- Klick irgendwo ins Spiel schliesst den Reiter, Klick auf Leiste/Blase nicht
R.frame.mouse = true
R.ticker.scripts.OnEvent(R.ticker, "GLOBAL_MOUSE_DOWN", "LeftButton")
assert(R.openView == "w:Brakk", "Klick auf die Leiste: bleibt offen")
R.frame.mouse = false
st.mouse = true
R.ticker.scripts.OnEvent(R.ticker, "GLOBAL_MOUSE_DOWN", "LeftButton")
assert(R.openView == "w:Brakk", "Klick auf eine Blase: bleibt offen")
st.mouse = false
R.ticker.scripts.OnEvent(R.ticker, "GLOBAL_MOUSE_DOWN", "LeftButton")
assert(not R.openView and not st.shown, "Klick ins Spiel: Reiter zu")
-- wieder oeffnen fuer die naechste Pruefung
for _, b in ipairs(R.icons) do if b.shown and b.conv and b.conv.view == "w:Brakk" then brakk = b end end
brakk.scripts.OnDoubleClick(brakk, "LeftButton")
assert(R.openView == "w:Brakk", "wieder offen")
-- nochmal Klick auf den offenen Reiter: schliesst ihn
for _, b in ipairs(R.icons) do if b.shown and b.conv and b.conv.view == "w:Brakk" then brakk = b end end
brakk.scripts.OnClick(brakk, "LeftButton")
assert(not R.openView and #R.bubbles == 0, "zweiter Klick schliesst den Reiter")
-- Verweilen ueber einem Symbol: Vorschau der letzten Nachrichten, solange die Maus bleibt (Nutzer 23.11.2026)
local gv
for _, b in ipairs(R.icons) do if b.shown and b.conv and b.conv.view == "guild" then gv = b end end
gv.mouse = true
gv.scripts.OnEnter(gv)
assert(R.previewView == "guild" and #R.bubbles > 0 and R.bubbles[1].static, "Vorschau sofort beim Drueberfahren")
assert(not R.openView, "Vorschau oeffnet den Reiter nicht")
-- Maus auf eine Vorschau-Blase: bleibt
gv.mouse = false
R.bubbles[#R.bubbles].mouse = true
clock = clock + 1
R:Tick(.016)
assert(R.previewView == "guild", "Maus auf den Blasen: bleibt")
R.bubbles[#R.bubbles].mouse = false
R:Tick(.016)
clock = clock + R.PREVIEW_LEAVE + .05
R:Tick(.016)
assert(not R.previewView and #R.bubbles == 0, "Maus weg: Vorschau weg")
-- offener Reiter kommt nach der Vorschau zurueck
brakk.scripts.OnDoubleClick(brakk, "LeftButton")
local openCount = #R.bubbles
gv.mouse = true
gv.scripts.OnEnter(gv)
clock = clock + R.PREVIEW_DELAY + .05
R:Tick(.016)
assert(R.previewView == "guild" and R.bubbles[1].view == "guild", "Vorschau ersetzt kurz den offenen Reiter")
gv.mouse = false
R:Tick(.016)
clock = clock + R.PREVIEW_LEAVE + .05
R:Tick(.016)
assert(R.openView == "w:Brakk" and #R.bubbles == openCount and R.bubbles[1].view == "w:Brakk", "danach wieder der offene Reiter")
R:CloseTab()
-- Rechtsklick: Menue mit Fenster oeffnen
brakk.scripts.OnClick(brakk, "RightButton")
local openItem
for _, it in ipairs(menu) do if it.label == "Im Fenster öffnen" then openItem = it end end
assert(openItem, "Menue: Im Fenster oeffnen")
openItem.cb()
assert(M.frame.shown and UI.current == "w:Brakk", "Fenster mit dem Gespraech")
M:Hide()
-- zurueck zur Gilde fuer die naechsten Pruefungen
R:SetActive("guild")
-- Online-Punkt an Fluester-Symbolen (Spieltest 23.11.2026)
local savedInfo = M.PersonInfo
M.PersonInfo = function(name) if name == "Brakk" then return {online = true} end end
R:Update()
for _, b in ipairs(R.icons) do
    if b.shown and b.conv and b.conv.view == "w:Brakk" then assert(b.online.shown and b.onlineRim.shown, "Brakk online: gruener Punkt") end
    if b.shown and b.conv and b.conv.view == "guild" then assert(not b.online.shown, "Gilde ohne Punkt") end
end
M.PersonInfo = savedInfo
-- Wappen beim Drueberfahren ueber ein Fluester-Symbol (nur wenn man einladen darf, nicht fuer Mitglieder)
local oldCan, oldRoster = M.CanInvite, M.RosterInfo
M.CanInvite = function() return true end
M.RosterInfo = function(n) if n == "Mira" then return {inGuild = true} end end
local bIcon
for _, b in ipairs(R.icons) do if b.shown and b.conv and b.conv.view == "w:Brakk" then bIcon = b end end
bIcon.scripts.OnEnter(bIcon)
assert(R.crest and R.crest.shown and R.crest.target == "Brakk", "Wappen neben Brakk")
assert(R.crest.points[#R.crest.points][2] == bIcon, "am Symbol")
bIcon.mouse = true
R:Tick(.016)
assert(R.crest.shown, "Maus auf dem Symbol: bleibt")
bIcon.mouse = false
R:Tick(.016)
assert(R.crest.shown, "Weg zum Wappen (Luecke): bleibt kurz stehen")
R.crest.mouse = true
clock = clock + 2
R:Tick(.016)
assert(R.crest.shown, "Maus auf dem Wappen: bleibt")
R.crest.mouse = false
R:Tick(.016)
clock = clock + 1
R:Tick(.016)
assert(not R.crest.shown, "Maus weg: Wappen nach kurzer Frist weg")
local gI
for _, b in ipairs(R.icons) do if b.shown and b.conv and b.conv.view == "guild" then gI = b end end
gI.scripts.OnEnter(gI)
assert(not R.crest.shown, "kein Wappen bei der Gilde")
M.CanInvite = function() return false end
bIcon.scripts.OnEnter(bIcon)
assert(not R.crest.shown, "ohne Rechte kein Wappen")
M.CanInvite, M.RosterInfo = oldCan, oldRoster
-- Freunde vorletztes Symbol, Klick: Fenster mit Freundesliste
assert(R.friendsButton.shown, "Freunde-Symbol")
local fy, wy = -R.friendsButton.points[#R.friendsButton.points][5], -R.windowButton.points[#R.windowButton.points][5]
assert(fy < wy, "Freunde vor dem Fenster-Knopf")
R.friendsButton.scripts.OnClick(R.friendsButton, "LeftButton")
assert(M.frame.shown and M.friendsMode, "Freundesliste im Fenster")
M:ToggleFriends(false)
M:Hide()
-- Fenster-Knopf
R.windowButton.scripts.OnClick(R.windowButton, "LeftButton")
assert(M.frame.shown, "Fenster-Knopf")
M:Hide()

-- 5) Enter: nur die Eingabezeile (mit Emoji-Knopf), Senden, Esc, Tab wechselt das Ziel
UI:OpenInput()
assert(R.docked and R.quick.shown and not M.frame.shown, "nur Eingabezeile, kein Fenster")
assert(#R.quick.border == 4 and not R.quickSurface, "Eingabezeile ohne Hintergrund, nur Rand")
assert(M.foot.parent == R.quick, "Zeile mit Emoji-Knopf und Feld in der Randleiste")
assert(M.input.focus, "Fokus im Feld")
assert(R.quick.to.text.text:find("Gilde", 1, true), "Ziel sichtbar: " .. R.quick.to.text.text)
M:TogglePicker()
assert(M.picker.shown and M.picker.parent == R.quick, "Emojis ueber der Eingabezeile")
M:InsertCode(":daumen:")
assert(M.input.text:find(":daumen:", 1, true), "Emoji eingefuegt")
M.picker:Hide()
for k in pairs(sent) do sent[k] = nil end
M.input:SetText("Hallo Gilde")
M.input.scripts.OnEnterPressed(M.input)
assert(sent[#sent] and sent[#sent][1] == "Hallo Gilde" and sent[#sent][2] == "GUILD", "gesendet an die Gilde")
M.input.scripts.OnEditFocusLost(M.input)
assert(not R.docked and not R.quick.shown and M.foot.parent == M.main, "nach dem Senden zu, Zeile zurueck im Fenster")
-- Tab: naechstes Ziel, ohne das Fenster zu oeffnen
UI:OpenInput()
local before = UI.current
M.input.scripts.OnTabPressed(M.input)
assert(UI.current ~= before and not M.frame.shown and R.docked, "Tab wechselt das Ziel: " .. tostring(UI.current))
-- Esc: zu
M.input.scripts.OnEscapePressed(M.input)
M.input.scripts.OnEditFocusLost(M.input)
assert(not R.docked and not R.quick.shown, "Esc schliesst die Zeile")
-- Fluestern aus dem Namens-Menue / Antworten: Zeile mit Ziel
UI:OpenInput(Chat:OpenWhisper("Brakk"))
assert(R.docked and UI.current == "w:Brakk" and R.quick.to.text.text:find("Brakk", 1, true), "Fluestern-Ziel")
-- ohne Fokus und ohne Maus schliesst sie nach ein paar Sekunden
M.input.focus = false
R:Tick(.1)
clock = clock + R.INPUT_CLOSE + 1
R:Tick(.1)
assert(not R.docked, "Zeile schliesst sich von selbst")
-- Fenster oeffnen holt die Zeile zurueck und raeumt Blasen weg
UI:OpenInput()
Guild("im Hintergrund")
UI:Show("guild")
assert(not R.docked and M.foot.parent == M.main and #R.bubbles == 0, "Fenster: Zeile zurueck, keine Blasen")
assert(UI:OpenInput() and M.frame.shown and not R.docked, "Fenster offen: Enter bleibt im Fenster")
M:Hide()

-- 5b) Fenster auf = Leiste weg, Fenster an der Leiste, klappt auf; zu = klappt zu, Leiste wieder da (Nutzer 23.11.2026)
M:Hide(true)
R.frame.shown = true
R.frame.GetLeft = function() return 2 end
R.frame.GetBottom = function() return 300 end
R.frame.GetHeight = function() return 200 end
UI:Show("guild")
assert(not R.frame.shown, "Fenster offen: Leiste weg")
local lp = M.frame.points[#M.frame.points]
assert(lp[1] == "LEFT" and lp[4] == 2 and lp[5] == 400, "Fenster an der Leiste (linker Rand, Mitte)")
M:Hide()
assert(not M.frame.shown and R.frame.shown, "zu: Leiste wieder da")
-- mit Massen: Vorhang laeuft ueber mehrere Bilder
M.frame.GetLeft = function() return 2 end
M.frame.GetTop = function() return 610 end
M.frame.fixedW, M.frame.fixedH = 640, 420
UI:Show("guild")
assert(R.anim and R.anim.opening and M.frame.parent == R.clip, "Aufklappen laeuft")
assert(R.clip.w < 10, "beginnt schmal an der Leiste")
R:AnimStep(R.ANIM / 2)
assert(R.clip.w > 100 and R.clip.w < 640, "halb offen: " .. R.clip.w)
R:AnimStep(R.ANIM)
assert(not R.anim and M.frame.parent == UIParent and R.clip.shown == false, "fertig: Fenster wieder normal")
M:Hide()
assert(R.anim and not R.anim.opening and M.frame.shown, "Zuklappen laeuft, Fenster noch da")
R:AnimStep(R.ANIM + .1)
assert(not M.frame.shown and R.frame.shown and not R.anim, "zugeklappt, Leiste da")
M.frame.GetLeft, M.frame.GetTop = nil, nil
-- von selbst zu (Standard aus)
UI:Show("guild")
for _ = 1, 50 do R:Tick(10) end
assert(M.frame.shown, "Standard: bleibt offen")
Chat:Settings().railAutoClose = 30
M.input.focus = false
M.frame.mouse = true
R:Tick(40)
assert(M.frame.shown, "Maus drauf: bleibt offen")
M.frame.mouse = false
R:Tick(20)
assert(M.frame.shown, "nach 20 s noch offen")
R:Tick(15)
assert(not M.frame.shown and R.frame.shown, "nach 30 s ohne Maus zu, Leiste da")
-- beim Tippen bleibt es offen
UI:Show("guild")
M.input.focus = true
R:Tick(100)
assert(M.frame.shown, "Tippen haelt offen")
M.input.focus = false
M:Hide(true)
Chat:Settings().railAutoClose = nil
-- Blinken: Symbole mit ungelesenen Nachrichten (nicht stumm)
Chat:MarkRead("guild")
R:SetActive("w:Brakk")
Guild("ungelesen in der Gilde")
R:Update()
local gb
for _, b in ipairs(R.icons) do if b.shown and b.conv and b.conv.view == "guild" then gb = b end end
assert(gb and gb.blink and not gb.flash, "Gilde atmet, ohne zusaetzlichen Ring")
-- ruhig: kleine Schritte von Bild zu Bild, gleich je Atemzug
local prev = R.BreathX(0)
for k = 1, 240 do
    local x = R.BreathX(k / 60)
    assert(math.abs(x - prev) < .03 and x >= 0 and x <= 1, "Atmen ohne Sprung")
    prev = x
end
assert(math.abs(R.BreathX(.3) - R.BreathX(.3 + R.BLINK_T)) < 1e-9, "gleichmaessig")
-- Neuzeichnen (jede Sekunde) setzt das Atmen nicht zurueck: Spieltest "Zucken"
clock = clock + .6
R:Tick(.016)
local before = gb.breath
R:Update()
assert(gb.breath and math.abs(gb.breath - before) < .03, "Neuzeichnen bleibt im Atemzug")
assert(gb.glass.ring.color[4] > .65 or R.BreathX(clock) < .01, "Rand leuchtet auf")
-- Rand in kraeftigem Rot (Nutzer 24.11.2026), Kreis leicht mitgefaerbt, egal welche Leuchtfarbe
R.Breathe(gb, 1, {0, 1, 0})
local rc = gb.glass.ring.color
assert(rc[1] == 1 and rc[2] < .2 and rc[3] < .2 and rc[4] == 1, "Rand kraeftig rot")
local ac = gb.glass.av.color
assert(ac[1] > ac[2] and ac[1] > ac[3] and ac[4] >= .85, "Kreis rot angehaucht")
assert(gb.glass.shine.color[4] >= .7, "Glanz")
R.Breathe(gb, 0, {0, 1, 0})
assert(gb.glass.ring.color[4] == .65, "ausgeatmet: normaler Rand")
Chat:Settings().railBlink = false
R:Update()
assert(not gb.blink, "Atmen abschaltbar")
Chat:Settings().railBlink = nil
R:SetActive("guild")

-- 5c) Chat-Knopf am WoW-Chat ist bei Randleiste weg (Spielbild 23.11.2026)
c.Launcher:Build()
c.Launcher:Update()
assert(c.Launcher.button and not c.Launcher.button.shown, "kein Chat-Knopf bei Randleiste")

-- 6) Ausschalten raeumt alles weg
UI:OpenInput()
Chat:Settings().rail = nil
R:Apply()
assert(not R.frame.shown and not R.docked and M.foot.parent == M.main, "aus: Leiste weg, Zeile zurueck")
assert(c.Launcher.button.shown, "aus: Chat-Knopf wieder da")

-- 7) Einstellungen: Randleiste im Chat, Hintergrund bis 0 % (durchsichtig)
local ids = {}
for _, d in ipairs(UI:SettingDefs()) do ids[d.id] = d end
assert(not ids["chat.rail"] and ids["chat.railWhisper"] and ids["chat.railTime"], "Randleiste ist ein Stil, Unterpunkte da")
local styleVals = {}
for _, o in ipairs(ids["chat.style"].options()) do styleVals[#styleVals + 1] = o.value end
assert(table.concat(styleVals, ",") == "messenger,rail,classic", "Stil: Messenger, Randleiste, Klassisch")
ids["chat.style"].set("rail")
assert(ids["chat.style"].get() == "rail" and R.Active() and ids["chat.railWhisper"].visible(), "Stil Randleiste")
ids["chat.style"].set("messenger")
assert(not R.Active() and not ids["chat.railWhisper"].visible(), "zurueck zu Messenger")
local found0
for _, o in ipairs(ids["chat.opacity"].options()) do if o.value == 0 then found0 = o.text end end
assert(found0 and found0:find("durchsichtig", 1, true), "Hintergrund 0 % waehlbar")

-- 8) Einrasten am Bildschirmrand (Nutzer 24.11.2026): links, rechts, oben, unten; frei bleibt frei
Chat:Settings().style = "rail"
Chat:Settings().rail = true
R:Apply()
assert(R.Active() and R.frame.shown, "Leiste wieder an")
UIParent.GetWidth = function() return 1920 end
UIParent.GetHeight = function() return 1080 end
local W, H = 1920, 1080
-- Rand-Erkennung
local side, pt = R.SnapPoint(20, 500, 38, 300, W, H)
assert(side == "left" and pt[1] == "LEFT" and pt[3] == R.EDGE, "links Mitte")
side, pt = R.SnapPoint(W - 38 - 10, 800, 38, 250, W, H)
assert(side == "right" and pt[1] == "TOPRIGHT" and pt[3] == -R.EDGE and pt[4] < 0, "rechts oben: Ecke bleibt")
side, pt = R.SnapPoint(900, H - 300 - 15, 38, 300, W, H)
assert(side == "top" and pt[1] == "TOP" and pt[4] == -R.EDGE, "oben Mitte")
side, pt = R.SnapPoint(1700, 10, 38, 300, W, H)
assert(side == "bottom" and pt[1] == "BOTTOMRIGHT" and pt[4] == R.EDGE, "unten rechts")
assert(R.SnapPoint(900, 400, 38, 300, W, H) == nil, "mitten im Bild: frei")
-- Ecken (Spieltest 24.11.2026): waagerecht bleibt waagerecht, senkrecht bleibt senkrecht, ganz in die Ecke
side, pt = R.SnapPoint(10, H - 38 - 5, 300, 38, W, H, true)
assert(side == "top" and pt[1] == "TOPLEFT" and pt[3] == R.EDGE and pt[4] == -R.EDGE, "waagerecht oben links in der Ecke")
side, pt = R.SnapPoint(W - 300 - 8, 6, 300, 38, W, H, true)
assert(side == "bottom" and pt[1] == "BOTTOMRIGHT" and pt[3] == -R.EDGE and pt[4] == R.EDGE, "waagerecht unten rechts in der Ecke")
side, pt = R.SnapPoint(5, H - 300 - 8, 38, 300, W, H, false)
assert(side == "left" and pt[1] == "TOPLEFT" and pt[4] == -R.EDGE, "senkrecht oben links bleibt senkrecht")
side, pt = R.SnapPoint(W - 38 - 4, 3, 38, 300, W, H, false)
assert(side == "right" and pt[1] == "BOTTOMRIGHT" and pt[4] == R.EDGE, "senkrecht unten rechts")
-- waagerecht an den linken Rand (nicht Ecke): wird senkrecht
side = R.SnapPoint(5, 500, 300, 38, W, H, true)
assert(side == "left", "waagerecht an die Seite: senkrecht")
-- Loslassen rastet ein und merkt sich Seite + Stelle
local railGetW, railGetH = R.frame.GetWidth, R.frame.GetHeight
local function DropAt(l, b, w, h)
    R.frame.GetLeft = function() return l end
    R.frame.GetBottom = function() return b end
    R.frame.GetWidth = function() return w end
    R.frame.GetHeight = function() return h end
    R:StopDrag()
    R.frame.GetWidth, R.frame.GetHeight = railGetW, railGetH
end
DropAt(900, H - 315, 38, 300)
assert(Chat:Settings().railSide == "top" and Chat:Settings().railPoint[1] == "TOP", "oben eingerastet")
assert(R.Horizontal() and R.frame.w > R.frame.h, "oben: Leiste waagerecht")
local icon1
for _, b in ipairs(R.icons) do if b.shown then icon1 = b break end end
assert(icon1.points[1][1] == "LEFT", "Symbole nebeneinander")
local hpTop = R.host.points[#R.host.points]
assert(hpTop[1] == "TOP" and hpTop[3] == "BOTTOM" and hpTop[5] < 0, "Blasen unter der Leiste")
-- oben: Blasen haengen darunter und sinken
R:ClearBubbles()
Guild("von oben")
local tb = R.bubbles[1]
local tp = tb.points[#tb.points]
assert(tp[1]:find("^TOP") and tp[5] <= 0, "Blase haengt nach unten")
R:Tick(1)
tp = tb.points[#tb.points]
assert(tp[5] < 0, "sinkt nach unten: " .. tostring(tp[5]))
-- Eingabezeile unter der Leiste, Listen darunter
UI:OpenInput()
local qp = R.quick.points[#R.quick.points]
assert(qp[1] == "TOP" and qp[3] == "BOTTOM", "Eingabezeile unter der Leiste")
local bp = R.bubbles[1].points[#R.bubbles[1].points]
assert(bp[5] <= -(R.QUICK_H + 6), "Blasen unter der Eingabezeile")
if M.picker then
    M:PlaceOverlay(M.picker, 20)
    assert(M.picker.points[1][1] == "TOPLEFT" and M.picker.points[1][3] == "BOTTOMLEFT", "Emojis unter der Zeile")
end
R:CloseInput()
-- Fenster klappt von oben nach unten auf
R.frame.GetLeft = function() return 900 end
R.frame.GetBottom = function() return H - 40 end
R.frame.GetHeight = function() return 38 end
R.frame.GetWidth = function() return 300 end
M.frame.GetLeft = function() return 730 end
M.frame.GetTop = function() return H - 2 end
M.frame.fixedW, M.frame.fixedH = 640, 420
UI:Show("guild")
local wp = M.frame.points[1]
assert(R.clip.points[1][1] == "TOPLEFT" and R.anim and R.anim.vertical, "Vorhang von oben")
assert(R.clip.h < 10 and R.clip.w == 640, "beginnt flach an der Leiste")
R:AnimStep(R.ANIM / 2)
assert(R.clip.h > 100 and R.clip.h < 420, "halb offen nach unten: " .. R.clip.h)
R:AnimStep(R.ANIM)
M:Hide()
R:AnimStep(R.ANIM + .1)
assert(not M.frame.shown and R.frame.shown, "zu: Leiste oben wieder da")
-- rechts: senkrecht, alles nach links
DropAt(W - 45, 400, 300, 38)
assert(Chat:Settings().railSide == "right" and not R.Horizontal() and R.frame.h > R.frame.w, "rechts: senkrecht")
local hpR = R.host.points[#R.host.points]
assert(hpR[1] == "BOTTOMRIGHT" and hpR[3] == "BOTTOMLEFT" and hpR[4] < 0, "Blasen links der Leiste")
assert(R.TipAnchor() == "ANCHOR_LEFT", "Tooltip nach links")
R.frame.GetLeft = function() return W - 40 end
R.frame.GetBottom = function() return 400 end
R.frame.GetHeight = function() return 300 end
R.frame.GetWidth = function() return 38 end
M:Hide(true)
R.frame.shown = true
UI:Show("guild")
assert(M.frame.points[1][1] == "TOPRIGHT" or M.frame.points[#M.frame.points][1] == "RIGHT", "Fenster am rechten Rand")
assert(R.clip.points[1][1] == "TOPRIGHT" and not R.anim.vertical, "Vorhang von rechts")
R:AnimStep(R.ANIM + .1)
M:Hide()
R:AnimStep(R.ANIM + .1)
-- unten: waagerecht, Blasen steigen darueber
DropAt(900, 8, 38, 300)
assert(Chat:Settings().railSide == "bottom" and R.Horizontal(), "unten: waagerecht")
local hpB = R.host.points[#R.host.points]
assert(hpB[1] == "BOTTOM" and hpB[3] == "TOP" and hpB[5] > 0, "Blasen ueber der Leiste")
R:ClearBubbles()
Guild("von unten")
local ub = R.bubbles[1].points[#R.bubbles[1].points]
assert(ub[1]:find("^BOTTOM") and ub[5] >= 0, "Blase steigt nach oben")
-- unten: ueber den Aktionsleisten, nicht dahinter (Spieltest 24.11.2026)
local function Bar(l, b, w, h) return {IsVisible = function() return true end, GetTop = function() return b + h end,
    GetBottom = function() return b end, GetLeft = function() return l end, GetRight = function() return l + w end} end
MainActionBar = Bar(700, 0, 520, 45)
MultiBarBottomLeft = Bar(700, 45, 520, 45)
MicroMenuContainer = Bar(1600, 0, 300, 40)
assert(R.BottomInset(800, 1000) == 90, "ueber beiden Leisten")
assert(R.BottomInset(100, 300) == 0, "links frei: kein Abstand")
assert(R.BottomInset(1650, 1700) == 40, "ueber dem Menue")
DropAt(900, 8, 38, 300)
local rp = R.frame.points[#R.frame.points]
assert(rp[1] == "BOTTOM" and rp[5] == R.EDGE + 90, "Leiste sitzt ueber den Aktionsleisten: " .. tostring(rp[5]))
MultiBarBottomLeft.IsVisible = function() return false end
R:Update()
rp = R.frame.points[#R.frame.points]
assert(rp[5] == R.EDGE + 45, "Leiste ausgeblendet: rutscht nach")
-- Knopf statt Leiste erkannt (anderer Name im Client)
MultiBarBottomLeft = nil
MainActionBar = nil
ActionButton3 = Bar(850, 0, 40, 40)
R:Update()
assert(R.frame.points[#R.frame.points][5] == R.EDGE + 40, "einzelner Aktionsknopf reicht")
-- Notausgang /trip leiste
R:Reset()
assert(Chat:Settings().railSide == nil and Chat:Settings().railPoint == nil, "Reset: frei")
assert(R.frame.points[#R.frame.points][1] == "LEFT" and not R.Horizontal(), "Reset: links, senkrecht")
assert(ONE.printed and ONE.printed:find("ActionButton3=40", 1, true), "Reset nennt erkannte Leisten: " .. tostring(ONE.printed))
ActionButton3 = nil
DropAt(900, 8, 38, 300)
MainActionBar, MultiBarBottomLeft, MicroMenuContainer = nil, nil, nil
R:Update()
assert(R.frame.points[#R.frame.points][5] == R.EDGE, "ohne Leisten am Rand")
-- Umriss beim Ziehen (Nutzer 24.11.2026): zeigt Lage und Stelle, bevor man loslaesst
R:StartDrag()
R.frame.GetLeft = function() return 900 end
R.frame.GetBottom = function() return H - 300 - 10 end
R.frame.GetWidth = function() return 38 end
R.frame.GetHeight = function() return 300 end
Chat:Settings().railSide = nil
R:Tick(.01)
assert(R.ghost and R.ghost.shown, "Umriss am oberen Rand")
assert(R.ghost.w == 300 and R.ghost.h == R.WIDTH, "Umriss schon waagerecht")
assert(R.ghost.points[1][1] == "TOP", "Umriss oben")
R.frame.GetBottom = function() return 400 end
R:Tick(.01)
assert(not R.ghost.shown, "mitten im Bild: kein Umriss")
R.frame.GetLeft = function() return 4 end
R:Tick(.01)
assert(R.ghost.shown and R.ghost.w == R.WIDTH and R.ghost.h == 300, "links: Umriss senkrecht")
R:StopDrag()
assert(not R.ghost.shown and Chat:Settings().railSide == "left", "losgelassen: Umriss weg, eingerastet")
R.frame.GetWidth, R.frame.GetHeight = railGetW, railGetH
-- frei im Bild: senkrecht, Seite nach Bildschirmhaelfte
DropAt(1400, 400, 300, 38)
assert(Chat:Settings().railSide == nil and not R.Horizontal(), "frei: senkrecht")
R.frame.GetLeft = function() return 1400 end
R.frame.GetWidth = function() return 38 end
assert(R.Layout() == "right", "frei in der rechten Haelfte: Blasen nach links")
R.frame.GetLeft = function() return 300 end
assert(R.Layout() == "left", "frei links: wie bisher")
M.frame.GetLeft, M.frame.GetTop, M.frame.fixedW, M.frame.fixedH = nil, nil, nil, nil
print("OK test_rail_166")
