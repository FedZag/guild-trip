-- Guild Trip Dungeons: wer steht in welchem Dungeon? (Nutzer 19.11.2026, "Weg 1: selbst sammeln")
-- Fuer die neuen Forever-Dungeons fehlen offene Boss- und Beutelisten. Darum merkt sich Guild Trip in jedem
-- Dungeon still, welche Gegner fallen (Gegner-Nummer aus der GUID + Name in deiner Sprache) und welche davon
-- Bosse sind (ENCOUNTER_END). Mit den Gegner-Nummern holt scripts/import_dungeon_finds.py spaeter die volle
-- Beute-Tabelle aus forever-db (GPL-3). Gespeichert kontoweit:
--   ONE.db.dungeons.roster[schluessel] = {npcs = {[npcID] = {name, n, boss}}, bosses = {[encounterID] = name}, runs}
-- Keine Spielernamen, nichts wird gesendet. /trip dungeondaten zeigt den Stand.
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Roster = {MAX_NPCS = 120}
dungeons.Roster = Roster

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function G(name) return rawget(_G, name) end
local function Now() return Call(G("GetTime")) or 0 end

function Roster:Store()
    if not ONE.db then return {} end
    ONE.db.dungeons = type(ONE.db.dungeons) == "table" and ONE.db.dungeons or {}
    local s = type(ONE.db.dungeons.roster) == "table" and ONE.db.dungeons.roster or {}
    ONE.db.dungeons.roster = s
    return s
end

-- aktueller Dungeon (Schluessel aus dem Dungeon-Rueckblick)
function Roster:Current()
    local run = dungeons.Recap and dungeons.Recap.run
    return run and run.key or nil
end

function Roster:Entry(key)
    local s = self:Store()
    local e = s[key]
    if type(e) ~= "table" then e = {npcs = {}, bosses = {}, runs = 0} s[key] = e end
    e.npcs, e.bosses = e.npcs or {}, e.bosses or {}
    return e
end

-- Gegner-Nummer aus der GUID ("Creature-0-…-NPCID-…"); Spieler/Begleiter nicht
function Roster.NpcID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end

local function Plain(v) local f = G("issecretvalue") return not (type(f) == "function" and f(v)) end

-- Gegner gesehen (Einheit im Dungeon: Namensplakette, Ziel, Mauszeiger, Boss-Leiste)
function Roster:See(unit, boss)
    local key = self:Current()
    if not key then return nil end
    local guid = Call(G("UnitGUID"), unit)
    local name = Call(G("UnitName"), unit)
    if not (guid and Plain(guid) and Plain(name)) then return nil end
    local id = self.NpcID(guid)
    if not id then return nil end
    local e = self:Entry(key)
    local n = e.npcs[id]
    if not n then
        local count = 0
        for _ in pairs(e.npcs) do count = count + 1 end
        if count >= self.MAX_NPCS then return nil end
        n = {n = 0}
        e.npcs[id] = n
    end
    if type(name) == "string" and name ~= "" then n.name = name end
    n.n = n.n + 1
    if boss then n.boss = true end
    return n
end
-- alt (Tests): ueber GUID + Name direkt
function Roster:OnKill(guid, name)
    local key, id = self:Current(), self.NpcID(guid)
    if not (key and id) then return nil end
    local e = self:Entry(key)
    local n = e.npcs[id] or {n = 0}
    e.npcs[id] = n
    if type(name) == "string" and name ~= "" then n.name = name end
    n.n = n.n + 1
    return n
end

-- Boss besiegt: Begegnung merken
function Roster:OnEncounter(encounterID, name, success)
    local key = self:Current()
    if not (key and success) then return end
    local e = self:Entry(key)
    if encounterID and Plain(encounterID) then e.bosses[encounterID] = (Plain(name) and name) or e.bosses[encounterID] or true end
end

-- Zusammenfassung: {{key, npcs, bosses}}
function Roster:Summary()
    local out = {}
    for key, e in pairs(self:Store()) do
        local n, b = 0, 0
        for _, v in pairs(e.npcs or {}) do n = n + 1 if v.boss then b = b + 1 end end
        out[#out + 1] = {key = key, npcs = n, bosses = b}
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

function Roster:Initialize()
    if ONE.RegisterSlash then
        ONE:RegisterSlash("dungeondaten", function()
            local list = Roster:Summary()
            if #list == 0 then ONE:Print(T("Noch keine Dungeon-Daten gesammelt.")) return end
            for _, d in ipairs(list) do
                local c
                for _, x in ipairs(dungeons.Catalog or {}) do if x.key == d.key then c = x end end
                ONE:Print(T("%s: %d Gegner, davon %d Bosse", c and T(c.name) or d.key, d.npcs, d.bosses))
            end
        end, T("Gesammelte Dungeon-Gegner und Bosse anzeigen"))
    end
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"ENCOUNTER_END", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT"}) do
        pcall(f.RegisterEvent, f, ev)
    end
    f:SetScript("OnEvent", function(_, event, a, b, _, _, e)
        if event == "ENCOUNTER_END" then Roster:OnEncounter(a, b, e == 1 or e == true) return end
        if not Roster:Current() then return end
        if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
            for i = 1, 5 do if Call(G("UnitExists"), "boss" .. i) then Roster:See("boss" .. i, true) end end
        elseif event == "NAME_PLATE_UNIT_ADDED" then Roster:See(a)
        elseif event == "PLAYER_TARGET_CHANGED" then Roster:See("target")
        else Roster:See("mouseover") end
    end)
    self.events = f
end
