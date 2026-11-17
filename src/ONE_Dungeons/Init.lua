local _, dungeons = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
-- Namensraum fuer das Entwickler-Addon ONE_Dev
ONE.ns = ONE.ns or {}
ONE.ns.dungeons = dungeons

if ONE.RegisterFeature then
    ONE:RegisterFeature("dungeons.notify", {module = "dungeons", section = "Gruppen", order = 21, label = "Hinweise bei Gruppengesuchen",
        tooltip = "Chatzeile und „!“ an der Minimap, wenn jemand aus der Gilde eine passende Gruppe sucht.",
        get = function() return dungeons.Share:Settings().notify end,
        set = function(on) dungeons.Share:Settings().notify = on and true or false end})
    ONE:RegisterFeature("dungeons.entrances", {module = "dungeons", section = "Dungeons", order = 10, label = "Dungeon-Eingänge merken",
        tooltip = "Merkt sich beim Betreten eines Dungeons den Eingang für „Zum Eingang“."})
    ONE:RegisterFeature("dungeons.recap", {module = "dungeons", section = "Dungeons", order = 11, label = "Rückblick nach jedem Dungeon",
        tooltip = "Nach dem Dungeon eine kleine Karte: Dauer (mit Bestzeit im Gildenpass), Gruppe, Bosse, Tode und Beute. Auf Wunsch eine Zeile in den Gildenchat."})
    ONE:RegisterFeature("dungeons.tripReminders", {module = "dungeons", category = "reminders", section = "Gildenausflüge", order = 40, label = "Erinnerung an Gildenausflüge",
        tooltip = "15 Minuten vor einem Ausflug, zu dem du dich angemeldet hast, eine Meldung; zum Start zeigt das Navi den Weg zum Treffpunkt."})
end

ONE:RegisterModule("dungeons", {
    title = "Dungeons",
    Initialize = function()
        dungeons.Page:Register()
        dungeons.Share:Initialize()
        dungeons.Entrances:Initialize()
        dungeons.Trips:Initialize()
        if dungeons.Recap then dungeons.Recap:Initialize() end
        -- Neue Daten aus der Gilde / nachgeladene Questtitel: sichtbare Seite neu
        -- aufbauen, aber gebuendelt (hoechstens alle 0,5 s) – jede Gildennachricht
        -- und jeder Questtitel einzeln war bei grossen Gilden zu viel.
        local pending = false
        local function Visible()
            local ui = ONE.UI
            return ui and ui.frame and ui.frame:IsShown() and ui.activeTab == "dungeons"
        end
        local function Later(fn)
            if not Visible() or pending then return end
            pending = true
            local function Go() pending = false if Visible() then fn() end end
            if C_Timer and C_Timer.After then C_Timer.After(.5, Go) else Go() end
        end
        dungeons.Share.onChange = function() Later(function() dungeons.Page:RefreshCombined() end) end
        -- Deutsche Questtitel kommen vom Server nach; dann Seite auffrischen.
        local events = CreateFrame("Frame")
        events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
        events:RegisterEvent("QUEST_TURNED_IN")
        events:RegisterEvent("QUEST_ACCEPTED")
        events:RegisterEvent("QUEST_REMOVED")
        events:SetScript("OnEvent", function(_, event, questID, success)
            if event ~= "QUEST_DATA_LOAD_RESULT" and dungeons.Trips then dungeons.Trips:QuestsChanged() end
            if event == "QUEST_DATA_LOAD_RESULT" then
                if not dungeons.Model:OnQuestData(questID, success) then return end
            end
            Later(function() dungeons.Page:Refresh() end)
        end)
    end,
    -- Quest-Seite (ONE_Nav): Gruppe fuer eine (Elite-)Quest suchen
    PostQuestAd = function(_, questID, title, size)
        if not ONE:IsEnabled("dungeons") or not questID then return nil end
        local have = type(GetNumGroupMembers) == "function" and GetNumGroupMembers() or 0
        return dungeons.Share:PostAd("q" .. questID, "T,H,D", math.max(1, have), "", title, size)
    end,
    -- Kalender (ONE_Guild): geplante Gildenausfluege als Kopien
    CalendarTrips = function()
        if not ONE:IsEnabled("dungeons") then return {} end
        local Tr, out = dungeons.Trips, {}
        for _, trip in ipairs(Tr:List()) do
            local mine, m = Tr:Mine(trip), trip.meet or {}
            out[#out + 1] = {id = trip.id, key = trip.key, name = Tr:Name(trip), start = trip.start,
                leader = Tr.Short(trip.leader), coming = Tr:Counts(trip).yes, mine = mine and mine.status or nil,
                info = Tr:InfoText(trip), roles = Tr:RoleText(trip), note = trip.note, dur = trip.dur,
                meet = m.name, mapID = m.mapID, x = m.x, y = m.y}
        end
        return out
    end,
    -- Kalender "Termin erstellen": Termin-Fenster (TripsPlanner) oeffnen
    PlanTrip = function()
        if dungeons.TripsPage then dungeons.TripsPage.openForm = true end
        return ONE.UI and ONE.UI.OpenLink and ONE.UI:OpenLink("trips")
    end,
    -- Einen Ausflug in der Ansicht "Ausfluege" oeffnen
    OpenTrip = function(_, id)
        if dungeons.TripsPage then dungeons.TripsPage.selectId = id end
        return ONE.UI and ONE.UI.OpenLink and ONE.UI:OpenLink("trips")
    end,
    MyQuestAd = function()
        local ad = dungeons.Share.myAd
        return ad and dungeons.Share:QuestOf(ad) or nil
    end,
})
