# Übergabe: Guild Trip 0.7.1-alpha (Stand 18.11.2026)

Diese Datei fasst alles zusammen, was im Chat zu 0.7.1 passiert ist. Wer weiterarbeitet (Mensch oder Claude), soll hier ohne den Chat einsteigen können.

---

## 1. Kurz gesagt

- **Projekt:** Guild Trip, ein WoW-Add-on für **WoW Forever** (Classic-Era-Client, Interface 16001). Es ist in Lua 5.1 geschrieben und besteht aus den Modulen `src/ONE_*`.
- **Veröffentlicht:** 0.7.0-alpha, PR #1 ist gemergt.
- **In Arbeit:** **0.7.1-alpha** auf dem Branch `claude/player-buff-radius-feature-rzww7r`. Der Stand ist gepusht und noch nicht veröffentlicht.
- **Nächster Schritt:** Der Nutzer testet 0.7.1 im Spiel (siehe Abschnitt 6). Danach werden Fehler behoben und erst dann veröffentlicht.
- **Tests:** `bash scripts/check.sh` führt alle `tests/*.lua` aus. Aktuell bestehen **alle 93**.

## 2. Regeln des Nutzers (gelten dauerhaft)

1. **Im Chat nichts posten, was nicht ausdrücklich gewünscht ist.** Gemeint sind Gilden-Chat und Ankündigungen.
2. **Nicht nach dem Mund reden.** Ist eine Idee schlecht oder passt sie nicht, das direkt sagen und begründen.
3. **Erst prüfen, dann Grenzen behaupten.** Der Nutzer hat kritisiert, dass Grenzen genannt wurden, die lösbar waren.
4. **Lieber eine Sache auf einmal und dann testen.** Für 0.7.1 hat der Nutzer ausnahmsweise „alles auf einmal zum Testen“ freigegeben.
5. Antworten auf Deutsch. Der Nutzer schreibt oft vom Handy aus.
6. Commit-Nachrichten enden mit den Attribution-Zeilen aus dem System-Hinweis. In Commits, PRs und Code steht keine Modellbezeichnung.

## 3. Was in diesem Chat passiert ist (in Reihenfolge)

### 3.1 UI-Experimente und Rückbau
- Ein neues Aussehen „Nachtroute“ (Skins, runde Knöpfe, eigene Menüs) wurde gebaut und auf Wunsch wieder auf den UI-Stand von 0.7.0 zurückgesetzt (Revert-Commit `5902d9a`).
- Der Nachtroute-Code liegt weiter in der Git-Geschichte (`d8fe595..3975b34`). Daraus wurden die Skin-Texturen und der Neun-Teile-Code für „Glas“ übernommen.

### 3.2 Startseite und Sprüche
- Die Startseite hat ein ruhiges Bild (`ONE_Core/Textures/Hero/TripHero.tga`, gebaut mit `scripts/build_textures.py hero()`) und die Begrüßung „Na <Name>!“ mit einem frechen Spruch.
- `ONE_Core/Quips.lua` enthält 100 Sprüche, einen Geist-Spruch und `ONE.QuipIndex(tag, name-realm, anzahl)`. Jeden Tag gibt es einen neuen Spruch, und jeder Charakter bekommt einen anderen. Alle Sprüche sind ins Englische übersetzt.
- Der Spruch steht auf der Startseite und im Begrüßungsfenster beim Einloggen, aber **nicht** auf „Heute“.

### 3.3 Dungeon-Bilder
- `ONE_Dungeons/Art.lua` zeigt echte Ladebildschirme aus dem Client (FileDataIDs aus der Polestar-Tabelle, GPL-3) als Kopfbild der Dungeon-Seite.
- `/trip bilder` (Modul `ONE_Dev/ArtCheck.lua`) zeigt ein Bildraster. Fehlende Bilder erscheinen rot, dazu kommt die Prüfung der Masken.

