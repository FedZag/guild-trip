-- Guild Trip Navi: Begleitzeile am Pfeil (Idee „Reisezettel“ vom 17.11.2026, Nutzer 25.11.: „kannst du gerne bauen“).
-- Unter dem Navi-Pfeil, was das Ziel nicht schon sagt: wer aus der Gilde in der Naehe ist (nur wer seine Position
-- teilt) und der naechste Gildenausflug. Leer = Zeile weg. Schalter „nav.arrowCompanion“, im Aussehen „Kompakt“/
-- „Minimal“ ausgeblendet.
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local C = {NEAR = 500, MAX_NAMES = 3, TRIP_AHEAD = 7 * 86400, EVERY = 3}
nav.Companion = C

if ONE.RegisterFeature then
    ONE:RegisterFeature("nav.arrowCompanion", {module = "nav", section = "Pfeil", order = 12,
        label = "Am Pfeil: Gilde in der Nähe und nächster Ausflug",
        tooltip = "Eine kleine Zeile unter dem Navi-Pfeil: wer aus der Gilde in der Nähe ist (wenn er seine Position teilt) und wann der nächste Gildenausflug ist."})
end
local function On() return not ONE.FeatureOn or ONE:FeatureOn("nav.arrowCompanion") end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end

-- Gildenmitglieder in der Naehe: {{name, yards}, …} nach Entfernung
function C.NearGuild()
    local guild = ONE.modules and ONE.modules.guild
    local peers = guild and guild.LivePeers and guild:LivePeers() or {}
    local Travel = nav.Travel
    local pc, px, py = Travel.PlayerWorld()
    if not pc then return {} end
    local out = {}
    for _, p in ipairs(peers) do
        local c, x, y = Travel.World(p.mapID, p.x, p.y)
        if c == pc and x then
            local d = Travel.Distance(px, py, x, y)
            if d <= C.NEAR then out[#out + 1] = {name = Short(p.name), yards = d} end
        end
    end
    table.sort(out, function(a, b) return a.yards < b.yards end)
    return out
end

-- Naechster Gildenausflug in den naechsten 7 Tagen (laufende zaehlen auch): trip, Start
function C.NextTrip()
    local d = ONE.ns and ONE.ns.dungeons
    local Trips = d and d.Trips
    if not (Trips and Trips.List) then return nil end
    local ok, list = pcall(Trips.List, Trips)
    if not ok or type(list) ~= "table" then return nil end
    local now = Trips:Now()
    local best
    for _, t in ipairs(list) do
        local s = tonumber(t.start)
        if s and s + (Trips.keep or 0) >= now and s - now <= C.TRIP_AHEAD and (not best or s < best.start) then best = t end
    end
    return best, Trips
end

local WEEKDAYS = {"So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"}
function C.When(start, now)
    if type(date) ~= "function" then return "" end
    if start <= now then return T("läuft") end
    local day = (date("%Y%m%d", start) == date("%Y%m%d", now)) and T("heute")
        or (date("%Y%m%d", start) == date("%Y%m%d", now + 86400)) and T("morgen")
        or T(WEEKDAYS[tonumber(date("%w", start)) + 1])
    return day .. " " .. date("%H:%M", start)
end

-- Text der Zeile oder nil
function C.Text()
    if not On() then return nil end
    local parts = {}
    local near = C.NearGuild()
    if #near > 0 then
        local names = {}
        for i = 1, math.min(#near, C.MAX_NAMES) do
            names[#names + 1] = near[i].name .. " " .. nav.Travel.FormatDistance(near[i].yards)
        end
        if #near > C.MAX_NAMES then names[#names + 1] = T("+%d", #near - C.MAX_NAMES) end
        parts[#parts + 1] = T("Gilde in der Nähe: %s", table.concat(names, ", "))
    end
    local trip, Trips = C.NextTrip()
    if trip then
        local okName, name = pcall(Trips.Name, Trips, trip)
        if not okName then name = trip.title end
        parts[#parts + 1] = T("Ausflug: %s", C.When(trip.start, Trips:Now()) .. (type(name) == "string" and name ~= "" and (" · " .. name) or ""))
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- Am Pfeil auffrischen (gedrosselt)
function C:Update(fs, now)
    if not fs then return end
    if self.at and now and now - self.at < self.EVERY then return end
    self.at = now
    local ok, text = pcall(C.Text)
    text = ok and text or nil
    fs:SetText(text or "")
    if fs.SetShown then fs:SetShown(text ~= nil) end
end
