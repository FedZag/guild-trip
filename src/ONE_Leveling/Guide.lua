-- Guild Trip Quest-Fuehrung: Anbindung ans Spiel (0.6.9).
-- Liest Stufe/Klasse/Ort/Questlog, ruft den Planer, plant bei Aenderungen neu (gebuendelt) und
-- meldet das den Anzeigen (Ansicht "Fuehrung" auf der Quest-Seite, Kasten "Naechster Schritt").
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local G = {listeners = {}}
lev.Guide = G
local P = lev.Planner

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

G.CLASS = {WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024}
G.RACE = {Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128}
G.TAGS = {
    dungeon = {"DUNGEON", "ff9a2e"}, class = {"KLASSE", "f58cba"}, pre = {"VORQUEST", "ffb070"},
    xp = {"EP", "4fd14f"}, upgrade = {"UPGRADE", "5aa9ff"}, group = {"GRUPPE", "ff5a4a"}, rec = {"EMPFOHLEN", "ffd100"},
}
G.ICON = {
    accept = "|TInterface\\GossipFrame\\AvailableQuestIcon:14:14|t",
    turnin = "|TInterface\\GossipFrame\\ActiveQuestIcon:14:14|t",
    obj = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:13:13|t",
    dungeon = "|TInterface\\Icons\\INV_Misc_Bone_HumanSkull_01:14:14|t",
    train = "|TInterface\\Icons\\INV_Misc_Book_09:14:14|t",
    fp = "|TInterface\\Icons\\INV_Misc_Map_01:14:14|t",
    hearth = "|TInterface\\Icons\\INV_Misc_Rune_01:14:14|t",
    grind = "|TInterface\\Icons\\INV_Sword_04:14:14|t",
    vendor = "|TInterface\\Icons\\INV_Misc_Bag_10:14:14|t",
}
G.CLASS_DE = {WARRIOR = "Krieger", PALADIN = "Paladin", HUNTER = "Jäger", ROGUE = "Schurke", PRIEST = "Priester",
    SHAMAN = "Schamane", MAGE = "Magier", WARLOCK = "Hexenmeister", DRUID = "Druide"}

function G:DB()
    ONE.db = ONE.db or {}
    local d = ONE.db.leveling
    if type(d) ~= "table" then d = {} ONE.db.leveling = d end
    if not P.TEMPO[d.tempo or ""] then d.tempo = "need" end
    if type(d.override) ~= "table" then d.override = {} end
    if d.tracker == nil then d.tracker = true end
    if d.view == nil then d.view = "guide" end
    return d
end

function G:Available() return P.Data() ~= nil end

local function Nav() return ONE.ns and ONE.ns.nav end
local function Dungeons() return ONE.ns and ONE.ns.dungeons end

function G.Title(id)
    local title = Try(C_QuestLog and C_QuestLog.GetTitleForQuestID, id)
    if type(title) == "string" and title ~= "" then return title end
    local d = rawget(_G, "GuildTripQuestDB")
    return d and d.titles and d.titles[id] or ("#" .. id)
end

