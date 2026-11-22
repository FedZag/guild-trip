-- Pruefung: /trip navilog (22.11.2026) – wer setzt den Navi-Pfeil? Spieltest: Klick auf der Ausruestungs-Seite
-- meldet "Navi zum Questgeber", der Pfeil zeigt aber weiter auf das Ziel der Quest-Fuehrung.
-- Schreibt die letzten 12 Zielwechsel mit Uhrzeit und Aufrufer mit (auch in GuildTripDevDB.naviLog).
local ONE = _G.ProjectONE
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end
local log = {}
local function Caller()
    if type(debugstack) ~= "function" then return "?" end
    local st = debugstack(3, 4, 0) or ""
    local out = {}
    for file, line in st:gmatch("AddOns[\\/]([^%]\"']-%.lua)\"?%]?:(%d+)") do out[#out + 1] = file:gsub("^ONE_", "") .. ":" .. line end
    return table.concat(out, " < ")
end
local function Add(kind, label)
    local t = (type(date) == "function" and date("%H:%M:%S") or "?") .. (type(GetTime) == "function" and string.format(" (%.0f)", GetTime()) or "")
    table.insert(log, 1, {t = t, kind = kind, label = tostring(label), from = Caller()})
    while #log > 12 do table.remove(log) end
    local db = DevDB()
    if db then db.naviLog = log end
end
local function Hook()
    local nav = ONE.ns and ONE.ns.nav
    local A = nav and nav.Arrow
    if not A or A.__naviLog then return false end
    A.__naviLog = true
    for _, name in ipairs({"StartPoint", "StartWorld", "Start", "Stop"}) do
        local orig = A[name]
        if type(orig) == "function" then
            A[name] = function(self, label, ...)
                Add(name, label)
                return orig(self, label, ...)
            end
        end
    end
    return true
end
if not Hook() and CreateFrame then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() Hook() end)
end
ONE:RegisterSlash("navilog", function()
    Hook()
    -- aelteste zuerst, neueste ganz unten (im Chat ohne Scrollen sichtbar); dazu, was der Pfeil gerade zeigt
    ONE:Print(("Navi-Protokoll (%d Einträge, neueste unten):"):format(#log))
    for i = math.min(6, #log), 1, -1 do
        local e = log[i]
        ONE:Print(("%s %s „%s“ – %s"):format(e.t, e.kind, e.label, e.from))
    end
    local A = ONE.ns and ONE.ns.nav and ONE.ns.nav.Arrow
    if A then
        ONE:Print(("Jetzt: aktiv=%s Ziel=„%s“ Probe=„%s“ Titel=„%s“ weitergegeben=%s"):format(tostring(A.active), tostring(A.target),
            tostring(A.probe and A.probe.name), tostring(A.title and A.title.GetText and A.title:GetText()), tostring(A.delegated)))
    end
end)
