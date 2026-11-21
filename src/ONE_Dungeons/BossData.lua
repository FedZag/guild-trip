-- ERZEUGT mit scripts/import_codex.lua – nicht von Hand aendern.
-- Bosse und Beute aus "Dungeon Codex" 1.4 von Baxter x DLDVLPR (CurseForge-Projekt 1715265).
-- Dungeon Codex steht unter GPL-2.0; Nutzung dieser Boss-/Beute-Daten in Guild Trip unter
-- GPL-3.0-or-later ausdruecklich erlaubt vom Autor am 19.11.2026 (docs/ANFRAGEN_DATEN.md, THIRD_PARTY.md).
local _, dungeons = ...

dungeons.BossData = {
    source = {name = "Dungeon Codex", author = "Baxter x DLDVLPR", version = "1.4", license = "GPL-2.0, Daten mit Erlaubnis unter GPL-3.0-or-later", url = "https://www.curseforge.com/wow/addons/dungeon-codex"},
    thanes = {
        {npc = 261306, name = "Faldrim Anvilmar", items = {270227, 271096, 271097}},
        {npc = 261316, name = "Magmatus", items = {270230, 270231, 271095}},
        {npc = 261311, name = "Plunder", de = "Schleppweg", items = {270228, 270229, 271098}},
        {npc = 261319, name = "Durgen Dirgehammer", items = {270256, 270260, 270261, 274286}},
    },
    ruins = {
        {npc = 250483, name = "Witherfang", de = "Welkzahn", level = 17, items = {271201, 271202, 271203}},
        {npc = 250631, name = "The Abandoned", de = "Der Verlassene", level = 18, items = {271207, 271208, 271216}},
        {npc = 250660, name = "The Baron", de = "Der Baron", level = 17, items = {271204, 271205, 271206}},
        {npc = 250657, name = "Rath'mael", level = 20, items = {271213, 271214, 271215, 273085, 273103}},
        {npc = 255699, name = "Lordaeron Captain", de = "Hauptmann von Lordaeron", level = 19, rare = true, items = {6641, 6642}},
        {npc = 256035, name = "Viktor the Vile", de = "Viktor der Üble", level = 19, items = {271211, 271212, 271218}},
        {npc = 256097, name = "Bjork", level = 19, items = {271209, 271210, 271217}},
    },
    excavation = {
        {npc = 260322, name = "Saltspine", de = "Salzrücken", level = 28, items = {273022, 273023, 273024}},
        {npc = 260325, name = "Shadetooth", de = "Schemenzahn", level = 29, items = {273025, 273026, 273027, 273106}},
        {npc = 260808, name = "Highland Horror", de = "Hochlandschrecken", level = 28, items = {270180}},
        {npc = 260326, name = "Relic Guardian", de = "Reliktwächter", level = 31, items = {273028, 273030, 270865, 273029, 273097}},
    },
    dalaran = {
        {npc = 247126, name = "Atrexis the Grave Knight", de = "Atrexis der Grabritter", level = 29, items = {273036, 273032, 273033}},
        {npc = 247032, name = "Lyn the Ignored", de = "Lyn der Ignorierte", level = 31, items = {273054, 273053, 273055}},
        {npc = 245999, name = "Arcane Anomaly", de = "Arkananomalie", level = 30, items = {273031, 273034, 273035}},
        {npc = 246016, name = "Arcanic Enigma", de = "Arkanes Mysterium", level = 30, items = {273045, 273044, 273043}},
        {npc = 246017, name = "Unstable Sentinel", de = "Instabile Schildwache", level = 31, items = {273046, 273048, 273047, 273099}},
        {npc = 246008, name = "Mana Devourer", de = "Manaschlinger", level = 31, items = {273040, 273042, 273041}},
        {npc = 246003, name = "Fel Ancient", de = "Teufelsurtum", level = 32, items = {273039, 273038, 273037}},
        {npc = 246020, name = "Shade of the Archmage", de = "Schemen des Erzmagiers", level = 33, items = {273052, 273051, 273049, 273103}},
    },
}
