# Guild Trip – Changelogs für CurseForge

Regel von CurseForge: **Englisch zuerst**, Deutsch darunter. Je Datei den passenden Abschnitt im Markdown-Modus einfügen.

---

## 0.6.9-alpha (gebaut 17.11.2026)

```
## 0.6.9-alpha

**English**
- New: Quest guide (levelling assistant) for twinks who want to reach 60 as fast as possible. New "Levelling" tab (replaces "Quests"; your quest log is a view there) with Plan | Skipped | Quest log. The plan shows a step-by-step plan (accept, do, turn in) with a Navi arrow per step. Always included: dungeon quests with all their prerequisite chains, class quests and important prerequisites. Everything else only if it gives more XP per minute than just grinding mobs (travel time from the Guild Trip road network, mob XP included, nearby quests bundled) or a real benefit: an upgrade for your class, a bigger bag, a lot of gold.
- "Why this quest?": XP, time, XP per minute compared to grinding and the reward, for every step. "Skipped" lists every left-out quest with its reason; "Skip it" / "Do it anyway" per quest.
- Three paces: Bare essentials (default), Balanced, Thorough. Elite and group quests show "Find group" (group finder).
- "Quest guide" box under the minimap: the next steps as a list (drag the bottom right corner to make it bigger – the bigger, the more steps; text size adjustable) with objective progress and a Navi arrow; movable, can be turned off, optionally text only without a frame. Optionally replaces the WoW quest tracker. Layout: NOW (the one step to do, large), TO PICK UP (new quests with their NPC – fills the space when you drag the box bigger), YOUR QUESTS (every quest in your log once, with progress; finished ones in green with whom to turn in to, unplanned ones greyed with the reason in the tooltip). Click a line to navigate there.
- All settings in one place: Options now has a list of sections on the left (General, Display, Reminders, Sharing, then one per module: Guild, Dungeons, Professions, Class, Levelling, Navi, Chat) and the settings of the chosen section on the right, with headings and scrolling. Every switch exists exactly once (several were doubled before). Gears jump straight to their section – e.g. the gear on the quest guide box opens Options › Levelling, the gear in the chat opens Options › Chat. Each module's on/off switch sits at the top of its section.
- Quest guide steps now name the NPC ("Accept X – at Name"), and the Navi arrow moves on to the next step by itself while you use the guide (can be turned off).
- Navi arrow turns smoothly now instead of in small jumps.
- Auto quests: planned quests are accepted and finished quests from your log turned in automatically (follow-ups included). With several rewards you always choose yourself. Hold Shift to do it yourself for that conversation. Escort quests and reputation/donation NPCs are never automated. Optionally also accept quests outside the guide. Off by default – turn it on under Options › Levelling.
- Vendors: repair automatically (optionally from guild funds first) and sell grey junk – Shift when opening the vendor skips it once. Off by default (Options › General › Vendors).
- Reward data from QuestieDB (with permission) and cmangos classic-db (GPL), item details from the game's own item table.
- Fixed: 188 escort and exploration quests were missing from the quest data (e.g. "The Defias Brotherhood" escort, "The Fargodeep Mine", the druid "Trial of the Lake") – they now show up everywhere (quest givers, map, guide). Holiday quests are left out properly instead.

**Deutsch**
- Neu: Quest-Führung (Leveling-Assistent) für Twinks, die so schnell wie möglich auf 60 wollen. Neuer Reiter „Leveln“ (ersetzt „Quests“; dein Questlog ist dort eine Ansicht) mit Plan | Ausgelassen | Questlog. Der Plan zeigt einen Plan Schritt für Schritt (annehmen, erledigen, abgeben) mit Navi-Pfeil. Immer dabei: Dungeon-Quests mit allen Vorquest-Ketten, Klassenquests und wichtige Vorquests. Alles andere nur, wenn es mehr EP pro Minute bringt als Monster hauen (Laufzeit aus dem Guild-Trip-Wegenetz, Gegner-EP eingerechnet, nahe Quests gebündelt) oder echten Mehrwert: Upgrade für deine Klasse, größere Tasche, viel Gold.
- „Warum diese Quest?“: EP, Zeit, EP pro Minute im Vergleich zum Monsterhauen und die Belohnung zu jedem Schritt. „Ausgelassen“ zeigt jede weggelassene Quest mit Grund; „Nicht machen“ / „Doch machen“ je Quest.
- Drei Tempo-Stufen: Nur das Nötigste (Standard), Ausgewogen, Gründlich. Elite-/Gruppenquests mit „Gruppe suchen“ (Gruppenfinder).
- Kasten „Quest-Führung“ unter der Minimap: die nächsten Schritte als Liste (unten rechts größer ziehen – je größer, desto mehr Schritte; Schriftgröße einstellbar) mit Zielfortschritt und Navi-Pfeil; verschiebbar, abschaltbar, wahlweise nur Text ohne Rahmen. Ersetzt auf Wunsch die WoW-Questliste. Aufteilung: JETZT (der eine Schritt, groß), NOCH ANNEHMEN (neue Quests mit NPC – füllt den Platz beim Größerziehen), DEINE QUESTS (jede Quest aus dem Log einmal mit Fortschritt; fertige grün mit Abgabe-NPC, nicht eingeplante grau mit Grund im Tooltip). Klick auf eine Zeile = Navi dorthin.
- Alle Einstellungen an einem Ort: Die Optionen haben links eine Liste der Bereiche (Allgemein, Darstellung, Erinnerungen, Teilen, dann je Modul: Gilde, Dungeons, Berufe, Klasse, Leveln, Navi, Chat) und rechts die Einstellungen des gewählten Bereichs mit Zwischenüberschriften und zum Scrollen. Jeden Schalter gibt es genau einmal (einige standen vorher doppelt da). Zahnräder springen direkt in ihren Bereich – z. B. das Zahnrad am Kasten der Quest-Führung öffnet Optionen › Leveln, das Zahnrad im Chat Optionen › Chat. Der An/Aus-Schalter eines Moduls steht oben in seinem Bereich.
- Die Schritte der Quest-Führung nennen jetzt den NPC („X annehmen – bei Name“), und der Navi-Pfeil springt von selbst zum nächsten Schritt, solange du die Führung benutzt (abschaltbar).
- Der Navi-Pfeil dreht sich jetzt fließend statt in kleinen Sprüngen.
- Automatische Quests: Eingeplante Quests werden angenommen und fertige Quests aus deinem Log abgegeben (Folgequests inklusive). Bei mehreren Belohnungen wählst du immer selbst. Shift gedrückt halten = in diesem Gespräch selbst machen. Begleitquests und Ruf-/Spenden-NPCs nie automatisch. Wahlweise auch Quests außerhalb der Führung annehmen. Standardmäßig aus – einschalten unter Optionen › Leveln.
- Händler: automatisch reparieren (wahlweise zuerst aus dem Gildengeld) und grauen Schrott verkaufen – Shift beim Öffnen des Händlers überspringt es einmal. Standardmäßig aus (Optionen › Allgemein › Händler).
- Belohnungsdaten aus QuestieDB (mit Erlaubnis) und cmangos classic-db (GPL), Gegenstandsangaben aus der Spieltabelle.
- Behoben: 188 Begleit- und Erkundungsquests fehlten in den Questdaten (z. B. die Begleitquest „Die Bruderschaft der Defias“, „Die Mine von Fargodeep“, die Druidenquest „Prüfung des Sees“) – jetzt überall dabei (Questgeber, Karte, Führung). Feiertagsquests werden dafür richtig aussortiert.
```

---

## 0.6.8-alpha (gebaut 17.11.2026)

