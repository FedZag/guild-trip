-- Guild Trip: versteckte Grafik-Einstellungen von WoW Forever (Optionen › Grafik).
-- Nutzer 22.11.2026: "lass uns da doch was schönes bauen" – Konsolenbefehle (CVars), die das
-- WoW-Menue nicht anbietet, als Regler und Vorlagen. Quellen (Werte/Grenzen, 22.11.2026):
-- kami-labs.fr, botwowforever.com, undying.app, conquestcapped.com, vgtimes.com und die Seiten
-- der Addons Forever Visuals / Panorama Forever (nur Ideen, kein Code).
--  * Gezeigt wird nur, was es im Client wirklich gibt (GetCVar ~= nil).
--  * Vor der ersten Aenderung einer Einstellung merkt sich Guild Trip den alten Wert ("Wie vorher").
--  * Sichere Grenzen: Wasserdetail hoechstens 2 und Lichtqualitaet hoechstens 4 (hoeher stuerzt ab),
--    "Nebel aus" gibt es in Forever nicht mehr (Beta 24.09.2026) – deshalb nicht dabei.
--  * Das WoW-Grafikmenue ueberschreibt Gras und Wetter: wahlweise beim Einloggen neu setzen (Standard aus).
local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local G = {}
ONE.Graphics = G

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

-- {cvar, Beschriftung, Bereich, min, max, Schritt, Tooltip}; Schritt nil = Schalter (0/1)
G.SETTINGS = {
    {"cameraDistanceMaxZoomFactor", "Kamera-Entfernung", "Kamera", 1, 2.6, .1,
        "Wie weit du herauszoomen kannst. WoW-Standard 1,9. Bei etwa 39 Metern ist trotzdem Schluss."},
    {"groundEffectDensity", "Grasdichte", "Gras und Umgebung", 16, 256, 16,
        "Wie dicht Gras und kleine Pflanzen wachsen. Das WoW-Menü geht nur bis 48. Viel Gras kostet Bilder pro Sekunde und versteckt Kräuter."},
    {"groundEffectDist", "Grasweite", "Gras und Umgebung", 40, 500, 10,
        "Bis wohin Gras gezeichnet wird."},
    {"lodObjectFadeScale", "Weite Objekte", "Gras und Umgebung", 50, 300, 10,
        "Wie lange Bäume, Felsen und Zäune in der Ferne ihre volle Form behalten."},
    {"lodObjectCullSize", "Kleine Objekte ausblenden ab", "Gras und Umgebung", 1, 30, 1,
        "Ab welcher Größe weit entfernte Kleinigkeiten verschwinden. Kleiner = mehr bleibt sichtbar."},
    {"terrainLodDist", "Gelände in voller Form", "Gras und Umgebung", 200, 1500, 50,
        "Bis wohin Hügel und Boden ihre volle Form behalten."},
    {"horizonStart", "Horizont beginnt", "Gras und Umgebung", 400, 6000, 100,
        "Wo der ferne Horizont anfängt."},
    {"weatherDensity", "Wetter", "Wetter, Licht und Wasser", 0, 3, 1,
        "Regen und Schnee: 0 = aus, 3 = voll. WoW-Standard 2."},
    {"sunshafts", "Lichtstrahlen", "Wetter, Licht und Wasser", 0, 2, 1,
        "Lichtstrahlen durch Bäume und Wolken: 0 = aus, 2 = am schönsten."},
    {"giQuality", "Indirektes Licht", "Wetter, Licht und Wasser", 0, 4, 1,
        "Wie gut Licht von Flächen zurückstrahlt. Höher als 4 kann das Spiel abstürzen lassen – deshalb geht der Regler nur bis 4."},
    {"reflectionMode", "Spiegelung im Wasser", "Wetter, Licht und Wasser", 0, 3, 1,
        "Wie viel von der Welt sich im Wasser spiegelt."},
    {"rippleDetail", "Wellen im Wasser", "Wetter, Licht und Wasser", 0, 3, 1,
        "Wellen, wenn du durchs Wasser läufst."},
    {"waterDetail", "Wasserdetail", "Wetter, Licht und Wasser", 0, 2, 1,
        "Höchstens 2 – Stufe 3 lässt Forever abstürzen."},
    {"ResampleAlwaysSharpen", "Bild immer nachschärfen", "Bild"},
    {"ResampleSharpness", "Stärke des Nachschärfens", "Bild", 0, 2, .1,
        "Kleiner = schärfer (0 ist am schärfsten)."},
    {"textureFilteringMode", "Texturfilter", "Bild", 0, 5, 1,
        "Schärfe schräger Böden und Wände: 0 = einfach, 5 = 16-fach."},
    {"projectedTextures", "Zauberkreise auf dem Boden", "Bild"},
    {"useMaxFPS", "Bilder pro Sekunde begrenzen", "Bildrate"},
    {"maxFPS", "Höchstens", "Bildrate", 30, 240, 5, "Bilder pro Sekunde im Vordergrund."},
    {"useMaxFPSBk", "Im Hintergrund begrenzen", "Bildrate"},
    {"maxFPSBk", "Im Hintergrund höchstens", "Bildrate", 8, 60, 1,
        "Bilder pro Sekunde, wenn WoW nicht im Vordergrund ist – schont Laptop und Lüfter."},
}
G.byCVar = {}
for i, s in ipairs(G.SETTINGS) do s.order = i G.byCVar[s[1]] = s end

