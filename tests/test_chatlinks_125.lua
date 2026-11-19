-- Offline-Test 0.7.2: Berufs-Links aus dem Chat (still mitlesen, nur lokal, Standard aus, nie senden).
local root = arg[1] or "src"
local printed = {}
local made = {}
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, scroll = 0}
    made[#made + 1] = r
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then
            return function() end
        end
    end})
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetPoint(...) self.point = {...} end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text or "" end
    function r:SetTextColor(...) self.color = {...} end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:HookScript(e, fn) self.scripts["hook:" .. e] = fn end
    function r:RegisterEvent(e) self.events = self.events or {} self.events[e] = true end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetVerticalScroll(v) self.scroll = v end
    function r:GetVerticalScroll() return self.scroll end
    function r:GetChecked() return self.checked end
    function r:SetChecked(v) self.checked = v end
    function r:GetStringHeight() return 40 end
    function r:SetTexture(t) self.texture = t end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
-- (Grundgeruest wie test_crafting_049)
local sent, opened = {}, {}
NOW = 1000
GetTime = function() return NOW end
GetServerTime = function() return 1794477894 end
IsInGuild = function() return true end
UnitFullName = function() return "Testheld", "Testrealm" end
GetNumGuildMembers = function() return 3, 2 end
GetGuildRosterInfo = function(i)
    local names = {"Testheld-Testrealm", "Rehgar-Testrealm", "Saurfang-Testrealm"}
    return names[i], "Mitglied", 1, 20, "Krieger", "Durotar", "", "", i <= 2