-- Umschalt+Klick auf eine Quest (Planer, Kasten): Quest-Links in den Chat (Nutzer 23.11.2026)
function G.LinkQuests(ids)
    if not (ONE.LinkQuests and ids and #ids > 0) then return false end
    local QL = Nav() and Nav().QuestLevels
    return ONE:LinkQuests(ids, G.Title, function(id) return QL and QL.Level and QL.Level(id) end)
end
function G.StepQuestIDs(step, qid)
    if qid then return {qid} end
    local out, seen = {}, {}
    for _, a in ipairs(step and step.actions or {}) do
        if a.id and not seen[a.id] then seen[a.id] = true out[#out + 1] = a.id end
    end
    return out
end

-- Titel mit Stufe davor ("[12] Die Volksmiliz"), wenn eingeschaltet (Optionen › Navi)
function G.LevelTitle(id, level)
    local QL = Nav() and Nav().QuestLevels
    return (QL and QL.Prefix(id, level) or "") .. G.Title(id)
end

-- Sehr empfohlene Reihen (Schlafsack): jetzt mit Vorrang machen oder spaeter – je Figur gefragt
function G.CharKey()
    local name, realm = Try(UnitFullName, "player")
    name = name or Try(UnitName, "player") or "?"
    return (realm and realm ~= "") and (name .. "-" .. realm) or name
end
function G:RecChoice(key)
    local d = self:DB()
    local c = type(d.recChoice) == "table" and d.recChoice[G.CharKey()]
    return type(c) == "table" and c[key] or nil
end
function G:SetRecChoice(key, value)
    local d = self:DB()
    d.recChoice = type(d.recChoice) == "table" and d.recChoice or {}
    local ck = G.CharKey()
    d.recChoice[ck] = type(d.recChoice[ck]) == "table" and d.recChoice[ck] or {}
    d.recChoice[ck][key] = value
    self:Replan()
end
-- offene Frage: Reihe ist im Plan (ab Startstufe) und noch nicht beantwortet -> Eintrag aus P.RECOMMENDED
function G:RecQuestion(plan)
    if not plan then return nil end
    for _, rec in ipairs(P.RECOMMENDED or {}) do
        if self:RecChoice(rec.key) == nil then
            for id, why in pairs(plan.chosen or {}) do
                local o = plan.info and plan.info[id]
                if o and o.rec and o.rec.key == rec.key and why then return rec end
            end
        end
    end
end

function G.Catalog(key)
    local dg = Dungeons()
    for _, c in ipairs(dg and dg.Catalog or {}) do if c.key == key then return c end end
end

-- Haendler fuer die Quest-Fuehrung (Nutzer 21.11.2026: "planst du einen haendler zum reparieren und verkaufen mit
-- ein, falls das inventar zu voll ist?"): freie Taschenplaetze (Reparieren nicht – Nutzer 21.11.2026: "nur Taschen")
local function Num(v) return type(v) == "number" and v == v and not (type(issecretvalue) == "function" and issecretvalue(v)) end
function G.FreeBagSlots()
    local fn = (C_Container and C_Container.GetContainerNumFreeSlots) or rawget(_G, "GetContainerNumFreeSlots")
    if type(fn) ~= "function" then return nil end
    local free, any = 0, false
    for bag = 0, 4 do
        local ok, n, kind = pcall(fn, bag)
        if ok and Num(n) and (not Num(kind) or kind == 0) then free, any = free + n, true end
    end
    return any and free or nil
end
-- Haendler im aktuellen Gebiet: {{mapID, x, y, name, id}}
G.VENDOR_BAGS = 8   -- erst ab so wenigen freien Plaetzen ueberhaupt Haendler suchen
function G.VendorSpots(mapID, faction)
    local nv = Nav()
    local M = nv and nv.Merchants
    if not (mapID and M and M.FromQuestDB) then return nil end
    local ok, all = pcall(M.FromQuestDB, faction)
    local out = {}
    for key, v in pairs(ok and all or {}) do
        if v.mapID == mapID then
            out[#out + 1] = {mapID = v.mapID, x = v.x, y = v.y, name = v.name, id = tonumber(tostring(key):match("%d+"))}
        end
    end
    table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return #out > 0 and out or nil
end

-- Berufe der Figur {[Beruf-Nr.] = Wert} (fuer Quests mit Berufs-Bedingung); Namen deutsch und englisch
G.SKILL_IDS = {
    ["Alchemie"] = 171, ["Alchemy"] = 171, ["Schmiedekunst"] = 164, ["Blacksmithing"] = 164,
    ["Verzauberkunst"] = 333, ["Enchanting"] = 333, ["Ingenieurskunst"] = 202, ["Engineering"] = 202,
    ["Kräuterkunde"] = 182, ["Herbalism"] = 182, ["Lederverarbeitung"] = 165, ["Leatherworking"] = 165,
    ["Bergbau"] = 186, ["Mining"] = 186, ["Kürschnerei"] = 393, ["Skinning"] = 393,
    ["Schneiderei"] = 197, ["Tailoring"] = 197, ["Kochkunst"] = 185, ["Cooking"] = 185,
    ["Erste Hilfe"] = 129, ["First Aid"] = 129, ["Angeln"] = 356, ["Fishing"] = 356,
}
function G.Skills()
    local n = Try(rawget(_G, "GetNumSkillLines"))
    if type(n) ~= "number" then return {} end
    local out = {}
    for i = 1, math.min(n, 80) do
        local name, isHeader, _, rank = Try(rawget(_G, "GetSkillLineInfo"), i)
        local id = not isHeader and type(name) == "string" and G.SKILL_IDS[name]
        if id and type(rank) == "number" then out[id] = rank end
    end
    return out
end

local function SmallestBag()
    local fn = (C_Container and C_Container.GetContainerNumSlots) or rawget(_G, "GetContainerNumSlots")
    if type(fn) ~= "function" then return nil end
    local small
    for bag = 1, 4 do
        local n = Try(fn, bag) or 0
        if not small or n < small then small = n end
    end
    return small
end

-- Bekannte Flugmeister dieses Charakters (vom Navi beim Oeffnen einer Flugkarte gemerkt): {{c, x, y, name = …}}
function G.FlightNodes()
    local nav = Nav()
    local F = nav and nav.Flights
    if not F then return {} end
    local out = {}
    local nodes, known = F:Nodes() or {}, F:Known() or {}
    for id in pairs(known) do
        local n = nodes[id]
        if type(n) == "table" and type(n.x) == "number" and type(n.continent) == "number" then
            out[#out + 1] = {n.continent, n.x, n.y, name = n.name}
        end
    end
    return out
end

-- Schiffe/Zeppeline der eigenen Fraktion: {{c, x, y, from, to, name, mapID, mx, my}}
function G.Departures()
    local nav = Nav()
    local tr = nav and nav.Travel
    if not (tr and tr.departures and tr.World) then return {} end
    local faction = tr.Faction and tr.Faction()
    local out = {}
    for _, d in ipairs(tr.departures) do
        if not d.faction or d.faction == faction then
            local c, wx, wy = tr.World(d.mapID, d.x, d.y)
            if c then
                local arr = tr.Arrival and tr.Arrival(d)
                out[#out + 1] = {c, wx, wy, from = d.from, to = d.to, name = d.name, mapID = d.mapID, mx = d.x, my = d.y,
                    arrive = arr and {arr[1], arr[2], arr[3]} or nil}
            end
        end
    end
    return out
end

-- ===== Klassen-Reisezauber (Nutzer 20.11.2026: "alles klassenspezifische ... muss mit eingebaut werden") =====
function G.Knows(spell)
    if Try(rawget(_G, "IsPlayerSpell"), spell) or Try(rawget(_G, "IsSpellKnown"), spell) then return true end
    local book = rawget(_G, "C_SpellBook")
    return (book and Try(book.IsSpellKnown, spell)) == true
end
-- Sekunden bis bereit (0 = bereit); globale Abklingzeit zaehlt nicht
function G.SpellReadyIn(spell)
    local start, duration
    local cs = rawget(_G, "C_Spell")
    local info = cs and Try(cs.GetSpellCooldown, spell)
    if type(info) == "table" then start, duration = info.startTime, info.duration
    else start, duration = Try(rawget(_G, "GetSpellCooldown"), spell) end
    if type(start) ~= "number" or type(duration) ~= "number" or start <= 0 or duration <= 2 then return 0 end
    return math.max(0, start + duration - (Try(rawget(_G, "GetTime")) or 0))
end
local function FactionBit(faction) return faction == "Alliance" and 1 or faction == "Horde" and 2 or 0 end
-- nutzbare Reisezauber fuer den Planer: {{kind, spell, name, place, w, bind, cd, inSec}}
function G.Ports(classFile, faction)
    local out = {}
    for _, t in ipairs(lev.TELEPORTS or {}) do
        local runes = t[11] and (Try(rawget(_G, "GetItemCount"), t[11]) or 0)
        if t[2] == classFile and (t[3] == 0 or t[3] == FactionBit(faction)) and G.Knows(t[1]) and (not runes or runes > 0) then
            local name = Try(rawget(_G, "GetSpellInfo"), t[1])
            local cs = rawget(_G, "C_Spell")
            if not name and cs and cs.GetSpellName then name = Try(cs.GetSpellName, t[1]) end
            out[#out + 1] = {kind = t[6] and "recall" or "teleport", spell = t[1], name = name or t[10] or T("Teleport"),
                place = t[10], w = t[7] and {t[7], t[8], t[9]} or nil, bind = t[6], cd = t[5], inSec = G.SpellReadyIn(t[1]), uses = runes or nil}
        end
    end
    return out
end
-- Magier-Teleports lernt man beim Portallehrer: noch nicht gelernte bis Stufe+2 mit Lehrern der eigenen Fraktion
-- Rueckgabe {now = n, next = {[stufe] = n}, spots, group = "portal"} oder nil
function G.PortalInfo(classFile, level, faction)
    local now, nxt, any = 0, {}, false
    for _, t in ipairs(lev.TELEPORTS or {}) do
        if t[11] and t[2] == classFile and (t[3] == 0 or t[3] == FactionBit(faction)) and t[4] <= level + 2 and not G.Knows(t[1]) then
            any = true
            if t[4] <= level then now = now + 1 else nxt[t[4]] = (nxt[t[4]] or 0) + 1 end
        end
    end
    if not any then return nil end
    local Trs = ONE.ns and ONE.ns.crafting and ONE.ns.crafting.Trainers
    local spots = {}
    for _, tr in ipairs(Trs and Trs.All and (Try(Trs.All, Trs) or {}) or {}) do
        if tr.what == "Portale" and tr.map and tr.x then spots[#spots + 1] = {mapID = tr.map, x = tr.x, y = tr.y, name = tr.npc} end
    end
    if #spots == 0 then return nil end
    return {now = now, next = nxt, spots = spots, group = "portal"}
end
-- Lauftempo (Yards/s): beritten 11, sonst 7 mal schnellster Tempo-Zauber (Geisterwolf, Reisegestalt, Gepard)
function G.Speed(classFile)
    if Try(rawget(_G, "IsMounted")) then return 11 end
    local f = 1
    for spell, t in pairs(lev.SPEED_SPELLS or {}) do
        if t[2] == classFile and t[1] > f and G.Knows(spell) then f = t[1] end
    end
    return 7 * f
end

-- Neue Klassen-Zauber beim Lehrer (Nutzer 20.11.2026: "wenn ich schon in der Naehe eines Lehrers bin, warum nicht
-- gleich neue Skills lernen?"). Genau, wenn der letzte Lehrerbesuch die kommenden Zauber gemerkt hat
-- (ONE_Classes/Trainer.lua: upcoming); sonst Classic-Regel: neue Zauber/Raenge gibt es zu jeder geraden Stufe.
-- Rueckgabe {now = jetzt lernbar, next = {[stufe] = anzahl}, spots = Klassenlehrer der eigenen Fraktion}
G.TRAIN_EVERY = 2
function G.TrainInfo(classFile, level, name)
    local crafting = ONE.ns and ONE.ns.crafting
    local Trs = crafting and crafting.Trainers
    local what = classFile and G.CLASS_DE[classFile]
    if not (what and Trs and Trs.All and level and level >= 2) then return nil end
    local cg = ONE.db and type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    local u = type(cg.upcoming) == "table" and cg.upcoming[name or Try(UnitName, "player") or "?"]
    if type(u) == "table" and u.class ~= classFile then u = nil end
    local now, nxt = 0, {}
    if u and type(u.list) == "table" and #u.list > 0 then
        for _, sp in ipairs(u.list) do
            local lvl = tonumber(sp.level) or 0
            if lvl > 0 and lvl <= level then now = now + 1
            elseif lvl > level and lvl <= level + 2 then nxt[lvl] = (nxt[lvl] or 0) + 1 end
        end
    else
        -- Stufe des letzten Besuchs; nie beim Lehrer gewesen: die letzte gerade Stufe gilt als noch nicht
        -- gelernt. Besuch gemerkt, aber ohne Stufe (aeltere Version): gilt als aktuell gelernt (Spieltest
        -- 20.11.2026: Zauber mit 14 gelernt, Guide schickte trotzdem zum Lehrer)
        local at = u and tonumber(u.level)
            or (level - level % G.TRAIN_EVERY - (u and 0 or 1))
        for lvl = G.TRAIN_EVERY, math.min(60, level + 2), G.TRAIN_EVERY do
            if lvl > at then
                if lvl <= level then now = now + 1 else nxt[lvl] = 1 end
            end
        end
    end
    local spots = {}
    for _, t in ipairs(Try(Trs.All, Trs) or {}) do
        if t.kind == "class" and t.what == what and t.map and t.x then
            spots[#spots + 1] = {mapID = t.map, x = t.x, y = t.y, name = t.npc}
        end
    end
    if #spots == 0 then return nil end
    return {now = now, next = nxt, spots = spots}
end

-- Noch nicht entdeckte Flugpunkte der eigenen Fraktion: {{c, x, y, id = , name = }}
function G.UnknownFlights(faction)
    local nav = Nav()
    local F = nav and nav.Flights
    local known = F and F.Known and (Try(F.Known, F) or {}) or {}
    local want = faction == "Alliance" and 1 or faction == "Horde" and 2 or 0
    local out = {}
    if want == 0 then return out end
    for _, f in ipairs(lev.FLIGHTMASTERS or {}) do
        if f[5] % (want * 2) >= want and not known[f[1]] then
            out[#out + 1] = {f[2], f[3], f[4], id = f[1], name = f[6]}
        end
    end
    return out
end

-- Gastwirte der eigenen Fraktion (Ruhestein setzen): {{c, x, y, id = , name = }}
function G.InnList()
    local H = lev.Hearth
    if not (H and lev.INNS) then return nil end
    local fac = H.Faction()
    local out = {}
    for _, inn in ipairs(lev.INNS) do
        if fac == 0 or inn[5] % (fac * 2) >= fac then
            out[#out + 1] = {inn[2], inn[3], inn[4], id = inn[1], name = H.InnName(inn)}
        end
    end
    return out
end

-- Heimatort und Ruhestein-Bereitschaft (Sekunden bis bereit, nil = kein Ruhestein)
function G.HearthState()
    local H = lev.Hearth
    if not H then return nil end
    -- gesetzt? Steht der Bindeort auf dem Ort, an dem man gerade ist, ist man hier gebunden – auch wenn die
    -- Meldung HEARTHSTONE_BOUND nicht kam (Spieltest 21.11.2026: "Ruhestein setzen" blieb stehen)
    local bind = Try(rawget(_G, "GetBindLocation"))
    local home = Try(H.Home, H)
    if type(bind) == "string" and bind ~= "" and (type(home) ~= "table" or home.place ~= bind)
        and (bind == Try(rawget(_G, "GetSubZoneText")) or bind == Try(rawget(_G, "GetZoneText"))) then
        home = Try(H.Bound, H) or home
    end
    if type(home) ~= "table" or not home[1] then return nil end
    local place = home.place
    if not place and home.inn and H.InnByID then place = H.InnName(H.InnByID(home.inn)) end
    -- ohne Ruhestein im Gepaeck (oder unter anderer Nummer) trotzdem den Heimatort kennen: sonst schlaegt der Planer
    -- das Setzen immer wieder vor; Reisen per Ruhestein plant er dann nicht (hearthIn = nil)
    local ready = H.Ready()
    local home2 = {home[1], home[2], home[3], inn = home.inn, place = place}
    if ready == nil then return home2, nil end
    return home2, ready == true and 0 or ready
end

function G:Context()
    local db = self:DB()
    local _, race = Try(UnitRace, "player")
    local _, class = Try(UnitClass, "player")
    local nav = Nav()
    local mapID, x, y
    if nav and nav.Travel then mapID, x, y = nav.Travel.PlayerMapPosition() end
    local level = Try(UnitLevel, "player") or 1
    local classes = ONE.ns and ONE.ns.classes
    local judgeCache = {}
    local faction = Try(UnitFactionGroup, "player") or "?"
    local home, hearthIn = G.HearthState()
    local bags = G.FreeBagSlots()
    local needVendor = bags and bags <= G.VENDOR_BAGS
    local doneMemo, logSet = {}, {}
    for _, id in ipairs(G.LogIDs()) do logSet[id] = true end
    return {
        me = {level = level, xp = Try(UnitXP, "player") or 0, xpMax = Try(UnitXPMax, "player") or 0,
            class = class and G.CLASS[class], race = race and G.RACE[race],
            sky = race ~= nil and G.RACE[race] == nil,   -- Himmelsgeborene (Forever): kein altes Volk
            faction = Try(UnitFactionGroup, "player") or "?", inGroup = (Try(IsInGroup) and true) or false,
            mapID = mapID, x = x, y = y, skills = G.Skills()},
        -- je Neuplanung gemerkt (Spieltest 22.11.2026: ~1 s Hänger nach Annehmen/Abgeben – der Planer fragt das
        -- Spiel sonst zehntausende Male nach denselben Quests; in der Nachstellung sind das nur Tabellen)
        done = function(id)
            local v = doneMemo[id]
            if v == nil then
                v = Try(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, id) == true
                doneMemo[id] = v
            end
            return v
        end,
        inLog = function(id) return logSet[id] == true end,
        complete = function(id) return Try(C_QuestLog and C_QuestLog.IsComplete, id) == true end,
        -- Ziel-Knoten der noch offenen Ziele (Planer: Zielgebiet/Spawnpunkte nur dafuer), nil = alle Ziele
        targets = function(id)
            local nv = Nav()
            local mi = nv and nv.MobInfo
            local list = Try(C_QuestLog and C_QuestLog.GetQuestObjectives, id)
            if mi and mi.OpenTargets and type(list) == "table" then return mi.OpenTargets(rawget(_G, "GuildTripQuestDB"), id, list) end
        end,
        -- Fortschritt im Log (erledigt, noetig) – Planer rechnet nur den Rest (Nutzer 20.11.2026)
        progress = function(id)
            local W = lev.WorkLog
            local list = Try(C_QuestLog and C_QuestLog.GetQuestObjectives, id)
            if W and W.Progress and type(list) == "table" then return W.Progress(list) end
        end,
        world = nav and nav.Travel and nav.Travel.World,
        judge = classes and classes.Gear and classes.Gear.UpgradePercent and function(item)
            if judgeCache[item] == nil then judgeCache[item] = classes.Gear:UpgradePercent(item) or false end
            return judgeCache[item] or nil
        end,
        smallestBag = SmallestBag(),
        tempo = db.tempo,
        override = db.override,
        speed = G.Speed(class),
        measured = lev.XPLog and lev.XPLog:Measured() or nil,
        workMinutes = lev.WorkLog and lev.WorkLog:Measured() or nil,
        recFirst = function(key) return self:RecChoice(key) == "now" end,
        catalog = G.Catalog,
        entrance = function(key)
            local dg = Dungeons()
            local e = dg and dg.Entrances and Try(dg.Entrances.Get, dg.Entrances, key)
            if e then return {e.mapID, e.x, e.y} end
        end,
        prefer = self.plan and self.plan.steps[1] and self.plan.steps[1].stopKey,
        flights = G.FlightNodes(),
        departures = G.Departures(),
        -- wie Leveling-Routen: Lehrer, Flugpunkte, Ruhestein (Nutzer 20.11.2026)
        train = G.TrainInfo(class, level),
        portal = G.PortalInfo(class, level, faction),
        prevChosen = self.plan and self.plan.chosen or nil,
        prevLog = self.plan and self.plan.logSeen or nil,
        onWay = self.plan and self.plan.onWay or nil,
        workZone = type(db.workZone) == "table" and db.workZone[Try(UnitName, "player") or "?"] or nil,
        ports = G.Ports(class, faction),
        fpSpots = G.UnknownFlights(faction),
        home = home, hearthIn = hearthIn,
        inns = G.InnList(),
        bags = bags,
        vendors = needVendor and G.VendorSpots(mapID, faction) or nil,
        followLoops = self.plan and G.FollowLoops(self.plan) or nil,
    }
end

-- follow = true: dem letzten Plan folgen (Fahrplan), ausser seitdem gab es eine echte Aenderung (self.fresh:
-- Stufenaufstieg, Quest abgebrochen, Gruppe, Einstellungen). Ohne follow wird immer frisch geplant.
-- ===== Feste Route (Neubau 21.11.2026, Nutzer: "bau es wie bei RestedXP") =====
-- GuildTripQuestRoutes["Volk:Klasse"] = {{"a12 t13", n = NPC, l = erwartete Stufe}, …} (scripts/build_routes.sh).
-- Im Spiel wird nichts umgerechnet: die Route ist der Fahrplan (ctx.follow), der Planer laeuft ihn nur ab.
G.ROUTE_BEHIND = 2   -- Annehmen-Schritte so viele Stufen unter der eigenen gelten als verpasst (uebersprungen)
-- Eine feste Route je Volk:Klasse – die schnellste (Nutzer 22.11.2026: "ich moechte weiterhin speed-leveln"; gerechnet
-- mit Tempo "all", das war schneller und mit weniger Rueckwegen als die strengeren Schwellen)
-- Voelker mit demselben Startgebiet (Volk-Maske -> Gruppe): Orc/Troll Tal der Pruefungen, Zwerg/Gnom Coldridge
G.START_GROUP = {[2] = "durotar", [128] = "durotar", [4] = "dunmorogh", [64] = "dunmorogh"}
G.HORDE_RACES = {[2] = true, [16] = true, [32] = true, [128] = true}
-- Himmelsgeborene (Forever-Voelker 95/96) starten auf Zephras – dafuer gibt es noch keine Questdaten. Danach geht es
-- per Zeppelin nach Donnerfels (Horde) bzw. Luftschiff nach Kalimdor (Allianz). Sie folgen der Route eines Volks
-- von dort, gleiche Klasse zuerst (Reihenfolge = Vorrang); Volks-Quests fallen ueber P.RaceOK weg.
G.SKY_ROUTE = {Horde = {32, 2, 128, 16}, Alliance = {8, 1, 64, 4}}
function G.Route(race, class, skyFaction)
    local all = rawget(_G, "GuildTripQuestRoutes")
    if type(all) ~= "table" then return nil end
    class = class or 0
    if not race then
        local list = skyFaction and G.SKY_ROUTE[skyFaction]
        if not list then return nil end
        for _, r in ipairs(list) do
            if all[r .. ":" .. class] then return all[r .. ":" .. class] end
        end
        return G.Route(list[1], class)
    end
    local r = all[race .. ":" .. class]
    if r then return r end
    -- Forever erlaubt Paare, die es in Classic nicht gab (Spieltest 23.11.2026: Orc-Magier bekam eine zufaellige
    -- Orc-Route einer anderen Klasse). Ersatz, fest in dieser Reihenfolge:
    -- 1) dieselbe Klasse eines Volks mit demselben Startgebiet (Orc-Magier -> Troll-Magier)
    local grp = G.START_GROUP[race]
    if grp then
        for other, g in pairs(G.START_GROUP) do
            if other ~= race and g == grp and all[other .. ":" .. class] then return all[other .. ":" .. class] end
        end
    end
    -- 2) eigenes Volk, andere Klasse (Startgebiet stimmt; Klassenquests fremder Klassen fallen von selbst weg) –
    --    die kleinste Klassen-Maske, damit es nicht vom Zufall abhaengt
    local best
    for k in pairs(all) do
        local rr, cc = k:match("^(%d+):(%d+)$")
        if tonumber(rr) == race and (not best or tonumber(cc) < best) then best = tonumber(cc) end
    end
    if best then return all[race .. ":" .. best] end
    -- 3) dieselbe Klasse derselben Fraktion
    local horde = G.HORDE_RACES[race] or false
    local keys = {}
    for k in pairs(all) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local rr, cc = k:match("^(%d+):(%d+)$")
        if tonumber(cc) == class and (G.HORDE_RACES[tonumber(rr)] or false) == horde then return all[k] end
    end
end
-- Fahrplan aus der Route: Rang je Halt; zu niedrige Annehmen-Schritte (man ist voraus) fallen weg.
-- Ziele in mehreren Gebieten (Routen-Bau 22.11.2026, "Chens leeres Faesschen": Loewen/Schreiter im Norden, Echsen im
-- Sueden): die Route hat je Teil einen Schritt "o821.2" mit p = {Ziel-Knoten des Teils}. Es gilt der erste Teil, der
-- noch offene Ziele hat – open(id) = Knoten der offenen Ziele (nil = unbekannt -> erster Teil).
-- Verpasste Annahmen (Nutzer 23.11.2026 "Ja, bauen"): wer schon weiter in der Route ist, wird nicht mehr zu
-- ausgelassenen frueheren Annahmen zurueckgeschickt. Eine Annahme gilt als verpasst, wenn man danach schon bei
-- mindestens G.ROUTE_AHEAD verschiedenen Questgebern der Route angenommen hat (Quest im Log oder erledigt) – verschiedene
-- Geber, damit ein zusammengefasster Doppelbesuch beim selben NPC ("ALS NAECHSTES") oder eine vorgezogene Quest nicht
-- reicht. Liegt der Rest der Quest (Ziele/Abgabe) noch vor einem, kommt sie in missed – der Planer zeigt sie als
-- Hinweis, wenn der Geber am Weg steht (P.MISSED_NEAR).
-- Abgeschaltet (Nachstellung 23.11.2026: auch mit 40 Schritten Abstand fielen ganze Reihen weg, ~380 statt ~770
-- Quests – das Spiel arbeitet die Route nie exakt in ihrer Reihenfolge ab); zu niedrige Annahmen regelt G.ROUTE_BEHIND
G.ROUTE_AHEAD = math.huge
G.ROUTE_MISS_STEPS = 40
-- Liefert den Fahrplan, je Quest die Ziel-Knoten des geltenden Teils und die verpassten Annahmen {id, n, z, rank (Platz
-- in der Route, falls der Planer sie statt langem Hauen zurueckholt), ahead (Rest der Quest liegt noch vor einem)}.
-- later = {[Quest] = 1 (einmal "Spaeter": ans Ende der Runde) | 2 (wieder nicht gemacht: faellt aus dem Plan)} –
-- Elite-Quests ohne Gruppe (Nutzer 24.11.2026). Runden beginnen an Schritten mit r = Nummer (scripts/build_loop.lua).
function G.RouteFollow(route, level, inLog, open, done, later, complete)
    local f, n, parts = {}, 0, {}
    local rankAt = {}
    local kinds = {a = "accept", o = "obj", t = "turnin"}
    local function Have(id) return (inLog and inLog(id)) or (done and done(id)) end
    -- ahead[i] = verschiedene Geber mit eigener Annahme nach Schritt i; last[id] = letzter Ziel-/Abgabe-Schritt
    local ahead, last = {}, {}
    if done then
        local givers, cnt = {}, 0
        for i = #route, 1, -1 do
            ahead[i] = cnt
            local st = route[i]
            if type(st[1]) == "string" then
                for k, id in st[1]:gmatch("(%a)(%d+)") do
                    id = tonumber(id)
                    if k == "a" and Have(id) and not givers[st.n or -i] then givers[st.n or -i] = true cnt = cnt + 1 end
                    if k ~= "a" and not last[id] then last[id] = i end
                end
            end
        end
    end
    -- und mindestens G.ROUTE_MISS_STEPS Routen-Schritte hinter der spaetesten eigenen Annahme
    local lastHave = 0
    if done then
        for i = #route, 1, -1 do
            local st = route[i]
            local hit = false
            if type(st[1]) == "string" then for k, id in st[1]:gmatch("(%a)(%d+)") do if k == "a" and Have(tonumber(id)) then hit = true end end end
            if hit then lastHave = i break end
        end
    end
    local function Behind(i) return (ahead[i] or 0) >= G.ROUTE_AHEAD and lastHave - i >= G.ROUTE_MISS_STEPS end
    local missed, gates, gate, dungeons = {}, {}, nil, {}
    for i, st in ipairs(route) do
        -- Flugpunkt lernen / Ruhestein setzen gehoeren zur Route (Nachstellung 23.11.2026: ohne sie lief man zu Fuss)
        if st.k == "fp" and st.fp and not f["fp:" .. st.fp] then n = n + 1 f["fp:" .. st.fp] = n end
        -- Hauen der Route: Stufe, die vor dem naechsten Schritt erreicht sein soll (gates[Schluessel] = Stufe)
        if st.k == "grind" and st.to then gate = math.max(gate or 0, st.to) end
        -- Dungeon-Lauf der Route (Nutzer 23.11.2026): Annahmen am Eingang (Tokens) zuerst, dann "d:<Schluessel>"
        local dun = st.k == "dungeon" and st.key and not f["d:" .. st.key] and {key = st.key, m = st.m, x = st.x, y = st.y, ids = {}} or nil
        if type(st[1]) == "string" then
            for k, id, part in st[1]:gmatch("(%a)(%d+)%.?(%d*)") do
                id = tonumber(id)
                local key = kinds[k] and (kinds[k] .. ":" .. id)
                local behind = k == "a" and (st.l or 0) < level - G.ROUTE_BEHIND and not (inLog and inLog(id))
                if k == "a" and not behind and Behind(i) and not Have(id) then
                    behind = true
                    if (st.n or 0) > 0 then
                        missed[#missed + 1] = {id = id, n = st.n, z = st.z, rank = n + .5, ahead = last[id] and not Behind(last[id]) or false}
                    end
                end
                if key and part ~= "" and type(st.p) == "table" then
                    n = n + 1
                    parts[id] = parts[id] or {}
                    table.insert(parts[id], {rank = n, nodes = st.p})
                elseif key and not f[key] and not behind then
                    n = n + 1 f[key] = n
                    if gate then gates[key] = gate gate = nil end
                end
                if dun and k == "o" then dun.ids[#dun.ids + 1] = id end
            end
        end
        if dun then n = n + 1 f["d:" .. dun.key] = n dungeons[#dungeons + 1] = dun end
        rankAt[i] = n
    end
    local nodes = {}
    for id, list in pairs(parts) do
        local o = open and inLog and inLog(id) and open(id) or nil
        local set
        if type(o) == "table" then set = {} for _, nr in ipairs(o) do set[nr] = true end end
        local pick
        for _, pt in ipairs(list) do
            local hit = not set
            if set then for _, nr in ipairs(pt.nodes) do if set[nr] then hit = true break end end end
            if hit then pick = pt break end
        end
        pick = pick or list[#list]
        f["obj:" .. id] = pick.rank
        nodes[id] = pick.nodes
    end
    if type(later) == "table" then G.RouteLater(route, f, nodes, rankAt, later, inLog, done) end
    if complete then G.RouteReady(route, f, rankAt, inLog, done, complete) end
    return f, nodes, missed, gates, dungeons
end
-- Fertige Quests im Log nicht aus dem Gebiet mitnehmen (Spieltest 24.11.2026: "einer zum Abgeben direkt in
-- Crossroads" – die Route gab Chol'aruk erst in der naechsten Brachland-Runde ab, man sollte vorher nach Unterstadt).
-- Laufende Runde = Runde der ersten noch offenen Quest im Log (Ziele nicht fertig); sonst der ersten offenen Annahme.
-- Liegt die Abgabe einer fertigen Quest im selben Gebiet, aber in einer spaeteren Runde: ans Ende der laufenden Runde.
function G.RouteReady(route, f, rankAt, inLog, done, complete)
    local hasR = false
    for _, st in ipairs(route) do if st.r then hasR = true break end end
    local function RoundStart(i)
        local j = i
        while j > 1 and not (hasR and route[j].r) and (hasR or route[j - 1].z == route[i].z) do j = j - 1 end
        return j
    end
    local function RoundEnd(i)
        local j = i
        while route[j + 1] and (hasR and not route[j + 1].r or (not hasR and route[j + 1].z == route[i].z)) do j = j + 1 end
        return j
    end
    local cur, curAcc, turnAt = nil, nil, {}
    for i, st in ipairs(route) do
        if type(st[1]) == "string" then
            for k, id in st[1]:gmatch("(%a)(%d+)") do
                id = tonumber(id)
                local open = not (done and done(id))
                if open and k ~= "a" and inLog(id) and not complete(id) and f[(k == "o" and "obj:" or "turnin:") .. id] then cur = cur or i end
                if open and k == "a" and not inLog(id) and f["accept:" .. id] then curAcc = curAcc or i end
                if k == "t" then turnAt[id] = i end
            end
        end
    end
    cur = cur or curAcc
    if not cur then return end
    local s, e = RoundStart(cur), RoundEnd(cur)
    local zones = {}
    for i = s, e do if route[i].z then zones[route[i].z] = true end end
    local base, k = rankAt[e] or 0, 0
    local ids = {}
    for id, i in pairs(turnAt) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return turnAt[a] < turnAt[b] end)
    for _, id in ipairs(ids) do
        local i, key = turnAt[id], "turnin:" .. id
        if i > e and f[key] and f[key] > base + 1 and zones[route[i].z] and inLog(id) and complete(id) and not (done and done(id)) then
            k = k + 1
            f[key] = base + .5 + k * .001
        end
    end
end
-- "Spaeter" (Elite ohne Gruppe): Schritte der Quest ans Ende ihrer Runde (die Runde, in der ihr naechster offener
-- Schritt liegt); zweites Mal: ganz aus dem Fahrplan. Runde = ab Schritt mit r bis vor den naechsten mit r (alte
-- Routen ohne r: zusammenhaengende Schritte im selben Gebiet).
function G.RouteLater(route, f, nodes, rankAt, later, inLog, done)
    local stepOf = {}
    for i, st in ipairs(route) do
        if type(st[1]) == "string" then
            for k, id in st[1]:gmatch("(%a)(%d+)") do
                id = tonumber(id)
                if later[id] then
                    stepOf[id] = stepOf[id] or {}
                    table.insert(stepOf[id], {k = k, i = i})
                end
            end
        end
    end
    local hasR = false
    for _, st in ipairs(route) do if st.r then hasR = true break end end
    local function RoundEnd(i)
        local j = i
        while route[j + 1] and (hasR and not route[j + 1].r or (not hasR and route[j + 1].z == route[i].z)) do j = j + 1 end
        return j
    end
    for id, v in pairs(later) do
        local keys = {"accept:" .. id, "obj:" .. id, "turnin:" .. id}
        if v and v >= 2 then
            for _, key in ipairs(keys) do f[key] = nil end
            nodes[id] = nil
        elseif v and stepOf[id] and not (done and done(id)) then
            local have = inLog and inLog(id)
            local first
            for _, s in ipairs(stepOf[id]) do
                if (s.k ~= "a" or not have) and (not first or s.i < first) then first = s.i end
            end
            if first then
                local base = rankAt[RoundEnd(first)] or 0
                local list = {}
                for _, key in ipairs(keys) do if f[key] then list[#list + 1] = key end end
                table.sort(list, function(a, b) return f[a] < f[b] end)
                for k, key in ipairs(list) do f[key] = base + k * .01 end
            end
        end
    end
end
-- Elite-/Gruppenquest? (Art aus Rewards.lua: 1 Gruppe/Elite, 16 Gruppe empfohlen)
function G.IsElite(id)
    local R = rawget(_G, "GuildTripLeveling")
    local rew = P and P.Rew and P.Rew(R, id)
    local kind = rew and rew[3] or 0
    return kind % 2 == 1 or math.floor(kind / 16) % 2 == 1
end
-- Knopf "Spaeter" im Kasten: erstes Mal ans Ende der Runde, zweites Mal aus dem Plan (je Figur gemerkt)
function G:LaterTable()
    local db = self:DB()
    db.later = type(db.later) == "table" and db.later or {}
    local who = Try(UnitName, "player") or "?"
    db.later[who] = type(db.later[who]) == "table" and db.later[who] or {}
    return db.later[who]
end
function G:LaterQuest(id)
    if not id then return end
    local t = self:LaterTable()
    t[id] = math.min(2, (t[id] or 0) + 1)
    if ONE.Print then
        if t[id] >= 2 then ONE:Print(T("%s fällt aus dem Plan (wieder keine Gruppe).", G.Title(id)))
        else ONE:Print(T("%s kommt ans Ende der Runde.", G.Title(id))) end
    end
    self:Later(.1, true)
end
-- Bessere Ausruestung aus Quests, die nicht in der Route sind (Nutzer 22.11.2026: "wird das bessere Gear mit
-- eingerechnet?" – die Route bleibt fest, nur ein Hinweis im Kasten). Quelle: Seite Ausruestung (Way:Plan).
-- rows = Way:Plan(...), follow = Fahrplan der Route; Ergebnis nach Verbesserung sortiert.
G.GEAR_MIN_PLUS = 10   -- erst ab 10 % besser (oder leerer Platz) lohnt der Umweg
function G.GearHints(rows, follow, planned, done)
    local out = {}
    follow = follow or {}
    -- vom Planer schon eingebaut (G.GearChains): kein Hinweis mehr
    planned = planned or {}
    for _, row in ipairs(rows or {}) do
        local now = row.upgrade and row.now
        local src = now and now.sources and now.sources[1]
        local plus = row.plus or 0
        if src and src.kind == "q" and src.quest and plus >= G.GEAR_MIN_PLUS then
            local id = src.quest
            -- ganze Reihe pruefen, nicht nur die Belohnungs-Quest (Stab von Orgrimmar, 22.11.2026)
            local W = lev.Way
            local dungeon = (W and W.ChainDungeon and W.ChainDungeon(id, done)) or (P and P.IsDungeonChain and P.IsDungeonChain(id))
            if not dungeon and not (follow["accept:" .. id] or follow["obj:" .. id] or follow["turnin:" .. id]) and not planned[id] then
                out[#out + 1] = {item = now.item, src = src, plus = plus, slot = row.slot}
            end
        end
    end
    table.sort(out, function(a, b) return a.plus > b.plus end)
    return out
end
-- Ausruestungs-Quests fest einbauen (Optionen › Leveln, Standard an; Nutzer 22.11.2026): je lohnendem Platz die
-- Questreihe ab dem ersten offenen Teil bis zur Belohnung. Nur Reihen ohne Dungeon (keine Stelle der ganzen Reihe,
-- auch nicht danach), jeder Teil hoechstens G.GEAR_ABOVE Stufen ueber dir, nicht schon in der Route. Ob sie ohne
-- Zickzack hineinpasst (Gebiete am Weg, Umweg), entscheidet der Planer (P.GEAR_EXTRA).
G.GEAR_ABOVE = 3
G.GEAR_CHAIN_MAX = 15
function G.GearChains(rows, follow, level, done)
    local Q = rawget(_G, "GuildTripQuestDB")
    if not (Q and Q.q) then return {} end
    follow, done = follow or {}, done or function() return false end
    local out, seen = {}, {}
    local function InRoute(id) return follow["accept:" .. id] or follow["obj:" .. id] or follow["turnin:" .. id] end
    for _, row in ipairs(rows or {}) do
        local now = row.upgrade and row.now
        local src = now and now.sources and now.sources[1]
        local id = src and src.kind == "q" and src.quest
        if id and (row.plus or 0) >= G.GEAR_MIN_PLUS and not seen[id] and not InRoute(id) then
            seen[id] = true
            -- Reihe rueckwaerts bis zum ersten erledigten Teil
            local list, back, cur = {id}, {[id] = true}, id
            while #list < G.GEAR_CHAIN_MAX do
                local e = Q.q[cur]
                local pre = e and ((type(e[9]) == "table" and e[9][1]) or (type(e[5]) == "table" and e[5][1])) or nil
                if e and type(e[5]) == "table" then for _, p in ipairs(e[5]) do if done(p) then pre = p break end end end
                if not pre or back[pre] or done(pre) then break end
                back[pre] = true
                table.insert(list, 1, pre)
                cur = pre
            end
            local ok = true
            for _, q in ipairs(list) do
                local e = Q.q[q]
                if not e or (e[1] or 0) > (level or 1) + G.GEAR_ABOVE or P.IsDungeonChain(q) or InRoute(q) then ok = false break end
            end
            -- und nach der Belohnung: fuehrt die Reihe weiter in einen Dungeon, nicht anfangen
            local nx, n = (Q.q[id] or {})[12], 0
            while ok and nx and nx > 0 and n < G.GEAR_CHAIN_MAX do
                if P.IsDungeonChain(nx) then ok = false end
                nx, n = (Q.q[nx] or {})[12], n + 1
            end
            if ok then out[#out + 1] = list end
        end
    end
    return out
end
G.GEAR_EVERY = 60      -- Sekunden: Ausruestungs-Plan ist teuer, nicht bei jedem Neuplanen rechnen
function G:GearRows(level)
    local W = lev.Way
    if not (W and W.Plan) then return nil end
    local now = Try(GetTime) or 0
    local c = self.gearCache
    if c and c.level == level and now - c.at < G.GEAR_EVERY then return c.rows end
    local ok, rows = pcall(W.Plan, W)
    self.gearCache = {level = level, at = now, rows = ok and rows or nil}
    return self.gearCache.rows
end

-- Schalter "Ausruestungs-Quests einbauen" (Optionen › Leveln), Standard an
function G:GearOn() return self:DB().gearQuests ~= false end

-- Quests im Log, die nicht zur Route gehoeren (Nutzer: "eigener Hinweis – abbrechen oder nebenbei")
function G.OffRoute(follow, logIDs, plan)
    local out = {}
    -- vom Planer passend eingebaut (Drop-Quests, selbst angenommene): gehoert dann zum Plan
    local inPlan = G.FollowKeys(plan) or {}
    for _, id in ipairs(logIDs or {}) do
        local planned = inPlan["obj:" .. id] or inPlan["turnin:" .. id]
        local inRoute = follow["obj:" .. id] or follow["turnin:" .. id] or follow["accept:" .. id]
        -- Dungeonquests und ihre Vorquests nie (Nutzer 22.11.2026: "diese Frage sollte nie bei Dungeonquests gestellt werden")
        if not (planned or inRoute) and not P.IsDungeonChain(id) then
            out[#out + 1] = {id = id}
        end
    end
    return out
end
function G.FollowKeys(plan)
    if not (plan and plan.orderKeys) then return nil end
    local f = {}
    for i, k in ipairs(plan.orderKeys) do if not f[k] then f[k] = i end end
    return f
end
-- Runde (Schleife) je Halt des letzten Plans – die Anzeige "Runde 2" bleibt beim Folgen gleich
function G.FollowLoops(plan)
    if not (plan and plan.orderKeys and plan.orderLoops) then return nil end
    local f = {}
    for i, k in ipairs(plan.orderKeys) do if not f[k] then f[k] = plan.orderLoops[i] end end
    return f
end
-- Stoppuhr je Neuplanung (ms), gemerkt in den Einstellungen (db.timing): wo die Zeit im Spiel bleibt
local function Clock() local f = rawget(_G, "debugprofilestop") return f and f() or 0 end
function G:Replan(follow)
    local t0, tm = Clock(), {}
    if not self:Available() or (ONE.IsEnabled and not ONE:IsEnabled("leveling")) then
        self.plan = nil
    else
        self.planAt = G.PlayerWorldPos()
        local ctx = self:Context()
        tm.context = Clock() - t0
        local route = G.Route(ctx.me and ctx.me.race, ctx.me and ctx.me.class, ctx.me and ctx.me.sky and ctx.me.faction)
        if route then
            ctx.route, ctx.flow = true, true
            -- selbst angenommene Quests: bereitwilliger einbauen (wer annimmt, will sie machen), nur ohne grossen Umweg
            ctx.tempo = P.ROUTE_TEMPO
            local later = self:LaterTable()
            ctx.follow, ctx.objNodes, ctx.missed, ctx.routeGates, ctx.routeDungeons = G.RouteFollow(route, ctx.me.level or 1, ctx.inLog, ctx.targets, ctx.done, later, ctx.complete)
            -- zweimal "Spaeter": abgewaehlt (im Log dann "Nicht im Plan", abbrechen mit Rueckfrage)
            for id, v in pairs(later) do
                if v >= 2 then
                    local ov = {}
                    for k, x in pairs(ctx.override or {}) do ov[k] = x end
                    for k, x in pairs(later) do if x >= 2 then ov[k] = "no" end end
                    ctx.override = ov
                    break
                end
            end
            ctx.followLoops = nil
            if self:GearOn() then
                local gc = G.GearChains(self:GearRows(ctx.me.level or 1), ctx.follow, ctx.me.level, ctx.done)
                if #gc > 0 then ctx.gear = gc end
            end
        elseif follow and not self.fresh then
            local saved = not self.plan and self:SavedFollow() or nil
            -- Fahrplan vom alten Planer (vor den Schleifen, 21.11.2026, ohne Runden): nicht weiterfahren – frisch planen
            if saved and not saved.orderLoops then saved = nil end
            ctx.follow = G.FollowKeys(self.plan) or G.FollowKeys(saved)
            ctx.followLoops = G.FollowLoops(self.plan) or G.FollowLoops(saved)
        else ctx.followLoops = nil end
        self.fresh = false
        local t1 = Clock()
        local ok, plan = pcall(P.Plan, P, ctx)
        tm.plan = Clock() - t1
        self.plan = ok and plan or nil
        if self.plan then G.TimedFirst(self.plan, G.QuestTimers()) end
        if self.plan and route then
            self.plan.offRoute = G.OffRoute(ctx.follow, G.LogIDs(), self.plan)
            self.plan.route = true
            -- Lehrer sind kein Routen-Schritt (Nutzer 21.11.2026: "neue Skills lernen nur als Info bei Stufenaufstieg")
            local tr = ctx.train
            if tr and (tr.now or 0) > 0 then self.plan.trainHint = {n = tr.now, spots = tr.spots} end
            -- Taschen (fast) voll: plan.vendorHint rechnet der Planer (Haendler am Weg zum naechsten Schritt)
            -- bessere Ausruestung aus Quests ausserhalb der Route: nur Hinweis
            local gh = G.GearHints(self:GearRows(ctx.me.level or 1), ctx.follow, self.plan.gearIn, ctx.done)
            if #gh > 0 then self.plan.gearHint = gh end
        end
        -- Arbeitsgebiet je Figur merken (uebersteht Abstecher und /reload)
        if self.plan then
            local db = self:DB()
            db.workZone = type(db.workZone) == "table" and db.workZone or {}
            db.workZone[Try(UnitName, "player") or "?"] = self.plan.workZone
            -- Fahrplan merken: gilt auch nach /reload, Neueinloggen und Installieren (Spieltest 20.11.2026)
            db.follow = type(db.follow) == "table" and db.follow or {}
            db.follow[Try(UnitName, "player") or "?"] = {keys = self.plan.orderKeys, loops = self.plan.orderLoops, t = Try(rawget(_G, "time")) or 0}
        end
        if not ok and ONE.Debug then ONE:Debug("Quest-Führung: " .. tostring(plan)) end
    end
    local t2 = Clock()
    for _, fn in ipairs(self.listeners) do pcall(fn, self.plan) end
    tm.show = Clock() - t2
    local t3 = Clock()
    pcall(self.AutoNavi, self, self.plan)
    tm.navi = Clock() - t3
    tm.total = Clock() - t0
    local db = self:DB()
    -- die letzten 10 Neuplanungen
    db.timing = type(db.timing) == "table" and db.timing or {}
    table.insert(db.timing, 1, tm)
    while #db.timing > 10 do table.remove(db.timing) end
    return self.plan
end
function G:OnChange(fn) self.listeners[#self.listeners + 1] = fn end

-- gebuendelt neu planen (Ereignisse kommen oft in Schauern)
-- gemerkter Fahrplan dieser Figur (hoechstens G.FOLLOW_KEEP Sekunden alt): {orderKeys = …} oder nil
G.FOLLOW_KEEP = 12 * 3600
function G:SavedFollow()
    local db = self:DB()
    local f = type(db.follow) == "table" and db.follow[Try(UnitName, "player") or "?"]
    if type(f) ~= "table" or type(f.keys) ~= "table" then return nil end
    local now = Try(rawget(_G, "time")) or 0
    if now > 0 and (f.t or 0) > 0 and now - f.t > G.FOLLOW_KEEP then return nil end
    return {orderKeys = f.keys, orderLoops = type(f.loops) == "table" and f.loops or nil}
end
function G:Later(delay, fresh)
    if fresh then self.fresh = true end
    if self.pending then return end
    self.pending = true
    local function Go()
        self.pending = false
        -- im Kampf nicht rechnen: nach dem Kampf (PLAYER_REGEN_ENABLED) nachholen
        if Try(InCombatLockdown) then self.deferred = true return end
        self:Replan(true)
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay or 1, Go) else Go() end
end

-- ===== Texte =====
function G.TagText(tags)
    local out = {}
    for _, t in ipairs(tags or {}) do
        local d = G.TAGS[t]
        if d then out[#out + 1] = "|cff" .. d[2] .. T(d[1]) .. "|r" end
    end
    return table.concat(out, " ")
end

-- Name eines Questgebers/Ziels (NPC oder Objekt) aus ONE_QuestDB
function G.NodeName(nr)
    local d = rawget(_G, "GuildTripQuestDB")
    local name = nr and d and d.names and d.names[nr]
    if type(name) == "string" and name ~= "" then return name end
end

-- short = nur Questnamen; plain = ohne NPC-Namen (Kasten zeigt ihn in eigener Zeile)
G.ICON.travel = "|TInterface\\Icons\\Ability_Mount_Gryphon_01:14:14|t"
G.ICON.boat = "|TInterface\\Icons\\INV_Misc_Spyglass_02:14:14|t"

-- Reise-Schritt: "Fliegen: A › B" bzw. "Schiff ab Auberdine nehmen"
function G.TravelText(via)
    if not via then return "" end
    if via.kind == "hearth" and via.port and via.port ~= "hearth" then
        local icon = via.spell and Try(rawget(_G, "GetSpellTexture"), via.spell)
        icon = icon and ("|T" .. icon .. ":14:14|t") or G.ICON.hearth
        if via.port == "recall" and via.place then return icon .. " " .. T("%s nach %s benutzen", via.name or "?", via.place) end
        return icon .. " " .. T("%s benutzen", via.name or "?")
    end
    if via.kind == "hearth" then
        return G.ICON.hearth .. " " .. (via.place and T("Ruhestein nach %s benutzen", via.place) or T("Ruhestein benutzen"))
    end
    if via.kind == "flight" then
        local S = Nav() and Nav().Travel and Nav().Travel.ShortName or function(n) return n end
        return G.ICON.travel .. " " .. T("Fliegen: %s › %s", S(via.from.name or "?"), S(via.to.name or "?"))
    end
    return G.ICON.boat .. " " .. T("%s nehmen", T(via.dep and via.dep.name or "Schiff"))
end

function G:StepText(step, short, plain)
    if not step then return "" end
    if step.kind == "travel" then return G.TravelText(step.via) end
    if step.kind == "train" and step.group == "portal" then return G.ICON.train .. " " .. T("Teleport lernen") end
    if step.kind == "train" then return G.ICON.train .. " " .. T("Neue Zauber lernen") end
    if step.kind == "fp" then
        local S = Nav() and Nav().Travel and Nav().Travel.ShortName or function(n) return n end
        return G.ICON.fp .. " " .. T("Flugpunkt %s holen", S(step.name or "?"))
    end
    if step.kind == "grind" and step.toXP and step.maxXP and step.toXP < step.maxXP then
        return G.ICON.grind .. " " .. T("Monster hauen bis %d / %d EP", step.toXP, step.maxXP)
    end
    if step.kind == "grind" then return G.ICON.grind .. " " .. T("Bis Stufe %d Monster hauen", step.lvl or 0) end
    if step.kind == "bind" then return G.ICON.hearth .. " " .. T("Ruhestein setzen: %s", step.name or "?") end
    if step.kind == "vendor" then
        return G.ICON.vendor .. " " .. T("Händler: Taschen leeren")
    end
    if step.kind == "dungeon" then
        local c = G.Catalog(step.key)
        return G.ICON.dungeon .. " " .. T("Dungeon %s: %d Quests", c and T(c.name) or step.key, #(step.ids or {}))
    end
    local who = G.NodeName(step.nr)
    local parts = {}
    for _, a in ipairs(step.actions) do
        local title = G.LevelTitle(a.id)
        if a.kind == "accept" then parts[#parts + 1] = G.ICON.accept .. " " .. (short and title or T("%s annehmen", title))
        elseif a.kind == "turnin" then parts[#parts + 1] = G.ICON.turnin .. " " .. (short and title or T("%s abgeben", title))
        else parts[#parts + 1] = G.ICON.obj .. " " .. (short and title or T("%s erledigen", title)) end
    end
    local text = table.concat(parts, "  ·  ")
    if not who or plain then return text end
    -- bei wem? (Ziel-Schritt: wen/was)
    if step.kind == "obj" then return text .. "  |cffa0a0a0(" .. who .. ")|r" end
    if #parts > 1 then return "|cffffd100" .. T("Bei %s:", who) .. "|r " .. text end
    if short then return text .. "  |cffa0a0a0(" .. who .. ")|r" end
    return text .. "  |cffa0a0a0– " .. T("bei %s", who) .. "|r"
end

-- Zweite Zeile im Kasten: wo/bei wem
function G:StepWho(step)
    if not step then return nil end
    if step.kind == "dungeon" then return T("Gruppe suchen – Eingang im Navi") end
    if step.kind == "train" and step.group == "portal" then
        return T("beim Portallehrer %s – Teleportrunen nicht vergessen", step.name or "?")
    end
    if step.kind == "train" then
        return step.name and T("beim Lehrer %s – liegt am Weg", step.name) or T("beim Klassenlehrer – liegt am Weg")
    end
    if step.kind == "fp" then return T("beim Flugmeister ansprechen – später schneller unterwegs") end
    if step.kind == "grind" and step.hub then
        return T("hier in der Nähe – danach Stufe %d", step.lvl or 0)
    end
    if step.kind == "grind" then
        return T("ca. %d min hier in der Gegend – die nächsten Quests brauchen Stufe %d", math.max(1, math.floor((step.work or 0) + .5)), step.lvl or 0)
    end
    if step.kind == "bind" then return T("beim Gastwirt – näher an deinen nächsten Quests") end
    if step.kind == "vendor" then return step.name and T("bei %s", step.name) or T("beim Händler") end
    if step.kind == "travel" then
        local v = step.via
        if v and v.kind == "hearth" then
            return T("spart ca. %d min gegenüber Laufen", math.max(1, math.floor((v.save or 0) + .5)))
        end
        if v and v.kind == "flight" then return T("Zum Flugmeister – lohnt sich gegenüber Laufen") end
        return T("Zur Abfahrt – anderer Kontinent")
    end
    local who = G.NodeName(step.nr)
    if not who then return nil end
    if step.kind == "obj" then return T("Ziel: %s", who) end
    return T("bei %s", who)
end

-- Navi folgt der Fuehrung von selbst – nur wenn die Fuehrung benutzt wird (Kasten an) und das Navi
-- nicht gerade zu etwas anderem zeigt, das du selbst gestartet hast.
function G:AutoNavi(plan)
    local db = self:DB()
    local step = plan and plan.steps[1]
    if not (step and (step.mapID or step.world) and db.autoNavi ~= false and db.tracker) then return false end
    if step.kind == "grind" then return false end
    if ONE.IsEnabled and not ONE:IsEnabled("leveling") then return false end
    if self.autoKey == step.stopKey then return false end
    local navMod = ONE.modules and ONE.modules.nav
    if navMod and navMod.AutoNaviAllowed and not navMod:AutoNaviAllowed() then return false end
    local nav = Nav()
    local arrow = nav and nav.Arrow
    if arrow and arrow.active and not (self.autoLabel and arrow.target == self.autoLabel) then return false end
    if not self:Navi(step, true) then return false end
    self.autoKey = step.stopKey
    self.autoLabel = arrow and arrow.target
    return true
end

function G:StepTags(step)
    if not (step and self.plan) then return "" end
    local seen, tags = {}, {}
    local ids = step.kind == "dungeon" and step.ids or {}
    if step.kind ~= "dungeon" then for _, a in ipairs(step.actions) do ids[#ids + 1] = a.id end end
    for _, id in ipairs(ids) do
        local o = self.plan.info[id]
        for _, t in ipairs(o and o.tags or {}) do if not seen[t] then seen[t] = true tags[#tags + 1] = t end end
    end
    return G.TagText(tags)
end

function G.ZoneName(mapID)
    local info = mapID and Try(C_Map and C_Map.GetMapInfo, mapID)
    return info and info.name or ""
end

-- ===== Gebietsuebersicht (Ansicht "Gebiete") – nur Anzeige =====
function G:Zones(plan)
    plan = plan or self.plan
    if not plan then return {} end
    if self.zonesPlan ~= plan then
        local ok, zones = pcall(P.Zones, P, self:Context(), plan)
        self.zones, self.zonesPlan = ok and zones or {}, plan
    end
    return self.zones
end

-- aufgeklappt? Vorgabe: aktuelles Gebiet (erstes in der Liste)
function G.ZoneOpen(state, mapID)
    if state.zoneOpen and state.zoneOpen[mapID] ~= nil then return state.zoneOpen[mapID] end
    return state.firstZone == mapID
end

G.ZONE_STATUS = {
    log = {"im Log", "66ccff"}, plan = {"im Plan", "40ff40"}, skip = {"ausgelassen", "9d9d9d"},
}
function G.ZoneStatus(q)
    local d = G.ZONE_STATUS[q.status]
    if d then return "|cff" .. d[2] .. T(d[1]) .. "|r" end
    if q.status == "locked" then
        if q.minLevel > ((G.plan and G.plan.level) or 0) then return "|cffff7f3f" .. T("ab Stufe %d", q.minLevel) .. "|r" end
        return "|cffff7f3f" .. T("Vorquest fehlt") .. "|r"
    end
    return "|cffbbbbbb" .. T("später (Stufe %d)", q.level) .. "|r"
end

function G:ZoneItems(plan, state)
    local out = {}
    local zones = self:Zones(plan)
    state.firstZone = zones[1] and zones[1].mapID
    for _, z in ipairs(zones) do
        local open = G.ZoneOpen(state, z.mapID)
        local parts = {T("%d/%d erledigt", z.done, z.total)}
        if z.plan > 0 then parts[#parts + 1] = T("%d im Plan", z.plan) end
        if z.open > 0 then parts[#parts + 1] = T("%d offen", z.open) end
        if z.locked > 0 then parts[#parts + 1] = T("%d gesperrt", z.locked) end
        out[#out + 1] = {key = "z" .. z.mapID, header = true, zone = z.mapID,
            text = (open and "− " or "+ ") .. G.ZoneName(z.mapID):upper() .. "  |cff9d9d9d· " .. table.concat(parts, " · ") .. "|r"}
        if open then
            for _, q in ipairs(z.quests) do
                out[#out + 1] = {key = "zq" .. q.id, qid = q.id, dim = q.status ~= "plan" and q.status ~= "log",
                    text = "[" .. q.level .. "] " .. G.Title(q.id), tags = G.ZoneStatus(q)}
            end
        end
    end
    return out
end

-- Ueberschrift eines Gebietsblocks: "WESTFALL · 12 Schritte · ~40 Min."
function G.BlockTitle(plan, step)
    local name = G.ZoneName(step.mapID):upper()
    local b = plan.blocks and step.block and plan.blocks[step.block]
    if not b then return name end
    local steps = b.steps == 1 and T("1 Schritt") or T("%d Schritte", b.steps)
    return name .. "  |cff9d9d9d· " .. steps .. " · " .. T("~%d Min.", math.max(1, math.floor(b.minutes + .5))) .. "|r"
end

-- Warum? Zeilen fuer eine Quest: {{links, rechts}, …}, Urteil
function G:Why(id)
    local plan = self.plan
    local o = plan and plan.info[id]
    if not o then return nil end
    local rows = {}
    local function Row(a, b) rows[#rows + 1] = {a, b} end
    Row(T("Quest-EP (für Stufe %d)", plan.level), tostring(o.xp))
    if o.work > 0 and not o.dungeon then Row(T("+ EP der Gegner (%d x ~%d)", o.work, math.floor(o.mobXP + .5)), tostring(math.floor(o.work * o.mobXP + .5))) end
    Row(T("Zeit (Weg %.0f min + Ziele %.0f min)", o.travel, o.work * P.KILL_SEC / 60), T("~%d min", math.max(1, math.floor(o.minutes + .5))))
    if not o.dungeon then
        Row(T("EP pro Minute"), tostring(math.floor(o.epm + .5)))
        Row(T("nur Monster hauen"), T("~%d", math.floor(plan.grind + .5)))
    end
    local verdict
    local why = o.why
    if why == "dungeon" then
        local c = G.Catalog(o.dungeon)
        verdict = T("Pflicht: Quest für %s – vor dem Dungeon abholen.", c and T(c.name) or o.dungeon)
    elseif o.rec and (why == "rec" or why == "pre") then
        verdict = T("Sehr empfohlen: %s.", T(o.rec.reason))
        local hint = P.RecHint(id, Try(UnitFactionGroup, "player"))
        if hint then verdict = verdict .. " " .. T("Achtung: %s.", T(hint)) end
    elseif why == "class" then verdict = T("Pflicht: Klassenquest.")
    elseif why == "pre" then verdict = T("Pflicht: Vorquest für „%s“.", G.Title(o.preFor or id))
    elseif why == "xp" then
        local pct = math.floor((o.epm / math.max(1, plan.grind) - 1) * 100 + .5)
        verdict = (o.near or 0) > 0 and T("Lohnt sich: %d %% schneller als Monster hauen, gleiche Gegend wie %d andere Quest(s).", pct, o.near)
            or T("Lohnt sich: %d %% schneller als Monster hauen.", pct)
    elseif why == "value" then verdict = T("Lohnt sich wegen der Belohnung.")
    elseif why == "yes" then verdict = T("Von dir gewählt.")
    elseif why == "log" then verdict = T("Steht schon in deinem Questlog.")
    else verdict = "|cff9d9d9d" .. T("Ausgelassen: %s", P.SkipText(o, plan, T) or "") .. "|r" end
    local values = {}
    for _, v in ipairs(o.value) do
        if v.kind == "upgrade" then values[#values + 1] = T("Upgrade +%d %% für dich", v.pct)
        elseif v.kind == "bag" then values[#values + 1] = T("Tasche mit %d Plätzen", v.slots)
        elseif v.kind == "gold" then values[#values + 1] = T("%d Silber", math.floor(v.money / 100)) end
    end
    return rows, verdict, values, o
end

-- Navi zu einem Schritt
function G:Navi(step, quiet)
    local ns = Nav()
    -- Reise-Schritt zum Flugmeister: nur Weltkoordinaten bekannt
    if step and not step.mapID and step.world and ns and ns.Arrow and ns.Arrow.StartWorld then
        local label = step.via and step.via.kind == "flight" and (step.via.from.name or T("Flugmeister"))
            or (step.kind == "fp" and T("Flugmeister")) or (step.kind == "bind" and (step.name or T("Gastwirt")))
            or (step.kind == "train" and (step.name or T("Lehrer"))) or (step.kind == "vendor" and (step.name or T("Händler"))) or T("Abfahrt")
        -- Ueberschrift am Pfeil: Personen "Zu …", Abfahrt ohne Zusatz (Nutzer 24.11.2026)
        local person = (step.via and step.via.kind == "flight") or step.kind == "fp" or step.kind == "bind" or step.kind == "train" or step.kind == "vendor"
        local ok = ns.Arrow:StartWorld(label, step.world[1], step.world[2], step.world[3], {quiet = quiet or nil, prefix = person and "Zu %s" or nil})
        if ok then self.autoKey, self.autoLabel = step.stopKey, ns.Arrow.target end
        return ok
    end
    if not (step and step.mapID) then ONE:Print(T("Für diesen Schritt kennt Guild Trip keinen Ort.")) return false end
    local nav = ONE.modules and ONE.modules.nav
    if not (nav and nav.PointTo) then return false end
    local label
    if step.kind == "dungeon" then label = (G.Catalog(step.key) or {}).name
    elseif step.kind == "travel" then label = step.via and step.via.dep and step.via.dep.name or "Abfahrt"
    elseif step.kind == "train" then label = step.name or "Lehrer"
    elseif step.kind == "vendor" then label = step.name or "Händler"
    elseif step.kind == "grind" then return false
    elseif step.actions[1] then label = G.Title(step.actions[1].id)
    else label = step.name or "" end
    -- Ankunftsklang je Ziel-Art (Questgeber, Abgabe, Zielgebiet)
    local first = step.actions and step.actions[1]
    -- Ueberschrift am Pfeil: Quests ohne Zusatz, Lehrer/Haendler "Zu …" (Nutzer 24.11.2026: "Zu Von Hass zerfressen")
    local opts = {quiet = quiet or nil, area = step.area, arrive = first and first.kind or nil,
        prefix = (step.kind == "train" or step.kind == "vendor") and "Zu %s" or nil}
    local ok = nav:PointTo(T(label or ""), step.mapID, step.x, step.y, opts)
    local arrow = Nav() and Nav().Arrow
    if ok and arrow then self.autoKey, self.autoLabel = step.stopKey, arrow.target end
    return ok
end

-- Gruppe suchen (Elite-/Dungeon-Quests) ueber den Gruppenfinder
function G:FindGroup(id)
    local nav = Nav()
    if nav and nav.Quests and nav.Quests.FindGroup then
        return nav.Quests:FindGroup({id = id, title = G.Title(id), group = 5})
    end
end

-- Nutzlos gewordene Quests abbrechen – nur auf Klick des Spielers und nach Rueckfrage (Nutzer 20.11.2026:
-- "abbrechen ohne selbst ins Questlog zu muessen ist schon cool ... nur selbst klicken muss man halt")
function G.AbandonQuest(id)
    local CQ = rawget(_G, "C_QuestLog")
    if CQ and CQ.SetSelectedQuest and CQ.SetAbandonQuest and CQ.AbandonQuest then
        local ok = pcall(function() CQ.SetSelectedQuest(id) CQ.SetAbandonQuest() CQ.AbandonQuest() end)
        return ok
    end
    local idx = CQ and Try(CQ.GetLogIndexForQuestID, id)
    local sel, set, ab = rawget(_G, "SelectQuestLogEntry"), rawget(_G, "SetAbandonQuest"), rawget(_G, "AbandonQuest")
    if type(idx) == "number" and idx > 0 and sel and set and ab then
        return (pcall(function() sel(idx) set() ab() end))
    end
    return false
end
function G:AskAbandon(ids)
    if type(ids) ~= "table" or #ids == 0 then return false end
    -- ohne Rueckfrage-Fenster nie abbrechen
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return false end
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = G.Title(id) end
    local list = {}
    for _, id in ipairs(ids) do list[#list + 1] = id end
    StaticPopupDialogs.GUILDTRIP_ABANDON = {
        text = (#list == 1 and T("Quest abbrechen?") or T("%d Quests abbrechen?", #list)) .. "\n\n" .. table.concat(names, "\n")
            .. "\n\n" .. T("Der Fortschritt geht verloren."),
        button1 = T("Ja"), button2 = T("Nein"),
        OnAccept = function()
            local i = 0
            local function Next()
                i = i + 1
                if list[i] then
                    G.AbandonQuest(list[i])
                    local after = rawget(_G, "C_Timer") and C_Timer.After
                    if after then after(.3, Next) else Next() end
                end
            end
            Next()
        end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }
    StaticPopup_Show("GUILDTRIP_ABANDON")
    return true
end

-- Quest direkt im Kasten abwaehlen (Nutzer 21.11.2026: "koennen wir die quests auch direkt im fenster abwaehlen?"):
-- Rechtsklick auf die Zeile -> Rueckfrage; erst nach Ja abgewaehlt, die Fuehrung plant ohne sie. Rueckgaengig ueber
-- die Quest-Seite.
function G:AskSkip(ids)
    if type(ids) ~= "table" or #ids == 0 then return false end
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return false end
    local list, names, seen = {}, {}, {}
    for _, id in ipairs(ids) do
        if not seen[id] then seen[id] = true list[#list + 1] = id names[#names + 1] = "„" .. G.Title(id) .. "“" end
    end
    StaticPopupDialogs.GUILDTRIP_SKIP = {
        text = (#list == 1 and T("Quest abwählen?") or T("%d Quests abwählen?", #list)) .. "\n\n" .. table.concat(names, "\n")
            .. "\n\n" .. T("Die Quest-Führung plant ohne sie weiter. Rückgängig: Quest-Seite."),
        button1 = T("Ja"), button2 = T("Nein"),
        OnAccept = function()
            local db = G:DB()
            for _, id in ipairs(list) do db.override[id] = "no" end
            G:Replan()
        end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }
    StaticPopup_Show("GUILDTRIP_SKIP")
    return true
end

function G:SetOverride(id, value)
    local db = self:DB()
    db.override[id] = value
    self:Replan()
end

-- Entfernung zum Schritt (Yards) fuer den Kasten
function G:Distance(step)
    local nav = ONE.modules and ONE.modules.nav
    if step and not step.mapID and step.world then
        local tr = Nav() and Nav().Travel
        local pc, px, py
        if tr then pc, px, py = tr.PlayerWorld() end
        if pc and pc == step.world[1] then return math.sqrt((px - step.world[2]) ^ 2 + (py - step.world[3]) ^ 2) end
        return nil
    end
    -- Quest-Ziel als Gebiet: Entfernung zum naechsten Spawnpunkt (wie der Pfeil)
    if step and step.area then
        local n = Nav()
        local tr, A = n and n.Travel, n and n.Arrow
        if tr and A and A.AreaNearest then
            local _, d = A.AreaNearest(step.area, tr.PlayerWorld())
            if d then return d end
        end
    end
    if not (step and step.mapID and nav and nav.DistanceTo) then return nil end
    return Try(nav.DistanceTo, nav, step.mapID, step.x, step.y)
end

-- Bis zur naechsten Stufe: Anzahl Abgaben + Minuten aus dem Plan
function G:ToNextLevel()
    local plan = self.plan
    if not plan then return nil end
    local need = (Try(UnitXPMax, "player") or 0) - (Try(UnitXP, "player") or 0)
    if need <= 0 then return nil end
    local xp, minutes, n = 0, 0, 0
    for _, s in ipairs(plan.steps) do
        minutes = minutes + (s.walk or 0)
        for _, a in ipairs(s.actions) do
            local o = plan.info[a.id]
            if o and a.kind == "turnin" then xp = xp + o.xp n = n + 1 minutes = minutes + P.TALK_MIN end
            if o and a.kind == "obj" then xp = xp + o.work * o.mobXP minutes = minutes + o.work * P.KILL_SEC / 60 end
        end
        if xp >= need then return n, minutes end
    end
    return nil
end

-- Pruefbefehl (Forever erlaubt kein /run): warum steht der erste Schritt da? Zeigt nur an, sendet nichts.
function G:PlanInfo()
    local c = self:Context()
    local p = self.plan
    local ports = {}
    for _, pt in ipairs(c.ports or {}) do ports[#ports + 1] = tostring(pt.name) end
    ONE:Print(T("Plan-Info: Stufe %d, Tempo %.1f, Arbeitsgebiet %s, Gebiet %s, Reisezauber: %s",
        c.me.level or 0, c.speed or 0, tostring(c.workZone), tostring(c.me.mapID), #ports > 0 and table.concat(ports, ", ") or "-"))
    if not p then ONE:Print(T("Plan-Info: kein Plan")) return end
    ONE:Print(T("Plan-Info: lohnt ab %.0f EP/min, %d Schritte", (p.grind or 0) * (p.factor or 0), #p.steps))
    -- Schleifen um Stuetzpunkte (21.11.2026): je Runde Gebiet, Dauer, EP/min
    for i = 1, math.min(4, #(p.loops or {})) do
        local l = p.loops[i]
        if l and l.minutes then
            ONE:Print(T("Runde %d: %s, %.0f min, %.0f EP/min", i, G.ZoneName(l.mapID), l.minutes, l.epm or 0))
        end
    end
    for i = 1, math.min(3, #p.steps) do
        local st = p.steps[i]
        local acts = {}
        for _, a in ipairs(st.actions or {}) do
            local o = p.info[a.id]
            acts[#acts + 1] = ("%s %d %s (%s, %.0f EP/min in der Runde, Weg %.1f min)"):format(a.kind, a.id, G.Title(a.id) or "?",
                tostring(p.chosen[a.id]), o and (o.loopEPM or o.epm) or 0, o and o.travel or 0)
        end
        ONE:Print(("%d. [Runde %s] %s %.1f min %s: %s"):format(i, tostring(st.loop or "-"), st.kind, st.walk or 0, st.via and st.via.kind or "",
            #acts > 0 and table.concat(acts, "; ") or tostring(st.name or st.lvl or "")))
    end
end

function G:Initialize()
    if self.started then return end
    self.started = true
    if ONE.RegisterSlash then
        ONE:RegisterSlash("planinfo", function() G:PlanInfo() end, T("Quest-Führung: warum der nächste Schritt (Prüfung)"))
    end
    local f = CreateFrame("Frame")
    local events = {"PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP",
        "QUEST_LOG_UPDATE", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
        "LEARNED_SPELL_IN_TAB", "TRAINER_CLOSED", "TAXIMAP_CLOSED", "HEARTHSTONE_BOUND", "PLAYER_CONTROL_GAINED", "PLAYER_XP_UPDATE"}
    for _, e in ipairs(events) do pcall(f.RegisterEvent, f, e) end
    pcall(f.RegisterEvent, f, "PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, a)
        if not G:Wants(event, a) then return end
        G:Later(event == "QUEST_LOG_UPDATE" and 2 or 1, G.IsFresh(event, a))
    end)
    -- weit weg vom Ort der letzten Planung (Flug im selben Gebiet, Ruhestein, Teleport): neu planen
    -- (Spieltest 20.11.2026: Plan beim Abflug in Ratchet gerechnet, nach der Landung in Crossroads noch der alte)
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < G.MOVED_EVERY then return end
        acc = 0
        if G:MovedAway() then G:Later(1)
        else
            -- "Ruhestein setzen" ist dran: geaenderten Bindeort bemerken, auch ohne Spielmeldung
            local st = G.plan and G.plan.steps[1]
            if st and st.kind == "bind" then
                local bind = Try(rawget(_G, "GetBindLocation"))
                if G.lastBind ~= nil and bind ~= G.lastBind then G:Later(1) end
                G.lastBind = bind
            else G.lastBind = nil end
        end
    end)
    G:Later(2)
end

-- Echte Aenderung -> frisch planen statt dem Fahrplan folgen (Nutzer 20.11.2026: "er wird schon noch sehen,
-- dass ich vielleicht schneller gelevelt habe als geplant und die quests dementsprechend anpasst?")
G.turned = {}
-- Spieltest 20.11.2026: Stufenaufstieg mitten auf dem Weg -> frischer Plan schickte zurueck zu einer neuen Quest.
-- Deshalb: kein Ereignis wirft den Fahrplan weg. Stufe/Gruppe/Abbruch aendern nur die AUSWAHL (neue Quests kommen
-- dazu, graue fallen weg) – die Reihenfolge der alten Halte bleibt. Frisch nur ueber Einstellungen und /reload.
function G.IsFresh() return false end
G.MOVED_EVERY = 5     -- Sekunden zwischen zwei Blicken
G.MOVED_YARDS = 400   -- so weit weg vom Planungsort: neu planen
function G.PlayerWorldPos()
    local nav = Nav()
    local tr = nav and nav.Travel
    if not (tr and tr.PlayerWorld) then return nil end
    local c, x, y = tr.PlayerWorld()
    if c and x and y then return {c, x, y} end
end
function G:MovedAway()
    if Try(rawget(_G, "UnitOnTaxi"), "player") then return false end
    local at, now = self.planAt, G.PlayerWorldPos()
    if not (at and now) then return false end
    if at[1] ~= now[1] then return true end
    return ((now[2] - at[2]) ^ 2 + (now[3] - at[3]) ^ 2) > G.MOVED_YARDS ^ 2
end

-- Lohnt sich Neuplanen? (Spart Rechenzeit beim Questen: WoW meldet QUEST_LOG_UPDATE nach fast jedem Kill.)
-- Fortschritt "3/8" zeigt der Kasten selbst an – neu geplant wird nur, wenn sich am Plan etwas aendern kann.
-- Quest-IDs im Log (ohne Kopfzeilen)
-- Quests mit Zeitlimit im Log (Nutzer 23.11.2026: "es gibt auch Quests, die zeitkritisch sind"):
-- {[questID] = Restsekunden}. Erst C_QuestLog.GetTimeAllowed (neuer Client), sonst GetQuestTimers (Classic).
-- Nur Lese-Abfragen; Forever-Pruefung im Spiel: /trip zeit
function G.QuestTimers()
    local out = {}
    local QL = C_QuestLog
    local Allowed = QL and QL.GetTimeAllowed
    if type(Allowed) == "function" then
        for _, id in ipairs(G.LogIDs()) do
            local ok, total, elapsed = pcall(Allowed, id)
            if ok and type(total) == "number" and total > 0 and type(elapsed) == "number" then out[id] = math.max(0, total - elapsed) end
        end
    end
    if next(out) == nil and type(GetQuestTimers) == "function" and type(GetQuestIndexForTimer) == "function" then
        local qt = {pcall(GetQuestTimers)}
        if qt[1] then
            for i = 2, table.maxn(qt) do
                local left = tonumber(qt[i])
                local okI, index = pcall(GetQuestIndexForTimer, i - 1)
                local info = okI and index and QL and QL.GetInfo and Try(QL.GetInfo, index)
                if left and type(info) == "table" and info.questID then out[info.questID] = left end
            end
        end
    end
    return out
end
-- Zeitquest zuerst: den ersten Schritt mit dieser Quest (Ziel oder Abgabe) an den Anfang des Plans, die mit der
-- wenigsten Restzeit gewinnt. plan.timed = {id, left, at}
function G.TimedFirst(plan, timers)
    if not (plan and plan.steps) then return end
    local bestID, bestLeft
    for id, left in pairs(timers or {}) do
        if not bestLeft or left < bestLeft then bestID, bestLeft = id, left end
    end
    if not bestID then return end
    for i, st in ipairs(plan.steps) do
        for _, a in ipairs(st.actions or {}) do
            if a.id == bestID and (a.kind == "obj" or a.kind == "turnin") then
                if i > 1 then table.remove(plan.steps, i) table.insert(plan.steps, 1, st) end
                plan.timed = {id = bestID, left = bestLeft, at = Try(GetTime) or 0}
                return true
            end
        end
    end
end
function G.LogIDs()
    local QL = C_QuestLog
    local n = Try(QL and QL.GetNumQuestLogEntries) or 0
    local out = {}
    for i = 1, n do
        local info = Try(QL.GetInfo, i)
        if type(info) == "table" and info.questID and not info.isHeader then out[#out + 1] = info.questID end
    end
    return out
end
function G.LogSignature()
    local QL = C_QuestLog
    local n = Try(QL and QL.GetNumQuestLogEntries) or 0
    local parts = {}
    for i = 1, n do
        local info = Try(QL.GetInfo, i)
        if type(info) == "table" and info.questID and not info.isHeader then
            parts[#parts + 1] = info.questID .. (Try(QL.IsComplete, info.questID) and "+" or "")
        end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

function G:Wants(event, arg)
    if event == "PLAYER_REGEN_ENABLED" then
        local was = self.deferred
        self.deferred = nil
        return was == true
    end
    if event == "PLAYER_XP_UPDATE" then
        -- nur wenn "Monster hauen bis X EP" erreicht ist
        local st = self.plan and self.plan.steps[1]
        return st and st.kind == "grind" and st.toXP and (Try(UnitXP, "player") or 0) >= st.toXP or false
    end
    if event == "QUEST_LOG_UPDATE" then
        local sig = G.LogSignature()
        if sig == self.logSig then return false end
        self.logSig = sig
    elseif event == "BAG_UPDATE_DELAYED" then
        -- neue Tasche (Belohnungen) oder Taschen werden voll bzw. wieder leer (Haendler-Schritt, Nutzer 21.11.2026)
        local small = SmallestBag()
        local free = G.FreeBagSlots()
        local low = free and free <= G.VENDOR_BAGS or false
        if small == self.lastBag and low == self.lastLow and not (low and free ~= self.lastFree) then return false end
        self.lastBag, self.lastLow, self.lastFree = small, low, free
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- nur Belohnungen der Fuehrung (fuer "Upgrade") sind interessant
        local R = rawget(_G, "GuildTripLeveling")
        if not (R and R.i and arg and R.i[arg]) then return false end
    end
    return true
end
