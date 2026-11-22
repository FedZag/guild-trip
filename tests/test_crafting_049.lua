-- Offline-Test 0.4.7a: Gilden-Funk (Fortschritt, Gesuche) und Reiter Gruppen – Mehrspieler simuliert.
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
-- Offline-Test 0.4.9a: ONE Berufe – eigene Rezepte, Teilen in der Gilde, Suche, Anfragen.
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
function ONE:RegisterModule(id, def) self.modules[id] = def def.Initialize(def) end
local tabs = {}
ONE.UI = {Layout = {width = 726}, activeTab = "crafting", frame = UIParent,
    AddTab = function(_, id, _, builder) tabs[id] = builder(Region("Frame")) return true end}
_G.ProjectONE = ONE
assert(loadfile(root .. "/ONE_Core/PlayerMenu.lua"))("ONE_Core", ONE) -- ONE:Whisper
for _, f in ipairs({"Themes.lua", "Kit.lua", "Geometry.lua", "Widgets.lua"}) do
    assert(loadfile(root .. "/ONE_Core/" .. f))("ONE_Core", ONE)
end
ONE.Themes:Initialize()
local c = {}
local toc = assert(io.open(root .. "/ONE_Crafting/ONE_Crafting.toc")):read("*a")
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Crafting/" .. name))("ONE_Crafting", c) end
local R, S = c.Recipes, c.Share
assert(tabs.crafting, "Reiter Berufe fehlt")

-- 1) Eigenes Berufsfenster: nur gelernte Rezepte werden gemerkt
local prof, count = R:Capture()
assert(prof == "Bergbau" and count == 1)
local mine = R:Mine().Bergbau
assert(mine.skill == 24 and mine.recipes[2657] == 2840 and not mine.recipes[2659])
assert(R:Name(2657) == "Kupfer verhütten")