-- Vorlagen: nur Werte, die vom WoW-Standard abweichen sollen
G.PRESETS = {
    {id = "schoen", name = "Schön", tip = "Dichtes Gras, weite Sicht, volles Wetter, Lichtstrahlen, schöne Spiegelung.",
        values = {cameraDistanceMaxZoomFactor = 2.6, groundEffectDensity = 128, groundEffectDist = 400,
            lodObjectFadeScale = 200, lodObjectCullSize = 8, terrainLodDist = 1000, horizonStart = 4000,
            weatherDensity = 3, sunshafts = 2, reflectionMode = 3, rippleDetail = 3, ResampleAlwaysSharpen = 1,
            textureFilteringMode = 5}},
    {id = "klar", name = "Klare Sicht", tip = "Wenig Gras (Kräuter und Gegner gut zu sehen), kein Wetter, keine Lichtstrahlen, scharfes Bild, weit herauszoomen.",
        values = {cameraDistanceMaxZoomFactor = 2.6, groundEffectDensity = 16, groundEffectDist = 120,
            weatherDensity = 0, sunshafts = 0, ResampleAlwaysSharpen = 1, textureFilteringMode = 5}},
    {id = "fps", name = "Mehr FPS", tip = "Wenig Gras, kein Wetter, keine Lichtstrahlen, einfaches Wasser, im Hintergrund höchstens 30 Bilder.",
        values = {groundEffectDensity = 16, groundEffectDist = 80, weatherDensity = 0, sunshafts = 0,
            reflectionMode = 0, rippleDetail = 0, waterDetail = 1, useMaxFPSBk = 1, maxFPSBk = 30}},
}

-- ===== Speicher und Zugriff =====
function G:Store()
    ONE.db = ONE.db or {}
    local s = type(ONE.db.graphics) == "table" and ONE.db.graphics or {}
    ONE.db.graphics = s
    s.values = type(s.values) == "table" and s.values or {}
    s.backup = type(s.backup) == "table" and s.backup or {}
    return s
end

function G.Get(cvar)
    local cv = rawget(_G, "C_CVar")
    local v = cv and Call(cv.GetCVar, cvar)
    if v == nil then v = Call(rawget(_G, "GetCVar"), cvar) end
    if v == nil then return nil end
    return tostring(v)
end
function G.Default(cvar)
    local cv = rawget(_G, "C_CVar")
    local v = cv and Call(cv.GetCVarDefault, cvar)
    if v == nil then v = Call(rawget(_G, "GetCVarDefault"), cvar) end
    return v ~= nil and tostring(v) or nil
end
local function Raw(cvar, value)
    local cv = rawget(_G, "C_CVar")
    if cv and type(cv.SetCVar) == "function" then return Call(cv.SetCVar, cvar, tostring(value)) end
    return Call(rawget(_G, "SetCVar"), cvar, tostring(value))
end

-- Gibt es die Einstellung in diesem Client?
function G:Has(cvar) return G.Get(cvar) ~= nil end

