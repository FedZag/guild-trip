local _, nav = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
-- Namensraum fuer das Entwickler-Addon ONE_Dev (Testwerkzeuge haengen sich hier an)
ONE.ns = ONE.ns or {}
ONE.ns.nav = nav

local function Paused()
    if ONE:IsEnabled("nav") then return false end
    ONE:Print(T("Das Navi-Modul ist pausiert (/trip modules)."))
    return true
end

local function Navi(rest)
    if Paused() then return end
    if rest == "" then
        ONE:Print(T("Navi: /trip navi <Name> | /trip navi probe | /trip navi stil | /trip navi aus | /trip navi fest | /trip navi mitte"))
        ONE:Print(T("Oder: Weltkarte öffnen (/trip map), Mitglied wählen, 'Navi zu …' klicken."))
        ONE:Print(T("Eigener Wegpunkt: Umschalt+Klick auf die Weltkarte oder /trip way 45.2 60.1 [Gebiet]."))
    elseif rest == "probe" then
        nav.Arrow:StartProbe()
    elseif rest == "stil" then
        nav.Arrow:Create()
        local style = nav.Arrow:ToggleStyle()
        ONE:Print(style == "blizzard" and T("Navi-Pfeil: Blizzard-Stil.") or T("Navi-Pfeil: Guild-Trip-Stil (gold)."))
    elseif rest == "aus" or rest == "stop" then
        nav.Arrow:Stop(T("Navi beendet."))
    elseif rest == "fest" then
        nav.Arrow:Create()
        local locked = not nav.Arrow:Settings().locked
        nav.Arrow:SetLocked(locked)
        ONE:Print(locked and T("Navi-Pfeil festgesetzt.") or T("Navi-Pfeil kann verschoben werden."))
    elseif rest == "mitte" then
        nav.Arrow:Create()
        nav.Arrow:ResetPosition()
        ONE:Print(T("Navi-Pfeil zurück über die Spielfigur gesetzt."))
    else
        nav.Arrow:Start(rest)
    end
end

-- Einzelfunktionen (Optionen › Module)
if ONE.RegisterFeature then
    ONE:RegisterFeature("nav.quests", {module = "nav", label = "Quest-Seite (Reiter Quests)", reload = true,
        tooltip = "Eigener Reiter mit deinen Quests, Fortschritt und Navi. Wirkt nach dem Neuladen."})
    ONE:RegisterFeature("nav.questMap", {module = "nav", label = "Quest-Symbole auf der Weltkarte",
        get = function() return nav.QuestPins:Settings().map end,
        set = function(on) nav.QuestPins:Settings().map = on and true or false nav.QuestPins:Refresh() end})
    ONE:RegisterFeature("nav.questMinimap", {module = "nav", label = "Quest-Symbole auf der Minimap",
        get = function() return nav.QuestPins:Settings().minimap end,
        set = function(on) nav.QuestPins:Settings().minimap = on and true or false nav.QuestPins:Refresh() end})
    ONE:RegisterFeature("nav.givers", {module = "nav", label = "Questgeber (!) sammeln und zeigen",
        tooltip = "Merkt sich NPCs, die Quests anbieten, und zeigt ein „!“ auf Karte und Minimap."})
    ONE:RegisterFeature("nav.routes", {module = "nav", label = "Wegführung über das Guild-Trip-Wegenetz",
        tooltip = "Der Pfeil folgt vorab berechneten Laufwegen (Straßen, Brücken, Pässe) zwischen Questgebern, Lehrern, Händlern und Flugmeistern – ohne Zusatz-Addon. Ist Shortest Path Forever installiert, führt weiter dieses."})
    ONE:RegisterFeature("nav.routeDots", {module = "nav", label = "Weg als Punkte auf Minimap und Weltkarte",
        tooltip = "Folgt der Pfeil dem Wegenetz, zeigen goldene Punkte den Weg auf Minimap und Weltkarte, ein Ring die nächste Abbiegung."})
    ONE:RegisterFeature("nav.routeWaypoint", {module = "nav", label = "Nächste Abbiegung als WoW-Wegpunkt",
        tooltip = "Setzt die nächste Abbiegung als WoW-Wegpunkt – so siehst du sie auch in der Spielwelt. Einen eigenen Wegpunkt von dir überschreibt Guild Trip nicht."})
    ONE:RegisterFeature("nav.spf", {module = "nav", label = "Wegführung über Shortest Path Forever (wenn installiert)",
        tooltip = "Ist das kostenlose Addon Shortest Path Forever installiert, übernimmt es die Wegführung: echte Wege, Flugrouten, Schiffe und die Route auf den Karten. Ohne es zeigt der Guild-Trip-Pfeil die Richtung."})
    ONE:RegisterFeature("nav.trackerNavi", {module = "nav", label = "Klick auf ? oder … in der Zielverfolgung startet das Navi",
        tooltip = "Klickst du in der Quest-Zielverfolgung auf das Fragezeichen oder die drei Punkte, zeigt der Pfeil zur Quest (Ziel bzw. Abgabe)."})
    ONE:RegisterFeature("nav.corpse", {module = "nav", label = "Nach dem Tod: Pfeil zur Leiche",
        tooltip = "Als Geist zeigt der Pfeil zu deiner Leiche; danach geht es zum vorherigen Ziel weiter. Aus, solange Polestar läuft (eigener Pfeil)."})
    ONE:RegisterFeature("nav.merchants", {module = "nav", label = "Händler-Verzeichnis",
        tooltip = "Merkt sich Händler, die du öffnest, und zeigt sie in der Navi unter „Händler“."})
