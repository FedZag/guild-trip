-- Offline-Test: Gegenstands-Vorschlaege beim Tippen von "[" (Nutzer 23.11.2026)
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
for _, f in ipairs({"Chat", "Emoji", "ChatUI", "Messenger", "SlashList", "ItemNames", "ItemList", "Rail", "TabEditor", "Settings", "Launcher"}) do
    assert(loadfile(root .. "/ONE_Chat/" .. f .. ".lua"))("ONE_Chat", c)
end
local Chat, UI, M, Emoji = c.Chat, c.UI, c.Messenger, c.Emoji
assert(Chat:Settings().style == "messenger", "Messenger ist Standard")
M:Install()
Chat.listeners[#Chat.listeners + 1] = function(entry, views, update) UI:OnMessage(entry, views, update) end
local IL = c.ItemList
assert(IL and c.ItemNames and c.ItemNames.count > 15000, "Gegenstandsnamen geladen")
GetLocale = function() return "deDE" end

-- 1) Suche: deutsch und englisch, Namensanfang zuerst, Umlaute, mindestens 2 Zeichen
local hits = IL:Search("armschienen der volks")
assert(hits[1] and hits[1].id == 710 and hits[1].name == "Armschienen der Volksmiliz", "deutscher Name: " .. tostring(hits[1] and hits[1].name))
hits = IL:Search("bracers of the people")
assert(hits[1] and hits[1].id == 710 and hits[1].name == "Armschienen der Volksmiliz", "englisch gesucht, deutsch gezeigt")
assert(#IL:Search("a") == 0, "ein Zeichen: noch nichts")
hits = IL:Search("eisbedeck")
assert(hits[1] and hits[1].id == 763, "Namensanfang")
local um = IL:Search("ÄTZ")
for _, e in ipairs(um) do assert(IL.Lower(e.name):find("ätz", 1, true) or e.keys[2] and e.keys[2]:find("ätz", 1, true), "Umlaut") end
-- Namensanfang vor Wortanfang vor Mitte
hits = IL:Search("armschienen")
assert(IL.Lower(hits[1].name):sub(1, 11) == "armschienen", "Anfang zuerst: " .. hits[1].name)
assert(#hits <= IL.MAX, "begrenzt")

-- 2) "[" vor dem Cursor erkennen, nach fertigem Link nicht
assert(select(2, IL.Token("ich brauche [eisbe")) == "eisbe", "Suchtext nach [")
assert(not IL.Token("schau |cff1eff00|Hitem:763::::::::|h[Eisbedeckte Armschienen]|h|r "), "nach fertigem Link keine Liste")
assert(not IL.Token("ohne Klammer"), "ohne [ nichts")

-- 3) Im Eingabefeld: Liste geht auf, Pfeil waehlt, Enter setzt den Link ein statt zu senden
UI:Show("guild")
local box = M.input
GetItemInfo = function(id) if id == 710 then return "Armschienen der Volksmiliz", "|cffffffff|Hitem:710::::::::|h[Armschienen der Volksmiliz]|h|r" end end
box:SetText("ich brauche noch [armschienen der v")
box.scripts.OnTextChanged(box)
assert(IL:IsShown() and IL.matches[1].id == 710, "Liste offen")
assert(IL.frame.rows[1].name.text:find("Armschienen der Volksmiliz", 1, true), "Zeile zeigt den Namen")
for k in pairs(sent) do sent[k] = nil end
box.scripts.OnEnterPressed(box)
assert(#sent == 0, "Enter sendet nicht, solange die Liste offen ist")
assert(box.text == "ich brauche noch |cffffffff|Hitem:710::::::::|h[Armschienen der Volksmiliz]|h|r ", "Link eingesetzt: " .. box.text)
assert(not IL:IsShown(), "Liste zu")
-- jetzt sendet Enter
box.scripts.OnEnterPressed(box)
assert(sent[#sent] and sent[#sent][1]:find("Hitem:710", 1, true), "mit Link gesendet")

-- 4) Pfeil + Tab, Escape schliesst nur die Liste
box:SetText("[eisbede")
box.scripts.OnTextChanged(box)
assert(IL:IsShown())
local first = IL.matches[1]
if #IL.matches > 1 then assert(IL:Move(1) and IL.sel == 2, "Pfeil runter") IL:Move(-1) end
box.scripts.OnEscapePressed(box)
assert(not IL:IsShown() and box.text == "[eisbede", "Esc: nur Liste zu")
-- Gegenstand, den der Client noch nicht kennt: eigener Link mit Qualitaetsfarbe
GetItemInfo = function() return nil end
box:SetText("[eisbede")
box.scripts.OnTextChanged(box)
box.scripts.OnTabPressed(box)
assert(box.text:find("|Hitem:" .. first.id .. "::::::::|h[" .. first.name .. "]|h|r", 1, true) and box.text:find("^|cff1eff00"), "selbst gebauter Link: " .. box.text)
GetItemInfo = nil
M:Hide()
print("OK test_itemlist_167")
