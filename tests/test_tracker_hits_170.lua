-- Offline-Test: Kasten blendet ueberzaehlige Zeilen aus, auch wenn Klickflaechen Luecken haben (Spieltest 24.11.2026:
-- Lua-Fehler Tracker.lua "attempt to index field '?' (a nil value)" – self.hits hatte Luecken, # zaehlte darueber)
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local hidden = 0
local function Stub()
    return setmetatable({}, {__index = function(t, k)
        if k == "Hide" then return function() hidden = hidden + 1 end end
        return function() end
    end})
end
CreateFrame = function() return Stub() end
UIParent = Stub()
UnitName = function() return "Testheld" end
_G.ProjectONE = {db = {}, modules = {}, ns = {}, Print = function() end}
GuildTripQuestDB = {q = {}, n = {}}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Tracker.lua"))("ONE_Leveling", lev)
local Tr = lev.Tracker
-- Lage wie im Spiel: 5 Zeilen, Klickflaechen nur bei Zeile 1 und 4 (Luecken bei 2, 3, 5)
Tr.lines = {Stub(), Stub(), Stub(), Stub(), Stub()}
Tr.rights = {Stub(), Stub(), Stub(), Stub(), Stub()}
Tr.hits = {[1] = Stub(), [4] = Stub()}
-- genau die Ausblend-Schleife aus Tr:Update (bei 2 Zeilen): darf nicht an der Luecke scheitern
local src = assert(io.open(root .. "/ONE_Leveling/Tracker.lua")):read("*a")
assert(not src:find("#(self.hits or {}) do self.hits[i]:Hide()", 1, true), "alte Schleife ueber # ist weg")
local rows = {{}, {}}
local self = Tr
for _, list in ipairs({self.lines, self.rights or {}, self.hits or {}}) do
    for i, w in pairs(list) do if type(i) == "number" and i > #rows and w.Hide then w:Hide() end end
end
assert(hidden == 3 + 3 + 1, "ausgeblendet: " .. hidden)
assert(src:find("for i, w in pairs(list) do if type(i) == \"number\" and i > #rows and w.Hide then w:Hide() end end", 1, true), "Tracker nutzt die sichere Schleife")
print("OK test_tracker_hits_170")