### 3.4 Buch-Look entfernt
- Das Aussehen „Altes Buch“ ist komplett raus, weil es nicht gut ankam. Vorher war es noch auf 15 % dunkler gestellt worden.
- `Themes.lua` kennt seitdem nur noch „native“ (Blizzard) und, ab dem nächsten Schritt, „glass“.

### 3.5 Kalender-Fehler behoben
- Fehler: Beim Anklicken eines Gildentermins kam ein Lua-Fehler, weil `answerLine` außerhalb des Buch-Looks nil war.
- Fix in `ONE_Guild/UI.lua`.

### 3.6 Minimap aufgeräumt
- Auf der Minimap stehen höchstens **3** schlichte „!“ ohne Ring, und zwar nur für Questgeber, die der Plan als Nächstes annehmen lässt.
- Auf der Weltkarte sind weiter alle zu sehen. Mit dem Schalter „Alle Questgeber auf der Minimap“ (Optionen › Navi) erscheinen auch dort alle.
- Dateien: `ONE_Nav/QuestPins.lua` und `ONE_Nav/Textures/QuestAvailableSmall.tga`.

### 3.7 OpenMap geprüft
- OpenMap muss **nicht** installiert werden. Die Lizenz ist MIT, die Texturen sind davon ausgenommen.
- Brauchbar für später wären: Forever-Dungeoneingänge, Bosslisten und Dungeon-Karten.

### 3.8 Ausrüstungsdaten gesammelt
- Erzeugt werden sie mit `scripts/import_gear.py <Polestar_ItemDB> <ClassicDB.sql.gz>`. Daraus entsteht `ONE_Leveling/GearData.lua` (`GuildTripGear`, ca. 376 KB).
- `items[id] = "platz gstufe mindeststufe qualität klasse unterklasse [werte]"`. Zu den Werten gehören auch `cls<Klassenmaske>`, `dmin`, `dmax` und `speed`.
- `src[id]` sagt, woher es den Gegenstand gibt:
  - `{"q",quest}`
  - `{"d",dungeon,npc,chance}`
  - `{"w",gebiet,npc,chance}`
  - `{"c",beruf_en,fertigkeit,zauber}`
- `learn[zauber]` sagt, wo man das Rezept lernt:
  - `{"t",lehrer,fertigkeit,preis}`
  - `{"v",händler,rezept,begrenzt}`
  - `{"d",dungeon,npc,rezept,chance}`
  - `{"w",npc,rezept,chance}`
  - `{"q",quest,rezept}`
  - `{"r",rezept,gegnerarten}`
- Außerdem gibt es `places[npc]` und `npcs`.
- Umfang: 3.824 Gegenstände, Beute aus 24 Dungeons und die Herkunft von 548 der 638 klassischen Rezepte.
- Die 667 Forever-eigenen Rezepte haben keine offenen Daten.
- Seit 0.7.1 schreiben Berufslehrer still mit, was sie anbieten (`ONE_Crafting/Trainers.lua`, `entry.recipes[itemID] = {fertigkeit, preis, stufe}`).