```
## 0.6.8-alpha

**English**
- New window layout (Blizzard look): the main areas sit in a column on the left with our own gold icons instead of tabs at the bottom; the page name is shown large at the top with a short summary next to it (e.g. guild name and how many are online, class and level).
- Every page switches its views at the same spot, top right (Guild: Overview | Members, Dungeons: Dungeons | Groups | Trips, Professions: Recipes | Trainers, Class: Bars | Talents | Weapons, Navi: Guild | Trainers | Flight masters | Vendors, Options: General | Assists | Sharing | Modules | Reminders).
- No more doubled page titles – the space goes to the content (larger picture on the start page, longer guild and member lists).
- Guild Trip chat in the Blizzard look: real Blizzard frame with title, channels with our own gold icons and gold edge, unread counts as red pills (Trade muted), whispers with a shield in class colour, online dot and class/level/zone. Large header with a short summary (e.g. "12 of 40 online"); when whispering also Navi and Invite. Messages with grey time, coloured channel name and names in class colours; mentions of your name are highlighted in gold. New "Send" button. The loot window got the same frame, with item icons and who/when below.
- New option (Options › Assists › Navi): show the route as footprints instead of golden dots – left and right in turn, pointing the way, lighting up step by step on the minimap (calm on the world map). The dots stay the default.
- Dungeons: a hand-drawn map (our own drawing: coast, mountains, forest or steppe with a red route and compass) heads the selected dungeon. On the left, a selection with counts replaces the checkbox: for your level, all, with open quests, level ranges.
- New guild passport (Dungeons › Passport): every dungeon you enter and every guild trip you joined gives a stamp with date, runs and how many came along. Free fields suggest dungeons that fit your level and show the next trip. With "Share progress" your guild sees your passport and you see theirs.
- The book look stays exactly as it was (main window and chat).
- Quest database now comes from QuestieDB's Forever data (with kind permission of the Questie team): about 4,900 quests instead of 3,500, including new Forever quests, Forever-accurate positions and stricter prerequisites (all required quests, mutually exclusive quests, maximum level).
- Navi › Trainers and Vendors now list every trainer (class, profession, weapon master) and every vendor in the world with exact positions – no longer only the ones you or your guild have visited. Vendors show what they sell and whether they repair.
- Dungeon entrances for all classic dungeons are known from the start (both Stratholme gates, the Stockade in Forever's new Stormwind) – no need to have been there first.

**Deutsch**
- Neuer Fensteraufbau (Blizzard-Aussehen): Die Hauptbereiche stehen links als Leiste mit eigenen Goldsymbolen statt als Reiter unten; der Seitenname steht groß oben, daneben eine kurze Angabe (z. B. Gildenname und wie viele online sind, Klasse und Stufe).
- Jede Seite wechselt ihre Ansichten an derselben Stelle oben rechts (Gilde: Übersicht | Mitglieder, Dungeons: Dungeons | Gruppen | Ausflüge, Berufe: Rezepte | Lehrer, Klasse: Leisten | Talente | Bewaffnung, Navi: Gilde | Lehrer | Flugmeister | Händler, Optionen: Allgemein | Spielhilfen | Teilen | Module | Erinnerungen).
- Keine doppelten Seitentitel mehr – der Platz geht an den Inhalt (größeres Bild auf der Startseite, längere Gilden- und Mitgliederliste).
- Guild-Trip-Chat im Blizzard-Aussehen: echter Blizzard-Rahmen mit Titel, Kanäle mit eigenen Goldsymbolen und goldener Kante, Ungelesenes als rote Zahl (Handel gedämpft), Flüstern mit Wappenschild in Klassenfarbe, Online-Punkt und Klasse/Stufe/Gebiet. Große Kopfzeile mit kurzer Angabe (z. B. „12 von 40 online“), beim Flüstern zusätzlich Navi und Einladen. Nachrichten mit grauer Uhrzeit, farbigem Kanalnamen und Namen in Klassenfarbe; wer dich erwähnt, wird golden hervorgehoben. Neuer „Senden“-Knopf. Das Beute-Fenster hat denselben Rahmen, mit Gegenstandssymbol und darunter wer/wann.
- Neue Einstellung (Optionen › Spielhilfen › Navi): den Weg als Fußspuren statt goldener Punkte zeigen – links und rechts im Wechsel, in Laufrichtung, auf der Minimap Schritt für Schritt aufleuchtend (auf der Weltkarte ruhig). Standard bleiben die Punkte.
- Dungeons: Über dem gewählten Dungeon steht eine gezeichnete Landkarte (eigene Zeichnung: Küste, Berge, Wald oder Steppe mit roter Route und Kompassrose). Links ersetzt eine Auswahl mit Zählern das Häkchen: für deine Stufe, alle, mit offenen Quests, Stufenbereiche.
- Neu: Gilden-Reisepass (Dungeons › Reisepass): Jeder Dungeon, den du betrittst, und jeder Gildenausflug, zu dem du zugesagt hast, gibt einen Stempel mit Datum, Anzahl Läufe und wie viele dabei waren. Freie Felder schlagen passende Dungeons vor und zeigen den nächsten Ausflug. Mit „Fortschritt teilen“ sieht die Gilde deinen Pass – und du ihre.
- Das Buch-Aussehen bleibt genau wie bisher (Hauptfenster und Chat).
- Die Questdatenbank kommt jetzt aus den Forever-Daten von QuestieDB (mit freundlicher Erlaubnis des Questie-Teams): rund 4.900 statt 3.500 Quests, inklusive neuer Forever-Quests, Forever-genaue Positionen und genauere Vorquest-Prüfung (alle nötigen Quests, sich ausschließende Quests, Höchststufe).
- Navi › Lehrer und Händler zeigen jetzt alle Lehrer (Klasse, Beruf, Waffenmeister) und alle Händler der Welt mit genauer Position – nicht mehr nur die, bei denen du oder deine Gilde schon wart. Händler zeigen, was sie verkaufen und ob sie reparieren.
- Die Eingänge aller Classic-Dungeons sind von Anfang an bekannt (beide Tore von Stratholme, das Verlies im neuen Forever-Sturmwind) – man muss nicht erst dort gewesen sein.
```

---

## 0.6.7-alpha (gebaut 17.11.2026)

```
## 0.6.7-alpha

**English**
- New "What's new" window after an update (once per version; /trip neu shows it again) – with a clear nudge to turn on sharing: the checkboxes are right there plus "Turn everything on". If sharing is still off at login, a short chat hint reminds you (/trip teilen opens the settings).
- Guild Trip chat can now replace the WoW chat (optional, chat settings › "Replace the WoW chat with this one"): the WoW chat is hidden, Enter and / open the Guild Trip chat. Not shown there: loot, experience, combat log. Back any time with the checkbox or /trip wowchat. Locked while ElvUI, Prat & co. manage the chat.
- Real route guidance without any extra add-on: the new "Guild Trip | Walking network" knows precomputed walking paths (roads, bridges, passes) between quest givers, trainers, vendors, flight masters and docks. The arrow now points to the next turn instead of straight through mountains, shows the remaining distance along the path, and golden dots show the way on minimap and world map (the next turn is a ring, also set as WoW waypoint). If a flight is worth it, the arrow first leads you to the flight master. Paths computed with Shortest Path Forever by cjber (GPL) – thanks! If Shortest Path Forever itself is installed, it keeps guiding as before.
- Quest database: quest givers and objectives in Mulgore, Eastern Plaguelands, Redridge Mountains and Stormwind now sit in the right spot (Forever re-measured these maps).
- Navi: on arrival the arrow turns green over the last 100 yards and says "Arrived" with a soft sound; fixed targets fade out after a moment.
- Navi "there and back": heading to a vendor, trainer, weapon master or flight master while another target is active? After your stop the arrow automatically continues to the previous target.
- Navi after death: as a ghost the arrow leads to your corpse, then back to your previous target (can be turned off in Options › Modules).
- Own waypoints: shift+click on the world map, or /trip way 45.2 60.1 [zone] (also /way, unless TomTom or another add-on uses it).
- Plays nicely with Polestar: while it runs, Guild Trip never starts its arrow on its own (corpse, trip start) – only when you click.
- Guild Trip is now free software under the GNU GPL v3 or later; third-party parts are credited in THIRD_PARTY.md.
- Quest database (new add-on "Guild Trip | Questdaten", from pfQuest, MIT): the "!" on map and minimap now also shows quest givers you have never met – only quests that fit your level, race and class, with prerequisites done. Quests the game knows no location for get one from the database (objective or turn-in). Your own and your guild's finds still take priority (Forever differs from Classic in places).
- Click the "?" or "…" next to a quest in the objective tracker and the navi points you there (objective, or the turn-in once done). Can be turned off in Options › Modules.
- New loot window (button in the chat window or /trip beute): shows which item dropped and who got it – names in class colors, hover for the item tooltip, filter by rarity (default green and better).
- Guild Trip chat looks nicer in both themes: coloured dots per channel, flashing unread pills, a proper input field with placeholder, calmer message area, empty-state text, more spacing. Item links and other coloured text are now always readable on the book's parchment.

**Deutsch**
- Neues „Neu in dieser Version“-Fenster nach einem Update (einmal je Version; /trip neu zeigt es erneut) – mit deutlichem Hinweis aufs Teilen: die Häkchen stehen gleich dabei, dazu „Alles einschalten“. Ist Teilen beim Einloggen noch aus, erinnert ein kurzer Chat-Hinweis (/trip teilen öffnet die Einstellungen).
- Der Guild-Trip-Chat kann jetzt den WoW-Chat ersetzen (freiwillig, Chat-Einstellungen › „WoW-Chat durch diesen ersetzen“): Der WoW-Chat wird ausgeblendet, Enter und / öffnen den Guild-Trip-Chat. Dort nicht zu sehen: Beute, Erfahrung, Kampflog. Jederzeit zurück per Haken oder /trip wowchat. Gesperrt, solange ElvUI, Prat & Co. den Chat verwalten.
- Echte Wegführung ohne Zusatz-Addon: Das neue „Guild Trip | Wegenetz“ kennt vorab berechnete Laufwege (Straßen, Brücken, Pässe) zwischen Questgebern, Lehrern, Händlern, Flugmeistern und Anlegern. Der Pfeil zeigt jetzt zur nächsten Abbiegung statt quer durchs Gebirge, die Entfernung ist der Restweg, und goldene Punkte zeigen den Weg auf Minimap und Weltkarte (die nächste Abbiegung als Ring, zusätzlich als WoW-Wegpunkt). Lohnt sich ein Flug, führt der Pfeil erst zum Flugmeister. Wege berechnet mit Shortest Path Forever von cjber (GPL) – danke! Ist Shortest Path Forever selbst installiert, führt weiter dieses.
- Questdatenbank: Questgeber und Ziele in Mulgore, den Östlichen Pestländern, dem Rotkammgebirge und Sturmwind stehen jetzt an der richtigen Stelle (Forever hat diese Karten neu vermessen).
- Navi: Kurz vor dem Ziel wird der Pfeil grün, bei Ankunft kommt „Angekommen“ mit leisem Ton; feste Ziele blenden sich danach aus.
- Navi „hin und zurück“: Unterwegs kurz zum Händler, Lehrer, Waffenmeister oder Flugmeister? Danach zeigt der Pfeil von selbst wieder zum vorherigen Ziel.
- Navi nach dem Tod: Als Geist führt der Pfeil zu deiner Leiche, danach zurück zum vorherigen Ziel (abschaltbar in Optionen › Module).
- Eigene Wegpunkte: Umschalt+Klick auf die Weltkarte oder /trip way 45.2 60.1 [Gebiet] (auch /way, solange TomTom o. Ä. den Befehl nicht hat).
- Verträgt sich mit Polestar: Läuft es, startet Guild Trip seinen Pfeil nie von selbst (Leiche, Ausflugsbeginn) – nur auf Klick.
- Guild Trip ist jetzt freie Software unter der GNU GPL v3 oder später; fremde Teile sind in THIRD_PARTY.md genannt.
- Questdatenbank (neues Addon „Guild Trip | Questdaten“, aus pfQuest, MIT): Das „!“ auf Karte und Minimap zeigt jetzt auch Questgeber, bei denen du noch nie warst – nur Quests, die zu Stufe, Volk und Klasse passen und deren Vorquests erledigt sind. Quests, für die das Spiel keinen Ort kennt, bekommen einen aus der Datenbank (Ziel bzw. Abgabe). Eigene und Gilden-Funde haben weiter Vorrang (Forever weicht stellenweise von Classic ab).
- Klick auf „?“ oder „…“ neben einer Quest in der Zielverfolgung: Das Navi zeigt dorthin (Ziel, bzw. Abgabe, wenn fertig). Abschaltbar in Optionen › Module.
- Neues Beute-Fenster (Knopf im Chatfenster oder /trip beute): zeigt, welcher Gegenstand gefallen ist und wer ihn bekommen hat – Namen in Klassenfarbe, Tooltip beim Drüberfahren, Filter nach Seltenheit (Vorgabe grün und besser).
- Guild-Trip-Chat sieht in beiden Aussehen hübscher aus: farbige Punkte je Kanal, blinkende Zähler-Pillen, richtiges Eingabefeld mit Platzhalter, ruhigerer Nachrichtenbereich, Text bei leerem Gespräch, mehr Luft. Gegenstandslinks und andere bunte Texte sind auf dem Pergament des Buchs jetzt immer lesbar.
```