-- 2) Teilen nur mit Zustimmung; Pakete <= 255 Zeichen
assert(not S:SendAll() and #sent == 0)
for i = 1, 60 do mine.recipes[100000 + i] = 2840 end -- viele Rezepte -> mehrere Pakete
S:SetSharing(true)
local c0, c1 = 0, 0
for _, m in ipairs(sent) do
    assert(m[1] == "ONECRF1" and m[3] == "GUILD" and #m[2] <= 255)
    if m[2]:find("^C0|Bergbau|24|75|") then c0 = c0 + 1 end
    if m[2]:find("^C1|Bergbau|") then c1 = c1 + 1 end
end
assert(c0 == 1 and c1 >= 2, "Rezepte in mehreren Stuecken")

-- 3) Ein Gildenmitglied teilt Schneiderei
S:Receive("ONECRF1", "C0|Schneiderei|60|75|1794400000", "GUILD", "Rehgar-Testrealm")
S:Receive("ONECRF1", "C1|Schneiderei|3914:4343,2385:2589", "GUILD", "Rehgar-Testrealm")
S:Receive("ONECRF1", "C0|Kochkunst|1|75|1794400000", "WHISPER", "Fremd-Testrealm") -- nur Gildenkanal
assert(R:Store().guild["Rehgar-Testrealm"].Schneiderei.recipes[3914] == 4343)
assert(not R:Store().guild["Fremd-Testrealm"])
-- Offline-Mitglied mit altem Stand
S:Receive("ONECRF1", "C0|Schneiderei|40|75|1794300000", "GUILD", "Saurfang-Testrealm")
S:Receive("ONECRF1", "C1|Schneiderei|3914:4343", "GUILD", "Saurfang-Testrealm")

-- 4) Seite: Suche "leinenhose" findet Rehgar (online) vor Offi (offline)
tabs.crafting()
local search
for _, r in ipairs(made) do if r.kind == "EditBox" then search = r end end
search.text = "leinenhose"
search.scripts["hook:OnTextChanged"]()
local rows = {}
for _, r in ipairs(made) do if r.kind == "Button" and r.cells and r.cells.item then rows[#rows + 1] = r end end
assert(rows[1].shown and rows[1].item.recipeID == 3914 and not rows[2].shown)
assert(rows[1].cells.item.text == "Schlichte Leinenhose")
local names, infos = {}, {}
for _, r in ipairs(made) do
    if r.kind == "FontString" and type(r.text) == "string" then
        if r.text == "Rehgar" then names.rehgar = r end
        if r.text == "Saurfang" then names.offi = r end
        if r.text:find("offline", 1, true) then infos.offline = r.text end
    end
end
assert(names.rehgar and names.offi and names.rehgar.point[5] > names.offi.point[5], "online zuerst")
assert(infos.offline and infos.offline:find("Stand", 1, true))
-- Anfragen oeffnet Fluesterfenster mit Text und Gegenstands-Link (Spieler sendet selbst)
local ask
for _, r in ipairs(made) do if r.kind == "Button" and r.text == "Anfragen" and r.shown then ask = r break end end
ask.scripts.OnClick(ask)
assert(opened[1] and opened[1]:find("^/w Rehgar%-Testrealm Hallo Rehgar") and opened[1]:find("Hitem:4343", 1, true))
assert(#sent == 0 or not sent[#sent][2]:find("Hallo"), "ONE sendet nie selbst Fluesternachrichten")

-- 5) Abmelden loescht die Daten
S:Receive("ONECRF1", "COFF", "GUILD", "Saurfang-Testrealm")
assert(not R:Store().guild["Saurfang-Testrealm"])
-- Alte Staende verfallen nach 30 Tagen, Ex-Mitglieder verschwinden
R:Store().guild["Rehgar-Testrealm"].Schneiderei.stamp = 1794477894 - 31 * 24 * 3600
R:Prune({["Testheld-Testrealm"] = true, ["Rehgar-Testrealm"] = true})
assert(not R:Store().guild["Rehgar-Testrealm"])
-- 6) Lehrer-Verzeichnis und "Wann zum Lehrer?"
local T = c.Trainers
GetProfessions = function() return 1, 2 end
GetProfessionInfo = function(i) if i == 1 then return "Kräuterkunde", 1, 52, 75 end return "Bergbau", 1, 24, 75 end
local due = T:Due(T:MyProfessions(), 19)
assert(due[1].ready and due[1].text == "Kräuterkunde: Geselle jetzt lernbar", due[1].text)
assert(not due[2].ready and due[2].text == "Bergbau: Geselle ab Fertigkeit 50")
assert(T:Due({X = {skill = 130, max = 150}}, 15)[1].text == "X: Experte ab Stufe 20")
-- Minimap "!" bei faelliger Ausbildung
local alert
ONE.MinimapButton = {SetAlert = function(_, r, t) alert = {r, t} end, ClearAlert = function() alert = nil end}
UnitLevel = function() return 19 end
c.CheckDue()
assert(alert and alert[1] == "crafting" and alert[2]:find("Kräuterkunde", 1, true))
-- Ansicht Lehrer: Grundliste sichtbar, unbestaetigt
R:Store().view = "trainers"
tabs.crafting()
local makaru
for _, r in ipairs(made) do if r.kind == "Button" and r.cells and r.cells.npc and r.item and r.item.npc == "Makaru" then makaru = r end end
assert(makaru and not makaru.item.confirmed and makaru.item.what == "Bergbau")
-- Allianz: eigene Grundliste, keine Horde-Lehrer
UnitFactionGroup = function() return "Alliance" end
local ally = T:All()
assert(#ally > 15, "Allianz-Lehrer fehlen")
for _, e in ipairs(ally) do assert(not e.area:find("Orgrimmar", 1, true), "Horde-Lehrer bei der Allianz: " .. e.npc) end
UnitFactionGroup = function() return "Horde" end
for _, e in ipairs(T:All()) do assert(not e.area:find("Sturmwind", 1, true), "Allianz-Lehrer bei der Horde: " .. e.npc) end
UnitFactionGroup = nil
-- Lehrer im Spiel ansprechen -> bestaetigt, mit Position, in der Gilde geteilt
UnitName = function(u) if u == "npc" then return "Makaru" end return "Testheld" end
C_TooltipInfo = {GetUnit = function() return {lines = {{leftText = "Makaru"}, {leftText = "Lehrer für Bergbau"}}} end}
GetNumTrainerServices = function() return 1 end
GetTrainerServiceInfo = function() return "Bergbau (Geselle)", "", "available" end
GetZoneText = function() return "Orgrimmar" end
C_Map = {GetBestMapForUnit = function() return 1454 end, GetPlayerMapPosition = function() return {x = .7312, y = .2655} end}
local e = T:CaptureCurrent()
assert(e.kind == "profession" and e.what == "Bergbau (Geselle)" and e.map == 1454 and e.x == .731)
local all = T:All()
local found
for _, x in ipairs(all) do if x.npc == "Makaru" then found = x end end
assert(found.confirmed and found.x == .731, "Fund ersetzt die Grundliste")
local before = #sent
S:SendTrainer(e)
S:Flush(10)
assert(sent[#sent][2]:find("^T|Makaru|profession|Bergbau %(Geselle%)|1454|0.731|"), sent[#sent][2])
-- Fund eines anderen Mitglieds
S:Receive("ONECRF1", "T|Neuer Lehrer|weapon|Waffenmeister|1456|0.4|0.6|Donnerfels", "GUILD", "Rehgar-Testrealm")
local neu
for _, x in ipairs(T:All()) do if x.npc == "Neuer Lehrer" then neu = x end end
assert(neu and neu.confirmed and neu.by == "Rehgar-Testrealm")
-- 0.4.9e: Blizzard-Filter versteckt alles (z. B. nur "verfuegbar" an) -> ONE erfasst trotzdem alles
local filter = {available = 1, unavailable = 0, used = 0}
local setCalls = 0
GetTrainerServiceTypeFilter = function(t) return filter[t] == 1 end
SetTrainerServiceTypeFilter = function(t, v) setCalls = setCalls + 1 filter[t] = v and v ~= 0 and 1 or 0 end
local skills = {{"Waffen", "", "header"}, {"Stäbe", "", "unavailable"}, {"Zweihandstreitkolben", "", "used"}}
local function Visible()
    local out = {}
    for _, s in ipairs(skills) do if s[3] == "header" or filter[s[3]] == 1 then out[#out + 1] = s end end
    return out
end
GetNumTrainerServices = function() return #Visible() end
GetTrainerServiceInfo = function(i) local s = Visible()[i] if s then return s[1], s[2], s[3] end end
UnitName = function(u) if u == "npc" then return "Ansekhwa" end return "Testheld" end
C_TooltipInfo = {GetUnit = function() return {lines = {{leftText = "Ansekhwa"}, {leftText = "Waffenmeisterin"}}} end}
assert(GetNumTrainerServices() == 1, "Ausgangslage: Filter versteckt die Waffen")
local w = T:CaptureCurrent()
assert(w.kind == "weapon" and w.count == 3, "Waffenmeister trotz Filter vollständig: " .. tostring(w.count))
assert(filter.available == 1 and filter.unavailable == 0 and filter.used == 0, "Filter zurückgestellt")
assert(setCalls == 4, "nur geänderte Filter angefasst: " .. setCalls)
GetTrainerServiceTypeFilter, SetTrainerServiceTypeFilter = nil, nil
-- 0.5.0 Datenschutz: Lehrer-Funde nur mit Freigabe, Finder-Name verfaellt, Widerruf entfernt ihn
local tstore = T:Store()
S:SetSharing(false)
local before050 = #sent
S:Flush(20)
before050 = #sent
assert(S:SendTrainer({npc = "Geheim", kind = "weapon", what = "x", area = "y"}) == false, "ohne Freigabe kein Lehrer-Fund")
S:Flush(20)
assert(#sent == before050, "ohne Freigabe nichts gesendet")
S:SetSharing(true)
S:Receive("ONECRF1", "T|Fundlehrer|weapon|Waffenmeister|1456|0.4|0.6|Donnerfels", "GUILD", "Saurfang-Testrealm")
assert(tstore["Fundlehrer"].by == "Saurfang-Testrealm")
S:Receive("ONECRF1", "COFF", "GUILD", "Saurfang-Testrealm")
assert(tstore["Fundlehrer"].by == nil and tstore["Fundlehrer"].npc == "Fundlehrer", "Widerruf entfernt nur den Namen")
S:Receive("ONECRF1", "T|Altlehrer|weapon|Waffenmeister|1456|0.4|0.6|Donnerfels", "GUILD", "Rehgar-Testrealm")
tstore["Altlehrer"].seen = R.Now() - 31 * 24 * 3600
R:Prune({["Testheld-Testrealm"] = true, ["Rehgar-Testrealm"] = true})
assert(tstore["Altlehrer"].by == nil and tstore["Altlehrer"].npc == "Altlehrer", "Finder-Name verfaellt nach 30 Tagen")
-- Aufraeumen laeuft beim Gildenlisten-Update wirklich
assert(type(c.PruneGuildData) == "function", "Aufraeumen nicht angebunden")
R:Store().guild["Weg-Testrealm"] = {Bergbau = {skill = 1, max = 75, stamp = R.Now(), recipes = {}}}
c.PruneGuildData()
assert(R:Store().guild["Weg-Testrealm"] == nil, "Ex-Mitglied beim Gildenlisten-Update geloescht")
print("OK: 0.5.0 - Datenschutz: Lehrer-Funde nur mit Freigabe, Namen verfallen, Aufraeumen aktiv")
print("OK: 0.4.9e - Lehrer: Blizzard-Filter beim Erfassen umgangen und zurückgestellt")
print("OK: 0.4.9b - Lehrer: faellige Ausbildung, Minimap-!, Grundliste, Erfassen, Teilen")
print("OK: 0.4.9a - Berufe: eigene Rezepte, Teilen mit Zustimmung, Suche, online zuerst, Anfragen, Verfall")
