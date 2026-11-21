local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end return text end

-- Zauberdaten fuer den Klassen-Ratgeber an den Guild-Trip-Entwickler der
-- eigenen Gilde schicken. NUR mit Haekchen (je Charakter, bleibt gesetzt).
--  * Der Entwickler (Addon ONE_Dev) meldet sich im Gildenkanal mit "HELLO".
--  * Ist das Haekchen gesetzt und haben sich die Daten seit dem letzten
--    Versand geaendert, gehen sie per Fluester-Addonnachricht an ihn.
--  * Inhalt: Klasse, Stufe, Zauber (Rang, Kosten, Zeiten, Beschreibung) und
--    Talente. KEIN Charaktername, keine Position, nichts anderes.
local Share = {prefix = "ONECLS1", chunk = 220, interval = .3, devTimeout = 900}
classes.Share = Share

local Path = classes.Player.Path

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function Clock() return (type(GetTime) == "function" and GetTime()) or os.time() end

local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    local s = ONE.db.classGuide
    s.share = type(s.share) == "table" and s.share or {}
    s.sentHash = type(s.sentHash) == "table" and s.sentHash or {}
    return s
end

-- Zustimmung gilt je Charakter (wie die Standort-Freigabe).
function Share:CharKey()
    local name = Call(UnitName, "player") or "?"
    -- Forever liefert den Realm direkt nach dem Einloggen manchmal leer: dann aus GetRealmName
    local realm = Call(GetNormalizedRealmName)
    if not realm or realm == "" then realm = (Call(GetRealmName) or ""):gsub("[%s%-]", "") end
    return name .. "-" .. realm, name