---

## 0.6.6-alpha (gebaut 16.11.2026)

```
## 0.6.6-alpha

**English**
- Bar 1 now follows the order of play for every spec: just press 1, 2, 3, 4 … ("Set up bars" moves your spells and macros; spots for spells you haven't learned yet stay free and fill up automatically).
- Minimap: quest icons are no longer drawn on top of your player arrow when you are already at the spot.
- Options › Sharing: long descriptions no longer run out of the window.
- Gear rating in the item tooltip: "Guild Trip: better / worse for you (spec)" based on the stat priority of your play style, compared with what you wear in that slot; also tells you when your class can't wear an armor type. Enchants on your worn item count too – if only the enchant tips the scale, the line says so. The line names the deciding reason, e.g. "better for you – +4 Spirit (your most important stat)". Can be turned off in Options › Modules.
- Remembers loot: when you loot gear (green and better), Guild Trip notes which enemy dropped it (boss, elite, rare) and where. The item tooltip then shows "Guild Trip: drops from … – zone". Shared with the developer via "Share spell data" and part of the starter pack – the basis for a future "best gear for you and where to get it" view.
- Class page: the order of play now shows key numbers in gold instead of a second row of small icons – much tidier. The trainer card explains on hover why it needs one visit to your class trainer.
- Trainer preview per class instead of per character: one visit to the class trainer with any character counts for all characters of that class – and ships with the starter pack, so new players see it right away.
- "Share spell data" now also sends your finds (class trainer lists, vendors, quest givers, trainers, dungeon entrances – no names) to the Guild Trip developer in your guild, so they make it into the starter pack for everyone.
- Class guide sharpened for Warrior, Paladin and Shaman: Arms gets Slam as filler and Sweeping Strikes for groups, Fury gets Whirlwind on bar 1 and a clear stance order, Protection keeps Demoralizing Shout up. Retribution opens with Seal of the Crusader + Judgement, keeps Seal of Command and switches to Righteousness at 3 stacks of Unsealed Wrath; Exorcism against undead for Retribution and Protection. Elemental gets Fire Nova and Magma Totem for groups, Enhancement uses Fire Nova instead of Chain Lightning, Restoration starts with Riptide.
- Guild trips, step 3: 15 minutes before a trip you signed up for you get a reminder; at the start the navi points you to the meeting point (unless you are already there). From 30 minutes before, the trip card turns into an arrival board: for everyone signed up it shows the distance to the meeting point and an estimated arrival – or "other continent" / "no location" (members need "Share my position"). Warlocks see whom to summon. Can be turned off in Options › Modules.
- Class page › Weapons: which weapon types your class can use, which ones you already know and which weapon master teaches the rest – click a row for the navi to the nearest one. When you talk to a weapon master, Guild Trip remembers what he really teaches in Forever and shares it with your guild via "Share recipes" (until then the list shows the Classic trainers, marked "per Classic").
- Own sounds: reminders and notices now ring a small Guild Trip bell instead of the raid warning; when a guild trip starts you hear three rising chimes. Try them with /trip klang. Turned off together with "Sound for notifications".
- Navi everywhere as a small green arrow instead of "Navi" buttons (members, Coming up, Navi targets, quests, dungeon entrance and quest giver, trip meeting point, travel prep, weapons, map search). Only the arrow starts the navi – clicking a row no longer does; the tooltip tells you where it leads, a grey arrow means no location is known yet.
- Name menu: click a character name (guild members, member list, Navi targets, trip participants) to open a small menu – Navi to (if they share their position), whisper, invite to group, poke, add friend. Offline members only offer what works offline.
- Events are created and answered entirely inside Guild Trip – the WoW calendar is never opened: "Create event" plans a guild trip with your own title (quest run, guild meeting, raid …) or a dungeon, including sign-up, reminder, navi to the meeting point and arrival board. WoW calendar events (e.g. from guild members without Guild Trip) can be accepted, marked maybe or declined right in the event view; your status is shown. Clicking an entry in "Coming up" opens the event or trip directly.
- New (optional): Guild Trip chat – like a messenger. Tabs (All, Guild, Group, Trade, Nearby and your own), whispers as separate conversations with unread counters that flash. Every conversation writes only where it belongs: guild tab to guild chat, a whisper only to that person, trade only to trade. Tab in the input jumps to the next conversation; item/quest/player links are clickable, clicking a name opens the name menu (now also with Ignore and Report). Blizzard's message filters and ignore list apply. Own subtle sounds – only for messages in a conversation you're not looking at (whisper on; guild, group and "sent" off by default), each switchable in the chat settings (cog in the chat window) and following the WoW effects volume. Works alongside ElvUI, Prat, Chatter, Glass and similar: they're detected, the chat settings show a hint (avoid double sounds) and a plain flat look is used by default (switchable). Open with /trip chat or via the minimap button menu; the WoW chat stays as it is.
- Book look: new thumb index – small, worn leather tabs with embossed gold symbols (house, banner, calendar, gate, hammer, shield, "!", compass, cog) instead of large labels; hovering slides a tab out and shows its name. The pages now have torn edges.
- Book look: aged ink – faded sepia instead of fresh black, slightly bled edges and worn, rubbed spots over the pages, as if the book were thousands of years old (still readable). Can be turned off in Options › Modules.
- New event window ("Create event" in the calendar or "Plan trip"): four numbered boxes – 1 What (type: dungeon, raid, quests, meeting, PvP, farming, party, other; title or destination; note), 2 When (day, start and duration, repeat weekly, reminder), 3 Where (your location, dungeon entrance, capital or later), 4 Who (spots, tanks/healers/DPS, level range). Only type, title and day are required; a one-line summary shows what will be announced. The trip card then shows which roles are still missing ("T 1/1 · H 0/1 · DD 2/3").
- Fixed a Lua error in the navi arrow tooltip (Widgets.lua:254).
- Calendar tidied up: no second heading, wider right column (day view without cut-off times/names, "Upcoming" and "Coming up" one below the other), filters no longer overlap, two equally sized buttons at the bottom.
- The box "Going on in the guild" is now called "Coming up".
- Fixed a Lua error with quest icons on the minimap ("QuestPins.lua:204 … 'sy' (a nil value)").
- Talent plans checked against the Forever talent tree: Arms Warrior, Arcane Mage and Shadow Priest no longer try talents before their row is unlocked (points would have gone into another tree); Hunters: "Lightning Reflexes" is now found correctly.
- Guild trips now also show up in the calendar (month grid, day view, "Upcoming") and in "Coming up" – with a navi button to the meeting point. Clicking a trip opens it in Dungeons › Trips to sign up.
- Guild Trip chat: a small speech bubble above the WoW chat opens it (with a counter for unread whispers; shift+drag to move, can be turned off), and you can set your own key under Key Bindings › AddOns.
- Guild Trip chat: names in class colors (in the book look a darker version that stays readable on parchment). The book chat is calmer: thin ink lines between list, history and input, selection in red instead of gold/orange bars.
- Guild Trip chat settings (cog) in two columns, with new options: background transparency, fade out when the mouse is away, line spacing, fade old lines, lock window.
- Pages that get too full (Options › Modules, Game aids) now continue on a second page – "Page 1 of 2" with ‹ › to turn.
- Book look: the thumb index no longer shows WoW's own white/gold label on hover; the "Guild Trip" header only appears on the start page; the Class page buttons (Bars, Talents, Weapons) no longer cross the fold.

**Deutsch**
- Leiste 1 folgt jetzt bei jeder Ausrichtung dem Ablauf: einfach 1, 2, 3, 4 … drücken („Leisten einrichten“ verschiebt Zauber und Makros; Plätze für noch nicht gelernte Zauber bleiben frei und füllen sich automatisch).
- Minimap: Quest-Symbole liegen nicht mehr auf deinem Spielerpfeil, wenn du schon am Ziel stehst.
- Optionen › Teilen: Lange Beschreibungen laufen nicht mehr aus dem Fenster.
- Ausrüstung bewerten im Gegenstands-Tooltip: „Guild Trip: besser / schlechter für dich (Ausrichtung)“ nach der Werte-Rangfolge deines Spielstils, verglichen mit dem, was du im gleichen Platz trägst; sagt auch, wenn deine Klasse eine Rüstungsart nicht tragen kann. Verzauberungen auf deinem getragenen Teil zählen mit – gibt nur die Verzauberung den Ausschlag, steht das dabei. Die Zeile nennt den entscheidenden Grund, z. B. „besser für dich – +4 Willenskraft (dein wichtigster Wert)“. Abschaltbar in Optionen › Module.
- Beute merken: Beim Plündern von Ausrüstung (grün und besser) merkt sich Guild Trip, welcher Gegner sie fallen ließ (Boss, Elite, Rar) und wo. Der Gegenstands-Tooltip zeigt dann „Guild Trip: fällt bei … – Gebiet“. Geht über „Zauberdaten teilen“ an den Entwickler und ins Startpaket – Grundlage für eine spätere Übersicht „beste Ausrüstung für dich und wo es sie gibt“.
- Klassen-Seite: Der Ablauf zeigt jetzt goldene Tastennummern statt einer zweiten Reihe kleiner Symbole – viel aufgeräumter. Die Lehrer-Karte erklärt beim Drüberfahren, warum sie einmal einen Besuch beim Klassenlehrer braucht.
- Lehrer-Vorschau je Klasse statt je Charakter: Ein Besuch beim Klassenlehrer mit irgendeinem Charakter gilt für alle Charaktere dieser Klasse – und kommt ins Startpaket, neue Spieler sehen sie sofort.
- „Zauberdaten teilen“ schickt jetzt auch deine Funde (Klassenlehrer-Listen, Händler, Questgeber, Lehrer, Dungeon-Eingänge – ohne Namen) an den Guild-Trip-Entwickler deiner Gilde, damit sie ins Startpaket für alle kommen.
- Klassen-Ratgeber für Krieger, Paladin und Schamane nachgeschärft: Waffen bekommt Zerschmettern als Füller und Weitreichende Stöße für Gruppen, Furor Wirbelwind auf Leiste 1 und eine klare Haltungs-Reihenfolge, Schutz hält den Demoralisierungsruf. Vergeltung eröffnet mit Siegel des Kreuzfahrers + Richturteil, hält Siegel des Befehls und wechselt bei 3 Stapeln Entfesselter Zorn auf Rechtschaffenheit; Exorzismus gegen Untote bei Vergeltung und Schutz. Elementar bekommt Feuernova und Magmatotem für Gruppen, Verstärkung nutzt Feuernova statt Kettenblitz, Wiederherstellung beginnt mit Springflut.
- Gildenausflüge, Stufe 3: 15 Minuten vor einem Ausflug, zu dem du angemeldet bist, kommt eine Erinnerung; zum Start zeigt das Navi den Weg zum Treffpunkt (außer du stehst schon da). Ab 30 Minuten vorher wird die Ausflugs-Karte zur Ankunftstafel: Für alle Angemeldeten stehen Entfernung zum Treffpunkt und ungefähre Ankunft da – oder „anderer Kontinent“ / „kein Standort“ (dafür braucht es „Meine Position teilen“). Hexer sehen, wen sie beschwören sollten. Abschaltbar in Optionen › Module.
- Klassen-Seite › Bewaffnung: welche Waffenarten deine Klasse tragen kann, welche du schon beherrschst und welcher Waffenmeister die übrigen lehrt – Klick auf eine Zeile startet das Navi zum nächsten. Sprichst du einen Waffenmeister an, merkt sich Guild Trip, was er in Forever wirklich lehrt, und teilt es über „Rezepte teilen“ mit deiner Gilde (bis dahin stehen die Classic-Lehrer da, markiert mit „laut Classic“).
- Eigene Klänge: Erinnerungen und Hinweise klingen jetzt nach einem kleinen Guild-Trip-Glöckchen statt nach der Raid-Warnung; beginnt ein Gildenausflug, hörst du drei aufsteigende Glockenschläge. Probehören mit /trip klang. Aus zusammen mit „Ton bei Benachrichtigungen“.
- Navi überall als kleiner grüner Pfeil statt „Navi“-Knöpfen (Mitglieder, Was steht an, Navi-Ziele, Quests, Dungeon-Eingang und Questgeber, Ausflugs-Treffpunkt, Reisevorbereitung, Bewaffnung, Kartensuche). Nur der Pfeil startet das Navi – ein Klick auf die Zeile nicht mehr; der Tooltip sagt, wohin, ein grauer Pfeil heißt: noch kein Ort bekannt.
- Namens-Menü: Klick auf einen Charakternamen (Gilde, Mitgliederliste, Navi-Ziele, Ausflugs-Teilnehmer) öffnet ein kleines Menü – Navi zu (wenn die Position geteilt wird), Flüstern, In Gruppe einladen, Anstupsen, Als Freund hinzufügen. Bei Offline-Mitgliedern nur, was offline geht.
- Termine entstehen und werden beantwortet nur noch in Guild Trip – der WoW-Kalender öffnet sich nie: „Termin erstellen“ plant einen Gildenausflug mit eigenem Titel (Questrun, Gildentreffen, Raid …) oder einem Dungeon, samt Anmeldung, Erinnerung, Navi zum Treffpunkt und Ankunftstafel. WoW-Termine (z. B. von Mitgliedern ohne Guild Trip) kannst du in der Terminansicht zusagen, auf „vielleicht“ setzen oder absagen; dein Stand steht dabei. Ein Klick in „Was steht an“ öffnet den Termin bzw. Ausflug direkt.
- Neu (freiwillig): Guild-Trip-Chat – wie ein Messenger. Reiter (Alle, Gilde, Gruppe, Handel, In der Nähe und eigene), Flüstern als eigene Gespräche mit Zähler für Ungelesenes, der blinkt. Jedes Gespräch schreibt nur dorthin, wo es hingehört: Gilde in den Gildenchat, Flüstern nur an diese Person, Handel nur in den Handel. Tab im Eingabefeld springt zum nächsten Gespräch; Gegenstands-, Quest- und Spielerlinks sind anklickbar, ein Klick auf einen Namen öffnet das Namens-Menü (jetzt auch mit Ignorieren und Melden). Blizzards Nachrichtenfilter und Ignorierliste gelten. Eigene, dezente Klänge – nur für Nachrichten in einem Gespräch, das du gerade nicht ansiehst (Flüstern an; Gilde, Gruppe und „gesendet“ zunächst aus), je einzeln in den Chat-Einstellungen abschaltbar (Zahnrad im Chatfenster), sie folgen der Effekt-Lautstärke von WoW. Läuft neben ElvUI, Prat, Chatter, Glass & Co.: Sie werden erkannt, die Chat-Einstellungen zeigen einen Hinweis (doppelte Töne vermeiden), und ein schlichtes, flaches Aussehen ist dann Vorgabe (umschaltbar). Öffnen mit /trip chat oder über das Menü am Minimap-Knopf; der WoW-Chat bleibt, wie er ist.
- Buch-Aussehen: neues Daumenregister – kleine, abgegriffene Lederreiter mit geprägtem Goldsymbol (Haus, Banner, Kalender, Tor, Hammer, Schild, „!“, Kompass, Zahnrad) statt großer Beschriftung; beim Drüberfahren gleitet der Reiter heraus und zeigt den Namen. Die Seiten sind am Rand eingerissen.
- Buch-Aussehen: gealterte Tinte – verblasstes Sepia statt frischem Schwarz, leicht ausgelaufene Ränder und abgegriffene Stellen über den Seiten, als wäre das Buch tausende Jahre alt (trotzdem lesbar). Abschaltbar in Optionen › Module.
- Neues Termin-Fenster („Termin erstellen“ im Kalender oder „Ausflug planen“): vier nummerierte Kästen – 1 Was (Art: Dungeon, Raid, Quests, Treffen, PvP, Farmen, Fest, Anderes; Titel oder Ziel; Notiz), 2 Wann (Tag, Beginn und Dauer, wöchentlich wiederholen, Erinnerung), 3 Wo (dein Standort, Dungeon-Eingang, Hauptstadt oder später), 4 Wer (Plätze, Tanks/Heiler/DDs, Stufenbereich). Pflicht sind nur Art, Titel und Tag; eine Zeile fasst zusammen, was angekündigt wird. Die Ausflugs-Karte zeigt danach, welche Rollen noch fehlen („T 1/1 · H 0/1 · DD 2/3“).
- Lua-Fehler im Tooltip des Navi-Pfeils behoben (Widgets.lua:254).
- Kalender aufgeräumt: keine zweite Überschrift, breitere rechte Spalte (Tagesansicht ohne abgeschnittene Zeiten/Namen, „Demnächst“ und „Was steht an“ untereinander), Filter überlappen nicht mehr, unten zwei gleich große Knöpfe.
- Der Kasten „In der Gilde los“ heißt jetzt „Was steht an“.
- Lua-Fehler bei Quest-Symbolen auf der Minimap behoben („QuestPins.lua:204 … 'sy' (a nil value)“).
- Talentpläne gegen den Forever-Talentbaum geprüft: Krieger Waffen, Magier Arkan und Priester Schatten wollen Talente nicht mehr vor der Freischaltung ihrer Reihe (die Punkte wären sonst in einen anderen Baum gewandert); Jäger: „Blitzartige Reflexe“ wird jetzt richtig gefunden.
- Gildenausflüge erscheinen jetzt auch im Kalender (Monatsraster, Tagesansicht, „Demnächst“) und in „Was steht an“ – mit Navi-Knopf zum Treffpunkt. Ein Klick auf den Ausflug öffnet ihn unter Dungeons › Ausflüge zum Anmelden.
- Guild-Trip-Chat: Eine kleine Sprechblase oben am WoW-Chat öffnet ihn (mit Zähler für ungelesenes Flüstern; Umschalt+Ziehen verschiebt sie, abschaltbar), außerdem eine eigene Taste unter Tastaturbelegung › AddOns.
- Guild-Trip-Chat: Namen in Klassenfarbe (im Buch-Aussehen eine dunklere Fassung, die auf Pergament lesbar bleibt). Der Buch-Chat ist ruhiger: feine Tintenlinien zwischen Liste, Verlauf und Eingabe, Auswahl in Rot statt gold/oranger Balken.
- Chat-Einstellungen (Zahnrad) zweispaltig, mit neuen Möglichkeiten: Durchsichtigkeit des Hintergrunds, Ausblenden ohne Maus, Zeilenabstand, alte Zeilen verblassen, Fenster festsetzen.
- Zu volle Seiten (Optionen › Module, Spielhilfen) gehen jetzt auf einer zweiten Seite weiter – „Seite 1 von 2“ mit ‹ › zum Blättern.
- Buch-Aussehen: Das Daumenregister zeigt beim Drüberfahren keine weiß-goldene WoW-Beschriftung mehr; „Guild Trip“ steht nur noch auf der Startseite; die Knöpfe der Klassen-Seite (Leisten, Talente, Bewaffnung) liegen nicht mehr über der Falz.
```

