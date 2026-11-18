-- Project ONE Berufe: Lehrer-Verzeichnis und "Wann zum Lehrer?".
-- Drei Quellen, ohne Zusatz-Addon:
--  1) Spieldaten: eigener Berufsstand -> wann die naechste Ausbildungsstufe faellig ist
--  2) Grundliste: Lehrer der Hauptstaedte je Fraktion (Classic-Stand, von Hand;
--     jeder sieht nur die Lehrer seiner Fraktion)
--     zusammengestellt, als "ungefaehr / unbestaetigt" markiert)
--  3) Gilde: Spricht jemand mit ONE einen Lehrer an, merkt ONE sich Name, Ort,
--     genaue Position und Angebot, teilt das in der Gilde -> "bestaetigt"
local _, crafting = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Trainers = {}
crafting.Trainers = Trainers

-- Classic-Ausbildungsstufen der Hauptberufe (Fertigkeit, ab der man lernen kann; Charakterstufe).
Trainers.ranks = {
    {name = "Geselle", fromMax = 75, skill = 50, level = 10, newMax = 150},
    {name = "Experte", fromMax = 150, skill = 125, level = 20, newMax = 225},
    {name = "Fachmann", fromMax = 225, skill = 200, level = 35, newMax = 300},
}

local O, TB, UC = 1454, 1456, 1458
-- Grundliste (Classic-Stand, aus allgemeinem Spielwissen; Positionen ungefaehr).
-- kind: class | profession | weapon | other
Trainers.seed = {
    {npc = "Grezz Ragefist", kind = "class", what = "Krieger", map = O, x = .804, y = .324, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Ormak Grimshot", kind = "class", what = "Jäger", map = O, x = .660, y = .185, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Ormok", kind = "class", what = "Schurke", map = O, x = .439, y = .546, area = "Orgrimmar, Kluft der Schatten"},
    {npc = "Mirket", kind = "class", what = "Hexenmeister", map = O, x = .486, y = .460, area = "Orgrimmar, Kluft der Schatten"},
    {npc = "Kardris Dreamseeker", kind = "class", what = "Schamane", map = O, x = .385, y = .360, area = "Orgrimmar, Tal der Weisheit"},
    {npc = "Pephredo", kind = "class", what = "Magier", map = O, x = .388, y = .856, area = "Orgrimmar, Tal der Geister"},
    {npc = "Ur'kyo", kind = "class", what = "Priester", map = O, x = .356, y = .878, area = "Orgrimmar, Tal der Geister"},
    {npc = "Sayoc", kind = "weapon", what = "Waffenmeister", map = O, x = .815, y = .196, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Hanashi", kind = "weapon", what = "Waffenmeister", map = O, x = .810, y = .190, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Makaru", kind = "profession", what = "Bergbau", map = O, x = .731, y = .261, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Saru Steelfury", kind = "profession", what = "Schmiedekunst", map = O, x = .820, y = .236, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Roxxik", kind = "profession", what = "Ingenieurskunst", map = O, x = .756, y = .252, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Lumak", kind = "profession", what = "Angeln", map = O, x = .699, y = .292, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Jandi", kind = "profession", what = "Kräuterkunde", map = O, x = .557, y = .396, area = "Orgrimmar, Die Gasse"},
    {npc = "Yelmak", kind = "profession", what = "Alchemie", map = O, x = .566, y = .331, area = "Orgrimmar, Die Gasse"},
    {npc = "Magar", kind = "profession", what = "Schneiderei", map = O, x = .632, y = .514, area = "Orgrimmar, Die Gasse"},
    {npc = "Karolek", kind = "profession", what = "Lederverarbeitung", map = O, x = .624, y = .447, area = "Orgrimmar, Die Gasse"},
    {npc = "Thuwd", kind = "profession", what = "Kürschnerei", map = O, x = .630, y = .446, area = "Orgrimmar, Die Gasse"},
    {npc = "Godan", kind = "profession", what = "Verzauberkunst", map = O, x = .535, y = .384, area = "Orgrimmar, Die Gasse"},
    {npc = "Zamja", kind = "profession", what = "Kochkunst", map = O, x = .574, y = .539, area = "Orgrimmar, Die Gasse"},
    {npc = "Arnok", kind = "profession", what = "Erste Hilfe", map = O, x = .340, y = .844, area = "Orgrimmar, Tal der Geister"},
    {npc = "Ansekhwa", kind = "weapon", what = "Waffenmeister", map = TB, x = .408, y = .626, area = "Donnerfels"},
    {npc = "Archibald", kind = "weapon", what = "Waffenmeister", map = UC, x = .574, y = .328, area = "Unterstadt, Kriegsviertel"},
}

