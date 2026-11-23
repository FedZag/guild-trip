local _, crafting = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
-- Namensraum fuer das Entwickler-Addon ONE_Dev
ONE.ns = ONE.ns or {}
ONE.ns.crafting = crafting

if ONE.RegisterFeature then
    ONE:RegisterFeature("crafting.recipes", {module = "crafting", label = "Eigene Rezepte merken",
        tooltip = "Liest beim Öffnen eines Berufsfensters deine Rezepte ein (für die Rezeptsuche und zum Teilen)."})
    ONE:RegisterFeature("crafting.trainers", {module = "crafting", label = "Lehrer merken",
        tooltip = "Lehrer, die du ansprichst, kommen ins Lehrer-Verzeichnis."})
    -- 0.7.2: Berufs-Links aus dem Chat – neue Automatik, darum Standard AUS
    ONE:RegisterFeature("crafting.chatLinks", {module = "crafting", label = "Berufs-Links aus dem Chat merken",
        tooltip = "Merkt still, wer in Gilde, Handel oder Flüstern Berufe oder Rezepte verlinkt (nur auf deinem Rechner, 30 Tage). Guild Trip sendet dabei nie etwas.",
        get = function() return crafting.ChatLinks:Enabled() end,
        set = function(on) crafting.ChatLinks:SetEnabled(on) end})
end