### 3.9 Neues Aussehen „Glas“ (Standard ab 0.7.1)
- **Wunsch des Nutzers:** Richtung Subnautica, aber passend zu WoW. Durchsichtiger Hintergrund, links ein Menü, in der Mitte die Kategorien, rechts die Unterpunkte, mit runden und leuchtenden Symbolen. Dazu Farben in WoW-Optik und eigene Farben.
- **Entwurf (Artefakt):** https://claude.ai/artifact/UXotZne63eFVf7NrDn3NcP. Er enthält die Beispiele Berufe und Dungeons und einen Umschalter zwischen Glas (Blau) und Azeroth (Gold).
- **Datei `ONE_Core/Glass.lua`:**
  - Skins: `azeroth` (Gold, Standard), `glas` (Blau), `horde`, `alliance`, `custom`.
  - Ein Skin besteht nur aus drei Farben: Tönung, Leuchtfarbe und Überschrift. Die Deckkraft ist ein eigener Regler (40–100 %, Standard 80 %).
  - Bei eigenen Farben wird eine zu helle Glasfarbe abgedunkelt (Helligkeit ≤ 0,22), damit die Schrift lesbar bleibt.
  - Fenster mit 1100 × 540 Einheiten. Spalte 1 zeigt die Bereiche (`Glass:NavButton` mit runder Kugel und Goldsymbol). Spalte 2 zeigt Seitentitel, Unterseiten (`Glass:ShowViews`) und **„Gilde online“** (Klick öffnet das Flüstern). Rechts liegt der Inhalt mit 726 × 437 wie bisher, sodass alle Seiten unverändert hineinpassen.
  - Karten, Knöpfe und kleine Fenster sind im Glas-Stil (`Themes:RegisterPanel`, `RegisterWindow` und `Widgets:Button` prüfen `Glass:Active()`).
  - Der gewählte Bereich „atmet“: Das Leuchten schwillt in 3,5 Sekunden an und ab (Animations-Gruppe, Alpha 1 → 0,3). Das hat der Nutzer ausdrücklich so gewollt, sanft und nicht blinkend.
  - Einstellungen unter Optionen › Darstellung › Aussehen: Aussehen (Glas oder Blizzard, ein Wechsel lädt die Oberfläche neu), Farben, Deckkraft, Leuchtfarbe und Glasfarbe (über den Farbwähler des Spiels) sowie Zurücksetzen.
  - Gespeichert wird in `ProjectONEDB.theme.look` (`"glass"` oder `"native"`) und `theme.glass` (`skin`, `tint`, `glow`, `alpha`).
- In der mittleren Spalte stehen inzwischen auch die Bereiche der Optionen, „Übersicht/Heute“ der Startseite und die Ansichten von Leveln.
- Neue Texturen liegen in `ONE_Core/Textures/Skin/`: Round, RoundRing, Shadow, Sheen, Glow, Circle, CircleRing und Orb. Erzeugt werden sie mit `python3 scripts/build_skin.py`.
- Ohne gespeicherte Fenstergröße startet das Glasfenster mit Skalierung 0,85 (`WindowScale.DEFAULT`).
- **Noch im Blizzard-Stil:** Häkchen, Auswahlfelder, Schieberegler, Chat-, Beute-, Fehlerbericht- und Gruppen-Dialog.

### 3.10 Leveln › Ausrüstung („Ausrüstung auf deinem Weg“)
- Die Logik steckt in `ONE_Leveling/Way.lua`, die Ansicht in `ONE_Leveling/Page.lua` (`Page:BuildGear`).
- **Für jeden Platz** zeigt die Ansicht das beste Teil bis zu deiner Stufe, das „verlässlich“ zu bekommen ist:
  - Quest, wenn sie zu Fraktion, Volk und Klasse passt, nicht erledigt ist und höchstens 3 Stufen über dir liegt. Der Filter entspricht dem der Quest-Führung (`Planner.Fits`).
  - Dungeon, wenn die Chance mindestens 3 % beträgt oder unbekannt ist und der Dungeon höchstens 2 Stufen über dir beginnt.
  - Herstellung, wenn du sie selbst kannst, bald kannst oder jemand aus der Gilde sie kann.
  - Seltene Weltdrops erscheinen nur im Tooltip.
- **Pro Zeile** stehen „+x %“ gegenüber dem getragenen Teil (mit „neu“ bei leerem Platz, „hast du“, wenn dein Teil besser ist), „hält bis Stufe X“ (das ist die Stufe, ab der es verlässlich 15 % Besseres gibt) und „bald“ (bis 5 Stufen voraus).
- **Bewertung:** Die Gewichte kommen aus `ONE_Classes/Gear.lua` (Werte-Rangfolge der Ausrichtung, wie im Tooltip „besser für dich“).
- **Grenzen nach Klasse:**
  - Rüstung: Krieger und Paladin tragen Platte ab Stufe 40, Jäger und Schamane Kette ab Stufe 40.
  - Waffenarten nach Klasse, Schilde nur für Krieger, Paladin und Schamane.
  - Die Klassenmaske des Gegenstands gilt zusätzlich.
