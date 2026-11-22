-- Guild Trip Klasse: Waffenkunde – welche Waffen deine Klasse lernen kann,
-- ob du sie schon beherrschst und welcher Waffenmeister sie lehrt (mit Navi).
-- Quellen:
--  * Klasse -> Waffen: Classic-Regeln (allgemeines Spielwissen)
--  * Beherrscht: Waffenfertigkeiten als Zauber – Forever hat eigene Nummern
--    (Auslese 15.11.2026, ab 1302900), dazu die alten Classic-Nummern
--  * Lehrer: was ein Waffenmeister wirklich anbietet, merkt sich ONE_Crafting beim
--    Ansprechen (Trainers:CaptureNow -> weapons); sonst Classic-Stand "unbestaetigt"
local _, classes = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Weapons = {}
classes.Weapons = Weapons
ONE.Weapons = Weapons -- auch fuer die Lehrer-Seite (Unterkategorie Waffenart)

-- key, deutscher Name, Zauber-Nummern (Classic, Forever); free = braucht keinen Lehrer
Weapons.types = {
    {key = "axe1", name = "Einhandäxte", ids = {196, 1302994}},
    {key = "axe2", name = "Zweihandäxte", ids = {197, 1303007}},
    {key = "mace1", name = "Einhandstreitkolben", ids = {198, 1302997}},
    {key = "mace2", name = "Zweihandstreitkolben", ids = {199, 1303001}},
    {key = "sword1", name = "Einhandschwerter", ids = {201, 1296663}},
    {key = "sword2", name = "Zweihandschwerter", ids = {202, 1302939}},
    {key = "polearm", name = "Stangenwaffen", ids = {200, 1303013}},
    {key = "staff", name = "Stäbe", ids = {227, 1302999}},
    {key = "dagger", name = "Dolche", ids = {1180, 1303008}},
    {key = "fist", name = "Faustwaffen", ids = {15590, 1303015}},
    {key = "bow", name = "Bögen", ids = {264, 1302995}},
    {key = "crossbow", name = "Armbrüste", ids = {5011, 1303010}},
    {key = "gun", name = "Schusswaffen", ids = {266, 1302996}},
    {key = "thrown", name = "Wurfwaffen", ids = {2567, 1303009}},
    {key = "wand", name = "Zauberstäbe", ids = {5009, 1303011}, free = true},
}
Weapons.byKey = {}
for _, w in ipairs(Weapons.types) do Weapons.byKey[w.key] = w end

-- Classic: was jede Klasse lernen kann (Reihenfolge = Anzeige)
Weapons.byClass = {
    WARRIOR = {"axe1", "axe2", "mace1", "mace2", "sword1", "sword2", "polearm", "staff", "dagger", "fist", "bow", "crossbow", "gun", "thrown"},
    PALADIN = {"axe1", "axe2", "mace1", "mace2", "sword1", "sword2", "polearm"},
    HUNTER = {"axe1", "axe2", "sword1", "sword2", "polearm", "staff", "dagger", "fist", "bow", "crossbow", "gun", "thrown"},
    ROGUE = {"dagger", "sword1", "mace1", "fist", "bow", "crossbow", "gun", "thrown"},
    PRIEST = {"mace1", "staff", "dagger", "wand"},
    SHAMAN = {"axe1", "axe2", "mace1", "mace2", "staff", "dagger", "fist"},
    MAGE = {"sword1", "staff", "dagger", "wand"},
    WARLOCK = {"sword1", "staff", "dagger", "wand"},
    DRUID = {"mace1", "mace2", "staff", "dagger", "fist"},
}

-- Classic-Stand: welcher Waffenmeister was lehrt (in Forever unbestaetigt)
Weapons.seedTeaches = {
    ["Sayoc"] = {"bow", "dagger", "fist", "axe1", "axe2"},
    ["Hanashi"] = {"bow", "staff", "thrown", "axe1", "axe2"},
    ["Ansekhwa"] = {"gun", "mace1", "mace2", "staff"},
    ["Archibald"] = {"crossbow", "dagger", "sword1", "sword2", "polearm"},
    ["Woo Ping"] = {"crossbow", "dagger", "sword1", "sword2", "polearm", "staff"},
    ["Bixi Wobblebonk"] = {"crossbow", "dagger", "thrown"},
    ["Buliwyf Stonehand"] = {"fist", "gun", "axe1", "axe2", "mace1", "mace2"},
    ["Ilyenia Moonfire"] = {"bow", "dagger", "fist", "staff", "thrown"},
}

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