-- Allianz-Grundliste (Classic-Stand, aus allgemeinem Spielwissen; Positionen
-- ungefaehr, im Spiel unbestaetigt). Gilden-Funde ersetzen die Eintraege.
local SW, IF, DN = 1453, 1455, 1457
for _, e in ipairs({
    {npc = "Wu Shen", kind = "class", what = "Krieger", map = SW, x = .784, y = .458, area = "Sturmwind, Altstadt"},
    {npc = "Osborne the Night Man", kind = "class", what = "Schurke", map = SW, x = .748, y = .526, area = "Sturmwind, Altstadt"},
    {npc = "Olmin Burningbeard", kind = "class", what = "Jäger", map = IF, x = .702, y = .836, area = "Eisenschmiede, Halle der Waffen"},
    {npc = "Elsharin", kind = "class", what = "Magier", map = SW, x = .386, y = .796, area = "Sturmwind, Magierviertel"},
    {npc = "Demisette Cloyce", kind = "class", what = "Hexenmeister", map = SW, x = .259, y = .776, area = "Sturmwind, Magierviertel"},
    {npc = "High Priestess Laurena", kind = "class", what = "Priester", map = SW, x = .386, y = .258, area = "Sturmwind, Kathedralenplatz"},
    {npc = "Lord Grayson Shadowbreaker", kind = "class", what = "Paladin", map = SW, x = .385, y = .326, area = "Sturmwind, Kathedralenplatz"},
    {npc = "Mathrengyl Bearwalker", kind = "class", what = "Druide", map = DN, x = .348, y = .080, area = "Darnassus, Enklave des Cenarius"},
    {npc = "Woo Ping", kind = "weapon", what = "Waffenmeister", map = SW, x = .572, y = .574, area = "Sturmwind, Handelsdistrikt"},
    {npc = "Bixi Wobblebonk", kind = "weapon", what = "Waffenmeister", map = IF, x = .620, y = .893, area = "Eisenschmiede, Halle der Waffen"},
    {npc = "Buliwyf Stonehand", kind = "weapon", what = "Waffenmeister", map = IF, x = .616, y = .890, area = "Eisenschmiede, Halle der Waffen"},
    {npc = "Ilyenia Moonfire", kind = "weapon", what = "Waffenmeister", map = DN, x = .576, y = .468, area = "Darnassus, Kriegerterrasse"},
    {npc = "Gelman Stonehand", kind = "profession", what = "Bergbau", map = SW, x = .594, y = .374, area = "Sturmwind, Zwergendistrikt"},
    {npc = "Therum Deepforge", kind = "profession", what = "Schmiedekunst", map = SW, x = .632, y = .372, area = "Sturmwind, Zwergendistrikt"},
    {npc = "Lilliam Sparkspindle", kind = "profession", what = "Ingenieurskunst", map = SW, x = .628, y = .320, area = "Sturmwind, Zwergendistrikt"},
    {npc = "Arnold Leland", kind = "profession", what = "Angeln", map = SW, x = .454, y = .584, area = "Sturmwind, Kanäle"},
    {npc = "Shylamiir", kind = "profession", what = "Kräuterkunde", map = SW, x = .642, y = .612, area = "Sturmwind, Altstadt"},
    {npc = "Lilyssia Nightbreeze", kind = "profession", what = "Alchemie", map = SW, x = .462, y = .792, area = "Sturmwind, Magierviertel"},
    {npc = "Georgio Bolero", kind = "profession", what = "Schneiderei", map = SW, x = .433, y = .736, area = "Sturmwind, Magierviertel"},
    {npc = "Simon Tanner", kind = "profession", what = "Lederverarbeitung", map = SW, x = .718, y = .627, area = "Sturmwind, Altstadt"},
    {npc = "Maris Granger", kind = "profession", what = "Kürschnerei", map = SW, x = .718, y = .620, area = "Sturmwind, Altstadt"},
    {npc = "Lucan Cordell", kind = "profession", what = "Verzauberkunst", map = SW, x = .531, y = .744, area = "Sturmwind, Handelsdistrikt"},
    {npc = "Stephen Ryback", kind = "profession", what = "Kochkunst", map = SW, x = .762, y = .372, area = "Sturmwind, Altstadt"},
    {npc = "Shaina Fuller", kind = "profession", what = "Erste Hilfe", map = SW, x = .424, y = .268, area = "Sturmwind, Kathedralenplatz"},
}) do
    e.faction = "Alliance"
    Trainers.seed[#Trainers.seed + 1] = e
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

function Trainers:Store()
    local s = crafting.Recipes:Store()
    s.trainers = type(s.trainers) == "table" and s.trainers or {}
    return s.trainers
end

-- 1) Faellige Ausbildungen aus dem eigenen Berufsstand
-- profs: {[name] = {skill, max}} (aus GetProfessionInfo oder gemerkten Daten)
function Trainers:Due(profs, level)
    local out = {}
    for prof, p in pairs(profs or {}) do
        for _, rank in ipairs(self.ranks) do
            if (p.max or 0) == rank.fromMax then
                if (p.skill or 0) >= rank.skill and (level or 0) >= rank.level then
                    out[#out + 1] = {prof = prof, rank = rank.name, ready = true, text = T("%s: %s jetzt lernbar", prof, T(rank.name))}
                else
                    local need = {}
                    if (p.skill or 0) < rank.skill then need[#need + 1] = T("Fertigkeit %s", tostring(rank.skill)) end
                    if (level or 0) < rank.level then need[#need + 1] = T("Stufe %d", rank.level) end
                    out[#out + 1] = {prof = prof, rank = rank.name, ready = false,
                        text = T("%s: %s ab %s", prof, T(rank.name), table.concat(need, T(" und ")))}
                end
            end
        end
    end
    table.sort(out, function(a, b) if a.ready ~= b.ready then return a.ready end return a.prof < b.prof end)
    return out
end

-- Eigene Berufe direkt aus dem Spiel (belegt: GetProfessions/GetProfessionInfo).
function Trainers:MyProfessions()
    local out = {}
    local list = {Call(GetProfessions)}
    for i = 1, 6 do
        local index = list[i]
        if type(index) == "number" then
            local name, _, skill, max = Call(GetProfessionInfo, index)
            if type(name) == "string" then out[name] = {skill = tonumber(skill) or 0, max = tonumber(max) or 0} end
        end
    end
    return out
end

-- 3) Lehrer im Spiel erfassen (beim Oeffnen des Lehrerfensters)
function Trainers:Kind(title, services)
    title = (title or ""):lower()
    if title:find("waffen") then return "weapon" end
    for _, s in ipairs(services or {}) do
        local n = (s or ""):lower()
        for _, prof in ipairs({"bergbau", "kräuterkunde", "kochkunst", "alchemie", "schmiedekunst", "schneiderei",
            "lederverarbeitung", "kürschnerei", "verzauberkunst", "ingenieurskunst", "angeln", "erste hilfe"}) do
            if n:find(prof, 1, true) then return "profession", s end
        end
    end
    if title:find("lehrer") or title:find("lehrerin") then return "class" end
    return "other"
end
-- Das Blizzard-Lehrerfenster filtert (verfuegbar / nicht verfuegbar / bereits bekannt).
-- GetNumTrainerServices zaehlt nur, was der Filter zeigt – sonst wirkt z. B. ein
-- Waffenmeister leer. Zum Erfassen kurz alles zeigen, danach den Filter zurueckstellen.
Trainers.filterTypes = {"available", "unavailable", "used"}
function Trainers:WithAllFilters(fn)
    local get, set = _G.GetTrainerServiceTypeFilter, _G.SetTrainerServiceTypeFilter
    if type(get) ~= "function" or type(set) ~= "function" then return fn() end
    local saved = {}
    for _, t in ipairs(self.filterTypes) do
        local ok, v = pcall(get, t)
        saved[t] = ok and v
        if ok and not v then pcall(set, t, 1) end
    end
    local result = {pcall(fn)}
    for _, t in ipairs(self.filterTypes) do
        if saved[t] ~= nil and not saved[t] then pcall(set, t, 0) end
    end
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2)
end

-- Waffenmeister: Angebot -> Waffenarten (Schluessel wie ONE_Classes/Weapons.lua), deutsch + englisch
Trainers.weaponNames = {
    {"axe1", "einhandäxte", "one%-handed axes"}, {"axe2", "zweihandäxte", "two%-handed axes"},
    {"mace1", "einhandstreitkolben", "one%-handed maces"}, {"mace2", "zweihandstreitkolben", "two%-handed maces"},
    {"sword1", "einhandschwerter", "one%-handed swords"}, {"sword2", "zweihandschwerter", "two%-handed swords"},
    {"polearm", "stangenwaffen", "polearms"}, {"staff", "^stäbe", "^staves"}, {"dagger", "dolche", "daggers"},
    {"fist", "faustwaffen", "fist weapons"}, {"bow", "^bogen", "^bows"}, {"bow", "^bögen", "^bow$"},
    {"crossbow", "armbrüste", "crossbows"}, {"gun", "schusswaffen", "guns"}, {"thrown", "wurfwaffe", "thrown"},
}
function Trainers.WeaponsFrom(services)
    local found
    for _, name in ipairs(services or {}) do
        local low = name:lower()
        for _, w in ipairs(Trainers.weaponNames) do
            if low:find(w[2]) or low:find(w[3]) then found = found or {} found[w[1]] = true end
        end
    end
    return found
end

function Trainers:CaptureCurrent()
    return self:WithAllFilters(function() return self:CaptureNow() end)
end
function Trainers:CaptureNow()
    local npc = Call(UnitName, "npc")
    if type(npc) ~= "string" or npc == "" then return nil end
    local title
    if C_TooltipInfo and type(C_TooltipInfo.GetUnit) == "function" then
        local data = Call(C_TooltipInfo.GetUnit, "npc")
        local line = type(data) == "table" and data.lines and data.lines[2]
        if type(line) == "table" and type(line.leftText) == "string" then title = line.leftText end
    end
    local services, rankText = {}, {}
    -- 0.7.1: angebotene Rezepte mit hergestelltem Gegenstand, Mindestfertigkeit und Preis
    -- (Forever-eigene Rezepte stehen in keiner offenen Datenbank; so fuellt die Gilde die Luecke)
    local recipes
    local n = tonumber((Call(GetNumTrainerServices))) or 0
    for i = 1, math.min(n, 400) do
        local name, sub, kind = Call(GetTrainerServiceInfo, i)
        if type(name) == "string" and kind ~= "header" then
            if #services < 40 then services[#services + 1] = name end
            -- Ausbildungsstufen stehen als Zusatztext am Berufsnamen ("Alchemie" / "Experte")
            if type(sub) == "string" and sub ~= "" then rankText[#rankText + 1] = {name, sub} end
            local link = Call(GetTrainerServiceItemLink, i)
            local item = type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if item then
                local _, skill = Call(GetTrainerServiceSkillReq, i)
                recipes = recipes or {}
                recipes[item] = {skill = tonumber(skill) or 0, cost = tonumber((Call(GetTrainerServiceCost, i))) or 0,
                    level = tonumber((Call(GetTrainerServiceLevelReq, i))) or 0}
            end
        end
    end
    local mapID, x, y
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        mapID = Call(C_Map.GetBestMapForUnit, "player")
        local pos = mapID and Call(C_Map.GetPlayerMapPosition, mapID, "player")
        if type(pos) == "table" then x, y = pos.x, pos.y end
    end
    local kind, what = self:Kind(title, services)
    -- Welche Ausbildungsstufen lehrt er? (fuer "Navi zum naechsten Lehrer, der die Stufe lehrt")
    local teaches
    for _, r in ipairs(rankText) do
        for _, rank in ipairs(self.ranks) do
            if (r[1] == what or r[1] == title) and r[2]:find(rank.name, 1, true) then teaches = teaches or {} teaches[rank.name] = true end
        end
    end
    local entry = {npc = npc, title = title, kind = kind, what = what or title, map = mapID,
        x = x and math.floor(x * 1000 + .5) / 1000, y = y and math.floor(y * 1000 + .5) / 1000,
        area = Call(GetZoneText), count = n, seen = crafting.Recipes.Now(), by = crafting.Recipes.Me(), teaches = teaches,
        faction = Call(UnitFactionGroup, "player"), recipes = recipes,
        weapons = kind == "weapon" and Trainers.WeaponsFrom(services) or nil}
    self:Store()[npc] = entry
    return entry
end

-- Lehrt dieser Lehrer die Stufe? true = sicher, nil = unbekannt (Faustregel), false = nein.
-- Faustregel ohne Daten: Geselle kann jeder Berufslehrer, ab Experte nur Lehrer der Hauptstaedte.
Trainers.capitals = {[1454] = true, [1456] = true, [1458] = true, [1453] = true, [1455] = true, [1457] = true}
-- Kurztext der gelehrten Stufen: "lehrt Geselle, Experte" (leer, wenn unbekannt)
function Trainers.TeachText(e)
    if type(e.teaches) ~= "table" then return "" end
    local parts = {}
    for _, r in ipairs(Trainers.ranks) do if e.teaches[r.name] then parts[#parts + 1] = T(r.name) end end
    return #parts > 0 and T("lehrt %s", table.concat(parts, ", ")) or ""
end
function Trainers.Teaches(e, rankName)
    if type(e.teaches) == "table" then return e.teaches[rankName] == true end
    if rankName == "Geselle" then return nil end
    if e.map and Trainers.capitals[e.map] then return nil end
    return false
end
-- Bester Lehrer fuer Beruf + Stufe: sichere vor unbekannten, dann der naechste
-- (Entfernung ueber das Navi-Modul, sonst Hauptstadt zuerst). Liefert Eintrag oder nil.
function Trainers:BestFor(prof, rankName)
    local navi = ONE.modules and ONE.modules.nav
    local best, bestScore
    for _, e in ipairs(self:All()) do
        if e.kind == "profession" and e.what == prof and e.map and e.x and e.y then
            local t = Trainers.Teaches(e, rankName)
            if t ~= false then
                local dist = navi and navi.DistanceTo and navi:DistanceTo(e.map, e.x, e.y)
                -- sicher = Vorsprung, gleicher Kontinent nach Entfernung, sonst weit hinten
                local score = (t and 0 or 100000) + (dist or 50000)
                if not bestScore or score < bestScore then best, bestScore = e, score end
            end
        end
    end
    return best
end

-- Lehrer aus ONE_QuestDB (einmal je Fraktion umgewandelt): {npc, kind, what, map, x, y, faction, confirmed, db}
Trainers.dbCache = {}
function Trainers.FromQuestDB(faction)
    if Trainers.dbCache[faction] then return Trainers.dbCache[faction] end
    local d = rawget(_G, "GuildTripQuestDB")
    local list = {}
    if type(d) == "table" and type(d.trainers) == "table" then
        local names = d.svcNames or d.names or {}
        local want = faction == "Alliance" and 1 or 2
        for id, t in pairs(d.trainers) do
            local fac, name = t[6], names[id]
            -- neutrale Lehrer in der Hauptstadt der anderen Fraktion erreicht man nicht
            local enemy = faction == "Alliance" and (t[3] == 1454 or t[3] == 1456 or t[3] == 1458)
                or faction ~= "Alliance" and (t[3] == 1453 or t[3] == 1455 or t[3] == 1457)
            if name and (fac == 3 or fac == want) and not enemy then
                list[#list + 1] = {npc = name, kind = t[1], what = t[2], map = t[3], x = t[4] / 1000, y = t[5] / 1000,
                    faction = faction, confirmed = true, db = true, npcID = id}
            end
        end
    end
    Trainers.dbCache[faction] = list
    return list
end

-- Gemeinsames Verzeichnis: eigene/Gilden-Funde, Startpaket, Questdatenbank (sonst Grundliste).
function Trainers:All()
    local out, byName = {}, {}
    for npc, e in pairs(self:Store()) do
        local copy = {}
        for k, v in pairs(e) do copy[k] = v end
        copy.confirmed = true
        byName[npc] = copy
    end
    -- Grundliste je Fraktion (Eintraege ohne faction sind Horde)
    local ok, faction = pcall(function() return UnitFactionGroup and UnitFactionGroup("player") end)
    faction = (ok and faction == "Alliance") and "Alliance" or "Horde"
    -- Startpaket aus eigenen Funden (TrainerPack.lua): vor der Grundliste, nach eigenen Funden
    for npc, e in pairs(crafting.TrainerPack or {}) do
        if not byName[npc] and (e.faction == nil or e.faction == faction) then
            local copy = {}
            for k, v in pairs(e) do copy[k] = v end
            copy.npc, copy.confirmed, copy.pack = npc, true, true
            byName[npc] = copy
        end
    end
    -- Lehrer-Verzeichnis aus der Questdatenbank (ONE_QuestDB/Services.lua, QuestieDB Forever): alle Lehrer
    -- mit genauer Position. Ersetzt die ungefähre Grundliste, eigene Funde und Startpaket haben Vorrang.
    local dbList = Trainers.FromQuestDB(faction)
    for _, e in ipairs(dbList) do
        if not byName[e.npc] then byName[e.npc] = e end
    end
    for _, s in ipairs(#dbList == 0 and self.seed or {}) do
        if (s.faction or "Horde") == faction and not byName[s.npc] then
            local copy = {}
            for k, v in pairs(s) do copy[k] = v end
            copy.confirmed = false
            byName[s.npc] = copy
        end
    end
    for _, e in pairs(byName) do out[#out + 1] = e end
    local order = {profession = 1, class = 2, weapon = 3, other = 4}
    table.sort(out, function(a, b)
        if a.kind ~= b.kind then return (order[a.kind] or 9) < (order[b.kind] or 9) end
        if (a.what or "") ~= (b.what or "") then return (a.what or "") < (b.what or "") end
        return a.npc < b.npc
    end)
    return out
end