-- Wert in die sicheren Grenzen bringen (Schalter: 0/1)
function G.Clamp(cvar, value)
    local s = G.byCVar[cvar]
    local n = tonumber(value)
    if not s or not n then return nil end
    if not s[6] then return n ~= 0 and 1 or 0 end
    if n < s[4] then n = s[4] elseif n > s[5] then n = s[5] end
    local step = s[6]
    n = s[4] + math.floor((n - s[4]) / step + .5) * step
    if step < 1 then n = math.floor(n * 100 + .5) / 100 end
    return n
end

-- Setzen: alten Wert einmal merken, Wert speichern (fuer "beim Einloggen neu setzen")
function G:Set(cvar, value)
    if not G.byCVar[cvar] or not self:Has(cvar) then return false end
    local n = G.Clamp(cvar, value)
    if n == nil then return false end
    local store = self:Store()
    if store.backup[cvar] == nil then store.backup[cvar] = G.Get(cvar) end
    store.values[cvar] = n
    Raw(cvar, n)
    return true
end

-- Auf WoW-Standard (bzw. "Wie vorher"): Guild Trip vergisst die Einstellung
function G:Reset(cvar, toBackup)
    if not G.byCVar[cvar] or not self:Has(cvar) then return false end
    local store = self:Store()
    local target = toBackup and store.backup[cvar] or G.Default(cvar)
    if target == nil and not toBackup then
        -- kein Standard bekannt: alten Wert nehmen
        target = store.backup[cvar]
    end
    store.values[cvar] = nil
    if target ~= nil then Raw(cvar, target) end
    if toBackup then store.backup[cvar] = nil end
    return true
end
function G:ResetAll(toBackup)
    for _, s in ipairs(G.SETTINGS) do
        local store = self:Store()
        if store.values[s[1]] ~= nil or (toBackup and store.backup[s[1]] ~= nil) then self:Reset(s[1], toBackup) end
    end
end
function G:HasBackup() return next(self:Store().backup) ~= nil end

-- Vorlage: erst alles Bisherige von Guild Trip zuruecknehmen, dann die Werte der Vorlage
function G:ApplyPreset(id)
    local preset
    for _, p in ipairs(G.PRESETS) do if p.id == id then preset = p end end
    if not preset then return false end
    self:ResetAll(false)
    for cvar, v in pairs(preset.values) do self:Set(cvar, v) end
    self:Store().preset = id
    return true
end

-- Beim Einloggen neu setzen (WoW-Grafikmenue ueberschreibt Gras/Wetter). Standard aus.
function G:Reapply()
    local store = self:Store()
    if not store.reapply then return 0 end
    local n = 0
    for cvar, v in pairs(store.values) do
        if G.byCVar[cvar] and self:Has(cvar) and G.Get(cvar) ~= tostring(v) then Raw(cvar, v) n = n + 1 end
    end
    return n
end

-- Anzeige des Werts
function G.Format(cvar, v)
    local s = G.byCVar[cvar]
    local n = tonumber(v)
    if not n then return "–" end
    if s and s[6] and s[6] < 1 then return (("%.1f"):format(n):gsub("%.", ",")) end
    return tostring(math.floor(n + .5))
end

