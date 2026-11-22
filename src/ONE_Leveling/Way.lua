-- Guild Trip 0.7.1: "Ausrüstung auf deinem Weg" (Leveln › Ausrüstung).
-- Fuer jeden Platz am Charakter: das Beste, was du auf deiner Stufe bekommen kannst –
-- aus Quests, Dungeons, Herstellung (selbst, bald selbst oder durch die Gilde) –,
-- wie viel besser es als dein getragenes Teil ist, und bis zu welcher Stufe es haelt.
-- Daten: GearData.lua (scripts/import_gear.py). Bewertung: dieselbe Werte-Rangfolge wie der
-- Tooltip "besser fuer dich" (ONE_Classes/Gear.lua), damit beide gleich urteilen.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local W = {}
lev.Way = W

local unpack = unpack or table.unpack
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, table.maxn(r)) end
end
local function Data() local g = rawget(_G, "GuildTripGear") return type(g) == "table" and type(g.items) == "table" and g or nil end
W.Data = Data

-- ===== Plaetze =====
-- InventoryType der Gegenstaende -> Anzeige-Platz; worn = Charakter-Plaetze zum Vergleich
W.SLOTS = {
    {key = "head", name = "Kopf", inv = {[1] = true}, worn = {1}},
    {key = "neck", name = "Hals", inv = {[2] = true}, worn = {2}},
    {key = "shoulder", name = "Schultern", inv = {[3] = true}, worn = {3}},
    {key = "back", name = "Rücken", inv = {[16] = true}, worn = {15}},
    {key = "chest", name = "Brust", inv = {[5] = true, [20] = true}, worn = {5}},
    {key = "wrist", name = "Handgelenke", inv = {[9] = true}, worn = {9}},
    {key = "hands", name = "Hände", inv = {[10] = true}, worn = {10}},
    {key = "waist", name = "Taille", inv = {[6] = true}, worn = {6}},
    {key = "legs", name = "Beine", inv = {[7] = true}, worn = {7}},
    {key = "feet", name = "Füße", inv = {[8] = true}, worn = {8}},
    {key = "finger", name = "Finger", inv = {[11] = true}, worn = {11, 12}},
    {key = "trinket", name = "Schmuck", inv = {[12] = true}, worn = {13, 14}},
    {key = "weapon", name = "Waffe", inv = {[13] = true, [17] = true, [21] = true}, worn = {16}},
    {key = "offhand", name = "Nebenhand", inv = {[14] = true, [22] = true, [23] = true}, worn = {17}},
    {key = "ranged", name = "Fernkampf", inv = {[15] = true, [25] = true, [26] = true}, worn = {18}},
}
-- Waffenarten (Unterklasse von Klasse 2), die eine Klasse fuehren kann
W.WEAPONS = {
    WARRIOR = {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18},
    PALADIN = {0, 1, 4, 5, 6, 7, 8},
    HUNTER = {0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18},
    ROGUE = {2, 3, 4, 7, 13, 15, 16, 18},
    PRIEST = {4, 10, 15, 19},
    SHAMAN = {0, 1, 4, 5, 10, 13, 15},
    MAGE = {7, 10, 15, 19},
    WARLOCK = {7, 10, 15, 19},
    DRUID = {4, 5, 10, 13, 15},
}
W.SHIELD = {WARRIOR = true, PALADIN = true, SHAMAN = true}
-- Klassen-Bitmaske (cls in den Werten): 1 Krieger, 2 Paladin, 4 Jaeger, 8 Schurke, 16 Priester,
-- 64 Schamane, 128 Magier, 256 Hexenmeister, 1024 Druide
W.CLASS_BIT = {WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024}
-- Ruestung: hoechste Art, ab Stufe 40 eine Stufe mehr (Kette fuer Jaeger/Schamane, Platte fuer Krieger/Paladin)
function W.MaxArmor(classFile, level)
    local m = ({PRIEST = 1, MAGE = 1, WARLOCK = 1, ROGUE = 2, DRUID = 2, HUNTER = 3, SHAMAN = 3, WARRIOR = 4, PALADIN = 4})[classFile or ""] or 1
    if (level or 1) < 40 and (classFile == "HUNTER" or classFile == "SHAMAN" or classFile == "WARRIOR" or classFile == "PALADIN") then m = m - 1 end
    return m
