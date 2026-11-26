-- Guild Trip Navi: Orte im Chat (Chat-Ideen 24.11.2026, Punkt 1, Nutzer: „Ja, loslegen“).
-- * Kartenmarkierung (WoW-Link |Hworldmap:Karte:x:y|h, z. B. per Umschalt+Klick auf die Karte gepostet):
--   Maus drueber zeigt Gebiet + Koordinaten, Klick startet das Guild-Trip-Navi dorthin.
-- * Getippte Koordinaten („45.2, 60.1“, „45,2 60,1“, „(52, 30)“) werden in der ANZEIGE klickbar
--   (|Hgtcoord:…|h, nie gesendet): Klick = Navi dorthin in deinem jetzigen Gebiet.
-- * Umschalt+Klick auf die Weltkarte, waehrend du im Guild-Trip-Chat tippst: WoW-Kartenmarkierung dort
--   setzen und ihren Link ins Eingabefeld (sonst wie bisher: Navi dorthin, Waypoints.lua).
-- Gilt im Guild-Trip-Chat in Fenster, Randleiste und Klassisch (ONE.LinkTips, ONE_Core).
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local CL = {COLOR = "ff66ddff"}
nav.ChatLinks = CL

if ONE.RegisterFeature then
    ONE:RegisterFeature("nav.chatCoords", {module = "nav", section = "Koordinaten", order = 52,
        label = "Koordinaten im Chat anklickbar",
        tooltip = "Getippte Koordinaten wie „45.2, 60.1“ und Kartenmarkierungen im Guild-Trip-Chat: Klick startet das Navi dorthin."})
end
local function On() return not ONE.FeatureOn or ONE:FeatureOn("nav.chatCoords") end

local function Num(s) return tonumber((tostring(s):gsub(",", "."))) end
local function IsDigitOrDot(b) return b and ((b >= 48 and b <= 57) or b == 46 or b == 44) end

