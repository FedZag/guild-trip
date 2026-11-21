-- Guild Trip Quest-Fuehrung: Klassen-Reisezauber (Nutzer 20.11.2026: "alles klassenspezifische, egal welche
-- Klasse was hat, muss mit eingebaut werden"). Zielorte aus Shortest Path Forever Data/Teleports.lua
-- (GPL-3.0, Commit 7dea1de; dort aus den Forever-Spieldaten 1.60.1 + classic-db), Weltkoordinaten in Yards.
-- {spell, klasse, fraktion (1 A, 2 H, 0 beide), lernstufe, abklingzeit (min), bind, kontinent, x, y, ort, rune}
-- bind = landet am Heimatort (wie der Ruhestein). Lernstufen wie Classic – Forever kann abweichen, gelernt
-- wird im Spiel geprueft (IsPlayerSpell). Magier-Teleports lehrt der Portallehrer, nicht der Klassenlehrer.
local _, lev = ...
lev.TELEPORTS = {
    {556, "SHAMAN", 0, 30, 60, true, nil, nil, nil, nil},                          -- Astraler Ruf
    {18960, "DRUID", 0, 10, 0, false, 1, 7991.9, -2679.8, "Mondlichtung"},         -- Teleportieren: Mondlichtung
    {3561, "MAGE", 1, 20, 0, false, 0, -9003.5, 870.0, "Sturmwind", 17031},
    {3562, "MAGE", 1, 20, 0, false, 0, -4613.6, -915.4, "Eisenschmiede", 17031},
    {3565, "MAGE", 1, 30, 0, false, 1, 9664.1, 2526.4, "Darnassus", 17031},
    {3567, "MAGE", 2, 20, 0, false, 1, 1469.9, -4221.5, "Orgrimmar", 17031},
    {3563, "MAGE", 2, 20, 0, false, 0, 1773.5, 61.1, "Unterstadt", 17031},
    {3566, "MAGE", 2, 30, 0, false, 1, -965.0, 283.4, "Donnerfels", 17031},
}
-- schneller unterwegs: Zauber -> {Tempo-Faktor, Klasse} (Geisterwolf, Reisegestalt, Aspekt des Geparden).
-- Nur fuer die eigene Klasse – das Spiel soll fremde Zauber nicht faelschlich als gelernt melden koennen.
lev.SPEED_SPELLS = {[2645] = {1.4, "SHAMAN"}, [783] = {1.4, "DRUID"}, [5118] = {1.3, "HUNTER"}}
