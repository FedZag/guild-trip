# Guild Trip – Fremde Quellen / Third-party sources

Guild Trip selbst steht unter der GNU GPL v3 oder später (siehe `LICENSE.txt`).
Diese Teile stammen von anderen und behalten ihre eigene Lizenz. Danke an alle!

Guild Trip itself is licensed under the GNU GPL v3 or later (see `LICENSE.txt`).
The parts below come from others and keep their own licences. Thank you all!

| Was / What | Wo im Addon / Where | Von / By | Lizenz / Licence | Stand / Version |
|---|---|---|---|---|
| Dungeon-Quest-Daten (Forever Dungeon Quests) | `ONE_Dungeons/QuestData.lua` | Sundee | MIT (`ONE_Dungeons/LICENSE_ForeverDungeonQuests.txt`) | übernommen 11/2026 |
| Questdaten (Geber, Abgabe, Ziele, Vorquests, EP, Titel, NPC-Namen) aus QuestieDB (Forever-Fassung, zusammengeführt mit dessen `tools/export-forever.lua --include-authored`) | `ONE_QuestDB/` inkl. NPC-Verzeichnis `Services.lua` (erzeugt mit `scripts/import_questiedb.lua`; Lehrer-Art aus Shortest Path Forever `Data/Services.lua`, GPL-3.0-or-later), Dungeon-Eingänge `ONE_Dungeons/EntranceData.lua` (`scripts/import_entrances.lua`) | Questie-Team (Aero, Logon, Muehe, TheCrux/BreakBB u. v. a.) | GPLv3 – Nutzung ausdrücklich erlaubt (BreakBB, 17.11.2026, https://github.com/Questie/Questie/issues/8365) | QuestieDB Commit e1652ce (2026-11-16) |
| Laufwege (Wegenetz): mit dem Wegsucher von Shortest Path Forever auf dessen Laufkarten vorab berechnet; Kartenrahmen aus dessen `Data/Zones.lua` (wago.tools UiMapAssignment) | `ONE_Routes/Data.lua` (erzeugt mit `scripts/bake_routes.lua`), Rahmen-Korrektur in `scripts/import_pfquest.lua` | cjber (Cillian Berragan) | GPL-3.0-or-later | Shortest Path Forever Commit 7dea1de (2026-11-16) |
| Schrift IM FELL English | `ONE_Core/Fonts/IMFellEnglish.ttf` | Igino Marini | SIL Open Font License 1.1 (`ONE_Core/Fonts/OFL.txt`) | – |

Regel für neue Einträge / Rule for new entries: Quelle, Autor, Lizenz und genaue Version
(Commit/Release) eintragen, bevor die Daten ins Paket kommen. Nur Lizenzen, die mit der
GPL v3 vereinbar sind (z. B. MIT, BSD, GPL-3.0, GPL-3.0-or-later, OFL für Schriften).
Record source, author, licence and exact version (commit/release) before data ships.
Only GPL-3.0-compatible licences.