---

## 0.6.5-alpha (gebaut 15.11.2026)

```
## 0.6.5-alpha – Quests, vendors, class guide for all classes

**English**
- Buff reminder now also watches your pet: hunters get "Call Pet", "Revive Pet" when it died and "Feed Pet" when it is unhappy; warlocks get a summon (Voidwalker with a soul shard, otherwise Imp); mages with the Water Elemental talent get their elemental. Click the icon to cast – only outside combat, not while flying or mounted.
- Quests page: see who in your guild has the same quest. Turn on "Share quests" in Options › Sharing – the list gets a GUILD column, the details show each member's progress ("Thrall 5/8, Rehgar done"). If the game knows no location for one of your quests, the location of a guild member is used for the Navi. Only shared with your own checkbox, nothing is saved.
- Find a group for elite quests: on the Quests page, elite and group quests get a "Find group" button. Your listing appears in Dungeons › Groups; guild members who have the same quest get a chat note and the "!" on the minimap button.
- Quest icons on the world map and minimap: a gold ring with a dot marks the objective area, a ring with a tick shows where to turn in. Hover for progress, click to start the Navi. Can be turned off in Options › Game aids › Navi.
- Quest givers ("!"): Guild Trip remembers where you were offered new quests (with "Share quests" also your guild's finds) and shows a "!" on the map and minimap – only for quests you have not done yet and that fit your level. Hover shows the quests, click starts the Navi. Off automatically when Questie is installed (it shows its own).
- Druid: cat and bear form bars. New "Forms" view on the Class page shows both bars with their order of use; "Set up bars" now also fills the cat bar (slots 73-84) and bear bar (97-108), including Forever's new abilities (Power Shift, Primal Bite, Feral Charge, Lacerate) once learned. Warrior stance bars are never touched.
- Performance: Professions and Class pages open much faster and no longer stall – item names are requested only once, page refreshes are bundled, the buff reminder no longer re-reads your whole spellbook and talent tree on every aura change, and the quest location search stops as soon as every quest has a location.
- Plays nicer with map addons (e.g. OpenMaps): the guild map search starts collapsed and stays on the map's own layer, map icons no longer float above other windows.
- Navi › Trainers: choose which trainers to show – class trainers, all professions or a single profession, weapon trainers, other. Your choice is remembered.
- Vendor directory in the Navi: every vendor you open is remembered with location and offer, sorted into groups (vials, thread & dyes, trade goods, food & drink, reagents, ammo, recipes, bags, weapons, armor, repair). New "Vendors" view with a filter – click to start the Navi. With "Share vendor finds" (Options › Sharing) the guild fills the directory together.
- Dungeons page: the "Trips" switch no longer slides under the dungeon card; "Also open for" shows as many names as fit (full list on hover); the data credit is no longer cut off.
- Navi to dungeon entrances: "To entrance" on the dungeon card. Classic dungeons start with approximate entrances; every dungeon you enter is remembered exactly (and shared with "Share dungeon progress"). Other continent? The Navi leads you to the zeppelin or ship first.
- Options › Modules is now a checkbox list: every module and its single features can be switched on or off (e.g. quest icons, quest givers, vendor directory, buff reminder, talent notice, guild map search). A module switched off no longer starts at all after reloading.
- Guild map search on the world map is readable again in the book look (own dark box) and sits reliably on top of the map.
- "What's on in the guild": a profession rank you can learn now ("Fishing: Journeyman") gets a "Navi" button to the nearest trainer who teaches that rank. Trainers you talk to remember which ranks they teach. These ranks are shared with the guild (with "Share recipes") and shown in Navi › Trainers ("teaches Journeyman, Expert"); the filter can show only trainers known to teach a rank.
- Class page › Trainer: instead of just "Level 18", it now shows what comes next ("Then: Renew (Rank 3), Heal …"), or what you can learn right now. Hover for the full list by level. Guild Trip remembers this from your last visit to the class trainer.
- Class guide reworked for all 9 classes and 27 specs, based on the current WoW Forever guides: own combat bar per spec, order of play including procs (e.g. Missile Barrage, Heating Up, Fingers of Frost, Nightfall, Maelstrom Weapon) and the buffs to have up, dungeon and raid versions, and a talent plan for levels 10–60 for every spec (new Forever talents included, every row unlocked in time).
- Play style picker on the Class page: hover a style to see its pros and cons. (The old picker in Options only ever showed "automatic" – fixed.)
- Dungeon/raid: hover "Stats" to see which food, elixir and potion fit your role.
- Race tips for all races including Alliance and Skyborne (passive racials), class tips now rotate.
- "Set up bars" now also swaps two macros onto their right places when both spells are in the plan; a macro that stays is named in chat. Rogue: Pick Pocket is now labeled "Steal".
- Starter pack: trainers, vendors, quest givers and dungeon entrances found by Guild Trip players ship with the add-on (growing with every version).

**Deutsch**
- Die Buff-Erinnerung achtet jetzt auch auf deinen Begleiter: Jäger bekommen „Tier rufen“, „Tier wiederbeleben“, wenn es gestorben ist, und „Tier füttern“, wenn es unglücklich ist; Hexenmeister einen Dämon (Leerwandler mit Seelensplitter, sonst Wichtel); Magier mit Wasserelementar-Talent ihren Elementar. Klick aufs Symbol wirkt den Zauber – nur außerhalb des Kampfes, nicht im Flug oder auf dem Reittier.
- Quest-Seite: Sieh, wer in deiner Gilde dieselbe Quest hat. „Quests teilen“ in Optionen › Teilen einschalten – die Liste bekommt eine Spalte GILDE, die Details zeigen den Fortschritt jedes Mitglieds („Thrall 5/8, Rehgar fertig“). Kennt das Spiel für eine deiner Quests keinen Ort, nutzt das Navi den Ort eines Gildenmitglieds. Geteilt wird nur mit eigenem Häkchen, gespeichert wird nichts.
- Gruppe für Elite-Quests: Auf der Quest-Seite haben Elite- und Gruppenquests einen Knopf „Gruppe suchen“. Dein Gesuch erscheint unter Dungeons › Gruppen; Gildenmitglieder mit derselben Quest bekommen einen Hinweis im Chat und das „!“ am Minimap-Knopf.
- Quest-Symbole auf Weltkarte und Minimap: Goldring mit Punkt = Zielgebiet, Ring mit Haken = hier abgeben. Maus drüber zeigt den Fortschritt, Klick startet das Navi. Abschaltbar in Optionen › Spielhilfen › Navi.
- Questgeber („!“): Guild Trip merkt sich, wo du neue Quests angeboten bekommen hast (mit „Quests teilen“ auch die Funde deiner Gilde), und zeigt dort ein „!“ auf Karte und Minimap – nur für Quests, die du noch nicht hattest und die zu deiner Stufe passen. Maus drüber zeigt die Quests, Klick startet das Navi. Automatisch aus, wenn Questie installiert ist (das zeigt eigene).
- Druide: Katzen- und Bärenleiste. Neue Ansicht „Gestalten“ auf der Klassen-Seite zeigt beide Leisten mit Ablauf; „Leisten einrichten“ belegt jetzt auch die Katzenleiste (Plätze 73–84) und Bärenleiste (97–108), samt Forevers neuen Fähigkeiten (Machtverschiebung, Urtümlicher Biss, Wilde Attacke, Aufschlitzen), sobald gelernt. Krieger-Haltungsleisten bleiben unberührt.
- Leistung: Berufe- und Klassen-Seite öffnen deutlich schneller und hängen nicht mehr – Gegenstandsnamen werden nur einmal angefragt, Auffrischungen gebündelt, die Buff-Erinnerung liest nicht mehr bei jeder Aura-Änderung Zauberbuch und Talentbaum neu, die Quest-Ortssuche hört auf, sobald jede Quest einen Ort hat.
- Verträgt sich besser mit Karten-Addons (z. B. OpenMaps): Die Gilden-Kartensuche startet eingeklappt und bleibt auf der Ebene der Karte, Kartensymbole liegen nicht mehr über anderen Fenstern.
- Navi › Lehrer: Auswahl, welche Lehrer gezeigt werden – Klassenlehrer, alle Berufe oder ein bestimmter Beruf, Waffenlehrer, Sonstige. Die Wahl wird gemerkt.
- Händler-Verzeichnis in der Navi: Jeder Händler, den du öffnest, wird mit Ort und Angebot gemerkt und in Gruppen sortiert (Phiolen, Faden & Farbstoffe, Handwerkswaren, Essen & Trinken, Reagenzien, Munition, Rezepte, Taschen, Waffen, Rüstung, Reparieren). Neue Ansicht „Händler“ mit Auswahl – Klick startet das Navi. Mit „Händler-Funde teilen“ (Optionen › Teilen) füllt die Gilde das Verzeichnis gemeinsam.
- Dungeon-Seite: Der Umschalter „Ausflüge“ rutscht nicht mehr unter die Dungeon-Karte; „Auch offen bei“ zeigt so viele Namen, wie passen (alle beim Drüberfahren); die Quellenangabe wird nicht mehr abgeschnitten.
- Navi zum Dungeon-Eingang: „Zum Eingang“ auf der Dungeon-Karte. Classic-Dungeons haben ungefähre Startwerte; jeden Dungeon, den du betrittst, merkt sich Guild Trip genau (und teilt ihn mit „Dungeon-Fortschritt teilen“). Anderer Kontinent? Das Navi führt erst zum Zeppelin oder Schiff.
- Optionen › Module ist jetzt eine Häkchen-Liste: Jedes Modul und seine Einzelfunktionen lassen sich an- und ausschalten (z. B. Quest-Symbole, Questgeber, Händler-Verzeichnis, Buff-Erinnerung, Talent-Hinweis, Gildensuche auf der Karte). Ein ausgeschaltetes Modul startet nach dem Neuladen gar nicht mehr.
- Die Gildensuche auf der Weltkarte ist im Buch-Aussehen wieder lesbar (eigener dunkler Kasten) und liegt zuverlässig über der Karte.
- „In der Gilde los“: Eine jetzt lernbare Berufsstufe („Angeln: Geselle“) bekommt einen Knopf „Navi“ zum nächsten Lehrer, der diese Stufe lehrt. Lehrer, die du ansprichst, merken sich, welche Stufen sie lehren. Diese Stufen gehen mit „Rezepte teilen“ an die Gilde und stehen in Navi › Lehrer („lehrt Geselle, Experte“); die Auswahl kann nur Lehrer zeigen, die eine Stufe nachweislich lehren.
- Klassen-Seite › Lehrer: statt nur „Stufe 18“ steht jetzt da, was dann kommt („Dann: Erneuerung (Rang 3), Heilung …“) bzw. was du gerade lernen kannst. Maus drüber zeigt alles nach Stufe. Guild Trip merkt sich das beim letzten Besuch beim Klassenlehrer.
- Klassen-Ratgeber für alle 9 Klassen und 27 Ausrichtungen neu, nach den aktuellen WoW-Forever-Guides: eigene Kampfleiste je Ausrichtung, Ablauf mit Auslösern (z. B. Geschosssalve, Aufwärmen, Eisige Finger, Einbruch der Nacht, Waffe des Mahlstroms) und den Buffs vorab, Dungeon- und Raid-Varianten sowie ein Talentplan Stufe 10–60 für jede Ausrichtung (inkl. neuer Forever-Talente, jede Reihe rechtzeitig frei).
- Spielstil-Auswahl auf der Klassen-Seite: Maus über einen Stil zeigt Vor- und Nachteile. (Die alte Auswahl in den Optionen zeigte nur „automatisch“ – behoben.)
- Dungeon/Raid: Maus über „Werte“ zeigt passendes Essen, Elixier und Trank für deine Rolle.
- Volks-Tipps für alle Völker inkl. Allianz und Himmelsgeborene (passive Volksfähigkeiten), Klassen-Tipps wechseln sich ab.
- „Leisten einrichten“ tauscht jetzt auch zwei Makros auf ihre richtigen Plätze, wenn beide Zauber im Plan stehen; ein Makro, das liegen bleibt, wird im Chat genannt. Schurke: Taschendiebstahl heißt jetzt „Stehlen“.
- Startpaket: Lehrer, Händler, Questgeber und Dungeon-Eingänge, die Guild-Trip-Spieler gefunden haben, kommen mit dem Addon (wächst mit jeder Version).
```

