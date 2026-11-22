-- Guild Trip Quest-Fuehrung: Abkuerzungen (Nutzer 19.11.2026)
--   * Ruhestein benutzen, wenn das naechste Ziel nahe am Heimatort liegt und Laufen deutlich laenger dauert
--   * Ruhestein neu setzen, wenn man an einem Gastwirt vorbeikommt, der naeher an den naechsten Quests liegt
--   * als Geist bis Stufe 10: beim Geistheiler wiederbeleben, wenn das schneller zum naechsten Ziel fuehrt
-- Nur Hinweise im Kasten – das Addon benutzt nichts selbst.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local H = {}
lev.Hearth = H

H.ITEM = 6948            -- Ruhestein
H.USE_SEC = 25           -- 10 s Zauber + Ladebildschirm
H.MIN_SAVE = 3           -- Ruhestein lohnt ab so vielen Minuten Ersparnis
H.WALK, H.MOUNT = 7, 11  -- Yards pro Sekunde (wie die Zeitangabe im Kasten)
H.GHOST = 7 * 1.25       -- Geister laufen etwas schneller
H.HEALER_SEC = 10
H.HEALER_MIN_SAVE = 1
H.HEALER_MAX_LEVEL = 10  -- bis hier keine Wiederbelebungskrankheit
H.INN_NEAR = 60          -- so nah am Gastwirt: Heimatort gilt als hier gebunden
H.PASS = 250             -- an diesem Gastwirt kommt man gerade vorbei
H.AHEAD = 8              -- die naechsten so vielen Schritte bestimmen die "Gegend"
H.BETTER = 600           -- neuer Gastwirt muss so viel naeher an der Gegend liegen
H.MAX_AREA = 1200        -- weiter weg: kein sinnvoller Heimatort fuer diese Gegend

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function Travel() local n = ONE.ns and ONE.ns.nav return n and n.Travel end
local function Dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

local function CharKey()
    local name, realm = Call(rawget(_G, "UnitFullName"), "player")
    name = name or Call(rawget(_G, "UnitName"), "player") or "?"
    return (realm and realm ~= "") and (name .. "-" .. realm) or name
end

-- ===== Heimatort =====
function H:Store()
    ONE.db.leveling = type(ONE.db.leveling) == "table" and ONE.db.leveling or {}
    local d = ONE.db.leveling
    d.home = type(d.home) == "table" and d.home or {}
    return d.home
end
function H:Home() return self:Store()[CharKey()] end

function H.Faction()
    local f = Call(rawget(_G, "UnitFactionGroup"), "player")
    return f == "Alliance" and 1 or f == "Horde" and 2 or 0
end
-- naechster nutzbarer Gastwirt zu einem Weltpunkt: inn, Entfernung
function H.NearestInn(c, x, y, faction)
    local best, bd
    for _, inn in ipairs(lev.INNS or {}) do
        if inn[2] == c and (faction == 0 or inn[5] % (faction * 2) >= faction) then
            local d = Dist(inn[3], inn[4], x, y)
            if not bd or d < bd then best, bd = inn, d end
        end
    end
    return best, bd
end
function H.InnName(inn)
    if not inn then return nil end
    local locale = Call(rawget(_G, "GetLocale"))
    return (locale == "deDE" and inn[7]) or inn[6]
end

-- Gebunden? Beim Binden (HEARTHSTONE_BOUND) steht man beim Gastwirt – den naechsten merken
function H:Bound()
    local tr = Travel()
    if not tr then return end
    local c, x, y = tr.PlayerWorld()
    if not c then return end
    local inn, d = self.NearestInn(c, x, y, self.Faction())
    local home = {c, x, y, place = Call(rawget(_G, "GetBindLocation"))}
    if inn and d <= self.INN_NEAR then home = {inn[2], inn[3], inn[4], inn = inn[1], place = home.place} end
    self:Store()[CharKey()] = home
    return home
