-- Offline-Test 0.5.5: Testwerkzeuge liegen im Entwickler-Addon ONE_Dev.
-- Alte Testdaten verlassen die Spieler-Datei, die Hilfe zeigt keine Testbefehle,
-- das CurseForge-Paket enthaelt ONE_Dev nicht.
local root = arg[1] or "src"
local function Frame()
    return {RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end}
end
CreateFrame = function() return Frame() end
SlashCmdList = {}
local out = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) out[#out + 1] = m end}

local ONE = {}
assert(loadfile(root .. "/ONE_Core/Core.lua"))("ONE_Core", ONE)
ProjectONEDB = {spellCatalog = {big = true}, navDiag = {1}, combatProbe = {}, theme = {selected = "forever"},
    crafting = {mine = {Bergbau = {}}}}
local stub = {Initialize = function() end}
ONE.Themes, ONE.Notifications, ONE.UI, ONE.Welcome = stub, stub, stub, stub
ONE:Initialize()

-- 1) Spieler-Datei: Testdaten raus, echte Daten bleiben
assert(ProjectONEDB.spellCatalog == nil and ProjectONEDB.navDiag == nil and ProjectONEDB.combatProbe == nil)
assert(ProjectONEDB.theme.selected == "forever" and ProjectONEDB.crafting.mine.Bergbau, "Spielerdaten bleiben")
assert(ONE.legacyDev.spellCatalog.big, "fuer ONE_Dev zwischengemerkt")

-- 2) ONE_Dev uebernimmt sie in die eigene Datei
assert(loadfile(root .. "/ONE_Dev/Dev.lua"))("ONE_Dev", {})
local db = ONE:DevDB()
assert(db == GuildTripDevDB and db.spellCatalog.big and db.navDiag[1] == 1 and ONE.legacyDev == nil)
assert(ONE:DevDB() == db, "nur einmal umziehen")

-- 3) Hilfe ohne Testbefehle; Testbefehle sind nicht mehr fest eingebaut
SlashCmdList.PROJECTONE("hilfe")
local help = table.concat(out, "\n")
assert(help:find("/trip bug", 1, true) and not help:find("navdiag", 1, true) and not help:find("/trip test", 1, true))
assert(ONE:RegisterSlash("test", function() end), "test ist frei fuer ONE_Dev")

-- 4) Ladelisten und Pakete
local core = assert(io.open(root .. "/ONE_Core/ONE_Core.toc")):read("*a")
assert(not core:find("SpellScan", 1, true) and not core:find("Native", 1, true) and not core:find("ClassSpells", 1, true))
for _, addon in ipairs({"ONE_Nav", "ONE_Dungeons", "ONE_Crafting"}) do
    local toc = assert(io.open(root .. "/" .. addon .. "/" .. addon .. ".toc")):read("*a")
    assert(not toc:find("Diagnostics", 1, true), addon .. " laedt kein Testwerkzeug")
end
local dev = assert(io.open(root .. "/ONE_Dev/ONE_Dev.toc")):read("*a")
assert(dev:find("## SavedVariables: GuildTripDevDB", 1, true) and dev:find("## Interface: 16001", 1, true))
local build = assert(io.open(root .. "/../scripts/build_release_windows.py")):read("*a")
assert(build:find("'ONE_Classes'", 1, true) and not build:find("ONE_Dev", 1, true), "ONE_Dev nicht im Paket")
local install = assert(io.open(root .. "/../scripts/install-forever.sh")):read("*a")
assert(install:find("ONE_Dev", 1, true), "lokal wird ONE_Dev installiert")
assert(install:find("[w]ow.exe", 1, true) and install:find("exit 5", 1, true), "Installieren bricht ab, solange WoW laeuft")
print("OK test_dev_055")
