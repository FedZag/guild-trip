-- Project ONE Dungeons: Katalog aller Forever-Dungeons.
-- Namen und Stufen kommen zur Laufzeit aus dem Spiel (Gruppensuche,
-- C_LFGList.GetActivityInfoTable). Die Werte hier sind nur Rueckfall, gemessen
-- im Forever-Spieltest vom 12.11.2026 (deutscher Client, Build 1.60.1.70862).
-- quests = Name des Eintrags in den Quest-Daten (Forever Dungeon Quests).
-- en = englischer Name (Anzeige in Klammern, hilft bei englischen Guides).
local _, dungeons = ...

dungeons.Catalog = {
    {key = "rfc", en = "Ragefire Chasm", activities = {798}, name = "Ragefireabgrund", min = 13, max = 18, quests = "Ragefire Chasm"},
    {key = "thanes", en = "The Hall of Thanes", activities = {1984}, name = "Halle der Thanen", min = 13, max = 20, quests = "The Hall of Thanes"},
    {key = "wc", en = "Wailing Caverns", activities = {796}, name = "Höhlen des Wehklagens", min = 15, max = 24, quests = "Wailing Caverns"},
    {key = "ruins", en = "Ruins of Lordaeron", activities = {1982}, name = "Ruinen von Lordaeron", min = 15, max = 22, quests = "Ruins of Lordaeron"},
    {key = "dm", en = "The Deadmines", activities = {799}, name = "Todesminen", min = 17, max = 26, quests = "The Deadmines"},
    {key = "sfk", en = "Shadowfang Keep", activities = {800}, name = "Burg Shadowfang", min = 20, max = 30, quests = "Shadowfang Keep"},
    {key = "stocks", en = "The Stockade", activities = {}, name = "Das Verlies", min = 22, max = 30, quests = "The Stockades", faction = "Alliance"},
    {key = "bfd", en = "Blackfathom Deeps", activities = {801}, name = "Blackfathom-Tiefe", min = 24, max = 32, quests = "Blackfathom Deeps"},
    {key = "excavation", en = "Excavation Site: Wetlands", activities = {1981}, name = "Ausgrabungsstätte: Sumpfland", min = 26, max = 33},
    {key = "dalaran", en = "Dalaran", activities = {1983}, name = "Dalaran", min = 28, max = 35},
    {key = "gnomer", en = "Gnomeregan", activities = {803}, name = "Gnomeregan", min = 29, max = 38, quests = "Gnomeregan"},
    {key = "rfk", en = "Razorfen Kraul", activities = {804}, name = "Kral von Razorfen", min = 29, max = 38, quests = "Razorfen Kraul"},
    {key = "sm", en = "Scarlet Monastery", activities = {805, 829, 827, 828}, name = "Scharlachrotes Kloster", min = 30, max = 46, quests = "Scarlet Monastery"},
    {key = "drowned", en = "The Drowned City", activities = {1985}, name = "Die Versunkene Stadt", min = 35, max = 42},
    {key = "rfd", en = "Razorfen Downs", activities = {806}, name = "Hügel von Razorfen", min = 37, max = 46, quests = "Razorfen Downs"},
    {key = "krol", en = "Krol'dok Stronghold", activities = {1986}, name = "Feste Krol'dok", min = 40, max = 47},
    {key = "ulda", en = "Uldaman", activities = {807}, name = "Uldaman", min = 41, max = 51, quests = "Uldaman"},
    {key = "zf", en = "Zul'Farrak", activities = {808}, name = "Zul'Farrak", min = 44, max = 54, quests = "Zul'Farrak"},
    {key = "mara", en = "Maraudon", activities = {809}, name = "Maraudon", min = 46, max = 55, quests = "Maraudon"},
    {key = "alcaz", en = "Alcaz Prison", activities = {1980}, name = "Gefängnis von Alcaz", min = 48, max = 55},
    {key = "st", en = "Sunken Temple", activities = {810}, name = "Versunkener Tempel", min = 50, max = 60, quests = "Sunken Temple"},
    {key = "brd", en = "Blackrock Depths", activities = {811}, name = "Blackrocktiefen", min = 52, max = 60, quests = "Blackrock Depths"},
    {key = "dme", en = "Dire Maul: East", activities = {813}, name = "Düsterbruch (Ost)", min = 54, max = 60, quests = "Dire Maul: East (Warpwood Quarter)"},
    {key = "dmw", en = "Dire Maul: West", activities = {814}, name = "Düsterbruch (West)", min = 56, max = 60, quests = "Dire Maul: West (Capital Gardens)"},
    {key = "dmn", en = "Dire Maul: North", activities = {815}, name = "Düsterbruch (Nord)", min = 56, max = 60, quests = "Dire Maul: North (Gordok Commons)"},
    {key = "lbrs", en = "Lower Blackrock Spire", activities = {812}, name = "Untere Blackrockspitze", min = 55, max = 60, quests = "Lower Blackrock Spire"},
    {key = "blackmaw", en = "Blackmaw Hold", activities = {1979}, name = "Schwarzschlundfeste", min = 55, max = 60},
    {key = "scholo", en = "Scholomance", activities = {797}, name = "Scholomance", min = 58, max = 60, quests = "Scholomance"},
    {key = "stratlive", en = "Stratholme: Main Gate", activities = {816}, name = "Stratholme (Haupttor)", min = 58, max = 60, quests = "Stratholme: Live Side"},
    {key = "stratud", en = "Stratholme: Service Entrance", activities = {1603}, name = "Stratholme (Dienstbotentor)", min = 58, max = 60, quests = "Stratholme: Undead Side"},
    {key = "shaper", en = "The Shaper's Terrace", activities = {1978}, name = "Terrasse des Formers", min = 58, max = 60},
    {key = "ubrs", en = "Upper Blackrock Spire", activities = {837}, name = "Obere Blackrockspitze", min = 59, max = 60, quests = "Upper Blackrock Spire"},
}

