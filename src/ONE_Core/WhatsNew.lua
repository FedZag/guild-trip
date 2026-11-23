-- Guild Trip: "Neu in dieser Version" beim Einloggen (einmal je Version) + Hinweis aufs Teilen.
-- Guild Trip lebt davon, dass alle etwas teilen (Position, Rezepte, Quests, Funde). Standardmaessig ist alles aus –
-- darum zeigt dieses Fenster die Teilen-Haekchen gleich mit und bietet "Alles einschalten" an.
-- Ist nach dem Fenster noch etwas aus, kommt bei jedem Einloggen ein kurzer Chat-Hinweis (/trip teilen).
local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local WhatsNew = {}
ONE.WhatsNew = WhatsNew

-- Neuigkeiten je Version (kurz, fuer Spieler). Neue Versionen oben ergaenzen.
WhatsNew.notes = {
    ["0.8.3-alpha"] = {
        "Quest-Führung: Routen für alle 46 Volk-Klasse-Paare von Forever, auch Himmelsgeborene; Questziele dort, wo die Gegner stehen",
        "Quests mit Zeitlimit: Restzeit im Kasten, Annehmen erst kurz vor dem Losgehen",
        "Kasten: Quests in derselben Gegend gemeinsam unter JETZT; Hinweis auf früher ausgelassene Quests am Weg und auf fehlende Questdaten",
        "Navi: rechnet alle 3 s neu und nimmt den kürzeren Weg; Fußspuren ohne gelbe Kreise",
        "Chat: Freundesliste mit Rechtsklick-Menü, Befehlsliste beim Tippen von /, letzte Eingaben mit Pfeiltasten, Quests per Umschalt+Klick in den Chat",
    },
    ["0.8.2-alpha"] = {
        "Quest-Führung: alle Routen neu geordnet – rund 15 % schneller bis 60, kaum noch Hin und Zurück",
        "Navi: steigt mitten auf Wegen ein und aus statt nur an festen Punkten",
        "Quest-Kasten: Quests außerhalb des Plans stehen unten in einem eigenen Abschnitt",
        "Taschen fast voll: Händler mit dem kleinsten Umweg zum nächsten Schritt",
        "Hinweis, wenn ein Geber für eine Dungeon-Quest direkt am Weg liegt",
    },
    -- Schnell-Fix nach 0.8.0: wer von 0.7.9 kommt, soll die Neuerungen von 0.8.0 trotzdem sehen
    ["0.8.1-alpha"] = {
        "Optionen: Suchfeld über allen Einstellungen, Minimap-Knopf als Schalter, alle Klänge an einem Ort",
        "Questlog: EP je Quest und Anteil an der Stufe; Erholt-EP in der Kopfzeile von Leveln",
        "Verkaufspreis im Gegenstands-Tooltip; Meine Figuren (Startseite): Gold, Stufe, Erholt und wer was in Tasche und Bank hat",
        "Navi: Lehrer mit Suchfeld, Koordinaten auf der Weltkarte, Restzeit im Flug",
        "Optionen › Allgemein › Anfragen (aus): Duelle und Einladungen von Fremden ablehnen, Wiederbelebung und Beschwörung annehmen",
        "Fix: Der Flug-Balken verschwindet nach der Landung von selbst",
    },
    ["0.8.0-alpha"] = {
        "Optionen: Suchfeld über allen Einstellungen, Minimap-Knopf als Schalter, alle Klänge an einem Ort",
        "Questlog: EP je Quest und Anteil an der Stufe; Erholt-EP in der Kopfzeile von Leveln",
        "Verkaufspreis im Gegenstands-Tooltip; Meine Figuren (Startseite): Gold, Stufe, Erholt und wer was in Tasche und Bank hat",
        "Navi: Lehrer mit Suchfeld, Koordinaten auf der Weltkarte, Restzeit im Flug",
        "Optionen › Allgemein › Anfragen (aus): Duelle und Einladungen von Fremden ablehnen, Wiederbelebung und Beschwörung annehmen",
    },
    ["0.7.9-alpha"] = {
        "Navi: Wege bevorzugen Straßen und gehen um Berge herum; richtiger Zeppelin oder richtiges Schiff zum anderen Kontinent",
        "Quest-Führung: eine feste, schnellste Route; Ziele nach dem, was noch offen ist",
        "Quest-Kasten: „Nicht im Plan“ als Abstecher mit Rückfrage",
        "Ausrüstung: nur Passendes für Klasse, Volk und Beruf; leere Plätze zeigen, was bald kommt",
    },
    ["0.7.8-alpha"] = {
        "Optionen › Grafik: versteckte Grafik-Einstellungen (Gras, Zoom, Wetter, Licht, Wasser, FPS) mit Vorlagen",
        "Chat: Antworten mit Zitat (Doppelklick auf eine Blase), fehlende WoW-Chatmeldungen im Guild-Trip-Chat",
        "Ausrüstung: Klick führt zum richtigen Ziel, „Anfragen“ bei Herstellern, die online sind; Ausrüstungs-Quests in der Route",
        "Lehrer: Unterkategorien, Ortsnamen, neutrale Lehrer markiert",
        "Keine abgeschnittenen Texte mehr – voller Text im Tooltip",
        "Schwebende Fenster: Zahnrad nur beim Drüberfahren, Rechtsklick öffnet die Einstellungen",
    },
    ["0.7.7-alpha"] = {
        "Chat: Knopf „Zum WoW-Chat“, zurück über die Sprechblase",
        "Quest-Kasten: NPC-Name bei mehreren Quests vorn, Questnamen in ihrer Farbe",
    },
    ["0.7.6-alpha"] = {
        "Quest-Führung mit festen Routen je Volk und Klasse – ein Gebiet nach dem anderen, Ziele zusammengefasst",
        "Quest-Kasten: Zahnrad öffnet eigenes Aussehen (WoW-Look, Kompakt, Minimal, Farben, Hintergrund)",
        "Ankunftsklang je Ziel-Art; eigene Questklänge wahlweise (Standard aus)",
        "Chat: mehr Farbvorlagen, eigene Blasen- und Textfarbe",
        "Fußspuren der Navi sind wieder da",
    },
    ["0.7.5-alpha"] = {
        "Chat: Battle.net-Nachrichten kommen an – Flüstern von Battle.net-Freunden mit eigenem Gespräch, antworten direkt dort",
        "Quest-Führung springt unterwegs nicht mehr um und nimmt nur Kurzes am Weg mit",
    },
    ["0.7.4-alpha"] = {
        "Neuer Chat im Messenger-Stil: Gesprächsliste, Sprechblasen, Emojis, Haken bei zugestelltem Flüstern; Einstellungen im Chat (Zahnrad)",
        "Quest-Führung plant wie eine Leveling-Route: Schleifen um Stützpunkte, fester Fahrplan, Lehrer, Flugpunkte, Ruhestein, Reisezauber",
        "Rechtsklick auf eine Quest im Kasten wählt sie ab; Weg querfeldein geradeaus (in Städten nicht)",
        "Klassen nach den Forever-Hotfixes aktualisiert; Arkan-Magier neu mit Ablauf je Stufe ab Stufe 1",
        "„Zauberdaten teilen“ bleibt angehakt; Schrott verkaufen geht wieder",
    },
    ["0.7.3-alpha"] = {
        "Dungeons: „Bosse & Beute“ – jeder Boss mit seiner Beute (Forever-Dungeons und alle klassischen), Umschalt+Klick verlinkt",
        "Chat lässt sich viel schmaler ziehen: Reiter oben, Flüstern links als Wappen; eigenes Aussehen unter Optionen › Chat",
        "ESC schließt den Chat nicht mehr; Dungeon-Quests zeigen die echte Quest-Stufe",
        "Quest-Führung: im Zielgebiet zeigt der Pfeil zum nächsten Fundort",
        "„Leisten automatisch aktuell halten“ ist jetzt standardmäßig aus (Optionen › Klasse)",
    },
    ["0.7.2-alpha"] = {
        "Raid-Skillungen für alle 27 Ausrichtungen (vorläufig bis 9.12.) und ab Stufe 60 „Raid-Vorbereitung“ unter Leveln › Ausrüstung",
        "Navi-Pfeil folgt echten Wegen auch zu Quest-Zielgebieten und sagt, wie viel Fliegen spart",
        "Chat behält seinen Verlauf nach /reload; Glas-Aussehen fertig (Häkchen, Regler, Auswahlfelder, runde Symbole)",
        "Für Buffs bedanken per WoW-Emote (Optionen › Klasse); Berufs-Links aus dem Chat merken (Optionen › Berufe, aus)",
        "Weniger Speicher; Quest-EP und Dungeon-Gegner werden still mitgeschrieben (/trip epdaten, /trip dungeondaten)",
    },
    ["0.7.1-alpha"] = {
        "Neues Aussehen „Glas“: durchsichtig, drei Spalten, runde leuchtende Symbole – Farben unter Optionen › Darstellung (Blizzard-Look bleibt wählbar)",
        "Kasten der Quest-Führung neu: Gebietszeile, „Jetzt“ groß mit Ort, Entfernung und Zeit, „Als Nächstes“ mit drei Schritten; plant mit Flugrouten",
        "Leveln › Ausrüstung und Tagebuch mit Steckbrief",
        "Buffen in der Nähe ohne Strg+V, nur Spieler in Reichweite, Klick bufft zuverlässig",
        "Hauptfenster, Chat und Kasten an jeder Kante ziehbar; schärfere Schrift",
    },
    ["0.7.0-alpha"] = {
        "Spieler in der Nähe buffen: Liste aller Spieler in Reichweite, ein Klick wirkt den Buff im passenden Rang",
        "Gilde: Questpartner in der Nähe, Hilferuf (/trip sos), Auftragsbrett (/trip auftrag), wer braucht die Beute?",
        "Quest-Führung: Gebiete am Stück, Ansicht „Gebiete“, Questgegner im Tooltip, Lager auf der Karte mit Farm-Runde",
        "Monster hauen nur, wenn es sich wirklich lohnt – mit Grund (neue Zauber, Quests, Dungeon)",
        "Dungeon-Rückblick mit Bestzeit im Gildenpass; Allianz voll unterstützt",
    },
    ["0.6.9-alpha"] = {
        "Neu: Quest-Führung für Twinks (Reiter „Leveln“) – nur Quests, die sich lohnen; Dungeon-, Klassen- und Vorquests immer",
        "Kasten „Quest-Führung“ unter der Minimap: Jetzt, Noch annehmen, Deine Quests – größer ziehen für mehr Schritte",
        "Alle Einstellungen an einem Ort: Optionen mit Bereichen je Modul",
        "Wahlweise: Quests automatisch annehmen/abgeben, reparieren, Schrott verkaufen (alles standardmäßig aus)",
        "Navi-Pfeil dreht sich fließend; 188 fehlende Begleit- und Erkundungsquests ergänzt",
    },
    ["0.6.8-alpha"] = {
        "Neuer Fensteraufbau im Blizzard-Stil: Bereiche links mit Goldsymbolen, Ansichten immer oben rechts",
        "Guild-Trip-Chat im Blizzard-Rahmen; Weg im Navi wahlweise als Fußspuren (Optionen › Spielhilfen › Navi)",
        "Questdatenbank aus QuestieDB (Forever): rund 4.900 Quests, auch neue Forever-Quests",
        "Alle Lehrer und Händler der Welt im Navi, alle Dungeon-Eingänge von Anfang an bekannt",
    },
    ["0.6.7-alpha"] = {
        "Echte Wegführung ohne Zusatz-Addon: Der Pfeil folgt Straßen und Pässen, goldene Punkte zeigen den Weg auf Minimap und Weltkarte",
        "Questdatenbank: „!“ auch bei Questgebern, bei denen du noch nie warst; Klick auf ? oder … in der Zielverfolgung startet das Navi",
        "Navi: Ankunft mit Ton, „hin und zurück“ bei Händler/Lehrer, Pfeil zur Leiche, eigene Wegpunkte (Umschalt+Klick, /way)",
        "Guild-Trip-Chat kann den WoW-Chat ersetzen (freiwillig), neues Beute-Fenster (/trip beute)",
        "Guild Trip ist jetzt freie Software (GNU GPL v3)",
    },
    ["0.6.6-alpha"] = {
        "Neuer Guild-Trip-Chat (freiwillig): Sprechblase am WoW-Chat, Reiter, Flüstern als eigene Gespräche",
        "Termine und Gildenausflüge planst und beantwortest du komplett in Guild Trip",
        "Klassen-Seite: Bewaffnung – welche Waffen du kannst und wo du sie lernst",
        "Klick auf einen Charakternamen öffnet ein Menü (Navi, Flüstern, Einladen …)",
        "Ausrüstung bewerten im Tooltip, Klassen-Ratgeber für Krieger, Paladin, Schamane nachgeschärft",
    },
}

