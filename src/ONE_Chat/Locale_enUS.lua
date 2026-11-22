local _ = ...
local ONE = _G.ProjectONE
if not (ONE and ONE.EN) then return end

-- Englische Texte fuer den Guild-Trip-Chat.
local EN = ONE.EN
EN["Chat"] = "Chat"
EN["In diesem Reiter kann man nicht schreiben."] = EN["In diesem Reiter kann man nicht schreiben."] or "You can't write in this tab."
EN["Du bist in keiner Gruppe."] = EN["Du bist in keiner Gruppe."] or "You're not in a group."
EN["Du bist nicht im Kanal %s."] = EN["Du bist nicht im Kanal %s."] or "You're not in the %s channel."
EN["Befehle gehen hier nicht – bitte im WoW-Chat."] = EN["Befehle gehen hier nicht – bitte im WoW-Chat."] or "Commands don't work here – please use the WoW chat."
EN["Senden geht in diesem Client nicht."] = EN["Senden geht in diesem Client nicht."] or "Sending isn't possible in this client."
EN["Senden ging nicht."] = EN["Senden ging nicht."] or "Sending failed."
EN["%s ist nicht in deiner Battle.net-Freundesliste."] = EN["%s ist nicht in deiner Battle.net-Freundesliste."] or "%s is not on your Battle.net friends list."
EN["Umschalt+Klick: Name einfügen (z. B. Gildeneinladung)"] = EN["Umschalt+Klick: Name einfügen (z. B. Gildeneinladung)"] or "Shift-click: insert name (e.g. guild invite)"
EN["Klick: Namens-Menü"] = EN["Klick: Namens-Menü"] or "Click: name menu"
EN["An %s"] = EN["An %s"] or "To %s"
EN["Guild Trip Chat"] = EN["Guild Trip Chat"] or "Guild Trip Chat"
EN["Menü"] = EN["Menü"] or "Menu"
EN["Reiter"] = EN["Reiter"] or "Tabs"
EN["nur lesen"] = EN["nur lesen"] or "read only"
EN["An: %s"] = EN["An: %s"] or "To: %s"
EN["Neue Flüsternachricht von %s"] = EN["Neue Flüsternachricht von %s"] or "New whisper from %s"
EN["Flüstern: %s"] = EN["Flüstern: %s"] or "Whisper: %s"
EN["Name"] = EN["Name"] or "Name"
EN["Was hinein soll"] = EN["Was hinein soll"] or "What goes in"
EN["Schreiben in"] = EN["Schreiben in"] or "Write to"
EN["Speichern"] = EN["Speichern"] or "Save"
EN["Gib dem Reiter einen Namen."] = EN["Gib dem Reiter einen Namen."] or "Give the tab a name."
EN["Löschen"] = EN["Löschen"] or "Delete"
EN["Reiter ändern"] = EN["Reiter ändern"] or "Edit tab"
EN["Neuer Reiter"] = EN["Neuer Reiter"] or "New tab"
EN["Guild-Trip-Chat öffnen/schließen"] = EN["Guild-Trip-Chat öffnen/schließen"] or "Open/close the Guild Trip chat"
EN["Gilde"] = EN["Gilde"] or "Guild"
EN["Offiziere"] = EN["Offiziere"] or "Officers"
EN["Gruppe"] = EN["Gruppe"] or "Group"
EN["Sagen"] = EN["Sagen"] or "Say"
EN["Schreien"] = EN["Schreien"] or "Yell"
EN["Emotes"] = EN["Emotes"] or "Emotes"
EN["Handel"] = EN["Handel"] or "Trade"
EN["Allgemein"] = EN["Allgemein"] or "General"
EN["Gruppensuche"] = EN["Gruppensuche"] or "Looking for group"
EN["Andere Kanäle"] = EN["Andere Kanäle"] or "Other channels"
EN["Flüstern"] = EN["Flüstern"] or "Whisper"
EN["System"] = EN["System"] or "System"
EN["Alle"] = EN["Alle"] or "All"
EN["In der Nähe"] = EN["In der Nähe"] or "Nearby"
EN["Guild-Trip-Chat öffnen"] = EN["Guild-Trip-Chat öffnen"] or "Open Guild Trip chat"
EN["Beim Einloggen öffnen"] = EN["Beim Einloggen öffnen"] or "Open at login"
EN["Flüstern im Guild-Trip-Chat öffnen"] = EN["Flüstern im Guild-Trip-Chat öffnen"] or "Open whispers in the Guild Trip chat"
EN["„Flüstern“ im Namens-Menü öffnet das Gespräch im Guild-Trip-Chat statt im WoW-Chat."] = EN["„Flüstern“ im Namens-Menü öffnet das Gespräch im Guild-Trip-Chat statt im WoW-Chat."] or "\"Whisper\" in the name menu opens the conversation in the Guild Trip chat instead of the WoW chat."
EN["Uhrzeit vor jeder Nachricht"] = EN["Uhrzeit vor jeder Nachricht"] or "Time before each message"
EN["Neue Nachrichten blinken"] = EN["Neue Nachrichten blinken"] or "Flash new messages"
EN["Gespräche mit ungelesenen Nachrichten blinken; bei Flüstern blinkt auch das WoW-Symbol in der Taskleiste."] = EN["Gespräche mit ungelesenen Nachrichten blinken; bei Flüstern blinkt auch das WoW-Symbol in der Taskleiste."] or "Conversations with unread messages flash; for whispers the WoW icon in the taskbar flashes too."
EN["Ton bei Flüsternachrichten"] = EN["Ton bei Flüsternachrichten"] or "Sound for whispers"
EN["Schriftgröße"] = EN["Schriftgröße"] or "Font size"
EN["Ton bei Gildennachrichten"] = "Sound for guild messages"
EN["Ton bei Gruppennachrichten"] = "Sound for group messages"
EN["Ton beim Senden"] = "Sound when sending"
EN["Leises „Pling“, höchstens alle paar Sekunden einmal."] = "A quiet \"ping\", at most once every few seconds."
EN["Chat-Einstellungen"] = "Chat settings"
EN["Nur, wenn das Gespräch gerade nicht offen ist."] = "Only when the conversation isn't open right now."
EN["Leises „Pling“, höchstens alle paar Sekunden einmal – nur, wenn die Gilde gerade nicht offen ist."] = "A quiet \"ping\", at most once every few seconds – only when the guild isn't open right now."
EN["Leises „Pling“, höchstens alle paar Sekunden einmal – nur, wenn die Gruppe gerade nicht offen ist."] = "A quiet \"ping\", at most once every few seconds – only when the group isn't open right now."
EN["Schlichtes Aussehen (passend zu ElvUI & Co.)"] = "Plain look (fits ElvUI and similar)"
EN["Flach und dunkel mit dünnem Rand statt Blizzard-Rahmen bzw. Pergament. Wirkt nach /reload."] = "Flat and dark with a thin border instead of the Blizzard frame or parchment. Takes effect after /reload."
EN["Das Aussehen des Chats ändert sich nach /reload."] = "The chat's look changes after /reload."
EN["%s erkannt:"] = "%s detected:"
EN["Töne ggf. dort oder hier abschalten, sonst klingt es doppelt. „WoW-Chat ausblenden“ bleibt gesperrt."] = "Turn sounds off there or here, otherwise you'll hear them twice. \"Hide WoW chat\" stays locked."
EN["%s verwaltet den WoW-Chat – Ausblenden ist deshalb gesperrt."] = "%s manages the WoW chat – hiding it is locked."
-- Chat-Knopf (15.11.2026)
EN["Chat-Knopf am WoW-Chat"] = EN["Chat-Knopf am WoW-Chat"] or "Chat button on the WoW chat"
EN["Kleine Sprechblase oben am WoW-Chat mit Zähler für ungelesene Flüsternachrichten. Umschalt+Ziehen verschiebt sie."] = "Small speech bubble above the WoW chat with a counter for unread whispers. Shift+drag moves it."
EN["%d ungelesene Flüsternachrichten"] = EN["%d ungelesene Flüsternachrichten"] or "%d unread whispers"
EN["Klick: öffnen/schließen"] = EN["Klick: öffnen/schließen"] or "Click: open/close"
EN["Umschalt+Ziehen: verschieben"] = EN["Umschalt+Ziehen: verschieben"] or "Shift+drag: move"
EN["Guild-Trip-Chat"] = EN["Guild-Trip-Chat"] or "Guild Trip chat"
-- Chat-Einstellungen Stufe 2 (16.11.2026)
EN["Verhalten & Töne"] = EN["Verhalten & Töne"] or "Behaviour & sounds"
EN["Aussehen"] = EN["Aussehen"] or "Appearance"
EN["Alte Zeilen verblassen"] = EN["Alte Zeilen verblassen"] or "Fade old lines"
EN["Wie im WoW-Chat: Zeilen verschwinden nach einer Minute. Mausrad holt sie zurück."] = "Like the WoW chat: lines disappear after a minute. The mouse wheel brings them back."
EN["Fenster festsetzen"] = EN["Fenster festsetzen"] or "Lock window"
EN["Nicht mehr verschieben oder in der Größe ändern."] = "No more moving or resizing."
EN["Zeilenabstand"] = EN["Zeilenabstand"] or "Line spacing"
EN["eng"] = EN["eng"] or "tight"
EN["normal"] = EN["normal"] or "normal"
EN["weit"] = EN["weit"] or "wide"
EN["sehr weit"] = EN["sehr weit"] or "very wide"
EN["Hintergrund"] = EN["Hintergrund"] or "Background"
EN["Ohne Maus"] = EN["Ohne Maus"] or "Without mouse"
EN["immer sichtbar"] = EN["immer sichtbar"] or "always visible"
EN["auf %d %% ausblenden"] = EN["auf %d %% ausblenden"] or "fade to %d %%"
EN["Nachricht schreiben …"] = "Write a message …"
EN["Noch keine Nachrichten."] = "No messages yet."
EN["Noch keine Nachrichten – schreib unten los."] = "No messages yet – start typing below."
-- WoW-Chat ersetzen (17.11.2026)
EN["WoW-Chat durch diesen ersetzen"] = "Replace the WoW chat with this one"
EN["Blendet das WoW-Chatfenster aus; Enter und / öffnen dann dieses Fenster. Nicht angezeigt werden dabei u. a. Beute, Erfahrung und das Kampflog. Jederzeit zurück: Haken raus oder /trip wowchat. Gesperrt bei ElvUI & Co."] = "Hides the WoW chat window; Enter and / then open this window. Not shown here: loot, experience and the combat log, among others. Back any time: uncheck or /trip wowchat. Locked with ElvUI & co."
EN["WoW-Chat ist ausgeblendet. /trip wowchat bringt ihn zurück."] = "The WoW chat is hidden. /trip wowchat brings it back."
EN["WoW-Chat ist wieder da."] = "The WoW chat is back."
EN["WoW-Chat aus-/einblenden"] = "Hide/show the WoW chat"
-- Beute-Fenster (17.11.2026)
EN["Grau"] = EN["Grau"] or "Poor" EN["Weiß"] = EN["Weiß"] or "Common" EN["Grün"] = EN["Grün"] or "Uncommon"
EN["Blau"] = EN["Blau"] or "Rare" EN["Episch"] = EN["Episch"] or "Epic" EN["Legendär"] = EN["Legendär"] or "Legendary"
EN["Du"] = EN["Du"] or "You"
EN["%d Gegenstände"] = "%d items"
EN["Beute"] = EN["Beute"] or "Loot"
EN["Leeren"] = EN["Leeren"] or "Clear"
EN["ab %s"] = "from %s"
EN["Noch keine Beute in dieser Sitzung."] = "No loot yet this session."
EN["Beute-Fenster"] = "Loot window"
EN["Wer hat welchen Gegenstand bekommen"] = "Who got which item"
EN["Beute-Fenster öffnen/schließen"] = "Open/close the loot window"
-- 0.6.8: Blizzard-Aussehen des Chats
EN["Guild Trip · Chat"] = "Guild Trip · Chat"
EN["Senden"] = "Send"
EN["Kanäle"] = "Channels"
EN["offline"] = "offline"
EN["Du an %s"] = "You to %s"
EN["%d von %d online"] = "%d of %d online"
EN["Nachricht an %s …"] = "Message to %s …"
EN["Hier kann man nur lesen."] = "Read only here."
EN["Diese Sitzung"] = "This session"
-- Verlauf ueber Neustart (19.11.2026)
EN["Verlauf nach Neustart behalten"] = "Keep history after restart"
EN["Die letzten 100 Nachrichten je Reiter und 50 je Flüstergespräch (höchstens 10 Gespräche, nicht älter als 7 Tage) bleiben nach /reload und Neueinloggen erhalten – je Charakter, nur auf diesem PC. Ausschalten löscht den gespeicherten Verlauf beim nächsten Ausloggen."] = "The last 100 messages per tab and 50 per whisper conversation (at most 10 conversations, no older than 7 days) stay after /reload and logging in again – per character, only on this PC. Switching it off deletes the saved history at your next logout."
-- Schmales Chatfenster + eigenes Aussehen (19.11.2026)
EN["%d ungelesen"] = "%d unread"
EN["Rechtsklick: Reiter bearbeiten"] = "Right-click: edit tab"
EN["Rechtsklick: Menü · Umschalt+Klick: schließen"] = "Right-click: menu · Shift-click: close"
EN["Flüstern an …"] = "Whisper to …"
EN["Neues Gespräch: Name eingeben"] = "New conversation: enter a name"
EN["Wie das Hauptfenster"] = "Same as main window"
EN["Glas"] = EN["Glas"] or "Glass"
EN["Schlicht (passend zu ElvUI & Co.)"] = "Plain (matches ElvUI & co.)"
EN["Aussehen des Chats"] = "Chat look"
EN["Nur für das Chatfenster. Wirkt nach /reload."] = "Only for the chat window. Takes effect after /reload."
EN["Glas-Farben des Chats"] = "Chat glass colours"
EN["Leuchtfarbe des Chats …"] = "Chat glow colour …"
EN["Farbe für Auswahl, Linien und Knöpfe – nur im Chat."] = "Colour for selection, lines and buttons – chat only."
EN["Glasfarbe des Chats …"] = "Chat glass tint …"
EN["Tönung des Chat-Glases. Die Deckkraft stellt „Hintergrund“ ein."] = "Tint of the chat glass. Opacity is set with “Background”."
EN["Chat-Aussehen prüfen (für Fehlersuche)"] = "Check chat look (for troubleshooting)"
EN["Gespräch schließen"] = "Close conversation"

