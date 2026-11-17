local _, classes = ...
local ONE = _G.ProjectONE
-- Namensraum fuer das Entwickler-Addon ONE_Dev
ONE.ns = ONE.ns or {}
ONE.ns.classes = classes

if ONE.RegisterFeature then
    ONE:RegisterFeature("classes.buffs", {module = "classes", label = "Buff-Erinnerung über den Leisten",
        get = function() return classes.Buffs:Enabled() end, set = function(on) classes.Buffs:SetEnabled(on) end})
    ONE:RegisterFeature("classes.autoRank", {module = "classes", label = "Leisten automatisch aktuell halten",
        get = function() return classes.Ranks:Enabled() end, set = function(on) classes.Ranks:SetEnabled(on) end})
    ONE:RegisterFeature("classes.talentHint", {module = "classes", label = "Hinweis bei freiem Talentpunkt",
        tooltip = "Chatzeile und „!“ an der Minimap, wenn ein Talentpunkt frei ist."})
    ONE:RegisterFeature("classes.gear", {module = "classes", label = "Ausrüstung bewerten (Tooltip)",
        tooltip = "Zeile im Gegenstands-Tooltip: besser oder schlechter für deinen Spielstil als das, was du trägst."})
    ONE:RegisterFeature("classes.loot", {module = "classes", label = "Beute merken (Fundorte)",
        tooltip = "Merkt sich beim Plündern, welcher Gegner welche Ausrüstung fallen lässt, und zeigt den Fundort im Tooltip."})
    ONE:RegisterFeature("classes.trainer", {module = "classes", label = "Ratgeber beim Klassenlehrer",
        tooltip = "Kleines Fenster beim Klassenlehrer: was sich zu lernen lohnt.",
        get = function() return not (ONE.db.classGuide and ONE.db.classGuide.trainerAdvice == false) end,
        set = function(on) ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {} ONE.db.classGuide.trainerAdvice = on and true or false end})
end

ONE:RegisterModule("classes", {
    title = "Klasse",
    Initialize = function()
        classes.Page:Register()
        classes.Share:Initialize()
        classes.Buffs:Initialize()
        classes.Talents:Initialize()
        classes.Trainer:Initialize()
        if classes.Gear then classes.Gear:Initialize() end
        if classes.Loot then classes.Loot:Initialize() end
        local function RefreshIfVisible()
            local ui = ONE.UI
            if ui and ui.frame and ui.frame:IsShown() and ui.activeTab == "classes" then classes.Page:Refresh() end
        end
        local events = CreateFrame("Frame")
        for _, ev in ipairs({"SPELLS_CHANGED", "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE",
            "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
            "CHARACTER_POINTS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED"}) do
            pcall(events.RegisterEvent, events, ev)
        end
        -- Neue Raenge automatisch auf die Leisten (sofort, nicht verzoegert)
        local ranks = CreateFrame("Frame")
        for _, ev in ipairs({"SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_REGEN_ENABLED"}) do
            pcall(ranks.RegisterEvent, ranks, ev)
        end
        ranks:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" then pcall(classes.Ranks.OnCombatEnded, classes.Ranks)
            else pcall(classes.Ranks.OnSpellsChanged, classes.Ranks) end
        end)
        pcall(classes.Ranks.OnSpellsChanged, classes.Ranks)
        local pending = false
        events:SetScript("OnEvent", function()
            if pending then return end
            pending = true
            local function Go() pending = false RefreshIfVisible() end
            if C_Timer and C_Timer.After then C_Timer.After(.5, Go) else Go() end
        end)
    end,
})
