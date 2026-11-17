-- Guild Trip Startpaket – ERZEUGT von scripts/build_pack.lua, nicht von Hand aendern.
-- Nur selbst gesammelte Funde der Guild-Trip-Spieler (keine fremden Datenbanken, keine Spielernamen).
-- ["Zauber|Rang"] = Stufe je Klasse (Klassenlehrer)
local _, classes = ...
classes.TrainerSpellPack = {
    MAGE = {
        ["Arkane Intelligenz|available"] = 1,
        ["Essen herbeizaubern|available"] = 6,
        ["Essen herbeizaubern|unavailable"] = 6,
        ["Feuerball|available"] = 6,
        ["Feuerball|unavailable"] = 6,
        ["Feuerschlag|available"] = 6,
        ["Feuerschlag|unavailable"] = 6,
        ["Frostblitz|available"] = 4,
        ["Frostblitz|unavailable"] = 4,
        ["Wasser herbeizaubern|available"] = 4,
        ["Wasser herbeizaubern|unavailable"] = 4,
    },
}
