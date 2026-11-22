-- Offline-Test 0.7.8: Optionen › Grafik – versteckte CVars, sichere Grenzen, Sicherung,
-- Vorlagen, zurueck auf Standard / wie vorher, beim Einloggen neu setzen (Standard aus), Englisch.
local root = arg[1] or "src"
local printed = {}
local ONE = {db = {}, slashCommands = {}}
function ONE:Print(s) printed[#printed + 1] = s end
function ONE:RegisterSlash(name, fn) self.slashCommands[name] = fn return true end
_G.ProjectONE = ONE
local onEvent
CreateFrame = function() return {RegisterEvent = function() end, UnregisterEvent = function() end,
    SetScript = function(_, _, fn) onEvent = fn end} end

-- Client: "giQuality" gibt es nicht, Rest mit Standardwerten
local defaults = {cameraDistanceMaxZoomFactor = "1.9", groundEffectDensity = "48", groundEffectDist = "200",
    weatherDensity = "2", waterDetail = "1", sunshafts = "1", ResampleAlwaysSharpen = "0", maxFPSBk = "60",
    useMaxFPSBk = "0", reflectionMode = "1", rippleDetail = "1", textureFilteringMode = "2"}
local cvars = {}
for k, v in pairs(defaults) do cvars[k] = v end
cvars.groundEffectDensity = "64" -- Spieler hatte schon selbst etwas eingestellt
local sets = 0
C_CVar = {
    GetCVar = function(n) return cvars[n] end,
    GetCVarDefault = function(n) return defaults[n] end,
    SetCVar = function(n, v) assert(cvars[n], "nur vorhandene CVars setzen: " .. n) cvars[n] = tostring(v) sets = sets + 1 return true end,
}
assert(loadfile(root .. "/ONE_Core/Graphics.lua"))("ONE_Core", ONE)
local G = ONE.Graphics
G:Initialize()
assert(ONE.slashCommands.grafik, "/trip grafik")

-- 1) nur vorhandene Einstellungen
assert(G:Has("groundEffectDensity") and not G:Has("giQuality"))
assert(G:Set("giQuality", 3) == false)
-- 2) sichere Grenzen und Raster
assert(G.Clamp("waterDetail", 3) == 2, "Wasserdetail 3 stuerzt ab")
assert(G.Clamp("groundEffectDensity", 999) == 256 and G.Clamp("groundEffectDensity", 70) == 64)
assert(G.Clamp("cameraDistanceMaxZoomFactor", 5) == 2.6 and G.Clamp("cameraDistanceMaxZoomFactor", 2.34) == 2.3)
assert(G.Clamp("ResampleAlwaysSharpen", 5) == 1 and G.Clamp("ResampleAlwaysSharpen", 0) == 0)
assert(G.byCVar.giQuality[5] <= 4, "Lichtqualitaet hoechstens 4")
assert(not G.byCVar.volumeFog, "Nebel aus gibt es in Forever nicht mehr")
G:Set("waterDetail", 3)
assert(cvars.waterDetail == "2")
-- 3) Sicherung: alter Wert einmal gemerkt
G:Set("groundEffectDensity", 128)
G:Set("groundEffectDensity", 256)
local store = ONE.db.graphics
assert(cvars.groundEffectDensity == "256" and store.backup.groundEffectDensity == "64" and store.values.groundEffectDensity == 256)
-- 4) Vorlage: nur vorhandene, Bisheriges zurueck
assert(G:ApplyPreset("klar"))
assert(cvars.groundEffectDensity == "16" and cvars.weatherDensity == "0" and cvars.cameraDistanceMaxZoomFactor == "2.6")
assert(cvars.waterDetail == "1", "nicht Teil der Vorlage -> WoW-Standard")
assert(store.preset == "klar" and not store.values.giQuality)
assert(G:ApplyPreset("fps") and cvars.maxFPSBk == "30" and cvars.useMaxFPSBk == "1")
assert(not G:ApplyPreset("gibtsnicht"))
-- 5) beim Einloggen neu setzen: Standard aus
cvars.groundEffectDensity = "48" -- WoW-Menue hat ueberschrieben
local before = sets
onEvent({UnregisterEvent = function() end})
assert(sets == before and cvars.groundEffectDensity == "48", "Standard aus: nichts neu setzen")
store.reapply = true
assert(G:Reapply() == 1 and cvars.groundEffectDensity == "16")
-- 6) WoW-Standard und Wie vorher
G:ResetAll(false)
assert(cvars.groundEffectDensity == "48" and cvars.maxFPSBk == "60" and next(store.values) == nil)
assert(G:HasBackup())
G:ResetAll(true)
assert(cvars.groundEffectDensity == "64", "wie vorher = eigener Wert des Spielers")
assert(cvars.weatherDensity == "2" and not G:HasBackup())
-- 7) Anzeige
assert(G.Format("cameraDistanceMaxZoomFactor", "2.6") == "2,6" and G.Format("groundEffectDensity", "128") == "128")

-- 8) Optionen: Bereich, Vorlagen, Regler nur fuer Vorhandenes
local settings, cats = {}, {}
local ui = {AddCategory = function(_, id, def) cats[id] = def return true end,
    AddSetting = function(_, o) settings[#settings + 1] = o return true end}
G:RegisterSettings(ui)
assert(cats.graphics and cats.graphics.title == "Grafik")
local byId = {}
for _, o in ipairs(settings) do byId[o.id] = o end
assert(byId.gfxPreset_schoen and byId.gfxPreset_klar and byId.gfxPreset_fps and byId.gfxDefault and byId.gfxBackup)
assert(byId.gfx_giQuality and not byId.gfx_giQuality.visible(), "fehlende Einstellung ausgeblendet")
assert(byId.gfx_groundEffectDensity.visible() and byId.gfx_groundEffectDensity.kind == "custom")
assert(byId.gfxReapply.get() == true)
byId.gfxReapply.set(false)
assert(byId.gfxReapply.get() == false)

-- 9) Englisch fuer alle Texte
local EN = {}
assert(loadfile(root .. "/ONE_Core/Locale_enUS.lua"))("ONE_Core", {EN = EN, RegisterEN = nil})
local enRoot = EN
local function Need(t) assert(enRoot[t] or (ONE.EN and ONE.EN[t]), "ohne Englisch: " .. t) end
local okLoad = pcall(function()
    local ONE2 = {}
    assert(loadfile(root .. "/ONE_Core/Locale.lua"))("ONE_Core", ONE2)
    assert(loadfile(root .. "/ONE_Core/Locale_enUS.lua"))("ONE_Core", ONE2)
    enRoot = ONE2.EN
end)
assert(okLoad and enRoot, "Locale laden")
Need("Grafik")
for _, s in ipairs(G.SETTINGS) do Need(s[2]) Need(s[3]) if s[7] then Need(s[7]) end end
for _, p in ipairs(G.PRESETS) do Need(p.name) Need(p.tip) end
for _, o in ipairs(settings) do
    if o.label and o.kind ~= "custom" then Need(o.label) end
    if o.tooltip then Need(o.tooltip) end
    if o.section then Need(o.section) end
end
for _, t in ipairs({"Grafik-Vorlage „%s“ gesetzt.", "Grafik: zurück auf WoW-Standard.", "Grafik: alles wie vorher.",
    "WoW-Standard: %s", "Standard", "Versteckte Grafik-Einstellungen öffnen"}) do Need(t) end
print("OK test_graphics_151")