local function Notes()
    return WhatsNew.notes[ONE.version]
end

-- Alle Teilen-Schalter, die gerade zu sehen sind
function WhatsNew:ShareOptions()
    local out = {}
    if not (ONE.UI and ONE.UI.shareOptions) then return out end
    for _, opt in ipairs(ONE.UI.shareOptions) do
        local on = (not opt.module or ONE:IsEnabled(opt.module)) and (not opt.visible or opt.visible())
        if on then out[#out + 1] = opt end
    end
    return out
end
function WhatsNew:SharesOff()
    local n = 0
    for _, opt in ipairs(self:ShareOptions()) do
        local ok, state = pcall(opt.get)
        if ok and not state then n = n + 1 end
    end
    return n
end

function WhatsNew:Build()
    if self.frame then return self.frame end
    local opts = self:ShareOptions()
    local notes = Notes() or {}
    local W = 560
    local noteH = 0
    local f = CreateFrame("Frame", "GuildTripWhatsNew", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", 0, 40)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(0.04, 0.08, 0.13, 1)
    local function Label(text, font, x, y, width, role)
        local fs = f:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        fs:SetWidth(width or W - 44)
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        fs:SetText(text)
        if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(fs, role or "text") end
        return fs
    end
    local title = Label("GUILD TRIP  |  " .. T("NEU IN %s", ONE.version or ""), "GameFontNormal", 22, -16, W - 70, "accent")
    ONE.Widgets:CloseButton(f, "TOPRIGHT", -6, -6, function() f:Hide() end)

    local y = -46
    for _, line in ipairs(notes) do
        local bullet = Label("•  " .. T(line), "GameFontHighlight", 26, y, W - 56)
        local h = bullet.GetStringHeight and bullet:GetStringHeight() or 18
        if type(h) ~= "number" or h < 16 then h = 18 end
        y = y - h - 6
    end
    f.checks = {}
    if #opts > 0 then
        y = y - 8
        Label(T("Teilen – damit alle etwas davon haben"), "GameFontNormal", 22, y, W - 44, "accent")
        y = y - 26
        local intro = Label(T("Guild Trip wird besser, wenn deine Gilde zusammenlegt: Ihr seht euch auf der Karte, wisst, wer welches Rezept kann, und die Funde (Lehrer, Händler, Questgeber) landen im Startpaket für alle. Es wird nichts gesendet, solange ein Häkchen fehlt."),
            "GameFontHighlightSmall", 22, y, W - 44, "soft")
        local h = intro.GetStringHeight and intro:GetStringHeight() or 44
        if type(h) ~= "number" or h < 20 then h = 44 end
        y = y - h - 10
        for _, opt in ipairs(opts) do
            f.checks[#f.checks + 1] = ONE.Kit:Check(f, {point = "TOPLEFT", x = 18, y = y, label = opt.label,
                tooltip = opt.tooltip and T(opt.tooltip), get = opt.get, set = opt.set})
            y = y - 26
        end
        y = y - 8
        f.all = ONE.Widgets:Button(f, T("Alles einschalten"), 190, 32, "TOPLEFT", 22, y, function()
            for _, o in ipairs(opts) do pcall(o.set, true) end
            for _, b in ipairs(f.checks) do if b.Refresh then b:Refresh() end end
            ONE:Print(T("Teilen ist an – danke! Du kannst es jederzeit unter Optionen › Teilen ändern."))
        end, "primary")
        ONE.Widgets:Button(f, T("Später"), 120, 32, "TOPLEFT", 226, y, function() f:Hide() end, "secondary")
        y = y - 42
    else
        ONE.Widgets:Button(f, T("Verstanden"), 140, 32, "TOPLEFT", 22, y - 6, function() f:Hide() end, "primary")
        y = y - 48
    end
    f:SetSize(W, -y + 14)
    if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripWhatsNew") end
    ONE.Themes:RegisterWindow(f, bg, title)
    if ONE.Themes.StyleTree then ONE.Themes:StyleTree(f) end
    f:Hide()
    self.frame = f
    return f
end

function WhatsNew:Show()
    local f = self:Build()
    for _, b in ipairs(f.checks) do if b.Refresh then b:Refresh() end end
    f:Show()
end

-- Beim Einloggen: neue Version → Fenster; sonst, wenn Teilen noch aus ist → Chat-Hinweis
function WhatsNew:Check()
    if not ONE.db then return end
    if ONE.db.seenVersion ~= ONE.version and Notes() then
        ONE.db.seenVersion = ONE.version
        self:Show()
        return
    end
    ONE.db.seenVersion = ONE.version
    local off = self:SharesOff()
    if off > 0 then
        ONE:Print(T("%d Teilen-Funktionen sind noch aus – Guild Trip ist besser, wenn die Gilde teilt. /trip teilen öffnet die Einstellungen.", off))
    end
end

function WhatsNew:Initialize()
    if ONE.RegisterSlash then
        ONE:RegisterSlash("neu", function() WhatsNew:Show() end, T("Neuigkeiten dieser Version zeigen"))
        ONE:RegisterSlash("speicher", function()
            -- erst aufraeumen: sonst zaehlt WoW auch schon freigegebenen, noch nicht weggeraeumten Speicher mit
            local gc = rawget(_G, "collectgarbage")
            if gc then pcall(gc, "collect") end
            local line = ONE.BugReport and ONE.BugReport.MemoryLine and ONE.BugReport.MemoryLine()
            ONE:Print(line and (line:gsub("^Memory:", T("Speicher:"))) or T("Speicheranzeige ist hier nicht verfügbar."))
        end, T("Speicherbedarf von Guild Trip anzeigen"))
        ONE:RegisterSlash("teilen", function()
            if ONE.UI then ONE.UI:Navigate("sharing") end
        end, T("Teilen-Einstellungen öffnen"))
    end
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_ENTERING_WORLD")
    login:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
        if not isInitialLogin or isReloadingUi or WhatsNew.started then return end
        WhatsNew.started = true
        local tries = 0
        local function Try()
            tries = tries + 1
            local blocked = (InCombatLockdown and InCombatLockdown())
                or (ONE.Welcome and ONE.Welcome.frame and ONE.Welcome.frame:IsShown())
                or (ONE.Welcome and ONE.Welcome.pendingLogin)
            if blocked and tries < 30 then C_Timer.After(3, Try) return end
            WhatsNew:Check()
        end
        C_Timer.After(5, Try)
    end)
end