-- Muster: beide Zahlen mit Nachkommastelle („45.2 60.1“, „45,2 / 60,1“, „45.2,60.1“) oder in Klammern „(52, 30)“
CL.PATTERNS = {
    "()(%d%d?[%.,]%d%d?)%s*[/;]?%s+(%d%d?[%.,]%d%d?)()",
    "()(%d%d?%.%d%d?)%s*,%s*(%d%d?%.%d%d?)()",
    "()%((%d%d?)%s*,%s*(%d%d?)%)()",
}
-- Fundstellen {from, to, x, y} (x, y 0..1) in Text ohne Links
function CL.Find(text)
    local hits, taken = {}, {}
    if type(text) ~= "string" or text == "" then return hits end
    for _, pat in ipairs(CL.PATTERNS) do
        for a, sx, sy, b in text:gmatch(pat) do
            local x, y = Num(sx), Num(sy)
            local okEdge = not IsDigitOrDot(text:byte(a - 1)) and not IsDigitOrDot(text:byte(b))
            if okEdge and x and y and x > 0 and y > 0 and x < 100 and y < 100 then
                local free = true
                for i = a, b - 1 do if taken[i] then free = false break end end
                if free then
                    for i = a, b - 1 do taken[i] = true end
                    hits[#hits + 1] = {from = a, to = b - 1, x = x / 100, y = y / 100}
                end
            end
        end
    end
    table.sort(hits, function(p, q) return p.from < q.from end)
    return hits
end

local function MarkPlain(text)
    local hits = CL.Find(text)
    if #hits == 0 then return text end
    local out, pos = {}, 1
    for _, h in ipairs(hits) do
        out[#out + 1] = text:sub(pos, h.from - 1)
        out[#out + 1] = ("|Hgtcoord:%d:%d|h|c%s%s|r|h"):format(math.floor(h.x * 1000 + .5), math.floor(h.y * 1000 + .5), CL.COLOR, text:sub(h.from, h.to))
        pos = h.to + 1
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out)
end
function CL.Mark(text)
    if type(text) ~= "string" or text == "" or not On() then return text end
    local LT = ONE.LinkTips
    if LT and LT.EachPlain then return LT.EachPlain(text, MarkPlain) end
    return text:find("|H", 1, true) and text or MarkPlain(text)
end

local function MapName(mapID)
    local CM = rawget(_G, "C_Map")
    local ok, info = pcall(CM and CM.GetMapInfo, mapID)
    return ok and type(info) == "table" and info.name or nil
end
local function Here() return nav.Travel and nav.Travel.PlayerMapPosition and nav.Travel.PlayerMapPosition() end

-- "gtcoord:452:601" -> x, y (0..1), Karte = wo du gerade bist
function CL.ParseCoord(link)
    local a, b = tostring(link or ""):match("^gtcoord:(%d+):(%d+)")
    if not a then return nil end
    return tonumber(a) / 1000, tonumber(b) / 1000
end
-- "worldmap:1413:4520:6010" -> Karte, x, y (0..1)
function CL.ParseMap(link)
    local m, a, b = tostring(link or ""):match("^worldmap:(%d+):(%d+):(%d+)")
    if not m then return nil end
    return tonumber(m), tonumber(a) / 10000, tonumber(b) / 10000
end

function CL.CoordLines(link)
    local x, y = CL.ParseCoord(link)
    if not x then return nil end
    local here = Here()
    local zone = here and MapName(here)
    local lines = {{T("Koordinaten %.1f, %.1f", x * 100, y * 100), 1, .82, 0}}
    if zone then lines[#lines + 1] = {T("In deinem Gebiet: %s", zone), .8, .8, .8}
    else lines[#lines + 1] = {T("Deine Position ist hier nicht verfügbar (Instanz?)"), .7, .7, .7} end
    lines[#lines + 1] = {T("Meint der Schreiber ein anderes Gebiet, stimmt das Ziel nicht."), .6, .6, .6}
    lines[#lines + 1] = {T("Klick: Navi dorthin"), .5, .5, .5}
    return lines
end
function CL.MapLines(link)
    local mapID, x, y = CL.ParseMap(link)
    if not mapID then return nil end
    local lines = {{T("Kartenmarkierung"), 1, .82, 0}}
    lines[#lines + 1] = {("%s %.1f, %.1f"):format(MapName(mapID) or T("Gebiet %d", mapID), x * 100, y * 100), .8, .8, .8}
    lines[#lines + 1] = {T("Klick: Navi dorthin"), .5, .5, .5}
    return lines
end

local function Fill(tt, lines) return ONE.LinkTips and ONE.LinkTips.FillTip(tt, lines) or false end
function CL.OpenCoord(link)
    local x, y = CL.ParseCoord(link)
    local mapID = Here()
    if not (x and nav.Arrow) then return false end
    if not mapID then ONE:Print(T("Deine Position ist hier nicht verfügbar (Instanz?)")) return false end
    return nav.Arrow:StartPoint(("%s %.1f, %.1f"):format(MapName(mapID) or T("Wegpunkt"), x * 100, y * 100), mapID, x, y) ~= false
end
function CL.OpenMap(link)
    local mapID, x, y = CL.ParseMap(link)
    if not (mapID and nav.Arrow) then return false end
    return nav.Arrow:StartPoint(("%s %.1f, %.1f"):format(MapName(mapID) or T("Kartenmarkierung"), x * 100, y * 100), mapID, x, y) ~= false
end

-- ===== Umschalt+Klick auf die Weltkarte, waehrend du im Guild-Trip-Chat tippst =====
-- Eingabefeld des Guild-Trip-Chats mit Fokus?
function CL.ChatInput()
    local chat = ONE.ns and ONE.ns.chat
    local box = chat and chat.UI and chat.UI.input
    if box and box.HasFocus and box:HasFocus() then return box end
end
-- WoW-Kartenmarkierung setzen und ihren Link liefern
function CL.MapLink(mapID, x, y)
    local CM = rawget(_G, "C_Map")
    if CM and type(CM.SetUserWaypoint) == "function" and rawget(_G, "UiMapPoint") and UiMapPoint.CreateFromCoordinates then
        local okP, point = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y)
        if okP and point then pcall(CM.SetUserWaypoint, point) end
        if type(CM.GetUserWaypointHyperlink) == "function" then
            local ok, link = pcall(CM.GetUserWaypointHyperlink)
            if ok and type(link) == "string" and link:find("|Hworldmap:", 1, true) then return link end
        end
    end
    local label = rawget(_G, "MAP_PIN_HYPERLINK") or T("Kartenmarkierung")
    return ("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(mapID, math.floor(x * 10000 + .5), math.floor(y * 10000 + .5), label)
end
-- true = Link ins Eingabefeld gesetzt (dann kein Navi)
function CL.MapClickToChat(mapID, x, y)
    if not On() then return false end
    local box = CL.ChatInput()
    if not box then return false end
    local link = CL.MapLink(mapID, x, y)
    if box.Insert then box:Insert(link) else box:SetText((box:GetText() or "") .. link) end
    return true
end

if ONE.LinkTips and ONE.LinkTips.Handle then
    ONE.LinkTips:Handle("gtcoord", {plain = true, tip = function(tt, link) return Fill(tt, CL.CoordLines(link)) end, open = CL.OpenCoord})
    ONE.LinkTips:Handle("worldmap", {tip = function(tt, link) return Fill(tt, CL.MapLines(link)) end, open = CL.OpenMap})
    ONE.LinkTips:AddMarker("coords", CL.Mark)
end