---

## 0.6.4-alpha (gebaut 14.11.2026)

```
## 0.6.4-alpha – Quests and travel legs

**English**
- **New tab "Quests":** all quests in your log with level, progress for every objective and an "(Elite)" mark for group quests. Finished quests are green and listed first.
- **Navi to your quests:** "Navi" points the golden arrow to the quest objective – or to the turn-in once the quest is done. The location comes straight from the game, also for quests in other zones and on the other continent.
- **Travel in legs:** if your target is on the other continent, the arrow first leads you to the nearest zeppelin or boat ("Leg 1") and switches to the real target automatically once you arrive.

**Deutsch**
- **Neuer Reiter „Quests“:** alle Quests aus deinem Log mit Stufe, Fortschritt für jedes Ziel und „(Elite)“ bei Gruppenquests. Fertige Quests sind grün und stehen oben.
- **Navi zu deinen Quests:** „Navi“ lässt den goldenen Pfeil zum Questziel zeigen – oder zur Abgabe, wenn die Quest erledigt ist. Der Ort kommt direkt aus dem Spiel, auch für Quests in anderen Gebieten und auf dem anderen Kontinent.
- **Reisen in Etappen:** Liegt dein Ziel auf dem anderen Kontinent, führt dich der Pfeil zuerst zum nächsten Zeppelin oder Schiff („Etappe 1“) und schaltet nach der Ankunft von selbst auf das eigentliche Ziel um.
```

