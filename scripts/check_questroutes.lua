-- Harte Pruefungen direkt auf den fertigen Routen (src/ONE_Leveling/Routes.lua) – das, was der Spieler bekommt
-- (Nutzer 21.11.2026: "ich muss mich da voll und ganz auf dich verlassen koennen").
-- Je Route: Gebietsbesuche fuer nur eine Quest (Stadt/Gebiet), Rueckkehr in ein verlassenes Gebiet innerhalb von
-- 2 Stufen, Hauptstadt-Besuche fuer eine einzelne Quest ohne Zauber.
-- Aufruf: lua5.1 scripts/check_questroutes.lua [Schluessel, z. B. 16:128] [-v]
local want, verbose, files = nil, false, {}
for _, a in ipairs(arg) do
    if a == "-v" then verbose = true
    elseif a:match("%.lua$") then files[#files + 1] = a
    else want = a end
end
GetLocale = function() return "deDE" end
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Names_deDE", "ONE_Leveling/ClassSpells", "ONE_Leveling/Routes"}) do
    assert(loadfile("src/" .. f .. ".lua"))()
end
local Q, SP = GuildTripQuestDB, GuildTripLeveling.sp or {}
-- einzelne Routen-Dateien aus der Nachstellung (SIM_RECORD) statt Routes.lua
if #files > 0 then
    GuildTripQuestRoutes = {}
    for _, f in ipairs(files) do GuildTripQuestRoutes[f:match("([^/]+)%.lua$")] = assert(loadfile(f))() end
end
local CITY = {[1454] = true, [1456] = true, [1458] = true, [1453] = true, [1455] = true, [1457] = true}
local CITYZONE = {[1454] = 1411, [1456] = 1412, [1458] = 1420, [1453] = 1429, [1455] = 1426, [1457] = 1438}
-- Grenzgebiete, die oft am selben Ort liegen (Ziel knapp ueber der Grenze) – zaehlen als ein Gebiet
local SAME = {[1416] = 1424, [1424] = 1424, [1427] = 1418, [1418] = 1418, [1419] = 1435, [1435] = 1435}
local function MapOf(n)
    local d = Q.n[n or 0]
    local m = d and d[2]
    return m and (SAME[m] or m)
end
-- Weltkoordinaten (SPF-Kartenrahmen, Umgebung SPF=<Ordner>): Gebietswechsel ueber eine nahe Grenze (< 700 yd) zaehlt
-- nicht als Wechsel – Questziele liegen oft knapp im Nachbargebiet
local Z
if os.getenv("SPF") then
    local ns = {}
    assert(loadfile(os.getenv("SPF") .. "/Data/Zones.lua"))("ShortestPathForever", ns)
    Z = ns.Zones
end
local function PosOf(n, z)
    local d = Q.n[n or 0]
    if not (d and Z) then return nil end
    for i = 2, #d - 2, 3 do
        if d[i] == z then
            local zz = Z[z]
            if zz then return {zz.map, zz.maxX - d[i + 2] / 1000 * (zz.maxX - zz.minX), zz.maxY - d[i + 1] / 1000 * (zz.maxY - zz.minY)} end
        end
    end
end
local function Near(a, b) return a and b and a[1] == b[1] and math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) < 700 end
local keys = {}
for k in pairs(GuildTripQuestRoutes) do if not want or k == want then keys[#keys + 1] = k end end
table.sort(keys)
local total = {single = 0, city = 0, back = 0}
for _, key in ipairs(keys) do
    local r = GuildTripQuestRoutes[key]
    local segs, cur = {}, nil
    for i, st in ipairs(r) do
        -- Gebiet des Schritts (z, aus der Nachstellung), Hauptstadt zaehlt zu ihrem Gebiet (Unterstadt = Tirisfal)
        local m = st[1] and (st.z and (SAME[st.z] or CITYZONE[st.z] or st.z) or MapOf(st.n))
        local isCity = st.z and CITY[st.z]
        if m then
            local p = PosOf(st.n, st.z)
            -- nahe Grenze: im bisherigen Abschnitt bleiben
            if cur and cur.m ~= m and Near(p, cur.last) then m = cur.m end
            if not cur or cur.m ~= m then cur = {m = m, ids = {}, n = 0, spell = false, from = i, l = st.l, city = isCity} segs[#segs + 1] = cur end
            cur.last = p or cur.last
            for id in st[1]:gmatch("%a(%d+)") do
                id = tonumber(id)
                if not cur.ids[id] then cur.ids[id] = true cur.n = cur.n + 1 end
                if SP[id] then cur.spell = true end
            end
            cur.to, cur.lEnd = i, st.l
        end
    end
    local single, city, back = 0, 0, 0
    local left = {}
    for i, s in ipairs(segs) do
        -- Zwischenstopp fuer eine Quest zwischen zwei Besuchen desselben anderen Gebiets ist ein Abstecher
        if s.n <= 1 and not s.spell and i > 1 and i < #segs then
            if s.city then city = city + 1 else single = single + 1 end
            if verbose then print(("  %s  Stufe %d: %s nur fuer Quest %s"):format(key, s.l or 0, tostring(s.m), next(s.ids) or "?")) end
        end
        if left[s.m] and (s.l or 0) < left[s.m] + 2 and not CITY[s.m] and s.n >= 1 then
            back = back + 1
            if verbose then print(("  %s  Stufe %d: zurueck nach %s (%d Quests)"):format(key, s.l or 0, tostring(s.m), s.n)) end
        end
        if segs[i + 1] then left[s.m] = s.lEnd or s.l end
    end
    total.single, total.city, total.back = total.single + single, total.city + city, total.back + back
    print(("%-8s %4d Schritte  Gebiet fuer 1 Quest %3d  Stadt fuer 1 Quest %3d  zurueck < 2 Stufen %3d"):format(key, #r, single, city, back))
end
print(("SUMME Gebiet-1 %d, Stadt-1 %d, zurueck %d (%d Routen)"):format(total.single, total.city, total.back, #keys))
