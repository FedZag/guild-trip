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
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

G.CLASS = {WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024}
G.RACE = {Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128}
G.TEMPO_NAMES = {need = "Nur das Nötigste", balanced = "Ausgewogen", all = "Gründlich"}
G.TAGS = {
    dungeon = {"DUNGEON", "ff9a2e"}, class = {"KLASSE", "f58cba"}, pre = {"VORQUEST", "ffb070"},
    xp = {"EP", "4fd14f"}, upgrade = {"UPGRADE", "5aa9ff"}, group = {"GRUPPE", "ff5a4a"},
}
G.ICON = {
    accept = "|TInterface\\GossipFrame\\AvailableQuestIcon:14:14|t",
    turnin = "|TInterface\\GossipFrame\\ActiveQuestIcon:14:14|t",
    obj = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:13:13|t",
    dungeon = "|TInterface\\Icons\\INV_Misc_Bone_HumanSkull_01:14:14|t",
}

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

function G.Catalog(key)
    local dg = Dungeons()
    for _, c in ipairs(dg and dg.Catalog or {}) do if c.key == key then return c end end
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
    return {
        me = {level = level, class = class and G.CLASS[class], race = race and G.RACE[race],
            faction = Try(UnitFactionGroup, "player") or "?", inGroup = (Try(IsInGroup) and true) or false,
            mapID = mapID, x = x, y = y},
        done = function(id) return Try(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, id) == true end,
        inLog = function(id)
            local i = Try(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, id)
            return type(i) == "number" and i > 0
        end,
        complete = function(id) return Try(C_QuestLog and C_QuestLog.IsComplete, id) == true end,
        world = nav and nav.Travel and nav.Travel.World,
        judge = classes and classes.Gear and classes.Gear.UpgradePercent and function(item)
            if judgeCache[item] == nil then judgeCache[item] = classes.Gear:UpgradePercent(item) or false end
            return judgeCache[item] or nil
        end,
        smallestBag = SmallestBag(),
        tempo = db.tempo,
        override = db.override,
        speed = (Try(IsMounted) and 11) or 7,
        catalog = G.Catalog,
        entrance = function(key)
            local dg = Dungeons()
            local e = dg and dg.Entrances and Try(dg.Entrances.Get, dg.Entrances, key)
            if e then return {e.mapID, e.x, e.y} end
        end,
        prefer = self.plan and self.plan.steps[1] and self.plan.steps[1].stopKey,
    }
end

function G:Replan()
    if not self:Available() or (ONE.IsEnabled and not ONE:IsEnabled("leveling")) then
        self.plan = nil
    else
        local ok, plan = pcall(P.Plan, P, self:Context())
        self.plan = ok and plan or nil
        if not ok and ONE.Debug then ONE:Debug("Quest-Führung: " .. tostring(plan)) end
    end
    for _, fn in ipairs(self.listeners) do pcall(fn, self.plan) end
    pcall(self.AutoNavi, self, self.plan)
    return self.plan