---

## 0.6.3-alpha (gebaut 14.11.2026)

```
## 0.6.3-alpha – Readable again, new logo

**English**
- New logo: crossed axes on a shield with a GT medallion.
- Fixed: in the Blizzard look many texts turned dark brown/red after switching pages and were hard to read.
- Navi arrow: lines below the arrow no longer overlap with long target names, and all text has an outline so it stays readable on bright ground.
- Golden player arrow now only replaces the minimap icon; the world map (and map addons like OpenMap) keep their own arrow.

**Deutsch**
- Neues Logo: gekreuzte Äxte auf einem Schild mit GT-Medaillon.
- Behoben: Im Blizzard-Aussehen wurden nach einem Seitenwechsel viele Texte dunkelbraun/-rot und waren kaum lesbar.
- Navi-Pfeil: Die Zeilen unter dem Pfeil überdecken sich bei langen Zielnamen nicht mehr, und alle Texte haben einen Rand – gut lesbar auch auf hellem Boden.
- Der goldene Spielerpfeil ersetzt nur noch das Symbol auf der Minimap; die Weltkarte (auch Karten-Addons wie OpenMap) behält ihren eigenen Pfeil.
```

---

## 0.6.2-alpha (gebaut 14.11.2026)

```
## 0.6.2-alpha – Guild trips

**English**
- **New: guild trips** (Dungeons tab → "Trips"). Plan a dungeon trip with day, time and meeting point (the spot where you stand when you announce it). Your guild sees it right away and can sign up with their role ("I'm coming", "Maybe", "Sign off"). The leader gets a notice for every sign-up, and "Navi to meeting point" points everyone there.
- **Trip prep:** for each dungeon quest you see who carries it (has it in their quest log and can share it in the dungeon), which quests nobody has picked up yet (click a quest = navi to the quest giver) and who is still missing a prerequisite. One copy per group is enough – only prerequisites and class quests are needed by everyone. Only members who share their dungeon progress (Options → Sharing) are included.
- **Class guide checked against real Forever data:** every class now knows the new talent abilities Forever added (e.g. Arcane Blast, Ice Lance, Incinerate, Holy Shock, Wild Growth, Riptide, Mutilate). They get a spot from key 9 onwards and only appear once you have learned the talent.
- **Racial abilities (Horde):** active racials get their own spot on key 12 (bar 1 cooldown, bar 2 emergency, bar 3 utility). If you already have them somewhere on your bars, they stay where they are. Passive racials appear as a tip.
- Fixed: setting up the bars could put spells on the wrong keys when a plan skips spots.

**Deutsch**
- **Neu: Gildenausflüge** (Reiter Dungeons → „Ausflüge“). Plane einen Dungeon-Ausflug mit Tag, Uhrzeit und Treffpunkt (die Stelle, an der du beim Ankündigen stehst). Die Gilde sieht ihn sofort und meldet sich mit ihrer Rolle an („Ich komme“, „Vielleicht“, „Abmelden“). Der Leiter bekommt zu jeder Anmeldung einen Hinweis, „Navi zum Treffpunkt“ führt alle hin.
- **Reisevorbereitung:** Für jede Dungeon-Quest siehst du, wer sie trägt (hat sie im Questlog und kann sie im Dungeon teilen), welche Quest noch niemand geholt hat (Klick auf die Quest = Navi zum Questgeber) und wem noch eine Vorquest fehlt. Eine Quest reicht pro Gruppe – nur Vorquests und Klassenquests braucht jeder selbst. Berücksichtigt werden Mitglieder, die ihren Dungeon-Fortschritt teilen (Optionen › Teilen).
- **Klassen-Ratgeber mit echten Forever-Daten geprüft:** Jede Klasse kennt jetzt die neuen Talent-Fähigkeiten von Forever (z. B. Arkanschlag, Eislanze, Verbrennen, Heiliger Schock, Wildwuchs, Springflut, Verstümmeln). Sie bekommen einen Platz ab Taste 9 und erscheinen erst, wenn du das Talent gelernt hast.
- **Volksfähigkeiten (Horde):** Aktive Volksfähigkeiten bekommen ihren eigenen Platz auf Taste 12 (Leiste 1 Stärkephase, Leiste 2 Notfall, Leiste 3 Hilfe). Liegen sie schon irgendwo auf deinen Leisten, bleiben sie dort. Passive erscheinen als Tipp.
- Behoben: „Leisten einrichten“ konnte Zauber auf falsche Tasten legen, wenn ein Plan Plätze auslässt.
```

