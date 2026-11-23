local _, classes = ...

-- Baupläne der übrigen Klassen (erster Entwurf aus allgemeinem Spielwissen,
-- 14.11.2026). Wie beim Priester: nur Zauber-Nummern und Stichworte; Namen,
-- Ränge, Werte und Tooltips kommen live aus dem Spiel. Unbekannte Zauber
-- werden ausgegraut und halten ihren Platz frei.
-- Talentpläne fehlen bewusst (Forever hat die Bäume umgebaut) -> "Plan folgt".
-- Situationen: ohne eigene Angaben gilt der Grundplan.
local Data = classes.Data
local WAND = Data.WAND

-- Grundplan einer Ausrichtung aus gemeinsamen Leisten + eigener Kampf-Leiste.
-- add = {[Leiste] = {Plaetze}}: Talent-Faehigkeiten dieser Ausrichtung, hinten
-- angehaengt (ab Taste 9), damit die festen Plaetze 1-8 nie verrutschen.
-- Sie erscheinen erst, wenn das Talent gelernt ist (talent = true), sonst
-- waeren die Karten im Buch zu eng. Hoechstens 3 je Leiste.
local function Build(combat, shared, flow, stats, add, forms)
    local function Join(title, bar, slots)
        local extra = add and add[bar]
        if not extra then return {title = title, bar = bar, slots = slots} end
        local all = {}
        for _, step in ipairs(slots) do all[#all + 1] = step end
        for _, step in ipairs(extra) do all[#all + 1] = {step[1], step[2], talent = true} end
        return {title = title, bar = bar, slots = all}
    end
    local bars = {Join("Kampf", 1, combat)}
    for _, bar in ipairs(shared) do bars[#bars + 1] = Join(bar.title, bar.bar, bar.slots) end
    return {flow = flow, stats = stats, bars = bars, forms = forms}
end

-- Talent-Faehigkeiten aus Forever (Auslese 14.11.2026, Spalte im Talentbaum
-- = Ausrichtung). Viele sind neu in Forever (Nummern ab 399000 bzw. 1000000).

-- ===== Krieger =====
local WARRIOR_SHARED = {
    {title = "Notfall", bar = 2, slots = {
        {2687, "Wut"}, {5246, "Furcht"}, {871, "Schildwall"}, {12975, "Letztes"}, {1719, "Tollkühn"},
        {20230, "Konter"}, {18499, "Wut lösen"}}},
    {title = "Hilfe", bar = 3, slots = {
        {6673, "Schlachtruf"}, {1160, "Schwächen"}, {2457, "Kampf"}, {71, "Verteid."}, {2458, "Berserker"},
        {676, "Entwaffnen"}, {6552, "Zuschlagen"}, {20252, "Abfangen"}}},
}
Data.classes.WARRIOR = {
    name = "Krieger", specs = {"Waffen", "Furor", "Schutz"}, defaultSpec = 1,
    roles = {"melee", "melee", "tank"},
    specNotes = {
        "Stabil und mit viel Burst – so levelt die Mehrheit · braucht eine gute Zweihandwaffe.",
        "Viel Schaden mit zwei Waffen und Wirbelwind · nimmt viel Schaden, richtig stark erst nach Stufe 30.",
        "Tank: hält große Gruppen und verliert dabei wenig Leben, auch zum Leveln stark · alleine etwas langsamer.",
    },
    build = {
        [1] = Build({{100, "Start"}, {772, "Blutung"}, {12294, "Haupt"}, {7384, "Konter"}, {78, "Wut übrig"},
            {5308, "Hinrichten"}, {1464, "Füller"}, {845, "Spalten"}}, WARRIOR_SHARED,
            "Vorher: Schlachtruf, Kampfhaltung · 1 · 4 sobald möglich · 2 wenn der Gegner länger lebt · 3 bei Abklingen · 7 als Füller · 5 bei Wutüberschuss · 6 unter 20 % · Weitreichende Stöße + 8 bei mehreren",
            {"Stärke", "Ausdauer", "Beweglichkeit"},
            {[1] = {{1310222, "Aufspießen"}, {12292, "Schwünge"}}}),
        [2] = Build({{100, "Start"}, {772, "Blutung"}, {23881, "Haupt"}, {7384, "Konter"}, {78, "Wut übrig"},
            {5308, "Hinrichten"}, {1680, "Mehrere"}, {845, "Spalten"}}, WARRIOR_SHARED,
            "Vorher: Schlachtruf · 1 aus der Kampfhaltung · 2 und 4 kurz in der Kampfhaltung · dann Berserkerhaltung · 3 bei Abklingen · 7 bei Abklingen · 5 ab etwa 50 Wut (8 bei mehreren) – löst jetzt Ungezügelter Zorn aus, verbraucht Schlaghagel nicht · 6 unter 20 %",
            {"Stärke", "Beweglichkeit", "Ausdauer"},
            {[1] = {{1329555, "Mehr Wut"}, {12328, "Todeswunsch"}, {12323, "Bremsen"}}}),
        [3] = Build({{355, "Spott"}, {7386, "Rüstung"}, {6572, "Rache"}, {2565, "Block"}, {72, "Unterbrechen"},
            {23922, "Schildschlag"}, {6343, "Donner"}, {845, "Spalten"}}, WARRIOR_SHARED,
            "Vorher: Schlachtruf, Verteidigungshaltung · Sturmangriff zum Ziehen · 3 sobald möglich · 2 mehrmals · 7 bei Abklingen · Demoralisierungsruf halten · 6 sobald möglich · 4 vor Treffern · 8 bei Wutüberschuss · 1 wenn ein Gegner wegläuft",
            {"Ausdauer", "Rüstung", "Stärke"},
            {[1] = {{12809, "Betäuben"}}}),
    },
    buffs = {{ids = {6673}}},
    tips = {
        {function(p) return p.spec ~= 3 end, "Wut entsteht durch Treffen und Getroffenwerden – Heldenhafter Stoß nur, wenn Wut übrig ist."},
        {function() return true end, "Im Dungeon tankt der Schutz-Krieger: Verteidigungshaltung und Rüstung zerreißen."},
    },
}

-- ===== Schurke =====
local ROGUE_SHARED = {
    {title = "Notfall", bar = 2, slots = {
        {5277, "Ausweichen"}, {2983, "Sprinten"}, {1856, "Weg"}, {1833, "Betäuben"}, {408, "Niere"},
        {2094, "Blenden"}, {1966, "Finte"}}},
    {title = "Hilfe", bar = 3, slots = {
        {921, "Stehlen"}, {6770, "Kopfnuss"}, {1804, "Schloss"}, {1725, "Ablenken"}, {2836, "Fallen"},
        {1842, "Entschärfen"}}},
}
local ROGUE_COMBAT = {{1784, "vorher"}, {1752, "Punkte"}, {2098, "Finisher"}, {5171, "Tempo"}, {53, "von hinten"},
    {8676, "Start"}, {1766, "Tritt"}, {1776, "Solarplexus"}}
Data.classes.ROGUE = {
    name = "Schurke", specs = {"Meucheln", "Kampf", "Täuschung"}, defaultSpec = 2,
    roles = {"agile", "agile", "agile"},
    specNotes = {
        "Wird mit Verstümmeln sehr stark, Gifte machen viel Schaden · kein Einsteiger-Stil, weniger robust als Kampf.",
        "Einsteiger-Stil: robust dank Abwehr und Riposte, ein Gegner nach dem anderen · weniger Burst als Täuschung.",
        "Großer Burst aus der Verstohlenheit (Hinterhalt), Todesmal für Elite · hängt vom Timing ab, schwerer zu spielen.",
    },
    build = {
        [1] = Build(ROGUE_COMBAT, ROGUE_SHARED, "Vorher: Gifte auf beide Waffen, 1 · 6 oder Fieser Trick · 9 sobald gelernt, sonst 2 · 4 sofort und erneuern · 3 bei 4–5 Punkten · 7 bei Zaubern · nächstes Ziel angreifen, bevor Gnadenlose Angriffe ausläuft",
            {"Kritische Treffer", "Beweglichkeit", "Angriffskraft"},
            {[1] = {{399956, "Verstümmeln"}, {14177, "Kaltblütig"}}}),
        [2] = Build(ROGUE_COMBAT, ROGUE_SHARED, "Vorher: Gifte auf beide Waffen · direkt angreifen oder 1 und Fieser Trick · 2 für Punkte · 4 halten · 3 bei 3–5 Punkten · 10 bei mehreren · 11 als Burst · 9 nach Parieren · 7 bei Zaubern",
            {"Kritische Treffer", "Beweglichkeit", "Angriffskraft"},
            {[1] = {{14251, "Riposte"}, {13877, "Klingen"}, {13750, "Adrenalin"}}}),
        [3] = Build(ROGUE_COMBAT, ROGUE_SHARED, "Vorher: Gifte auf beide Waffen, 1 · 6 Start · 9 für Punkte · 10 bei Abklingen (Hinterhalt im Kampf) · 3 bei Punkten · 11 mit 4 bei Elite · Notfall: Verschwinden, dann 6",
            {"Kritische Treffer", "Beweglichkeit", "Angriffskraft"},
            {[1] = {{16511, "Blutsturz"}, {14278, "Geist"}, {1316709, "Todesmal"}}, [2] = {{14185, "Vorbereitung"}}}),
    },
    buffs = {},
    tips = {
        {function() return true end, "Gifte auf die Waffen nicht vergessen – ab Stufe 20 beim Giftlehrer."},
    },
}

local rogue = Data.classes.ROGUE.build
for i = 1, 3 do
    rogue[i].situations = {
        dungeon = {flow = "Tank zieht zuerst · hinter den Gegner stellen · 2 für Punkte · 4 halten · 3 bei 5 Punkten · 7 bei Zaubern · Finte bei Aggro"},
        raid = {flow = "Hinter dem Boss · 4 immer halten · 2 für Punkte · 3 bei 5 Punkten · Rüstung schwächen nach Absprache · Finte regelmäßig"},
    }
end
rogue[1].talents = { -- Meucheln
    {14138, 5}, {14144, 2}, {14165, 3}, {14156, 3}, {14128, 2}, {14113, 5}, {16513, 5}, {14179, 5},
    {14186, 3}, {14177, 1}, {399956, 1},
    {13732, 2}, {14162, 3}, {13705, 3}, {13713, 3}, {14251, 1}, {13743, 2}, {14983, 2},
}
rogue[2].talents = { -- Kampf
    {13732, 2}, {14162, 3}, {13705, 3}, {13713, 2}, {14251, 1}, {13742, 2}, {1329265, 2}, {1310711, 1},
    {18427, 3}, {30919, 2}, {13715, 2}, {13877, 1}, {13960, 5}, {1329284, 5}, {13750, 1},
    {14138, 5}, {14144, 2}, {14156, 3}, {14165, 3}, {14128, 2}, {14983, 1},
}
rogue[3].talents = { -- Taeuschung (Hinterhalt)
    {14057, 5}, {14079, 3}, {14082, 2}, {13976, 3}, {14171, 2}, {14278, 1}, {14171, 3}, {14183, 1},
    {13975, 2}, {14185, 1}, {16511, 1}, {30894, 2}, {13981, 1}, {1329286, 5}, {1316709, 1},
    {14138, 5}, {14144, 2}, {14156, 3}, {14165, 3}, {14128, 2}, {14113, 5},
}

local warrior = Data.classes.WARRIOR.build
warrior[1].situations = {
    dungeon = {flow = "Tank zieht zuerst · 4 sobald möglich · 3 bei Abklingen · Weitreichende Stöße + 8 bei mehreren · 5 nur bei Wutüberschuss · 6 unter 20 %"},
    raid = {flow = "Hinter dem Boss stehen · 3 bei Abklingen · 4 sobald möglich · 2 halten (nach Absprache) · 6 unter 20 %"},
}
warrior[2].situations = {
    dungeon = {flow = "Tank zieht zuerst · 3 bei Abklingen · 7 bei Abklingen · 8 bei mehreren · 5 ab etwa 50 Wut · 6 unter 20 %"},
    raid = {flow = "Hinter dem Boss · 3 und 7 bei Abklingen · 5 ab etwa 50 Wut · 6 unter 20 % · Todeswunsch mit Abklingzeiten"},
}
warrior[3].situations = {
    dungeon = {flow = "Vorher: Schlachtruf · Sturmangriff · 7 auf alle · 6 und 3 aufs Hauptziel · 8 für die anderen · 1 wenn ein Gegner zum Heiler läuft"},
    raid = {flow = "6 und 3 sobald möglich · 2 auf 5 Stapel · 4 vor großen Treffern · 1 bei Tankwechsel · Letztes Gefecht im Notfall"},
}
warrior[1].talents = { -- Waffen
    {16462, 5}, {12290, 2}, {12295, 3}, {12286, 3}, {12296, 1}, {12834, 3}, {12163, 3}, {1310222, 1}, {16493, 2},
    {12292, 1}, {1289682, 2}, {1290261, 2}, {12862, 2}, {1290261, 5}, {12294, 1},
    {12320, 5}, {12321, 5}, {12322, 5}, {12323, 1}, {12282, 1},
}
warrior[2].talents = { -- Furor
    {12320, 5}, {1323964, 5}, {12323, 1}, {12317, 4}, {23584, 5}, {1329555, 1}, {12328, 1}, {1323967, 2},
    {20502, 1}, {1310315, 2}, {12319, 3}, {23881, 1}, {12317, 5}, {12321, 5}, {12322, 5}, {20502, 2},
    {16462, 5}, {12282, 3},
}
warrior[3].talents = { -- Schutz
    {12298, 5}, {12297, 5}, {12792, 3}, {12287, 2}, {12975, 1}, {1310317, 1}, {12308, 3}, {12809, 1},
    {29787, 3}, {12311, 1}, {16538, 5}, {23922, 1}, {12287, 3}, {12797, 3}, {1310316, 2}, {12962, 5},
    {12301, 2}, {16462, 5}, {12282, 2},
}

-- ===== Jäger =====
local HUNTER_SHARED = {
    {title = "Notfall", bar = 2, slots = {
        {136, "Tier heilen"}, {5384, "Totstellen"}, {1499, "Falle"}, {781, "Rückzug"}, {19263, "Abschrecken"},
        {3045, "Schnellfeuer"}}},
    {title = "Hilfe", bar = 3, slots = {
        {883, "Tier rufen"}, {982, "Beleben"}, {6991, "Füttern"}, {13165, "Falke"}, {13163, "Affe"},
        {5118, "Gepard"}, {1494, "Aufspüren"}, {1515, "Zähmen"}, {2641, "Freigeben"}}},
}
-- Nach Forever-Guides (Warcraft Tavern, Nov. 2026), siehe docs/KLASSEN_GUIDES_FOREVER.md
local HUNTER_RANGED = {{1130, "Mal"}, {1978, "Biss"}, {3044, "Sofort"}, {19434, "Gezielt"}, {2643, "Mehrere"},
    {5116, "Bremsen"}, {2973, "Nah"}, {2974, "Stutzen"}}
local HUNTER_SV = {{1130, "Mal"}, {1978, "Biss"}, {2973, "Raptor"}, {1495, "Mungo"}, {13795, "Feuerfalle"},
    {2974, "Stutzen"}, {3044, "Sofort"}, {2643, "Mehrere"}}
Data.classes.HUNTER = {
    name = "Jäger", specs = {"Tierherrschaft", "Treffsicherheit", "Überleben"}, defaultSpec = 1,
    roles = {"hunter", "hunter", "hunter"},
    specNotes = {
        "Am angenehmsten zum Leveln: dein Tier hält die Gegner, du schießt sicher aus der Ferne · weniger eigener Schaden.",
        "Starker eigener Schaden mit Scharfschützenschuss · weniger verzeihend, öfter Abstand halten.",
        "Fernkampf und Nahkampf gemischt, viel Kontrolle · der schwierigste Stil, Wechsel stört den Ablauf.",
    },
    build = {
        [1] = Build(HUNTER_RANGED, HUNTER_SHARED,
            "Vorher: Falkenaspekt, Tier bereit · 1 · Tier greift an · 2 · 3 bei Abklingen · 4 bei Abklingen · Zorn und Schnellfeuer bei Abklingen · Tier verliert Aggro: 6 oder Frostfalle",
            {"Beweglichkeit", "Angriffskraft", "Intelligenz"},
            {[1] = {{19574, "Zorn"}, {19577, "Einschüchtern"}, {1293241, "Falke"}}}),
        [2] = Build(HUNTER_RANGED, HUNTER_SHARED,
            "Vorher: Falkenaspekt, Aura · 1 · 2 · 9 bei Abklingen · 3 · 4 · Schnellfeuer bei Abklingen · 5 bei mehreren · Abstand halten",
            {"Beweglichkeit", "Angriffskraft", "Kritische Treffer"},
            {[1] = {{1310687, "Heckenschuss"}, {1299346, "Aura"}, {19503, "Streuschuss"}}}),
        [3] = Build(HUNTER_SV, HUNTER_SHARED,
            "Vorher: Falkenaspekt (nur Nahkampf: Wildtieraspekt) · 1 · 2 aus der Ferne · nah: 3 · 5 · 4 sobald möglich · 9 bei Abklingen · Notfall: Totstellen",
            {"Beweglichkeit", "Angriffskraft", "Kritische Treffer"},
            {[1] = {{1317257, "Tritt"}, {19306, "Gegenangriff"}}}),
    },
    buffs = {{ids = {13165}, also = {13163, 5118, 13159, 20043, 13161}}},
    tips = {
        {function() return true end, "Dein Tier ist dein Tank: es greift zuerst an, du schießt danach."},
        {function() return true end, "Einsamer Wolf (ohne Tier) lohnt sich beim Leveln nicht – das Tier hält dir die Gegner vom Leib."},
    },
}
local hunter = Data.classes.HUNTER.build
for i = 1, 3 do
    hunter[i].situations = {
        dungeon = {flow = "Tank zieht zuerst · Tier auf passiv/Knurren aus · 1 aufs Ziel des Tanks · 2 · 3 · 4 · Mehrfachschuss nur ohne Schaf · Totstellen bei Aggro"},
        raid = {flow = "1 auf den Boss · 2 nach Absprache · 3 und 4 bei Abklingen · Schnellfeuer mit Abklingzeiten · Totstellen bei Aggro"},
    }
end
hunter[1].talents = { -- Tierherrschaft, ab ~43 Treffsicherheit (Effizienz)
    {19552, 5}, {1223755, 2}, {19583, 3}, {19559, 2}, {19616, 5}, {19598, 5}, {1293241, 1}, {19577, 1},
    {19590, 2}, {19578, 2}, {19621, 5}, {19574, 1},
    {19498, 3}, {19426, 2}, {19416, 5}, {1310661, 3}, {19426, 5}, {415405, 1},
}
hunter[2].talents = { -- Treffsicherheit (ohne Einsamer Wolf)
    {19426, 5}, {19416, 5}, {19454, 5}, {1299346, 1}, {19485, 4}, {1223987, 2}, {19461, 3}, {19507, 5},
    {1310687, 1}, {19485, 5}, {1223984, 5}, {19498, 3}, {415405, 2},
    {19552, 5}, {1223755, 2}, {19583, 2},
}
hunter[3].talents = { -- Ueberleben
    {19295, 5}, {19159, 2}, {19228, 3}, {19263, 1}, {19239, 2}, {19290, 2}, {19376, 2}, {19306, 1},
    {1310627, 2}, {1317257, 1}, {440529, 2}, {1310532, 2}, {19168, 5}, {1310533, 1}, {1310627, 5},
    {19255, 5}, {1310496, 2}, {19426, 5}, {19416, 5},
}

-- ===== Magier =====
local MAGE_SHARED = {
    {title = "Notfall", bar = 2, slots = {
        {1953, "Blinzeln"}, {1463, "Manaschild"}, {11426, "Barriere"}, {11958, "Eisblock"}, {12051, "Mana"},
        {2139, "Gegenzauber"}, {118, "Schaf"}}},
    {title = "Hilfe", bar = 3, slots = {
        {1459, "Intelligenz"}, {168, "Rüstung"}, {6117, "Magierüstung"}, {587, "Essen"}, {5504, "Wasser"},
        {475, "Fluch weg"}, {130, "Schweben"}, {604, "Dämpfen"}, {1008, "Verstärken"}}},
}
-- Kampfleisten je Ausrichtung (Forever-Guides Nov. 2026: Warcraft Tavern, kami-labs/Mobalytics,
-- zusammengefasst und an unsere Plaetze angepasst; Talent-Plaetze ab Taste 9).
-- Auslöser (passive Talente) stehen im Ablauf: Geschosssalve -> Arkane Geschosse,
-- Arkane Konzentration (Freizauber), Aufwärmen -> Pyroschlag, Eisige Finger -> Eislanze.
-- Arkan nach dem Leveling-Guide von Mr. Ronnet (YouTube, Nov. 2026), geprüft gegen die Spieldaten
-- 1.60.1.70959 (wago.tools: Talentbaum, Arkaner Zorn +5 % max. Mana als Zauberschaden, Arkanschlag
-- +100 % Manakosten je Stapel, Magierrüstung + Arkane Meditation je 50 % Mana-Erholung, Offenbarung).
-- Frostblitz Rang 1 ab Stufe 27 (exact = 27): billig und schnell, bremst, löst Geschosssalve aus;
-- vorher der höchste Rang als Hauptzauber.
local MAGE_ARCANE = {{116, "Bremsen", exact = 27}, {5143, "Salve"}, {2136, "Erledigen"}, {122, "Einfrieren"}, {2120, "Mehrere"},
    {WAND, "Sparen"}, {1449, "Nah"}, {10, "Blizzard"}}
local MAGE_FIRE = {{133, "Füller"}, {2136, "Sofort"}, {2948, "Versengen"}, {122, "Einfrieren"}, {5143, "Salve"},
    {WAND, "Sparen"}, {2120, "Mehrere"}, {116, "Bremsen"}}
local MAGE_FROST = {{116, "Füller"}, {5143, "Salve"}, {122, "Einfrieren"}, {2136, "Sofort"}, {120, "Kegel"},
    {WAND, "Sparen"}, {10, "Blizzard"}, {1449, "Mehrere"}}
Data.classes.MAGE = {
    name = "Magier", specs = {"Arkan", "Feuer", "Frost"}, defaultSpec = 3,
    -- Kurz: Vor- und Nachteile je Spielstil (Auswahl auf der Klassen-Seite)
    specNotes = {
        "Bester Magier zum Leveln: Arkaner Zorn, kostenlose Geschosse und Blizzard per Freizauber, kaum Pausen · richtig stark erst ab Stufe 20–27, Arkanschlag nur sparsam.",
        "Höchster Schaden, kurze Kämpfe dank Pyroschlag und Druckwelle · wenig Kontrolle, gefährlich bei vielen Gegnern.",
        "Am sichersten: bremsen, einfrieren, Eislanze – ideal zum Leveln allein · etwas weniger Schaden als Feuer.",
    },
    build = {
        [1] = Build(MAGE_ARCANE, MAGE_SHARED,
            "Ab Stufe 27 – vorher: Arkane Intelligenz, Frostrüstung (ab 34 Magierrüstung) · 10 zum Eröffnen · Nahkämpfer: 1 (Rang 1) zum Bremsen · 9 höchstens zweimal (danach zu teuer) · 1 bis 10 wieder bereit · nah: 4, zurückgehen, wieder 10 · Geschosssalve oder Freizauber: sofort 2 · fast tot: 6 (3 nur bei viel Mana) · zähe Gegner: 11, dann 10",
            {"Intelligenz", "Ausdauer", "Zauberschaden"},
            {[1] = {{400574, "Aufladen"}, {1326079, "Zorn"}, {12043, "Sofort"}}}),
        [2] = Build(MAGE_FIRE, MAGE_SHARED,
            "Vorher: Arkane Intelligenz, Frostrüstung · 9 vorab · 1 Füller · 2 sobald bereit · 3 bis 5 Versengen-Stapel · 9 bei 3x Aufwärmen · 5 bei Geschosssalve · nah: 4 und Blinzeln · Mana knapp: 6",
            {"Zauberschaden", "Intelligenz", "Willenskraft"},
            {[1] = {{11366, "Pyroschlag"}, {11113, "Druckwelle"}, {11129, "Verbrennung"}}}),
        [3] = Build(MAGE_FROST, MAGE_SHARED,
            "Vorher: Arkane Intelligenz, Frostrüstung · 1 Füller · 9 bei Eisige Finger oder eingefroren · 2 bei Geschosssalve · nah: 3, dann 9 · 5 nach 3 · Mana knapp: 6",
            {"Zauberschaden", "Intelligenz", "Willenskraft"},
            {[1] = {{1312002, "Eislanze"}, {12472, "Kälte"}}}),
    },
    buffs = {{ids = {1459}, also = {23028}}, {ids = {168}, also = {7302, 6117}}},
    tips = {
        {function() return true end, "Essen und Wasser selbst herbeizaubern – das spart viel Gold beim Leveln."},
        {function() return true end, "Geschosssalve (Talent): nach Arkanschlag oder Frostblitz leuchtet Arkane Geschosse – dann sofort wirken, kostet nichts extra."},
        {function(p) return p.spec == 1 end, "Arkan: Waffenverzauberung „Offenbarung“ (etwa 3–4 Gold) – trifft ein Zauber nicht kritisch, trifft der nächste sicher kritisch; laut Spielerberichten hält das über den ganzen Blizzard."},
        {function(p) return p.spec == 1 end, "Arkan: Intelligenz vor Zauberschaden – Arkaner Zorn wird mit jedem Punkt Mana stärker."},
        {function() return true end, "Erste Hilfe lernen: Magier können sich nicht heilen, Verbände sparen Pausen."},
    },
}
-- Situationen: Dungeon (mehrere Gegner, Tank zieht) und Raid (Stufe 60, nach Simulationen)
local mage = Data.classes.MAGE.build
mage[1].situations = {
    dungeon = {flow = "Tank zieht zuerst · ab 34 Magierrüstung statt Frostrüstung · ab 3 Gegnern: 5 legen · Freizauber: sofort 8 (kostet dann nichts) · bis dahin Ablauf wie allein · 8 ab und zu auch mit Mana · Geschosssalve: 2"},
    raid = {flow = "Arkane Macht mit Abklingzeiten · 9 lädt auf (4x) · 2 bei Geschosssalve · 10 bei 3–4 Ladungen · 11, dann 10 · Hervorrufung unter 15 % Mana"},
}
mage[1].stages = { -- Leveln ab Stufe 1 (Lernstufen aus den Spieldaten 70959: Frostblitz 4, Feuerschlag 6,
    -- Geschosse 8, Frostnova 10, Arkane Explosion 14, Flammenstoß 16, Blizzard 20, Magierrüstung 34; Talente laut Plan)
    {upTo = 3, flow = "Stufe 1–3 – vorher: Frostrüstung, Arkane Intelligenz · Feuerball bis tot (liegt schon auf der Leiste) · ab Stufe 4 Frostblitz · Mana knapp: essen und trinken"},
    {upTo = 9, flow = "Stufe 4–9 – vorher: Frostrüstung, Arkane Intelligenz · 1 bis tot (bremst, Nahkämpfer erreichen dich kaum) · fast tot: 3 (ab 6) · ab 8: 2 bei vollem Mana · Mana knapp: 6, sobald du einen Zauberstab hast · Wasser herbeizaubern ab 4"},
    {upTo = 19, flow = "Stufe 10–19 – vorher: Frostrüstung, Arkane Intelligenz · 1 Füller · nah: 4, zurückgehen, weiter 1 · Geschosssalve (ab 15) oder Freizauber (ab 17): sofort 2 · fast tot: 6 oder 3 · mehrere nah: 7 (ab 14) · Mana knapp: 6"},
    {upTo = 26, flow = "Stufe 20–26 – vorher: Frostrüstung, Arkane Intelligenz · 9 zweimal (nicht öfter, sonst zu teuer) · dann 1 bis tot · Geschosssalve oder Freizauber: sofort 2 · nah: 4, zurückgehen · fast tot: 6 · Mana knapp: 6"},
}
mage[2].situations = {
    dungeon = {flow = "Tank zieht zuerst · 3 bis 5 Stapel · 1 Füller · 9 bei 3x Aufwärmen · 7 bei vielen Gegnern · 10 wenn sie nah sind"},
    raid = {flow = "9 vorab · 3 hält 5 Stapel · 11 bei 5 Stapeln · 9 bei 3x Aufwärmen · 2 sobald bereit · 1 Füller"},
}
mage[3].situations = {
    dungeon = {flow = "Tank zieht zuerst · 1 Füller · 9 bei Eisige Finger · 7 bei 4+ Gegnern · 5 bei 3+ nah · 3 wenn es eng wird"},
    raid = {flow = "Eisbarriere vorab · 1 Füller · 9 bei Eisige Finger · 2 bei Geschosssalve · 10 mit Abklingzeiten"},
}
-- Talentplaene Stufe 10-60 (Reihenfolge = ein Punkt je Stufe; {Talent, Zielrang}).
-- Reihen-Freischaltung (5 Punkte je Reihe) ist eingerechnet.
mage[1].talents = { -- Arkan (Leveln, nach Mr. Ronnet Nov. 2026, Bäume/Reihen gegen Spieldaten 70959 geprüft)
    {11237, 5}, {400588, 2}, {11213, 3}, {400574, 1}, {11213, 5}, {29438, 2}, {11242, 2}, {1326079, 1},
    {18462, 3}, {11242, 3}, {12043, 1}, {11232, 5}, {11210, 2}, {15058, 3}, {12042, 1}, {29438, 3},
    {11070, 5}, {11071, 3}, {11165, 2}, {11175, 3}, {11170, 3}, -- Frost: Bremsen, Einfrieren, Zertrümmern
}
mage[2].talents = { -- Feuer
    {11069, 5}, {11119, 5}, {11366, 1}, {11078, 2}, {11100, 2}, {400624, 1}, {11095, 3}, {29074, 3},
    {11115, 3}, {11113, 1}, {11124, 3}, {18459, 1}, {11129, 1}, {18459, 5}, {11108, 3},
    {11237, 5}, {400588, 2}, {11210, 2}, {11213, 4},
}
mage[3].talents = { -- Frost (erst 7 Punkte Arkan fuer Geschosssalve)
    {11237, 5}, {400588, 2}, {11070, 5}, {11207, 5}, {1312002, 1}, {11160, 3}, {11071, 3}, {11170, 3},
    {400647, 2}, {12472, 1}, {11190, 3}, {11180, 5}, {11426, 1}, {29438, 3}, {16757, 2}, {11165, 2},
    {11958, 1}, {11175, 3}, {11189, 1},
}

-- ===== Hexenmeister =====
local WARLOCK_SHARED = {
    {title = "Notfall", bar = 2, slots = {
        {1454, "Aderlass"}, {755, "Tier heilen"}, {6789, "Todesmantel"}, {5484, "Heulen"}, {6229, "Zauberschutz"}}},
    {title = "Hilfe", bar = 3, slots = {
        {688, "Wichtel"}, {697, "Leerwandler"}, {712, "Sukkubus"}, {691, "Teufelsjäger"}, {687, "Haut"},
        {706, "Rüstung"}, {6201, "Stein"}, {693, "Seelenstein"}, {5697, "Atem"}}},
}
-- Nach Forever-Guides (Warcraft Tavern, Nov. 2026), siehe docs/KLASSEN_GUIDES_FOREVER.md
local WARLOCK_AFF = {{172, "DoT"}, {980, "Pein"}, {348, "Feuerbrand"}, {689, "Leben"}, {686, "Füller"},
    {WAND, "Sparen"}, {5782, "Furcht"}, {1120, "Splitter"}}
local WARLOCK_DEMO = {{980, "Pein"}, {172, "DoT"}, {348, "Feuerbrand"}, {5676, "Brandmal"}, {686, "Füller"},
    {WAND, "Sparen"}, {689, "Leben"}, {5782, "Furcht"}}
local WARLOCK_DESTRO = {{348, "Start"}, {980, "Pein"}, {686, "Füller"}, {172, "DoT"}, {WAND, "Sparen"},
    {5676, "Sofort"}, {689, "Leben"}, {5782, "Furcht"}}
Data.classes.WARLOCK = {
    name = "Hexenmeister", specs = {"Gebrechen", "Dämonologie", "Zerstörung"}, defaultSpec = 1,
    specNotes = {
        "Am einfachsten: Schaden über Zeit, auch im Laufen, zwei Gegner gleichzeitig · braucht Geduld bis zum Tod des Gegners.",
        "Schnellste Kills mit Sayaad und Brandmal, sehr stark in PvP · bis Stufe 27 wie Gebrechen spielen.",
        "Viel Burst, stark im Dungeon · hoher Manaverbrauch, weniger Ausdauer im Leveln.",
    },
    build = {
        [1] = Build(WARLOCK_AFF, WARLOCK_SHARED,
            "Vorher: Dämonenhaut, Dämon rufen · Tier vor · 2 · 1 · 3 bei zähen Gegnern · 9 ab Stufe 37 · 6 bis 30, dann 4 · 10 erst, wenn 1, 2 und 9 laufen – dann ticken sie doppelt so schnell · Einbruch der Nacht: 5 sofort · Leben > Mana: Aderlass",
            {"Zauberschaden", "Intelligenz", "Ausdauer"},
            {[1] = {{18265, "Entzug"}, {1316697, "Zermürben"}, {18223, "Erschöpfung"}}}),
        [2] = Build(WARLOCK_DEMO, WARLOCK_SHARED,
            "Vorher: Dämonenhaut, Sayaad (Schaden) oder Leerwandler (mehrere) · Tier vor · 4 auf das Ziel des Dämons, vor Ablauf des Brandmals erneuern · 1 · 2 · 3 · 7 · Leben > Mana: Aderlass",
            {"Zauberschaden", "Ausdauer", "Intelligenz"},
            {[1] = {{18788, "Opferung"}, {19028, "Verbindung"}, {18708, "Schnell rufen"}}}),
        [3] = Build(WARLOCK_DESTRO, WARLOCK_SHARED,
            "Vorher: Dämonenhaut, Wichtel · 1 Start · 2 · 9 bevor 1 ausläuft · 3 oder 11 Füller · 10 zum Abschluss · Leben > Mana: Aderlass",
            {"Zauberschaden", "Intelligenz", "Ausdauer"},
            {[1] = {{1293817, "Feuersbrunst"}, {17877, "Schattenbrand"}, {412758, "Verbrennen"}}}),
    },
    buffs = {{ids = {706}, also = {687}}},
    tips = {
        {function() return true end, "Mit Aderlass Leben in Mana tauschen, dann mit Blutsauger zurückholen – kaum Pausen."},
        {function() return true end, "Zwei Gegner: den zweiten mit DoTs belegen und fürchten, während dein Dämon den ersten hält."},
    },
}
local warlock = Data.classes.WARLOCK.build
warlock[1].situations = {
    dungeon = {flow = "Tank zieht zuerst · 2 und 1 auf mehrere Gegner · 10 nur auf ein Ziel mit 1, 2 und 9 · 5 Füller · Seelenstein auf den Heiler · Leben > Mana: Aderlass"},
    raid = {flow = "Fluch nach Absprache (z. B. Elemente) · 1, 2 und 9 halten · dann 10 (lässt sie doppelt so schnell ticken) · 5 Füller · Seelenstein auf den Heiler"},
}
warlock[2].situations = {
    dungeon = {flow = "Tank zieht zuerst · Dämon greift das Ziel des Tanks an · 4 auf dasselbe Ziel · 1 · 2 · 5 Füller"},
    raid = {flow = "Seelenverbindung/Opferung nach Plan · 1 und 3 halten · 5 Füller · Seelenstein auf den Heiler"},
}
warlock[3].situations = {
    dungeon = {flow = "Tank zieht zuerst · 1 · 9 bevor 1 ausläuft · 3 oder 11 Füller · 10 zum Abschluss · Furcht nie im Dungeon"},
    raid = {flow = "Fluch nach Absprache · 1 halten · 9 bei Abklingen · 11 oder 3 Füller · Seelenstein auf den Heiler"},
}
-- Talentplaene 10-60 (Gebrechen genau nach Guide; Daemonologie/Zerstoerung aus den Kerntalenten,
-- Reihen-Freischaltung eingerechnet)
warlock[1].talents = {
    {17810, 5}, {18174, 3}, {18769, 5}, {1225214, 2}, {403511, 3}, {18288, 1}, {18827, 2}, {18174, 5},
    {427712, 3}, {18182, 1}, {18265, 1}, {17804, 3}, {18182, 2}, {18271, 5}, {1316697, 1}, {1310949, 5},
    {17783, 3}, {18094, 2}, {17793, 3},
}
warlock[2].talents = {
    {18769, 5}, {1225214, 2}, {18731, 3}, {18709, 2}, {18754, 3}, {1293695, 3}, {18788, 1}, {18708, 1},
    {19028, 1}, {412732, 3}, {18697, 1}, {23785, 5}, {425464, 1},
    {17810, 5}, {18174, 5}, {403511, 3}, {18288, 1}, {18827, 2}, {427712, 3}, {18182, 1},
}
warlock[3].talents = {
    {17793, 5}, {17778, 3}, {18119, 2}, {17877, 1}, {17959, 5}, {1293817, 1}, {17927, 3}, {412751, 3},
    {18119, 4}, {426316, 5}, {412758, 1},
    {17810, 5}, {18174, 5}, {403511, 3}, {18288, 1}, {18827, 2}, {18182, 1}, {18769, 3},
}

-- ===== Paladin =====
local PALADIN_SHARED = {
    {title = "Notfall & Heilung", bar = 2, slots = {
        {19750, "Schnell"}, {635, "Viel"}, {498, "Gottesschutz"}, {642, "Gottesschild"}, {633, "Handauflegen"},
        {1022, "Schützen"}, {1152, "Läutern"}, {4987, "Reinigen"}}},
    {title = "Hilfe", bar = 3, slots = {
        {19740, "Macht"}, {19742, "Weisheit"}, {20217, "Könige"}, {465, "Hingabe"}, {7294, "Vergeltung"},
        {19746, "Konzentr."}, {7328, "Erlösung"}, {1044, "Freiheit"}, {25780, "Zorn"}}},
}
-- Heiliger Stoss ist neu in Forever (Auslese: 678)
local PALADIN_MAIN = {{21084, "Siegel"}, {20271, "Urteil"}, {678, "Heil. Stoß"}, {26573, "Weihe"}, {853, "Betäuben"},
    {879, "Untote"}, {24275, "unter 20 %"}, {20375, "Befehl"}}
-- Vergeltung (Forever-Guide Stufe 60): Kreuzfahrer-Siegel + Urteil zum Eroeffnen,
-- Betaeuben ersetzt dort die Konzentrationsaura auf der Hilfe-Leiste
local PALADIN_RET = {{20375, "Befehl"}, {20271, "Urteil"}, {678, "Heil. Stoß"}, {26573, "Weihe"}, {21082, "Eröffnen"},
    {879, "Untote"}, {24275, "unter 20 %"}, {21084, "Rechtsch."}}
local PALADIN_RET_SHARED = {PALADIN_SHARED[1], {title = PALADIN_SHARED[2].title, bar = 3, slots = {}}}
for _, step in ipairs(PALADIN_SHARED[2].slots) do
    table.insert(PALADIN_RET_SHARED[2].slots, step[1] == 19746 and {853, "Betäuben"} or step)
end
local PALADIN_COMBAT = {{21084, "Siegel"}, {20271, "Urteil"}, {21082, "Start"}, {853, "Betäuben"}, {879, "Untote"},
    {26573, "Weihe"}, {24275, "unter 20 %"}, {20375, "Befehl"}}
Data.classes.PALADIN = {
    name = "Paladin", specs = {"Heilig", "Schutz", "Vergeltung"}, defaultSpec = 3,
    roles = {"healer", "tank", "melee"},
    specNotes = {
        "Heiler oder „Schock-Paladin“ mit überraschend viel Schaden · braucht Heiliger Schock, dazu meist eine Zauberwaffe.",
        "Tank für große Gruppen mit Weihe, weicht viel aus · alleine langsamer, braucht Zaubermacht.",
        "Am einfachsten: sparsam mit Mana, Weihe gegen mehrere, Siegel des Befehls macht viel Burst · wenig Fernkampf.",
    },
    build = {
        [1] = Build(PALADIN_MAIN, PALADIN_SHARED, "Vorher: Segen der Könige, Vergeltungsaura · 1 an · Heiliger Schock zum Ziehen · 2 · 4 · 3 · alles bei Abklingen · Heilen: Leiste 2",
            {"Zauberschaden", "Intelligenz", "Ausdauer"},
            {[2] = {{1311606, "Schock"}, {20216, "Gunst"}, {1310911, "Lichtwacht"}}}),
        [2] = Build(PALADIN_MAIN, PALADIN_SHARED, "Vorher: Segen der Könige, Vergeltungsaura, Zorn der Gerechtigkeit · 1 vor dem Kampf · 2 · 4 im Nahkampf · 3 · 9 bei Abklingen · 6 gegen Untote · etwa vier Gegner sammeln (Weihe wird bei mehr schwächer)",
            {"Zauberschaden", "Ausdauer", "Intelligenz"},
            {[1] = {{20925, "Heil. Schild"}, {1310994, "Schnell-Urteil"}}, [2] = {{1311015, "Bollwerk"}}}),
        [3] = Build(PALADIN_RET, PALADIN_RET_SHARED, "Vorher: Segen der Macht, Vergeltungsaura · 5 und 2 zum Eröffnen · 1 an (unter 20 oder Einhand: 8) · 2 bei Abklingen · 3 bei Abklingen · 4 bei mehreren · Entfesselter Zorn 3 Stapel: 8 statt 1 · 6 gegen Untote · 7 unter 20 %",
            {"Stärke", "Ausdauer", "Zauberschaden"},
            {[1] = {{20066, "Buße"}, {1310735, "Zorn"}}}),
    },
    buffs = {{ids = {19740}, also = {19742, 20217, 1038, 19977, 20911}}, {ids = {465}, also = {7294, 19746, 19876, 19888, 19891, 20218}}},
    tips = {
        {function() return true end, "Immer ein Siegel aktiv halten – Urteil verbraucht es, danach gleich wieder an."},
        {function(p) return p.spec == 3 end, "Vergeltung: Zweihandwaffe – ihre Spezialisierung verstärkt jetzt auch Heiligschaden (Siegel, Urteil, Weihe)."},
    },
}

-- ===== Schamane =====
local SHAMAN_SHARED = {
    {title = "Notfall & Heilung", bar = 2, slots = {
        {8004, "Schnell"}, {331, "Viel"}, {1064, "Kettenheilung"}, {2645, "Geisterwolf"}, {2484, "Erdbindung"},
        {8143, "Erdstoß"}, {5394, "Heilung"}}},
    {title = "Hilfe", bar = 3, slots = {
        {324, "Schild"}, {8017, "Felsbeißer"}, {8024, "Flamme"}, {8232, "Windzorn"}, {8071, "Steinhaut"},
        {5675, "Manaquelle"}, {526, "Gift weg"}, {2008, "Beleben"}, {556, "Rückruf"}}},
}
-- Lavaeruption ist neu in Forever (Nummer aus dem Katalog, erste bekannte gewinnt)
local SHAMAN_ELE = {{403, "Füller"}, {{1238299, 1238300}, "Lava"}, {8050, "Dauer"}, {8042, "Unterbrechen"}, {421, "Mehrere"},
    {3599, "Totem"}, {8056, "Bremsen"}, {1535, "Nova"}}
local SHAMAN_ENH = {{403, "Ziehen"}, {17364, "Sturmschlag"}, {8050, "Dauer"}, {8042, "Füller"}, {3599, "Totem"},
    {8075, "Stärke"}, {1535, "Mehrere"}, {8056, "Bremsen"}}
local SHAMAN_COMBAT = {{403, "Start"}, {8042, "Unterbrechen"}, {8050, "Dauer"}, {8056, "Bremsen"}, {421, "Mehrere"},
    {17364, "Sturmschlag"}, {3599, "Totem"}, {8075, "Stärke"}}
Data.classes.SHAMAN = {
    name = "Schamane", specs = {"Elementar", "Verstärkung", "Wiederherstellung"}, defaultSpec = 2,
    roles = {"caster", "melee", "healer"},
    specNotes = {
        "Fernkampf mit Lavaeruption und Flammenschock, viel Schaden · Auslöser schwanken, braucht viel Mana.",
        "Bester Weg zum Leveln: starker Nahkampf, beweglich, mit Schild sogar kleine Dungeons tanken · weniger Heilung.",
        "Gruppenheiler mit Totems und Kettenheilung · zum Leveln allein zäh – besser ab 40 als zweite Ausrichtung.",
    },
    build = {
        [1] = Build(SHAMAN_ELE, SHAMAN_SHARED, "Vorher: Blitzschlagschild · 6 stellen · 2 zum Ziehen · 3 sofort, dann halten · 2 bei Abklingen · 1 Füller · 4 bei Zaubern · bei mehreren: Magmatotem, 8 bei Abklingen, 5 solange Mana reicht",
            {"Zauberschaden", "Intelligenz", "Kritische Treffer"},
            {[1] = {{16166, "Beherrschung"}}}),
        [2] = Build(SHAMAN_ENH, SHAMAN_SHARED, "Vorher: Blitzschlagschild, Windzorn-Waffe · 5 und 6 stellen · 1 zum Ziehen · 3 halten, kurz vor Ablauf erneuern · 2 bei Abklingen, gleich danach 4 (Sturmschlag macht den nächsten Schock oder Blitz 20 % stärker) · sonst 4 als Füller · Mahlstrom 5 Stapel (kommt seltener): 1 sofort · 7 bei mehreren",
            {"Stärke", "Angriffskraft", "Trefferchance"},
            {[1] = {{425336, "Tempo"}}}),
        [3] = Build(SHAMAN_COMBAT, SHAMAN_SHARED, "Vorher: Wasserschild · 1 Start · 3 · Heilen: Springflut zuerst, dann Leiste 2 · Kettenheilung bei mehreren · Totem der Manaquelle",
            {"Intelligenz", "Willenskraft", "Ausdauer"},
            {[2] = {{408521, "Springflut"}, {16188, "Sofort"}}, [3] = {{408510, "Wasserschild"}, {16190, "Manaflut"}}}),
    },
    buffs = {{ids = {324}, also = {408510}}},
    tips = {
        {function() return true end, "Waffenverzauberung (Felsbeißer, später Flammenzunge/Windzorn) vor jedem Kampf prüfen."},
        {function(p) return p.spec == 2 end, "Verstärkung: langsame Zweihandwaffe mit Windzorn-Waffe · Stärke und Angriffskraft zählen am meisten, Intelligenz gibt nur noch so viel Angriffskraft wie sie selbst hat."},
    },
}

-- ===== Druide =====
local DRUID_SHARED = {
    {title = "Notfall & Heilung", bar = 2, slots = {
        {8936, "Schnell"}, {5185, "Viel"}, {774, "Dauer"}, {22812, "Rinde"}, {20484, "Wiedergeburt"},
        {2637, "Schlaf"}, {1850, "Spurt"}, {29166, "Anregen"}}},
    {title = "Hilfe", bar = 3, slots = {
        {1126, "Mal"}, {467, "Dornen"}, {2782, "Fluch weg"}, {8946, "Gift weg"}, {783, "Reisen"},
        {1066, "Wasser"}, {18960, "Mondlichtung"}, {770, "Feenfeuer"}}},
}
local DRUID_BALANCE = {{8921, "Dot"}, {2912, "Haupt"}, {5176, "Füller"}, {339, "Fesseln"}, {16914, "Mehrere"},
    {5487, "Bär"}, {768, "Katze"}, {24858, "Mondkin"}}
local DRUID_COMBAT = {{5176, "Start"}, {8921, "Dauer"}, {339, "Fesseln"}, {5487, "Bär"}, {768, "Katze"},
    {2912, "Sternenfeuer"}, {16914, "Hurrikan"}, {24858, "Mondkin"}}
-- Gestalt-Leisten: ersetzen in Katzen-/Baerengestalt die Leiste 1 (Tasten 1-12).
-- Talent-Plaetze = neue Forever-Faehigkeiten (Auslese 14.11.2026, "Benoetigt ...gestalt").
local DRUID_FORMS = {
    {title = "Katzengestalt", bar = 7, flow = "1 vor dem Angriff · 2 von hinten aus 1 · 4 halten · 5 (von hinten) oder 3 sammelt Punkte · 6 bei 5 Punkten · 7 bei 4–5 Punkten und 70 Energie · 9 unter 50 Energie · 8 sobald bereit",
        slots = {{5215, "Schleichen"}, {6785, "Öffner"}, {1082, "Klaue"}, {1822, "Blutung"}, {5221, "Schreddern"},
            {1079, "Zerfetzen"}, {22568, "Biss"}, {5217, "Tigerfuror"},
            {1322605, "Energie", talent = true}, {16857, "Feenfeuer", talent = true}}},
    {title = "Bärengestalt", bar = 9, flow = "9 zum Heranspringen · 4 halten · 10 bei Abklingen · 11 auf 5 Stapel · 2 einzeln · 3 bei mehreren · 1 wenn ein Gegner wegläuft",
        slots = {{6795, "Spott"}, {6807, "Zermalmen"}, {779, "Prankenhieb"}, {99, "Gebrüll"}, {5229, "Wutanfall"},
            {5211, "Hieb"}, {22842, "Regeneration"}, {5209, "Alle spotten"},
            {1238122, "Attacke", talent = true}, {407995, "Biss", talent = true}, {1328617, "Aufschlitzen", talent = true}}},
}
Data.classes.DRUID = {
    name = "Druide", specs = {"Gleichgewicht", "Wilder Kampf", "Wiederherstellung"}, defaultSpec = 2,
    roles = {"caster", "agile", "healer"},
    specNotes = {
        "Fernkampf mit DoTs und Sternenfeuer, gute Hilfe für die Gruppe, ab 40 Mondkin · kein Burst, lange Zauber.",
        "Bester Weg zum Leveln: Katze für Schaden, Bär zum Tanken, sehr beweglich · viele Ressourcen, schwer zu meistern.",
        "Starke Heilung über Zeit, gut für die Gruppe · zum Leveln allein nicht empfohlen, braucht Vorlauf.",
    },
    build = {
        [1] = Build(DRUID_BALANCE, DRUID_SHARED, "Vorher: Mal der Wildnis, Dornen · 1 · 9 halten · 2, 2, 3 im Wechsel · Freizauber: 2 · 5 bei 5+ Gegnern · ab 40 in 8 bleiben",
            {"Zauberschaden", "Intelligenz", "Willenskraft"},
            {[1] = {{5570, "Schwarm"}}}, DRUID_FORMS),
        [2] = Build(DRUID_COMBAT, DRUID_SHARED, "Vorher: Mal der Wildnis, Dornen · 1 und 2 vorher · dann 5 Katze oder 4 Bär · Heilen: zurück in Normalgestalt",
            {"Stärke", "Beweglichkeit", "Ausdauer"}, nil, DRUID_FORMS),
        [3] = Build(DRUID_COMBAT, DRUID_SHARED, "Vorher: Mal der Wildnis, Dornen · 1 und 2 · Heilen: Leiste 2 · Dauer-Heilung zuerst",
            {"Intelligenz", "Willenskraft", "Ausdauer"},
            {[2] = {{408120, "Wildwuchs"}, {18562, "Rasch"}, {17116, "Sofort"}}}, DRUID_FORMS),
    },
    buffs = {{ids = {1126}, also = {21849}}, {ids = {467}}},
    tips = {
        {function() return true end, "Katzen- und Bärenleiste: oben auf „Gestalten“ klicken. „Leisten einrichten“ belegt sie mit."},
    },
}

local druid = Data.classes.DRUID.build
druid[1].situations = {
    dungeon = {flow = "Tank zieht zuerst · 1 und 9 aufs Ziel · 2 als Hauptzauber · 5 bei vielen · Anregen auf den Heiler"},
    raid = {flow = "8 · 1 und 9 halten · 2, 2, 3 · Freizauber: 2 · Anregen auf den Heiler"},
}
druid[2].situations = {
    dungeon = {flow = "Als Tank: Bärengestalt (Leiste Gestalten) · Gebrüll halten · Biss bei Abklingen · Aufschlitzen auf 5 · Prankenhieb bei mehreren"},
    raid = {flow = "Katze hinter dem Boss · Feenfeuer halten · Krallenhieb halten · Zerfetzen bei 5 Punkten · Schreddern · Machtverschiebung unter 50 Energie"},
}
druid[3].situations = {
    dungeon = {flow = "Verjüngung auf den Tank · Rasche Heilung, wenn Verjüngung drauf ist · Nachwachsen bei viel Schaden · Wildwuchs bei Gruppenschaden – heilt jetzt doppelt so stark, nur im Stehen"},
    raid = {flow = "Verjüngung verteilt halten · Wildwuchs bei Gruppenschaden, alle 6 s (nur im Stehen) · Rasche Heilung im Notfall · Schnelligkeit der Natur + Wildwuchs = sofort"},
}
druid[1].talents = { -- Gleichgewicht
    {16814, 5}, {16845, 3}, {16821, 2}, {1223083, 1}, {16819, 2}, {16918, 2}, {5570, 1}, {16850, 4},
    {408248, 3}, {17245, 2}, {16896, 5}, {24858, 1}, {1223081, 5}, {16850, 5}, {16909, 4},
    {17063, 5}, {17069, 5},
}
druid[2].talents = { -- Wilder Kampf (Katze und Baer)
    {16934, 5}, {16929, 3}, {16940, 2}, {1238122, 1}, {16942, 2}, {16998, 2}, {1328617, 1}, {1328613, 1},
    {16972, 3}, {17007, 1}, {1223242, 2}, {16958, 2}, {1223246, 5}, {407995, 1}, {1322605, 1}, {417051, 5},
    {16814, 5}, {16819, 2}, {16845, 2}, {17003, 5},
}
druid[3].talents = { -- Wiederherstellung
    {17063, 5}, {17106, 3}, {17069, 2}, {1328621, 1}, {17104, 4}, {18562, 1}, {17111, 3}, {24968, 1},
    {17116, 1}, {17123, 2}, {1309631, 2}, {17074, 5}, {408120, 1}, {17104, 5}, {17069, 5}, {24968, 4},
    {16814, 5}, {16845, 3}, {16819, 2}, {1223083, 1}, {16821, 2},
}

local shaman = Data.classes.SHAMAN.build
shaman[1].situations = {
    dungeon = {flow = "Tank zieht zuerst · Totem der Manaquelle · 3 halten · 2 bei Abklingen · 1 Füller · Magmatotem und 8 bei mehreren · 4 bei Zaubern"},
    raid = {flow = "Totems nach Absprache · 3 halten · 2 bei Abklingen · 1 Füller · 9 mit Abklingzeiten"},
}
shaman[2].situations = {
    dungeon = {flow = "Tank zieht zuerst · Windzorn-Totem für Nahkämpfer (wirkt zusätzlich zur Windzorn-Waffe) · 2 bei Abklingen, gleich danach 4 · 3 halten · 4 bei Zaubern unterbrechen"},
    raid = {flow = "Windzorn-Totem in die Nahkampfgruppe (wirkt zusätzlich zur Windzorn-Waffe) · 2 bei Abklingen, gleich danach 4 · 3 halten · Mahlstrom 5 Stapel: 1 sofort"},
}
shaman[3].situations = {
    dungeon = {flow = "Wasserschild · Totem der Manaquelle oder Heilender Fluss · Springflut zuerst · Welle der Heilung als Standard · Geringe Welle im Notfall · Kettenheilung bei Gruppenschaden"},
    raid = {flow = "Springflut auf den Tank · Kettenheilung bei Gruppenschaden · Totem der Manaflut bei wenig Mana · Schnelligkeit der Natur im Notfall"},
}
shaman[1].talents = { -- Elementar
    {16035, 5}, {16038, 3}, {30160, 2}, {16164, 1}, {16039, 4}, {1222988, 1}, {16086, 2}, {29062, 2},
    {16120, 1}, {408438, 3}, {28999, 1}, {16089, 5}, {16166, 1}, {16039, 5}, {30160, 3}, {28996, 3},
    {28999, 2}, {29062, 3}, {16179, 5}, {16173, 5}, {29187, 3},
}
shaman[2].talents = { -- Verstaerkung
    {17485, 5}, {16255, 5}, {415140, 3}, {16266, 2}, {16256, 5}, {17364, 1}, {16268, 1}, {1223031, 2},
    {30812, 1}, {408498, 5}, {425336, 1}, {16252, 5}, {16262, 2}, {16266, 3}, {16254, 3}, {30812, 2},
    {16035, 5}, {16038, 3},
}
shaman[3].talents = { -- Wiederherstellung
    {16179, 5}, {16182, 5}, {408510, 1}, {16176, 3}, {16173, 1}, {16194, 5}, {16190, 1}, {16188, 1},
    {29206, 3}, {16178, 5}, {408521, 1}, {16187, 5}, {29187, 3}, {16173, 5}, {16035, 5}, {16038, 3},
}

local paladin = Data.classes.PALADIN.build
paladin[1].situations = {
    dungeon = {flow = "Segen verteilen · Lichtblitz als Standard · Heiliger Schock im Notfall · Heiliges Licht bei viel Schaden · Läutern gegen Gift und Krankheit"},
    raid = {flow = "Lichtblitz auf die Tanks · Heiliger Schock in Bewegung · Göttliche Gunst für einen sicheren Krit · Segen nach Absprache"},
}
paladin[2].situations = {
    dungeon = {flow = "Zorn der Gerechtigkeit an · 4 sofort · 1 · 2 · 3 · 9 bei Abklingen · 6 gegen Untote · etwa vier Gegner je Zug, vom Heiler wegdrehen"},
    raid = {flow = "Zorn der Gerechtigkeit an · 9 und 2 bei Abklingen · 3 · 4 bei mehreren · Segen nach Absprache"},
}
paladin[3].situations = {
    dungeon = {flow = "Tank zieht zuerst · 5 und 2 zum Eröffnen · 1 an · 2 · 3 bei Abklingen · 4 bei mehreren · 6 gegen Untote · 7 unter 20 % · Segen der Macht verteilen"},
    raid = {flow = "5 per Urteil nach Absprache · 1 an · 3 und 2 bei Abklingen · Entfesselter Zorn 3 Stapel: 8 statt 1 · 7 unter 20 %"},
}
paladin[1].talents = { -- Heilig (Schock-Paladin)
    {20262, 5}, {20224, 5}, {20210, 5}, {20216, 1}, {426065, 2}, {1328548, 1}, {1310904, 1}, {1311606, 1},
    {1328550, 2}, {1310905, 2}, {5923, 5}, {1310911, 1}, {20237, 3}, {20205, 5}, {1310899, 2}, {1237268, 2},
    {20060, 5}, {25956, 2}, {20117, 1},
}
paladin[2].talents = { -- Schutz
    {20127, 5}, {20189, 3}, {20174, 2}, {20143, 5}, {20096, 5}, {1310994, 1}, {20925, 1}, {20177, 3},
    {1311034, 3}, {1328546, 2}, {1328544, 1}, {1311015, 1}, {20468, 3}, {20177, 5}, {1224697, 2}, {20257, 5},
    {20060, 5}, {25956, 2},
}
paladin[3].talents = { -- Vergeltung
    {20060, 5}, {25956, 2}, {20117, 3}, {20375, 1}, {26022, 2}, {9452, 2}, {20111, 3}, {1311087, 1},
    {1311074, 1}, {20066, 1}, {20049, 3}, {1328370, 1}, {1311084, 5}, {1310735, 1}, {1311074, 3}, {9452, 3},
    {20101, 5}, {9453, 2}, {1328370, 2}, {20262, 5}, {20224, 4},
}

-- ===== Tasten in Ablauf-Reihenfolge (15.11.2026, Nutzer-Wunsch) =====
-- Leiste 1 wird je Ausrichtung so umgeordnet, dass der Ablauf einfach 1, 2, 3 … ist.
-- Die Bauplaene oben behalten ihre Nummern; beim Laden wird umsortiert und jede
-- Platznummer in den Ablauf-Texten (Leveln/Dungeon/Raid) per slotMap umgeschrieben.
-- Talent-Plaetze (9-11) bleiben, Zahlen wie "Stufe 20", "5 Stapel", "Leiste 2" bleiben.
local KEY_OVERRIDE = {
    MAGE = {[1] = {1, 2, 3, 6, 4, 5, 7, 8}},      -- Arkan: vor Stufe 20 ist Frostblitz der Hauptzauber
    ROGUE = {[1] = {1, 6, 2, 4, 3, 7, 5, 8}, [3] = {1, 6, 3, 4, 2, 5, 7, 8}}, -- Verstohlenheit zuerst
}
-- Ist die Zahl an dieser Stelle ein Platz-Bezug? (nicht "Stufe 20", "5 Stapel", "3x" …)
function Data.IsSlotRef(text, s, e, n, fixed)
    if n < 1 or n > fixed then return false end
    local before, after = text:sub(1, s - 1), text:sub(e + 1)
    if after:match("^%s*[%%+%-]") or after:match("^%s*–") or after:match("^x[%s%)]") or after:match("^%s+Punkt") or after:match("^%s+Stapel") or after:match("^%s+Energie")
        or after:match("^%s+Ladung") then return false end
    if before:match("Stufe%s*$") or before:match("Leiste%s*$") or before:match("bis%s*$") or before:match("[%d%.]$")
        or before:match("ab%s*$") or before:match("unter%s*$") or before:match("auf%s*$") then return false end
    return true
end
-- Alle Platz-Bezuege eines Ablaufs in Reihenfolge des ersten Auftretens
function Data.FlowSlots(flow, fixed)
    local order, seen = {}, {}
    flow = (flow or ""):gsub("^Vorher:[^·]*·%s*", "")
    local pos = 1
    while true do
        local s, e, num = flow:find("(%d+)", pos)
        if not s then break end
        local n = tonumber(num)
        if Data.IsSlotRef(flow, s, e, n, fixed) and not seen[n] then seen[n] = true order[#order + 1] = n end
        pos = e + 1
    end
    return order
end
-- Zahlen eines (auch uebersetzten) Ablauf-Texts auf die neuen Plaetze umschreiben
function Data.RemapFlow(text, map, fixed)
    if type(text) ~= "string" or not map then return text end
    local out, pos = {}, 1
    while true do
        local s, e, num = text:find("(%d+)", pos)
        if not s then break end
        out[#out + 1] = text:sub(pos, s - 1)
        local n = tonumber(num)
        out[#out + 1] = (Data.IsSlotRef(text, s, e, n, fixed) and map[n]) and tostring(map[n]) or num
        pos = e + 1
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out)
end
function Data.ApplyKeyOrder()
    for cls, def in pairs(Data.classes) do
        for spec, b in pairs(def.build or {}) do
            local bar = b.bars and b.bars[1]
            if bar and not b.slotMap then
                local fixed, fixedSlots, talentSlots = 0, {}, {}
                for _, st in ipairs(bar.slots) do
                    if st.talent then talentSlots[#talentSlots + 1] = st else fixed = fixed + 1 fixedSlots[fixed] = st end
                end
                local order = KEY_OVERRIDE[cls] and KEY_OVERRIDE[cls][spec]
                if not order then
                    order = Data.FlowSlots(b.flow, fixed)
                    local used = {}
                    for _, n in ipairs(order) do used[n] = true end
                    for i = 1, fixed do if not used[i] then order[#order + 1] = i end end
                end
                local slots, map = {}, {}
                for newPos, oldPos in ipairs(order) do slots[newPos] = fixedSlots[oldPos] map[oldPos] = newPos end
                for _, st in ipairs(talentSlots) do slots[#slots + 1] = st end
                -- neue Tabelle: gemeinsame Kampfleisten anderer Ausrichtungen bleiben unberuehrt
                local newBar = {}
                for k, v in pairs(bar) do newBar[k] = v end
                newBar.slots = slots
                b.bars[1] = newBar
                b.slotMap, b.slotFixed = map, fixed
            end
        end
    end
end
Data.ApplyKeyOrder()

-- ===== Raid-Skillungen Stufe 60 (19.11.2026, VORLAEUFIG bis zur Raid-Oeffnung am 9.12.2026) =====
-- Talentwahl aus foreverspec.com (Stand 13.11.2026, Live 1.60.1.70790) als Fakten; Talentnummern ueber die
-- Spieltabellen von Forever 1.60.1.70959 (wago.tools, scripts/raid_talents.py), je 51 Punkte geprueft.
-- Gilt in der Situation "Raid" (in Schlachtzuegen automatisch); Text-Hinweis talentsNote im Klassen-Reiter.
local RAID_NOTE = "Raid-Skillung vorläufig – Stand vor der Raid-Öffnung am 9.12."
paladin[1].situations.raid.talents = {{20205, 5}, {20257, 5}, {20101, 5}, {20237, 3}, {1310899, 2}, {429144, 2}, {20189, 1}, {20174, 2}, {1224697, 2}, {20117, 3}, {20216, 1}, {20210, 5}, {1311015, 1}, {1310904, 2}, {426065, 2}, {1328548, 1}, {1311606, 1}, {1328550, 2}, {5923, 5}, {1310911, 1}}  -- Heilig 32/11/8
paladin[1].situations.raid.talentsNote = RAID_NOTE
druid[3].situations.raid.talents = {{1223081, 5}, {17003, 5}, {16845, 3}, {1223082, 2}, {17069, 5}, {17106, 3}, {1223083, 1}, {17104, 5}, {1328621, 1}, {24968, 5}, {17111, 3}, {18562, 1}, {17116, 1}, {1309631, 3}, {17123, 2}, {17074, 5}, {408120, 1}}  -- Wiederherstellung 11/0/40
druid[3].situations.raid.talentsNote = RAID_NOTE
druid[2].situations.raid.talents = {{16934, 5}, {17056, 3}, {17003, 5}, {17002, 2}, {16947, 3}, {16929, 3}, {17069, 5}, {16998, 2}, {1238122, 1}, {16942, 2}, {16972, 3}, {1328617, 1}, {16958, 2}, {17007, 1}, {1223242, 2}, {1223246, 5}, {417051, 5}, {407995, 1}}  -- Baer (Tank) 0/41/10
druid[2].situations.raid.talentsNote = RAID_NOTE .. " (Bär/Tank)"
shaman[3].situations.raid.talents = {{16255, 5}, {17485, 5}, {16182, 5}, {16179, 5}, {1223033, 3}, {16176, 3}, {16181, 3}, {408510, 1}, {16194, 5}, {16187, 5}, {16190, 1}, {29206, 3}, {16188, 1}, {16178, 5}, {408521, 1}}  -- Wiederherstellung 0/10/41
shaman[3].situations.raid.talentsNote = RAID_NOTE
warrior[3].situations.raid.talents = {{12320, 5}, {12301, 2}, {12298, 5}, {12322, 5}, {12297, 5}, {12797, 3}, {12287, 3}, {12975, 1}, {1310316, 2}, {12792, 3}, {12308, 3}, {12311, 2}, {12312, 2}, {12809, 1}, {29787, 3}, {16538, 5}, {23922, 1}}  -- Schutz 0/10/41
warrior[3].situations.raid.talentsNote = RAID_NOTE

-- Schadensklassen (gleiche Quelle/Version, je 51 Punkte geprueft; Taeuschung: Seite hat keine Raid-Skillung,
-- dort deren Stufe-60-Plan). Priester Disziplin/Schatten stehen in Data.lua.
local function Raid(spec, talents, note)
    spec.situations = spec.situations or {}
    spec.situations.raid = spec.situations.raid or {}
    spec.situations.raid.talents = talents
    spec.situations.raid.talentsNote = note or RAID_NOTE
end
Raid(paladin[2], {{20127, 5}, {20101, 5}, {20189, 3}, {1224697, 2}, {25956, 2}, {20117, 3}, {1311074, 3}, {1311015, 1}, {20150, 2}, {20143, 5}, {26022, 2}, {1310994, 1}, {20468, 3}, {20096, 5}, {1311087, 1}, {20925, 1}, {20177, 3}, {1311034, 3}, {1328544, 1}}, RAID_NOTE .. " (Schutz/Tank)")
Raid(paladin[3], {{20262, 5}, {20257, 5}, {20101, 5}, {20224, 5}, {20189, 3}, {25956, 2}, {20117, 3}, {1311074, 3}, {1237268, 2}, {9452, 1}, {20375, 1}, {26022, 2}, {1311087, 1}, {20111, 3}, {20066, 1}, {20049, 3}, {1311084, 5}, {1310735, 1}})
Raid(warrior[1], {{12282, 3}, {12286, 3}, {12321, 5}, {12320, 5}, {12295, 3}, {12290, 2}, {12322, 5}, {12296, 1}, {12834, 3}, {12317, 2}, {12163, 3}, {16493, 2}, {1329555, 1}, {20502, 2}, {1289682, 2}, {12292, 1}, {1290261, 5}, {12862, 2}, {12294, 1}})
Raid(warrior[2], {{12282, 3}, {12286, 3}, {12321, 4}, {12320, 5}, {12295, 3}, {12290, 2}, {12322, 5}, {12296, 1}, {12834, 3}, {1323963, 3}, {16493, 2}, {23584, 5}, {1329555, 1}, {20502, 2}, {20500, 2}, {12328, 1}, {1310315, 2}, {12319, 3}, {23881, 1}})
Raid(rogue[1], {{14138, 5}, {14162, 3}, {13712, 2}, {14156, 3}, {14165, 3}, {1224716, 3}, {13705, 3}, {13743, 2}, {14983, 2}, {14128, 2}, {13742, 2}, {16513, 5}, {14177, 1}, {14113, 5}, {14179, 5}, {1329328, 1}, {14186, 3}, {399956, 1}})
Raid(rogue[2], {{14138, 5}, {14162, 3}, {13732, 2}, {14156, 3}, {14165, 3}, {13713, 3}, {13705, 3}, {13743, 2}, {14983, 2}, {14128, 2}, {13742, 2}, {14251, 1}, {1310711, 1}, {30919, 2}, {18427, 3}, {13715, 2}, {13877, 1}, {13960, 5}, {1329284, 5}, {13750, 1}})
Raid(rogue[3], {{14144, 2}, {14138, 5}, {14057, 5}, {14156, 3}, {14165, 3}, {14082, 2}, {13975, 1}, {14079, 3}, {14983, 2}, {14128, 2}, {13976, 3}, {14183, 1}, {14171, 3}, {14177, 1}, {14113, 2}, {13981, 2}, {14278, 1}, {30894, 2}, {14185, 1}, {16511, 1}, {1329286, 5}, {1316709, 1}}, "Stufe-60-Skillung (keine eigene Raid-Skillung bekannt) – vorläufig bis zur Raid-Öffnung am 9.12.")
Raid(hunter[1], {{19552, 5}, {19583, 3}, {19426, 5}, {1223755, 2}, {19416, 3}, {1223984, 5}, {19596, 1}, {19616, 5}, {415405, 2}, {19598, 5}, {1293241, 1}, {1299346, 1}, {19485, 4}, {19577, 1}, {19590, 2}, {19621, 5}, {19574, 1}})
Raid(hunter[2], {{19426, 5}, {24293, 5}, {1310661, 3}, {19416, 5}, {1223984, 5}, {19255, 5}, {415405, 2}, {415370, 1}, {19290, 3}, {1299346, 1}, {19485, 5}, {1223987, 2}, {19461, 3}, {19507, 5}, {1310687, 1}})
Raid(hunter[3], {{19426, 5}, {24293, 5}, {19416, 3}, {1223984, 5}, {19159, 2}, {19255, 3}, {415405, 2}, {19239, 2}, {19290, 3}, {1299346, 1}, {19485, 4}, {1310627, 5}, {440529, 2}, {1310532, 2}, {1317257, 1}, {19168, 5}, {1310533, 1}})
Raid(mage[1], {{11237, 5}, {18459, 5}, {11069, 5}, {29438, 3}, {11210, 2}, {29441, 2}, {11213, 5}, {400588, 2}, {11247, 2}, {11242, 3}, {400574, 1}, {11255, 2}, {18462, 3}, {1326079, 1}, {12043, 1}, {11232, 5}, {15058, 3}, {12042, 1}})
Raid(mage[2], {{11237, 5}, {18459, 5}, {11069, 5}, {29438, 3}, {11213, 5}, {400588, 2}, {11119, 5}, {400574, 1}, {11083, 3}, {11366, 1}, {11078, 2}, {11095, 3}, {400624, 1}, {29074, 3}, {11115, 3}, {11124, 3}, {11129, 1}})
Raid(mage[3], {{11237, 5}, {11070, 5}, {29438, 3}, {11210, 2}, {11213, 5}, {400588, 2}, {11207, 5}, {11247, 1}, {11160, 3}, {1312002, 1}, {18462, 3}, {16757, 1}, {11170, 3}, {11190, 3}, {12472, 1}, {400647, 2}, {11180, 5}, {11426, 1}})
Raid(warlock[1], {{18182, 2}, {18174, 5}, {17810, 5}, {17793, 5}, {17788, 5}, {17778, 3}, {18827, 2}, {427712, 3}, {17959, 5}, {1310949, 5}, {18094, 2}, {17927, 3}, {18265, 1}, {18271, 5}})
Raid(warlock[2], {{18174, 1}, {17810, 1}, {18697, 2}, {18769, 5}, {17793, 5}, {17788, 5}, {18731, 3}, {1225214, 2}, {18754, 3}, {18788, 1}, {17959, 5}, {440870, 2}, {1293695, 3}, {17927, 3}, {19028, 1}, {412732, 3}, {23785, 5}, {425464, 1}})
Raid(warlock[3], {{18174, 5}, {17810, 5}, {17793, 5}, {17788, 5}, {17778, 2}, {18288, 1}, {18827, 2}, {427712, 3}, {17959, 5}, {17877, 1}, {1310949, 5}, {17927, 3}, {1293817, 1}, {412751, 3}, {426316, 5}})
Raid(shaman[1], {{16039, 5}, {16035, 5}, {16255, 5}, {16179, 5}, {16040, 2}, {16578, 3}, {16038, 3}, {1223033, 3}, {29187, 3}, {16164, 1}, {408510, 1}, {29062, 3}, {28999, 2}, {16120, 1}, {408438, 3}, {16089, 5}, {16166, 1}})
Raid(shaman[2], {{16035, 5}, {16255, 5}, {17485, 4}, {16179, 5}, {30160, 3}, {415140, 3}, {1223033, 3}, {16266, 3}, {1223030, 1}, {16256, 5}, {17364, 1}, {16262, 2}, {16268, 1}, {30812, 2}, {1223031, 2}, {408498, 5}, {425336, 1}})
Raid(druid[1], {{16814, 5}, {1223081, 5}, {17003, 5}, {16845, 3}, {16821, 2}, {1223082, 2}, {16819, 2}, {17069, 5}, {1223083, 1}, {5570, 1}, {16909, 5}, {16850, 5}, {16880, 1}, {408248, 3}, {16896, 5}, {24858, 1}})
