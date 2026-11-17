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
    function r:SetWidth(w) self.w = w end -- wie im Spiel: Textbreite zaehlt beim Ueberlappungs-Test
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
GetServerTime = function() return 1 end

UnitLevel = function() return 16 end
UnitFactionGroup = function() return "Horde" end
UnitClass = function() return "Priester", "PRIEST" end
local requested = {}
local titles = {[5761] = "Erlegt das Untier"}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return id == 5761 or id == 5726 end,
    GetLogIndexForQuestID = function(id) if id == 5725 then return 3 end end,
    GetTitleForQuestID = function(id) return titles[id] end,
    RequestLoadQuestByID = function(id) requested[#requested + 1] = id end,
}
C_LFGList = {GetActivityInfoTable = function(id)
    if id == 798 then return {fullName = "Ragefireabgrund", minLevelSuggestion = 13, maxLevelSuggestion = 18} end
    if id == 805 then return {fullName = "SM Friedhof", minLevelSuggestion = 30, maxLevelSuggestion = 38} end
    if id == 828 then return {fullName = "SM Kathedrale", minLevelSuggestion = 38, maxLevelSuggestion = 46} end
end}
local pointed
local sent, notified, invited, whispered = {}, {}, {}, {}
IsInGuild = function() return true end
UnitFullName = function() return "Testheld", "Testrealm" end
GetTime = function() return NOW or 1000 end
NOW = 1000
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel, target) sent[#sent + 1] = {prefix, msg, channel, target} return true end}
C_PartyInfo = {InviteUnit = function(name) invited[#invited + 1] = name end}
ChatFrame_SendTell = function(name) whispered[#whispered + 1] = name end
local ONE = {db = {}, modules = {}, slash = {}}
function ONE:Print() end
function ONE:Notify(m, o) notified[#notified + 1] = m ONE.lastNotifyOpts = o return true end
local alerts = {}
ONE.MinimapButton = {SetAlert = function(_, reason, text, tab) alerts[#alerts + 1] = {reason, text, tab} end}
local guildChat = {}
SendChatMessage = function(text, channel) guildChat[#guildChat + 1] = {text, channel} end
function ONE:IsEnabled() return true end
function ONE:RegisterSlash(n, fn) self.slash[n] = fn end
function ONE:RegisterModule(id, def) self.modules[id] = def def.Initialize(def) end
ONE.modules.nav = {PointTo = function(_, label, map, x, y) pointed = {label, map, x, y} return true end}
local tabs = {}
ONE.UI = {Layout = {width = 726}, activeTab = "dungeons", frame = UIParent,
    AddTab = function(_, id, _, builder) tabs[id] = builder(Region("Frame")) return true end,
    OpenLink = function(_, id) ONE.opened = id end}
_G.ProjectONE = ONE
for _, f in ipairs({"Themes.lua", "Kit.lua", "Geometry.lua", "Widgets.lua"}) do
    assert(loadfile(root .. "/ONE_Core/" .. f))("ONE_Core", ONE)
end
ONE.Themes:Initialize()
local d = {}
local toc = assert(io.open(root .. "/ONE_Dungeons/ONE_Dungeons.toc")):read("*a")
assert(toc:find("## OptionalDeps: ONE_Nav", 1, true))
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Dungeons/" .. name))("ONE_Dungeons", d) end
local S, M = d.Share, d.Model
assert(S and d.Groups and tabs.dungeons and not tabs.groups, "Gruppen sind eine Ansicht im Reiter Dungeons")
tabs.groups = function() d.Page:ShowView("groups") end
local function Last() return sent[#sent] and sent[#sent][2] end

-- 1) Teilen ist aus, bis man es einschaltet; danach P0/P1 an die Gilde
assert(not S:IsSharing())
local before = #sent
S:SendProgress()
assert(#sent == before, "ohne Zustimmung wird nichts gesendet")
S:SetSharing(true)
assert(S:IsSharing() and ONE.db.dungeons.shareChars["Testheld-Testrealm"])
local p0, p1
for i = before + 1, #sent do
    local msg = sent[i][2]
    assert(sent[i][1] == "ONEGRP1" and sent[i][3] == "GUILD" and #msg <= 255)
    if msg:find("^P0|") then p0 = msg end
    if msg:find("^P1|rfc|") then p1 = msg end
end
assert(p0 == "P0|16|PRIEST", tostring(p0))
assert(p1 and p1:find("5723", 1, true) and not p1:find("5761", 1, true), "nur offene Quests: " .. tostring(p1))

-- 2) Ein anderes Mitglied (Boo) teilt seinen Stand
S:Receive("ONEGRP1", "P0|14|DRUID", "GUILD", "Garona-Testrealm")
S:Receive("ONEGRP1", "P1|rfc|5723,5728", "GUILD", "Garona-Testrealm")
S:Receive("ONEGRP1", "P1|rfc|9999", "GUILD", "Testheld-Testrealm") -- eigene Nachricht ignorieren
local needers = S:Needers("rfc")
assert(#needers == 1 and needers[1].name == "Garona-Testrealm" and needers[1].level == 14 and needers[1].open == 2)
local q5723
for _, x in ipairs(M:Dungeons()) do if x.key == "rfc" then for _, q in ipairs(x.quests) do if q.ids[1] == 5723 then q5723 = q end end end end
assert(#S:QuestNeeders("rfc", q5723) == 1)
-- Dungeonseite zeigt Spalte GILDE und "Auch offen bei"
tabs.dungeons()
local line
for _, r in ipairs(made) do if r.kind == "FontString" and type(r.text) == "string" and r.text:find("Auch offen bei", 1, true) then line = r.text end end
assert(line and line:find("Garona", 1, true) and line:find("(14)", 1, true), tostring(line))
local gildeCell
for _, r in ipairs(made) do if r.kind == "Button" and r.cells and r.cells.guild and r.item and r.item.key == "rfc" then gildeCell = r.cells.guild.text end end
assert(gildeCell == "1", "Spalte GILDE: " .. tostring(gildeCell))
-- Abmelden entfernt Boo
S:Receive("ONEGRP1", "POFF", "GUILD", "Garona-Testrealm")
assert(#S:Needers("rfc") == 0)

-- 3) Fremdes Gesuch fuer einen passenden Dungeon -> Hinweis; unpassend -> kein Hinweis
S:Receive("ONEGRP1", "GA|boo1|rfc|H,D|2|5|Treffpunkt Orgrimmar", "GUILD", "Garona-Testrealm")
assert(#notified == 1 and notified[1]:find("Ragefireabgrund", 1, true))
S:Receive("ONEGRP1", "GA|rehgar1|scholo|T|1|5|", "GUILD", "Rehgar-Testrealm")
assert(#notified == 1, "kein Hinweis fuer unpassende Stufe")
assert(ONE.lastNotifyOpts.toast == false, "nur Chatzeile, kein Hinweisfenster")
assert(alerts[#alerts][1] == "groups" and alerts[#alerts][3] == "groups", "Ausrufezeichen an der Minimap")
-- Hoeherstufige duerfen mit (Ausruestung/Helfen), auch ohne offene Quests
UnitLevel = function() return 30 end
local countBefore = #notified
S:Receive("ONEGRP1", "GA|boo2|rfc|D|2|5|", "GUILD", "Garona-Testrealm")
assert(#notified == countBefore + 1, "Stufe 30 wird fuer RFC (13-18) trotzdem benachrichtigt")
local canJoin, _, over = S:Fit(S.ads.boo2)
assert(canJoin and over)
-- ohne offene Quests lautet der Hinweis "Ausruestung oder Helfen"
local realDone = C_QuestLog.IsQuestFlaggedCompleted
C_QuestLog.IsQuestFlaggedCompleted = function() return true end
S.ads.boo2 = nil
S:Receive("ONEGRP1", "GA|boo3|rfc|D|2|5|", "GUILD", "Garona-Testrealm")
assert(notified[#notified]:find("Ausrüstung", 1, true), notified[#notified])
C_QuestLog.IsQuestFlaggedCompleted = realDone
S.ads.boo3 = nil
UnitLevel = function() return 16 end
S.ads.boo2 = nil
local ads = S:Ads()
assert(#ads == 2 and ads[1].gid == "boo1", "passende Gesuche zuerst")
-- Reiter Gruppen: Gesuch auswaehlen und "Ich bin dabei"
tabs.groups()
local joinBtn
for _, r in ipairs(made) do if r.kind == "Button" and type(r.text) == "string" and r.text:find("^Ich bin dabei") then joinBtn = r end end
assert(joinBtn and joinBtn.text == "Ich bin dabei (Schaden)")
joinBtn.scripts.OnClick(joinBtn)
local j = sent[#sent]
assert(j[2] == "GJ|boo1|D|16|PRIEST" and j[3] == "WHISPER" and j[4] == "Garona-Testrealm")
-- Gesuch geschlossen (nur vom Besitzer)
S:Receive("ONEGRP1", "GC|boo1", "GUILD", "Fremder-Testrealm")
assert(S.ads.boo1, "nur der Besitzer darf schliessen")
S:Receive("ONEGRP1", "GC|boo1", "GUILD", "Garona-Testrealm")
assert(not S.ads.boo1)
-- Abgelaufene Gesuche verschwinden
NOW = NOW + 400
assert(#S:Ads() == 0)

-- 4) Eigenes Gesuch ueber den Dialog der Dungeonseite
local dlg = d.Page:OpenSeekDialog({key = "rfc", name = "Ragefireabgrund"})
assert(dlg.parent == UIParent, "Dialog liegt ueber dem ONE-Fenster, nicht darin")
dlg.roles.H.checked = true
dlg.note.text = "noch | Heiler"
local post
for _, r in ipairs(made) do if r.kind == "Button" and r.text == "Gesuch aufgeben" then post = r end end
post.scripts.OnClick(post)
assert(S.myAd and S.myAd.key == "rfc" and S.myAd.roles == "H" and S.myAd.note == "noch   Heiler", "Notiz ohne Trennzeichen")
assert(Last():find("^GA|" .. S.myAd.gid .. "|rfc|H|1|5|"))
assert(ONE.opened == "groups")
-- Gesuch im Gildenchat (erreicht auch Mitglieder ohne ONE)
tabs.groups()
local postBtn
for _, r in ipairs(made) do if r.kind == "Button" and r.text == "Im Gildenchat posten" and r.shown then postBtn = r end end
assert(postBtn, "Knopf Gildenchat fehlt beim eigenen Gesuch")
postBtn.scripts.OnClick(postBtn)
assert(guildChat[1] and guildChat[1][2] == "GUILD" and guildChat[1][1]:find("Ragefireabgrund", 1, true)
    and guildChat[1][1]:find("Heiler", 1, true) and not guildChat[1][1]:find("|", 1, true))
-- Meldung trifft ein -> Hinweis + Einladen/Anfluestern
S:Receive("ONEGRP1", "GJ|" .. S.myAd.gid .. "|H|15|PALADIN", "WHISPER", "Zuljin-Testrealm")
assert(notified[#notified]:find("Zuljin", 1, true))
tabs.groups()
local inviteBtn, tellBtn
for _, r in ipairs(made) do
    if r.kind == "Button" and r.text == "Einladen" and r.shown then inviteBtn = r end
    if r.kind == "Button" and r.text == "Anflüstern" and r.shown then tellBtn = r end
end
-- Keine zwei sichtbaren Textzeilen derselben Karte duerfen sich ueberlappen
local byParent = {}
for _, r in ipairs(made) do
    if r.kind == "FontString" and type(r.text) == "string" and r.text ~= "" and r.point and r.point[1] == "TOPLEFT"
        and type(r.point[4]) == "number" and type(r.point[5]) == "number" and r.parent then
        byParent[r.parent] = byParent[r.parent] or {}
        table.insert(byParent[r.parent], r)
    end
end
for _, list in pairs(byParent) do
    for i = 1, #list do for k = i + 1, #list do
        local a, b = list[i], list[k]
        local ax, bx = a.point[4], b.point[4]
        local overlapX = ax < bx + (b.w or 100) and bx < ax + (a.w or 100)
        if overlapX and a.shown ~= false and b.shown ~= false then
            local function Lines(t) local n = 1 for _ in t:gmatch("\n") do n = n + 1 end return n end
            local aTop, bTop = a.point[5], b.point[5]
            local aBottom, bBottom = aTop - 16 * Lines(a.text), bTop - 16 * Lines(b.text)
            assert(aBottom >= bTop or bBottom >= aTop,
                "Text ueberlappt: '" .. a.text:sub(1, 30) .. "' / '" .. b.text:sub(1, 30) .. "'")
        end
    end end
end
inviteBtn.scripts.OnClick(inviteBtn)
tellBtn.scripts.OnClick(tellBtn)
assert(invited[1] == "Zuljin-Testrealm" and whispered[1] == "Zuljin-Testrealm")
-- Gesuch endet nach 30 Minuten automatisch
NOW = NOW + 1900
S:BroadcastAd()
assert(S.myAd == nil and Last():find("^GC|"), "Gesuch nach 30 Minuten geschlossen")
-- Ausschalten sendet POFF
S:SetSharing(false)
assert(Last() == "POFF" and not S:IsSharing())
print("OK: 0.4.7a - Gruppenfinder: Teilen mit Zustimmung, Gilden-Bedarf, Gesuche, Dabei, Einladen, Ablauf")