end
-- Noch kein Heimatort gemerkt: steht man am Gastwirt und der Bindeort ist dieses Gebiet, gilt er
function H:Learn()
    if self:Home() then return end
    local bind = Call(rawget(_G, "GetBindLocation"))
    local sub = Call(rawget(_G, "GetSubZoneText"))
    local zone = Call(rawget(_G, "GetZoneText"))
    if not bind or bind == "" or (bind ~= sub and bind ~= zone) then return end
    local tr = Travel()
    if not tr then return end
    local c, x, y = tr.PlayerWorld()
    if not c then return end
    local inn, d = self.NearestInn(c, x, y, self.Faction())
    if inn and d <= self.PASS then
        self:Store()[CharKey()] = {inn[2], inn[3], inn[4], inn = inn[1], place = bind}
    end
end

-- Ruhestein bereit? true | Restsekunden | nil (keiner im Gepaeck)
function H.Ready()
    local count = Call(rawget(_G, "GetItemCount"), H.ITEM)
    if type(count) ~= "number" or count < 1 then return nil end
    local cd = rawget(_G, "C_Container") and C_Container.GetItemCooldown or rawget(_G, "GetItemCooldown")
    local start, duration = Call(cd, H.ITEM)
    if type(start) ~= "number" or type(duration) ~= "number" or start <= 0 or duration <= 0 then return true end
    local now = Call(rawget(_G, "GetTime")) or 0
    local left = start + duration - now
    return left <= 0 and true or left
end

-- Weltpunkt eines Schritts
function H.StepWorld(step)
    if not step then return nil end
    if step.world then return step.world[1], step.world[2], step.world[3] end
    local tr = Travel()
    if tr and step.mapID and step.x then return tr.World(step.mapID, step.x, step.y) end
end

local function Speed()
    local mounted = Call(rawget(_G, "IsMounted"))
    return mounted and H.MOUNT or H.WALK
end

-- ===== Ruhestein benutzen =====
-- Minuten Ersparnis (oder nil), Ortsname
function H:UseAdvice(step, pc, px, py, speed)
    local home = self:Home()
    if not (home and pc) then return nil end
    local sc, sx, sy = self.StepWorld(step)
    if not sc or home[1] ~= sc then return nil end
    local tr = Travel()
    local detour = tr and tr.DETOUR or 1.3
    local walk
    if pc == sc then walk = Dist(px, py, sx, sy) * detour / speed / 60
    elseif step.walk then walk = step.walk
    else walk = 15 end -- anderer Kontinent: Schiff/Zeppelin
    local hearth = self.USE_SEC / 60 + Dist(home[2], home[3], sx, sy) * detour / speed / 60
    local save = walk - hearth
    if save < self.MIN_SAVE then return nil end
    local inn = home.inn and self.InnByID(home.inn)
    return save, home.place or self.InnName(inn)
end
function H.InnByID(id)
    for _, inn in ipairs(lev.INNS or {}) do if inn[1] == id then return inn end end
end

-- ===== Ruhestein neu setzen =====
-- Mitte der naechsten Schritte auf dem Kontinent des Spielers
function H.Area(plan, pc)
    local n, sx, sy = 0, 0, 0
    for i, st in ipairs(plan and plan.steps or {}) do
        if i > H.AHEAD then break end
        local c, x, y = H.StepWorld(st)
        if c and c == pc then n, sx, sy = n + 1, sx + x, sy + y end
    end
    if n < 3 then return nil end
    return sx / n, sy / n
end
-- Gastwirt in der Naehe, der deutlich naeher an den naechsten Quests liegt als der Heimatort: inn
function H:BindAdvice(plan, pc, px, py)
    if not pc then return nil end
    local ax, ay = self.Area(plan, pc)
    if not ax then return nil end
    local faction = self.Faction()
    local here, dHere = self.NearestInn(pc, px, py, faction)
    if not here or dHere > self.PASS then return nil end
    local toArea = Dist(here[3], here[4], ax, ay)
    if toArea > self.MAX_AREA then return nil end
    local home = self:Home()
    if home and home.inn == here[1] then return nil end
    if home and home[1] == pc and Dist(home[2], home[3], ax, ay) < toArea + self.BETTER then return nil end
    return here