-- Messenger-Stil, Emojis, Einstellungen im Chat (21.11.2026)
-- Blasenfarben (22.11.2026)
EN["Stärke der Blasenfarbe"] = "Bubble colour strength"
EN["Wie deutlich die Sprechblasen gefärbt sind."] = "How strongly the speech bubbles are tinted."
EN["dezent"] = EN["dezent"] or "subtle"
EN["kräftig"] = EN["kräftig"] or "strong"
EN["sehr kräftig"] = EN["sehr kräftig"] or "very strong"
EN["Farbe meiner Blasen …"] = "Colour of my bubbles …"
EN["Farbe deiner eigenen Sprechblasen. Ohne Auswahl: die Leuchtfarbe des Chats."] = "Colour of your own speech bubbles. If not set: the chat's glow colour."
EN["Textfarbe in den Blasen …"] = "Text colour in bubbles …"
EN["Farbe der Nachrichten in den Sprechblasen. Ohne Auswahl: weiß."] = "Colour of the messages in the speech bubbles. If not set: white."
EN["Blasenfarben zurücksetzen"] = "Reset bubble colours"
EN["Eigene Blasenfarbe, Textfarbe und Stärke wieder wie am Anfang."] = "Own bubble colour, text colour and strength back to default."
-- Sprung zum WoW-Chat (22.11.2026)
EN["Zum WoW-Chat"] = "To WoW chat"
EN["Schließt diesen Chat und zeigt den WoW-Chat. Zurück: Sprechblase am WoW-Chat."] = "Closes this chat and shows the WoW chat. Back: speech bubble at the WoW chat."
EN["Knopf „Zum WoW-Chat“"] = "“To WoW chat” button"
EN["Kleiner Knopf oben im Chat: schließt diesen Chat und zeigt den WoW-Chat – auch wenn er ersetzt ist (nur vorübergehend). Zurück über die Sprechblase am WoW-Chat."] = "Small button at the top of the chat: closes this chat and shows the WoW chat – even if it is replaced (only temporarily). Back via the speech bubble at the WoW chat."
EN["Im Kampf geht das nicht – der WoW-Chat kommt gleich nach dem Kampf."] = "Not possible in combat – the WoW chat appears right after combat."
-- Sicherer Einlade-Knopf (22.11.2026)
EN["In die Gilde einladen"] = EN["In die Gilde einladen"] or "Invite to guild"
EN["Lädt %s in deine Gilde ein."] = "Invites %s to your guild."
-- Alle WoW-Chatfunktionen im Messenger (22.11.2026)
EN["Emote ging nicht."] = "Emote failed."
EN["Abwesend"] = EN["Abwesend"] or "Away"
EN["Nicht stören"] = EN["Nicht stören"] or "Do not disturb"
EN["NPC-Gespräche"] = "NPC speech"
EN["Beute & Fortschritt"] = "Loot & progress"
-- Links oeffnen (22.11.2026)
EN["Der Link ließ sich nicht öffnen (%s)."] = "The link could not be opened (%s)."
EN["Berufs-Link"] = "Profession link"
EN["Klick: bekannte Rezepte zeigen und anflüstern"] = "Click: show known recipes and whisper"
EN["Noch keine Rezepte bekannt."] = "No recipes known yet."
EN["Forever zeigt fremde Berufsfenster nicht – frag einfach nach."] = "Forever does not show other players' profession windows – just ask."
EN["… und %d weitere"] = "… and %d more"
EN["Anflüstern"] = EN["Anflüstern"] or "Whisper"
EN["Hi, kannst du mir mit %s helfen?"] = "Hi, could you help me with %s?"
EN["Öffnen: %s"] = "Open: %s"
-- Antworten mit Zitat (22.11.2026)
EN["Antwort an %s"] = "Reply to %s"
EN["Antwort abbrechen"] = "Cancel reply"
local function Add(de, en) EN[de] = EN[de] or en end
for de, en in pairs({
    ["offline seit %d Jahren"] = "offline for %d years", ["offline seit 1 Monat"] = "offline for 1 month",
    ["offline seit %d Monaten"] = "offline for %d months", ["offline seit 1 Tag"] = "offline for 1 day",
    ["offline seit %d Tagen"] = "offline for %d days", ["offline seit 1 Std."] = "offline for 1 hr",
    ["offline seit %d Std."] = "offline for %d hrs", ["gerade offline"] = "just went offline", ["Gestern"] = "Yesterday",
    ["Heute"] = "Today", ["Du"] = "You",
    ["Suchen …"] = "Search …", ["Neues Gespräch"] = "New conversation",
    ["Flüstern an jemanden oder eigenen Reiter anlegen"] = "Whisper someone or create your own tab",
    ["Neuer Reiter …"] = "New tab …", ["NACHRICHTEN"] = "MESSAGES", ["Nichts gefunden"] = "Nothing found",
    ["ANGEHEFTET"] = "PINNED", ["GESPRÄCHE"] = "CONVERSATIONS", ["FLÜSTERN"] = "WHISPERS", ["SYSTEM"] = "SYSTEM", ["Entwurf:"] = "Draft:", ["stumm"] = "muted",
    ["stummgeschaltet: kein Ton, grauer Zähler"] = "muted: no sound, grey counter",
    ["Rechtsklick: Anheften, Stumm, …"] = "Right-click: pin, mute, …", ["Lösen"] = "Unpin", ["Anheften"] = "Pin",
    ["Ton an"] = "Unmute", ["Stummschalten"] = "Mute", ["Als gelesen markieren"] = "Mark as read",
    ["Namens-Menü …"] = "Name menu …", ["Reiter bearbeiten …"] = "Edit tab …", ["Zurück zur Liste"] = "Back to the list",
    ["Namens-Menü"] = "Name menu", ["Einladen, Navi, Ignorieren …"] = "Invite, navigate, ignore …", ["Nach unten"] = "Scroll down",
    ["Emojis und WoW-Zeichen"] = "Emojis and WoW markers",
    ["Emojis sehen nur Spieler mit Guild Trip als Bild, andere lesen den Code (z. B. :daumen:). WoW-Zeichen wie {Stern} sieht jeder."] =
        "Only players with Guild Trip see emojis as pictures, others read the code (e.g. :thumbsup:). Everyone sees WoW markers like {star}.",
    ["(sieht jeder)"] = "(everyone sees it)", ["WoW-Zeichen sieht jeder – auch ohne Guild Trip."] = "Everyone sees WoW markers – even without Guild Trip.",
    ["Emojis: Bild nur mit Guild Trip, sonst steht der Code da."] = "Emojis: picture only with Guild Trip, otherwise the code shows.",
    ["Antworten"] = "Reply", ["Text kopieren"] = "Copy text",
    ["Text steht im Eingabefeld und ist markiert – Strg+C kopiert ihn."] = "The text is in the input field and selected – Ctrl+C copies it.",
    ["1 neue Nachricht"] = "1 new message", ["%d neue Nachrichten"] = "%d new messages",
    ["nicht zugestellt – %s ist offline"] = "not delivered – %s is offline", ["Meldungen von WoW und Addons"] = "Messages from WoW and addons",
    ["schreibt in: %s"] = "writes to: %s", ["Name eingeben, Enter"] = "Type a name, Enter",
    ["Zuletzt"] = "Recent", ["Gesichter"] = "Faces", ["Gesten"] = "Gestures", ["Herzen"] = "Hearts", ["WoW"] = "WoW", ["Zeichen"] = "Markers",
    ["Messenger"] = "Messenger", ["Klassisch"] = "Classic", ["Der Stil des Chats ändert sich nach /reload."] = "The chat style changes after /reload.",
    ["Fertig"] = "Done", ["Geändert: wirkt nach dem Neuladen."] = "Changed: takes effect after reloading.", ["Jetzt neu laden"] = "Reload now",
    ["Linksklick: weiter · Rechtsklick: zurück"] = "Left-click: next · Right-click: back", ["Stil des Chats"] = "Chat style",
    ["Chat-Einstellungen öffnen"] = "Open chat settings",
    ["Messenger: Gesprächsliste und Sprechblasen. Klassisch: Reiter oben, Zeilen wie im WoW-Chat. Wirkt nach /reload."] =
        "Messenger: conversation list and speech bubbles. Classic: tabs on top, lines like the WoW chat. Takes effect after /reload.",
    ["Alle Einstellungen des Chats stehen jetzt direkt im Chatfenster (Zahnrad oben rechts)."] = "All chat settings are now right in the chat window (gear at the top right).",
    ["Stil"] = "Style", ["Emojis"] = "Emojis", ["System & Addons"] = "System & addons",
    ["Emojis als Bilder zeigen"] = "Show emojis as pictures",
    ["Codes wie :daumen: und WoW-Zeichen wie {Stern} erscheinen als Bild. Aus: der Text bleibt, wie er gesendet wurde."] =
        "Codes like :thumbsup: and WoW markers like {star} appear as pictures. Off: the text stays as it was sent.",
    ["Smileys wie :) als Bild"] = "Smileys like :) as pictures",
    ["Auch getippte Smileys (:) :D ;) <3 …) werden zum Bild – nur, wenn sie frei stehen."] = "Typed smileys (:) :D ;) <3 …) become pictures too – only when they stand alone.",
    ["Nur Emojis: groß zeigen"] = "Emojis only: show large",
    ["Blasen farbig je Art"] = "Tint bubbles by type",
    ["Klassen-Symbol vor dem Namen"] = "Class icon before the name",
    ["In den Sprechblasen ein kleines rundes Klassen-Symbol vor dem Namen – wenn WoW die Klasse kennt."] = "A small round class icon before the name in the bubbles – when WoW knows the class.",
    ["Sprechblasen der anderen leicht in der Farbe ihrer Art: Gilde grün, Gruppe blau, Flüstern rosa … Eigene bleiben in der Leuchtfarbe."] = "Other people's bubbles get a light tint of their type: guild green, party blue, whisper pink … Your own keep the glow colour.",
    ["Besteht eine Nachricht nur aus 1–3 Emojis, werden sie groß und ohne Blase gezeigt – wie im Messenger."] = "If a message is just 1–3 emojis, they are shown large without a bubble – like in a messenger.",
    -- Emoji-Namen
    ["Lächeln"] = "Smile", ["Freude"] = "Joy", ["Lachen"] = "Laugh", ["Grinsen"] = "Grin", ["Tränen lachen"] = "Tears of joy",
    ["Kugeln vor Lachen"] = "Rolling on the floor", ["Zwinkern"] = "Wink", ["Puh"] = "Phew", ["Verliebt"] = "In love", ["Kuss"] = "Kiss",
    ["Zunge"] = "Tongue", ["Cool"] = "Cool", ["Hmm"] = "Hmm", ["Augenrollen"] = "Eye roll", ["Staunen"] = "Surprised", ["Schreck"] = "Scream",
    ["Traurig"] = "Sad", ["Weinen"] = "Crying", ["Wütend"] = "Angry", ["Schlafen"] = "Sleeping", ["Party"] = "Party", ["Froh"] = "Happy",
    ["Daumen hoch"] = "Thumbs up", ["Daumen runter"] = "Thumbs down", ["Winken"] = "Wave", ["Klatschen"] = "Clap", ["Jubel"] = "Cheer",
    ["Bitte / Danke"] = "Please / thanks", ["Stark"] = "Strong", ["Okay"] = "Okay", ["Peace"] = "Peace", ["Abgemacht"] = "Deal",
    ["Daumen drücken"] = "Fingers crossed", ["Augen"] = "Eyes", ["Herz"] = "Heart", ["Herz orange"] = "Orange heart",
    ["Herz gelb"] = "Yellow heart", ["Herz grün"] = "Green heart", ["Herz blau"] = "Blue heart", ["Herz lila"] = "Purple heart",
    ["Gebrochenes Herz"] = "Broken heart", ["Schwerter"] = "Swords", ["Schild"] = "Shield", ["Totenkopf"] = "Skull", ["Feuer"] = "Fire",
    ["Stern"] = "Star", ["Gold"] = "Gold", ["Münze"] = "Coin", ["Bier"] = "Beer", ["Konfetti"] = "Confetti", ["Geschenk"] = "Gift",
    ["Pokal"] = "Trophy", ["Drache"] = "Dragon", ["Magier"] = "Mage", ["Haken"] = "Check", ["Kreuz"] = "Cross", ["Hundert"] = "Hundred",
    ["Müde"] = "Tired", ["Warten"] = "Waiting", ["Kreis"] = "Circle", ["Diamant"] = "Diamond", ["Dreieck"] = "Triangle", ["Mond"] = "Moon",
    ["Quadrat"] = "Square", ["Totenschädel"] = "Skull",
}) do Add(de, en) end
-- Beute-Aussehen (22.11.2026)
EN["Beute: Aussehen"] = "Loot: appearance"
EN["Überschriften"] = "Headings"
EN["Text"] = "Text"
EN["Aussehen"] = "Appearance"
