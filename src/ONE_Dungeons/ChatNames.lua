-- Guild Trip Dungeons: Dungeon-Namen im Chat (Chat-Ideen 24.11.2026, Punkt 2, Nutzer: „2 und 3 klingt richtig gut“).
-- „LFG Todesminen“, „wer kommt mit SFK?“: der Name wird in der Anzeige farbig und zum Guild-Trip-Link
-- (|Hgtdungeon:KEY|h…|h). Maus drueber: Stufe, passt es zu dir, deine Quests dort. Klick: Dungeon-Seite.
-- Nur die ANZEIGE wird markiert – gespeicherter Text, Kopieren, Zitieren und Senden bleiben unveraendert,
-- der Link geht also nie an andere Spieler. Gilt in Fenster, Randleiste und Klassisch (ONE_Chat ruft
-- ONE.DungeonChat auf); Blizzards WoW-Chat bleibt unberuehrt.
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local DC = {KIND = "gtdungeon", COLOR = "ffff9a3d"}
dungeons.ChatNames = DC
ONE.DungeonChat = DC

-- Kurzformen aus dem Chat. Zweibuchstabige nur in GROSSBUCHSTABEN (sonst „wc“, „dm“ in normalen Saetzen).
DC.UPPER = {WC = "wc", DM = "dm", SM = "sm", ZF = "zf", ST = "st", DME = "dme", DMW = "dmw", DMN = "dmn"}
DC.ANY = {
    rfc = "rfc", sfk = "sfk", bfd = "bfd", rfk = "rfk", rfd = "rfd", brd = "brd", lbrs = "lbrs", ubrs = "ubrs",
    deadmines = "dm", todesminen = "dm", shadowfang = "sfk", stockade = "stocks", stockades = "stocks", stocks = "stocks",
    gnomer = "gnomer", kloster = "sm", ulda = "ulda", mara = "mara", strat = "stratlive", scholo = "scholo",
    ragefire = "rfc", wehklagen = "wc", ["kral"] = "rfk", stratholme = "stratlive",
    ["düsterbruch"] = "dme", ["dire maul"] = "dme",
}

DC.SKIP = {dalaran = true}

local function Lower(s) return (tostring(s or ""):lower()) end
-- Buchstabe/Ziffer (auch Umlaute: Bytes ab 128 gehoeren zum Wort)
local function IsWordByte(b) return b and (b >= 128 or (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)) end

