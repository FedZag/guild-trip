-- Offline-Test 0.6.0: Sprachen (Deutsch im Code, Englisch ueber ONE.EN).
local root = arg[1] or "src"
local locale = "enUS"
GetLocale = function() return locale end
local ONE = {db = {}}
_G.ProjectONE = ONE
assert(loadfile(root .. "/ONE_Core/Locale.lua"))("ONE_Core", ONE)
assert(loadfile(root .. "/ONE_Core/Locale_enUS.lua"))("ONE_Core", ONE)
assert(loadfile(root .. "/ONE_Classes/Locale_enUS.lua"))("ONE_Classes", {})
assert(loadfile(root .. "/ONE_Guild/Locale_enUS.lua"))("ONE_Guild", {})
assert(loadfile(root .. "/ONE_Nav/Locale_enUS.lua"))("ONE_Nav", {})
assert(loadfile(root .. "/ONE_Dungeons/Locale_enUS.lua"))("ONE_Dungeons", {})
assert(loadfile(root .. "/ONE_Crafting/Locale_enUS.lua"))("ONE_Crafting", {})
assert(loadfile(root .. "/ONE_Chat/Locale_enUS.lua"))("ONE_Chat", {})
local T = ONE.T

-- 1) Automatisch nach Spielsprache
assert(ONE:Language() == "en" and T("Kalender") == "Calendar")
locale = "deDE"
assert(ONE:Language() == "de" and T("Kalender") == "Kalender")
-- 2) Auswahl in den Optionen gewinnt
ONE.db.language = "en"
assert(T("Kalender") == "Calendar" and T("Stufe %d", 20) == "Level 20")
assert(T("%s · Stufe %d", T("Priester"), 20) == "Priest · level 20")
ONE.db.language = "de"
locale = "enUS"
assert(T("Kalender") == "Kalender" and T("Stufe %d", 20) == "Stufe 20")
-- 3) Fehlende Uebersetzung: deutscher Text bleibt, Platzhalter werden gefuellt
ONE.db.language = "en"
assert(T("Gibt es nicht %d", 3) == "Gibt es nicht 3")
assert(T(nil) == nil and T(42) == 42)

-- 4) Vollstaendigkeit: jeder T("...")-Text in bereits uebersetzten Dateien hat Englisch,
--    und Platzhalter stimmen ueberein.
local done = {
    "ONE_Core/UI.lua", "ONE_Core/Welcome.lua", "ONE_Core/WhatsNew.lua", "ONE_Core/MinimapButton.lua", "ONE_Core/Core.lua",
    "ONE_Classes/Page.lua", "ONE_Classes/Bars.lua", "ONE_Classes/Ranks.lua", "ONE_Classes/Share.lua", "ONE_Classes/Buffs.lua", "ONE_Classes/Nearby.lua", "ONE_Classes/Init.lua", "ONE_Classes/Talents.lua", "ONE_Classes/Trainer.lua", "ONE_Classes/Gear.lua", "ONE_Classes/Loot.lua",
    "ONE_Guild/UI.lua", "ONE_Guild/Calendar.lua", "ONE_Guild/Pins.lua", "ONE_Guild/Reminders.lua",
    "ONE_Guild/Roster.lua", "ONE_Guild/Presence.lua", "ONE_Guild/Guild.lua",
    "ONE_Nav/Arrow.lua", "ONE_Nav/Flights.lua", "ONE_Nav/Page.lua", "ONE_Nav/Travel.lua", "ONE_Nav/Init.lua", "ONE_Nav/Quests.lua", "ONE_Nav/QuestShare.lua", "ONE_Nav/QuestPins.lua", "ONE_Nav/Merchants.lua", "ONE_Nav/Waypoints.lua", "ONE_Nav/QuestDB.lua", "ONE_Nav/QuestGivers.lua", "ONE_Nav/Routes.lua", "ONE_Nav/RouteDots.lua",
    "ONE_Dungeons/Page.lua", "ONE_Dungeons/Groups.lua", "ONE_Dungeons/Share.lua", "ONE_Dungeons/Trips.lua", "ONE_Dungeons/TripsPage.lua", "ONE_Dungeons/TripsPlanner.lua", "ONE_Dungeons/Entrances.lua",
    "ONE_Crafting/Page.lua", "ONE_Crafting/Trainers.lua", "ONE_Crafting/Recipes.lua", "ONE_Crafting/Init.lua",
    "ONE_Chat/Chat.lua", "ONE_Chat/ChatUI.lua", "ONE_Chat/TabEditor.lua", "ONE_Chat/Settings.lua", "ONE_Chat/Launcher.lua", "ONE_Chat/Hider.lua", "ONE_Chat/LootWindow.lua", "ONE_Chat/Init.lua",
}
local bilingual = {["Sprache / Language"] = true, ["Automatisch / Automatic"] = true, ["Deutsch"] = true,
    ["English"] = true, ["Guild Trip"] = true, ["Guild Trip Test"] = true, ["Dungeons"] = true}
