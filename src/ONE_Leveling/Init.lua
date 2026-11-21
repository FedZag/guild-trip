-- Guild Trip Quest-Fuehrung (Leveling-Assistent), Modul "leveling" (0.6.9).
-- Eigener Reiter "Leveln" (ersetzt den Reiter "Quests"; der Questlog ist dort eine Ansicht).
-- Alle Einstellungen stehen in Optionen › Leveln (Settings.lua), samt Modul-Hauptschalter.
local _, lev = ...
local ONE = _G.ProjectONE
ONE.ns = ONE.ns or {}
ONE.ns.leveling = lev

ONE:RegisterModule("leveling", {
    title = "Quest-Führung",
    Initialize = function()
        lev.Page:Register()
        lev.Tracker:Initialize()
        lev.Guide:Initialize()
        lev.AutoQuest:Initialize()
        lev.Journal:Initialize()
        if lev.XPLog then lev.XPLog:Initialize() end
        if lev.WorkLog then lev.WorkLog:Initialize() end
        if lev.Hearth then lev.Hearth:Initialize() end
    end,
    -- ONE_Nav: Reiter "Quests" nur ohne Fuehrung
    OwnsQuestTab = function() return not ONE.IsEnabled or ONE:IsEnabled("leveling") end,
    Replan = function() return lev.Guide:Replan() end,
    OpenSettings = function() lev.Settings:Open() end,
})
