-- Guild Trip Quest-Fuehrung: Einstellungen stehen in Optionen › Leveln (0.6.9, alle Einstellungen
-- zentral, Nutzer 17.11.2026, keine Doppelungen). Das Zahnrad am Kasten springt genau dorthin.
-- Reparieren/Schrott verkaufen gehoeren nicht zur Fuehrung und stehen unter Optionen › Allgemein.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local S = {}
lev.Settings = S
local G = lev.Guide

-- Schalter (Schluessel in db.leveling), nach Abschnitten
S.SECTIONS = {
    {title = "Kasten „Quest-Führung“", options = {
        {key = "tracker", label = "Kasten anzeigen", default = true,
            tip = "Der Kasten unter der Minimap mit dem nächsten Schritt der Quest-Führung. Aus: Führung läuft weiter, nur ohne Kasten."},
        {key = "trackerBare", label = "Ohne Rahmen (nur Text)",
            tip = "Zeigt nur den Text; der Rahmen erscheint kurz, wenn die Maus darüber ist (zum Verschieben)."},
        {key = "replaceBlizzard", label = "WoW-Questliste durch den Kasten ersetzen",
            tip = "Blendet die WoW-Liste „Alle Ziele / Quests“ aus. Alle Quests siehst du weiter mit L, den Fortschritt der aktuellen Quest im Kasten unter „Jetzt“. Ausschalten stellt alles wieder her."},
    }},
    {title = "Navi und Quests", options = {
        {key = "autoNavi", label = "Navi-Pfeil folgt der Führung", default = true,
            tip = "Ist ein Schritt erledigt, zeigt der Pfeil von selbst zum nächsten – nur solange der Kasten an ist und du das Navi nicht selbst woandershin gestellt hast."},
        {key = "autoQuest", label = "Quests automatisch annehmen und abgeben",
            tip = "Nimmt eingeplante Quests an und gibt fertige Quests aus deinem Questlog ab (Folgequests inklusive). Bei mehreren Belohnungen wählst du selbst. Shift gedrückt halten = für dieses Gespräch nicht."},
        {key = "autoQuestAll", label = "… auch Quests außerhalb der Führung annehmen", indent = 1,
            tip = "Nimmt alle nicht-grauen, nicht wiederholbaren Quests an."},
        {key = "gearQuests", label = "Ausrüstungs-Quests einbauen", default = true,
            tip = "Baut Quests mit deutlich besserer Ausrüstung (ab 10 % besser oder leerer Platz) in die Route ein – nur ohne Dungeon, höchstens 3 Stufen über dir und nur in Gebieten, durch die die Route ohnehin kommt. Ändert nur die Vorschläge."},
    }},
    {title = "Reisetagebuch", options = {
        {key = "journal", label = "Reisetagebuch führen", default = true,
            tip = "Merkt sich abgegebene Quests, Stufenaufstiege, neue Gebiete und Dungeon-Läufe mit Datum und Ort (Leveln › Tagebuch). Nur bei dir gespeichert."},
    }},
}

function S.Value(o)
    local v = G:DB()[o.key]
    if v == nil then v = o.default or false end
    return v == true
end

function S:Set(key, value)
    local db = G:DB()
    if key == "trackerScale" then lev.Tracker:SetScale(value)
    else db[key] = value and true or false end
    -- "Ohne Rahmen" hier = Hintergrund "Unsichtbar" im Zahnrad-Menue (gleiche Einstellung)
    if key == "trackerBare" and type(db.trackerLook) == "table" then
        db.trackerLook.bg = value and "none" or nil
        db.trackerLook.alpha = nil
        if not value and db.trackerLook.preset and lev.Tracker.PRESETS[db.trackerLook.preset] then
            local bg = lev.Tracker.PRESETS[db.trackerLook.preset].bg
            db.trackerLook.bg = bg ~= "none" and bg or "dark"
        end
    end
    if key == "gearQuests" then G:Replan() else lev.Tracker:Update(G.plan) end
    if ONE.UI and ONE.UI.Refresh then ONE.UI:Refresh() end
end


