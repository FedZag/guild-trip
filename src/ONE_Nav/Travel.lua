-- Project ONE Navigation, Stufe 1: Weltkoordinaten, Richtung, Reisehinweis.
-- Bewusst KEINE Wegfuehrung: Alles hier ist Luftlinie plus Faustregeln.
-- Belegt im Forever-Spieltest (10.11.2026): GetWorldPosFromMapPos und
-- GetPlayerFacing sind lesbar, auch im Kampf. Welt-X = Norden, Welt-Y = Westen.
local _, nav = ...
local ONE = _G.ProjectONE or {}
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Travel = {nearDistance = 1500, arriveDistance = 15}
nav.Travel = Travel

local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) == true
end
local function Number(v)
    return type(v) == "number" and not IsSecret(v) and v == v
end

local function Vector(x, y)
    if type(CreateVector2D) == "function" then
        local ok, v = pcall(CreateVector2D, x, y)
        if ok and v then return v end
    end
    return {x = x, y = y}
end

-- Kartenanteil (0..1) -> Kontinent-ID, Welt-X (Nord), Welt-Y (West) in Yards.
function Travel.World(mapID, x, y)
    if not (Number(mapID) and Number(x) and Number(y)) then return end
    if not (C_Map and type(C_Map.GetWorldPosFromMapPos) == "function") then return end
    local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, Vector(x, y))
    if not ok or not Number(continent) or type(pos) ~= "table" or IsSecret(pos) then return end
    local wx, wy = pos.x, pos.y
    if not (Number(wx) and Number(wy)) then return end
    return continent, wx, wy
end

function Travel.PlayerMapPosition()
    if not (C_Map and type(C_Map.GetBestMapForUnit) == "function"
        and type(C_Map.GetPlayerMapPosition) == "function") then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not Number(mapID) then return end
    local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okPos or type(pos) ~= "table" or IsSecret(pos) then return end
    local x, y = pos.x, pos.y
    if x == nil and type(pos.GetXY) == "function" then
        local good, a, b = pcall(pos.GetXY, pos)
        if good then x, y = a, b end
    end
    if Number(x) and Number(y) then return mapID, x, y end
end

function Travel.PlayerWorld()
    local mapID, x, y = Travel.PlayerMapPosition()
    if not mapID then return end
    return Travel.World(mapID, x, y)
end

function Travel.Facing()
    if type(GetPlayerFacing) ~= "function" then return end
    local ok, f = pcall(GetPlayerFacing)
    if ok and Number(f) then return f end
end

function Travel.Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x == 0 then return y >= 0 and math.pi / 2 or -math.pi / 2 end
    local a = math.atan(y / x)
    if x < 0 then a = a + (y >= 0 and math.pi or -math.pi) end
    return a
end

-- Drehwinkel fuer einen nach oben zeigenden Pfeil (gegen den Uhrzeigersinn,
-- wie GetPlayerFacing und Texture:SetRotation).
function Travel.ArrowAngle(fromX, fromY, toX, toY, facing)
    local bearing = Travel.Atan2(toY - fromY, toX - fromX)
    local angle = bearing - facing
    local tau = math.pi * 2
    angle = angle % tau
    if angle > math.pi then angle = angle - tau end
    return angle
end

