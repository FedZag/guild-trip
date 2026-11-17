-- Guild Trip Startpaket – ERZEUGT von scripts/build_pack.lua, nicht von Hand aendern.
-- Nur selbst gesammelte Funde der Guild-Trip-Spieler (keine fremden Datenbanken, keine Spielernamen).
-- [itemID] = {slot, minLevel, sources = {[gegner] = {name, kind, instance, mapID, x, y, count}}}
local _, classes = ...
classes.LootPack = {
    [14113] = {
        ilvl = 15,
        minLevel = 10,
        q = 2,
        slot = "INVTYPE_WAIST",
        sources = {
            c3284 = {
                count = 1,
                kind = "normal",
                mapID = 1413,
                name = "Zwangsarbeiter der Venture Co.",
                x = 0.563,
                y = 0.071,
            },
        },
    },
    [14119] = {
        ilvl = 17,
        minLevel = 12,
        q = 2,
        slot = "INVTYPE_LEGS",
        sources = {
            c3278 = {
                count = 1,
                kind = "normal",
                mapID = 1413,
                name = "Töterin der Hexenschwingen",
                x = 0.396,
                y = 0.162,
            },
        },
    },
    [15305] = {
        ilvl = 18,
        minLevel = 13,
        q = 2,
        slot = "INVTYPE_FEET",
        sources = {
            c3282 = {count = 1, kind = "normal", mapID = 1413, name = "Söldner der Venture Co.", x = 0.564, y = 0.084},
        },
    },
}