-- Kasten auf Lage/Groesse/Schrift ab Werk
function S:ResetTracker()
    local db, Tr = G:DB(), lev.Tracker
    db.trackerPos, db.trackerWidth, db.trackerHeight, db.trackerScale = nil, nil, nil, nil
    if Tr.frame then Tr.frame:SetScale(Tr.SCALE) Tr.frame:SetSize(Tr.WIDTH, Tr.HEIGHT) end
    Tr:Place()
    Tr:Update(G.plan)
    if ONE.UI and ONE.UI.Refresh then ONE.UI:Refresh() end
end

-- Schriftgroesse im Kasten: A − 115 % A +
local function BuildScale(row, w)
    local Tr = lev.Tracker
    -- schmal (Buch-Aussehen): Knoepfe unter die Beschriftung
    local bx, by = 210, -2
    if (w or 500) < 380 then bx, by = 0, -24 end
    local function Step(d) S:Set("trackerScale", (G:DB().trackerScale or Tr.SCALE) + d) end
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -6)
    label:SetText(T("Schriftgröße im Kasten"))
    if ONE.Themes then ONE.Themes:RegisterText(label, "text") end
    row.smaller = ONE.Widgets:Button(row, "A −", 44, 22, "TOPLEFT", bx, by, function() Step(-.05) end)
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("TOPLEFT", row, "TOPLEFT", bx + 50, by - 4)
    value:SetWidth(48)
    value:SetJustifyH("CENTER")
    if ONE.Themes then ONE.Themes:RegisterText(value, "text") end
    row.bigger = ONE.Widgets:Button(row, "A +", 44, 22, "TOPLEFT", bx + 102, by, function() Step(.05) end)
    row.scaleText = value
    return function() value:SetText(math.floor((G:DB().trackerScale or Tr.SCALE) * 100 + .5) .. " %") end, by == -2 and 30 or 52
end

-- In Optionen › Leveln anmelden (Abschnitte wie frueher in der Ansicht "Einstellungen")
function S:Register()
    local UI = ONE.UI
    if not (UI and UI.AddSetting) then return false end
    local function Add(o) o.category, o.module = "leveling", "leveling" UI:AddSetting(o) end
    -- keine Tempo-Wahl mehr (Nutzer 22.11.2026): eine feste Route, die schnellste; wer mehr questen will, nimmt
    -- Quests selbst an – sie werden eingebaut, wenn sie ohne grossen Umweg passen
    -- Sehr empfohlene Reihe (Schlafsack) mit Vorrang – je Figur (Frage im Kasten ab Stufe 14)
    Add({id = "lev.recFirst", section = "Navi und Quests", order = 45, label = "Schlafsack-Reihe mit Vorrang (diese Figur)",
        tooltip = "Die Schritte der Questreihe zum Schlafsack kommen zuerst, auch mit weitem Weg. Aus: Die Reihe läuft ohne Vorrang mit.",
        get = function() return G:RecChoice("sleepingbag") == "now" end,
        set = function(on) G:SetRecChoice("sleepingbag", on and "now" or "later") end})
    for i, sec in ipairs(S.SECTIONS) do
        for k, o in ipairs(sec.options) do
            Add({id = "lev." .. o.key, section = sec.title, order = 20 + i * 10 + k, label = o.label, tooltip = o.tip,
                indent = o.indent, get = function() return S.Value(o) end, set = function(on) S:Set(o.key, on) end})
        end
        -- Kasten: erst anzeigen/Aussehen, dann Schrift, ganz unten Zuruecksetzen (Gesamtpruefung 23.11.2026)
        local after = 20 + i * 10 + #sec.options
        if i == 1 then
            Add({id = "levScale", section = sec.title, order = after + 1, kind = "custom", searchText = {"Schriftgröße im Kasten"}, build = BuildScale})
            Add({id = "levSizeHint", section = sec.title, order = after + 2, kind = "text", label = "Mehr Schritte: den Kasten unten rechts größer ziehen."})
            Add({id = "levReset", section = sec.title, order = after + 3, kind = "button", label = "Kasten zurücksetzen", width = 180,
                onClick = function() S:ResetTracker() end})
        end
    end
    return true
end

-- Zahnrad am Kasten: Optionen › Leveln
function S:Open()
    local ui = ONE.UI
    if not ui then return end
    if ui.OpenOptions then ui:OpenOptions("leveling") return end
    if ui.Show then ui:Show() end
    if ui.OpenLink then ui:OpenLink("options") end
end
S.Toggle = S.Open