end
-- Berufsnamen der Daten (englisch) -> Spielsprache
W.PROF = {
    Tailoring = "Schneiderei", Leatherworking = "Lederverarbeitung", Blacksmithing = "Schmiedekunst",
    Engineering = "Ingenieurskunst", Alchemy = "Alchemie", Enchanting = "Verzauberkunst",
    Cooking = "Kochkunst", ["First Aid"] = "Erste Hilfe", Jewelcrafting = "Juwelierskunst",
}
function W.ProfName(en)
    local locale = Try(GetLocale)
    if locale == "deDE" then return W.PROF[en] or en end
    return en
end

-- ===== Eintrag lesen =====
-- "inv ilvl req quality class subclass [werte]" -> Tabelle; Werte als Gruppen wie in ONE_Classes/Gear
local STAT_KEY = {armor = "armor", str = "str", agi = "agi", sta = "sta", int = "int", spi = "spi", sp = "sp",
    heal = "heal", ap = "ap", rap = "ap", crit = "crit", hit = "hit", mpr = "mp5", defense = "def"}
local cache = {}
function W.Item(id)
    if cache[id] ~= nil then return cache[id] or nil end
    local d = Data()
    local s = d and d.items[id]
    if type(s) ~= "string" then cache[id] = false return nil end
    local f = {}
    for w in s:gmatch("%S+") do f[#f + 1] = w end
    local it = {id = id, inv = tonumber(f[1]), ilvl = tonumber(f[2]) or 0, req = tonumber(f[3]) or 0,
        quality = tonumber(f[4]) or 1, class = tonumber(f[5]), sub = tonumber(f[6]), stats = {}}
    local dmin, dmax, speed
    for i = 7, #f do
        local k, v = f[i]:match("^(%a+)(%-?%d+)$")
        v = tonumber(v)
        if k == "dmin" then dmin = v elseif k == "dmax" then dmax = v elseif k == "speed" then speed = v
        elseif k == "cls" then it.classMask = v
        elseif k == "uniq" then it.unique = true
        elseif k and STAT_KEY[k] then it.stats[STAT_KEY[k]] = (it.stats[STAT_KEY[k]] or 0) + v end
    end
    if dmin and dmax and speed and speed > 0 then it.stats.dps = math.floor((dmin + dmax) / 2 / (speed / 1000) * 10 + .5) / 10 end
    -- ohne Mindeststufe: Gegenstandsstufe als Anhalt (Quests/Drops dieser Stufe)
    if it.req == 0 then it.reqGuess = math.max(1, it.ilvl - 5) end
    cache[id] = it
    return it
end
function W.ReqLevel(it) return it.req > 0 and it.req or it.reqGuess or 1 end

-- Darf die Klasse den Gegenstand tragen/fuehren?
function W.Usable(it, classFile, level)
    if it.classMask and it.classMask > 0 then
        local bit = W.CLASS_BIT[classFile or ""]
        if bit and math.floor(it.classMask / bit) % 2 == 0 then return false end
    end
    if it.class == 4 then
        if it.sub == 6 then return W.SHIELD[classFile or ""] == true end
        if it.sub and it.sub >= 1 and it.sub <= 4 and it.inv ~= 16 then return it.sub <= W.MaxArmor(classFile, level) end
        if it.sub and it.sub >= 7 then return false end -- Buchbaende, Goetzen, Totems
        return true
    end
    if it.class == 2 then
        if it.sub == 20 then return false end -- Angel
        for _, s in ipairs(W.WEAPONS[classFile or ""] or {}) do if s == it.sub then return true end end
        return false
    end
    return true
end
function W.SlotOf(it)
    for _, s in ipairs(W.SLOTS) do if s.inv[it.inv or 0] then return s end end
end

-- ===== Bewertung =====
-- Gewichte wie im Tooltip (Ausrichtung, Rolle); ohne Klassenmodul Grundgewichte der Klasse
function W:Context()
    local classes = ONE.ns and ONE.ns.classes
    local _, classFile = Try(UnitClass, "player")
    local level = Try(UnitLevel, "player") or 1
    local ctx = {classFile = classFile, level = level, spec = "", faction = Try(UnitFactionGroup, "player")}
    -- Quest-Filter wie die Fuehrung (Fraktion, Volk, Klasse, erledigt, Vorquests)
    local g = lev.Guide and Try(lev.Guide.Context, lev.Guide)
    if g then ctx.me, ctx.done, ctx.inLog = g.me, g.done, g.inLog end
    if classes and classes.Player and classes.Data and classes.Gear then
        local store = ONE.db and ONE.db.classGuide or {}
        local p = Try(classes.Player.Read, classes.Player, store.spec)
        local def = p and classes.Data.classes[p.classFile or ""]
        if def then
            local build = Try(classes.Data.Build, classes.Data, def, p.spec, p.situation)
            local role = def.roles and def.roles[p.spec] or "caster"
            ctx.weights = classes.Gear.Weights(build, role)
            ctx.spec = def.specs and def.specs[p.spec] or ""
            ctx.ranks = build and build.stats
        end
    end
    if not ctx.weights then
        local base = classes and classes.Gear and classes.Gear.BASE
        local role = ({WARRIOR = "melee", PALADIN = "melee", ROGUE = "agile", HUNTER = "hunter", DRUID = "agile",
            SHAMAN = "melee", PRIEST = "healer"})[classFile or ""] or "caster"
        ctx.weights = base and base[role] or {sta = .5, str = .5, agi = .5, int = .5, spi = .3, armor = .02, dps = 1}
    end
    return ctx
end
function W.Score(it, weights)
    local s = 0
    for k, v in pairs(it.stats) do s = s + v * (weights[k] or 0) end
    return s
end

-- Getragenes Teil (schlechteres von zwei Ringen/Schmuckstuecken)
function W:Worn(slot, ctx)
    local classes = ONE.ns and ONE.ns.classes
    local G = classes and classes.Gear
    local worst, link, any
    for _, inv in ipairs(slot.worn) do
        local l = Try(GetInventoryItemLink, "player", inv)
        if l then
            any = true
            local stats = G and G.WornStats and G.WornStats(inv, l) or {}
            local sc = 0
            for k, v in pairs(stats or {}) do sc = sc + v * (ctx.weights[k] or 0) end
            if not worst or sc < worst then worst, link = sc, l end
        else
            worst, link = 0, nil
        end
    end
    return worst or 0, link, any
end

-- ===== Herkunft =====
local function Planner() return lev.Planner end
local function QuestDB() return rawget(_G, "GuildTripQuestDB") end
local function NpcName(npc)
    if not npc or npc == 0 then return nil end
    local d = Data()
    local q = QuestDB()
    return (q and q.names and q.names[npc]) or (d and d.npcs and d.npcs[npc]) or ("#" .. tostring(npc))
end
W.NpcName = NpcName
local function Catalog(key)
    local dg = ONE.ns and ONE.ns.dungeons
    for _, c in ipairs(dg and dg.Catalog or {}) do if c.key == key then return c end end
end
W.Catalog = Catalog
-- Dungeon der anderen Fraktion (Katalog-Feld faction, z. B. Halle der Thanen = Allianz)?
function W.EnemyDungeon(key, faction)
    local c = Catalog(key)
    return (c and c.faction and faction and (faction == "Alliance" or faction == "Horde") and c.faction ~= faction) and true or false
end

-- Faktion eines NPCs aus dem Verzeichnis (1 Allianz, 2 Horde, 3 beide; unbekannt = passt)
local function NpcFits(npc, faction)
    local q = QuestDB()
    local t = q and q.trainers and q.trainers[npc]
    local v = q and q.vendors and q.vendors[npc]
    local f = (t and t[6]) or (v and v[4])
    if not f or f == 3 then return true end
    return (faction == "Alliance" and f == 1) or (faction == "Horde" and f == 2)
end
W.NpcFits = NpcFits

-- Eigene Berufe: {["Schneiderei"] = {skill, max}}
function W.MyProfessions()
    local crafting = ONE.ns and ONE.ns.crafting
    if crafting and crafting.Trainers and crafting.Trainers.MyProfessions then return crafting.Trainers:MyProfessions() end
    return {}
end
-- Wer kann den Zauber (Rezept) herstellen? me = gelernt; guild = {Namen}, online zuerst
function W.Crafters(spell, ctx)
    local crafting = ONE.ns and ONE.ns.crafting
    local out = {me = false, guild = {}}
    if not (crafting and crafting.Recipes) then return out end
    -- Rezeptliste einmal je Planung lesen
    if ctx and not ctx.catalog then ctx.catalog = Try(crafting.Recipes.Catalog, crafting.Recipes) or {} end
    local catalog = ctx and ctx.catalog or Try(crafting.Recipes.Catalog, crafting.Recipes) or {}
    local online = {}
    if type(GetNumGuildMembers) == "function" and type(GetGuildRosterInfo) == "function" then
        for i = 1, (Try(GetNumGuildMembers) or 0) do
            local name, _, _, _, _, _, _, _, isOnline = Try(GetGuildRosterInfo, i)
            if name and isOnline then online[name] = true online[name:match("^[^%-]+") or name] = true end
        end
    end
    for _, e in ipairs(catalog) do
        if e.recipeID == spell then
            for _, c in ipairs(e.crafters) do
                if c.me then out.me = true
                else out.guild[#out.guild + 1] = {name = c.name, online = online[c.name] or online[c.name:match("^[^%-]+") or c.name] or false} end
            end
        end
    end
    table.sort(out.guild, function(a, b) if a.online ~= b.online then return a.online end return a.name < b.name end)
    return out
end

-- Wo lernt man das Rezept? Liste {kind="t"|"v"|"d"|"w"|"q"|"r", text, npc, cost, skill}
function W.LearnOptions(spell, faction)
    local d = Data()
    local out = {}
    for _, l in ipairs(d and d.learn and d.learn[spell] or {}) do
        local k = l[1]
        if k == "t" and NpcFits(l[2], faction) then
            out[#out + 1] = {kind = "t", npc = l[2], skill = l[3], cost = l[4]}
        elseif k == "v" and NpcFits(l[2], faction) then
            out[#out + 1] = {kind = "v", npc = l[2], recipe = l[3], limited = l[4] == 1}
        elseif k == "d" and not W.EnemyDungeon(l[2], faction) then
            out[#out + 1] = {kind = "d", dungeon = l[2], npc = l[3], recipe = l[4], chance = l[5]}
        elseif k == "w" then
            out[#out + 1] = {kind = "w", npc = l[2], recipe = l[3], chance = l[4]}
        elseif k == "q" then
            out[#out + 1] = {kind = "q", quest = l[2], recipe = l[3]}
        elseif k == "r" then
            out[#out + 1] = {kind = "r", recipe = l[2], mobs = l[3]}
        end
    end
    -- Lehrer zuerst (sicher, guenstig), dann Haendler, dann Drops
    local order = {t = 1, v = 2, q = 3, d = 4, w = 5, r = 6}
    table.sort(out, function(a, b) return (order[a.kind] or 9) < (order[b.kind] or 9) end)
    return out
end

-- Alle erreichbaren Quellen eines Gegenstands fuer dich. Liefert Liste
-- {kind, sure (verlaesslich?), ...} – leer = fuer dich nicht zu bekommen.
function W:Sources(id, ctx)
    local d = Data()
    local list = {}
    local P = Planner()
    local Q = QuestDB()
    for _, s in ipairs(d and d.src and d.src[id] or {}) do
        local k = s[1]
        if k == "q" then
            local e = Q and Q.q and Q.q[s[2]]
            local ok = e ~= nil
            if ok and P and P.Fits and ctx.me then
                ok = P.Fits(s[2], e, ctx.me, ctx.done, ctx.inLog)
            elseif ok and ctx.done then ok = not ctx.done(s[2]) end
            if ok then list[#list + 1] = {kind = "q", quest = s[2], level = e and e[1], min = e and e[2], sure = true} end
        elseif k == "d" and W.EnemyDungeon(s[2], ctx.faction) then
            -- Eingang in der Hauptstadt der anderen Fraktion: nicht vorschlagen
        elseif k == "d" then
            local c = Catalog(s[2])
            local chance = s[4] or 0
            list[#list + 1] = {kind = "d", dungeon = s[2], npc = s[3], chance = chance, min = c and c.min, max = c and c.max,
                sure = chance == 0 or chance >= 3}
        elseif k == "w" then
            list[#list + 1] = {kind = "w", zone = s[2], npc = s[3], chance = s[4] or 0, sure = (s[4] or 0) >= 10}
        elseif k == "c" then
            local prof = W.ProfName(s[2])
            local mine = W.MyProfessions()[prof]
            local who = W.Crafters(s[4], ctx)
            local learn = W.LearnOptions(s[4], ctx.faction)
            local status
            if who.me then status = "self"
            elseif mine and mine.skill >= (s[3] or 0) and #learn > 0 then status = "learn"
            elseif mine and #learn > 0 then status = "soon"
            elseif #who.guild > 0 then status = "guild"
            else status = "none" end
            list[#list + 1] = {kind = "c", prof = prof, skill = s[3] or 0, spell = s[4], status = status,
                mine = mine, guild = who.guild, learn = learn, sure = status ~= "none"}
        end
    end
    return list
end

-- ===== Plan je Platz =====
-- Liefert Liste je Platz: {slot, now = {item, score, sources}, next = {...}, holdsTo, worn, plus}
W.HORIZON = 5        -- "bald": bis 5 Stufen ueber dir
W.BETTER = 1.15      -- haelt, bis etwas 15 % Besseres kommt
W.QUEST_ABOVE = 3    -- Quests hoechstens 3 Stufen ueber dir
function W:Plan(ctx)
    ctx = ctx or self:Context()
    local d = Data()
    if not d then return {} end
    local L = ctx.level
    -- Kandidaten nach Platz
    local bySlot = {}
    for id in pairs(d.items) do
        local it = W.Item(id)
        if it and W.Usable(it, ctx.classFile, L + W.HORIZON) then
            local slot = W.SlotOf(it)
            if slot then
                local req = W.ReqLevel(it)
                if req <= 60 then
                    it.score = W.Score(it, ctx.weights)
                    if it.score > 0 then
                        bySlot[slot.key] = bySlot[slot.key] or {}
                        table.insert(bySlot[slot.key], it)
                    end
                end
            end
        end
    end
    local out = {}
    for _, slot in ipairs(W.SLOTS) do
        local cands = bySlot[slot.key] or {}
        table.sort(cands, function(a, b) return a.score > b.score end)
        local row = {slot = slot}
        local wornScore, wornLink, wornAny = self:Worn(slot, ctx)
        row.wornScore, row.wornLink = wornScore, wornLink
        -- erreichbare Quelle (verlaesslich) fuer Stufe <= lvl
        local srcCache = {}
        local function Reach(it, maxReq)
            if W.ReqLevel(it) > maxReq then return nil end
            if srcCache[it.id] == nil then
                local ss = self:Sources(it.id, ctx)
                local sure = {}
                for _, s in ipairs(ss) do
                    local okLevel = true
                    if s.kind == "d" and s.min and s.min > maxReq + 2 then okLevel = false end
                    if s.kind == "q" and s.min and s.min > maxReq then okLevel = false end
                    -- Quests weit ueber deiner Stufe sind (noch) nicht zu schaffen
                    if s.kind == "q" and s.level and s.level > maxReq + W.QUEST_ABOVE then okLevel = false end
                    if s.sure and okLevel then sure[#sure + 1] = s end
                end
                srcCache[it.id] = #sure > 0 and {sure = sure, all = ss} or false
            end
            return srcCache[it.id] or nil
        end
        for _, it in ipairs(cands) do
            local r = Reach(it, L)
            if r then row.now = {item = it, sources = r.sure, all = r.all} break end
        end
        local base = row.now and row.now.item.score or wornScore
        for _, it in ipairs(cands) do
            if W.ReqLevel(it) > L and it.score > base * W.BETTER then
                local r = Reach(it, L + W.HORIZON)
                if r then row.next = {item = it, sources = r.sure, all = r.all} break end
            end
        end
        -- haelt bis: erste Stufe, ab der es (verlaesslich) 15 % Besseres gibt
        if row.now then
            local best
            for _, it in ipairs(cands) do
                local req = W.ReqLevel(it)
                if req > L and it.score > row.now.item.score * W.BETTER and (not best or req < best) then
                    if Reach(it, req) then best = req end
                end
            end
            row.holdsTo = best
            row.plus = wornAny and wornScore > 0 and math.floor((row.now.item.score - wornScore) / wornScore * 100 + .5)
                or (not wornAny and 100) or nil
            row.upgrade = (not wornAny) or row.now.item.score > wornScore * 1.03
        end
        out[#out + 1] = row
    end
    return out
end

-- ===== Texte =====
local function Money(c)
    c = c or 0
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    if g > 0 then return T("%d G %d S", g, s) end
    if s > 0 then return T("%d S", s) end
    return T("%d K", k)
end
W.Money = Money
local function Pct(c) if not c or c == 0 then return "" end return (" · %s %%"):format(c >= 10 and math.floor(c + .5) or c) end
function W.SourceText(s, short)
    if s.kind == "q" then
        local title = lev.Guide and lev.Guide.Title and lev.Guide.Title(s.quest) or ("#" .. s.quest)
        return short and T("Quest: %s", title) or T("Quest „%s“ (Stufe %d)", title, s.level or 0)
    elseif s.kind == "d" then
        local c = Catalog(s.dungeon)
        local name = c and c.name or s.dungeon
        local boss = NpcName(s.npc)
        if short then return boss and T("%s · %s", T(name), boss) or T(name) end
        return (boss and T("Dungeon %s: %s", T(name), boss) or T("Dungeon %s", T(name))) .. Pct(s.chance)
    elseif s.kind == "w" then
        return T("Beute von %s", NpcName(s.npc) or "?") .. Pct(s.chance)
    elseif s.kind == "c" then
        if s.status == "self" then return T("%s – stellst du selbst her", s.prof) end
        if s.status == "learn" then return T("%s – Rezept lernen (du hast den Beruf)", s.prof) end
        if s.status == "soon" then return T("%s %d – bald selbst (du hast %d)", s.prof, s.skill, s.mine and s.mine.skill or 0) end
        if s.status == "guild" then
            local g = s.guild[1]
            return T("%s – %s kann es herstellen", s.prof, g.name:match("^[^%-]+") or g.name) .. (g.online and (" |cff40ff40" .. T("(online)") .. "|r") or "")
        end
        return T("%s %d – niemand in deiner Gilde", s.prof, s.skill)
    end
    return ""
end
function W.LearnText(l)
    if l.kind == "t" then return T("Lehrer %s (Fertigkeit %d, %s)", NpcName(l.npc) or "?", l.skill or 0, Money(l.cost)) end
    if l.kind == "v" then return T("Händler %s%s", NpcName(l.npc) or "?", l.limited and (" " .. T("(begrenzt)")) or "") end
    if l.kind == "d" then
        local c = Catalog(l.dungeon)
        return T("Rezept-Beute in %s von %s", c and T(c.name) or l.dungeon, NpcName(l.npc) or "?") .. Pct(l.chance)
    end
    if l.kind == "w" then return T("Rezept-Beute von %s", NpcName(l.npc) or "?") .. Pct(l.chance) end
    if l.kind == "q" then return T("Rezept aus Quest „%s“", lev.Guide and lev.Guide.Title(l.quest) or l.quest) end
    if l.kind == "r" then return T("seltener Weltdrop (bei %d Gegnerarten)", l.mobs or 0) end
    return ""
end

-- ===== Navi =====
-- Ziel einer Quelle: Questgeber, Dungeon-Eingang, Lehrer/Haendler, Gegner
function W:Navi(s, itemID)
    local navi = ONE.modules and ONE.modules.nav
    if not (s and navi and navi.PointTo) then return false end
    local d = Data()
    local function ToNpc(npc, label)
        local q = QuestDB()
        local t = q and q.trainers and q.trainers[npc]
        if t then return navi:PointTo(label, t[3], t[4] / 1000, t[5] / 1000) end
        local v = q and q.vendors and q.vendors[npc]
        if v then return navi:PointTo(label, v[1], v[2] / 1000, v[3] / 1000) end
        local p = d and d.places and d.places[npc]
        if p then return navi:PointTo(label, p[1], p[2], p[3]) end
        ONE:Print(T("Für %s kennt Guild Trip keinen Ort.", NpcName(npc) or "?"))
        return false
    end
    if s.kind == "q" then
        local Q, P = QuestDB(), Planner()
        local e = Q and Q.q and Q.q[s.quest]
        for _, nr in ipairs(e and e[6] or {}) do
            local m, x, y = P and P.NodePoint and P.NodePoint(Q, nr)
            if m then return navi:PointTo(lev.Guide.Title(s.quest), m, x, y, {arrive = "accept"}) end
        end
        ONE:Print(T("Für diese Quest kennt Guild Trip keinen Questgeber-Ort."))
        return false
    elseif s.kind == "d" then
        local dg = ONE.ns and ONE.ns.dungeons
        local c = Catalog(s.dungeon)
        if dg and dg.Entrances and c then return dg.Entrances:Navi(c) end
    elseif s.kind == "w" then
        return ToNpc(s.npc, NpcName(s.npc) or "?")
    elseif s.kind == "c" then
        if s.status == "learn" or s.status == "soon" then
            for _, l in ipairs(s.learn) do
                if l.kind == "t" or l.kind == "v" then return ToNpc(l.npc, NpcName(l.npc) or "?") end
            end
        end
        if s.status == "guild" and s.guild[1] and type(ChatFrame_OpenChat) == "function" then
            ChatFrame_OpenChat("/w " .. s.guild[1].name .. " " .. (itemID and W.AskText(itemID) or ""))
            return true
        end
    end
    return false
end
-- Bitte an ein Gildenmitglied (Herstellung): Fluesterzeile mit Gegenstand vorbereiten
function W.AskText(itemID)
    local link = Try(C_Item and C_Item.GetItemInfo, itemID) and select(2, Try(C_Item.GetItemInfo, itemID))
    link = link or select(2, Try(GetItemInfo, itemID)) or ("item:" .. itemID)
    return T("Hi! Kannst du mir %s herstellen? Material bringe ich mit.", link)
end

return W