-- Gebietsnamen der Quest-Daten (englisch) -> Classic-uiMapID fuer den Navi-Pfeil.
-- Nur Oberwelt; Orte "Inside ..." haben keine Karte.
dungeons.Zones = {
    ["Durotar"] = 1411, ["Mulgore"] = 1412, ["The Barrens"] = 1413, ["Orgrimmar"] = 1454,
    ["Thunder Bluff"] = 1456, ["Undercity"] = 1458, ["Tirisfal Glades"] = 1420, ["Brill"] = 1420,
    ["Silverpine Forest"] = 1421, ["Hillsbrad Foothills"] = 1424, ["Ashenvale"] = 1440,
    ["Stonetalon Mountains"] = 1442, ["Desolace"] = 1443, ["Thousand Needles"] = 1441,
    ["Dustwallow Marsh"] = 1445, ["Tanaris"] = 1446, ["Feralas"] = 1444, ["Un'Goro Crater"] = 1449,
    ["Silithus"] = 1451, ["Winterspring"] = 1452, ["Felwood"] = 1448, ["Azshara"] = 1447,
    ["Moonglade"] = 1450, ["Darkshore"] = 1439, ["Teldrassil"] = 1438, ["Darnassus"] = 1457,
    ["Stormwind"] = 1453, ["Stormwind City"] = 1453, ["Ironforge"] = 1455, ["Elwynn Forest"] = 1429,
    ["Westfall"] = 1436, ["Redridge Mountains"] = 1433, ["Duskwood"] = 1431,
    ["Stranglethorn Vale"] = 1434, ["Swamp of Sorrows"] = 1435, ["Blasted Lands"] = 1419,
    ["Deadwind Pass"] = 1430, ["Burning Steppes"] = 1428, ["Searing Gorge"] = 1427,
    ["Badlands"] = 1418, ["Loch Modan"] = 1432, ["Dun Morogh"] = 1426, ["Wetlands"] = 1437,
    ["Arathi Highlands"] = 1417, ["Alterac Mountains"] = 1416, ["Hinterlands"] = 1425,
    ["The Hinterlands"] = 1425, ["Western Plaguelands"] = 1422, ["Eastern Plaguelands"] = 1423,
}
