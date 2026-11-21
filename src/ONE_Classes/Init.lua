local _, classes = ...
local ONE = _G.ProjectONE
-- Namensraum fuer das Entwickler-Addon ONE_Dev
ONE.ns = ONE.ns or {}
ONE.ns.classes = classes

if ONE.RegisterFeature then
    ONE:RegisterFeature("classes.buffs", {module = "classes", section = "Leisten", order = 20, label = "Buff-Erinnerung über den Leisten",
        tooltip = "Zeigt außerhalb des Kampfes über deinen Leisten, welche Buffs fehlen oder bald auslaufen – Buffs von anderen Spielern zählen mit. Klick auf ein Symbol wirkt den Buff. Alt + Ziehen verschiebt die Zeile.",
        get = function() return classes.Buffs:Enabled() end, set = function(on) classes.Buffs:SetEnabled(on) end})
    ONE:RegisterFeature("classes.nearby", {module = "classes", section = "Leisten", order = 22, label = "Spieler in der Nähe buffen",
        tooltip = "Kleines Fenster mit allen Spielern in Reichweite, denen einer deiner Buffs fehlt – Gruppe, Gilde, Freunde und Fremde. Ein Klick auf einen Namen wirkt den Buff im passenden Rang für die Stufe – sobald er sitzt, verschwindet der Spieler aus der Liste (Rechtsklick / Umschalt + Linksklick: weitere Buffs). Nur außerhalb des Kampfes.",
        get = function() return classes.Nearby:Enabled() end, set = function(on) classes.Nearby:SetEnabled(on) end})
    ONE:RegisterFeature("classes.nearbyAuto", {module = "classes", section = "Leisten", order = 23, label = "… alle Spieler in der Nähe automatisch erkennen",
        tooltip = "Addons sehen andere Spieler nur über Namensplaketten – die blauen Namen über den Köpfen bleiben für sie unsichtbar. Darum schaltet Guild Trip die freundlichen Namensplaketten ein und macht sie unsichtbar. Umschalt + V blendet sie ein und wieder aus – die Liste sieht die Spieler so oder so. Mit Plater & Co. fasst Guild Trip die Plaketten nicht an.",
        get = function() return classes.Nearby:AutoEnabled() end, set = function(on) classes.Nearby:SetAuto(on) end})
    ONE:RegisterFeature("classes.thanks", {module = "classes", section = "Leisten", order = 24, label = "Für Buffs bedanken (Emote)",
        tooltip = "Bufft dich ein anderer Spieler, antwortet Guild Trip mit einem WoW-Emote an ihn – z. B. „Grimmbart dankt Lunara.“, „verbeugt sich“, „jubelt“ oder „winkt“. Das sehen alle in der Nähe. Höchstens einmal je Spieler in 15 Minuten, nicht für deine Gruppe, nicht im Kampf."})
    ONE:RegisterFeature("classes.autoRank", {module = "classes", section = "Leisten", order = 21, label = "Leisten automatisch aktuell halten",
        tooltip = "Neue Ränge tauscht Guild Trip auf deinen Leisten aus. Neu gelernte Zauber aus dem Vorschlag legt es auf ihren freien Platz (sobald du einmal „Leisten einrichten“ benutzt hast). Makros und absichtlich niedrige Ränge bleiben unverändert. Im Kampf erst danach.",
        get = function() return classes.Ranks:Enabled() end, set = function(on) classes.Ranks:SetEnabled(on) end})
    ONE:RegisterFeature("classes.talentHint", {module = "classes", section = "Talente", order = 31, label = "Hinweis bei freiem Talentpunkt",
        tooltip = "Chatzeile und „!“ an der Minimap, wenn ein Talentpunkt frei ist."})
    ONE:RegisterFeature("classes.gear", {module = "classes", section = "Ratgeber", order = 11, label = "Ausrüstung bewerten (Tooltip)",
        tooltip = "Zeile im Gegenstands-Tooltip: besser oder schlechter für deinen Spielstil als das, was du trägst."})
    ONE:RegisterFeature("classes.loot", {module = "classes", section = "Ratgeber", order = 12, label = "Beute merken (Fundorte)",
        tooltip = "Merkt sich beim Plündern, welcher Gegner welche Ausrüstung fallen lässt, und zeigt den Fundort im Tooltip."})
    ONE:RegisterFeature("classes.trainer", {module = "classes", section = "Ratgeber", order = 13, label = "Ratgeber beim Klassenlehrer",
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
        classes.Nearby:Initialize()
        if classes.Thanks then classes.Thanks:Initialize() end
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