local missing = {}
local function Check(text, where)
    if bilingual[text] then return end
    local en = ONE.EN[text]
    if not en then missing[#missing + 1] = where .. ": " .. text return end
    local a, b = select(2, text:gsub("%%[%d%.]*[sd]", "")), select(2, en:gsub("%%[%d%.]*[sd]", ""))
    assert(a == b, "Platzhalter passen nicht: " .. text)
end
for _, file in ipairs(done) do
    local src = assert(io.open(root .. "/" .. file)):read("*a")
    src = src:gsub("%-%-[^\n]*", "")
    for text in src:gmatch('T%("([^"]+)"[,)]') do Check((text:gsub("\\n", "\n")), file) end
    for a, b in src:gmatch('T%("([^"]+)"%s*%.%.%s*"([^"]+)"%)') do Check(((a .. b):gsub("\\n", "\n")), file) end
end
-- Spaltentitel, Kacheln, Modulnamen und die Lehrer-Grundliste (werden beim Anzeigen uebersetzt)
for _, addon in ipairs({"ONE_Core", "ONE_Guild", "ONE_Nav", "ONE_Dungeons", "ONE_Crafting", "ONE_Classes", "ONE_Chat"}) do
    local toc = assert(io.open(root .. "/" .. addon .. "/" .. addon .. ".toc")):read("*a")
    for name in toc:gmatch("\n([%w_]+%.lua)") do
        -- Startpakete (…Pack.lua) enthalten Spieldaten aus dem Client, keine Oberflaechentexte
        if name ~= "Locale_enUS.lua" and not name:match("Pack%.lua$") then
            local src = assert(io.open(root .. "/" .. addon .. "/" .. name)):read("*a")
            for text in src:gmatch('title%s*=%s*"([^"]+)"') do Check(text, addon .. "/" .. name .. " title") end
            for text in src:gmatch('what = "([^"]+)"') do Check(text, addon .. "/" .. name .. " what") end
            for text in src:gmatch('area = "([^"]+)"') do Check(text, addon .. "/" .. name .. " area") end
        end
    end
end
for _, name in pairs({"Leveln", "Dungeon", "Raid"}) do Check(name, "Situationsnamen") end
-- Bauplaene: Beschriftungen, Ausrichtungen, Werte, Ablauf, Tipps
local c = {}
assert(loadfile(root .. "/ONE_Classes/Data.lua"))("ONE_Classes", c)
assert(loadfile(root .. "/ONE_Classes/DataClasses.lua"))("ONE_Classes", c)
for _, def in pairs(c.Data.classes) do
    Check(def.name, "Data")
    for _, spec in ipairs(def.specs) do Check(spec, "Data") end
    for _, build in pairs(def.build) do
        if build.flow then Check(build.flow, "Data") end
        for _, stat in ipairs(build.stats or {}) do Check(stat, "Data") end
        for _, sit in pairs(build.situations or {}) do
            if sit.flow then Check(sit.flow, "Data situation") end
            for _, stat in ipairs(sit.stats or {}) do Check(stat, "Data situation") end
        end
        for _, bar in ipairs(build.forms or {}) do
            Check(bar.title, "Data forms") Check(bar.flow, "Data forms")
            for _, step in ipairs(bar.slots) do Check(step[2], "Data forms") end
        end
        for _, bar in ipairs(build.bars or {}) do
            Check(bar.title, "Data")
            for _, step in ipairs(bar.slots) do Check(step[2], "Data") end
        end
    end
    for _, tip in ipairs(def.tips or {}) do Check(tip[2], "Data") end
    for _, tip in ipairs(c.Data.raceTips or {}) do Check(tip[2], "Data") end
    for _, tip in ipairs(c.Data.raceTipsByRace or {}) do Check(tip.text, "Data race") end
end
assert(#missing == 0, "ohne Englisch:\n" .. table.concat(missing, "\n"))
print("OK test_locale_057 (" .. ONE:TranslationCount() .. " Texte auf Englisch)")
