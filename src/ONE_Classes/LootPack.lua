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
            c3272 = {count = 1, kind = "normal", mapID = 1413, name = "Zänker der Kolkar", x = 0.485, y = 0.404},
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
    [14114] = {
        ilvl = 16,
        minLevel = 11,
        q = 2,
        slot = "INVTYPE_FEET",
        sources = {
            c3273 = {count = 1, kind = "normal", mapID = 1413, name = "Sturmruferin der Kolkar", x = 0.489, y = 0.388},
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
    [15012] = {
        ilvl = 16,
        minLevel = 11,
        q = 2,
        slot = "INVTYPE_FEET",
        sources = {
            c3461 = {count = 1, kind = "normal", mapID = 1413, name = "Oasenschnappkiefer", x = 0.461, y = 0.402},
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
    [2075] = {
        ilvl = 12,
        minLevel = 7,
        q = 2,
        slot = "INVTYPE_WEAPONMAINHAND",
        sources = {
            c3272 = {count = 1, kind = "normal", mapID = 1413, name = "Zänker der Kolkar", x = 0.48, y = 0.409},
        },
    },
    [275724] = {
        ilvl = 10,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {c3207 = {count = 2, kind = "normal", mapID = 1411, name = "Verhexter Troll", x = 0.68, y = 0.841}},
    },
    [2842] = {
        ilvl = 10,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {o106319 = {count = 1, kind = "object", mapID = 1413, x = 0.465, y = 0.228}},
    },
    [3292] = {
        ilvl = 13,
        minLevel = 8,
        q = 2,
        slot = "INVTYPE_CHEST",
        sources = {
            c3273 = {count = 1, kind = "normal", mapID = 1413, name = "Sturmruferin der Kolkar", x = 0.48, y = 0.384},
        },
    },
    [3307] = {
        ilvl = 15,
        minLevel = 10,
        q = 2,
        slot = "INVTYPE_FEET",
        sources = {
            c3255 = {count = 1, kind = "normal", mapID = 1413, name = "Bluthornkreischer", x = 0.471, y = 0.257},
        },
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
    [4566] = {
        ilvl = 13,
        minLevel = 8,
        q = 2,
        slot = "INVTYPE_2HWEAPON",
        sources = {
            c3255 = {count = 1, kind = "normal", mapID = 1413, name = "Bluthornkreischer", x = 0.529, y = 0.175},
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
            c3272 = {count = 1, kind = "normal", mapID = 1413, name = "Zänker der Kolkar", x = 0.48, y = 0.409},
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