function Travel.Distance(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

function Travel.FormatDistance(yards)
    local n = math.floor(yards + .5)
    local text
    if n >= 10000 then
        text = string.format("%.1fk", n / 1000)
    else
        text = tostring(n)
    end
    -- Blizzard zeigt Yards in deutschen Clients als "m"; wir bleiben dabei.
    return text .. " m"
end

local function ShortName(name)
    if type(name) ~= "string" then return "?" end
    return name:match("^([^,]+)") or name
end
Travel.ShortName = ShortName

-- Bekannte Transportwege je Fraktion (Classic-Stand; in Forever noch im Spiel
-- zu bestaetigen, siehe NAVIGATION_KONZEPT.md 1.6). Texte deutsch, beim Anzeigen
-- uebersetzt.
Travel.crossings = {
    Horde = {
        ["1>0"] = "Zeppelin ab Orgrimmar (nach Unterstadt oder Grom'gol) oder Schiff ab Ratchet nach Beutebucht",
        ["0>1"] = "Zeppelin ab Unterstadt oder Grom'gol nach Orgrimmar oder Schiff ab Beutebucht nach Ratchet",
    },
    Alliance = {
        ["1>0"] = "Schiff ab Auberdine oder Theramore nach Menethil oder Schiff ab Ratchet nach Beutebucht",
        ["0>1"] = "Schiff ab Menethil nach Auberdine oder Theramore oder Schiff ab Beutebucht nach Ratchet",
    },
}
-- Abflugorte fuer die Etappen-Navi (Classic-Koordinaten, ungefaehr; in Forever
-- zu bestaetigen). from/to = Kontinent (0 Oestliche Koenigreiche, 1 Kalimdor),
-- faction nil = beide Fraktionen.
Travel.departures = {
    {name = "Zeppelin ab Orgrimmar", faction = "Horde", from = 1, to = 0, mapID = 1411, x = .508, y = .134},
    {name = "Schiff ab Ratchet", from = 1, to = 0, mapID = 1413, x = .638, y = .387},
    {name = "Zeppelin ab Unterstadt", faction = "Horde", from = 0, to = 1, mapID = 1420, x = .607, y = .588},
    {name = "Zeppelin ab Grom'gol", faction = "Horde", from = 0, to = 1, mapID = 1434, x = .316, y = .291},
    {name = "Schiff ab Beutebucht", from = 0, to = 1, mapID = 1434, x = .258, y = .731},
    {name = "Schiff ab Auberdine", faction = "Alliance", from = 1, to = 0, mapID = 1439, x = .324, y = .438},
    {name = "Schiff ab Theramore", faction = "Alliance", from = 1, to = 0, mapID = 1445, x = .715, y = .563},
    {name = "Schiff ab Menethil", faction = "Alliance", from = 0, to = 1, mapID = 1437, x = .050, y = .600},
}

-- Naechster passender Abflugort auf dem eigenen Kontinent Richtung Zielkontinent
function Travel.Departure(player, target)
    if not (player and target) or player.continent == target.continent then return end
    local faction = Travel.Faction and Travel.Faction()
    local best, bestDistance
    for _, d in ipairs(Travel.departures) do
        if d.from == player.continent and d.to == target.continent and (not d.faction or d.faction == faction) then
            if not d.world then
                local c, wx, wy = Travel.World(d.mapID, d.x, d.y)
                d.world = c and {c, wx, wy} or false
            end
            if d.world and d.world[1] == player.continent then
                local dist = Travel.Distance(player.x, player.y, d.world[2], d.world[3])
                if not bestDistance or dist < bestDistance then best, bestDistance = d, dist end
            end
        end
    end
    if best then return {name = best.name, continent = best.world[1], x = best.world[2], y = best.world[3], distance = bestDistance} end
end

function Travel.Faction()
    local ok, faction = pcall(function() return UnitFactionGroup and UnitFactionGroup("player") end)
    return ok and faction == "Alliance" and "Alliance" or "Horde"
end

local function Nearest(nodes, continent, x, y, filter)
    local best, bestDistance
    for id, node in pairs(nodes or {}) do
        if node.continent == continent and Number(node.x) and Number(node.y)
            and (not filter or filter(id, node)) then
            local d = Travel.Distance(x, y, node.x, node.y)
            if not bestDistance or d < bestDistance then
                best, bestDistance = id, d
            end
        end
    end
    return best, bestDistance
end

-- Reisehinweis aus reinen Daten (testbar ohne Spiel).
-- player/target = {continent=, x=, y=}; nodes = {[id]={name,continent,x,y}};
-- known = {[id]=true}. Ergebnis: {kind=..., text=..., tip=...}
function Travel.Advice(player, target, nodes, known)
    if not player then
        return {kind = "noself", text = T("Deine Position ist hier nicht verfügbar (Instanz?)")}
    end
    if not target then
        return {kind = "notarget", text = T("Keine Position des Mitglieds")}
    end
    if player.continent ~= target.continent then
        local key = tostring(player.continent) .. ">" .. tostring(target.continent)
        return {kind = "continent", text = T("Anderer Kontinent – Zeppelin oder Schiff nötig"),
            tip = (Travel.crossings[Travel.Faction()][key] and T(Travel.crossings[Travel.Faction()][key]))
                or T("Weg zwischen diesen Gebieten ist Guild Trip noch unbekannt")}
    end
    local distance = Travel.Distance(player.x, player.y, target.x, target.y)
    if distance <= Travel.arriveDistance then
        return {kind = "arrived", text = T("Ihr seid am Ziel!"), distance = distance}
    end
    if distance < Travel.nearDistance then
        return {kind = "near", text = T("Gleicher Kontinent · zu Fuß oder mit Reittier"), distance = distance}
    end
    local hasKnown = false
    for id in pairs(known or {}) do
        if nodes and nodes[id] then hasKnown = true break end
    end
    if not hasKnown then
        return {kind = "far", text = T("Gleicher Kontinent · weite Strecke"), distance = distance,
            tip = T("Öffne einmal eine Flugkarte beim Flugmeister, dann kennt Guild Trip deine Flugpunkte.")}
    end
    local isKnown = function(id) return known[id] == true end
    local from, fromDistance = Nearest(nodes, player.continent, player.x, player.y, isKnown)
    local to, toDistance = Nearest(nodes, target.continent, target.x, target.y, isKnown)
    local result = {kind = "far", text = T("Gleicher Kontinent · weite Strecke"), distance = distance}
    if from and to and from ~= to and fromDistance + toDistance < distance * .6 then
        result.kind = "flight"
        result.text = T("Flugpunkt: %s › %s", ShortName(nodes[from].name), ShortName(nodes[to].name))
        result.from, result.to = from, to
    end
    local unknownNear, unknownDistance = Nearest(nodes, target.continent, target.x, target.y,
        function(id) return not known[id] end)
    if unknownNear and unknownDistance < (toDistance or distance) * .5 and unknownDistance < distance * .4 then
        result.tip = T("%s liegt näher am Ziel (noch nicht entdeckt)", ShortName(nodes[unknownNear].name))
    end
    return result
end