---

## 0.6.1-alpha (gebaut 14.11.2026, Stand Buch 14)

```
## 0.6.1-alpha – Class guide for all classes

**English**
- The class guide now covers all classes: Warrior, Rogue, Hunter, Mage, Warlock, Paladin, Shaman and Druid join the Priest – with suggested bars (combat, emergency, utility), flow, stat priority, buffs and tips for all three specs. Talent plans for these classes will follow.
- The flow below bar 1 is now shown as icons with arrows instead of key numbers.
- Calendar overhaul: event icons instead of cut-off names, running WoW events as a thin bar, day view with full names, "Coming up" also shows when events start or end, filters with colour legend (WoW events, guild, own, resets) and a "Create event" button that opens Blizzard's calendar.
- Dungeons and Groups are now one tab: switch between "Dungeons" and "Groups (n)" at the top left. "Find group", chat notices and the minimap "!" open the groups view directly.
- New page Options → Sharing: every switch for what Guild Trip shares with your guild (position, dungeon progress, recipes, spell data) in one place.
- Alliance: the navigation tip for other continents now names Alliance ships instead of Horde zeppelins, and the trainer directory has its own list of Alliance trainers (Stormwind, Ironforge, Darnassus; approximate positions until a guild member visits them).
- New guild page: guild name, members, online count and message of the day at the top; "Online now" with class icons, level and zone (click = navi to members who share their position, right-click = whisper); "Going on in the guild" with upcoming guild events, group requests and due trainer visits.
- New navi page: current target with distance and travel tip at the top; pick a target from the guild, trainers (your class trainer first) or your known flight masters, nearest first; arrow settings in one line at the bottom.
- Preview: new look "Old book" (Options → Display → Look): the whole window becomes an open book – worn leather cover with blind tooling, two aged parchment pages with a centre fold (start page with an illuminated initial, wax-seal link and table of contents), a thumb index of leather tabs, an old-print typeface (IM FELL English), buttons as ink links, section headings with ornamental rules, parchment drop-down menus, every page laid out as a two-page spread (guild list like a ledger across both pages) and fully readable lists. The daily overview and notices become loose sheets of parchment.
- New page Options → Game aids: all settings of the class guide (spec, situation, buff reminder, automatic talents, keep bars up to date), the navigation arrow and the group finder (role, notices) in one place. All sharing switches are now only in Options → Sharing.
- Sounds: page turning, opening/closing the book, ticking boxes and seal links use matching in-game sounds (switch: menu sounds). /trip klang plays them all as a preview.
- Fixed: the checkbox "Keep bars up to date automatically" appeared next to the minimap.
- Fixed: spending talent points no longer shows a red error message.

**Deutsch**
- Der Klassen-Ratgeber gilt jetzt für alle Klassen: Krieger, Schurke, Jäger, Magier, Hexenmeister, Paladin, Schamane und Druide kommen zum Priester dazu – mit Leisten-Vorschlag (Kampf, Notfall, Hilfe), Ablauf, Werte-Reihenfolge, Buffs und Tipps für alle drei Ausrichtungen. Talentpläne für diese Klassen folgen.
- Der Ablauf unter Leiste 1 erscheint jetzt als Symbole mit Pfeilen statt als Tastennummern.
- Kalender überarbeitet: Event-Symbole statt abgeschnittener Namen, laufende WoW-Events als dünner Streifen, Tagesansicht mit vollen Namen, „Demnächst“ zeigt auch, wann Events beginnen oder enden, Filter mit Farblegende (WoW-Events, Gilde, Eigene, Resets) und ein Knopf „Termin erstellen“, der Blizzards Kalender öffnet.
- Dungeons und Gruppen sind jetzt ein Reiter: oben links zwischen „Dungeons“ und „Gruppen (n)“ umschalten. „Gruppe suchen“, Chat-Hinweise und das „!“ an der Minimap öffnen direkt die Gruppen-Ansicht.
- Neue Seite Optionen → Teilen: alle Schalter dafür, was Guild Trip mit deiner Gilde teilt (Position, Dungeon-Fortschritt, Rezepte, Zauberdaten), an einem Ort.
- Allianz: Der Navi-Tipp für andere Kontinente nennt jetzt Allianz-Schiffe statt Horde-Zeppeline, und das Lehrer-Verzeichnis hat eine eigene Liste mit Allianz-Lehrern (Sturmwind, Eisenschmiede, Darnassus; Positionen ungefähr, bis ein Gildenmitglied sie besucht).
- Neue Gilde-Seite: oben Gildenname, Mitglieder, Online-Zahl und Nachricht des Tages; „Jetzt online“ mit Klassensymbol, Stufe und Gebiet (Klick = Navi zu Mitgliedern, die ihre Position teilen, Rechtsklick = anflüstern); „In der Gilde los“ mit nächsten Gildenterminen, Gruppengesuchen und fälligen Lehrerbesuchen.
- Neue Navi-Seite: oben das aktuelle Ziel mit Entfernung und Reisetipp; Ziele aus Gilde, Lehrern (eigener Klassenlehrer zuerst) oder bekannten Flugmeistern wählen, die nächsten zuerst; Pfeil-Einstellungen unten in einer Zeile.
- Probe: neues Aussehen „Altes Buch“ (Optionen → Darstellung → Aussehen): das ganze Fenster wird ein aufgeschlagenes Buch – abgegriffener Ledereinband mit Blindprägung, zwei gealterte Pergamentseiten mit Falz (Startseite mit Initiale, Wachssiegel-Link und Inhaltsverzeichnis), ein Daumenregister aus Lederreitern, alte Druckschrift (IM FELL English), Knöpfe als Tintenlinks, Überschriften mit Zierlinie, Auswahlmenüs aus Pergament, jede Seite als Doppelseite (Gildenliste wie ein Kassenbuch über beide Seiten) und vollständig lesbare Listen. Tagesüberblick und Hinweise werden lose Pergamentblätter.
- Neue Seite Optionen → Spielhilfen: alle Einstellungen des Klassen-Ratgebers (Ausrichtung, Situation, Buff-Erinnerung, Talente automatisch, Leisten aktuell halten), des Navi-Pfeils und des Gruppenfinders (Rolle, Hinweise) an einem Ort. Alle Teilen-Schalter stehen nur noch unter Optionen → Teilen.
- Klänge: Umblättern, Buch öffnen/schließen, Häkchen und Siegel-Links mit passenden Klängen aus dem Spiel (Schalter: Menüklänge). /trip klang spielt alle zur Probe vor.
- Behoben: Das Häkchen „Leisten automatisch aktuell halten“ erschien neben der Minimap.
- Behoben: Beim Setzen von Talentpunkten erscheint keine rote Fehlermeldung mehr.
```