end
function G:OnChange(fn) self.listeners[#self.listeners + 1] = fn end

-- gebuendelt neu planen (Ereignisse kommen oft in Schauern)
function G:Later(delay)
    if self.pending then return end
    self.pending = true
    local function Go() self.pending = false self:Replan() end
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
function G:StepText(step, short, plain)
    if not step then return "" end
    if step.kind == "dungeon" then
        local c = G.Catalog(step.key)
        return G.ICON.dungeon .. " " .. T("Dungeon %s: %d Quests", c and T(c.name) or step.key, #(step.ids or {}))
    end
    local who = G.NodeName(step.nr)
    local parts = {}
    for _, a in ipairs(step.actions) do
        local title = G.Title(a.id)
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
    if not (step and step.mapID and db.autoNavi ~= false and db.tracker) then return false end
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

-- ===== Monster hauen (Grind.lua) – Hinweis, aendert den Plan nicht =====
function G:Grind(plan)
    plan = plan or self.plan
    local Gr = lev.Grind
    if not (Gr and plan) then return nil end
    if self.grindPlan ~= plan then
        local ok, advice = pcall(Gr.Advice, Gr, self:Context(), plan)
        self.grind, self.grindPlan = ok and advice or nil, plan
    end
    return self.grind
end

-- Lager als "Schritt" fuer Navi und Liste
function G.CampStep(c)
    return {kind = "grind", camp = c, mapID = c.mapID, x = c.x, y = c.y, actions = {}, stopKey = "g:" .. c.npc .. ":" .. c.mapID}
end

function G.CampText(c)
    local lvl = c.min == c.max and tostring(c.min) or (c.min .. "–" .. c.max)
    return T("%s (Stufe %s) · %s %d/%d", c.name, lvl, G.ZoneName(c.mapID), math.floor(c.x * 100 + .5), math.floor(c.y * 100 + .5))
end

-- Listeneintraege: Ueberschrift + bis zu drei Lager
function G:GrindItems(advice, always)
    local out = {}
    if not advice or #advice.camps == 0 or not (advice.worth or always) then return out end
    local head
    if advice.reason == "empty" then head = T("MONSTER HAUEN – GERADE KEINE PASSENDEN QUESTS")
    elseif advice.worth then head = T("MONSTER HAUEN LOHNT SICH GERADE")
    else head = T("MONSTER IN DER NÄHE – DEIN PLAN IST SCHNELLER (~%d EP/MIN)", math.floor((advice.planEPM or 0) + .5)) end
    out[#out + 1] = {key = "gh", header = true, text = head}
    for _, c in ipairs(advice.camps) do
        out[#out + 1] = {key = "g" .. c.npc .. ":" .. c.mapID, camp = c, step = G.CampStep(c), dim = not advice.worth,
            text = G.CampText(c), tags = "|cff40ff40" .. T("~%d EP/Min", math.floor(c.epm + .5)) .. "|r"}
    end
    return out
end

-- Warum dieses Lager? Zeilen {{links, rechts}}, Urteil
function G:CampWhy(c, advice)
    local P = lev.Planner
    local plan = self.plan
    local L = plan and plan.level or 1
    local avg = (c.min + c.max) / 2
    local xp = P.MobXP(L, math.floor(avg + .5))
    local secs = lev.Grind.KillSeconds(L, avg, c.count)
    local rows = {
        {T("EP je Gegner (für Stufe %d)", L), tostring(math.floor(xp + .5))},
        {T("Zeit je Gegner (Kampf + Laufen)"), T("~%d s", math.floor(secs + .5))},
        {T("Gegner im Lager"), tostring(c.count)},
        {T("EP pro Minute"), tostring(math.floor(c.epm + .5))},
        {T("Weg dorthin"), T("~%d min", math.max(1, math.floor(c.travel + .5)))},
    }
    if advice and advice.planEPM then rows[#rows + 1] = {T("dein Plan gerade (dieses Gebiet)"), T("~%d EP/Min", math.floor(advice.planEPM + .5))} end
    local verdict
    if advice and advice.reason == "empty" then verdict = T("Gerade keine passenden Quests – hier geht es am schnellsten weiter.")
    elseif advice and advice.worth then verdict = T("Schneller als dein Plan: zwischendurch hier farmen bringt mehr EP pro Minute.")
    else verdict = T("Dein Plan ist gerade schneller – farmen nur, wenn du Lust drauf hast.") end
    return rows, verdict
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
    if o.work > 0 and not o.dungeon then Row(T("+ EP der Gegner (%d × ~%d)", o.work, math.floor(o.mobXP + .5)), tostring(math.floor(o.work * o.mobXP + .5))) end
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
    if not (step and step.mapID) then ONE:Print(T("Für diesen Schritt kennt Guild Trip keinen Ort.")) return false end
    local nav = ONE.modules and ONE.modules.nav
    if not (nav and nav.PointTo) then return false end
    local label = step.kind == "dungeon" and (G.Catalog(step.key) or {}).name
        or step.kind == "grind" and step.camp and T("Monster hauen: %s", step.camp.name)
        or G.Title(step.actions[1].id)
    local ok = nav:PointTo(T(label or ""), step.mapID, step.x, step.y, quiet and {quiet = true} or nil)
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

function G:SetOverride(id, value)
    local db = self:DB()
    db.override[id] = value
    self:Replan()
end

function G:CycleTempo()
    local db = self:DB()
    for i, k in ipairs(P.TEMPO_ORDER) do
        if k == db.tempo then db.tempo = P.TEMPO_ORDER[i % #P.TEMPO_ORDER + 1] break end
    end
    self:Replan()
    return db.tempo
end

-- Entfernung zum Schritt (Yards) fuer den Kasten
function G:Distance(step)
    local nav = ONE.modules and ONE.modules.nav
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

function G:Initialize()
    if self.started then return end
    self.started = true
    local f = CreateFrame("Frame")
    local events = {"PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP",
        "QUEST_LOG_UPDATE", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED"}
    for _, e in ipairs(events) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, event)
        if event == "GET_ITEM_INFO_RECEIVED" or event == "QUEST_LOG_UPDATE" or event == "BAG_UPDATE_DELAYED" then G:Later(3)
        else G:Later(1) end
    end)
    G:Later(2)
end
