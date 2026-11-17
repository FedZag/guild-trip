-- Offline-Test: Module und Einzelfunktionen schaltbar (Optionen › Module).
local root = arg[1] or "src"
CreateFrame = function() return {RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end} end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
local ONE = {}
assert(loadfile(root .. "/ONE_Core/Core.lua"))("ONE_Core", ONE)
ProjectONEDB = {modules = {nav = false}}
local stub = {Initialize = function() end, Refresh = function() end}
ONE.Themes, ONE.Notifications, ONE.UI, ONE.Welcome = stub, stub, stub, stub
ONE:Initialize()

-- 1) Kern-Funktionen sind angemeldet und schalten echte Einstellungen
assert(ONE.features["core.loginSummary"] and ONE:FeatureOn("core.loginSummary"))
ONE:SetFeature("core.loginSummary", false)
assert(ProjectONEDB.loginSummaryEnabled == false and not ONE:FeatureOn("core.loginSummary"))

-- 2) eigene Funktion: Standard an, merkt sich "aus"
assert(ONE:RegisterFeature("x.demo", {module = "x", label = "Demo"}))
assert(not ONE:RegisterFeature("x.demo", {label = "doppelt"}), "nicht doppelt")
assert(ONE:FeatureOn("x.demo"))
ONE:SetFeature("x.demo", false)
assert(not ONE:FeatureOn("x.demo") and ProjectONEDB.features["x.demo"] == false)
ONE:SetFeature("x.demo", true)
assert(ONE:FeatureOn("x.demo"))

-- 3) Modul aus -> startet nicht, seine Funktionen gelten als aus
local started = {}
ONE:RegisterModule("nav", {Initialize = function() started.nav = true end})
ONE:RegisterModule("x", {Initialize = function() started.x = true end})
assert(not started.nav and ONE.modules.nav.skipped, "ausgeschaltetes Modul startet nicht")
assert(started.x)
ONE:RegisterFeature("nav.demo", {module = "nav", label = "Nav-Demo"})
assert(not ONE:FeatureOn("nav.demo"), "Funktion eines ausgeschalteten Moduls ist aus")
print("OK test_features_076")
