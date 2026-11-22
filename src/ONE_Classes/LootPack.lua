-- Guild Trip Startpaket – ERZEUGT von scripts/build_pack.lua, nicht von Hand aendern.
-- Nur selbst gesammelte Funde der Guild-Trip-Spieler (keine fremden Datenbanken, keine Spielernamen).
-- [itemID] = {slot, minLevel, sources = {[gegner] = {name, kind, instance, mapID, x, y, count}}}
local _, classes = ...
classes.LootPack = {
    [10404] = {
        ilvl = 30,
        minLevel = 25,
        q = 2,
        slot = "INVTYPE_WAIST",
        sources = {
            c4030 = {count = 2, kind = "rare", mapID = 1442, name = "Rachsüchtiges Urtum", x = 0.365, y = 0.7},
        },
    },
    [1210] = {
        ilvl = 20,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {
            c11915 = {count = 1, kind = "normal", mapID = 1442, name = "Felsbewahrer der Gogger", x = 0.604, y = 0.907},
        },
    },
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
    [14195] = {
        ilvl = 29,
        minLevel = 24,
        q = 2,
        slot = "INVTYPE_FEET",
        sources = {
            c4027 = {count = 1, kind = "normal", mapID = 1442, name = "Sturmhexe der Blutfurien", x = 0.352, y = 0.692},
        },
    },
    [14370] = {
        ilvl = 19,
        minLevel = 14,
        q = 2,
        slot = "INVTYPE_LEGS",
        sources = {
            c3258 = {count = 1, kind = "normal", mapID = 1413, name = "Jäger der Borstennacken", x = 0.45, y = 0.54},
        },
    },
    [14723] = {
        ilvl = 17,
        minLevel = 12,
        q = 2,
        slot = "INVTYPE_WRIST",
        sources = {
            c3258 = {count = 1, kind = "normal", mapID = 1413, name = "Jäger der Borstennacken", x = 0.434, y = 0.521},
        },
    },
    [14726] = {
        ilvl = 18,
        minLevel = 13,
        q = 2,
        slot = "INVTYPE_HAND",
        sources = {
            c3989 = {
                count = 1,
                kind = "normal",
                mapID = 1442,
                name = "Holzarbeiter der Venture Co.",
                x = 0.663,
                y = 0.512,
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
    [15210] = {
        ilvl = 16,
        minLevel = 11,
        q = 2,
        slot = "INVTYPE_WEAPON",
        sources = {
            c3381 = {
                count = 1,
                kind = "normal",
                mapID = 1413,
                name = "Brigant der Südmeerfreibeuter",
                x = 0.638,
                y = 0.479,
            },
        },
    },
    [15268] = {
        ilvl = 16,
        minLevel = 11,
        q = 2,
        slot = "INVTYPE_2HWEAPON",
        sources = {
            c11915 = {count = 1, kind = "normal", mapID = 1442, name = "Felsbewahrer der Gogger", x = 0.588, y = 0.903},
        },
    },
    [15303] = {
        ilvl = 14,
        minLevel = 9,
        q = 2,
        slot = "INVTYPE_LEGS",
        sources = {
            c3272 = {count = 1, kind = "normal", mapID = 1413, name = "Zänker der Kolkar", x = 0.451, y = 0.205},
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
    [15310] = {
        ilvl = 18,
        minLevel = 13,
        q = 2,
        slot = "INVTYPE_HAND",
        sources = {
            c3989 = {
                count = 1,
                kind = "normal",
                mapID = 1442,
                name = "Holzarbeiter der Venture Co.",
                x = 0.661,
                y = 0.52,
            },
        },
    },
    [15477] = {
        ilvl = 11,
        minLevel = 6,
        q = 2,
        slot = "INVTYPE_LEGS",
        sources = {
            c3244 = {count = 1, kind = "normal", mapID = 1413, name = "Großer Ebenenschreiter", x = 0.491, y = 0.23},
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
    [2078] = {
        ilvl = 18,
        minLevel = 13,
        q = 2,
        slot = "INVTYPE_WEAPON",
        sources = {c3633 = {count = 1, kind = "elite", mapID = 1414, name = "Deviattöter", x = 0.528, y = 0.548}},
    },
    [248703] = {
        ilvl = 1,
        minLevel = 10,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {
            c1781 = {count = 1, kind = "normal", mapID = 1421, name = "Nebelkrabbler", x = 0.351, y = 0.103},
            c3240 = {count = 1, kind = "normal", mapID = 1413, name = "Sturmschnauze", x = 0.466, y = 0.559},
        },
    },
    [249391] = {
        ilvl = 25,
        minLevel = 0,
        q = 2,
        slot = "INVTYPE_NON_EQUIP_IGNORE",
        sources = {o1731 = {count = 1, kind = "object", mapID = 1442, x = 0.36, y = 0.612}},
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
    [3036] = {
        ilvl = 15,
        minLevel = 10,
        q = 2,
        slot = "INVTYPE_RANGED",
        sources = {c3632 = {count = 1, kind = "elite", mapID = 1414, name = "Deviatkrabbler", x = 0.52, y = 0.545}},
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
            c3381 = {
                count = 1,
                kind = "normal",
                mapID = 1413,
                name = "Brigant der Südmeerfreibeuter",
                x = 0.637,
                y = 0.486,
            },
        },
    },
    [4566] = {
        ilvl = 13,
        minLevel = 8,
        q = 2,
        slot = "INVTYPE_2HWEAPON",
        sources = {
            c3244 = {count = 1, kind = "normal", mapID = 1413, name = "Großer Ebenenschreiter", x = 0.488, y = 0.239},
            c3255 = {count = 1, kind = "normal", mapID = 1413, name = "Bluthornkreischer", x = 0.529, y = 0.175},
        },
    },
    [4569] = {
        ilvl = 14,
        minLevel = 9,
        q = 2,
        slot = "INVTYPE_WEAPONMAINHAND",
        sources = {
            c3415 = {count = 1, kind = "normal", mapID = 1413, name = "Savannenjägerin", x = 0.504, y = 0.231},
        },
    },
    [4570] = {
        ilvl = 15,
        minLevel = 10,
        q = 2,
        slot = "INVTYPE_2HWEAPON",
        sources = {
            c1894 = {count = 1, kind = "elite", mapID = 1421, name = "Pyrewood-Wachposten", x = 0.447, y = 0.733},
        },
    },
    [4577] = {
        ilvl = 13,
        minLevel = 8,
        q = 2,
        slot = "INVTYPE_RANGEDRIGHT",
        sources = {
            c3415 = {count = 1, kind = "normal", mapID = 1413, name = "Savannenjägerin", x = 0.512, y = 0.214},
        },
    },
    [5069] = {
        ilvl = 12,
        minLevel = 7,
        q = 2,
        slot = "INVTYPE_RANGEDRIGHT",
        sources = {
            c1797 = {count = 1, kind = "normal", mapID = 1421, name = "Ergrauter Riesenbär", x = 0.46, y = 0.172},
        },
    },
    [5071] = {
        ilvl = 14,
        minLevel = 9,
        q = 2,
        slot = "INVTYPE_RANGEDRIGHT",
        sources = {
            c1782 = {count = 1, kind = "normal", mapID = 1421, name = "Moonrage-Dunkelseele", x = 0.559, y = 0.459},
        },
    },
    [6266] = {
        ilvl = 13,
        minLevel = 8,
        q = 2,
        slot = "INVTYPE_CHEST",
        sources = {
            c1867 = {count = 1, kind = "normal", mapID = 1421, name = "Lehrling von Dalaran", x = 0.509, y = 0.588},
        },
    },
    [6269] = {
        ilvl = 12,
        minLevel = 7,
        q = 2,
        slot = "INVTYPE_LEGS",
        sources = {
            c1782 = {count = 1, kind = "normal", mapID = 1421, name = "Moonrage-Dunkelseele", x = 0.561, y = 0.484},
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
            o1731 = {count = 1, kind = "object", mapID = 1442, x = 0.369, y = 0.196},
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
            c3632 = {count = 1, kind = "elite", mapID = 1414, name = "Deviatkrabbler", x = 0.521, y = 0.55},
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
