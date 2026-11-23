local _, classes = ...

-- Klassen-Ratgeber: Bauplaene je Klasse und Ausrichtung.
-- Nur Zauber-Nummern (ein beliebiger Rang) und Stichworte. Namen, Symbole,
-- Raenge und Zahlen holt die Seite aus dem Zauberbuch des Spielers; der
-- Tooltip zeigt beim Drueberfahren die echten Forever-Werte.
-- Stand: Forever 1.60.1, ausgelesen am 13.11.2026 (siehe docs/KLASSEN_RATGEBER.md).
--
-- Aktionsleisten (Ergonomie):
--   Leiste 1 (Tasten 1-8): Kampf. Was in jedem Kampf gedrueckt wird, liegt auf
--     1-5 direkt neben WASD; Seltenes weiter rechts.
--   Leiste 2: Notfall und Heilung – getrennt, damit man sie nie aus Versehen drueckt.
--   Leiste 3: Hilfe ausserhalb des Kampfes (Buffs, Wiederbeleben, Bannen ...).
-- Jeder Zauber hat einen FESTEN Platz. Was erst spaeter gelernt wird, haelt
-- seinen Platz frei – so muss man nie umlernen.
local Data = {}
classes.Data = Data

-- Alle Zauber-Nummern eines Eintrags (eine Nummer oder eine Liste).
function Data.Ids(id) return type(id) == "table" and id or {id} end

-- Namen, die zum selben Zauber gehoeren (aus Listen-Eintraegen aller Bauplaene):
-- Name -> fester gemeinsamer Schluessel ("#" .. erste Nummer der Liste).
function Data:AliasNames()
    local alias = {}
    for _, def in pairs(self.classes) do
        for _, build in pairs(def.build) do
            for _, bar in ipairs(Data.AllBars(build)) do
                for _, step in ipairs(bar.slots) do
                    if type(step[1]) == "table" then
                        local key = "#" .. tostring(step[1][1])
                        for _, id in ipairs(step[1]) do
                            local name = classes.Player.SpellInfo(id)
                            if name then alias[name] = key end
                        end
                    end
                end
            end
        end
    end
    return alias
end

Data.WAND = 5019 -- "Schiessen" (Zauberstab)

-- Aktions-Slots der Blizzard-Leisten (Leiste 1 = 1-12, Leiste 2 = unten links
-- 61-72, Leiste 3 = unten rechts 49-60)
Data.barSlots = {[1] = 1, [2] = 61, [3] = 49, [7] = 73, [9] = 97}
-- Gestalt-Leisten (Druide): in Katzengestalt ersetzt WoW Leiste 1 durch die
-- Plaetze 73-84, in Baerengestalt durch 97-108. Nur Bauplaene mit "forms"
-- nutzen sie – bei Kriegern liegen dort die Haltungsleisten (nie anfassen).
Data.formBars = {[7] = true, [9] = true}

