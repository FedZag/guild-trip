# Guild Trip – Fremde Quellen / Third-party sources

Guild Trip selbst steht unter der GNU GPL v3 oder später (siehe `LICENSE.txt`).
Diese Teile stammen von anderen und behalten ihre eigene Lizenz. Danke an alle!

Guild Trip itself is licensed under the GNU GPL v3 or later (see `LICENSE.txt`).
The parts below come from others and keep their own licences. Thank you all!

| Was / What | Wo im Addon / Where | Von / By | Lizenz / Licence | Stand / Version |
|---|---|---|---|---|
| Dungeon-Quest-Daten (Forever Dungeon Quests) | `ONE_Dungeons/QuestData.lua` | Sundee | MIT (`ONE_Dungeons/LICENSE_ForeverDungeonQuests.txt`) | übernommen 11/2026 |
| Questdaten (Geber, Abgabe, Ziele, Titel, NPC-Namen) aus pfQuest; dessen Daten stammen aus VMaNGOS | `ONE_QuestDB/` (erzeugt mit `scripts/import_pfquest.lua`) | Eric Mauser (Shagu) | MIT (`ONE_QuestDB/LICENSE_pfQuest.txt`) | pfQuest Commit 104f356 (2025-08-25) |
| Laufwege (Wegenetz): mit dem Wegsucher von Shortest Path Forever auf dessen Laufkarten vorab berechnet; Kartenrahmen aus dessen `Data/Zones.lua` (wago.tools UiMapAssignment) | `ONE_Routes/Data.lua` (erzeugt mit `scripts/bake_routes.lua`), Rahmen-Korrektur in `scripts/import_pfquest.lua` | cjber (Cillian Berragan) | GPL-3.0-or-later | Shortest Path Forever Commit 7dea1de (2026-11-16) |
| Schrift IM FELL English | `ONE_Core/Fonts/IMFellEnglish.ttf` | Igino Marini | SIL Open Font License 1.1 (`ONE_Core/Fonts/OFL.txt`) | – |

Regel für neue Einträge / Rule for new entries: Quelle, Autor, Lizenz und genaue Version
(Commit/Release) eintragen, bevor die Daten ins Paket kommen. Nur Lizenzen, die mit der
GPL v3 vereinbar sind (z. B. MIT, BSD, GPL-3.0, GPL-3.0-or-later, OFL für Schriften).
Record source, author, licence and exact version (commit/release) before data ships.
Only GPL-3.0-compatible licences.
