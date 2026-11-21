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

-- Raid-Skillungen Stufe 60 (19.11.2026, vorlaeufig): Heiler und Tanks, je 51 Punkte, nur in der Situation Raid
do
    local raid = {}
    for _, cls in ipairs(expected) do for spec = 1, 3 do raid[#raid + 1] = {cls, spec} end end  -- alle 27
    for _, r in ipairs(raid) do
        local def = c.Data.classes[r[1]]
        local b = c.Data:Build(def, r[2], "raid")
        local solo = c.Data:Build(def, r[2], "solo")
        local sum, seen = 0, {}
        for _, step in ipairs(b.talents) do
            assert(not seen[step[1]], r[1] .. " " .. r[2] .. ": Talent doppelt " .. step[1])
            seen[step[1]] = true
            sum = sum + step[2]
        end
        assert(sum == 51, r[1] .. " " .. r[2] .. ": " .. sum .. " Punkte")
        assert(b.talentsNote and b.talentsNote:find("vorläufig"), r[1] .. " " .. r[2] .. ": als vorlaeufig gekennzeichnet")
        assert(solo.talents ~= b.talents and not solo.talentsNote, "Leveln behaelt seinen Plan")
    end
end
print("OK: Raid-Skillungen")

-- Stufen-Abschnitte beim Leveln (Nutzer 21.11.2026): Arkan-Magier ab Stufe 1
do
    local mage = c.Data.classes.MAGE
    local function Flow(level, situation) return c.Data:Build(mage, 1, situation, level).flow end
    assert(Flow(1):find("^Stufe 1–3"), "Stufe 1: erster Abschnitt")
    assert(Flow(9):find("^Stufe 4–9") and Flow(10):find("^Stufe 10–19"), "Grenzen der Abschnitte")
    assert(Flow(26):find("^Stufe 20–26") and Flow(27):find("^Ab Stufe 27"), "ab 27 der normale Ablauf")
    assert(Flow(15, "dungeon"):find("^Tank zieht zuerst"), "Dungeon ohne Stufen-Abschnitte")
    assert(c.Data:Build(mage, 1, nil, nil).flow:find("^Ab Stufe 27"), "ohne Stufe: normaler Ablauf")
    -- Abschnitte aufsteigend, jeder Text übersetzbar geprüft im Locale-Test
    for _, def in pairs(c.Data.classes) do
        for spec, b in pairs(def.build) do
            local last = 0
            for _, st in ipairs(b.stages or {}) do
                assert(st.upTo > last and type(st.flow) == "string", def.name .. " " .. spec .. ": Abschnitte aufsteigend")
                last = st.upTo
            end
        end
    end
    -- Frostblitz Rang 1 erst ab Stufe 27 (vorher der höchste Rang)
    assert(mage.build[1].bars[1].slots[1].exact == 27)
end
print("OK: Stufen-Abschnitte")
