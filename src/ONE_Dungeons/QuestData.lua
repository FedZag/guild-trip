-- AUTOMATISCH ERZEUGT von scripts/import_fdq.lua – nicht von Hand bearbeiten.
-- Quest-Daten: "Forever Dungeon Quests" von Sundee, MIT-Lizenz (siehe LICENSE_ForeverDungeonQuests.txt).
-- Quelle: https://github.com/ImSundee/forever-dungeon-quest (Stand: main, abgerufen 2026-11-12 (letzter Commit fed422e vom 2026-09-26))
local _, dungeons = ...
dungeons.QuestData = {
  dungeons = {
    {
      levels = {
        atLevel = 14,
        easy = 19,
        hard = 9,
        medium = 12,
      },
      name = "Ragefire Chasm",
      quests = {
        {
          faction = "Horde",
          giver = "Neeru Fireblade",
          ids = {
            5761,
          },
          level = 9,
          location = "Orgrimmar, The Drag",
          name = "Slaying the Beast",
          x = 0.49,
          y = 0.5,
          zone = "Orgrimmar",
        },
        {
          faction = "Horde",
          giver = "Varimathras",
          ids = {
            5725,
          },
          level = 9,
          location = "Undercity, Royal Quarter",
          name = "The Power to Destroy...",
          x = 0.56,
          y = 0.92,
          zone = "Undercity",
        },
        {
          faction = "Horde",
          giver = "Rahauro",
          ids = {
            5723,
          },
          level = 9,
          location = "Thunder Bluff, Elder Rise",
          name = "Testing an Enemy's Strength",
          x = 0.7,
          y = 0.3,
          zone = "Thunder Bluff",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Grimtotem Satchel (drop from Maur Grimtotem)",
          ids = {
            5722,
          },
          level = 9,
          location = "Inside Ragefire Chasm",
          name = "Searching for the Lost Satchel",
          zone = "Inside Ragefire Chasm",
        },
        {
          faction = "Horde",
          giver = "Thrall",
          ids = {
            5728,
          },
          level = 9,
          location = "Orgrimmar, Valley of Wisdom",
          name = "Hidden Enemies",
          prereqs = {
            {
              ids = {
                5726,
              },
              name = "Hidden Enemies",
            },
            {
              ids = {
                5727,
              },
              name = "Hidden Enemies",
            },
            {
              ids = {
                5729,
              },
              name = "Hidden Enemies",
            },
            {
              ids = {
                5730,
              },
              name = "Hidden Enemies",
            },
          },
          x = 0.31,
          y = 0.37,
          zone = "Orgrimmar",
        },
      },
    },
    {
      levels = {
        atLevel = 14,
        easy = 19,
        hard = 11,
        medium = 13,
      },
      name = "The Hall of Thanes",
      quests = {
        {
          faction = "Neutral",
          giver = "Thom Filch",
          ids = {
            96403,
          },
          level = 14,
          location = "Ironforge, Old Ironforge",
          name = "Important Heirlooms",
          x = 0.326,
          y = 0.446,
          zone = "Ironforge",
        },
        {
          faction = "Neutral",
          giver = "Afadra Dunwall",
          ids = {
            96394,
          },
          level = 15,
          location = "Ironforge, Old Ironforge",
          name = "The Restless Dead",
          x = 0.648,
          y = 0.584,
          zone = "Ironforge",
        },
        {
          faction = "Neutral",
          giver = "Earthseer Farsen",
          ids = {
            96393,
          },
          level = 15,
          location = "Dun Morogh, Gol'Golar Quarry",
          name = "Old Ironforge Incursion",
          notes = "Prerequisite to pick up Underground Map from Dark Iron Map.",
          x = 0.648,
          y = 0.584,
          zone = "Dun Morogh",
        },
        {
          faction = "Neutral",
          giver = "Interactable item",
          ids = {
            98423,
          },
          level = 16,
          location = "The Hall of Thanes, Reliquary of Kings vault",
          name = "The Treaty of Understanding",
          zone = "The Hall of Thanes",
        },
        {
          faction = "Neutral",
          giver = "Ghostly Attendant",
          ids = {
            96395,
          },
          level = 14,
          location = "The Hall of Thanes, Anvilmar's Rest",
          name = "An Ancient Grudge",
          zone = "The Hall of Thanes",
        },
      },
    },
    {
      levels = {
        atLevel = 19,
        easy = 24,
        hard = 15,
        medium = 17,
      },
      name = "Wailing Caverns",
      quests = {
        {
          faction = "Horde",
          giver = "Apothecary Zamah",
          ids = {
            962,
          },
          level = 14,
          location = "Thunder Bluff, Pools of Vision",
          name = "Serpentbloom",
          x = 0.34,
          y = 0.21,
          zone = "Thunder Bluff",
        },
        {
          faction = "Neutral",
          giver = "Mebok Mizzyrix",
          ids = {
            1491,
          },
          level = 13,
          location = "The Barrens, Ratchet",
          name = "Smart Drinks",
          notes = "Prerequisite: complete Raptor Horns from same NPC first.",
          prereqs = {
            {
              ids = {
                865,
              },
              name = "Raptor Horns",
            },
          },
          x = 0.62,
          y = 0.37,
          zone = "The Barrens",
        },
        {
          faction = "Neutral",
          giver = "Crane Operator Bigglefuzz",
          ids = {
            959,
          },
          level = 14,
          location = "The Barrens, Ratchet",
          name = "Trouble at the Docks",
          x = 0.63,
          y = 0.37,
          zone = "The Barrens",
        },
        {
          faction = "Neutral",
          giver = "Nalpak",
          ids = {
            1486,
          },
          level = 13,
          location = "The Barrens, above WC entrance",
          name = "Deviate Hides",
          x = 0.46,
          y = 0.35,
          zone = "The Barrens",
        },
        {
          faction = "Neutral",
          giver = "Ebru",
          ids = {
            1487,
          },
          level = 15,
          location = "The Barrens, above WC entrance",
          name = "Deviate Eradication",
          x = 0.46,
          y = 0.35,
          zone = "The Barrens",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop from Mutanus the Devourer",
          ids = {
            6981,
          },
          level = 10,
          location = "Wailing Caverns",
          name = "The Glowing Shard",
          zone = "Wailing Caverns",
        },
        {
          faction = "Horde",
          giver = "Nara Wildmane",
          ids = {
            914,
          },
          level = 15,
          location = "Thunder Bluff, Elder Rise",
          name = "Leaders of the Fang",
          notes = "The Barrens Oases is an alternate, skippable entry point into this chain (Tonga hands out either it or The Forgotten Pools, not both) -- omitted below since requiring it shows a permanent false Missing for players who started via The Forgotten Pools instead.",
          prereqs = {
            {
              ids = {
                870,
              },
              name = "The Forgotten Pools",
            },
            {
              ids = {
                877,
              },
              name = "The Stagnant Oasis",
            },
            {
              ids = {
                880,
              },
              name = "Altered Beings",
            },
            {
              ids = {
                1489,
              },
              name = "Hamuul Runetotem",
            },
            {
              ids = {
                1490,
              },
              name = "Nara Wildmane",
            },
          },
          x = 0.45,
          y = 0.23,
          zone = "Thunder Bluff",
        },
      },
    },
    {
      levels = {
        atLevel = 19,
        easy = 24,
        hard = 14,
        medium = 17,
      },
      name = "The Deadmines",
      quests = {
        {
          faction = "Alliance",
          giver = "Wilder Thistlenettle",
          ids = {
            168,
          },
          level = 14,
          location = "Stormwind, Dwarven District",
          name = "Collecting Memories",
          x = 0.65,
          y = 0.21,
          zone = "Stormwind",
        },
        {
          faction = "Alliance",
          giver = "Wilder Thistlenettle",
          ids = {
            167,
          },
          level = 15,
          location = "Stormwind, Dwarven District",
          name = "Oh Brother...",
          x = 0.65,
          y = 0.21,
          zone = "Stormwind",
        },
        {
          faction = "Alliance",
          giver = "Shoni the Shilent",
          ids = {
            2040,
          },
          level = 15,
          location = "Stormwind, Dwarven District",
          name = "Underground Assault",
          x = 0.55,
          y = 0.13,
          zone = "Stormwind",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop from Edwin VanCleef",
          ids = {
            373,
          },
          level = 16,
          location = "The Deadmines",
          name = "The Unsent Letter",
          notes = "Prerequisite to pick up The Stockade Riots.",
          zone = "The Deadmines",
        },
        {
          faction = "Alliance",
          giver = "Scout Riell",
          ids = {
            214,
          },
          level = 14,
          location = "Westfall, Sentinel Hill",
          name = "Red Silk Bandanas",
          prereqs = {
            {
              ids = {
                142,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                65,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                132,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                135,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                141,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                155,
              },
              name = "The Defias Brotherhood",
            },
          },
          x = 0.56,
          y = 0.47,
          zone = "Westfall",
        },
        {
          faction = "Alliance",
          giver = "Gryan Stoutmantle",
          ids = {
            166,
          },
          level = 14,
          location = "Westfall, Sentinel Hill",
          name = "The Defias Brotherhood",
          prereqs = {
            {
              ids = {
                142,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                65,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                132,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                135,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                141,
              },
              name = "The Defias Brotherhood",
            },
            {
              ids = {
                155,
              },
              name = "The Defias Brotherhood",
            },
          },
          x = 0.56,
          y = 0.47,
          zone = "Westfall",
        },
        {
          classOnly = "PALADIN",
          faction = "Alliance",
          giver = "Jordan Stilwell",
          ids = {
            1806,
          },
          level = 20,
          location = "Ironforge, inside Gates",
          name = "The Test of Righteousness",
          notes = "Paladin only. Starts the Tome of Valor quest chain; start point varies by race.",
          x = 0.52,
          y = 0.36,
          zone = "Ironforge",
        },
      },
    },
    {
      levels = {
        atLevel = 19,
        easy = 24,
        hard = 15,
        medium = 17,
      },
      name = "Ruins of Lordaeron",
      quests = {
        {
          faction = "Horde",
          giver = "Tabitha Heartweaver",
          ids = {
            92401,
          },
          level = 15,
          location = "Undercity",
          name = "A Frightened Request",
          x = 0.34,
          y = 0.21,
          zone = "Undercity",
        },
        {
          faction = "Horde",
          giver = "Deathguard Kristof",
          ids = {
            92422,
          },
          level = 15,
          location = "Brill",
          name = "The Wrath of Rath'mael",
          zone = "Brill",
        },
        {
          faction = "Horde",
          giver = "Theodore Griffs",
          ids = {
            95216,
          },
          level = 16,
          location = "Undercity",
          name = "The New Plague",
          x = 0.47,
          y = 0.726,
          zone = "Undercity",
        },
        {
          faction = "Horde",
          giver = "Morbin Lightbane",
          ids = {
            92421,
          },
          level = 15,
          location = "Undercity",
          name = "Light's Justice",
          x = 0.578,
          y = 0.898,
          zone = "Undercity",
        },
        {
          faction = "Neutral",
          giver = "Inside dungeon",
          ids = {
            97290,
          },
          level = 15,
          location = "Ruins of Lordaeron",
          name = "Unending Torment",
          notes = "5-step in-dungeon/Undercity chain; step order after the first two is best-effort (Wowhead's chain-order data doesn't fully disambiguate steps 3-4).",
          prereqs = {
            {
              ids = {
                97288,
              },
              name = "Unending Torment",
            },
            {
              ids = {
                97289,
              },
              name = "Unending Torment",
            },
            {
              ids = {
                97292,
              },
              name = "Unending Torment",
            },
            {
              ids = {
                97291,
              },
              name = "Unending Torment",
            },
          },
          zone = "Ruins of Lordaeron",
        },
        {
          dungeonDrop = true,
          faction = "Horde",
          giver = "Inside dungeon (turn in to Oran Snakewrithe, Undercity)",
          ids = {
            95204,
          },
          level = 15,
          location = "Ruins of Lordaeron",
          name = "Crest of Lordaeron",
          zone = "Ruins of Lordaeron",
        },
        {
          dungeonDrop = true,
          faction = "Alliance",
          giver = "Inside dungeon (turn in to Lady Dena Kennedy, Stormwind City)",
          ids = {
            95189,
          },
          level = 15,
          location = "Ruins of Lordaeron",
          name = "Crest of Lordaeron",
          zone = "Ruins of Lordaeron",
        },
        {
          faction = "Alliance",
          giver = "TBD (beta data incomplete)",
          ids = {
            95250,
          },
          level = 16,
          location = "TBD",
          name = "Abominable Creatures",
          zone = "TBD",
        },
        {
          faction = "Alliance",
          giver = "General Marcus Jonathan",
          ids = {
            95195,
          },
          level = 16,
          location = "Stormwind City",
          name = "Bloodied Insignia",
          zone = "Stormwind City",
        },
        {
          faction = "Alliance",
          giver = "TBD (beta data incomplete)",
          ids = {
            92415,
          },
          level = 15,
          location = "TBD",
          name = "Remember That I Love You",
          zone = "TBD",
        },
      },
    },
    {
      levels = {
        atLevel = 23,
        easy = 28,
        hard = 18,
        medium = 21,
      },
      name = "Shadowfang Keep",
      quests = {
        {
          faction = "Horde",
          giver = "Keeper Bel'dugur",
          ids = {
            1013,
          },
          level = 16,
          location = "Undercity, Apothecarium",
          name = "The Book of Ur",
          x = 0.53,
          y = 0.54,
          zone = "Undercity",
        },
        {
          faction = "Horde",
          giver = "High Executor Hadrec",
          ids = {
            1098,
          },
          level = 18,
          location = "Silverpine Forest, Sepulcher",
          name = "Deathstalkers in Shadowfang",
          x = 0.43,
          y = 0.41,
          zone = "Silverpine Forest",
        },
        {
          faction = "Horde",
          giver = "Dalar Dawnweaver",
          ids = {
            1014,
          },
          level = 18,
          location = "Silverpine Forest, Sepulcher",
          name = "Arugal Must Die",
          x = 0.44,
          y = 0.39,
          zone = "Silverpine Forest",
        },
        {
          classOnly = "WARLOCK",
          faction = "Neutral",
          giver = "Doan Karhan",
          ids = {
            1740,
          },
          level = 20,
          location = "The Barrens, near Camp Taurajo",
          name = "The Orb of Soran'ruk",
          notes = "Warlock only.",
          x = 0.49,
          y = 0.57,
          zone = "The Barrens",
        },
        {
          classOnly = "PALADIN",
          faction = "Alliance",
          giver = "Jordan Stilwell",
          ids = {
            1806,
          },
          level = 20,
          location = "Ironforge, inside Gates",
          name = "The Test of Righteousness",
          notes = "Paladin only. Starts the Tome of Valor quest chain; start point varies by race.",
          x = 0.52,
          y = 0.36,
          zone = "Ironforge",
        },
      },
    },
    {
      levels = {
        atLevel = 25,
        easy = 30,
        hard = 21,
        medium = 23,
      },
      name = "Blackfathom Deeps",
      quests = {
        {
          faction = "Horde",
          giver = "Je'neu Sancrea",
          ids = {
            6563,
          },
          level = 17,
          location = "Ashenvale, Zoram'gar Outpost",
          name = "The Essence of Aku'Mai",
          x = 0.11,
          y = 0.34,
          zone = "Ashenvale",
        },
        {
          faction = "Horde",
          giver = "Argent Guard Thaelrid",
          ids = {
            6561,
          },
          level = 18,
          location = "Blackfathom Deeps, alcove SW of Ghamoo-ra",
          name = "Blackfathom Villainy",
          zone = "Blackfathom Deeps",
        },
        {
          faction = "Horde",
          giver = "Je'neu Sancrea",
          ids = {
            6921,
          },
          level = 21,
          location = "Ashenvale, Zoram'gar Outpost",
          name = "Amongst the Ruins",
          notes = "Summons Baron Aquanis when Fathom Core is picked up; needed for next quest.",
          x = 0.11,
          y = 0.34,
          zone = "Ashenvale",
        },
        {
          dungeonDrop = true,
          faction = "Horde",
          giver = "Drop: Strange Water Globe from Baron Aquanis",
          ids = {
            909,
          },
          level = 21,
          location = "Blackfathom Deeps",
          name = "Baron Aquanis",
          zone = "Blackfathom Deeps",
        },
        {
          faction = "Horde",
          giver = "Je'neu Sancrea (after turning in the drop-only Damp Note)",
          ids = {
            6565,
          },
          level = 17,
          location = "Blackfathom Tide Priestess, outside instance",
          name = "Allegiance to the Old Gods",
          notes = "Starts from a low-drop-rate Damp Note.",
          prereqs = {
            {
              ids = {
                6564,
              },
              name = "Allegiance to the Old Gods",
            },
          },
          zone = "Blackfathom Tide Priestess",
        },
        {
          faction = "Alliance",
          giver = "Gerrig Bonegrip",
          ids = {
            971,
          },
          level = 10,
          location = "Ironforge, Forlorn Cave",
          name = "Knowledge in the Deeps",
          x = 0.5,
          y = 0.05,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "Gershala Nightwhisper",
          ids = {
            1275,
          },
          level = 18,
          location = "Darkshore, Auberdine",
          name = "Researching the Corruption",
          x = 0.38,
          y = 0.43,
          zone = "Darkshore",
        },
        {
          faction = "Alliance",
          giver = "Argent Guard Manados",
          ids = {
            1199,
          },
          level = 20,
          location = "Darnassus, Craftsman's Terrace",
          name = "Twilight Falls",
          x = 0.55,
          y = 0.24,
          zone = "Darnassus",
        },
        {
          faction = "Alliance",
          giver = "Dawnwatcher Shaedlass",
          ids = {
            1198,
          },
          level = 18,
          location = "Darnassus, Craftsman's Terrace",
          name = "In Search of Thaelrid",
          notes = "Prerequisite to Blackfathom Villainy.",
          x = 0.55,
          y = 0.24,
          zone = "Darnassus",
        },
        {
          faction = "Alliance",
          giver = "Argent Guard Thaelrid",
          ids = {
            1200,
          },
          level = 18,
          location = "Blackfathom Deeps, alcove SW of Ghamoo-ra",
          name = "Blackfathom Villainy",
          notes = "Requires In Search of Thaelrid.",
          zone = "Blackfathom Deeps",
        },
        {
          classOnly = "WARLOCK",
          faction = "Neutral",
          giver = "Doan Karhan",
          ids = {
            1740,
          },
          level = 20,
          location = "The Barrens, near Camp Taurajo",
          name = "The Orb of Soran'ruk",
          notes = "Warlock only.",
          x = 0.49,
          y = 0.57,
          zone = "The Barrens",
        },
        {
          classOnly = "PALADIN",
          faction = "Alliance",
          giver = "Jordan Stilwell",
          ids = {
            1806,
          },
          level = 20,
          location = "Ironforge, inside Gates",
          name = "The Test of Righteousness",
          notes = "Paladin only.",
          x = 0.52,
          y = 0.36,
          zone = "Ironforge",
        },
      },
    },
    {
      levels = {
        atLevel = 26,
        easy = 30,
        hard = 22,
        medium = 24,
      },
      name = "The Stockades",
      quests = {
        {
          faction = "Alliance",
          giver = "Warden Thelwater",
          ids = {
            387,
          },
          level = 22,
          location = "Stormwind, outside Stockades",
          name = "Quell The Uprising",
          x = 0.41,
          y = 0.58,
          zone = "Stormwind",
        },
        {
          faction = "Alliance",
          giver = "Nikova Raskol (patrols)",
          ids = {
            388,
          },
          level = 22,
          location = "The Stockades, Old Town",
          name = "The Color of Blood",
          zone = "The Stockades",
        },
        {
          faction = "Alliance",
          giver = "Councilman Millstipe",
          ids = {
            377,
          },
          level = 22,
          location = "Duskwood, Darkshire",
          name = "Crime and Punishment",
          x = 0.42,
          y = 0.47,
          zone = "Duskwood",
        },
        {
          faction = "Alliance",
          giver = "Guard Berton",
          ids = {
            386,
          },
          level = 22,
          location = "Redridge Mountains, Lakeshire",
          name = "What Comes Around...",
          x = 0.26,
          y = 0.46,
          zone = "Redridge Mountains",
        },
        {
          faction = "Alliance",
          giver = "Motley Garmason",
          ids = {
            378,
          },
          level = 25,
          location = "Wetlands, Dun Modr",
          name = "The Fury Runs Deep",
          notes = "Requires The Dark Iron War.",
          prereqs = {
            {
              ids = {
                303,
              },
              name = "The Dark Iron War",
            },
          },
          x = 0.49,
          y = 0.18,
          zone = "Wetlands",
        },
        {
          faction = "Alliance",
          giver = "Warden Thelwater",
          ids = {
            391,
          },
          level = 16,
          location = "Stormwind, outside Stockades",
          name = "The Stockade Riots",
          prereqs = {
            {
              ids = {
                373,
              },
              name = "The Unsent Letter",
            },
          },
          x = 0.41,
          y = 0.58,
          zone = "Stormwind",
        },
      },
    },
    {
      keyNote = "At least one player must have the Workshop Key to open the back door (Lockpicking 150 also works).",
      levels = {
        atLevel = 33,
        easy = 38,
        hard = 25,
        medium = 30,
      },
      name = "Gnomeregan",
      quests = {
        {
          faction = "Horde",
          giver = "Nogg",
          ids = {
            2841,
          },
          level = 25,
          location = "Orgrimmar, Valley of Honor",
          name = "Rig Wars",
          x = 0.76,
          y = 0.25,
          zone = "Orgrimmar",
        },
        {
          faction = "Horde",
          giver = "Sovik",
          ids = {
            2842,
          },
          level = 20,
          location = "Orgrimmar, Valley of Honor",
          name = "Chief Engineer Scooty",
          notes = "Must pick up Rig Wars first.",
          prereqs = {
            {
              ids = {
                2841,
              },
              name = "Rig Wars",
            },
          },
          x = 0.76,
          y = 0.25,
          zone = "Orgrimmar",
        },
        {
          faction = "Horde",
          giver = "Scooty",
          ids = {
            2843,
          },
          level = 20,
          location = "Stranglethorn Vale, Booty Bay",
          name = "Gnomer-gooooone!",
          x = 0.27,
          y = 0.77,
          zone = "Stranglethorn Vale",
        },
        {
          faction = "Alliance",
          giver = "Tinkmaster Overspark",
          ids = {
            2922,
          },
          level = 20,
          location = "Ironforge, Tinkertown",
          name = "Save Techbot's Brain!",
          x = 0.69,
          y = 0.5,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "Shoni the Shilent",
          ids = {
            2928,
          },
          level = 20,
          location = "Stormwind, Dwarven Quarter",
          name = "Gyrodrillmatic Excavationators",
          x = 0.55,
          y = 0.12,
          zone = "Stormwind",
        },
        {
          faction = "Alliance",
          giver = "Klockmort Spannerspan",
          ids = {
            2924,
          },
          level = 24,
          location = "Ironforge, Tinkertown",
          name = "Essential Artificials",
          x = 0.47,
          y = 0.64,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "Master Mechanic Castpipe",
          ids = {
            2930,
          },
          level = 25,
          location = "Ironforge, Tinkertown",
          name = "Data Rescue",
          x = 0.69,
          y = 0.48,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "High Tinker Mekkatorque",
          ids = {
            2929,
          },
          level = 25,
          location = "Ironforge, Tinkertown",
          name = "The Grand Betrayal",
          x = 0.68,
          y = 0.49,
          zone = "Ironforge",
        },
        {
          faction = "Neutral",
          giver = "Ozzie Togglevolt",
          ids = {
            2926,
          },
          level = 20,
          location = "Dun Morogh, Kharanos",
          name = "Gnogaine",
          x = 0.45,
          y = 0.49,
          zone = "Dun Morogh",
        },
        {
          faction = "Neutral",
          giver = "Ozzie Togglevolt",
          ids = {
            2962,
          },
          level = 20,
          location = "Dun Morogh, Kharanos",
          name = "The Only Cure is More Green Glow",
          notes = "Complete Gnogaine first.",
          prereqs = {
            {
              ids = {
                2926,
              },
              name = "Gnogaine",
            },
          },
          x = 0.45,
          y = 0.49,
          zone = "Dun Morogh",
        },
        {
          faction = "Neutral",
          giver = "Needs Grime-Encrusted Object",
          ids = {
            2951,
            2952,
            4601,
            4602,
            4605,
            4606,
          },
          level = 25,
          location = "Gnomeregan, the Sparklematic 5200",
          name = "The Sparklematic 5200!",
          notes = "The game hands out one of several interchangeable quest IDs for this action; id is a list, not a single ID (see Core.lua).",
          zone = "Gnomeregan",
        },
        {
          faction = "Neutral",
          giver = "Escort quest",
          ids = {
            2904,
          },
          level = 20,
          location = "Gnomeregan, room right of Clean Room",
          name = "A Fine Mess",
          notes = "Escort Kernobee.",
          zone = "Gnomeregan",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop: Grime-Encrusted Ring",
          ids = {
            2945,
          },
          level = 28,
          location = "Gnomeregan",
          name = "Grime-Encrusted Ring",
          notes = "Starts Return of the Ring.",
          zone = "Gnomeregan",
        },
      },
    },
    {
      levels = {
        atLevel = 31,
        easy = 34,
        hard = 25,
        medium = 28,
      },
      name = "Razorfen Kraul",
      quests = {
        {
          faction = "Horde",
          giver = "Auld Stonespire",
          ids = {
            1102,
          },
          level = 29,
          location = "Thunder Bluff, near Main Lift",
          name = "A Vengeful Fate",
          x = 0.37,
          y = 0.29,
          zone = "Thunder Bluff",
        },
        {
          faction = "Horde",
          giver = "Master Apothecary Faranell",
          ids = {
            1109,
          },
          level = 30,
          location = "Undercity, The Apothecarium",
          name = "Going, Going, Guano!",
          notes = "Prerequisite for the Scarlet Monastery quest Hearts of Zeal.",
          x = 0.48,
          y = 0.69,
          zone = "Undercity",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop: Small Scroll from Charlga Razorflank",
          ids = {
            6522,
          },
          level = 28,
          location = "Razorfen Kraul",
          name = "An Unholy Alliance",
          notes = "Prerequisite for the Razorfen Downs quest of the same name.",
          zone = "Razorfen Kraul",
        },
        {
          faction = "Neutral",
          giver = "Falfindel Waywarder",
          ids = {
            1101,
          },
          level = 29,
          location = "Feralas, The Lower Wilds",
          name = "The Crone of the Kraul",
          notes = "Complete Lonebrow's Journal first.",
          prereqs = {
            {
              ids = {
                1100,
              },
              name = "Lonebrow's Journal",
            },
          },
          x = 0.89,
          y = 0.46,
          zone = "Feralas",
        },
        {
          faction = "Neutral",
          giver = "Heralath Fallowbrook",
          ids = {
            1142,
          },
          level = 25,
          location = "Razorfen Kraul, behind main boss",
          name = "Mortality Wanes",
          zone = "Razorfen Kraul",
        },
        {
          faction = "Neutral",
          giver = "Mebok Mizzyrix",
          ids = {
            1221,
          },
          level = 20,
          location = "The Barrens, Ratchet",
          name = "Blueleaf Tubers",
          notes = "Quest items are next to Mizzyrix.",
          x = 0.62,
          y = 0.37,
          zone = "The Barrens",
        },
        {
          faction = "Neutral",
          giver = "Willix the Importer",
          ids = {
            1144,
          },
          level = 22,
          location = "Razorfen Kraul, tent near final boss",
          name = "Willix the Importer",
          notes = "Escort quest.",
          zone = "Razorfen Kraul",
        },
      },
    },
    {
      keyNote = "At least one player must have The Scarlet Key to open both the Armory and Cathedral wings (Lockpicking 175 also works).",
      levels = {
        atLevel = 37,
        easy = 45,
        hard = 26,
        medium = 32,
      },
      name = "Scarlet Monastery",
      quests = {
        {
          faction = "Horde",
          giver = "Varimathras",
          ids = {
            1048,
          },
          level = 33,
          location = "Undercity, Royal Quarter",
          name = "Into The Scarlet Monastery",
          x = 0.56,
          y = 0.92,
          zone = "Undercity",
        },
        {
          faction = "Alliance",
          giver = "Raleigh the Devout",
          ids = {
            1053,
          },
          level = 34,
          location = "Hillsbrad Foothills, Southshore",
          name = "In the Name of the Light",
          prereqs = {
            {
              ids = {
                6141,
              },
              name = "Brother Anton",
            },
            {
              ids = {
                261,
              },
              name = "Down the Scarlet Path",
            },
            {
              ids = {
                1052,
              },
              name = "Down the Scarlet Path",
            },
          },
          x = 0.51,
          y = 0.58,
          zone = "Hillsbrad Foothills",
        },
        {
          faction = "Neutral",
          giver = "Vorrel Sengutz",
          ids = {
            1051,
          },
          level = 25,
          location = "Scarlet Monastery, Graveyard",
          name = "Vorrel's Revenge",
          zone = "Scarlet Monastery",
        },
        {
          faction = "Horde",
          giver = "Master Apothecary Faranell",
          ids = {
            1113,
          },
          level = 30,
          location = "Undercity, The Apothecarium",
          name = "Hearts of Zeal",
          notes = "Requires Going, Going, Guano! (Razorfen Kraul) first.",
          prereqs = {
            {
              ids = {
                1109,
              },
              name = "Going, Going, Guano!",
            },
          },
          x = 0.48,
          y = 0.69,
          zone = "Undercity",
        },
        {
          faction = "Horde",
          giver = "Sage Truthseeker",
          ids = {
            1049,
          },
          level = 28,
          location = "Thunder Bluff, First Rise",
          name = "Compendium of the Fallen",
          notes = "Undead cannot pick up this quest.",
          x = 0.36,
          y = 0.26,
          zone = "Thunder Bluff",
        },
        {
          faction = "Horde",
          giver = "Parqual Fintallas",
          ids = {
            1160,
          },
          level = 25,
          location = "Undercity, The Apothecarium",
          name = "Test of Lore",
          prereqs = {
            {
              ids = {
                1149,
              },
              name = "Test of Faith",
            },
            {
              ids = {
                1150,
              },
              name = "Test of Endurance",
            },
            {
              ids = {
                1151,
              },
              name = "Test of Strength",
            },
            {
              ids = {
                1152,
              },
              name = "Test of Lore",
            },
            {
              ids = {
                1154,
              },
              name = "Test of Lore",
            },
            {
              ids = {
                6627,
              },
              name = "Test of Lore",
            },
            {
              ids = {
                1159,
              },
              name = "Test of Lore",
            },
          },
          x = 0.57,
          y = 0.65,
          zone = "Undercity",
        },
        {
          faction = "Alliance",
          giver = "Librarian Mae Paledust",
          ids = {
            1050,
          },
          level = 28,
          location = "Ironforge, Hall of Explorers",
          name = "Mythology of the Titans",
          x = 0.75,
          y = 0.12,
          zone = "Ironforge",
        },
        {
          classOnly = "MAGE",
          faction = "Neutral",
          giver = "Magus Tirth",
          ids = {
            1951,
          },
          level = 30,
          location = "Thousand Needles, Shimmering Flats Raceway",
          name = "Rituals of Power",
          notes = "Mage only.",
          prereqs = {
            {
              ids = {
                1947,
              },
              name = "Journey to the Marsh",
            },
            {
              ids = {
                1949,
              },
              name = "Hidden Secrets",
            },
            {
              ids = {
                1950,
              },
              name = "Get the Scoop",
            },
          },
          x = 0.78,
          y = 0.75,
          zone = "Thousand Needles",
        },
      },
    },
    {
      levels = {
        atLevel = 39,
        easy = 44,
        hard = 35,
        medium = 37,
      },
      name = "Razorfen Downs",
      quests = {
        {
          faction = "Horde",
          giver = "Andrew Brownell",
          ids = {
            3341,
          },
          level = 37,
          location = "Undercity, Magic Quarter",
          name = "Bring the End",
          x = 0.74,
          y = 0.33,
          zone = "Undercity",
        },
        {
          faction = "Horde",
          giver = "Varimathras",
          ids = {
            6521,
          },
          level = 28,
          location = "Undercity, Royal Quarter",
          name = "An Unholy Alliance",
          notes = "Requires An Unholy Alliance from Razorfen Kraul first.",
          prereqs = {
            {
              ids = {
                6522,
              },
              name = "An Unholy Alliance",
            },
          },
          x = 0.36,
          y = 0.26,
          zone = "Undercity",
        },
        {
          faction = "Alliance",
          giver = "Archbishop Benedictus",
          ids = {
            3636,
          },
          level = 39,
          location = "Stormwind, Cathedral",
          name = "Bring the Light",
          x = 0.39,
          y = 0.27,
          zone = "Stormwind",
        },
        {
          faction = "Neutral",
          giver = "Myriam Moonsinger",
          ids = {
            6626,
          },
          level = 28,
          location = "The Barrens, outside instance portal",
          name = "A Host of Evil",
          x = 0.49,
          y = 0.95,
          zone = "The Barrens",
        },
        {
          faction = "Neutral",
          giver = "Belnistrasz",
          ids = {
            3523,
          },
          level = 32,
          location = "Razorfen Downs, Murder Pens",
          name = "Scourge of the Downs",
          notes = "Entire party should complete before picking up the next quest.",
          zone = "Razorfen Downs",
        },
        {
          faction = "Neutral",
          giver = "Belnistrasz",
          ids = {
            3525,
          },
          level = 32,
          location = "Razorfen Downs, Murder Pens",
          name = "Extinguishing the Idol",
          notes = "Escort quest. Entire party must finish Scourge of the Downs first or they won't get credit.",
          prereqs = {
            {
              ids = {
                3523,
              },
              name = "Scourge of the Downs",
            },
          },
          zone = "Razorfen Downs",
        },
      },
    },
    {
      levels = {
        atLevel = 42,
        easy = 47,
        hard = 37,
        medium = 40,
      },
      name = "Uldaman",
      quests = {
        {
          faction = "Horde",
          giver = "Patrick Garrett",
          ids = {
            2342,
          },
          level = 33,
          location = "Undercity, Center",
          name = "Reclaimed Treasures",
          x = 0.62,
          y = 0.48,
          zone = "Undercity",
        },
        {
          faction = "Horde",
          giver = "Jarkal Mossmeld",
          ids = {
            2202,
          },
          level = 36,
          location = "Badlands, Kargath",
          name = "Uldaman Reagent Run",
          notes = "Complete Badlands Reagent Run first.",
          prereqs = {
            {
              ids = {
                2258,
              },
              name = "Badlands Reagent Run",
            },
          },
          x = 0.03,
          y = 0.46,
          zone = "Badlands",
        },
        {
          faction = "Neutral",
          giver = "Drop: Shattered Necklace from Shadowforge/Shadowvault mobs",
          ids = {
            2283,
          },
          level = 37,
          location = "Badlands, outside Uldaman instance",
          name = "Necklace Recovery",
          notes = "Drop-only.",
          zone = "Badlands",
        },
        {
          faction = "Alliance",
          giver = "Krom Stoutarm",
          ids = {
            1360,
          },
          level = 33,
          location = "Ironforge, Hall of Explorers",
          name = "Reclaimed Treasures",
          x = 0.74,
          y = 0.09,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "Prospector Stormpike",
          ids = {
            2398,
          },
          level = 35,
          location = "Ironforge, Hall of Explorers",
          name = "The Lost Dwarves",
          x = 0.75,
          y = 0.12,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "Baelog's Journal",
          ids = {
            2240,
          },
          level = 35,
          location = "Uldaman, Lost Dwarves area",
          name = "The Hidden Chamber",
          notes = "Complete The Lost Dwarves first.",
          prereqs = {
            {
              ids = {
                2398,
              },
              name = "The Lost Dwarves",
            },
          },
          zone = "Uldaman",
        },
        {
          faction = "Alliance",
          giver = "Ghak Healtouch",
          ids = {
            17,
          },
          level = 38,
          location = "Loch Modan, Thelsamar",
          name = "Uldaman Reagent Run",
          notes = "Complete Badlands Reagent Run first.",
          prereqs = {
            {
              ids = {
                2500,
              },
              name = "Badlands Reagent Run",
            },
          },
          x = 0.37,
          y = 0.49,
          zone = "Loch Modan",
        },
        {
          faction = "Alliance",
          giver = "Prospector Ironband",
          ids = {
            704,
          },
          level = 33,
          location = "Loch Modan, Ironband's Excavation Site",
          name = "Agmond's Fate",
          prereqs = {
            {
              ids = {
                707,
              },
              name = "Ironband Wants You!",
            },
            {
              ids = {
                738,
              },
              name = "Find Agmond",
            },
            {
              ids = {
                739,
              },
              name = "Murdaloc",
            },
          },
          x = 0.65,
          y = 0.65,
          zone = "Loch Modan",
        },
        {
          faction = "Alliance",
          giver = "Advisor Belgrum",
          ids = {
            1139,
          },
          level = 30,
          location = "Ironforge, Hall of Explorers",
          name = "The Lost Tablets of Will",
          prereqs = {
            {
              ids = {
                720,
              },
              name = "A Sign of Hope",
            },
            {
              ids = {
                721,
              },
              name = "A Sign of Hope",
            },
            {
              ids = {
                722,
              },
              name = "Amulet of Secrets",
            },
            {
              ids = {
                723,
              },
              name = "Prospect of Faith",
            },
            {
              ids = {
                724,
              },
              name = "Prospect of Faith",
            },
            {
              ids = {
                725,
              },
              name = "Passing Word of a Threat",
            },
            {
              ids = {
                726,
              },
              name = "Passing Word of a Threat",
            },
            {
              ids = {
                762,
              },
              name = "An Ambassador of Evil",
            },
          },
          x = 0.77,
          y = 0.09,
          zone = "Ironforge",
        },
        {
          faction = "Neutral",
          giver = "Drop: Shattered Necklace from Shadowforge/Shadowvault mobs",
          ids = {
            2198,
          },
          level = 37,
          location = "Badlands, outside Uldaman instance",
          name = "The Shattered Necklace",
          notes = "Drop-only.",
          zone = "Badlands",
        },
        {
          faction = "Neutral",
          giver = "Rigglefuzz",
          ids = {
            2418,
          },
          level = 30,
          location = "Badlands, Central",
          name = "Power Stones",
          x = 0.42,
          y = 0.52,
          zone = "Badlands",
        },
        {
          faction = "Neutral",
          giver = "Theldurin the Lost",
          ids = {
            709,
          },
          level = 30,
          location = "Badlands, Southern",
          name = "Solution to Doom",
          x = 0.51,
          y = 0.76,
          zone = "Badlands",
        },
        {
          faction = "Neutral",
          giver = "Item pickup",
          ids = {
            2278,
          },
          level = 40,
          location = "Uldaman, room after Archaedas",
          name = "The Platinum Discs",
          zone = "Uldaman",
        },
        {
          classOnly = "MAGE",
          faction = "Neutral",
          giver = "Tabetha",
          ids = {
            1956,
          },
          level = 35,
          location = "Dustwallow Marsh, N. of Stonemaul Ruins",
          name = "Power in Uldaman",
          notes = "Mage only.",
          prereqs = {
            {
              ids = {
                1953,
              },
              name = "Return to the Marsh",
            },
            {
              ids = {
                1954,
              },
              name = "The Infernal Orb",
            },
            {
              ids = {
                1955,
              },
              name = "The Exorcism",
            },
          },
          x = 0.46,
          y = 0.57,
          zone = "Dustwallow Marsh",
        },
      },
    },
    {
      keyNote = "At least one player must have the Mallet of Zul'Farrak to summon Gahz'rilla, the end boss.",
      levels = {
        atLevel = 44,
        easy = 50,
        hard = 40,
        medium = 42,
      },
      name = "Zul'Farrak",
      quests = {
        {
          faction = "Horde",
          giver = "Master Gadrin",
          ids = {
            2936,
          },
          level = 40,
          location = "Durotar, Sen'jin Village",
          name = "The Spider God",
          prereqs = {
            {
              ids = {
                2933,
              },
              name = "Venom Bottles",
            },
            {
              ids = {
                2934,
              },
              name = "Undamaged Venom Sac",
            },
            {
              ids = {
                2935,
              },
              name = "Consult Master Gadrin",
            },
          },
          x = 0.56,
          y = 0.74,
          zone = "Durotar",
        },
        {
          faction = "Alliance",
          giver = "Thadius Grimshade",
          ids = {
            2991,
          },
          level = 40,
          location = "Blasted Lands, Nethergarde Keep",
          name = "Nekrum's Medallion",
          prereqs = {
            {
              ids = {
                2988,
              },
              name = "Witherbark Cages",
            },
            {
              ids = {
                2989,
              },
              name = "The Altar of Zul",
            },
            {
              ids = {
                2990,
              },
              name = "Thadius Grimshade",
            },
          },
          x = 0.66,
          y = 0.19,
          zone = "Blasted Lands",
        },
        {
          faction = "Neutral",
          giver = "Chief Engineer Bilgewhizzle",
          ids = {
            2768,
          },
          level = 40,
          location = "Tanaris, Gadgetzan",
          name = "Divino-matic Rod",
          x = 0.52,
          y = 0.28,
          zone = "Tanaris",
        },
        {
          faction = "Neutral",
          giver = "Tran'rek",
          ids = {
            2865,
          },
          level = 40,
          location = "Tanaris, Gadgetzan",
          name = "Scarab Shells",
          x = 0.51,
          y = 0.26,
          zone = "Tanaris",
        },
        {
          faction = "Neutral",
          giver = "Trenton Lighthammer",
          ids = {
            3042,
          },
          level = 40,
          location = "Tanaris, Gadgetzan",
          name = "Troll Temper",
          x = 0.51,
          y = 0.28,
          zone = "Tanaris",
        },
        {
          faction = "Neutral",
          giver = "Tabetha",
          ids = {
            2846,
          },
          level = 40,
          location = "Dustwallow Marsh, N. of Stonemaul Ruins",
          name = "Tiara of the Deep",
          x = 0.46,
          y = 0.57,
          zone = "Dustwallow Marsh",
        },
        {
          faction = "Neutral",
          giver = "Wizzle Brassbolts",
          ids = {
            2770,
          },
          level = 40,
          location = "Thousand Needles, Shimmering Flats",
          name = "Gahz'rilla",
          notes = "Needs the Mallet of Zul'Farrak (drop from Qiaga the Keeper, Hinterlands).",
          x = 0.78,
          y = 0.77,
          zone = "Thousand Needles",
        },
        {
          faction = "Neutral",
          giver = "Yeh'kinya",
          ids = {
            3527,
          },
          level = 40,
          location = "Tanaris, Steamwheedle Port",
          name = "The Prophecy of Mosh'aru",
          notes = "Complete Screecher Spirits first.",
          prereqs = {
            {
              ids = {
                3520,
              },
              name = "Screecher Spirits",
            },
          },
          x = 0.67,
          y = 0.22,
          zone = "Tanaris",
        },
      },
    },
    {
      keyNote = "At least one player must have the Scepter of Celebras to open the portal to Earth Song Falls (skips the orange/purple sides).",
      levels = {
        atLevel = 46,
        easy = 50,
        hard = 41,
        medium = 44,
      },
      name = "Maraudon",
      quests = {
        {
          faction = "Horde",
          giver = "Uthel'nay",
          ids = {
            7068,
          },
          level = 39,
          location = "Orgrimmar, Valley of Spirits",
          name = "Shadowshard Fragments",
          x = 0.39,
          y = 0.86,
          zone = "Orgrimmar",
        },
        {
          faction = "Horde",
          giver = "Vark Battlescar",
          ids = {
            7029,
          },
          level = 41,
          location = "Desolace, Shadowprey Village",
          name = "Vyletongue Corruption",
          x = 0.23,
          y = 0.7,
          zone = "Desolace",
        },
        {
          faction = "Horde",
          giver = "Selendra",
          ids = {
            7064,
          },
          level = 45,
          location = "Desolace, S. of Shadowprey Village",
          name = "Corruption of Earth and Seed",
          x = 0.26,
          y = 0.77,
          zone = "Desolace",
        },
        {
          faction = "Alliance",
          giver = "Archmage Tervosh",
          ids = {
            7070,
          },
          level = 39,
          location = "Dustwallow Marsh, Theramore",
          name = "Shadowshard Fragments",
          x = 0.66,
          y = 0.49,
          zone = "Dustwallow Marsh",
        },
        {
          faction = "Alliance",
          giver = "Talendria",
          ids = {
            7041,
          },
          level = 41,
          location = "Desolace, Nijel's Point",
          name = "Vyletongue Corruption",
          x = 0.68,
          y = 0.08,
          zone = "Desolace",
        },
        {
          faction = "Alliance",
          giver = "Keeper Marandis",
          ids = {
            7065,
          },
          level = 45,
          location = "Desolace, Nijel's Point",
          name = "Corruption of Earth and Seed",
          x = 0.63,
          y = 0.1,
          zone = "Desolace",
        },
        {
          faction = "Neutral",
          giver = "Willow",
          ids = {
            7028,
          },
          level = 41,
          location = "Desolace, SE of Thunderaxe Fortress",
          name = "Twisted Evils",
          x = 0.62,
          y = 0.39,
          zone = "Desolace",
        },
        {
          faction = "Neutral",
          giver = "Cavindra",
          ids = {
            7044,
          },
          level = 41,
          location = "Maraudon, Orange side, outside instance",
          name = "Legends of Maraudon",
          zone = "Maraudon",
        },
        {
          faction = "Neutral",
          giver = "Zaetar's Spirit",
          ids = {
            7066,
          },
          level = 39,
          location = "Maraudon, middle ring, after killing Princess Theradras",
          name = "Seed of Life",
          zone = "Maraudon",
        },
        {
          faction = "Neutral",
          giver = "Centaur Pariah (patrols)",
          ids = {
            7067,
          },
          level = 39,
          location = "Desolace, south of Mannoroc Coven",
          name = "The Pariah's Instructions",
          x = 0.484,
          y = 0.87,
          zone = "Desolace",
        },
        {
          faction = "Neutral",
          giver = "Celebras the Redeemed",
          ids = {
            7046,
          },
          level = 41,
          location = "Maraudon, Purple side",
          name = "The Scepter of Celebras",
          notes = "Complete Legends of Maraudon first.",
          prereqs = {
            {
              ids = {
                7044,
              },
              name = "Legends of Maraudon",
            },
          },
          zone = "Maraudon",
        },
      },
    },
    {
      keyNote = "At least one player must have Yeh'kinya's Scroll to summon the Avatar of Hakkar. Also hosts a per-class Sunken Temple class quest.",
      levels = {
        atLevel = 51,
        easy = 54,
        hard = 46,
        medium = 49,
      },
      name = "Sunken Temple",
      quests = {
        {
          faction = "Horde",
          giver = "Fel'zerul",
          ids = {
            1445,
          },
          level = 38,
          location = "Swamp of Sorrows, Stonard",
          name = "The Temple of Atal'Hakkar",
          prereqs = {
            {
              ids = {
                1424,
              },
              name = "Pool of Tears",
            },
            {
              ids = {
                1429,
              },
              name = "The Atal'ai Exile",
            },
            {
              ids = {
                1444,
              },
              name = "Return to Fel'Zerul",
            },
          },
          x = 0.47,
          y = 0.54,
          zone = "Swamp of Sorrows",
        },
        {
          faction = "Neutral",
          giver = "Liv Rizzlefix",
          ids = {
            4146,
          },
          level = 47,
          location = "The Barrens, Ratchet",
          name = "Zapper Fuel",
          prereqs = {
            {
              ids = {
                4145,
              },
              name = "Larion and Muigin",
            },
            {
              ids = {
                4147,
              },
              name = "Marvon's Workshop",
            },
          },
          x = 0.62,
          y = 0.38,
          zone = "The Barrens",
        },
        {
          faction = "Neutral",
          giver = "Gregan Brewspewer",
          ids = {
            4143,
          },
          level = 47,
          location = "Feralas, Twin Colossals",
          name = "Haze of Evil",
          notes = "Distinct chain from Zapper Fuel despite the similar breadcrumb name.",
          prereqs = {
            {
              ids = {
                4141,
              },
              name = "Muigin and Larion",
            },
            {
              ids = {
                4142,
              },
              name = "A Visit to Gregan",
            },
          },
          x = 0.45,
          y = 0.25,
          zone = "Feralas",
        },
        {
          faction = "Alliance",
          giver = "Brohann Caskbelly",
          ids = {
            1475,
          },
          level = 38,
          location = "Stormwind, Dwarven District",
          name = "Into The Temple of Atal'Hakkar",
          prereqs = {
            {
              ids = {
                1448,
              },
              name = "In Search of The Temple",
            },
            {
              ids = {
                1449,
              },
              name = "To The Hinterlands",
            },
            {
              ids = {
                1450,
              },
              name = "Gryphon Master Talonaxe",
            },
            {
              ids = {
                1451,
              },
              name = "Rhapsody Shindigger",
            },
            {
              ids = {
                1452,
              },
              name = "Rhapsody's Kalimdor Kocktail",
            },
            {
              ids = {
                1469,
              },
              name = "Rhapsody's Tale",
            },
          },
          x = 0.64,
          y = 0.21,
          zone = "Stormwind",
        },
        {
          faction = "Neutral",
          giver = "Atal'ai Exile",
          ids = {
            1446,
          },
          level = 38,
          location = "Hinterlands, spider area SW of Altar of Zul",
          name = "Jammal'an the Prophet",
          x = 0.33,
          y = 0.75,
          zone = "Hinterlands",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop: Essence of Eranikus",
          ids = {
            3373,
          },
          level = 48,
          location = "Sunken Temple",
          name = "The Essence of Eranikus",
          zone = "Sunken Temple",
        },
        {
          faction = "Neutral",
          giver = "Marvon Rivetseeker",
          ids = {
            3446,
          },
          level = 46,
          location = "Tanaris, S. of Gadgetzan",
          name = "Into the Depths",
          notes = "Shares this chain with Secret of the Circle.",
          prereqs = {
            {
              ids = {
                3380,
                3445,
              },
              name = "The Sunken Temple",
            },
            {
              ids = {
                3444,
              },
              name = "The Stone Circle",
            },
          },
          x = 0.52,
          y = 0.45,
          zone = "Tanaris",
        },
        {
          faction = "Neutral",
          giver = "Marvon Rivetseeker",
          ids = {
            3447,
          },
          level = 46,
          location = "Tanaris, S. of Gadgetzan",
          name = "Secret of the Circle",
          notes = "Shares this chain with Into the Depths.",
          prereqs = {
            {
              ids = {
                3380,
                3445,
              },
              name = "The Sunken Temple",
            },
            {
              ids = {
                3444,
              },
              name = "The Stone Circle",
            },
          },
          x = 0.52,
          y = 0.45,
          zone = "Tanaris",
        },
        {
          faction = "Neutral",
          giver = "Yeh'kinya",
          ids = {
            3528,
          },
          level = 40,
          location = "Tanaris, Steamwheedle Port",
          name = "The God Hakkar",
          prereqs = {
            {
              ids = {
                3520,
              },
              name = "Screecher Spirits",
            },
            {
              ids = {
                3527,
              },
              name = "The Prophecy of Mosh'aru",
            },
            {
              ids = {
                4787,
              },
              name = "The Ancient Egg",
            },
          },
          x = 0.67,
          y = 0.22,
          zone = "Tanaris",
        },
      },
    },
    {
      keyNote = "At least one player must have the Shadowforge Key to open the Shadowforge Doors (Lockpicking 280 also works).",
      levels = {
        atLevel = 55,
        easy = 60,
        hard = 50,
        medium = 52,
      },
      name = "Blackrock Depths",
      quests = {
        {
          faction = "Horde",
          giver = "WANTED poster",
          ids = {
            4081,
          },
          level = 48,
          location = "Badlands, Kargath",
          name = "KILL ON SIGHT: Dark Iron Dwarves",
          x = 0.04,
          y = 0.47,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Shadowmage Vivian Lagrave",
          ids = {
            4134,
          },
          level = 50,
          location = "Badlands, Kargath",
          name = "Lost Thunderbrew Recipe",
          notes = "Breadcrumb: Vivian Lagrave in Undercity for easy XP.",
          x = 0.03,
          y = 0.48,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "WANTED poster",
          ids = {
            4082,
          },
          level = 50,
          location = "Badlands, Kargath",
          name = "KILL ON SIGHT: High Ranking Dark Iron Officials",
          notes = "Complete KILL ON SIGHT: Dark Iron Dwarves first.",
          prereqs = {
            {
              ids = {
                4081,
              },
              name = "KILL ON SIGHT: Dark Iron Dwarves",
            },
          },
          x = 0.04,
          y = 0.47,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Lotwil Veriatus",
          ids = {
            4063,
          },
          level = 52,
          location = "Badlands, Eastern",
          name = "The Rise of the Machines",
          prereqs = {
            {
              ids = {
                4061,
              },
              name = "The Rise of the Machines",
            },
            {
              ids = {
                4062,
              },
              name = "The Rise of the Machines",
            },
          },
          x = 0.25,
          y = 0.44,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Thunderheart",
          ids = {
            3906,
          },
          level = 48,
          location = "Badlands, Kargath",
          name = "Disharmony of Flame",
          x = 0.036,
          y = 0.48,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Thunderheart",
          ids = {
            3907,
          },
          level = 48,
          location = "Badlands, Kargath",
          name = "Disharmony of Fire",
          notes = "Opens after Disharmony of Flame.",
          prereqs = {
            {
              ids = {
                3906,
              },
              name = "Disharmony of Flame",
            },
          },
          x = 0.036,
          y = 0.48,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Galamav the Marksman",
          ids = {
            3981,
          },
          level = 48,
          location = "Badlands, Kargath",
          name = "Commander Gor'shak",
          notes = "Opens after Disharmony of Flame.",
          prereqs = {
            {
              ids = {
                3906,
              },
              name = "Disharmony of Flame",
            },
          },
          x = 0.06,
          y = 0.47,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Shadowmage Vivian Lagrave",
          ids = {
            7201,
            3911,
          },
          level = 48,
          location = "Badlands, Kargath",
          name = "The Last Element",
          notes = "Opens after Disharmony of Flame.",
          prereqs = {
            {
              ids = {
                3906,
              },
              name = "Disharmony of Flame",
            },
          },
          x = 0.03,
          y = 0.48,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Warlord Goretooth",
          ids = {
            4132,
          },
          level = 52,
          location = "Badlands, Kargath",
          name = "Operation: Death to Angerforge",
          notes = "Includes a long escort (Grark Lorkrub).",
          prereqs = {
            {
              ids = {
                4081,
              },
              name = "KILL ON SIGHT: Dark Iron Dwarves",
            },
            {
              ids = {
                4082,
              },
              name = "KILL ON SIGHT: High Ranking Dark Iron Officials",
            },
            {
              ids = {
                4122,
              },
              name = "Grark Lorkrub",
            },
            {
              ids = {
                4121,
              },
              name = "Precarious Predicament",
            },
          },
          x = 0.06,
          y = 0.47,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Thrall",
          ids = {
            4003,
          },
          level = 48,
          location = "Orgrimmar, Valley of Wisdom",
          name = "The Royal Rescue",
          prereqs = {
            {
              ids = {
                3981,
              },
              name = "Commander Gor'shak",
            },
            {
              ids = {
                3982,
              },
              name = "What Is Going On?",
            },
            {
              ids = {
                4001,
              },
              name = "What Is Going On?",
            },
            {
              ids = {
                4002,
              },
              name = "The Eastern Kingdoms",
            },
          },
          x = 0.32,
          y = 0.38,
          zone = "Orgrimmar",
        },
        {
          faction = "Alliance",
          giver = "Jalinda Sprig",
          ids = {
            4262,
          },
          level = 48,
          location = "Burning Steppes, Morgan's Vigil",
          name = "Overmaster Pyron",
          x = 0.85,
          y = 0.7,
          zone = "Burning Steppes",
        },
        {
          faction = "Alliance",
          giver = "Jalinda Sprig",
          ids = {
            4263,
          },
          level = 48,
          location = "Burning Steppes, Morgan's Vigil",
          name = "Incendius!",
          notes = "Complete Overmaster Pyron first.",
          prereqs = {
            {
              ids = {
                4262,
              },
              name = "Overmaster Pyron",
            },
          },
          x = 0.85,
          y = 0.7,
          zone = "Burning Steppes",
        },
        {
          faction = "Alliance",
          giver = "Oralius",
          ids = {
            4286,
          },
          level = 50,
          location = "Burning Steppes, Morgan's Vigil",
          name = "The Good Stuff",
          x = 0.84,
          y = 0.68,
          zone = "Burning Steppes",
        },
        {
          faction = "Alliance",
          giver = "Ragnar Thunderbrew",
          ids = {
            4126,
          },
          level = 50,
          location = "Dun Morogh, Kharanos",
          name = "Hurley Blackbreath",
          x = 0.46,
          y = 0.52,
          zone = "Dun Morogh",
        },
        {
          faction = "Alliance",
          giver = "King Magni Bronzebeard",
          ids = {
            4341,
          },
          level = 50,
          location = "Ironforge, Throne Room",
          name = "Kharan Mighthammer",
          prereqs = {
            {
              ids = {
                3702,
              },
              name = "The Smoldering Ruins of Thaurissan",
            },
            {
              ids = {
                3701,
              },
              name = "The Smoldering Ruins of Thaurissan",
            },
          },
          x = 0.39,
          y = 0.56,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "King Magni Bronzebeard",
          ids = {
            4362,
          },
          level = 50,
          location = "Ironforge, Throne Room",
          name = "The Fate of the Kingdom",
          prereqs = {
            {
              ids = {
                4341,
              },
              name = "Kharan Mighthammer",
            },
          },
          x = 0.39,
          y = 0.56,
          zone = "Ironforge",
        },
        {
          faction = "Alliance",
          giver = "Marshal Maxwell",
          ids = {
            4241,
          },
          level = 48,
          location = "Burning Steppes, Morgan's Vigil",
          name = "Marshal Windsor",
          prereqs = {
            {
              ids = {
                4182,
              },
              name = "Dragonkin Menace",
            },
            {
              ids = {
                4224,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4183,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4184,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4185,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4186,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4223,
              },
              name = "The True Masters",
            },
          },
          x = 0.84,
          y = 0.68,
          zone = "Burning Steppes",
        },
        {
          faction = "Alliance",
          giver = "Marshal Windsor",
          ids = {
            4322,
          },
          level = 50,
          location = "Blackrock Depths, Prison Cell",
          name = "Jail Break!",
          prereqs = {
            {
              ids = {
                4182,
              },
              name = "Dragonkin Menace",
            },
            {
              ids = {
                4224,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4183,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4184,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4185,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4186,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4223,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4241,
              },
              name = "Marshal Windsor",
            },
            {
              ids = {
                4242,
              },
              name = "Abandoned Hope",
            },
            {
              ids = {
                4264,
              },
              name = "A Crumpled Up Note",
            },
            {
              ids = {
                4282,
              },
              name = "A Shred of Hope",
            },
          },
          zone = "Blackrock Depths",
        },
        {
          faction = "Neutral",
          giver = "Yuka Screwspigot",
          ids = {
            4136,
          },
          level = 50,
          location = "Burning Steppes, Flame Crest",
          name = "Ribbly Screwspigot",
          notes = "Breadcrumb: Yuka Screwspigot in Steamwheedle Port for easy XP.",
          x = 0.66,
          y = 0.21,
          zone = "Burning Steppes",
        },
        {
          faction = "Neutral",
          giver = "Maxwort Uberglint",
          ids = {
            4123,
          },
          level = 50,
          location = "Burning Steppes, Flame Crest",
          name = "The Heart of the Mountain",
          x = 0.65,
          y = 0.23,
          zone = "Burning Steppes",
        },
        {
          faction = "Neutral",
          giver = "Lothos Riftwaker",
          ids = {
            7848,
            7487,
          },
          level = 55,
          location = "Blackrock Mountain",
          name = "Attunement to the Core",
          zone = "Blackrock Mountain",
        },
        {
          faction = "Neutral",
          giver = "Franclorn Forgewright",
          ids = {
            3802,
          },
          level = 48,
          location = "Blackrock Mountain, structure in the middle",
          name = "Dark Iron Legacy",
          notes = "NPC only visible while you are dead.",
          prereqs = {
            {
              ids = {
                3801,
              },
              name = "Dark Iron Legacy",
            },
          },
          zone = "Blackrock Mountain",
        },
        {
          faction = "Neutral",
          giver = "Mistress Nagmara",
          ids = {
            4201,
          },
          level = 50,
          location = "Blackrock Depths, Grim Guzzler",
          name = "The Love Potion",
          zone = "Blackrock Depths",
        },
        {
          faction = "Neutral",
          giver = "Cyrus Therepentous",
          ids = {
            4024,
          },
          level = 52,
          location = "Burning Steppes, cave in NE",
          name = "A Taste of Flame",
          notes = "Chain of 11 starting with Divine Retribution (only the last 2 local steps are ID-tracked below).",
          prereqs = {
            {
              ids = {
                4022,
                4023,
              },
              name = "A Taste of Flame",
            },
          },
          x = 0.95,
          y = 0.31,
          zone = "Burning Steppes",
        },
      },
    },
    {
      keyNote = "At least one player must have the Crescent Key to open the West and North wings of Dire Maul (Lockpicking 300 also works).",
      levels = {
        atLevel = 56,
        easy = 60,
        hard = 52,
        medium = 54,
      },
      name = "Dire Maul: East (Warpwood Quarter)",
      quests = {
        {
          faction = "Horde",
          giver = "Talo Thornhoof",
          ids = {
            7489,
          },
          level = 54,
          location = "Feralas, Camp Mojache",
          name = "Lethtendris's Web",
          x = 0.76,
          y = 0.43,
          zone = "Feralas",
        },
        {
          faction = "Alliance",
          giver = "Latronicus Moonspear",
          ids = {
            7488,
          },
          level = 54,
          location = "Feralas, Feathermoon Stronghold",
          name = "Lethtendris's Web",
          x = 0.3,
          y = 0.46,
          zone = "Feralas",
        },
        {
          faction = "Neutral",
          giver = "Azj'Tordin",
          ids = {
            7441,
          },
          level = 54,
          location = "Feralas, Lariss Pavilion",
          name = "Pusillin and the Elder Azj'Tordin",
          x = 0.76,
          y = 0.37,
          zone = "Feralas",
        },
        {
          faction = "Neutral",
          giver = "Rabine Saturna",
          ids = {
            5526,
          },
          level = 56,
          location = "Moonglade, Nighthaven",
          name = "Shards of the Felvine",
          notes = "Complete A Reliquary of Purity from the same NPC and explore all of Dire Maul first.",
          prereqs = {
            {
              ids = {
                5527,
              },
              name = "A Reliquary of Purity",
            },
          },
          x = 0.51,
          y = 0.45,
          zone = "Moonglade",
        },
        {
          classOnly = "MAGE",
          faction = "Neutral",
          giver = "Lorekeeper Lydros",
          ids = {
            7463,
          },
          level = 60,
          location = "Dire Maul, Library",
          name = "Arcane Refreshment",
          notes = "Mage only.",
          zone = "Dire Maul",
        },
      },
    },
    {
      levels = {
        atLevel = 60,
        hard = 54,
        medium = 56,
      },
      name = "Dire Maul: West (Capital Gardens)",
      quests = {
        {
          faction = "Neutral",
          giver = "Shen'dralar Ancient",
          ids = {
            7461,
          },
          level = 56,
          location = "Dire Maul, West, second floor",
          name = "The Madness Within",
          zone = "Dire Maul",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Nostro's Compendium of Dragon Slaying",
          ids = {
            7507,
          },
          level = 60,
          location = "Dire Maul",
          name = "Foror's Compendium",
          notes = "Rare drop, or looted from A Dusty Tome. Not BoP; used to craft a BoP tanking sword (item #18348).",
          zone = "Dire Maul",
        },
      },
    },
    {
      levels = {
        atLevel = 60,
        hard = 54,
        medium = 56,
      },
      name = "Dire Maul: North (Gordok Commons)",
      quests = {
        {
          faction = "Horde",
          giver = "Sage Korolusk",
          ids = {
            7481,
          },
          level = 54,
          location = "Feralas, Camp Mojache",
          name = "Elven Legends",
          notes = "Eligibility for Libram of Protection/Rapidity/Focus.",
          x = 0.74,
          y = 0.43,
          zone = "Feralas",
        },
        {
          faction = "Alliance",
          giver = "Scholar Runethorn",
          ids = {
            7482,
          },
          level = 54,
          location = "Feralas, Feathermoon Stronghold",
          name = "Elven Legends",
          notes = "Eligibility for Libram of Protection/Rapidity/Focus.",
          x = 0.31,
          y = 0.43,
          zone = "Feralas",
        },
        {
          faction = "Neutral",
          giver = "Knot Thimblejack",
          ids = {
            5525,
            7429,
          },
          level = 56,
          location = "Dire Maul, North",
          name = "Free Knot!",
          notes = "Cannot be completed during a Tribute Run unless a party member already has the Gordok Shackle Key. One of the two IDs is the repeatable variant.",
          zone = "Dire Maul",
        },
        {
          faction = "Neutral",
          giver = "Knot Thimblejack",
          ids = {
            5518,
            5519,
          },
          level = 56,
          location = "Dire Maul, North",
          name = "The Gordok Ogre Suit",
          zone = "Dire Maul",
        },
        {
          faction = "Neutral",
          giver = "Stomper Kreeg",
          ids = {
            5528,
          },
          level = 56,
          location = "Dire Maul, North",
          name = "The Gordok Taste Test",
          notes = "Can only be picked up after completing a Tribute Run.",
          zone = "Dire Maul",
        },
        {
          faction = "Neutral",
          giver = "Captain Kromcrush",
          ids = {
            7703,
            1318,
          },
          level = 56,
          location = "Dire Maul, North",
          name = "Unfinished Gordok Business",
          notes = "Requires one Tribute Run, then a second after killing Prince Tortheldrin and looting the Gauntlet of Gordok Might.",
          zone = "Dire Maul",
        },
      },
    },
    {
      levels = {
        atLevel = 60,
        hard = 55,
        medium = 56,
      },
      name = "Lower Blackrock Spire",
      quests = {
        {
          faction = "Neutral",
          giver = "Galamav the Marksman",
          ids = {
            4724,
          },
          level = 55,
          location = "Badlands, Kargath",
          name = "The Pack Mistress",
          x = 0.06,
          y = 0.47,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Lexlort",
          ids = {
            4981,
          },
          level = 55,
          location = "Badlands, Kargath",
          name = "Operative Bijou",
          notes = "Leads to Bijou's Belongings inside LBRS.",
          x = 0.05,
          y = 0.47,
          zone = "Badlands",
        },
        {
          faction = "Neutral",
          giver = "Warlord Goretooth",
          ids = {
            4903,
          },
          level = 55,
          location = "Badlands, Kargath",
          name = "Warlord's Command",
          x = 0.05,
          y = 0.47,
          zone = "Badlands",
        },
        {
          faction = "Neutral",
          giver = "Helendis Riverhorn",
          ids = {
            4701,
          },
          level = 55,
          location = "Burning Steppes, Morgan's Vigil",
          name = "Put Her Down",
          x = 0.65,
          y = 0.69,
          zone = "Burning Steppes",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop from Overlord Wyrmthalak",
          ids = {
            5089,
          },
          level = 55,
          location = "Blackrock Spire, Lower",
          name = "General Drakkisath's Command",
          zone = "Blackrock Spire",
        },
        {
          faction = "Horde",
          giver = "Bijou",
          ids = {
            4982,
          },
          level = 55,
          location = "Blackrock Spire, Lower",
          name = "Bijou's Belongings",
          prereqs = {
            {
              ids = {
                4981,
              },
              name = "Operative Bijou",
            },
          },
          zone = "Blackrock Spire",
        },
        {
          faction = "Alliance",
          giver = "Bijou",
          ids = {
            5001,
          },
          level = 55,
          location = "Blackrock Spire, Lower",
          name = "Bijou's Belongings",
          zone = "Blackrock Spire",
        },
        {
          faction = "Neutral",
          giver = "Kibler",
          ids = {
            4862,
          },
          level = 55,
          location = "Burning Steppes, Flame Crest",
          name = "En-Ay-Es-Tee-Why",
          x = 0.65,
          y = 0.21,
          zone = "Burning Steppes",
        },
        {
          faction = "Neutral",
          giver = "Kibler",
          ids = {
            4729,
          },
          level = 55,
          location = "Burning Steppes, Flame Crest",
          name = "Kibler's Exotic Pets",
          x = 0.65,
          y = 0.21,
          zone = "Burning Steppes",
        },
        {
          faction = "Neutral",
          giver = "Ragged John",
          ids = {
            4866,
          },
          level = 55,
          location = "Burning Steppes, Flame Crest",
          name = "Mother's Milk",
          x = 0.65,
          y = 0.23,
          zone = "Burning Steppes",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop: Unadorned Seal of Ascension + 3 Gemstones",
          ids = {
            4743,
          },
          level = 57,
          location = "Blackrock Spire, Lower",
          name = "Seal of Ascension",
          prereqs = {
            {
              ids = {
                4742,
              },
              name = "Seal of Ascension",
            },
          },
          zone = "Blackrock Spire",
        },
        {
          faction = "Neutral",
          giver = "Warosh (patrols)",
          ids = {
            4867,
          },
          level = 55,
          location = "Blackrock Spire, Lower, near beginning",
          name = "Urok Doomhowl",
          zone = "Blackrock Spire",
        },
        {
          faction = "Neutral",
          giver = "Prospector Ironboot",
          ids = {
            4788,
          },
          level = 40,
          location = "Tanaris, Steamwheedle Port",
          name = "The Final Tablets",
          prereqs = {
            {
              ids = {
                3520,
              },
              name = "Screecher Spirits",
            },
            {
              ids = {
                3527,
              },
              name = "The Prophecy of Mosh'aru",
            },
            {
              ids = {
                4787,
              },
              name = "The Ancient Egg",
            },
            {
              ids = {
                3528,
              },
              name = "The God Hakkar",
            },
            {
              ids = {
                5065,
              },
              name = "The Lost Tablets of Mosh'aru",
            },
          },
          x = 0.66,
          y = 0.24,
          zone = "Tanaris",
        },
      },
    },
    {
      keyNote = "At least one player must have the Skeleton Key to open the front door in Caer Darrow.",
      levels = {
        atLevel = 60,
        hard = 54,
        medium = 56,
      },
      name = "Scholomance",
      quests = {
        {
          faction = "Horde",
          giver = "Alexi Barov",
          ids = {
            5341,
          },
          level = 52,
          location = "Tirisfal Glades, The Bulwark",
          name = "Barov Family Fortune",
          notes = "May be dead due to Alliance kill quest; 30 minute spawn timer.",
          x = 0.83,
          y = 0.71,
          zone = "Tirisfal Glades",
        },
        {
          classOnly = "SHAMAN",
          faction = "Horde",
          giver = "Sagorne Creststrider",
          ids = {
            7668,
            8258,
          },
          level = 58,
          location = "Orgrimmar, Valley of Wisdom",
          name = "The Darkreaver Menace",
          notes = "Shaman only.",
          prereqs = {
            {
              ids = {
                7667,
              },
              name = "Material Assistance",
            },
          },
          x = 0.38,
          y = 0.35,
          zone = "Orgrimmar",
        },
        {
          faction = "Alliance",
          giver = "Weldon Barov",
          ids = {
            5343,
          },
          level = 52,
          location = "Western Plaguelands, Chillwind Camp",
          name = "Barov Family Fortune",
          notes = "May be dead due to Horde kill quest; 30 minute spawn timer.",
          x = 0.43,
          y = 0.83,
          zone = "Western Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Betina Bigglezink",
          ids = {
            5529,
          },
          level = 55,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "Plagued Hatchlings",
          x = 0.81,
          y = 0.59,
          zone = "Eastern Plaguelands",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop from Plagued Hatchlings",
          ids = {
            5582,
          },
          level = 55,
          location = "Scholomance",
          name = "Healthy Dragon Scale",
          notes = "Repeatable for Argent Dawn rep. Complete Plagued Hatchlings first.",
          prereqs = {
            {
              ids = {
                5529,
              },
              name = "Plagued Hatchlings",
            },
          },
          zone = "Scholomance",
        },
        {
          faction = "Neutral",
          giver = "Eva Sarkhoff",
          ids = {
            5382,
          },
          level = 55,
          location = "Western Plaguelands, Caer Darrow",
          name = "Doctor Theolen Krastinov, the Butcher",
          x = 0.7,
          y = 0.73,
          zone = "Western Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Eva Sarkhoff",
          ids = {
            5515,
          },
          level = 55,
          location = "Western Plaguelands, Caer Darrow",
          name = "Krastinov's Bag of Horrors",
          notes = "Complete Doctor Theolen Krastinov, the Butcher first.",
          prereqs = {
            {
              ids = {
                5382,
              },
              name = "Doctor Theolen Krastinov, the Butcher",
            },
          },
          x = 0.7,
          y = 0.73,
          zone = "Western Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Eva Sarkhoff",
          ids = {
            5384,
          },
          level = 55,
          location = "Western Plaguelands, Caer Darrow",
          name = "Kirtonos the Herald",
          notes = "Complete Krastinov's Bag of Horrors first; keep item #13544.",
          prereqs = {
            {
              ids = {
                5515,
              },
              name = "Krastinov's Bag of Horrors",
            },
          },
          x = 0.7,
          y = 0.73,
          zone = "Western Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Betina Bigglezink",
          ids = {
            4771,
          },
          level = 57,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "Dawn's Gambit",
          prereqs = {
            {
              ids = {
                4726,
              },
              name = "Broodling Essence",
            },
            {
              ids = {
                4808,
              },
              name = "Felnok Steelspring",
            },
            {
              ids = {
                4809,
              },
              name = "Chillwind Horns",
            },
            {
              ids = {
                4810,
              },
              name = "Return to Tinkee",
            },
            {
              ids = {
                4907,
              },
              name = "Tinkee Steamboil",
            },
            {
              ids = {
                4734,
              },
              name = "Egg Freezing",
            },
            {
              ids = {
                4735,
              },
              name = "Egg Collection",
            },
            {
              ids = {
                5522,
              },
              name = "Leonid Barthalomew",
            },
            {
              ids = {
                5531,
              },
              name = "Betina Bigglezink",
            },
          },
          x = 0.81,
          y = 0.59,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Magistrate Marduke",
          ids = {
            5466,
          },
          level = 57,
          location = "Western Plaguelands, Caer Darrow",
          name = "The Lich, Ras Frostwhisper",
          notes = "Must have item #13544 equipped to see Marduke.",
          prereqs = {
            {
              ids = {
                5382,
              },
              name = "Doctor Theolen Krastinov, the Butcher",
            },
            {
              ids = {
                5515,
              },
              name = "Krastinov's Bag of Horrors",
            },
            {
              ids = {
                5384,
              },
              name = "Kirtonos the Herald",
            },
            {
              ids = {
                5461,
              },
              name = "The Human, Ras Frostwhisper",
            },
            {
              ids = {
                5462,
              },
              name = "The Dying, Ras Frostwhisper",
            },
            {
              ids = {
                5463,
              },
              name = "Menethil's Gift",
            },
            {
              ids = {
                5464,
              },
              name = "Menethil's Gift",
            },
            {
              ids = {
                5465,
              },
              name = "Soulbound Keepsake",
            },
          },
          x = 0.7,
          y = 0.74,
          zone = "Western Plaguelands",
        },
      },
    },
    {
      keyNote = "At least one player needs The Scarlet Key (Live Side, Scarlet Hold) and the Key to the City (side entrance to Undead side); Lockpicking 275 also works for both.",
      levels = {
        atLevel = 60,
        hard = 54,
        medium = 56,
      },
      name = "Stratholme: Live Side",
      quests = {
        {
          faction = "Neutral",
          giver = "Smokey LaRue",
          ids = {
            5214,
          },
          level = 55,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "The Great Fras Siabi",
          notes = "Renamed from Classic's \"The Great Ezra Grimm\" in Forever -- same quest, same giver.",
          x = 0.8,
          y = 0.58,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Duke Nicholas Zverenhoff",
          ids = {
            5251,
          },
          level = 55,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "The Archivist",
          x = 0.81,
          y = 0.59,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Egan",
          ids = {
            5282,
          },
          level = 55,
          location = "Eastern Plaguelands, Terrordale",
          name = "The Restless Souls",
          x = 0.14,
          y = 0.33,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Aurius",
          ids = {
            5122,
          },
          level = 55,
          location = "Stratholme, Undead Side, inside chapel at beginning",
          name = "The Medallion of Faith",
          notes = "Complete The Restless Souls (Undead side) first.",
          prereqs = {
            {
              ids = {
                5282,
              },
              name = "The Restless Souls",
            },
          },
          zone = "Stratholme",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop: Head of Balnazzar from Balnazzar",
          ids = {
            5262,
          },
          level = 55,
          location = "Stratholme, Live Side",
          name = "The Truth Comes Crashing Down",
          notes = "Complete The Archivist to be eligible.",
          prereqs = {
            {
              ids = {
                5251,
              },
              name = "The Archivist",
            },
          },
          zone = "Stratholme",
        },
        {
          faction = "Neutral",
          giver = "Artist Renfray",
          ids = {
            5848,
          },
          level = 52,
          location = "Western Plaguelands, Caer Darrow",
          name = "Of Love and Family",
          notes = "Blood Tinged Skies, Carrion Grubbage, and Demon Dogs are all required, in any order.",
          prereqs = {
            {
              ids = {
                5543,
              },
              name = "Blood Tinged Skies",
            },
            {
              ids = {
                5544,
              },
              name = "Carrion Grubbage",
            },
            {
              ids = {
                5542,
              },
              name = "Demon Dogs",
            },
            {
              ids = {
                5742,
              },
              name = "Redemption",
            },
            {
              ids = {
                5781,
              },
              name = "Of Forgotten Memories",
            },
            {
              ids = {
                5845,
              },
              name = "Of Lost Honor",
            },
          },
          x = 0.65,
          y = 0.75,
          zone = "Western Plaguelands",
        },
      },
    },
    {
      levels = {
        atLevel = 60,
        hard = 54,
        medium = 56,
      },
      name = "Stratholme: Undead Side",
      quests = {
        {
          faction = "Neutral",
          giver = "Nathanos Blightcaller",
          ids = {
            6163,
          },
          level = 56,
          location = "Eastern Plaguelands, Marris Stead",
          name = "Ramstein",
          notes = "A second claimed starter, To Kill With Purpose, could not be confirmed as linking into this chain -- may be an independent breadcrumb.",
          prereqs = {
            {
              ids = {
                6133,
              },
              name = "The Ranger Lord's Behest",
            },
            {
              ids = {
                6135,
              },
              name = "Duskwing, Oh How I Hate Thee...",
            },
          },
          x = 0.26,
          y = 0.74,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Leonid Barthalomew the Revered",
          ids = {
            5243,
          },
          level = 55,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "Houses of the Holy",
          x = 0.81,
          y = 0.57,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Betina Bigglezink",
          ids = {
            5212,
          },
          level = 55,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "The Flesh Does Not Lie",
          x = 0.81,
          y = 0.59,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Betina Bigglezink",
          ids = {
            5213,
          },
          level = 55,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "The Active Agent",
          notes = "Complete The Flesh Does Not Lie first.",
          prereqs = {
            {
              ids = {
                5212,
              },
              name = "The Flesh Does Not Lie",
            },
          },
          x = 0.81,
          y = 0.59,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Aurius",
          ids = {
            5125,
          },
          level = 55,
          location = "Stratholme, Undead Side, chapel at beginning",
          name = "Aurius' Reckoning",
          notes = "Complete The Medallion of Faith first.",
          prereqs = {
            {
              ids = {
                5122,
              },
              name = "The Medallion of Faith",
            },
          },
          zone = "Stratholme",
        },
        {
          faction = "Neutral",
          giver = "Duke Nicholas Zverenhoff",
          ids = {
            5263,
          },
          level = 55,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "Above and Beyond",
          prereqs = {
            {
              ids = {
                5251,
              },
              name = "The Archivist",
            },
            {
              ids = {
                5262,
              },
              name = "The Truth Comes Crashing Down",
            },
          },
          x = 0.81,
          y = 0.59,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Leonid Barthalomew the Revered",
          ids = {
            5463,
          },
          level = 57,
          location = "Eastern Plaguelands, Light's Hope Chapel",
          name = "Menethil's Gift",
          prereqs = {
            {
              ids = {
                5382,
              },
              name = "Doctor Theolen Krastinov, the Butcher",
            },
            {
              ids = {
                5515,
              },
              name = "Krastinov's Bag of Horrors",
            },
            {
              ids = {
                5384,
              },
              name = "Kirtonos the Herald",
            },
            {
              ids = {
                5461,
              },
              name = "The Human, Ras Frostwhisper",
            },
            {
              ids = {
                5462,
              },
              name = "The Dying, Ras Frostwhisper",
            },
          },
          x = 0.81,
          y = 0.57,
          zone = "Eastern Plaguelands",
        },
        {
          faction = "Neutral",
          giver = "Anthion Harmon",
          ids = {
            8945,
          },
          level = 58,
          location = "Eastern Plaguelands, Stratholme Main Entrance",
          name = "Dead Man's Plea",
          notes = "Requires the Extra-Dimensional Ghost Revealer to see the quest NPC. One step (Return to Deliana for Alliance / Return to Mokvar for Horde) is faction-specific and omitted below -- Just Compensation implies it.",
          prereqs = {
            {
              ids = {
                8922,
                8923,
              },
              name = "A Supernatural Device",
            },
            {
              ids = {
                8921,
              },
              name = "The Ectoplasmic Distiller",
            },
            {
              ids = {
                8924,
              },
              name = "Hunting for Ectoplasm",
            },
            {
              ids = {
                8925,
              },
              name = "A Portable Power Source",
            },
            {
              ids = {
                8928,
              },
              name = "A Shifty Merchant",
            },
            {
              ids = {
                8926,
                8944,
                8936,
                8935,
                8938,
                8941,
                8927,
                8933,
                8940,
                8937,
                8932,
                8931,
                8939,
                8943,
                8934,
                8942,
              },
              name = "Just Compensation",
            },
            {
              ids = {
                8929,
                8930,
              },
              name = "In Search of Anthion",
            },
          },
          x = 0.3,
          y = 0.16,
          zone = "Eastern Plaguelands",
        },
      },
    },
    {
      keyNote = "At least one player must have item #12344 to enter Upper Blackrock Spire.",
      levels = {
        atLevel = 60,
        hard = 54,
        medium = 56,
      },
      name = "Upper Blackrock Spire",
      quests = {
        {
          faction = "Neutral",
          giver = "Shadowmage Vivian Lagrave",
          ids = {
            4768,
          },
          level = 57,
          location = "Badlands, Kargath",
          name = "The Darkstone Tablet",
          notes = "Breadcrumb: Vivian Lagrave and the Darkstone Tablet in Undercity for easy XP.",
          x = 0.03,
          y = 0.48,
          zone = "Badlands",
        },
        {
          faction = "Horde",
          giver = "Thrall",
          ids = {
            4974,
          },
          level = 55,
          location = "Orgrimmar, Valley of Wisdom",
          name = "For The Horde!",
          prereqs = {
            {
              ids = {
                4903,
              },
              name = "Warlord's Command",
            },
            {
              ids = {
                4941,
              },
              name = "Eitrigg's Wisdom",
            },
          },
          x = 0.31,
          y = 0.37,
          zone = "Orgrimmar",
        },
        {
          faction = "Horde",
          giver = "Rexxar (patrols)",
          ids = {
            6602,
          },
          level = 55,
          location = "Desolace",
          name = "Blood of the Black Dragon Champion",
          notes = "Shares its first 3 prerequisite steps with For The Horde!.",
          prereqs = {
            {
              ids = {
                4903,
              },
              name = "Warlord's Command",
            },
            {
              ids = {
                4941,
              },
              name = "Eitrigg's Wisdom",
            },
            {
              ids = {
                6566,
              },
              name = "What the Wind Carries",
            },
            {
              ids = {
                6567,
              },
              name = "The Champion of the Horde",
            },
            {
              ids = {
                6568,
              },
              name = "The Testament of Rexxar",
            },
            {
              ids = {
                6569,
              },
              name = "Oculus Illusions",
            },
            {
              ids = {
                6570,
              },
              name = "Emberstrife",
            },
            {
              ids = {
                6584,
              },
              name = "The Test of Skulls, Chronalis",
            },
            {
              ids = {
                6582,
              },
              name = "The Test of Skulls, Scryer",
            },
            {
              ids = {
                6583,
              },
              name = "The Test of Skulls, Somnus",
            },
            {
              ids = {
                6585,
              },
              name = "The Test of Skulls, Axtroz",
            },
            {
              ids = {
                6601,
              },
              name = "Ascension...",
            },
          },
          zone = "Desolace",
        },
        {
          faction = "Alliance",
          giver = "Mayara Brightwing",
          ids = {
            4764,
          },
          level = 57,
          location = "Burning Steppes, Morgan's Vigil",
          name = "Doomrigger's Clasp",
          notes = "Breadcrumb: Mayara Brightwing in Stormwind Keep for easy XP.",
          x = 0.84,
          y = 0.69,
          zone = "Burning Steppes",
        },
        {
          faction = "Alliance",
          giver = "Marshal Maxwell",
          ids = {
            5102,
          },
          level = 55,
          location = "Burning Steppes, Morgan's Vigil",
          name = "General Drakkisath's Demise",
          notes = "Requires General Drakkisath's Command first.",
          prereqs = {
            {
              ids = {
                5089,
              },
              name = "General Drakkisath's Command",
            },
          },
          x = 0.84,
          y = 0.68,
          zone = "Burning Steppes",
        },
        {
          faction = "Neutral",
          giver = "Haleh",
          ids = {
            6502,
          },
          level = 50,
          location = "Winterspring, Mazthoril",
          name = "Drakefire Amulet",
          notes = "Step on the blue rune at end of cave to spawn Haleh.",
          prereqs = {
            {
              ids = {
                4182,
              },
              name = "Dragonkin Menace",
            },
            {
              ids = {
                4224,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4183,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4184,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4185,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4186,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4223,
              },
              name = "The True Masters",
            },
            {
              ids = {
                4241,
              },
              name = "Marshal Windsor",
            },
            {
              ids = {
                4242,
              },
              name = "Abandoned Hope",
            },
            {
              ids = {
                4264,
              },
              name = "A Crumpled Up Note",
            },
            {
              ids = {
                4282,
              },
              name = "A Shred of Hope",
            },
            {
              ids = {
                4322,
              },
              name = "Jail Break!",
            },
            {
              ids = {
                6402,
              },
              name = "Stormwind Rendezvous",
            },
            {
              ids = {
                6403,
              },
              name = "The Great Masquerade",
            },
            {
              ids = {
                6501,
              },
              name = "The Dragon's Eye",
            },
          },
          x = 0.56,
          y = 0.49,
          zone = "Winterspring",
        },
        {
          dungeonDrop = true,
          faction = "Neutral",
          giver = "Drop from Scarshield Quartermaster",
          ids = {
            7761,
          },
          level = 55,
          location = "Blackrock Mountain, side hallway on the way to BWL",
          name = "Blackhand's Command",
          zone = "Blackrock Mountain",
        },
        {
          faction = "Neutral",
          giver = "Awbee",
          ids = {
            5160,
          },
          level = 57,
          location = "Blackrock Spire, Upper, ledge in room after killing Blackhand",
          name = "The Matron Protectorate",
          zone = "Blackrock Spire",
        },
        {
          faction = "Neutral",
          giver = "Pip Quickwit",
          ids = {
            5047,
          },
          level = 57,
          location = "Blackrock Spire, Upper",
          name = "Finkle Einhorn, At Your Service!",
          notes = "Only spawns after skinning (300) The Beast with Pip Quickwit.",
          zone = "Blackrock Spire",
        },
        {
          faction = "Neutral",
          giver = "Tinkee Steamboil",
          ids = {
            4735,
          },
          level = 57,
          location = "Burning Steppes, Flame Crest",
          name = "Egg Collection",
          notes = "Egg Freezing (the last prereq step) is not a second starting point.",
          prereqs = {
            {
              ids = {
                4726,
              },
              name = "Broodling Essence",
            },
            {
              ids = {
                4808,
              },
              name = "Felnok Steelspring",
            },
            {
              ids = {
                4809,
              },
              name = "Chillwind Horns",
            },
            {
              ids = {
                4810,
              },
              name = "Return to Tinkee",
            },
            {
              ids = {
                4907,
              },
              name = "Tinkee Steamboil",
            },
            {
              ids = {
                4734,
              },
              name = "Egg Freezing",
            },
          },
          x = 0.65,
          y = 0.23,
          zone = "Burning Steppes",
        },
        {
          faction = "Neutral",
          giver = "Duke Hydraxis",
          ids = {
            6821,
          },
          level = 55,
          location = "Azshara",
          name = "Eye of the Emberseer",
          notes = "Stormers and Rumblers and Poisoned Water are both required, in any order.",
          prereqs = {
            {
              ids = {
                6805,
              },
              name = "Stormers and Rumblers",
            },
            {
              ids = {
                6804,
              },
              name = "Poisoned Water",
            },
          },
          x = 0.79,
          y = 0.73,
          zone = "Azshara",
        },
        {
          faction = "Neutral",
          giver = "Lorax",
          ids = {
            5127,
          },
          level = 55,
          location = "Winterspring, Southeast",
          name = "The Demon Forge",
          notes = "Blacksmiths only. Complete Lorax's Tale first. Rewards Plans: Demon Forged Breastplate.",
          prereqs = {
            {
              ids = {
                5126,
              },
              name = "Lorax's Tale",
            },
          },
          x = 0.63,
          y = 0.73,
          zone = "Winterspring",
        },
      },
    },
  },
  prereqInfo = {
    ["A Portable Power Source"] = {
      giver = "Mux Manascrambler",
      location = "Tanaris, Gadgetzan",
      zone = "Tanaris",
    },
    ["A Reliquary of Purity"] = {
      giver = "Rabine Saturna",
      location = "Moonglade, Nighthaven",
      zone = "Moonglade",
    },
    ["A Shifty Merchant"] = {
      giver = "Mux Manascrambler",
      location = "Tanaris, Gadgetzan",
      zone = "Tanaris",
    },
    ["A Shred of Hope"] = {
      giver = "Marshal Windsor",
      location = "Blackrock Depths",
      zone = "Blackrock Depths",
    },
    ["A Supernatural Device"] = {
      giver = "Mux Manascrambler",
      location = "Tanaris, Gadgetzan",
      zone = "Tanaris",
    },
    ["Abandoned Hope"] = {
      giver = "Marshal Windsor",
      location = "Blackrock Depths",
      zone = "Blackrock Depths",
    },
    ["Altered Beings"] = {
      giver = "Tonga Runetotem",
      location = "The Barrens, Crossroads",
      zone = "The Barrens",
    },
    ["Amulet of Secrets"] = {
      giver = "Hammertoe Grez",
      location = "Uldaman",
      zone = "Uldaman",
    },
    ["An Ambassador of Evil"] = {
      giver = "Historian Karnik",
      location = "Ironforge",
      zone = "Ironforge",
    },
    ["Betina Bigglezink"] = {
      giver = "Betina Bigglezink",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      x = 0.81,
      y = 0.59,
      zone = "Eastern Plaguelands",
    },
    ["Blood Tinged Skies"] = {
      giver = "Tirion Fordring",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      zone = "Eastern Plaguelands",
    },
    ["Broodling Essence"] = {
      giver = "Tinkee Steamboil",
      location = "Burning Steppes, Flame Crest",
      zone = "Burning Steppes",
    },
    ["Brother Anton"] = {
      giver = "Brother Crowley",
      location = "Stormwind City",
      zone = "Stormwind City",
    },
    ["Carrion Grubbage"] = {
      giver = "Tirion Fordring",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      zone = "Eastern Plaguelands",
    },
    ["Demon Dogs"] = {
      giver = "Tirion Fordring",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      zone = "Eastern Plaguelands",
    },
    ["Disharmony of Flame"] = {
      giver = "Thunderheart",
      location = "Badlands, Kargath",
      x = 0.036,
      y = 0.48,
      zone = "Badlands",
    },
    ["Doctor Theolen Krastinov, the Butcher"] = {
      giver = "Eva Sarkhoff",
      location = "Western Plaguelands, Caer Darrow",
      x = 0.7,
      y = 0.73,
      zone = "Western Plaguelands",
    },
    ["Duskwing, Oh How I Hate Thee..."] = {
      giver = "Nathanos Blightcaller",
      location = "Eastern Plaguelands, Marris Stead",
      x = 0.26,
      y = 0.74,
      zone = "Eastern Plaguelands",
    },
    ["Egg Collection"] = {
      giver = "Tinkee Steamboil",
      location = "Burning Steppes, Flame Crest",
      x = 0.65,
      y = 0.23,
      zone = "Burning Steppes",
    },
    ["Eitrigg's Wisdom"] = {
      giver = "Eitrigg",
      location = "Orgrimmar, Valley of Strength",
      zone = "Orgrimmar",
    },
    ["Find Agmond"] = {
      giver = "Prospector Ironband",
      location = "Loch Modan, Ironband's Excavation Site",
      x = 0.65,
      y = 0.65,
      zone = "Loch Modan",
    },
    ["Get the Scoop"] = {
      giver = "Magus Tirth",
      location = "Thousand Needles, Shimmering Flats",
      x = 0.77,
      y = 0.76,
      zone = "Thousand Needles",
    },
    Gnogaine = {
      giver = "Ozzie Togglevolt",
      location = "Dun Morogh, Kharanos",
      x = 0.45,
      y = 0.49,
      zone = "Dun Morogh",
    },
    ["Going, Going, Guano!"] = {
      giver = "Master Apothecary Faranell",
      location = "Undercity, The Apothecarium",
      x = 0.48,
      y = 0.69,
      zone = "Undercity",
    },
    ["Grark Lorkrub"] = {
      giver = "Lexlort",
      location = "Badlands, Kargath",
      x = 0.06,
      y = 0.48,
      zone = "Badlands",
    },
    ["Gryphon Master Talonaxe"] = {
      giver = "Gryphon Master Talonaxe",
      location = "The Hinterlands",
      x = 0.49,
      y = 0.68,
      zone = "The Hinterlands",
    },
    ["Hidden Secrets"] = {
      giver = "Magus Tirth",
      location = "Thousand Needles, Shimmering Flats",
      zone = "Thousand Needles",
    },
    ["Hunting for Ectoplasm"] = {
      giver = "Mux Manascrambler",
      location = "Tanaris, Gadgetzan",
      zone = "Tanaris",
    },
    ["In Search of The Temple"] = {
      giver = "Brohann Caskbelly",
      location = "Stormwind, Dwarven District",
      x = 0.64,
      y = 0.21,
      zone = "Stormwind",
    },
    ["Ironband Wants You!"] = {
      giver = "Prospector Ironband",
      location = "Loch Modan, Ironband's Excavation Site",
      x = 0.65,
      y = 0.65,
      zone = "Loch Modan",
    },
    ["KILL ON SIGHT: Dark Iron Dwarves"] = {
      giver = "WANTED poster",
      location = "Badlands, Kargath",
      x = 0.04,
      y = 0.47,
      zone = "Badlands",
    },
    ["KILL ON SIGHT: High Ranking Dark Iron Officials"] = {
      giver = "WANTED poster",
      location = "Badlands, Kargath",
      x = 0.04,
      y = 0.47,
      zone = "Badlands",
    },
    ["Kharan Mighthammer"] = {
      giver = "King Magni Bronzebeard",
      location = "Ironforge, Throne Room",
      x = 0.39,
      y = 0.56,
      zone = "Ironforge",
    },
    ["Kirtonos the Herald"] = {
      giver = "Eva Sarkhoff",
      location = "Western Plaguelands, Caer Darrow",
      x = 0.7,
      y = 0.73,
      zone = "Western Plaguelands",
    },
    ["Krastinov's Bag of Horrors"] = {
      giver = "Eva Sarkhoff",
      location = "Western Plaguelands, Caer Darrow",
      x = 0.7,
      y = 0.73,
      zone = "Western Plaguelands",
    },
    ["Larion and Muigin"] = {
      giver = "Larion",
      location = "Un'Goro Crater, Marshal's Refuge",
      zone = "Un'Goro Crater",
    },
    ["Legends of Maraudon"] = {
      giver = "Cavindra",
      location = "Maraudon, Orange side, outside instance",
      zone = "Maraudon",
    },
    ["Leonid Barthalomew"] = {
      giver = "Leonid Barthalomew the Revered",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      x = 0.81,
      y = 0.57,
      zone = "Eastern Plaguelands",
    },
    ["Lonebrow's Journal"] = {
      giver = "Henrig Lonebrow's corpse",
      location = "Thousand Needles, near the Great Lift",
      x = 0.31,
      y = 0.24,
      zone = "Thousand Needles",
    },
    ["Lorax's Tale"] = {
      giver = "Lorax",
      location = "Winterspring, Southeast",
      x = 0.63,
      y = 0.73,
      zone = "Winterspring",
    },
    ["Marvon's Workshop"] = {
      giver = "Liv Rizzlefix",
      location = "The Barrens, Ratchet",
      x = 0.62,
      y = 0.38,
      zone = "The Barrens",
    },
    ["Material Assistance"] = {
      giver = "Sagorne Creststrider",
      location = "Orgrimmar, Valley of Wisdom",
      x = 0.38,
      y = 0.35,
      zone = "Orgrimmar",
    },
    Murdaloc = {
      giver = "Prospector Ironband",
      location = "Loch Modan, Ironband's Excavation Site",
      x = 0.65,
      y = 0.65,
      zone = "Loch Modan",
    },
    ["Nara Wildmane"] = {
      giver = "Nara Wildmane",
      location = "Thunder Bluff, Elder Rise",
      x = 0.45,
      y = 0.23,
      zone = "Thunder Bluff",
    },
    ["Of Forgotten Memories"] = {
      giver = "Tirion Fordring",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      zone = "Eastern Plaguelands",
    },
    ["Of Lost Honor"] = {
      giver = "Tirion Fordring",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      zone = "Eastern Plaguelands",
    },
    ["Overmaster Pyron"] = {
      giver = "Jalinda Sprig",
      location = "Burning Steppes, Morgan's Vigil",
      x = 0.85,
      y = 0.7,
      zone = "Burning Steppes",
    },
    ["Plagued Hatchlings"] = {
      giver = "Betina Bigglezink",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      x = 0.81,
      y = 0.59,
      zone = "Eastern Plaguelands",
    },
    ["Poisoned Water"] = {
      giver = "Duke Hydraxis",
      location = "Azshara",
      x = 0.79,
      y = 0.73,
      zone = "Azshara",
    },
    ["Pool of Tears"] = {
      giver = "Fel'zerul",
      location = "Swamp of Sorrows, Stonard",
      x = 0.47,
      y = 0.54,
      zone = "Swamp of Sorrows",
    },
    ["Precarious Predicament"] = {
      giver = "Lexlort",
      location = "Badlands, Kargath",
      x = 0.06,
      y = 0.48,
      zone = "Badlands",
    },
    ["Raptor Horns"] = {
      giver = "Mebok Mizzyrix",
      location = "The Barrens, Ratchet",
      x = 0.62,
      y = 0.37,
      zone = "The Barrens",
    },
    ["Return to Fel'Zerul"] = {
      giver = "Atal'ai Exile",
      location = "The Hinterlands, Shadra'Alor",
      x = 0.33,
      y = 0.75,
      zone = "The Hinterlands",
    },
    ["Return to the Marsh"] = {
      giver = "Tabetha",
      location = "Dustwallow Marsh, N. of Stonemaul Ruins",
      x = 0.46,
      y = 0.57,
      zone = "Dustwallow Marsh",
    },
    ["Rig Wars"] = {
      giver = "Nogg",
      location = "Orgrimmar, Valley of Honor",
      x = 0.76,
      y = 0.25,
      zone = "Orgrimmar",
    },
    ["Scourge of the Downs"] = {
      giver = "Belnistrasz",
      location = "Razorfen Downs, Murder Pens",
      zone = "Razorfen Downs",
    },
    ["Screecher Spirits"] = {
      giver = "Yeh'kinya",
      location = "Tanaris, Steamwheedle Port",
      x = 0.67,
      y = 0.22,
      zone = "Tanaris",
    },
    ["Stormers and Rumblers"] = {
      giver = "Duke Hydraxis",
      location = "Azshara",
      x = 0.79,
      y = 0.73,
      zone = "Azshara",
    },
    ["Stormwind Rendezvous"] = {
      giver = "Marshal Maxwell",
      location = "Burning Steppes, Morgan's Vigil",
      zone = "Burning Steppes",
    },
    ["Test of Endurance"] = {
      giver = "Dorn Plainstalker",
      location = "Thousand Needles",
      zone = "Thousand Needles",
    },
    ["Test of Faith"] = {
      giver = "Dorn Plainstalker",
      location = "Thousand Needles",
      zone = "Thousand Needles",
    },
    ["Test of Strength"] = {
      giver = "Dorn Plainstalker",
      location = "Thousand Needles",
      zone = "Thousand Needles",
    },
    ["The Altar of Zul"] = {
      giver = "Gryphon Master Talonaxe",
      location = "The Hinterlands",
      x = 0.49,
      y = 0.68,
      zone = "The Hinterlands",
    },
    ["The Ancient Egg"] = {
      giver = "Yeh'kinya",
      location = "Tanaris, Steamwheedle Port",
      x = 0.66,
      y = 0.23,
      zone = "Tanaris",
    },
    ["The Archivist"] = {
      giver = "Duke Nicholas Zverenhoff",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      x = 0.81,
      y = 0.59,
      zone = "Eastern Plaguelands",
    },
    ["The Atal'ai Exile"] = {
      giver = "Atal'ai Exile",
      location = "The Hinterlands, Shadra'Alor",
      x = 0.33,
      y = 0.75,
      zone = "The Hinterlands",
    },
    ["The Dark Iron War"] = {
      giver = "Motley Garmason",
      location = "Wetlands, Dun Modr",
      zone = "Wetlands",
    },
    ["The Dragon's Eye"] = {
      giver = "Highlord Bolvar Fordragon",
      location = "Stormwind City",
      zone = "Stormwind City",
    },
    ["The Dying, Ras Frostwhisper"] = {
      giver = "Leonid Barthalomew the Revered",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      x = 0.81,
      y = 0.57,
      zone = "Eastern Plaguelands",
    },
    ["The Ectoplasmic Distiller"] = {
      giver = "Mux Manascrambler",
      location = "Tanaris, Gadgetzan",
      zone = "Tanaris",
    },
    ["The Exorcism"] = {
      giver = "Tabetha",
      location = "Dustwallow Marsh, N. of Stonemaul Ruins",
      x = 0.46,
      y = 0.57,
      zone = "Dustwallow Marsh",
    },
    ["The Flesh Does Not Lie"] = {
      giver = "Betina Bigglezink",
      location = "Eastern Plaguelands, Light's Hope Chapel",
      x = 0.81,
      y = 0.59,
      zone = "Eastern Plaguelands",
    },
    ["The Forgotten Pools"] = {
      giver = "Tonga Runetotem",
      location = "The Barrens, Crossroads",
      zone = "The Barrens",
    },
    ["The God Hakkar"] = {
      giver = "Yeh'kinya",
      location = "Tanaris, Steamwheedle Port",
      x = 0.67,
      y = 0.22,
      zone = "Tanaris",
    },
    ["The Great Masquerade"] = {
      giver = "Reginald Windsor",
      location = "Stormwind City",
      zone = "Stormwind City",
    },
    ["The Human, Ras Frostwhisper"] = {
      giver = "Magistrate Marduke",
      location = "Arathi Highlands, Stromgarde",
      zone = "Arathi Highlands",
    },
    ["The Infernal Orb"] = {
      giver = "Tabetha",
      location = "Dustwallow Marsh, N. of Stonemaul Ruins",
      x = 0.46,
      y = 0.57,
      zone = "Dustwallow Marsh",
    },
    ["The Lost Dwarves"] = {
      giver = "Prospector Stormpike",
      location = "Ironforge, Hall of Explorers",
      x = 0.75,
      y = 0.12,
      zone = "Ironforge",
    },
    ["The Lost Tablets of Mosh'aru"] = {
      giver = "Prospector Ironboot",
      location = "Tanaris, Steamwheedle Port",
      x = 0.66,
      y = 0.24,
      zone = "Tanaris",
    },
    ["The Medallion of Faith"] = {
      giver = "Aurius",
      location = "Stratholme, Undead Side, inside chapel at beginning",
      zone = "Stratholme",
    },
    ["The Prophecy of Mosh'aru"] = {
      giver = "Yeh'kinya",
      location = "Tanaris, Steamwheedle Port",
      x = 0.67,
      y = 0.22,
      zone = "Tanaris",
    },
    ["The Ranger Lord's Behest"] = {
      giver = "Nathanos Blightcaller",
      location = "Eastern Plaguelands, Marris Stead",
      x = 0.26,
      y = 0.74,
      zone = "Eastern Plaguelands",
    },
    ["The Restless Souls"] = {
      giver = "Egan",
      location = "Eastern Plaguelands, Terrordale",
      x = 0.14,
      y = 0.33,
      zone = "Eastern Plaguelands",
    },
    ["The Smoldering Ruins of Thaurissan"] = {
      giver = "Royal Historian Archesonus",
      location = "Ironforge",
      zone = "Ironforge",
    },
    ["The Stagnant Oasis"] = {
      giver = "Tonga Runetotem",
      location = "The Barrens, Crossroads",
      zone = "The Barrens",
    },
    ["The Stone Circle"] = {
      giver = "Marvon Rivetseeker",
      location = "Tanaris, S. of Gadgetzan",
      x = 0.52,
      y = 0.45,
      zone = "Tanaris",
    },
    ["The Truth Comes Crashing Down"] = {
      giver = "Drop from Balnazzar",
      location = "Stratholme, Live Side",
      zone = "Stratholme",
    },
    ["The Unsent Letter"] = {
      giver = "Drop from Edwin VanCleef",
      location = "The Deadmines",
      zone = "The Deadmines",
    },
    ["Tinkee Steamboil"] = {
      giver = "Felnok Steelspring",
      location = "Winterspring, Everlook",
      zone = "Winterspring",
    },
    ["To The Hinterlands"] = {
      giver = "High Thane Falstad Wildhammer",
      location = "The Hinterlands, Aerie Peak",
      x = 0.14,
      y = 0.44,
      zone = "The Hinterlands",
    },
    ["Undamaged Venom Sac"] = {
      giver = "Apothecary Lydon",
      location = "Hillsbrad Foothills, Tarren Mill",
      zone = "Hillsbrad Foothills",
    },
    ["Venom Bottles"] = {
      giver = "Apothecary Lydon",
      location = "Hillsbrad Foothills, Tarren Mill",
      zone = "Hillsbrad Foothills",
    },
    ["Warlord's Command"] = {
      giver = "Warlord Goretooth",
      location = "Badlands, Kargath",
      x = 0.05,
      y = 0.47,
      zone = "Badlands",
    },
    ["Witherbark Cages"] = {
      giver = "Gryphon Master Talonaxe",
      location = "The Hinterlands",
      x = 0.49,
      y = 0.68,
      zone = "The Hinterlands",
    },
  },
  source = {
    author = "Sundee",
    license = "MIT",
    name = "Forever Dungeon Quests",
    revision = "main, abgerufen 2026-11-12 (letzter Commit fed422e vom 2026-09-26)",
    url = "https://github.com/ImSundee/forever-dungeon-quest",
  },
}