end

-- ===== Geistheiler =====
function H:HealerAdvice(step, pc, px, py, corpse, level)
    if not (pc and corpse and level and level <= self.HEALER_MAX_LEVEL) then return nil end
    local sc, sx, sy = self.StepWorld(step)
    if not sc or sc ~= pc or corpse[1] ~= pc then return nil end
    local tr = Travel()
    local detour = tr and tr.DETOUR or 1.3
    local viaCorpse = Dist(px, py, corpse[2], corpse[3]) * detour / self.GHOST / 60
        + Dist(corpse[2], corpse[3], sx, sy) * detour / self.WALK / 60
    local viaHealer = self.HEALER_SEC / 60 + Dist(px, py, sx, sy) * detour / self.WALK / 60
    local save = viaCorpse - viaHealer
    if save < self.HEALER_MIN_SAVE then return nil end
    return save
end

-- ===== Zeilen fuer den Kasten =====
function H:Lines(plan)
    local step = plan and plan.steps and plan.steps[1]
    local tr = Travel()
    if not (step and tr) then return {} end
    local pc, px, py = tr.PlayerWorld()
    if not pc then return {} end
    local out = {}
    local ghost = Call(rawget(_G, "UnitIsGhost"), "player")
    if ghost then
        local nav = ONE.ns and ONE.ns.nav
        local W = nav and nav.Waypoints
        local mapID, x, y
        if W and W.CorpsePosition then mapID, x, y = W:CorpsePosition() end
        local cc, cx, cy
        if mapID then cc, cx, cy = tr.World(mapID, x, y) end
        local save = cc and self:HealerAdvice(step, pc, px, py, {cc, cx, cy}, Call(rawget(_G, "UnitLevel"), "player"))
        if save then
            out[#out + 1] = T("Beim Geistheiler wiederbeleben spart ca. %d min (bis Stufe 10 keine Krankheit, Rüstung verliert etwas Haltbarkeit)",
                math.max(1, math.floor(save + .5)))
        end
        return out
    end
    local ready = self.Ready()
    -- Ruhestein/Gastwirt steht schon als Schritt im Plan: kein doppelter Hinweis
    local planned = false
    for i = 1, math.min(#plan.steps, self.AHEAD) do
        local st = plan.steps[i]
        if st.kind == "bind" or (st.via and st.via.kind == "hearth") then planned = true break end
    end
    if planned then return out end
    local save, place = self:UseAdvice(step, pc, px, py, Speed())
    if save and ready == true then
        out[#out + 1] = place and T("Ruhestein nach %s benutzen – spart ca. %d min", place, math.floor(save + .5))
            or T("Ruhestein benutzen – spart ca. %d min", math.floor(save + .5))
    elseif save and type(ready) == "number" and ready / 60 < save then
        out[#out + 1] = T("Ruhestein in %d min bereit – lohnt sich dann", math.max(1, math.ceil(ready / 60)))
    end
    local inn = self:BindAdvice(plan, pc, px, py)
    if inn then
        out[#out + 1] = T("Ruhestein hier setzen (%s) – näher an deinen nächsten Quests", self.InnName(inn))
    end
    return out
end

function H:Initialize()
    local f = CreateFrame("Frame")
    for _, e in ipairs({"HEARTHSTONE_BOUND", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_COOLDOWN"}) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, event)
        if event == "HEARTHSTONE_BOUND" then H:Bound()
        elseif event ~= "BAG_UPDATE_COOLDOWN" and event ~= "PLAYER_DEAD" then pcall(H.Learn, H) end
        local G, Tr = lev.Guide, lev.Tracker
        if G and G.plan and Tr and Tr.Update then pcall(Tr.Update, Tr, G.plan) end
    end)
    self.frame = f
end
