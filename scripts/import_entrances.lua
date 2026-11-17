-- Import: Dungeon-Eingänge aus QuestieDB (support/Forever/Zones/dungeons.lua – Eingangs-Symbole auf der Karte,
-- schon in Forever-Prozenten; GPLv3 mit Erlaubnis des Questie-Teams, Questie/Questie#8365)
-- -> src/ONE_Dungeons/EntranceData.lua
--
--   lua5.1 scripts/import_entrances.lua <QuestieDB-Ordner>
--
-- (Shortest Path Forever hat auch Eingänge, aber als „Leichenpunkt“ im Inneren – fürs Hinlaufen ungeeignet.)
local src = assert(arg[1], "Aufruf: lua5.1 scripts/import_entrances.lua <QuestieDB-Ordner>")
local dest = arg[2] or "src/ONE_Dungeons/EntranceData.lua"
local text = assert(io.open(src .. "/support/Forever/Zones/dungeons.lua")):read("*a")
local commit = "?"
do
    local h = io.popen("git -C '" .. src:gsub("'", "") .. "' log -1 --format='%h %ad' --date=short 2>/dev/null")
    if h then commit = h:read("*l") or "?" h:close() end
end
-- Gebiet (AreaTable) -> uiMapID, nur die hier gebrauchten
local AREA = {[1519] = 1453, [1637] = 1454, [17] = 1413, [331] = 1440, [1] = 1426, [85] = 1420, [440] = 1446,
    [3] = 1418, [8] = 1435, [40] = 1436, [46] = 1428, [51] = 1427, [139] = 1423, [28] = 1422, [405] = 1443,
    [130] = 1421, [357] = 1444}
-- Guild-Trip-Schlüssel -> {Questie-Name, welcher Punkt (bei mehreren Eingängen)}
local KEY = {rfc = {"Ragefire Chasm"}, wc = {"Wailing Caverns"}, dm = {"The Deadmines"}, sfk = {"Shadowfang Keep"},
    stocks = {"The Stockade"}, bfd = {"Blackfathom Deeps"}, gnomer = {"Gnomeregan"}, rfk = {"Razorfen Kraul"},
    sm = {"Scarlet Monastery"}, rfd = {"Razorfen Downs"}, ulda = {"Uldaman", 1}, zf = {"Zul'Farrak"},
    mara = {"Maraudon"}, st = {"The Temple of Atal'Hakkar"}, brd = {"Blackrock Depths", 2},
    lbrs = {"Blackrock Spire", 2}, ubrs = {"Blackrock Spire", 2}, scholo = {"Scholomance"},
    stratlive = {"Stratholme", 1}, stratud = {"Stratholme", 2}}
local points = {}
for line in text:gmatch("[^\n]+") do
    local name, rest = line:match('^%s*%[%d+%] = {"([^"]+)",(.*)$')
    -- nur der erste Eintrag je Name (spätere sind andere Erweiterungen), Orte = letzte Liste nach dem Elterngebiet
    local locs = rest and rest:match(",%s*%d+%s*,%s*(%b{})%s*}")
    if name and locs and not points[name] then
        local pts = {}
        for area, x, y in locs:gmatch("{(%d+),%s*([%d.]+),%s*([%d.]+)}") do pts[#pts + 1] = {tonumber(area), tonumber(x), tonumber(y)} end
        points[name] = pts
    end
end
local out, missing, keys = {}, {}, {}
for k in pairs(KEY) do keys[#keys + 1] = k end
table.sort(keys)
for _, key in ipairs(keys) do
    local pts = points[KEY[key][1]]
    local p = pts and pts[KEY[key][2] or 1]
    local m = p and AREA[p[1]]
    if m then out[#out + 1] = ("    %s = {%d, %.4f, %.4f},"):format(key, m, p[2] / 100, p[3] / 100)
    else missing[#missing + 1] = key end
end
local f = assert(io.open(dest, "w"))
f:write("-- Guild Trip Dungeon-Eingänge – ERZEUGT von scripts/import_entrances.lua, nicht von Hand ändern.\n")
f:write("-- Quelle: QuestieDB (Forever) vom Questie-Team, GPLv3 mit Erlaubnis (Questie/Questie#8365), Stand " .. commit .. ".\n")
f:write("-- schluessel = {uiMapID, x, y} (Kartenanteile 0..1). Düsterbruch-Flügel: eigene Startwerte (Questie: ein Punkt).\n")
f:write("local _, dungeons = ...\ndungeons.EntranceData = {\n")
f:write(table.concat(out, "\n"), "\n}\n")
f:close()
print(("%d Eingänge geschrieben, ohne Treffer: %s"):format(#out, table.concat(missing, ", ")))
