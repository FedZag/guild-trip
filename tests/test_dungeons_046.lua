-- Offline-Test: Dungeon-Probe (0.4.6a). Echte Daten gibt es nur im Spiel.
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
GetServerTime = function() return 1 end
GetBuildInfo = function() return "1.60.1", "70862", "Nov 6 2026", 16001 end
UnitLevel = function() return 16 end
GetLFDChoiceOrder = function() return {-1, 4, 10, -2, 6} end
GetLFGDungeonInfo = function(id) return "Dungeon" .. id, 1, 1, 13, 18, 15, 13, 18, 0 end
C_LFGList = {
    GetAvailableActivities = function(cat) assert(cat == 2) return {301, 302} end,
    GetActivityInfoTable = function(id) return {fullName = "Hall of Thanes " .. id, minLevel = 13, mapID = 3065} end,
}
C_EncounterJournal = {GetDungeonEntrancesForMap = function(map)
    if map == 1411 then return {{name = "Ragefireabgrund", journalInstanceID = 226, position = {x = .5, y = .4}}} end
    return {}
end}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return id == 865 end,
    GetTitleForQuestID = function(id) if id == 1491 then return "Smart Drinks" end end,
    GetQuestsOnMap = function() return {{questID = 1}} end,
}
C_Map = {GetBestMapForUnit = function() return 1413 end}
C_QuestLine = {
    RequestQuestLinesForMap = function() end,
    GetAvailableQuestLines = function() return {{questLineName = "Kette", questName = "Start", questLineID = 7, questID = 99, x = .3, y = .2}} end,
    GetQuestLineQuests = function(id) assert(id == 7) return {99, 100} end,
}
local ONE = {db = {}, slash = {}}
function ONE:Print(m) printed[#printed + 1] = m end
function ONE:IsEnabled() return true end
function ONE:RegisterSlash(n, fn) self.slash[n] = fn end
function ONE:RegisterModule(_, def) def.Initialize(def) end
_G.ProjectONE = ONE
local d = {}
local toc = assert(io.open(root .. "/ONE_Dungeons/ONE_Dungeons.toc")):read("*a")
assert(toc:find("## Interface: 16001", 1, true) and toc:find("## Dependencies: ONE_Core", 1, true))
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Dungeons/" .. name))("ONE_Dungeons", d) end
assert(loadfile(root .. "/ONE_Dev/DungeonDiag.lua"))("ONE_Dev", {})
ONE.slash.dungeondiag("")
local r = ONE.db.dungeonDiag
assert(#r.finder.list == 3 and r.finder.list[1].id == 4 and r.finder.list[1].values[1] == "Dungeon4")
assert(r.finder.list[1].values[4] == 13, "Stufen werden gespeichert")
assert(#r.activities.list == 2 and r.activities.list[1].info.mapID == 3065)
assert(r.entrances[1].map == 1411 and r.entrances[1].list[1].name == "Ragefireabgrund" and r.entrances[1].list[1].x == .5)
local s = r.quests.samples
assert(s[1].id == 1491 and s[1].title == "Smart Drinks" and s[2].done == true)
assert(r.quests.apis.flagged and not r.quests.apis.tagInfo)
assert(r.givers.map == 1413 and r.givers.linesTotal == 1 and r.givers.lines[1].questID == 99)
assert(r.givers.firstLineQuests[2] == 100 and r.givers.questsOnMap == 1)
assert(table.concat(printed, "\n"):find("3 Dungeons", 1, true))
-- Ohne jede Schnittstelle: kein Absturz
GetLFDChoiceOrder, C_LFGList, C_EncounterJournal, C_QuestLog, C_QuestLine = nil, nil, nil, nil, nil
ONE.slash.dungeondiag("")
assert(ONE.db.dungeonDiag.finder.status == "FEHLT" and #ONE.db.dungeonDiag.finder.list == 0)
print("OK: 0.4.6a - Dungeon-Probe: Gruppensuche, Durchsuchen, Eingaenge, Quest-Schnittstellen")
