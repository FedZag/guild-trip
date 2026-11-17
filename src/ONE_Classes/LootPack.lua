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
    [275724] = {
        ilvl = 10,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {c3207 = {count = 2, kind = "normal", mapID = 1411, name = "Verhexter Troll", x = 0.68, y = 0.841}},
    },
    [4408] = {
        ilvl = 15,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {
            c3198 = {
                count = 1,
                kind = "normal",
                mapID = 1411,
                name = "Lehrling der Burning Blade",
                x = 0.535,
                y = 0.084,
            },
        },
    },
    [4564] = {
        ilvl = 13,
        minLevel = 8,
        q = 2,
        slot = "INVTYPE_2HWEAPON",
        sources = {
            c3198 = {
                count = 1,
                kind = "normal",
                mapID = 1411,
                name = "Lehrling der Burning Blade",
                x = 0.536,
                y = 0.086,
            },
        },
    },
    [774] = {
        ilvl = 7,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {
            c3197 = {
                count = 1,
                kind = "normal",
                mapID = 1411,
                name = "Fanatikerin der Burning Blade",
                x = 0.533,
                y = 0.077,
            },
        },
    },
    [8178] = {
        ilvl = 10,
        minLevel = 5,
        q = 2,
        slot = "INVTYPE_2HWEAPON",
        sources = {
            c3197 = {
                count = 1,
                kind = "normal",
                mapID = 1411,
                name = "Fanatiker der Burning Blade",
                x = 0.539,
                y = 0.089,
            },
        },
    },
    [818] = {
        ilvl = 15,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {
            c3130 = {count = 1, kind = "normal", mapID = 1411, name = "Donnerechse", x = 0.392, y = 0.291},
            c3197 = {
                count = 1,
                kind = "normal",
                mapID = 1411,
                name = "Fanatikerin der Burning Blade",
                x = 0.533,
                y = 0.077,
            },
        },
    },
    [8180] = {
        ilvl = 11,
        minLevel = 6,
        q = 2,
        slot = "INVTYPE_RANGED",
        sources = {
            c5822 = {count = 1, kind = "rare", mapID = 1411, name = "Höllenwirker Hoohn", x = 0.534, y = 0.078},
        },
    },
}