-- Alle Leisten eines Bauplans: normale + Gestalt-Leisten
function Data.AllBars(build)
    local list = {}
    for _, bar in ipairs(build and build.bars or {}) do list[#list + 1] = bar end
    for _, bar in ipairs(build and build.forms or {}) do list[#list + 1] = bar end
    return list
end
Data.barFrames = {[2] = "MultiBarBottomLeft", [3] = "MultiBarBottomRight"}

local PRIEST_HELP = {title = "Hilfe", bar = 3, slots = {
    {1243, "Ausdauer"}, {588, "Rüstung"}, {976, "Schattenschutz"}, {527, "Bannen"},
    {528, "Krankheit"}, {9484, "Fesseln"}, {453, "Ruhig"}, {2006, "Beleben"},
}}

Data.classes = {
    PRIEST = {
        name = "Priester",
        -- Talentbaum von links nach rechts (Spaltengruppen im C_Traits-Baum)
        specs = {"Disziplin", "Heilig", "Schatten"},
        defaultSpec = 3,
        roles = {"healer", "healer", "caster"},
        specNotes = {
            "Starker Tankheiler mit Schilden und Sühne, gute Hilfe für andere (Seele der Macht) · wenig Bewegung, schwächer bei Gruppenschaden.",
            "Bester Gruppen- und Raidheiler, viele Werkzeuge · wenig Bewegung, Gebet der Besserung etwas zufällig.",
            "Zum Leveln am besten: viel Schaden, kaum Pausen, heilt nebenbei mit Vampirumarmung · in Schattengestalt keine Heilzauber, schwach gegen viele Gegner.",
        },
        build = {
            -- Schatten: alleine leveln
            [3] = {
                flow = "Vorher: Seelenstärke, Inneres Feuer, ab 40 Schattengestalt · 4 vorher · 2 · 7 · 1 · 6 · 3 Füller · Mana: 5",
                bars = {
                    {title = "Kampf", bar = 1, slots = {
                        {8092, "Start"}, {589, "Schmerz"}, {15407, "Füller"}, {17, "Schild"},
                        {Data.WAND, "Sparen"}, {15286, "Umarmung"}, {2944, "Seuche"}, {15473, "Gestalt"},
                        {15487, "Stille", talent = true}}},
                    {title = "Notfall & Heilung", bar = 2, slots = {
                        {1277324, "Mana"}, {8122, "Furcht"}, {586, "Aggro"},
                        {2061, "Schnell"}, {139, "Erneuern"}, {2054, "Viel"}}},
                    PRIEST_HELP,
                },
                stats = {"Willenskraft", "Intelligenz", "Ausdauer"},
                -- Situationen aendern Ablauf, Werte und Tipps – NIE die Plaetze auf den Leisten
                situations = {
                    dungeon = {
                        flow = "Tank zieht zuerst · 2 auf alle · 3 Füller · 1 erst bei sicherer Aggro · Mana knapp: 5",
                        stats = {"Intelligenz", "Ausdauer", "Willenskraft"},
                    },
                    raid = {
                        flow = "Schattengestalt · 2 und Verschlingende Seuche halten · 1 bei Abklingen · Vampirumarmung halten · 3 Füller, nicht abbrechen",
                        stats = {"Intelligenz", "Ausdauer", "Willenskraft"},
                    },
                },
                talents = {
                    -- Reihenfolge mit Reihen-Freischaltung (5 Punkte je Reihe), Kerntalente nach
                    -- Forever-Guide (Gedankenschinden, Vampirumarmung, Schattenwirken, Stille, Schattengestalt)
                    {15270, 5}, -- Willensentzug: Mana nach jedem Kill
                    {15260, 3}, -- Schattenfokus (frueh, sonst fehlt vor Stille ein Punkt fuer Reihe 5)
                    {15275, 2}, -- Verb. Schattenwort: Schmerz
                    {15273, 3}, -- Verb. Gedankenschlag
                    {15407, 1}, -- Gedankenschinden
                    {1225139, 2}, -- Verb. Gedankenschinden
                    {15273, 5},
                    {15257, 3}, -- Schattenwirken
                    {15286, 1}, -- Vampirumarmung
                    {15487, 1}, -- Stille
                    {1309950, 2}, -- Verschlingende Ansteckung
                    {1326159, 3}, -- Dunkle Inspiration
                    {15259, 5}, -- Dunkelheit
                    {15473, 1}, -- Schattengestalt
                    {1225132, 5}, {18551, 5}, {14751, 1}, {14521, 3}, -- Disziplin: Zwillingsdisziplinen, Mentale Staerke, Innerer Fokus, Meditation
                    {14889, 3}, -- Heiligspezialisierung
                },
            },
            -- Heilig: alleine Heiliges Feuer, in der Gruppe heilen
            [2] = {
                flow = "Vorher: Seelenstärke, Inneres Feuer · 4 vorher · 1 Start · 2 · 3 bis tot · Mana knapp: 5",
                bars = {
                    {title = "Kampf", bar = 1, slots = {
                        {14914, "Start"}, {589, "Schmerz"}, {{591, 585}, "Füller"}, {17, "Schild"}, {Data.WAND, "Sparen"},
                        {8092, "Schlag"}, {2944, "Seuche"}}},
                    {title = "Heilung & Notfall", bar = 2, slots = {
                        {139, "Zuerst"}, {2061, "Schnell"}, {2054, "Viel"}, {2050, "Sparsam"}, {596, "Gruppe"},
                        {1277324, "Mana"}, {8122, "Furcht"}, {586, "Aggro"},
                        {401859, "Besserung", talent = true}, {15237, "Nova", talent = true}}},
                    PRIEST_HELP,
                },
                stats = {"Intelligenz", "Willenskraft", "Heilung"},
                situations = {
                    dungeon = {
                        flow = "Schild auf den Tank vor dem Pull · Erneuern auf den Tank · Schnell bei Gefahr · Viel bei großem Schaden",
                        stats = {"Intelligenz", "Willenskraft", "Heilung"},
                    },
                    raid = {
                        flow = "Gebet der Besserung bei Abklingen · Erneuerung auf viele · Gruppenheilung bei Gruppenschaden · Zauber abwechseln (Litanei des Lichts)",
                        stats = {"Heilung", "Intelligenz", "Willenskraft"},
                    },
                },
            },
            -- Disziplin: wie Heilig, dazu Suehne
            [1] = {
                flow = "Vorher: Seelenstärke, Inneres Feuer · 4 vorher · 1 Start · 2 · 6 bei Abklingen · 3 · Mana knapp: 5",
                bars = {
                    {title = "Kampf", bar = 1, slots = {
                        {14914, "Start"}, {589, "Schmerz"}, {{591, 585}, "Füller"}, {17, "Schild"}, {Data.WAND, "Sparen"},
                        {402174, "Sühne"}, {8092, "Schlag"}, {2944, "Seuche"}}},
                    {title = "Heilung & Notfall", bar = 2, slots = {
                        {17, "Zuerst"}, {139, "Dazu"}, {2061, "Schnell"}, {2054, "Viel"}, {596, "Gruppe"},
                        {1277324, "Mana"}, {8122, "Furcht"}, {586, "Aggro"},
                        {14751, "Fokus", talent = true}, {10060, "Macht", talent = true}}},
                    PRIEST_HELP,
                },
                stats = {"Intelligenz", "Willenskraft", "Ausdauer"},
                situations = {
                    dungeon = {
                        flow = "Schild auf den Tank · Erneuern dazu · 6 Sühne für Schaden und Heilung · Schnell bei Gefahr",
                        stats = {"Intelligenz", "Willenskraft", "Ausdauer"},
                    },
                    raid = {
                        flow = "Schild und Erneuerung auf die Tanks · Sühne · Seele der Macht auf den stärksten Zauberer · Große Heilung mit Innerer Fokus",
                        stats = {"Intelligenz", "Heilung", "Willenskraft"},
                    },
                },
            },
        },
        -- (Talentplaene Disziplin/Heilig: siehe unten, nach der Tabelle gesetzt)
        -- Buff-Erinnerung (ausserhalb des Kampfes): ids = eigener Zauber (beliebiger
        -- Rang), also = gleichwertige Buffs, auch von anderen Spielern (z. B. Gebet).
        -- spec = nur fuer diese Ausrichtung. Gezeigt wird nur, was man gelernt hat.
        buffs = {
            {ids = {1243}, also = {21562}},   -- Machtwort: Seelenstaerke / Gebet der Seelenstaerke
            {ids = {588}},                    -- Inneres Feuer (nur selbst)
            {ids = {976}, also = {27683}},    -- Schattenschutz / Gebet des Schattenschutzes
            {ids = {15473}, spec = 3},        -- Schattengestalt (Schatten)
        },
        -- Ein Satz, der erste passende wird gezeigt (p = Spielerzustand).
        tips = {
            {function(p) return p.situation == "dungeon" and p.spec == 3 end,
                "Im Dungeon: Gedankenschlag erst, wenn der Tank die Gegner sicher hat."},
            {function(p) return p.situation == "dungeon" and p.spec ~= 3 end,
                "Im Dungeon: Schild auf den Tank, bevor er angreift – das spart später Heilung."},
            {function(p) return p.spec == 3 and p:TalentRank(15270) < 5 and p.level >= 10 end,
                "Willensentzug zuerst: nach jedem Kill kommt Mana zurück."},
            {function(p) return p:Knows(1277324) end, "Mana leer? Dunkles Opfer tauscht Leben gegen Mana."},
            {function(p) return p.spec == 3 and not p:Knows(15473) end,
                "Ziel des Schatten-Baums: Schattengestalt ganz unten."},
            {function() return true end, "Immer einen Zauberstab tragen – er kostet kein Mana."},
        },
    },
}
-- Talentplaene Disziplin und Heilig (Forever-Guides, Warcraft Tavern Nov. 2026: Kerntalente,
-- Reihenfolge mit Reihen-Freischaltung selbst gebaut; Schatten-Plan steht oben)
Data.classes.PRIEST.build[1].talents = {
    {1225132, 5}, {18551, 5}, {14751, 1}, {14521, 3}, {14748, 1}, {402000, 1}, {14748, 3}, {14520, 2},
    {402174, 1}, {425280, 4}, {431622, 3}, {425280, 5}, {14520, 3}, {10060, 1},
    {14908, 3}, {14889, 2}, {18530, 5}, {14892, 3}, {27811, 2}, {14912, 3}, {27789, 2},
}
Data.classes.PRIEST.build[2].talents = {
    {14908, 3}, {14889, 2}, {18530, 5}, {14892, 3}, {15237, 1}, {27811, 1}, {1328569, 1}, {14912, 3},
    {27789, 1}, {14901, 5}, {1317006, 2}, {14898, 3}, {401859, 1}, {20711, 1}, {27900, 1},
    {1225132, 5}, {18551, 5}, {14751, 1}, {14521, 3}, {14748, 1}, {402000, 1}, {14520, 2},
}

-- Raid-Skillung Heilig (vorlaeufig, siehe DataClasses.lua „Raid-Skillungen Stufe 60“): 18/33/0
Data.classes.PRIEST.build[2].situations = Data.classes.PRIEST.build[2].situations or {}
Data.classes.PRIEST.build[2].situations.raid = Data.classes.PRIEST.build[2].situations.raid or {}
Data.classes.PRIEST.build[2].situations.raid.talents = {{1225132, 5}, {14908, 3}, {14889, 5}, {18551, 5}, {18530, 5}, {14751, 1}, {14748, 3}, {14521, 3}, {15237, 1}, {14892, 3}, {402000, 1}, {14912, 3}, {1328569, 1}, {1317006, 2}, {20711, 1}, {14901, 5}, {14898, 3}, {401859, 1}}
Data.classes.PRIEST.build[2].situations.raid.talentsNote = "Raid-Skillung vorläufig – Stand vor der Raid-Öffnung am 9.12."

for spec, plan in pairs({[1] = {{1225132, 5}, {14908, 3}, {14889, 5}, {18551, 5}, {18530, 5}, {14520, 3}, {14751, 1}, {14748, 3}, {14521, 3}, {14892, 3}, {402000, 1}, {14912, 3}, {1328569, 1}, {402174, 1}, {425280, 5}, {431622, 3}, {10060, 1}}, -- Disziplin 31/20/0
    [3] = {{1225132, 5}, {15260, 5}, {14523, 3}, {18551, 5}, {15273, 5}, {15275, 2}, {14751, 1}, {14521, 3}, {15407, 1}, {1225139, 2}, {1326159, 5}, {15286, 1}, {15257, 3}, {15487, 1}, {1309950, 1}, {1310076, 2}, {15259, 5}, {15473, 1}}}) do -- Schatten 17/0/34
    local b = Data.classes.PRIEST.build[spec]
    b.situations = b.situations or {}
    b.situations.raid = b.situations.raid or {}
    b.situations.raid.talents = plan
    b.situations.raid.talentsNote = "Raid-Skillung vorläufig – Stand vor der Raid-Öffnung am 9.12."
end

-- Situationen (Leveln allein, Dungeon, Raid)
Data.situations = {"solo", "dungeon", "raid"}
-- Vorbereitung fuer Dungeon/Raid je Rolle: Essen, Elixier/Flaeschchen, Trank (Gruppen von
-- Gegenstaenden, keine festen Nummern – passend zur eigenen Stufe kaufen oder herstellen).
-- Rolle je Ausrichtung: def.roles = {"caster", "melee", ...}; ohne Angabe "caster".
Data.prep = {
    caster = {food = "Essen mit Willenskraft oder Mana pro 5 Sek.", elixir = "Elixier für Zauberschaden (z. B. Großes Arkanelixier) und Elixier der Weisheit/Intelligenz",
        potion = "Manatrank; im Raid zusätzlich Dunkle/Dämonische Rune"},
    melee = {food = "Essen mit Stärke oder Ausdauer", elixir = "Elixier der Riesen (Stärke) bzw. der Mungos (Beweglichkeit), Stärkungs-Elixier",
        potion = "Heiltrank; im Raid zusätzlich Schutztrank gegen die Schadensart des Bosses"},
    agile = {food = "Essen mit Beweglichkeit", elixir = "Elixier der Mungos (Beweglichkeit) und Elixier der Riesen",
        potion = "Heiltrank; Schurken: Gift ausreichend dabei"},
    hunter = {food = "Essen mit Beweglichkeit (und Futter für das Tier!)", elixir = "Elixier der Mungos (Beweglichkeit), Elixier der Weisheit",
        potion = "Manatrank, Heiltrank"},
    tank = {food = "Essen mit Ausdauer", elixir = "Elixier der Verteidigung/Seelenstärke (Rüstung, Leben), Elixier der Riesen",
        potion = "Großer Heiltrank; im Raid Schutztränke und Fläschchen der Titanen"},
    healer = {food = "Essen mit Willenskraft oder Mana pro 5 Sek.", elixir = "Elixier für Heilung und Elixier der Weisheit/Intelligenz",
        potion = "Manatrank; im Raid zusätzlich Dunkle/Dämonische Rune"},
}
Data.situationNames = {solo = "Leveln", dungeon = "Dungeon", raid = "Raid"}

-- Bauplan fuer Ausrichtung und Situation: Grundplan, darueber die Felder der
-- Situation (Ablauf, Werte, ggf. Talente). Die Leisten bleiben immer gleich.
-- level: Stufen-Abschnitte (stages) beim Leveln – {upTo = Stufe, flow = …} aufsteigend; über dem letzten
-- Abschnitt gilt der normale Ablauf (Nutzer 21.11.2026: „keine Guides, die das Leveln ab Stufe 1 beschreiben“).
function Data:Build(def, spec, situation, level)
    if not def then return nil end
    local base = def.build[spec] or def.build[def.defaultSpec]
    if not base then return nil end
    local over = situation and base.situations and base.situations[situation]
    local stage
    if base.stages and level and (not situation or situation == "solo") then
        for _, st in ipairs(base.stages) do
            if level <= st.upTo then stage = st break end
        end
    end
    if not over and not stage then return base end
    local merged = {}
    for k, v in pairs(base) do merged[k] = v end
    for k, v in pairs(over or {}) do if k ~= "bars" then merged[k] = v end end
    if stage then
        merged.flow = stage.flow
        merged.stage = stage
    end
    return merged
end

-- Volksfaehigkeiten. Horde: Auslese 14.11.2026 (Forever-Nummern). Allianz (0.7.0): Classic-Nummern –
-- erkannt wird ueber den Namen des Zaubers, eine neue Forever-Nummer mit gleichem Namen passt also auch.
-- Aktive bekommen auf jeder Leiste den festen Platz 12 – nur wenn man sie hat (Volk wird so von
-- selbst erkannt). Je Volk hoechstens eine pro Leiste.
--   Leiste 1: Staerkephase · Leiste 2: Notfall · Leiste 3: Hilfe
Data.racePos = 12
Data.raceSlots = {
    [1] = {{20554, 20572}, "Volk"},                   -- Troll Berserker, Orc Kochendes Blut
    -- Untoter Wille, Orc Fluch brechen, Tauren Kriegsdonner, Windformer Luftwandeln,
    -- Zwerg Steingestalt, Gnom Entfesselungskuenstler, Mensch Wille zum Ueberleben
    [2] = {{7744, 1299026, 20549, 1259416, 20594, 20589, 59752}, "Volk"},
    -- Untoter Kannibalismus, Troll Rasche Regeneration, Windformer Himmelssicht, Tauren Gruener Daumen,
    -- Nachtelf Schattenhaftigkeit, Mensch Wahrnehmung
    [3] = {{20577, 1260270, 1259686, 20552, 20580, 20600}, "Volk"},
}
-- Passive Volksfaehigkeiten als Tipp. Erkannt am aktiven Volkszauber
-- (passive stehen nicht in der Liste bekannter Zauber).
Data.raceTips = {
    {20572, "Orc: Betäubungen halten bei dir 20 % kürzer (Zähigkeit)."},
    {20572, "Orc: Dein Begleiter macht 5 % mehr Schaden (Befehlsgewalt).", {HUNTER = true, WARLOCK = true}},
    {7744, "Untoter: Deine Treffer stehlen manchmal Leben (Berührung des Grabes), unter Wasser hältst du viel länger durch."},
    {20549, "Tauren: 5 % mehr Leben, und je länger du läufst, desto schneller wirst du (Ebenenlaufen)."},
    {20554, "Troll: Leben kommt 20 % schneller zurück, auch im Kampf – dazu 5 % mehr Schaden gegen Wildtiere."},
    {1259686, "Windformer: 2 % schneller in Angriff und Zauber, 5 % mehr Schaden gegen Elementare."},
}

-- Volks-Tipps nach dem Volk des Charakters (UnitRace) – auch fuer die Allianz, deren neue
-- Forever-Volkszauber wir (noch) nicht als Nummern kennen. Passive zuerst, dann die
-- wichtigste aktive als Hinweis. Quelle: docs/VOELKER_FOREVER.md (eigene Notizen).
-- race = Dateiname aus UnitRace, names = Teil des angezeigten Namens (Rueckfall).
Data.raceTipsByRace = {
    {race = "Human", names = {"Mensch", "Human"}, text = "Mensch: Unbarmherzig gibt dir etwas mehr Schaden und Heilung, Menschlicher Geist mehr Willenskraft – dein Mana kommt schneller zurück."},
    {race = "Human", names = {"Mensch", "Human"}, text = "Mensch: Wille zum Überleben befreit dich aus Betäubungen – auf eine Taste legen und im Notfall drücken."},
    {race = "Dwarf", names = {"Zwerg", "Dwarf"}, text = "Zwerg: Handwerkspräzision gibt mehr Trefferchance, Großwildjäger mehr Schaden gegen Wildtiere."},
    {race = "Dwarf", names = {"Zwerg", "Dwarf"}, text = "Zwerg: Steingestalt entfernt Blutung, Gift und Krankheit und senkt körperlichen Schaden – bei Gefahr drücken."},
    {race = "Gnome", names = {"Gnom", "Gnome"}, text = "Gnom: Weiter Geist gibt dir 5 % mehr Mana, Wut oder Energie."},
    {race = "Gnome", names = {"Gnom", "Gnome"}, text = "Gnom: Entfesselungskünstler befreit dich aus Verlangsamung und Wurzeln – ideal zum Weglaufen."},
    {race = "NightElf", names = {"Nachtelf", "Night Elf"}, text = "Nachtelf: Flinkheit – etwas mehr Ausweichen und 2 % schneller laufen; als Irrwisch bist du nach dem Tod schneller."},
    {race = "NightElf", names = {"Nachtelf", "Night Elf"}, text = "Nachtelf: Schattenhaftigkeit macht dich unsichtbar, solange du still stehst – gut zum Rasten."},
    {race = "Orc", names = {"Orc"}, text = "Orc: Betäubungen halten bei dir kürzer (Robustheit)."},
    {race = "Orc", names = {"Orc"}, text = "Orc: Dein Begleiter macht mehr Schaden (Befehlsgewalt).", classes = {HUNTER = true, WARLOCK = true}},
    {race = "Scourge", names = {"Untot", "Undead"}, text = "Untoter: Deine Treffer stehlen manchmal Leben (Berührung des Grabes), unter Wasser hältst du viel länger durch."},
    {race = "Scourge", names = {"Untot", "Undead"}, text = "Untoter: Wille der Verlassenen befreit dich von Furcht, Schlaf und Bezauberung – gegen Furcht-Gegner bereithalten."},
    {race = "Tauren", names = {"Tauren"}, text = "Tauren: Mehr Leben, und je länger du läufst, desto schneller wirst du (Präriespringer)."},
    {race = "Troll", names = {"Troll"}, text = "Troll: Leben kommt schneller zurück, auch im Kampf – dazu mehr Schaden gegen Wildtiere."},
    {race = "Troll", names = {"Troll"}, text = "Troll: Berserker ist deine Stärkephase – bei schweren Gegnern zusammen mit deinen anderen Abklingzeiten zünden."},
    {names = {"Himmelsgeboren", "Skyborne", "Windformer", "Hohe Ordnung"}, text = "Himmelsgeborene: Windgesegnet gibt etwas mehr Schaden; „Auf Luft gehen“ bremst jeden Sturz."},
}
-- Passende Volks-Tipps fuer raceFile/raceName und Klasse
function Data.RaceTipsFor(raceName, raceFile, classFile)
    local out = {}
    for _, tip in ipairs(Data.raceTipsByRace) do
        local match = tip.race and tip.race == raceFile
        if not match and type(raceName) == "string" then
            for _, n in ipairs(tip.names or {}) do if raceName:find(n, 1, true) then match = true break end end
        end
        if match and (not tip.classes or tip.classes[classFile or ""]) then out[#out + 1] = tip.text end
    end
    return out
end

-- Lehrer: neue Raenge gibt es in der Regel auf geraden Stufen.
function Data:NextTrainerLevel(level)
    level = tonumber(level) or 1
    if level >= 60 then return nil end
    local nextLevel = level + 1
    if nextLevel % 2 == 1 then nextLevel = nextLevel + 1 end
    return math.min(nextLevel, 60)
end