end
function Share:IsEnabled()
    local share = Store().share
    local key, name = self:CharKey()
    if share[key] == true then return true end
    -- Realm (noch) unbekannt oder frueher leer gespeichert: jede Zustimmung dieses Namens zaehlt
    if key:sub(-1) == "-" or share[name .. "-"] == true then
        for k, v in pairs(share) do
            if v == true and k:sub(1, #name + 1) == name .. "-" then return true end
        end
    end
    return false
end
function Share:SetEnabled(on)
    local share = Store().share
    local key, name = self:CharKey()
    if on then
        share[key] = true
        if key ~= name .. "-" then share[name .. "-"] = nil end
        self:TrySend()
    else
        -- alle Eintraege dieses Namens weg, sonst schaltet ein alter Eintrag es wieder an
        for k in pairs(share) do if k:sub(1, #name + 1) == name .. "-" then share[k] = nil end end
    end
end

-- ===== kleines Verpackungsformat (nur Zahlen, Texte, Wahrheitswerte, Tabellen) =====
local function Escape(s)
    return (s:gsub("[%%{}=;|\n\r]", function(c) return string.format("%%%02X", c:byte()) end))
end
local function Unescape(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

function Share.Serialize(v)
    local t = type(v)
    if t == "number" then return "n" .. tostring(v) end
    if t == "string" then return "s" .. Escape(v) end
    if t == "boolean" then return v and "b1" or "b0" end
    if t == "table" then
        local parts = {}
        for k, x in pairs(v) do
            local tk, tx = type(k), type(x)
            if (tk == "string" or tk == "number") and (tx == "string" or tx == "number" or tx == "boolean" or tx == "table") then
                parts[#parts + 1] = Share.Serialize(k) .. "=" .. Share.Serialize(x)
            end
        end
        table.sort(parts) -- gleiche Daten = gleicher Text (fuer den Vergleich)
        return "{" .. table.concat(parts, ";") .. "}"
    end
    return "b0"
end

function Share.Deserialize(text)
    local pos = 1
    local function Value()
        local tag = text:sub(pos, pos)
        if tag == "{" then
            pos = pos + 1
            local tbl = {}
            if text:sub(pos, pos) == "}" then pos = pos + 1 return tbl end
            while true do
                local k = Value()
                if text:sub(pos, pos) ~= "=" then error("= erwartet") end
                pos = pos + 1
                tbl[k] = Value()
                local sep = text:sub(pos, pos)
                pos = pos + 1
                if sep == "}" then return tbl end
                if sep ~= ";" then error("; erwartet") end
            end
        end
        local stop = pos + 1
        while stop <= #text and not text:sub(stop, stop):find("[=;}]") do stop = stop + 1 end
        local raw = text:sub(pos + 1, stop - 1)
        pos = stop
        if tag == "n" then return tonumber(raw) end
        if tag == "s" then return Unescape(raw) end
        if tag == "b" then return raw == "1" end
        error("unbekanntes Zeichen " .. tag)
    end
    local ok, result = pcall(Value)
    if ok then return result end
end

local function Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end
Share.Hash = Hash

-- ===== Daten sammeln (ohne Namen) =====
function Share:Collect()
    local _, classFile = Call(UnitClass, "player")
    local data = {class = classFile, level = Call(UnitLevel, "player"), locale = Call(GetLocale),
        build = (Call(GetBuildInfo)), addon = ONE.version, spells = {}, talents = {}}
    local book, bank = Path("C_SpellBook"), Path("Enum.SpellBookSpellBank.Player")
    local function AddSpell(id, rank, tab)
        if type(id) ~= "number" then return end
        local name = classes.Player.SpellInfo(id)
        local info = Call(Path("C_Spell.GetSpellInfo"), id)
        local cost = Call(Path("C_Spell.GetSpellPowerCost"), id) or Call(GetSpellPowerCost, id)
        data.spells[#data.spells + 1] = {id = id, name = name, rank = rank, tab = tab,
            cast = type(info) == "table" and info.castTime or nil,
            range = type(info) == "table" and info.maxRange or nil,
            cost = type(cost) == "table" and cost[1] and cost[1].cost or nil,
            cd = Call(GetSpellBaseCooldown, id),
            desc = Call(Path("C_Spell.GetSpellDescription"), id) or Call(GetSpellDescription, id)}
    end
    if book and type(book.GetNumSpellBookSkillLines) == "function" and bank ~= nil then
        for t = 1, (Call(book.GetNumSpellBookSkillLines) or 0) do
            local line = Call(book.GetSpellBookSkillLineInfo, t)
            if type(line) == "table" then
                local offset = line.itemIndexOffset or 0
                for i = offset + 1, offset + (line.numSpellBookItems or 0) do
                    local item = Call(book.GetSpellBookItemInfo, i, bank)
                    if type(item) == "table" then AddSpell(item.spellID, item.subName, t) end
                end
            end
        end
    end
    for spellID, t in pairs(classes.Player:Talents()) do
        data.talents[#data.talents + 1] = {id = spellID, name = t.name, ranks = t.ranks, max = t.max, x = t.x, y = t.y,
            desc = Call(Path("C_Spell.GetSpellDescription"), spellID)}
    end
    table.sort(data.talents, function(a, b) return a.id < b.id end)
    data.finds = self:CollectFinds(classFile)
    return data
end

-- Funde fuers Startpaket (seit 0.6.6): Klassenlehrer-Listen, Haendler, Questgeber, Lehrer,
-- Dungeon-Eingaenge – nur NPC, Ort, Angebot, Stufen; KEINE Spielernamen (Finder-Namen
-- werden entfernt). Je Liste hoechstens die neuesten Eintraege, damit der Versand klein bleibt.
Share.maxFinds = 300
local function Newest(map, max, copy)
    local list = {}
    for key, e in pairs(type(map) == "table" and map or {}) do
        if type(e) == "table" then list[#list + 1] = {key, e} end
    end
    table.sort(list, function(a, b) return (a[2].seen or 0) > (b[2].seen or 0) end)
    local out = {}
    for i = 1, math.min(#list, max) do out[list[i][1]] = copy(list[i][2]) end
    return out
end
function Share:CollectFinds(classFile)
    local db = ONE.db or {}
    local nav = type(db.nav) == "table" and db.nav or {}
    local finds = {nav = {}, crafting = {}, dungeons = {}, classGuide = {}}
    local cs = type(db.classGuide) == "table" and type(db.classGuide.classSpells) == "table" and db.classGuide.classSpells
    if cs then finds.classGuide.classSpells = cs end
    -- Beute-Funde (Gegner-/NPC-Namen, keine Spielernamen)
    local loot = type(db.classGuide) == "table" and db.classGuide.loot
    finds.classGuide.loot = Newest(loot, self.maxFinds, function(e)
        local sources = {}
        for k, s in pairs(e.sources or {}) do
            sources[k] = {name = s.name, kind = s.kind, instance = s.instance, mapID = s.mapID, x = s.x, y = s.y, count = s.count}
        end
        return {q = e.q, slot = e.slot, minLevel = e.minLevel, ilvl = e.ilvl, sources = sources}
    end)
    finds.nav.merchants = Newest(nav.merchants, self.maxFinds, function(m)
        return {name = m.name, mapID = m.mapID, x = m.x, y = m.y, faction = m.faction, cats = m.cats}
    end)
    finds.nav.givers = Newest(nav.givers, self.maxFinds, function(g)
        local quests = {}
        for qk, q in pairs(g.quests or {}) do quests[qk] = {title = q.title, level = q.level} end
        return {name = g.name, mapID = g.mapID, x = g.x, y = g.y, faction = g.faction, quests = quests}
    end)
    local crafting = type(db.crafting) == "table" and db.crafting or {}
    finds.crafting.trainers = Newest(crafting.trainers, self.maxFinds, function(e)
        return {kind = e.kind, what = e.what, map = e.map, x = e.x, y = e.y, area = e.area, faction = e.faction,
            title = e.title, teaches = e.teaches}
    end)
    local dungeons = type(db.dungeons) == "table" and db.dungeons or {}
    finds.dungeons.entrances = {}
    for key, e in pairs(type(dungeons.entrances) == "table" and dungeons.entrances or {}) do
        if e.source == "self" or e.source == "guild" or e.source == "game" then
            finds.dungeons.entrances[key] = {mapID = e.mapID, x = e.x, y = e.y, source = e.source}
        end
    end
    return finds
end

-- ===== Versand =====
function Share:DevOnline()
    return self.dev and (Clock() - (self.devSeen or 0)) < self.devTimeout and self.dev or nil
end

local function SendAddon(prefix, msg, channel, target)
    local fn = Path("C_ChatInfo.SendAddonMessage")
    if type(fn) ~= "function" then return false end
    return pcall(fn, prefix, msg, channel, target)
end

function Share:TrySend()
    local dev = self:DevOnline()
    if not dev or not self:IsEnabled() or self.sending then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return false end
    local text = Share.Serialize(self:Collect())
    local hash = Hash(text)
    local store = Store()
    local key = self:CharKey()
    if store.sentHash[key] == hash then return false end -- nichts Neues
    local parts = {}
    for i = 1, #text, self.chunk do parts[#parts + 1] = text:sub(i, i + self.chunk - 1) end
    self.sending = true
    SendAddon(self.prefix, ("H:%s:%d"):format(hash, #parts), "WHISPER", dev)
    local i = 0
    local function Step()
        i = i + 1
        if i > #parts then
            self.sending = false
            store.sentHash[key] = hash
            ONE:Print(T("Zauberdaten an den Guild-Trip-Entwickler geschickt. Danke!"))
            return
        end
        SendAddon(self.prefix, ("C:%s:%d:%s"):format(hash, i, parts[i]), "WHISPER", dev)
        local timer = Path("C_Timer.After")
        if type(timer) == "function" then timer(self.interval, Step) else Step() end
    end
    Step()
    return true
end

-- Nachrichten: "HELLO" vom Entwickler im Gildenkanal.
function Share:Receive(prefix, message, channel, sender)
    if prefix ~= self.prefix or type(message) ~= "string" or type(sender) ~= "string" then return end
    if message == "HELLO" and channel == "GUILD" then
        self.dev, self.devSeen = sender, Clock()
        if classes.Page and classes.Page.RefreshShare then pcall(classes.Page.RefreshShare, classes.Page) end
        self:TrySend()
    end
end

function Share:Initialize()
    local register = Path("C_ChatInfo.RegisterAddonMessagePrefix")
    if type(register) == "function" then pcall(register, self.prefix) end
    local frame = CreateFrame("Frame")
    pcall(frame.RegisterEvent, frame, "CHAT_MSG_ADDON")
    pcall(frame.RegisterEvent, frame, "PLAYER_LEVEL_UP")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then self:Receive(...)
        else
            local timer = Path("C_Timer.After")
            if type(timer) == "function" then timer(10, function() self:TrySend() end) end
        end
    end)
    self.frame = frame
end