-- Suchliste: {needle (klein), key, exact = Grossschreibung pruefen}
function DC.Needles()
    if DC.needles then return DC.needles end
    local list, seen = {}, {}
    local function Add(text, key, exact)
        if type(text) ~= "string" or text == "" then return end
        local n = exact and text or Lower(text)
        local id = n .. "\0" .. key
        if seen[id] then return end
        seen[id] = true
        list[#list + 1] = {needle = n, key = key, exact = exact, len = #n}
    end
    for _, e in ipairs(dungeons.Catalog or {}) do
        -- „Dalaran“ ist auch die Stadt – im Chat meist die Stadt gemeint
        for _, name in ipairs(DC.SKIP[e.key] and {} or {e.name, e.en}) do
            if type(name) == "string" then
                Add(name, e.key)
                -- ohne Artikel: „Verlies“, „Deadmines“, „Drowned City“
                local bare = name:gsub("^Das ", ""):gsub("^Die ", ""):gsub("^The ", "")
                if bare ~= name and #bare >= 6 then Add(bare, e.key) end
            end
        end
    end
    local valid = {}
    for _, e in ipairs(dungeons.Catalog or {}) do valid[e.key] = true end
    for short, key in pairs(DC.UPPER) do if valid[key] then Add(short, key, true) end end
    for short, key in pairs(DC.ANY) do if valid[key] then Add(short, key) end end
    -- laengere zuerst: „Burg Shadowfang“ vor „Shadowfang“, „Untere Blackrockspitze“ vor „Blackrock…“
    table.sort(list, function(a, b) if a.len ~= b.len then return a.len > b.len end return a.needle < b.needle end)
    DC.needles = list
    return list
end

-- Fundstellen in einem Textstueck ohne Links: {from, to, key}, ohne Ueberlappung
function DC.Find(text)
    local found, taken = {}, {}
    if type(text) ~= "string" or text == "" then return found end
    local low = Lower(text)
    for _, n in ipairs(DC.Needles()) do
        local hay = n.exact and text or low
        local init = 1
        while true do
            local a, b = hay:find(n.needle, init, true)
            if not a then break end
            init = b + 1
            if not IsWordByte(hay:byte(a - 1)) and not IsWordByte(hay:byte(b + 1)) then
                local free = true
                for i = a, b do if taken[i] then free = false break end end
                if free then
                    for i = a, b do taken[i] = true end
                    found[#found + 1] = {from = a, to = b, key = n.key}
                end
            end
        end
    end
    table.sort(found, function(x, y) return x.from < y.from end)
    return found
end

function DC.Enabled()
    if ONE.FeatureOn and not ONE:FeatureOn("dungeons.chatNames") then return false end
    return true
end

-- Ein Stueck ohne Links markieren; Farbcodes im Stueck stoeren nicht (Name bleibt zusammenhaengend)
local function MarkPlain(text)
    local hits = DC.Find(text)
    if #hits == 0 then return text end
    local out, pos = {}, 1
    for _, h in ipairs(hits) do
        out[#out + 1] = text:sub(pos, h.from - 1)
        out[#out + 1] = "|H" .. DC.KIND .. ":" .. h.key .. "|h|c" .. DC.COLOR .. text:sub(h.from, h.to) .. "|r|h"
        pos = h.to + 1
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out)
end

-- Anzeige-Text: Dungeon-Namen als Guild-Trip-Link. Vorhandene Links (|H…|h…|h) bleiben unberuehrt.
function DC.Mark(text)
    if type(text) ~= "string" or text == "" or not DC.Enabled() then return text end
    local LT = ONE.LinkTips
    if LT and LT.EachPlain then return LT.EachPlain(text, MarkPlain) end
    return text:find("|H", 1, true) and text or MarkPlain(text)
end

function DC.KeyOf(link)
    return type(link) == "string" and link:match("^" .. DC.KIND .. ":([%w_]+)") or nil
end
function DC.IsLink(link) return DC.KeyOf(link) ~= nil end

-- Dungeon aus dem Modell (Stufen aus der Gruppensuche, Quests fuer diesen Charakter)
function DC.Info(key)
    local M = dungeons.Model
    if not M then return nil end
    for _, d in ipairs(M:Dungeons()) do if d.key == key then return d end end
    -- andere Fraktion: Model:Dungeons laesst ihn weg -> nur Katalog
    for _, e in ipairs(dungeons.Catalog or {}) do
        if e.key == key then return {key = key, entry = e, name = e.name, en = e.en, min = e.min, max = e.max, quests = {}, otherFaction = true} end
    end
end

-- Zeilen fuer den Tooltip: {{text, r, g, b}, ...}
function DC.Lines(key)
    local d = DC.Info(key)
    if not d then return nil end
    local M = dungeons.Model
    local lines = {}
    local title = d.name
    if d.en and d.en ~= d.name and not (ONE.Language and ONE:Language() == "en") then title = title .. " (" .. d.en .. ")" end
    lines[#lines + 1] = {title, 1, .82, 0}
    if d.otherFaction then
        lines[#lines + 1] = {T("Stufe %d–%d · Eingang im Gebiet der anderen Fraktion", d.min, d.max), .7, .7, .7}
        return lines
    end
    local level = M:PlayerLevel()
    local kind, color = M:Difficulty(d.min, d.max, level)
    local verdict = ({hard = "zu schwer für dich", medium = "etwas schwer für dich", fit = "passt zu deiner Stufe",
        easy = "leicht für dich", trivial = "zu niedrig für dich"})[kind] or ""
    lines[#lines + 1] = {T("Stufe %d–%d · %s", d.min, d.max, T(verdict)), color[1], color[2], color[3]}
    if not d.hasData then
        lines[#lines + 1] = {T("Noch keine Questdaten (neuer Forever-Dungeon)"), .7, .7, .7}
    else
        local open, inLog, done = 0, 0, 0
        for _, q in ipairs(d.quests or {}) do
            local s = M:Status(q)
            if s == "done" then done = done + 1 elseif s == "log" then inLog = inLog + 1 open = open + 1 else open = open + 1 end
        end
        if open == 0 and done == 0 then
            lines[#lines + 1] = {T("Keine Quests dort für dich"), .7, .7, .7}
        elseif open == 0 then
            lines[#lines + 1] = {T("Alle %d Quests dort erledigt", done), .25, .75, .25}
        else
            local text = inLog > 0 and T("Deine Quests dort: %d offen, davon %d im Questlog", open, inLog) or T("Deine Quests dort: %d offen", open)
            lines[#lines + 1] = {text, .5, .85, 1}
        end
    end
    lines[#lines + 1] = {T("Klick: Dungeon-Seite öffnen"), .5, .5, .5}
    return lines
end

function DC.Tip(tt, link)
    local key = DC.KeyOf(link)
    local lines = key and DC.Lines(key)
    if not (tt and lines) then return false end
    for i, l in ipairs(lines) do
        if i == 1 and tt.SetText then tt:SetText(l[1], l[2], l[3])
        else tt:AddLine(l[1], l[2], l[3], true) end
    end
    if tt.Show then tt:Show() end
    return true
end

-- im Chat anmelden (ONE_Core/LinkTips.lua)
if ONE.LinkTips and ONE.LinkTips.Handle then
    ONE.LinkTips:Handle(DC.KIND, {tip = DC.Tip, open = DC.Open, plain = true})
    ONE.LinkTips:AddMarker("dungeons", DC.Mark)
end

-- Klick: Hauptfenster auf der Dungeon-Seite, dieser Dungeon gewaehlt
function DC.Open(link)
    local key = DC.KeyOf(link)
    if not key then return false end
    if dungeons.Page then dungeons.Page.wantKey = key end
    local UI = ONE.UI
    if UI then
        if UI.Show then pcall(UI.Show, UI) end
        if UI.Navigate then pcall(UI.Navigate, UI, "dungeons") end
    end
    if dungeons.Page and dungeons.Page.Refresh then pcall(dungeons.Page.Refresh, dungeons.Page) end
    return true
end
