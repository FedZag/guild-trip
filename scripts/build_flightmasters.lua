-- Guild Trip: Flugmeister fuer die Quest-Fuehrung erzeugen -> src/ONE_Leveling/FlightMasters.lua
--   lua5.1 scripts/build_flightmasters.lua ~/Projekte/quellen/shortest-path-forever
-- Quelle: Shortest Path Forever Data/Taxi.lua (GPL-3.0-or-later; TaxiNodes aus den Forever-Spieldaten, wago.tools)
local spf = assert(arg[1], "Pfad zu shortest-path-forever fehlt")
local ns = {}
assert(loadfile(spf .. "/Data/Taxi.lua"))("SPF", ns)
-- Gebiet je Flugpunkt (fuer "nahe Ort" nur im selben Gebiet): Name nach dem Komma = Gebiet in Data/Zones.lua (Kommentar)
local zoneByName = {}
for line in io.lines(spf .. "/Data/Zones.lua") do
    local id, name = line:match("^%s*%[(%d+)%]%s*=.-%-%-%s*(.-)%s*$")
    if id and name ~= "" and not zoneByName[name] then zoneByName[name] = tonumber(id) end
end
-- Gebiete ohne Namenskommentar in Zones.lua (Karten-Nr. per Stufenbereich in Zones.lua geprueft, 20.11.2026)
for name, zid in pairs({["Redridge"] = 1433, ["Hillsbrad"] = 1424, ["Stranglethorn"] = 1434, ["Stonetalon Mountains"] = 1442,
    ["Thousand Needles"] = 1441, ["Dustwallow Marsh"] = 1445, ["Blasted Lands"] = 1419, ["Moonglade"] = 1450,
    ["Swamp of Sorrows"] = 1435, ["Eastern Plaguelands"] = 1423}) do zoneByName[name] = zoneByName[name] or zid end
local ids = {}
for id, n in pairs(ns.TaxiNodes or {}) do if n.map == 0 or n.map == 1 then ids[#ids + 1] = id end end
table.sort(ids)
local out = {
    "-- Guild Trip Flugmeister (Flugpunkte) – ERZEUGT von scripts/build_flightmasters.lua, nicht von Hand aendern.",
    "-- Quelle: Shortest Path Forever Data/Taxi.lua (cjber, GPL-3.0-or-later; TaxiNodes der Forever-Spieldaten).",
    "-- {Flugpunkt-Nr. (wie die Flugkarte), Kontinent, Welt-x, Welt-y, nutzbar (1 = Allianz, 2 = Horde, 3 = beide), Name,",
    "--  Gebiet (Karten-Nr., 0 = unbekannt)}",
    "local _, lev = ...",
    "lev.FLIGHTMASTERS = {",
}
for _, id in ipairs(ids) do
    local n = ns.TaxiNodes[id]
    local mask = n.faction == "Alliance" and 1 or n.faction == "Horde" and 2 or 3
    local suffix = n.name:match(",%s*(.+)$") or n.name
    local zone = zoneByName[suffix]
    if not zone and suffix ~= "" then
        -- kurze Namen ("Elwynn", "Hillsbrad"): Gebiet, dessen Name damit beginnt
        for name, zid in pairs(zoneByName) do
            if name:sub(1, #suffix) == suffix and (not zone or zid < zone) then zone = zid end
        end
    end
    zone = zone or 0
    out[#out + 1] = ("    {%d, %d, %.1f, %.1f, %d, %q, %d},"):format(id, n.map, n.x, n.y, mask, n.name, zone)
end
out[#out + 1] = "}"
local f = assert(io.open("src/ONE_Leveling/FlightMasters.lua", "w"))
f:write(table.concat(out, "\n") .. "\n")
f:close()
print(#ids .. " Flugmeister geschrieben")