end
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(p, m, c) sent[#sent + 1] = {p, m, c} return true end}
ChatFrame_OpenChat = function(text) opened[#opened + 1] = text end
local items = {[2840] = "Kupferbarren", [2589] = "Leinenstoff", [4343] = "Schlichte Leinenhose"}
C_Item = {GetItemNameByID = function(id) return items[id] end, GetItemInfo = function(id)
    if id == 4343 then return "Schlichte Leinenhose", "|cffffffff|Hitem:4343|h[Schlichte Leinenhose]|h|r" end end,
    GetItemIconByID = function() return 1 end}
C_Spell = {GetSpellName = function(id) return id == 3914 and "Schlichte Leinenhose herstellen" or nil end}
C_TradeSkillUI = {
    IsTradeSkillLinked = function() return false end,
    GetBaseProfessionInfo = function() return {professionName = "Bergbau", skillLevel = 24, maxSkillLevel = 75} end,
    GetAllRecipeIDs = function() return {2657, 2659, 1213638} end,
    GetRecipeInfo = function(id) return {name = id == 2657 and "Kupfer verhütten" or "Anderes", learned = id == 2657} end,
    GetRecipeOutputItemData = function(id) return {itemID = id == 2657 and 2840 or 1} end,
}
local ONE = {db = {}, modules = {}, slash = {}}
function ONE:Print() end
function ONE:IsEnabled() return true end
function ONE:RegisterSlash(n, fn) self.slash[n] = fn end
ONE.features = {}
function ONE:RegisterFeature(id, def) self.features[id] = def end
function ONE:FeatureOn(id) local d = self.features[id] return d and d.get and d.get() or false end
function ONE:SetFeature(id, on) self.features[id].set(on) end
function ONE:RegisterModule(id, def) self.modules[id] = def def.Initialize(def) end
local tabs = {}
ONE.UI = {Layout = {width = 726}, activeTab = "crafting", frame = UIParent,
    AddTab = function(_, id, _, builder) tabs[id] = builder(Region("Frame")) return true end}
_G.ProjectONE = ONE
for _, f in ipairs({"Themes.lua", "Kit.lua", "Geometry.lua", "Widgets.lua"}) do
    assert(loadfile(root .. "/ONE_Core/" .. f))("ONE_Core", ONE)
end
ONE.Themes:Initialize()
local c = {}
local toc = assert(io.open(root .. "/ONE_Crafting/ONE_Crafting.toc")):read("*a")
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Crafting/" .. name))("ONE_Crafting", c) end
local R, S = c.Recipes, c.Share
assert(tabs.crafting, "Reiter Berufe fehlt")
local L = c.ChatLinks
local refs = {}
SetItemRef = function(link, text, button) refs[#refs + 1] = {link, text, button} end
GetPlayerInfoByGUID = function(guid) if guid == "Player-1-00000BBB" then return "Krieger", "WARRIOR", "Mensch", "Human", 2, "Kraxler", "" end end
local wolle = "|cffffd000|Henchant:2964|h[Schneiderei: Wollstoffballen]|h|r"
local beruf = "|cffffd000|Htrade:Player-1-00000AAA:3908:197|h[Schneiderei]|h|r"

-- 1) Nur erlaubte Chat-Ereignisse, kein Kampflog, nichts senden
assert(L.frame and L.frame.events, "Ereignisse angemeldet")
for ev in pairs(L.frame.events) do
    assert(ev == "CHAT_MSG_GUILD" or ev == "CHAT_MSG_OFFICER" or ev == "CHAT_MSG_WHISPER" or ev == "CHAT_MSG_CHANNEL", ev)
end
local src = assert(io.open(root .. "/ONE_Crafting/ChatLinks.lua")):read("*a"):gsub("%-%-[^\n]*", "")
for _, bad in ipairs({"SendChatMessage", "SendAddonMessage", "COMBAT_LOG", "CombatLog", "DoEmote", "BNSendWhisper"}) do
    assert(not src:find(bad, 1, true), "ChatLinks darf nicht: " .. bad)
end

-- 2) Erkennen: Rezept, Beruf, spell-Variante, keine Gegenstaende
local p = L.Parse("Mache " .. wolle .. " und " .. beruf .. " und |cffffffff|Hitem:4343|h[Hose]|h|r")
assert(#p == 2 and p[1].kind == "recipe" and p[1].recipeID == 2964 and p[1].prof == "Schneiderei"
    and p[1].recipe == "Wollstoffballen", "Rezept-Link")
assert(p[2].kind == "trade" and p[2].prof == "Schneiderei" and p[2].guid == "Player-1-00000AAA", "Beruf-Link")
assert(#L.Parse("|Hspell:3914|h[Tailoring: Linen Pants]|h") == 1)
assert(#L.Parse("|Hspell:133|h[Feuerball: Rang 1]|h") == 0, "Zauber ohne Beruf ignorieren")
assert(L.ChannelKind("2. Handel - Stadt") == "trade" and L.ChannelKind("Trade - City") == "trade"
    and not L.ChannelKind("1. Allgemein - Durotar"))

-- 3) Standard AUS: nichts wird gemerkt
assert(not L:Enabled() and not ONE:FeatureOn("crafting.chatLinks"))
local fire = L.frame.scripts.OnEvent
fire(L.frame, "CHAT_MSG_CHANNEL", "WTS " .. wolle, "Weber-Testrealm", "", "2. Handel - Stadt", "", "", 0, 2, "Handel - Stadt", 0, 1, "Player-1-00000CCC")
assert(next(L:Data()) == nil, "aus = nichts merken")

-- 4) Eingeschaltet: Handel, Gilde, Fluestern; allgemeiner Kanal und eigene Nachrichten nicht
ONE:SetFeature("crafting.chatLinks", true)
assert(L:Enabled())
fire(L.frame, "CHAT_MSG_CHANNEL", "WTS " .. wolle, "Weber-Testrealm", "", "2. Handel - Stadt", "", "", 0, 2, "Handel - Stadt", 0, 1, "Player-1-00000CCC")
fire(L.frame, "CHAT_MSG_CHANNEL", "LF " .. wolle, "Plauder-Testrealm", "", "1. Allgemein", "", "", 0, 1, "Allgemein", 0, 2, "Player-1-00000DDD")
fire(L.frame, "CHAT_MSG_GUILD", "kann ich " .. beruf, "Schneider-Testrealm", "", "", "", "", 0, 0, "", 0, 3, "Player-1-00000AAA")
fire(L.frame, "CHAT_MSG_GUILD", "meins " .. wolle, "Testheld-Testrealm", "", "", "", "", 0, 0, "", 0, 4, "Player-1-00000EEE")
-- weitergereichter Beruf-Link: Besitzer laut GUID, nicht der Absender
fire(L.frame, "CHAT_MSG_WHISPER", "frag den " .. (beruf:gsub("00000AAA", "00000BBB")), "Bote-Testrealm", "", "", "", "", 0, 0, "", 0, 5, "Player-1-00000FFF")
local d = L:Data()
assert(d["Weber-Testrealm"].recipes[2964].src == "trade", "Handel gemerkt")
assert(not d["Plauder-Testrealm"], "Allgemein-Kanal nicht")
assert(not d["Testheld-Testrealm"], "eigene Nachrichten nicht")
assert(d["Schneider-Testrealm"].profs.Schneiderei.src == "guild" and d["Schneider-Testrealm"].profs.Schneiderei.link:find("Htrade:", 1, true))
assert(d["Kraxler"] and d["Kraxler"].profs.Schneiderei.src == "whisper" and not d["Bote-Testrealm"], "Besitzer aus GUID")
assert(R:Name(2964) == "Wollstoffballen", "Rezeptname aus dem Link")

-- 5) Geheime Werte (im Kampf) werden uebersprungen
issecretvalue = function(v) return v == "GEHEIM" end
fire(L.frame, "CHAT_MSG_GUILD", "GEHEIM", "Geheim-Testrealm", "", "", "", "", 0, 0, "", 0, 6, "Player-1-00000999")
assert(not d["Geheim-Testrealm"])
issecretvalue = nil