ONE:RegisterModule("crafting", {
    title = "Berufe",
    -- Lehrer-Verzeichnis fuer die Navi-Seite
    AllTrainers = function() return crafting.Trainers:All() end,
    TeachText = function(e) return crafting.Trainers.TeachText(e) end,
    WhatName = function(e) return crafting.Trainers.WhatName(e) end,
    WeaponsOf = function(e) return crafting.Trainers.WeaponsOf(e) end,
    FactionText = function(e, faction) return crafting.Trainers.FactionText(e, faction) end,
    Initialize = function()
        crafting.Page:Register()
        crafting.Share:Initialize()
        -- Auffrischen gebuendelt: viele Ereignisse kurz hintereinander (Gegenstandsdaten,
        -- Gildenliste, Gildenfunk) bauen die Seite nur EINMAL neu auf.
        local refreshPending = false
        local function RefreshNow()
            refreshPending = false
            local ui = ONE.UI
            if ui and ui.frame and ui.frame:IsShown() and ui.activeTab == "crafting" then crafting.Page:Refresh() end
        end
        local function RefreshIfVisible()
            local ui = ONE.UI
            if not (ui and ui.frame and ui.frame:IsShown() and ui.activeTab == "crafting") then return end
            if refreshPending then return end
            refreshPending = true
            if C_Timer and C_Timer.After then C_Timer.After(.5, RefreshNow) else RefreshNow() end
        end
        crafting.Share.onChange = RefreshIfVisible
        crafting.ChatLinks.onChange = RefreshIfVisible
        crafting.ChatLinks:Initialize()
        -- Eigene Rezepte beim Oeffnen eines Berufsfensters merken und (falls freigegeben) teilen.
        local events = CreateFrame("Frame")
        for _, ev in ipairs({"TRADE_SKILL_SHOW", "NEW_RECIPE_LEARNED", "ITEM_DATA_LOAD_RESULT", "GUILD_ROSTER_UPDATE"}) do
            pcall(events.RegisterEvent, events, ev)
        end
        local pending = false
        -- Datensparsamkeit: alte Staende (30 Tage) und Ex-Mitglieder regelmaessig loeschen.
        local lastPrune = -1e9
        local function PruneGuildData()
            local now = type(GetTime) == "function" and GetTime() or 0
            if now - lastPrune < 60 then return end
            lastPrune = now
            local names = {}
            local total = type(GetNumGuildMembers) == "function" and tonumber((GetNumGuildMembers())) or 0
            for i = 1, total or 0 do
                local name = type(GetGuildRosterInfo) == "function" and GetGuildRosterInfo(i)
                if type(name) == "string" then names[name] = true end
            end
            crafting.Recipes:Prune(names)
        end
        crafting.PruneGuildData = PruneGuildData
        function crafting.AskShare()
            local store = crafting.Recipes:Store()
            local me = crafting.Recipes.Me()
            store.askedShare = type(store.askedShare) == "table" and store.askedShare or {}
            if crafting.Share:IsSharing() or store.askedShare[me] then return false end
            if type(IsInGuild) == "function" and not IsInGuild() then return false end
            if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return false end
            store.askedShare[me] = true
            StaticPopupDialogs.GUILDTRIP_SHARE_RECIPES = {
                text = T("Guild Trip: Sollen deine Gildenmitglieder sehen, was du herstellen kannst?\n\nDann kann dich die Gilde um Ausrüstung bitten – und du siehst umgekehrt, wer dir etwas herstellen kann. Änderbar unter Optionen › Teilen."),
                button1 = T("Ja, teilen"), button2 = T("Nein"),
                OnAccept = function() crafting.Share:SetSharing(true) end,
                timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
            }
            StaticPopup_Show("GUILDTRIP_SHARE_RECIPES")
            return true
        end
        events:SetScript("OnEvent", function(_, event)
            if event == "GUILD_ROSTER_UPDATE" then pcall(PruneGuildData) RefreshIfVisible() return end
            if event == "ITEM_DATA_LOAD_RESULT" then RefreshIfVisible() return end
            if pending then return end
            pending = true
            local function Go()
                pending = false
                if ONE.FeatureOn and not ONE:FeatureOn("crafting.recipes") then return end
                local prof, count = crafting.Recipes:Capture()
                if prof then
                    local data = crafting.Recipes:Mine()[prof]
                    if crafting.Share:IsSharing() and data then crafting.Share:SendProfession(prof, data) end
                    RefreshIfVisible()
                    if count and event == "TRADE_SKILL_SHOW" and not crafting.announced then
                        crafting.announced = true
                        ONE:Print(T("Berufe: %s gemerkt (%d gelernte Rezepte).", prof, count))
                    end
                    -- 0.7.1: beim ersten Berufsfenster einmal fragen, ob die Gilde sehen darf,
                    -- was du herstellen kannst (sonst kennt "Ausruestung auf deinem Weg" keine Hersteller)
                    if event == "TRADE_SKILL_SHOW" and crafting.AskShare then pcall(crafting.AskShare) end
                end
            end
            if C_Timer and C_Timer.After then C_Timer.After(1, Go) else Go() end
        end)
        -- Lehrer, die man anspricht, kommen ins Gilden-Verzeichnis (bestaetigt).
        local trainerEvents = CreateFrame("Frame")
        pcall(trainerEvents.RegisterEvent, trainerEvents, "TRAINER_SHOW")
        trainerEvents:SetScript("OnEvent", function()
            local function Go()
                if ONE.FeatureOn and not ONE:FeatureOn("crafting.trainers") then return end
                local e = crafting.Trainers:CaptureCurrent()
                if e then crafting.Share:SendTrainer(e) RefreshIfVisible() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(.5, Go) else Go() end
        end)
        -- "!" am Minimap-Knopf, wenn eine Berufsausbildung faellig ist
        local function CheckDue()
            local due = crafting.Trainers:Due(crafting.Trainers:MyProfessions(), tonumber((UnitLevel and UnitLevel("player"))) or 0)
            local ready = {}
            for _, d in ipairs(due) do if d.ready then ready[#ready + 1] = d.text end end
            local mini = ONE.MinimapButton
            if mini and mini.SetAlert then
                if #ready > 0 then mini:SetAlert("crafting", table.concat(ready, " · "), "nav-trainers")
                else mini:ClearAlert("crafting") end
            end
        end
        local dueEvents = CreateFrame("Frame")
        for _, ev in ipairs({"PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD"}) do
            pcall(dueEvents.RegisterEvent, dueEvents, ev)
        end
        dueEvents:SetScript("OnEvent", function() if C_Timer and C_Timer.After then C_Timer.After(2, CheckDue) else CheckDue() end end)
        crafting.CheckDue = CheckDue
    end,
})