-- ===== Optionen › Grafik =====
function G:RegisterSettings(ui)
    if not (ui and ui.AddSetting and ui.AddCategory) or self.registered then return end
    self.registered = true
    ui:AddCategory("graphics", {title = "Grafik", order = 2.5})
    local function Set(section, o) o.category, o.section = "graphics", section ui:AddSetting(o) end
    Set(nil, {id = "gfxHint", kind = "text", order = 1,
        label = "Versteckte Grafik-Einstellungen von WoW, die das Spielmenü nicht anbietet. Es erscheint nur, was es in deinem Spiel gibt. Vor der ersten Änderung merkt sich Guild Trip deine bisherigen Werte."})
    -- Vorlagen
    for i, p in ipairs(G.PRESETS) do
        Set("Vorlagen", {id = "gfxPreset_" .. p.id, kind = "button", label = p.name, tooltip = p.tip, width = 200, order = 10 + i,
            onClick = function() G:ApplyPreset(p.id) ONE:Print(T("Grafik-Vorlage „%s“ gesetzt.", T(p.name))) end})
    end
    Set("Vorlagen", {id = "gfxDefault", kind = "button", label = "WoW-Standard", width = 200, order = 18,
        tooltip = "Alle Einstellungen, die Guild Trip geändert hat, zurück auf den WoW-Standard.",
        onClick = function() G:ResetAll(false) G:Store().preset = nil ONE:Print(T("Grafik: zurück auf WoW-Standard.")) end})
    Set("Vorlagen", {id = "gfxBackup", kind = "button", label = "Wie vorher", width = 200, order = 19,
        tooltip = "Alles so, wie es vor Guild Trip war.",
        visible = function() return G:HasBackup() end,
        onClick = function() G:ResetAll(true) G:Store().preset = nil ONE:Print(T("Grafik: alles wie vorher.")) end})
    Set("Vorlagen", {id = "gfxReapply", label = "Beim Einloggen neu setzen", order = 20,
        tooltip = "Das WoW-Grafikmenü setzt Gras und Wetter manchmal zurück. Damit setzt Guild Trip deine Werte bei jedem Einloggen wieder.",
        get = function() return G:Store().reapply == true end,
        set = function(on) G:Store().reapply = on and true or nil if on then G:Reapply() end end})
    -- Einzelne Einstellungen
    for _, s in ipairs(G.SETTINGS) do
        local cvar = s[1]
        local visible = function() return G:Has(cvar) end
        if not s[6] then
            Set(s[3], {id = "gfx_" .. cvar, label = s[2], tooltip = s[7], order = 100 + s.order, visible = visible,
                get = function() return tonumber(G.Get(cvar) or 0) == 1 end,
                set = function(on) G:Set(cvar, on and 1 or 0) end})
        else
            Set(s[3], {id = "gfx_" .. cvar, kind = "custom", order = 100 + s.order, visible = visible, build = function(row, w)
                return G:BuildSlider(row, w, s)
            end})
        end
    end
end

function G:BuildSlider(row, w, s)
    local ui = ONE.UI
    local cvar = s[1]
    local sw = math.min(w - 110, 300)
    ui.OptionLabel(row, T(s[2]), "GameFontHighlight", 4, -2, sw - 60, "text")
    local value = ui.OptionLabel(row, "", "GameFontHighlight", sw - 56, -2, 60, "text")
    if value.SetJustifyH then value:SetJustifyH("RIGHT") end
    local slider = ui.OptionSlider(row, 4, -22, sw)
    slider:SetMinMaxValues(s[4], s[5])
    slider:SetValueStep(s[6])
    local updating
    slider:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        local n = G.Clamp(cvar, v)
        value:SetText(G.Format(cvar, n))
        if n and tostring(n) ~= G.Get(cvar) and tonumber(G.Get(cvar)) ~= n then G:Set(cvar, n) end
    end)
    if s[7] and slider.HookScript then
        local function Tip(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(T(s[2]), 1, .82, 0)
            GameTooltip:AddLine(T(s[7]), 1, 1, 1, true)
            local d = G.Default(cvar)
            if d then GameTooltip:AddLine(T("WoW-Standard: %s", G.Format(cvar, d)), .7, .7, .7) end
            GameTooltip:Show()
        end
        slider:HookScript("OnEnter", Tip)
        slider:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    if ONE.Widgets and ONE.Widgets.Button then
        ONE.Widgets:Button(row, T("Standard"), 80, 20, "TOPLEFT", sw + 16, -18, function()
            G:Reset(cvar, false)
            if ui.Refresh then ui:Refresh() end
        end)
    end
    return function()
        local n = tonumber(G.Get(cvar))
        updating = true
        if n and slider.SetValue then slider:SetValue(n) end
        updating = nil
        value:SetText(G.Format(cvar, n))
    end, 48
end

-- ===== Start =====
function G:Initialize()
    if self.started then return end
    self.started = true
    if ONE.RegisterSlash then
        ONE:RegisterSlash("grafik", function()
            if ONE.UI and ONE.UI.OpenOptions then ONE.UI:OpenOptions("graphics") end
        end, T("Versteckte Grafik-Einstellungen öffnen"))
    end
    if type(CreateFrame) ~= "function" then return end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(frame)
        pcall(frame.UnregisterEvent, frame, "PLAYER_ENTERING_WORLD")
        pcall(G.Reapply, G)
    end)
end
