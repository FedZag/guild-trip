# Guild Trip

**Your guild's travel companion for WoW: Forever.** Calendar and guild trips, guild members on the map,
a navi arrow, quests and quest givers, dungeons and a group finder, recipes and trainers, a class guide
that sets up your bars, a messenger-style chat and an optional old-book look – all in one add-on.

*Deutsch weiter unten.*

- **Download:** [CurseForge](https://www.curseforge.com/wow/addons/guildtrip)
- **Bugs & ideas:** [Issues](../../issues)
- **Licence:** GNU GPL v3 or later ([LICENSE.txt](LICENSE.txt)); third-party parts in [THIRD_PARTY.md](THIRD_PARTY.md)
- **Status:** alpha – expect changes

## Add-ons in this repository

| Folder | What it does |
|---|---|
| `src/ONE_Core` | Window, themes (Blizzard, old book), options, sounds, name menu, "what's new" |
| `src/ONE_Guild` | Guild members, calendar, reminders, positions on the map |
| `src/ONE_Nav` | Navi arrow, quests page, quest givers, waypoints, corpse run, route guidance along the walking network (or via [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) when installed) |
| `src/ONE_QuestDB` | Quest database generated from [QuestieDB](https://github.com/Questie/QuestieDB) (Forever data, GPLv3, used with the Questie team's permission) |
| `src/ONE_Routes` | Walking network: paths between quest givers, trainers, vendors and flight masters, precomputed with [Shortest Path Forever](https://github.com/cjber/shortest-path-forever) (GPL-3.0-or-later) |
| `src/ONE_Dungeons` | Dungeon quests, group finder, guild trips |
| `src/ONE_Crafting` | Recipes and trainers of your guild |
| `src/ONE_Classes` | Class guide: bars, order of play, talents, gear rating, weapons |
| `src/ONE_Chat` | Optional messenger-style chat and loot window |
| `src/ONE_Dev` | Developer tools (not part of the release) |

Internally the add-ons are called `ONE_*` – the visible name is Guild Trip.

## Developing

- Tests: `bash scripts/check.sh` (Lua 5.1)
- Quest data: in a QuestieDB checkout run `lua5.1 tools/export-forever.lua --include-authored`, then `lua5.1 scripts/import_questiedb.lua <QuestieDB checkout>`
- Walking network: `luajit scripts/bake_routes.lua <shortest-path-forever checkout>` (check quality with `scripts/check_routes.lua`)
- Release zip: `python3 -I scripts/build_release_windows.py --curseforge`
- Release: push the tag `v<version>`; `.github/workflows/release.yml` tests, builds and uploads to CurseForge. Versions already listed in `.github/curseforge-uploads.txt` are not uploaded again (a manual `scripts/upload_curseforge.py` run adds its line there – commit it)

Internal comments and many identifiers are German. Pull requests are welcome; by contributing you agree to
licence your contribution under GPL-3.0-or-later.

---

# Guild Trip (Deutsch)

**Der Reisebegleiter deiner Gilde für WoW: Forever.** Kalender und Gildenausflüge, Gildenmitglieder auf
der Karte, Navi-Pfeil, Quests und Questgeber, Dungeons und Gruppensuche, Rezepte und Lehrer, ein
Klassen-Ratgeber, der deine Leisten einrichtet, und ein Chat wie ein Messenger – alles in einem Addon.

- **Download:** [CurseForge](https://www.curseforge.com/wow/addons/guildtrip)
- **Fehler & Ideen:** [Issues](../../issues)
- **Lizenz:** GNU GPL v3 oder später ([LICENSE.txt](LICENSE.txt)); fremde Teile in [THIRD_PARTY.md](THIRD_PARTY.md)
- **Stand:** Alpha – Änderungen sind zu erwarten

World of Warcraft, Warcraft and Blizzard Entertainment are trademarks or registered trademarks of
Blizzard Entertainment, Inc. Guild Trip is a fan project and is not affiliated with Blizzard Entertainment.