---

## 0.6.0-alpha (Paket gebaut: dist/GuildTrip_0.6.0-alpha_CurseForge.zip)

```
## 0.6.0-alpha – English interface

**English**
- Guild Trip now speaks English: the whole interface (home, calendar, guild, guild map, Navi, dungeons, groups, professions, class guide, options, chat messages) is translated.
- New option "Sprache / Language" (Options → More settings): Automatic (follows your game language), Deutsch or English. Changing it asks to reload the interface.
- New: situations for the class guide – Levelling, Dungeon, Raid (automatic in instances): flow, stats and tips change, your bar spots stay the same.
- New: learning order at your class trainer – spells sorted by your plan (combat first), with costs and your gold; "Learn recommended" buys them after a confirmation.
- New: talent points by plan – a notice when a point is free and a "Spend next point" button (one point, with confirmation); fully automatic only if you tick it.
- New: buff reminder above your bars (out of combat): shows missing or expiring buffs – buffs from other players count – click an icon to cast it.
- With the English interface, dungeon names are shown in English even on a German game client. Quest titles, profession and recipe names come from the game and follow your game language.

**Deutsch**
- Guild Trip spricht jetzt auch Englisch: die ganze Oberfläche (Startseite, Kalender, Gilde, Gildenkarte, Navi, Dungeons, Gruppen, Berufe, Klassen-Ratgeber, Optionen, Chatmeldungen) ist übersetzt.
- Neue Option „Sprache / Language“ (Optionen → Weitere Einstellungen): Automatisch (folgt der Spielsprache), Deutsch oder English. Nach dem Wechsel fragt Guild Trip, ob die Oberfläche neu geladen werden soll.
- Neu: Situationen im Klassen-Ratgeber – Leveln, Dungeon, Raid (in Instanzen automatisch): Ablauf, Werte und Tipps passen sich an, die Plätze auf deinen Leisten bleiben gleich.
- Neu: Lern-Reihenfolge beim Klassenlehrer – Zauber nach deinem Plan sortiert (Kampf zuerst), mit Kosten und deinem Gold; „Empfohlene lernen“ kauft sie nach Rückfrage.
- Neu: Talentpunkte nach Plan – Hinweis bei freiem Punkt und Knopf „Nächsten Punkt setzen“ (ein Punkt, mit Rückfrage); ganz automatisch nur per Häkchen.
- Neu: Buff-Erinnerung über den Leisten (außerhalb des Kampfes): zeigt fehlende oder bald auslaufende Buffs – Buffs von anderen Spielern zählen mit – Klick aufs Symbol wirkt den Buff.
- Mit englischer Oberfläche erscheinen Dungeon-Namen auch auf einem deutschen Spiel auf Englisch. Questtitel, Berufs- und Rezeptnamen kommen aus dem Spiel und folgen der Spielsprache.
```

---

## 0.5.4-alpha (Paket gebaut: dist/GuildTrip_0.5.4-alpha_CurseForge.zip, enthält 0.5.3)

```
## 0.5.4-alpha

**English**
- New tab "Klasse" – class guide, priest first:
  - Suggested action bars: bar 1 combat (keys 1–8), bar 2 emergency & healing, bar 3 utility. Fixed spots; spells you learn later keep their place free.
  - "Leisten einrichten" sets up your bars (out of combat, after confirmation), "Rückgängig" restores them. Macros are never touched – a macro for a planned spell is used. Unplanned class spells leave your bars and are listed for experimenting.
  - Talent tree with suggested order and the next point highlighted; next trainer visit, stat priority, one short tip.
- New for all classes: newly learned ranks replace the previous highest rank on all bars automatically (after combat; macros and lower ranks stay; can be switched off).
- New: `/trip bug` – ready-to-copy bug report (no names). Paste it into the comments.
- Optional: "Zauberdaten teilen" sends your spells and talents (no names) to the Guild Trip developer in your guild to help build guides for more classes.
- Smaller saved-data file; `/trip help` only shows player commands.

⚠️ Interface currently German only – English is coming with 0.6.0.

**Deutsch**
- Neuer Reiter „Klasse“ – Klassen-Ratgeber, zuerst Priester:
  - Vorschlag für die Aktionsleisten: Leiste 1 Kampf (Tasten 1–8), Leiste 2 Notfall & Heilung, Leiste 3 Hilfe. Feste Plätze; später gelernte Zauber halten ihren Platz frei.
  - „Leisten einrichten“ richtet die Leisten ein (außerhalb des Kampfes, nach Rückfrage), „Rückgängig“ holt die alte Belegung zurück. Makros werden nie angerührt – ein Makro für einen eingeplanten Zauber wird genutzt. Nicht eingeplante Klassenzauber kommen von den Leisten und stehen zum Ausprobieren auf der Seite.
  - Talentbaum mit vorgeschlagener Reihenfolge und markiertem nächsten Punkt; nächster Lehrerbesuch, Werte-Reihenfolge, ein kurzer Tipp.
- Neu für alle Klassen: Neu gelernte Ränge ersetzen auf allen Leisten automatisch den bisher höchsten Rang (nach dem Kampf; Makros und niedrigere Ränge bleiben; abschaltbar).
- Neu: `/trip bug` – fertiger Fehlerbericht zum Kopieren (ohne Namen). Einfach in die Kommentare einfügen.
- Freiwillig: „Zauberdaten teilen“ schickt deine Zauber und Talente (ohne Namen) an den Guild-Trip-Entwickler deiner Gilde, damit Ratgeber für weitere Klassen entstehen.
- Kleinere Speicherdatei; `/trip hilfe` zeigt nur noch Spielerbefehle.
```

---

## 0.5.2-alpha (Paket gebaut: dist/GuildTrip_0.5.2-alpha_CurseForge.zip)

```
## 0.5.2-alpha

**English**
- Choices are now real dropdown menus: profession filter, trainer type, group role and arrow style.
- On/off settings are now checkboxes: share recipes, share progress, group notifications, lock arrow, golden player arrow.

⚠️ Interface currently German only.

**Deutsch**
- Auswahlen sind jetzt echte Dropdown-Menüs: Beruf-Filter, Lehrer-Art, Gruppenrolle und Pfeil-Aussehen.
- An/Aus-Einstellungen sind jetzt Häkchen: Rezepte teilen, Fortschritt teilen, Gruppen-Hinweise, Pfeil festsetzen, goldener Spielerpfeil.
```

---

## 0.5.1-alpha (erste öffentliche Datei)

```
## 0.5.1-alpha – First public alpha

⚠️ Interface currently German only.

**English**
- Calendar as a month sheet with calendar weeks, world events, guild events and reminders
- Guild: member list, guild map, guide arrow to members (opt-in)
- Dungeons: all Forever dungeons with quests, prerequisites, class quests and a guild-only group finder
- Professions: guild recipe search, ask crafters, trainer directory

Command: /trip – bugs and feature requests welcome in the comments!

**Deutsch**
- Kalender als Monatsblatt mit Kalenderwochen, WoW-Events, Gildenterminen und Erinnerungen
- Gilde: Mitgliederliste, Gildenkarte, Navi-Pfeil zu Mitgliedern (nur mit Freigabe)
- Dungeons: alle Forever-Dungeons mit Quests, Vorquests, Klassenquests und gildeninternem Gruppenfinder
- Berufe: Rezeptsuche in der Gilde, Handwerker anfragen, Lehrer-Verzeichnis

Befehl: /trip – Fehler und Wünsche gern in die Kommentare!
```