end

ONE:RegisterModule("nav", {
    title = "Navigation",
    Initialize = function()
        nav.Flights:Initialize()
        nav.Page:Register()
        if not ONE.FeatureOn or ONE:FeatureOn("nav.quests") then nav.Quests:Register() end
        nav.QuestShare:Initialize()
        nav.QuestGivers:Initialize()
        nav.QuestPins:Initialize()
        nav.RouteDots:Initialize()
        nav.Merchants:Initialize()
        nav.PlayerArrow:Initialize()
        nav.Waypoints:Initialize()
        ONE:RegisterSlash("navi", Navi, T("Richtungspfeil zu einem Gildenmitglied"))
    end,
    -- Entfernung in Yards vom Spieler (gleicher Kontinent), sonst nil
    DistanceTo = function(_, mapID, x, y)
        local pc, px, py = nav.Travel.PlayerWorld()
        local tc, tx, ty = nav.Travel.World(mapID, x, y)
        if not (pc and tc and pc == tc) then return nil end
        return nav.Travel.Distance(px, py, tx, ty)
    end,
    -- Entfernung in Yards zwischen zwei Kartenpunkten; nil, "continent" bei
    -- verschiedenen Kontinenten, nil ohne Umrechnung
    DistanceBetween = function(_, mapA, xA, yA, mapB, xB, yB)
        local ac, ax, ay = nav.Travel.World(mapA, xA, yA)
        local bc, bx, by = nav.Travel.World(mapB, xB, yB)
        if not (ac and bc) then return nil end
        if ac ~= bc then return nil, "continent" end
        return nav.Travel.Distance(ax, ay, bx, by)
    end,
    -- opts: {service = true} fuer Abstecher (danach zurueck zum vorherigen Ziel)
    PointTo = function(_, label, mapID, x, y, opts)
        if Paused() then return false end
        return nav.Arrow:StartPoint(label, mapID, x, y, opts)
    end,
    -- Fuer den Gruppenfinder: wer in der Gilde hat diese Quest ("Thrall 5/8, ...")
    QuestHolders = function(_, questID)
        return nav.QuestShare and (nav.QuestShare:HoldersText(questID)) or ""
    end,
    -- Darf Guild Trip den Pfeil von selbst starten? Nein, wenn Polestar seinen eigenen Pfeil fuehrt.
    AutoNaviAllowed = function() return nav.Waypoints.AutoAllowed() end,
    StartTo = function(_, name)
        if Paused() then return false end
        return nav.Arrow:Start(name)
    end,
})