-- Beherrschst du die Waffe? true / false; nil, wenn das Spiel es nicht verraet
function Weapons.Known(w)
    local api = IsPlayerSpell or IsSpellKnown
    if type(api) ~= "function" then return nil end
    for _, id in ipairs(w.ids) do
        if Call(IsPlayerSpell, id) or Call(IsSpellKnown, id) then return true end
    end
    return false
end

-- Waffenmeister aus dem Lehrer-Verzeichnis (eigene/Gilden-Funde, Startpaket, Grundliste)
function Weapons:Trainers()
    local crafting = ONE.modules and ONE.modules.crafting
    if not (crafting and crafting.AllTrainers) then return {} end
    local ok, all = pcall(crafting.AllTrainers)
    local out = {}
    for _, e in ipairs(ok and type(all) == "table" and all or {}) do
        if e.kind == "weapon" then out[#out + 1] = e end
    end
    return out
end

-- Lehrt dieser Waffenmeister die Waffe? true sicher (im Spiel gesehen), nil laut Classic, false nein
function Weapons.Teaches(trainer, key)
    if type(trainer.weapons) == "table" then return trainer.weapons[key] == true end
    for _, k in ipairs(Weapons.seedTeaches[trainer.npc] or {}) do if k == key then return nil end end
    return false
end

-- Naechster Lehrer fuer eine Waffe: sichere vor Classic-Angaben, dann nach Entfernung
function Weapons:BestTrainer(key, trainers)
    local navi = ONE.modules and ONE.modules.nav
    local best, bestScore
    for _, e in ipairs(trainers or self:Trainers()) do
        local t = Weapons.Teaches(e, key)
        if t ~= false and e.map and e.x and e.y then
            local dist = navi and navi.DistanceTo and navi:DistanceTo(e.map, e.x, e.y)
            local score = (t and 0 or 100000) + (dist or 50000)
            if not bestScore or score < bestScore then best, bestScore = e, score end
        end
    end
    return best, best and Weapons.Teaches(best, key) == true
end

-- Zeilen fuer die Ansicht: je Waffe Name, Stand, Lehrer
function Weapons:Rows(classFile)
    local trainers = self:Trainers()
    local rows = {}
    for _, key in ipairs(self.byClass[classFile or ""] or {}) do
        local w = self.byKey[key]
        local trainer, sure = nil, false
        if not w.free then trainer, sure = self:BestTrainer(key, trainers) end
        rows[#rows + 1] = {key = key, weapon = w, known = Weapons.Known(w), trainer = trainer, sure = sure}
    end
    return rows
end

function Weapons.StateText(row)
    if row.known then return "|cff40e040" .. T("kannst du") .. "|r" end
    if row.weapon.free then return T("von Anfang an") end
    if row.known == false then return "|cffffd100" .. T("beim Waffenmeister lernen") .. "|r" end
    return "|cff9d9d9d" .. T("unbekannt") .. "|r"
end

function Weapons.TrainerText(row)
    if row.weapon.free then return T("kein Lehrer nötig") end
    local e = row.trainer
    if not e then return "|cff9d9d9d" .. T("kein Lehrer bekannt") .. "|r" end
    -- kurz: "Ansekhwa · Donnerfels" (nur die Stadt, Viertel steht im Tooltip); * = laut Classic
    local city = type(e.area) == "string" and e.area:match("^[^,]+") or nil
    local text = e.npc .. (city and ("  ·  " .. T(city)) or "")
    if not row.sure then text = text .. " |cff9d9d9d*|r" end
    return text
end

-- Navi zum Lehrer einer Zeile
function Weapons.Navi(row)
    local e, navi = row and row.trainer, ONE.modules and ONE.modules.nav
    if not (e and e.map and navi and navi.PointTo) then return false end
    return navi:PointTo(e.npc, e.map, e.x, e.y, {service = true}) and true or false
end
