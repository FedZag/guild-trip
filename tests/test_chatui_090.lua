-- Offline-Test: Guild-Trip-Chat (Fenster) – oeffnen, Verlauf, Zaehler/Blinken, Senden mit
-- festem Ziel, Tab wechselt Gespraech, Spielerlink -> Namens-Menue, eigener Reiter.
local root = arg[1] or "src"
local made = {}
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, lines = {}, text = ""}
    made[#made + 1] = r
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:GetScript(e) return self.scripts[e] end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:GetHeight() return 300 end
    function r:GetWidth() return 600 end
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
local sentMsgs = {}
SendChatMessage = function(msg, chatType, _, target) sentMsgs[#sentMsgs + 1] = {msg, chatType, target} end
local ONE = {db = {}, modules = {}}
_G.ProjectONE = ONE
function ONE:Print(m) self.printed = m end
ONE.Themes = setmetatable({}, {__index = function() return function() end end})
local buttons = {}
ONE.Widgets = {
    Button = function(_, parent, text, w, h, point, x, y, cb) local b = Region("Button", parent) b.text = text b.click = cb buttons[#buttons + 1] = b return b end,
    CloseButton = function(_, parent) return Region("Button", parent) end,
}
local checks = {}
ONE.Kit = {
    Check = function(_, parent, o) local b = Region("CheckButton", parent) b.o = o checks[#checks + 1] = b function b:Refresh() end return b end,
    Dropdown = function(_, parent, o) local d = {o = o, frame = Region("Frame", parent)} function d:Refresh() end return d end,
}
local menuFor
ONE.PlayerMenu = {Open = function(_, owner, name, ctx) menuFor = {name, ctx} return true end}
local c = {}
for _, f in ipairs({"Chat", "ChatUI", "TabEditor", "Settings"}) do assert(loadfile(root .. "/ONE_Chat/" .. f .. ".lua"))("ONE_Chat", c) end
local Chat, UI = c.Chat, c.UI
Chat.listeners[#Chat.listeners + 1] = function(entry, views) UI:OnMessage(entry, views) end

-- 1) Nachrichten vor dem Oeffnen: Zaehler; beim Oeffnen gelesen und im Verlauf
Chat:OnEvent("CHAT_MSG_GUILD", "Hallo Gilde", "Rexxar", "", "", "", "", 0, 0, "", 0, 7, "")
assert(Chat.unread.all == 1)
UI:Show("guild")
assert(UI.frame.shown and UI.current == "guild" and #UI.log.lines == 1 and UI.log.lines[1]:find("Hallo Gilde"))
assert(Chat.unread.guild == nil, "beim Ansehen gelesen")
-- 0.6.8: im Blizzard-Aussehen mit Auswahlpfeil dahinter
assert(UI.toButton.text:find("^An: Gilde"), UI.toButton.text)
assert(UI.modern and UI.sendButton and UI.headContext, "Blizzard-Aussehen: Senden-Knopf und Kopfzeile")

-- 2) Fluestern kommt rein: eigenes Gespraech mit Zaehler, das blinkt
Chat:OnEvent("CHAT_MSG_WHISPER", "Bist du dabei?", "Thrall-Forever", "", "", "", "", 0, 0, "", 0, 9, "")
local row
for _, r in ipairs(UI.rows) do if r.entry and r.entry.whisper == "Thrall" then row = r end end
assert(row and row.badge.text:find("1") and row.flash.shown and row.pulse.playing, "Zaehler blinkt")
assert(#UI.log.lines == 1, "Gildenansicht bekommt kein Fluestern")

-- 3) Gespraech oeffnen (Klick), Enter schickt genau dorthin
row.scripts.OnClick(row, "LeftButton")
assert(UI.current == "w:Thrall" and UI.toButton.text:find("^An: Thrall") and #UI.log.lines == 1)
assert(not row.pulse.playing, "gelesen: Blinken aus")
UI.input.text = "Ja, ich komme"
UI.input.scripts.OnEnterPressed(UI.input)
assert(sentMsgs[1][2] == "WHISPER" and sentMsgs[1][3] == "Thrall" and UI.input.text == "")

-- 4) Tab im Eingabefeld: naechstes Gespraech
Chat:OnEvent("CHAT_MSG_WHISPER", "Erz?", "Jaina", "", "", "", "", 0, 0, "", 0, 10, "")
UI:CycleWhisper()
assert(UI.current == "w:Thrall" or UI.current == "w:Jaina")
local before = UI.current
UI:CycleWhisper()
assert(UI.current ~= before, "Tab wechselt das Gespraech")

-- 5) Spielerlink im Verlauf: Namens-Menue mit Zeilennummer (fuer Melden)
UI.log.scripts.OnHyperlinkClick(UI.log, "player:Thrall-Forever:9", "[Thrall]", "LeftButton")
assert(menuFor[1] == "Thrall-Forever" and menuFor[2].lineID == 9)

-- 6) Lesereiter ohne Schreibziel: Senden geht nicht, Hinweis
UI:Show("all")
Chat:Tab("all").send = nil
UI.input.text = "test"
UI.input.scripts.OnEnterPressed(UI.input)
assert(ONE.printed == "In diesem Reiter kann man nicht schreiben." and UI.input.text == "test")

-- 7) Eigener Reiter ueber den Dialog
UI:EditTab()
local d = UI.editor
d.name.text = "Handwerk"
d.state.kinds = {trade = true, guild = true}
d.state.send = "guild"
d.save.click()
local tab
for _, t in ipairs(Chat:Tabs()) do if t.label == "Handwerk" then tab = t end end
assert(tab and tab.kinds.trade and tab.send == "guild" and UI.current == tab.id)
-- 8) Zahnrad: springt in Optionen › Chat (0.6.9: kein eigenes Einstellungsfenster mehr)
local registered, opened = {}, nil
ONE.UI = {AddSetting = function(_, o) registered[#registered + 1] = o return true end,
    OpenOptions = function(_, cat) opened = cat return true end}
assert(UI:RegisterSettings())
assert(UI.gear and UI.gear.scripts.OnClick, "Zahnrad im Fenster")
UI.gear.scripts.OnClick(UI.gear)
assert(opened == "chat" and not UI.settings, "Zahnrad oeffnet Optionen › Chat")
local checks, drops, guildBox = 0, 0, nil
for _, o in ipairs(registered) do
    assert(o.category == "chat" and o.module == "chat")
    if o.kind == "dropdown" then drops = drops + 1 elseif o.kind ~= "text" then checks = checks + 1 end
    if o.label == "Ton bei Gildennachrichten" then guildBox = o end
end
assert(checks == #UI.settingChecks and drops == #UI.settingDrops, "alle Chat-Schalter angemeldet")
assert(guildBox and guildBox.get() == false and guildBox.section == "Verhalten & Töne")
guildBox.set(true)
assert(Chat:Settings().guildSound == true)
ONE.UI = nil
local sd = {drops = {}}
for _, o in ipairs(registered) do if o.kind == "dropdown" then sd.drops[o.id:gsub("^chat%.", "")] = {o = o} end end
sd.font = sd.drops.fontSize
assert(UI.SettingOn("whisperHere"), "Fluestern hier: Standard an")
sd.font.o.set(18)
assert(Chat:Settings().fontSize == 18)
-- 8b) Aussehen: Hintergrund-Deckkraft, Zeilenabstand, Festsetzen, Ausblenden ohne Maus
do
    local parts, realParts = {}, UI.BackgroundParts
    UI.BackgroundParts = function() return parts end
    local tex = Region("Texture") function tex:SetAlpha(a) self.alpha = a end
    parts[1] = tex
    function UI.log:SetSpacing(n) self.spacing = n end
    function UI.frame:SetAlpha(a) self.alpha = a end
    function UI.frame:GetAlpha() return self.alpha or 1 end
    function UI.frame:IsMouseOver() return false end
    sd.drops.opacity.o.set(.4)
    assert(tex.alpha == .4, "Hintergrund halb durchsichtig")
    sd.drops.spacing.o.set(4)
    assert(UI.log.spacing == 4)
    sd.drops.idleAlpha.o.set(.35)
    local tick = UI.frame.scripts.OnUpdate
    assert(tick, "Ausblenden laeuft")
    for _ = 1, 40 do tick(UI.frame, .25) end
    assert(math.abs(UI.frame.alpha - .35) < .01, "ohne Maus ausgeblendet")
    UI:WakeUp()
    for _ = 1, 4 do tick(UI.frame, .25) end
    assert(UI.frame.alpha == 1, "neue Nachricht: wieder sichtbar")
    sd.drops.idleAlpha.o.set(1)
    assert(UI.frame.scripts.OnUpdate == nil and UI.frame.alpha == 1)
    UI.SetSetting("locked", true) UI:ApplyLook()
    assert(not UI.grip.shown, "festgesetzt: kein Groessengriff")
    UI.SetSetting("locked", false) UI:ApplyLook()
    UI.BackgroundParts = realParts
end
-- 9) Mit ElvUI: Hinweis im Zahnrad, schlichtes Aussehen ohne Tinte (eigene Instanz)
do
    local c2 = {}
    C_AddOns = {IsAddOnLoaded = function(name) return name == "ElvUI" end}
    ONE.db = {}
    ONE.Book = {IsActive = function() return true end, Ink = function() return .1, .05, .01 end, InkCodes = function() return "TINTE" end}
    for _, f in ipairs({"Chat", "ChatUI", "TabEditor", "Settings"}) do assert(loadfile(root .. "/ONE_Chat/" .. f .. ".lua"))("ONE_Chat", c2) end
    c2.UI:Show("guild")
    assert(c2.UI.flat, "schlicht bei ElvUI")
    c2.Chat:OnEvent("CHAT_MSG_GUILD", "Hallo", "Rexxar", "", "", "", "", 0, 0, "", 0, 1, "")
    c2.UI:Render()
    assert(c2.UI.log.lines[1] ~= "TINTE" and c2.UI.log.lines[1]:find("Hallo"), "keine Tinte auf dunklem Grund")
    local hint
    ONE.UI = {AddSetting = function(_, o) if o.id == "chatOther" then hint = o end return true end}
    c2.UI:RegisterSettings()
    assert(hint and hint.visible() and hint.label():find("ElvUI"), "Hinweis in Optionen › Chat")
    ONE.UI = nil
    C_AddOns, ONE.Book = nil, nil
end
-- 10) Chat-Knopf: Zaehler nur fuer Fluestern, Klick oeffnet/schliesst, abschaltbar
do
    ONE.db = {}
    assert(loadfile(root .. "/ONE_Chat/Launcher.lua"))("ONE_Chat", c)
    local L = c.Launcher
    Chat.unread = {guild = 3, all = 5, ["w:Thrall"] = 2}
    local b = L:Build()
    L:Update()
    assert(b.shown and b.badge.text == "2", "Zaehler zeigt Fluestern")
    UI:Hide()
    b.scripts.OnClick(b)
    assert(UI.frame.shown, "Klick oeffnet den Chat")
    b.scripts.OnClick(b)
    assert(not UI.frame.shown, "zweiter Klick schliesst")
    assert(UI.SettingOn("launcher"), "Knopf: Standard an")
    UI.SetSetting("launcher", false)
    L:Update()
    assert(not b.shown, "abgeschaltet")
    assert(type(GuildTripChat_Toggle) == "function" and BINDING_NAME_GUILDTRIPCHAT_TOGGLE)
end
print("OK test_chatui_090")
