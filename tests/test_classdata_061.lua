-- Offline-Test 0.6.0: Bauplaene aller Klassen sind vollstaendig und stimmig.
local root = arg[1] or "src"
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
for _, f in ipairs({"Data.lua", "DataClasses.lua", "Player.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
-- ParseStep aus der Seite (ohne die Seite aufzubauen)
local function Region() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Region() end
UIParent = Region()
assert(loadfile(root .. "/ONE_Classes/Page.lua"))("ONE_Classes", c)
local Parse = c.Page.ParseStep

local expected = {"PRIEST", "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PALADIN", "SHAMAN", "DRUID"}
-- je Leiste feste Plaetze + hoechstens 3 Talent-Plaetze (nur sichtbar, wenn gelernt)
local maxSlots = {[1] = 8, [2] = 8, [3] = 9}
local maxTalent = 3
local count = 0
for _, classFile in ipairs(expected) do
    local def = c.Data.classes[classFile]
    assert(def, "Bauplan fehlt: " .. classFile)
    assert(type(def.name) == "string" and #def.specs == 3, classFile .. ": Name und drei Ausrichtungen")
    assert(def.build[def.defaultSpec], classFile .. ": Standard-Ausrichtung")
    for spec = 1, 3 do
        for _, situation in ipairs({"solo", "dungeon", "raid"}) do
            local build = c.Data:Build(def, spec, situation)
            assert(build and build.flow and #build.stats == 3, classFile .. " " .. spec .. ": Ablauf und drei Werte")
            assert(#build.bars == 3, classFile .. " " .. spec .. ": drei Leisten")
            local seenBars = {}
            for _, bar in ipairs(build.bars) do
                assert(not seenBars[bar.bar], classFile .. ": Leiste doppelt")
                seenBars[bar.bar] = true
                local fixed, talent = 0, 0
                for _, step in ipairs(bar.slots) do
                    if step.talent then talent = talent + 1 else
                        assert(talent == 0, classFile .. ": Talent-Plaetze gehoeren ans Ende")
                        fixed = fixed + 1 end
                end
                assert(fixed >= 1 and fixed <= maxSlots[bar.bar], classFile .. ": Leiste " .. bar.bar .. " zu voll")
                assert(talent <= maxTalent, classFile .. ": zu viele Talent-Plaetze auf Leiste " .. bar.bar)
                assert(fixed + talent < c.Data.racePos, classFile .. ": Platz 12 ist fuer die Volksfaehigkeit")
                for _, step in ipairs(bar.slots) do
                    for _, id in ipairs(c.Data.Ids(step[1])) do
                        assert(type(id) == "number" and id > 0, classFile .. ": ungueltige Zauber-Nummer")
                    end
                    assert(type(step[2]) == "string" and step[2] ~= "", classFile .. ": Beschriftung fehlt")
                end
            end
            -- jede Zahl im Ablauf zeigt auf einen Platz von Leiste 1
            local bar1 = #build.bars[1].slots
            for token in (build.flow .. " · "):gmatch("(.-)%s*·%s*") do
                if token ~= "" then
                    local pos, label = Parse(token, bar1)
                    for _, n in ipairs(pos) do assert(n <= bar1, classFile .. ": Ablauf zeigt auf leeren Platz " .. n) end
                    assert(#pos > 0 or label ~= "", classFile .. ": leerer Ablauf-Schritt")
                    -- eine fuehrende Zahl, die kein Platz ist, waere ein Tippfehler im Ablauf
                    local lead = token:match("^(%d)%f[%D]")
                    if lead then assert(tonumber(lead) <= bar1, classFile .. " " .. spec .. ": '" .. token .. "' meint Platz " .. lead) end
                end
            end
        end
    end
    for _, b in ipairs(def.buffs or {}) do assert(type(b.ids) == "table" and #b.ids > 0, classFile .. ": Buff ohne Zauber") end
    assert(#(def.tips or {}) >= 1, classFile .. ": mindestens ein Tipp")
    count = count + 1
end
print("OK test_classdata_061 (" .. count .. " Klassen)")

-- Talent-Plaetze erscheinen erst, wenn das Talent gelernt ist
do
    local bars = c.Data.classes.MAGE.build[3].bars
    local n = 0
    for _, step in ipairs(bars[1].slots) do if step.talent then n = n + 1 end end
    assert(n == 2 and #bars[1].slots == 10, "Frost: Eislanze und Kaelteeinbruch als Talent-Plaetze 9 und 10")
end
print("OK: Talent-Plaetze")

-- Volksfaehigkeiten: je Leiste ein Platz, Tipps zeigen auf einen Volkszauber
do
    for bar = 1, 3 do assert(c.Data.raceSlots[bar] and #c.Data.raceSlots[bar][1] >= 2, "Volksplatz Leiste " .. bar) end
    assert(#c.Data.raceTips >= 5)
    for _, tip in ipairs(c.Data.raceTips) do assert(type(tip[1]) == "number" and tip[2] ~= "") end
end
print("OK: Volksfaehigkeiten")