- **Herstellung:**
  - Status `self`, `learn`, `soon`, `guild` oder `none`.
  - Die Lern-Möglichkeiten sind nach Fraktion gefiltert (`ONE_QuestDB/Services.lua`). Lehrer stehen zuerst.
  - Gilden-Hersteller kommen aus den geteilten Rezepten (`ONE_Crafting/Recipes.lua Catalog`), wer online ist, steht zuerst.
- **Klick auf eine Zeile:** Navi zum Questgeber, zum Dungeon-Eingang oder zum Lehrer bzw. Händler. Bei Gilden-Herstellung öffnet sich ein Flüstern mit fertiger Anfrage.
- Gegenstandsnamen kommen vom Server nach. Die Liste zeichnet sich bei `GET_ITEM_INFO_RECEIVED` neu.
- Stichprobe (Krieger auf Stufe 15, Horde): Dungeon-Beute aus Halle der Thanen, Ruinen von Lordaeron und Flammenschlund, Questbelohnungen nur dort, wo kein besseres Dungeon-Teil zu haben ist. Das hat sich der Nutzer ausdrücklich so gewünscht.

### 3.11 Berufe: Frage nach dem Teilen
- Beim ersten Berufsfenster fragt Guild Trip einmal pro Charakter, ob die Gilde sehen darf, was du herstellen kannst (`crafting.AskShare` in `ONE_Crafting/Init.lua`).
- Gemerkt wird das in `ONE.db.crafting.askedShare`.

### 3.12 Version
- Alle TOCs und `ONE.version` stehen auf **0.7.1-alpha**.
- CHANGELOG ist zweisprachig (Englisch zuerst). „Was ist neu“ hat einen Eintrag für 0.7.1-alpha.

## 4. Werkzeuge

| Zweck | Befehl |
|---|---|
| Alle Tests | `bash scripts/check.sh` |
| Vorschau der Seiten (ohne Spiel) | `lua5.1 scripts/render_ui.lua <out.json> glass\|native [seiten]`, dann `python3 -I scripts/render_ui.py <out.json> <out.html> Titel` |
| Skin wählen in der Vorschau | Umgebungsvariable `SKIN=azeroth\|glas\|horde\|alliance` |
| Ausrüstungsseite in der Vorschau | Seite `gear` (z. B. `... glass gear`) |
| Skin-Texturen neu bauen | `python3 scripts/build_skin.py` |
| Ausrüstungsdaten neu bauen | `python3 -I scripts/import_gear.py <Polestar_ItemDB> <ClassicDB.sql.gz>` |

Die Vorschau ahmt Blizzard-Vorlagen und Gegenstandsnamen nur nach. Was im Spiel gilt, entscheidet der Test im Spiel.

## 5. Installieren beim Nutzer

- Diese Chat-Sitzung lief in der Cloud **ohne Zugriff auf den Rechner des Nutzers**. Deshalb gab es eine ZIP (`GuildTrip-0.7.1-alpha-test.zip`) mit allen `ONE_*`-Ordnern.
- So wird installiert:
  1. WoW schließen.
  2. Im AddOns-Ordner des Forever-Clients die alten `ONE_*`-Ordner löschen.
  3. Die ZIP dort entpacken.
  4. WoW **komplett neu starten**, nicht nur `/reload`.
  5. Unten links im Fenster muss **v0.7.1-alpha** stehen.
- Soll Claude selbst installieren, muss die Sitzung auf dem Rechner des Nutzers laufen (Claude-Desktop-App im Projektordner).

## 6. Testliste für den Nutzer (0.7.1)

