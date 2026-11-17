local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Neue Raenge automatisch auf die Leisten.
-- Forever tauscht Raenge auf den Aktionsleisten nicht selbst aus. Lernt man
-- einen neuen Rang, ersetzt Guild Trip auf ALLEN Leisten den bisher hoechsten
-- Rang durch den neuen.
--  * Makros werden nie angefasst (wer ein Makro hat, hat einen Grund).
--  * Absichtlich niedrige Raenge (z. B. "Heilen Rang 1" zum Manasparen)
--    bleiben, getauscht wird nur der bisher hoechste Rang.
--  * Im Kampf duerfen Addons die Leisten nicht aendern: dann nach dem Kampf.
-- Abschaltbar ueber das Haekchen auf der Klasse-Seite.
local Ranks = {pending = {}, names = {}, learned = {}}
classes.Ranks = Ranks
Ranks.maxSlot = 120

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    return ONE.db.classGuide
end

function Ranks:Enabled() return Store().autoRank ~= false end
function Ranks:SetEnabled(on) Store().autoRank = on and true or false end

-- Name -> hoechster bekannter Rang
function Ranks:Snapshot()
    local snap, best = {}, {}
    local alias = classes.Data:AliasNames()
    for name, e in pairs(classes.Player:KnownSpells()) do
        -- Gleicher Zauber mit anderem Namen je Rang zaehlt zusammen
        local key = alias[name] or name
        if not best[key] or (e.best or 0) > best[key] then snap[key], best[key], self.names[key] = e.id, e.best or 0, name end
    end
    return snap
end

-- Aufruf bei SPELLS_CHANGED / LEARNED_SPELL_IN_TAB.
function Ranks:OnSpellsChanged()
    local snap = self:Snapshot()
    if not self.last or not next(self.last) then self.last = snap return 0 end
    local learned = {}
    for name, id in pairs(snap) do
        local old = self.last[name]
        if old and old ~= id then self.pending[old] = {new = id, name = name} end
        -- ganz neu gelernt (nicht nur ein neuer Rang)
        if not old and name:sub(1, 1) ~= "#" then learned[#learned + 1] = name end
    end
    -- Leeres Zauberbuch (z. B. Ladebildschirm) loescht das Wissen nicht.
    if next(snap) then self.last = snap end
    local count = self:Run()
    -- Neue, eingeplante Zauber auf ihren freien Platz legen (Bars:AutoAdd)
    if #learned > 0 and classes.Bars and classes.Bars.AutoAdd then
        for _, name in ipairs(learned) do self.learned[name] = true end
        count = count + classes.Bars:AutoAdd(self.learned)
    end
    return count
end

function Ranks:OnCombatEnded()
    local count = 0
    if self.waiting then count = self:Run() end
    if next(self.learned) and classes.Bars and classes.Bars.AutoAdd then
        count = count + classes.Bars:AutoAdd(self.learned)
    end
    return count
end

local function PickupSpellID(id)
    local new = classes.Player.Path("C_Spell.PickupSpell")
    if type(new) == "function" then return pcall(new, id) end
    return pcall(PickupSpell, id)
end

function Ranks:Run()
    if not next(self.pending) then return 0 end
    if not self:Enabled() then self.pending = {} return 0 end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then self.waiting = true return 0 end
    self.waiting = false
    local count, perName = 0, {}
    for slot = 1, self.maxSlot do
        local kind, id = Call(GetActionInfo, slot)
        local change = kind == "spell" and self.pending[id]
        if change then
            Call(ClearCursor)
            -- falls inzwischen noch ein Rang dazukam: immer den aktuell hoechsten nehmen
            local newest = self.last and self.last[change.name] or change.new
            if PickupSpellID(newest) then
                Call(PlaceAction, slot)
                count = count + 1
                local shown = self.names[change.name] or change.name
                perName[shown] = (perName[shown] or 0) + 1
            end
            Call(ClearCursor) -- alter Rang faellt vom Mauszeiger
        end
    end
    self.pending = {}
    for name, n in pairs(perName) do
        ONE:Print(n == 1 and T("%s: neuer Rang auf 1 Leistenplatz.", name) or T("%s: neuer Rang auf %d Leistenplätzen.", name, n))
    end
    return count
end