-- 6) Berufe-Seite: Eintrag mit "hat verlinkt", Ansehen + Anfragen
local cat = R:Catalog()
local wool, trade
for _, e in ipairs(cat) do
    if e.recipeID == 2964 then wool = e end
    if e.recipeID == "trade:Schneiderei" then trade = e end
end
assert(wool and #wool.crafters == 1 and wool.crafters[1].chat and wool.crafters[1].name == "Weber-Testrealm")
assert(trade and trade.trade and #trade.crafters == 2)
tabs.crafting()
local search
for _, r in ipairs(made) do if r.kind == "EditBox" then search = r end end
search.text = "wollstoff"
search.scripts["hook:OnTextChanged"]()
local info
for _, r in ipairs(made) do
    if r.kind == "FontString" and type(r.text) == "string" and r.text:find("im Chat verlinkt (Handel)", 1, true) then info = r.text end
end
assert(info, "Vermerk 'hat am … im Chat verlinkt (Handel)'")
search.text = "ganzer beruf"
search.scripts["hook:OnTextChanged"]()
local view, ask
for _, r in ipairs(made) do
    if r.kind == "Button" and r.shown and r.text == "Ansehen" and not view then view = r end
    if r.kind == "Button" and r.shown and r.text == "Anfragen" and not ask then ask = r end
end
assert(view and ask, "Ansehen + Anfragen")
view.scripts.OnClick(view)
assert(refs[1] and refs[1][1]:find("^trade:Player%-1%-") and refs[1][3] == "LeftButton", "Berufsfenster oeffnen")
ask.scripts.OnClick(ask)
assert(opened[#opened]:find("^/w ") and opened[#opened]:find("Schneiderei", 1, true) and not opened[#opened]:find("Rezept trade"))
assert(#sent == 0, "nichts gesendet")

-- 7) Verfallen nach 30 Tagen, Befehl, Leeren
assert(ONE.slash.berufslinks)
ONE.slash.berufslinks("")
L:Prune(R.Now() + 31 * 24 * 3600)
assert(next(L:Data()) == nil, "alte Links verfallen")
fire(L.frame, "CHAT_MSG_WHISPER", wolle, "Weber-Testrealm", "", "", "", "", 0, 0, "", 0, 7, "Player-1-00000CCC")
assert(next(L:Data()))
ONE.slash.berufslinks("leeren")
assert(next(L:Data()) == nil)
print("OK test_chatlinks_125")