0. Vorbereitung wie in Abschnitt 5 und die Versionsanzeige prüfen.
1. **Glas (Hauptpunkt):**
   - Die drei Spalten in jedem Bereich und „Gilde online“.
   - Alle Farben, den Deckkraft-Regler und die eigenen Farben samt Zurücksetzen.
   - **Lesbarkeit über bunter Landschaft, und bei welcher Deckkraft?**
   - Wo sieht es noch nach Blizzard aus? Ist das Atmen angenehm?
   - Notausgang: Aussehen › „Blizzard (wie 0.7.0)“.
2. **Leveln › Ausrüstung:**
   - Passen die Vorschläge?
   - Tooltip, Klick und Navi.
   - Kommen Namen statt „#12345“?
3. **Berufe:** Kommt die Frage nach dem Teilen beim ersten Fenster? Einmal den Schneiderlehrer öffnen.
4. **Startseite und Begrüßung:** Spruch, Bild, „Übersicht/Heute“ in der Mitte.
5. **Dungeons:** Ladebildschirm-Bild und ein Screenshot von `/trip bilder`.
6. **Kalender:** Gildentermin anklicken, es darf kein Lua-Fehler kommen.
7. **Minimap:** höchstens 3 „!“.
8. Lua-Fehler notieren oder `/trip bug` nutzen, und Screenshots machen.

Die Testliste der Abendsitzung liegt als `Testliste_heute_Abend.md` vor. Sie wurde dem Nutzer geschickt.

## 7. Offen oder bewusst nicht gemacht

- **Rückmeldung aus dem Spieltest einarbeiten.** Das hat Vorrang vor allem anderen.
- **Glas weiterziehen:** Häkchen, Auswahlfelder, Schieberegler und Scrollleisten im Glas-Stil, außerdem Chat-, Beute- und Fehlerbericht-Fenster. Wiederverwendbar ist Nachtroute Teil 4 und 5 in der Git-Geschichte (`775a82e` und `91cf161`).
- **Spielsymbole statt Platzhaltern:** In der Ausrüstungsliste und auf den Berufe- und Dungeon-Seiten fehlen noch echte Symbole als runde Kugeln (`Glass:Orb` mit `SetIconTexture(tex, true)` und Maske). In der Git-Geschichte gibt es dafür den Baustein `Widgets:Icon` (`8cf9f88`).
- **Lehrer-Rezepte an die Gilde schicken:** Nicht gebaut, weil die Daten nirgends angezeigt würden. Forever-eigene Rezepte haben keine Werte in `GearData`.
- **Berufs-Links aus dem Chat erfassen:** Nicht gebaut. Zuerst im Spiel klären, ob Forever überhaupt Berufs-Links verschickt.
- **Fehlende Daten:**
  - Fünf Forever-Dungeons ohne Beute: Versunkene Stadt, Krol'dok, Alcaz, Schwarzschlund und Formerterrasse.
  - Düsterbruch-Flügel und Blackrockspitze teilen sich je eine Karte.
  - Bossnamen sind teilweise englisch, weil die deutschen Namen in den Quellen fehlen.
- **OpenMap-Daten übernehmen:** Forever-Eingänge, Bosslisten und Dungeon-Karten.
- **Veröffentlichen:** Erst nach dem Test. Dann einen PR vom Branch nach `main` erstellen und das Paket für CurseForge bauen.

## 8. Lizenzen und Quellen (für THIRD_PARTY.md schon eingetragen)

- **Polestar:** GPL-3.0 (Ladebildschirm-Nummern, Polestar_ItemDB)
- **ForeverLevelingBiS (Thunder):** MIT
- **forever-db:** GPL-3
- **cmangos classic-db:** GPL-3
- **QuestieDB (Forever):** GPLv3 mit Erlaubnis (Questie#8365)
- **OpenMap:** MIT, Texturen ausgenommen (nicht übernommen)
- **Guild Trip selbst:** GPL-3.0-or-later
