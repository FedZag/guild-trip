local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Buffen in der Naehe (0.7.0): kleines Fenster mit allen Spielern in Reichweite,
-- denen einer DEINER Buffs fehlt – Gruppe, Gilde, Freunde und Fremde.
--  * Woher die Spieler kommen: Gruppe/Schlachtzug, dein Ziel, freundliche
--    Namensplaketten und wen du kurz mit der Maus beruehrt hast.
--  * Automatisch erkennen (Standard): Addons sehen andere Spieler NUR ueber Namensplaketten
--    (die blauen Namen ueber den Koepfen sind fuer Addons unsichtbar). Guild Trip schaltet
--    deshalb die freundlichen Namensplaketten ein, macht sie aber unsichtbar und nicht
--    anklickbar – so landet jeder, der an dir vorbeilaeuft, in der Liste.
--    0.7.1: Umschalt+V (oder das Menue) heisst nur noch sichtbar/unsichtbar – die Plaketten bleiben
--    technisch an, die Liste verliert nie die Spieler. Laeuft ein Namensplaketten-Addon (Plater, Kui …),
--    fasst Guild Trip die Plaketten gar nicht an. Die Reichweite bleibt, wie du sie hast.
--    Abschalten und Ausloggen stellen deine Einstellung wieder her.
--  * Klick auf eine Zeile wirkt den Buff: Linksklick = erster Buff,
--    Rechtsklick = zweiter, Umschalt+Linksklick = dritter. Blizzard-Knopf
--    (SecureActionButtonTemplate) – erlaubt, weil du selbst klickst.
--  * Der Rang passt zur Stufe des Ziels (sonst "Ziel ist zu niedrig").
--  * Ein Klick reicht: sobald der Buff WIRKLICH sitzt (Zauber erfolgreich),
--    verschwindet der Spieler aus der Liste (30 Minuten; verliert er den
--    Buff vorher, z. B. durch Tod, kommt er wieder). Klappt der Zauber nicht
--    (Reichweite, Sicht), bleibt er drin.
--  * Nur ausserhalb des Kampfes; im Kampf blendet Blizzards Zustandssteuerung
--    das Fenster sicher aus. Alt + Ziehen verschiebt es.
local Nearby = {rows = 8, rowH = 22, width = 230, keep = 30, soon = 60, doneFor = 1800, grace = 10}
classes.Nearby = Nearby

-- Buffs, die man anderen geben kann. ranks = {Zauber, benoetigte Stufe}
-- (Ziel darf hoechstens 10 Stufen darunter sein). also = gleichwertige Buffs
-- (Gebete, Grosse Segen). group = ein Ziel traegt nur einen davon (Segen).
Nearby.offers = {
    PRIEST = {
        {ranks = {{1243, 1}, {1244, 12}, {1245, 24}, {2791, 36}, {10937, 48}, {10938, 60}}, also = {21562, 21564}},
        {ranks = {{14752, 30}, {14818, 40}, {14819, 50}, {27841, 60}}, also = {27681}},
        {ranks = {{976, 30}, {10957, 42}, {10958, 56}}, also = {27683}},
    },
    MAGE = {
        {ranks = {{1459, 1}, {1460, 14}, {1461, 28}, {10156, 42}, {10157, 56}}, also = {23028}},
    },
    DRUID = {
        {ranks = {{1126, 1}, {5232, 10}, {6756, 20}, {5234, 30}, {8907, 40}, {9884, 50}, {9885, 60}}, also = {21849, 21850}},
        {ranks = {{467, 6}, {782, 14}, {1075, 24}, {8914, 34}, {9756, 44}, {9910, 54}}},
    },
    PALADIN = {
        {ranks = {{20217, 20}}, also = {25898}, group = "blessing"},
        {ranks = {{19742, 14}, {19850, 24}, {19852, 34}, {19853, 44}, {19854, 54}, {25290, 60}}, also = {25894, 25918}, group = "blessing", mana = true},
        {ranks = {{19740, 4}, {19834, 12}, {19835, 22}, {19836, 32}, {19837, 42}, {19838, 52}, {25291, 60}}, also = {25782, 25916}, group = "blessing", melee = true},
    },
}
-- Klassen mit Mana (Segen der Weisheit zuerst), alle anderen bekommen Macht
Nearby.manaClasses = {PRIEST = true, MAGE = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true, HUNTER = true}

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret == true
end
local function Plain(v) if v ~= nil and not IsSecret(v) then return v end end
local function U(fnName, ...) return Plain((Call(rawget(_G, fnName), ...))) end
local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    return ONE.db.classGuide
end
local function InCombat() return type(InCombatLockdown) == "function" and InCombatLockdown() end
local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end

function Nearby:Enabled() return Store().buffNearby ~= false end
function Nearby:SetEnabled(on)
    Store().buffNearby = on and true or false
    self:Update()
end
function Nearby:AutoEnabled() return Store().nearbyAuto ~= false end
function Nearby:SetAuto(on)
    Store().nearbyAuto = on and true or false
    self:Update()
end

-- ===== Automatisch erkennen: unsichtbare freundliche Namensplaketten =====
local function GetCV(name)
    local cv = rawget(_G, "C_CVar")
    local v = cv and Call(cv.GetCVar, name)
    if v == nil then v = Call(rawget(_G, "GetCVar"), name) end
    return v ~= nil and tostring(v) or nil
end
local function SetCV(name, value)
    -- eigene Aenderung markieren (damit sie nicht als "du hast umgeschaltet" zaehlt)
    Nearby.ownChange = true
    local cv = rawget(_G, "C_CVar")
    local r
    if cv and type(cv.SetCVar) == "function" then r = Call(cv.SetCVar, name, value)
    else r = Call(rawget(_G, "SetCVar"), name, value) end
    Nearby.ownChange = nil
    return r
end

-- Namensplaketten-Addons: dann fasst Guild Trip die Plaketten nicht an
Nearby.PLATE_ADDONS = {"Plater", "Kui_Nameplates", "TidyPlates", "TidyPlates_ThreatPlates", "NeatPlates", "Platynator", "KkthnxUI", "ElvUI"}
function Nearby.PlateAddon()
    local loaded = (rawget(_G, "C_AddOns") or {}).IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    for _, name in ipairs(Nearby.PLATE_ADDONS) do
        if Call(loaded, name) then return name end
    end
end

-- Name der Einstellung "freundliche Spieler-Plaketten": im Forever-Client nameplateShowFriendlyPlayers
-- (Umschalt+V/Strg+V schalten diese; /trip buffcheck 19.11.2026), sonst nameplateShowFriends
function Nearby.FriendCV()
    if GetCV("nameplateShowFriendlyPlayers") ~= nil then return "nameplateShowFriendlyPlayers" end
    return "nameplateShowFriends"
end
local FriendCV = Nearby.FriendCV

-- Plaketten an/aus je nach Zustand; alte Werte werden gemerkt und zurueckgestellt.
-- Sichtbar oder unsichtbar? Deine Wahl (Umschalt+V) gilt; sonst wie vor Guild Trip
-- (hattest du freundliche Plaketten schon an, bleiben sie sichtbar).
function Nearby:Visible()
    local store = Store()
    if store.nearbyVisible ~= nil then return store.nearbyVisible end
    local old = store.nearbyCVars
    return (old and old.friends or GetCV(FriendCV())) == "1"
end

-- Plaketten sichtbar/unsichtbar und durchklickbar setzen
function Nearby:ApplyVisibility()
    self.hidePlates = self.autoOn and not self:Visible() or false
    local np = rawget(_G, "C_NamePlate")
    if np and type(np.SetNamePlateFriendlyClickThrough) == "function" then Call(np.SetNamePlateFriendlyClickThrough, self.hidePlates) end
    for i = 1, 40 do self:StylePlate("nameplate" .. i) end
end

function Nearby:ApplyAuto(want)
    if InCombat() then return end
    local store = Store()
    -- anderes Namensplaketten-Addon: nichts anfassen (dort selbst einschalten)
    if want and Nearby.PlateAddon() then want = false end
    if want then
        if not store.nearbyCVars then store.nearbyCVars = {friends = GetCV(FriendCV()) or "0"} end
        -- "Immer zeigen" (Strg+V): ohne das zeigt WoW Plaketten nur im Kampf -> Liste bliebe leer (Nutzer 18.11.2026)
        if store.nearbyCVars.all == nil then store.nearbyCVars.all = GetCV("nameplateShowAll") or "0" end
        if GetCV(FriendCV()) ~= "1" then SetCV(FriendCV(), "1") end
        if GetCV("nameplateShowAll") ~= "1" then SetCV("nameplateShowAll", "1") end
    else
        local old = store.nearbyCVars
        if old then
            -- zurueck: deine letzte eigene Wahl (sichtbar = an, unsichtbar = aus), sonst wie vor Guild Trip
            local friends = store.nearbyVisible == true and "1" or store.nearbyVisible == false and "0" or old.friends
            if friends then SetCV(FriendCV(), friends) end
            -- aus 0.7.0: dort wurde noch die Reichweite verstellt
            if old.dist then SetCV("nameplateMaxDistance", old.dist) end
            if old.all then SetCV("nameplateShowAll", old.all) end
            store.nearbyCVars = nil
        end
    end
    self.autoOn = want
    self:ApplyVisibility()
end

-- Du hast die freundlichen Plaketten selbst umgeschaltet (Umschalt+V, Menue): sichtbar <-> unsichtbar.
function Nearby:UserToggled()
    if not self.autoOn or self.ownChange then return false end
    -- Umschalt+V heisst jetzt nur noch sichtbar/unsichtbar: technisch bleiben die Plaketten an,
    -- sonst verliert die Buff-Liste die Spieler in der Naehe.
    local visible = not self:Visible()
    Store().nearbyVisible = visible
    if GetCV(FriendCV()) ~= "1" then SetCV(FriendCV(), "1") end
    self:ApplyVisibility()
    if ONE.Print then
        ONE:Print(visible and T("Freundliche Namensplaketten sichtbar. Umschalt + V blendet sie wieder aus – die Buff-Liste sieht die Spieler in der Nähe so oder so.")
            or T("Freundliche Namensplaketten ausgeblendet. Die Buff-Liste sieht die Spieler in der Nähe trotzdem."))
    end
    return true
end

-- Freundliche Spieler-Plakette unsichtbar (nur wenn wir sie eingeschaltet haben).
function Nearby:StylePlate(unit)
    local np = rawget(_G, "C_NamePlate")
    local plate = np and Call(np.GetNamePlateForUnit, unit)
    local uf = type(plate) == "table" and plate.UnitFrame
    if type(uf) ~= "table" or type(uf.SetAlpha) ~= "function" then return end
    -- Spieler und was Spielern gehoert (Begleiter, Totems) – freundliche NPCs bleiben, wie du sie eingestellt hast
    local hide = self.hidePlates and (U("UnitIsPlayer", unit) or U("UnitPlayerControlled", unit)) and U("UnitCanAssist", "player", unit)
    pcall(uf.SetAlpha, uf, hide and 0 or 1)
end

-- ===== Was kann ich verteilen? =====
-- Liste {name, icon, ids = {id -> Stufe}, also = {Name ...}, group, mana, melee}
function Nearby:MyOffers(p)
    local out = {}
    for _, o in ipairs(self.offers[p and p.classFile or ""] or {}) do
        local s = p:Spell(o.ranks[1][1])
        local mine = s.known and s.name and p.known[s.name]
        if mine then
            local e = {name = s.name, icon = s.icon, ranks = {}, also = {}, group = o.group, mana = o.mana, melee = o.melee}
            for _, r in ipairs(o.ranks) do
                if mine.ids and mine.ids[r[1]] then e.ranks[#e.ranks + 1] = r end
            end
            e.best = mine.id
            for _, id in ipairs(o.also or {}) do
                local n = classes.Player.SpellInfo(id)
                if n then e.also[#e.also + 1] = n end
            end
            out[#out + 1] = e
        end
    end
    return out
end

-- Hoechster bekannter Rang, den ein Ziel dieser Stufe annimmt (Ziel >= Stufe - 10).
-- Ohne Stufe (unbekannt) oder ohne Rangtabelle: dein bester Rang.
function Nearby.RankFor(offer, level)
    if type(level) ~= "number" or level <= 0 or #offer.ranks == 0 then return offer.best end
    local pick
    for _, r in ipairs(offer.ranks) do
        if r[2] - 10 <= level then pick = r[1] end
    end
    return pick or offer.ranks[1][1]
end

-- ===== Wer ist in der Naehe? =====
local function UnitAuras(unit)
    local list = {}
    local get = classes.Player.Path("C_UnitAuras.GetAuraDataByIndex")
    for i = 1, 40 do
        local aura = get and Call(get, unit, i, "HELPFUL")
        if type(aura) ~= "table" then
            if get then break end
            local name, _, _, _, _, expiration = Call(rawget(_G, "UnitBuff"), unit, i)
            if not name then break end
            aura = {name = name, expirationTime = expiration}
        end
        local name, expiration = aura.name, aura.expirationTime
        if type(name) == "string" and not IsSecret(name) then
            local left = math.huge
            if type(expiration) == "number" and not IsSecret(expiration) and expiration > 0 then left = expiration - Now() end
            if not list[name] or left > list[name] then list[name] = left end
        else
            return nil -- gesperrt: Buffs unbekannt
        end
    end
    return list
end

local function Tag(unit, name, guid)
    if U("UnitInRaid", unit) or U("UnitInParty", unit) or (unit or ""):match("^party") or (unit or ""):match("^raid") then return "group" end
    if U("UnitIsInMyGuild", unit) then return "guild" end
    local fl = rawget(_G, "C_FriendList")
    if fl and guid and type(fl.IsFriend) == "function" and Plain((Call(fl.IsFriend, guid))) then return "friend" end
    if fl and name and type(fl.GetFriendInfo) == "function" and type(Call(fl.GetFriendInfo, name)) == "table" then return "friend" end
end

-- Merkt sich Spieler, die du mit der Maus beruehrt hast (fuer ohne Namensplaketten).
function Nearby:Remember(unit)
    if not (U("UnitIsPlayer", unit) and U("UnitCanAssist", "player", unit)) or U("UnitIsUnit", unit, "player") then return end
    local name = U("GetUnitName", unit, true)
    if type(name) ~= "string" then return end
    local _, classFile = Call(rawget(_G, "UnitClass"), unit)
    self.seen = self.seen or {}
    self.seen[name] = {name = name, level = U("UnitLevel", unit), classFile = Plain(classFile), guid = U("UnitGUID", unit),
        tag = Tag(unit, name, U("UnitGUID", unit)), at = Now()}
end

function Nearby:Units()
    local units = {}
    if U("IsInRaid") then for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else for i = 1, 4 do units[#units + 1] = "party" .. i end end
    units[#units + 1] = "target"
    for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
    return units
end

-- Sicher in Zauber-Reichweite? true/false/nil. Meldet WoW nichts (nil), hilft "Folgen"-Abstand (28 m).
function Nearby.InRange(rangeFn, spellName, unit)
    local r = Plain((Call(rangeFn, spellName, unit)))
    if r == 1 or r == true then return true end
    if r == 0 or r == false then return false end
    local close = Plain((Call(rawget(_G, "CheckInteractDistance"), unit, 4)))
    if close == true or close == 1 then return true end
    return nil
end

-- Spieler in Reichweite, denen mindestens einer deiner Buffs fehlt.
-- Eintrag: {name, unit (oder nil = nur per Name), level, classFile, tag, missing = {Angebot ...}, range}
function Nearby:Scan(offers)
    local out, byName = {}, {}
    if #offers == 0 then return out end
    local rangeFn = classes.Player.Path("C_Spell.IsSpellInRange") or rawget(_G, "IsSpellInRange")
    for _, unit in ipairs(self:Units()) do
        if U("UnitExists", unit) and U("UnitIsPlayer", unit) and not U("UnitIsUnit", unit, "player")
            and U("UnitCanAssist", "player", unit) and not U("UnitIsDeadOrGhost", unit) and U("UnitIsConnected", unit) ~= false then
            local name = U("GetUnitName", unit, true)
            if type(name) == "string" and not byName[name] then
                local range = Nearby.InRange(rangeFn, offers[1].name, unit)
                -- nur wer sicher in Reichweite ist (Nutzer 18.11.2026: Spieler in der Liste waren teils zu weit weg)
                if range == true then
                    local _, classFile = Call(rawget(_G, "UnitClass"), unit)
                    local guid = U("UnitGUID", unit)
                    local e = {name = name, unit = unit, level = U("UnitLevel", unit), classFile = Plain(classFile),
                        tag = Tag(unit, name, guid), auras = UnitAuras(unit), range = range}
                    byName[name] = e
                    out[#out + 1] = e
                end
            end
        end
    end
    -- Zuletzt beruehrte Spieler ohne Einheit kommen NICHT mehr in die Liste: ihre Entfernung ist unbekannt,
    -- der Buff scheiterte oft an der Reichweite (18.11.2026). Gemerkt bleiben sie nur fuer kurze Zeit.
    local now = Now()
    for name, s in pairs(self.seen or {}) do
        if now - s.at > self.keep then self.seen[name] = nil end
    end
    -- Was fehlt jedem? Wer gerade von dir gebufft wurde, ist raus.
    local keep = {}
    for _, e in ipairs(out) do
        e.missing = self:MissingFor(e, offers)
        if #e.missing > 0 and not self:IsDone(e, offers) then keep[#keep + 1] = e end
    end
    local order = {group = 1, guild = 2, friend = 3}
    table.sort(keep, function(a, b)
        local oa, ob = order[a.tag or ""] or 4, order[b.tag or ""] or 4
        if oa ~= ob then return oa < ob end
        if (a.unit ~= nil) ~= (b.unit ~= nil) then return a.unit ~= nil end
        return a.name < b.name
    end)
    return keep
end

-- Fehlende Buffs eines Spielers, in Klick-Reihenfolge. Segen: nur einer je
-- Ziel – Koenige, sonst Weisheit fuer Mana-Klassen und Macht fuer alle anderen.
function Nearby:MissingFor(e, offers)
    local list = {}
    local hasGroup = {}
    local function Has(o)
        if not e.auras then return false end
        local best = e.auras[o.name]
        for _, n in ipairs(o.also) do if e.auras[n] and (not best or e.auras[n] > best) then best = e.auras[n] end end
        return best ~= nil and best >= self.soon
    end
    for _, o in ipairs(offers) do
        if o.group and Has(o) then hasGroup[o.group] = true end
    end
    local mana = self.manaClasses[e.classFile or ""]
    for _, o in ipairs(offers) do
        if not (o.group and hasGroup[o.group]) and not Has(o) then
            local score = (o.mana and (mana and 1 or 3)) or (o.melee and (mana and 3 or 1)) or 0
            list[#list + 1] = {offer = o, score = score, spell = self.RankFor(o, e.level)}
        end
    end
    for i, m in ipairs(list) do m.pos = i end
    table.sort(list, function(a, b) if a.score ~= b.score then return a.score < b.score end return a.pos < b.pos end)
    return list
end

-- ===== Erledigt (von dir gebufft) =====
local function Short(name) return type(name) == "string" and (name:gsub("%-.*", "")) or nil end

-- Zauber abgeschickt: Ziel merken (castGUID -> Name + Buff).
function Nearby:OnSent(unit, target, castGUID, spellID)
    if unit ~= "player" or type(target) ~= "string" or IsSecret(target) or target == "" or not castGUID then return end
    local spell = classes.Player.SpellInfo(spellID)
    for _, o in ipairs(self.myOffers or {}) do
        if o.name == spell then
            self.sent = self.sent or {}
            self.sent[castGUID] = {name = Short(target), buff = o.name}
            return
        end
    end
end

-- Zauber erfolgreich: Spieler ist erledigt und faellt aus der Liste.
function Nearby:OnSucceeded(unit, castGUID)
    local s = unit == "player" and self.sent and self.sent[castGUID]
    if not s then return end
    self.sent[castGUID] = nil
    self:MarkDone(s.name, s.buff)
end

function Nearby:MarkDone(name, buff)
    if not name or name == Short(U("UnitName", "player")) then return end
    self.done = self.done or {}
    self.done[name] = {at = Now(), buff = buff}
    self.forceNext = true
end

-- Erledigt = in den letzten 30 Minuten von dir gebufft. Kennt man seine Buffs
-- und fehlt deiner wieder (nach kurzer Wartezeit), kommt er zurueck.
function Nearby:IsDone(e, offers)
    local d = self.done and self.done[Short(e.name)]
    if not d then return false end
    local age = Now() - d.at
    if age > self.doneFor then self.done[Short(e.name)] = nil return false end
    if age < self.grace or not e.auras then return true end
    for _, m in ipairs(e.missing) do
        if m.offer.name == d.buff then self.done[Short(e.name)] = nil return false end
    end
    return true
end

-- ===== Knoepfe =====
local function SpellText(id, fallback)
    local name = classes.Player.SpellInfo(id) or fallback
    local sub = Plain((Call(classes.Player.Path("C_Spell.GetSpellSubtext") or rawget(_G, "GetSpellSubtext"), id)))
    if type(sub) == "string" and sub ~= "" then return name .. "(" .. sub .. ")" end
    return name
end
Nearby.SpellText = SpellText

-- Klick-Belegung: Knopf 1, 2 und Umschalt+1
local SLOTS = {{"", "1"}, {"", "2"}, {"shift-", "1"}}
function Nearby:Bind(b, e)
    for _, s in ipairs(SLOTS) do
        local m = s[1]
        b:SetAttribute(m .. "type" .. s[2], nil)
        b:SetAttribute(m .. "spell" .. s[2], nil)
        b:SetAttribute(m .. "unit" .. s[2], nil)
        b:SetAttribute(m .. "macrotext" .. s[2], nil)
        b:SetAttribute(m .. "onespell" .. s[2], nil)
        b:SetAttribute(m .. "oneunit" .. s[2], nil)
    end
    for i, m in ipairs(e.missing) do
        local s = SLOTS[i]
        if not s then break end
        local mod, btn = s[1], s[2]
        -- Immer per Name: kurz anvisieren, wirken, altes Ziel zurueck. Zauber direkt auf "nameplateN" wirkt
        -- dieser Client nicht – ohne Fehlermeldung (Spieltest 19.11.2026, /trip buffcheck).
        local back = U("UnitExists", "target") and "/targetlasttarget" or "/cleartarget"
        b:SetAttribute(mod .. "type" .. btn, "macro")
        b:SetAttribute(mod .. "macrotext" .. btn, "/targetexact " .. e.name .. "\n/cast " .. SpellText(m.spell, m.offer.name) .. "\n" .. back)
        b:SetAttribute(mod .. "onespell" .. btn, m.spell)   -- nur zum Nachsehen (buffcheck, Tests)
        b:SetAttribute(mod .. "oneunit" .. btn, e.unit)
    end
end

local TAGS = {group = "Gruppe", guild = "Gilde", friend = "Freund"}
local CLICKS = {"Linksklick", "Rechtsklick", "Umschalt + Linksklick"}

-- Fenster im Blizzard-Aussehen, Texte in Theme-Farben
local function Ink(text) return text end
-- Aussehen (Zahnrad neben dem Titel, Nutzer 22.11.2026): Hintergrund, Titelfarbe. Namen bleiben in Klassenfarbe.
local function LookGear(parent, def, anchor)
    local gear = CreateFrame("Button", nil, parent)
    gear:SetSize(14, 14)
    gear:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    local gi = gear:CreateTexture(nil, "OVERLAY")
    gi:SetAllPoints()
    gi:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function() if ONE.WindowLook then ONE.WindowLook:Toggle(def, parent) end end)
    gear:SetScript("OnEnter", function(b)
        if not GameTooltip then return end
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:AddLine(T("Aussehen"), 1, .82, 0)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return gear
end
Nearby.LOOK = {
    id = "nearby", title = "In der Nähe: Aussehen", key = "nearbyLook",
    store = function() return ONE.db and (function()
        ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
        return ONE.db.classGuide
    end)() end,
    defaultBg = "dark", defaultAlpha = .55,
    roles = {{key = "head", label = "Überschriften", default = {1, .82, 0}}},
    onChange = function() Nearby:ApplyLook() end,
}
function Nearby:ApplyLook()
    local f, WL = self.frame, ONE.WindowLook
    if not (f and WL) then return end
    WL.ApplyBg(self.LOOK, f.bg)
    if f.title and f.title.SetTextColor then f.title:SetTextColor(WL.Color(self.LOOK, "head")) end
end

local function Themed(frame, bg, title, texts)
    local th = ONE.Themes
    if not th then return end
    if th.RegisterWindow then pcall(th.RegisterWindow, th, frame, bg, title) end
    for fs, role in pairs(texts or {}) do if th.RegisterText then pcall(th.RegisterText, th, fs, role) end end
end

-- Lage merken: echte linke untere Ecke (GetPoint lieferte nach dem Ziehen oft eine andere Bezugsecke,
-- beim Laden landete das Fenster dann links – Spieltest 19.11.2026)
local function SavePos(f)
    f:StopMovingOrSizing()
    local x, y = f.GetLeft and f:GetLeft(), f.GetBottom and f:GetBottom()
    if type(x) ~= "number" or type(y) ~= "number" then local _, _, _, px, py = f:GetPoint() x, y = px, py end
    if type(x) == "number" and type(y) == "number" then
        Store().nearbyPos = {x = math.floor(x + .5), y = math.floor(y + .5), v = 2}
        if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end   -- nur Guild Trip merkt sich die Lage
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Store().nearbyPos.x, Store().nearbyPos.y)
    end
end
Nearby.SavePos = SavePos

local function NewRow(parent, width, height)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "SecureActionButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(width, height)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    if hl.SetColorTexture then hl:SetColorTexture(1, 1, 1, .12) end
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 4, 0)
    if ONE.Themes and ONE.Themes.RegisterText then pcall(ONE.Themes.RegisterText, ONE.Themes, b.label, "text") end
    if b.label.SetJustifyH then b.label:SetJustifyH("LEFT") end
    b.icons = {}
    for i = 1, 3 do
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetSize(height - 4, height - 4)
        t:SetPoint("RIGHT", b, "RIGHT", -2 - (3 - i) * (height - 2), 0)
        if t.SetTexCoord then t:SetTexCoord(.07, .93, .07, .93) end
        b.icons[i] = t
    end
    b:SetScript("OnEnter", function(self)
        local e = self.entry
        if not GameTooltip or not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(e.name)
        if GameTooltip.AddLine then
            if e.level then GameTooltip:AddLine(T("Stufe %d", e.level), .8, .8, .8) end
            for i, m in ipairs(e.missing) do
                if not CLICKS[i] then break end
                GameTooltip:AddLine(T(CLICKS[i]) .. ": " .. SpellText(m.spell, m.offer.name), 1, .82, 0)
            end
            GameTooltip:AddLine(T("Nach dem Buff verschwindet er aus der Liste."), .7, .7, .7)
            if not e.unit then GameTooltip:AddLine(T("Nur per Name bekannt – zielt kurz an und wieder zurück."), .7, .7, .7) end
            if e.range == nil and e.unit then GameTooltip:AddLine(T("Reichweite unbekannt"), .7, .7, .7) end
            GameTooltip:AddLine(T("Alt + Ziehen: verschieben"), .5, .5, .5)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- fuer /trip buffcheck: was hat der letzte Klick ausgeloest? (Spieltest 18.11.2026: Klick tat nichts)
    if b.HookScript then
        b:HookScript("PostClick", function(self, button, down)
            local function A(k) local ok, v = pcall(self.GetAttribute, self, k) return ok and v or nil end
            local key = (button == "RightButton") and "2" or "1"
            Nearby.lastClick = {button = tostring(button), down = down, t = Now(), err = nil,
                type = A("type" .. key) or A("type"), spell = A("onespell" .. key), unit = A("oneunit" .. key),
                name = self.entry and self.entry.name}
        end)
    end
    if b.RegisterForDrag then b:RegisterForDrag("LeftButton") end
    b:SetScript("OnDragStart", function()
        if type(IsAltKeyDown) == "function" and IsAltKeyDown() and not InCombat() then Nearby.frame:StartMoving() end
    end)
    b:SetScript("OnDragStop", function() SavePos(Nearby.frame) end)
    return b
end

function Nearby:Frame()
    if self.frame then return self.frame end
    if InCombat() then return nil end -- Blizzard-Knoepfe nur ausserhalb des Kampfes anlegen
    local f = CreateFrame("Frame", "GuildTripBuffNearby", UIParent)
    f:SetSize(self.width, self.rowH)
    local pos = Store().nearbyPos
    if pos and pos.v ~= 2 then
        -- alter Wert (bis 0.7.1): bezog sich auf die Bildschirmmitte unten (wie WoWs eigene Fensterliste)
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", pos.x or 0, pos.y or 320)
    else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos and pos.x or 40, pos and pos.y or 320)
    end
    if f.SetMovable then f:SetMovable(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(self) if not InCombat() then self:StartMoving() end end)
    f:SetScript("OnDragStop", SavePos)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then bg:SetColorTexture(0, 0, 0, .55) end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    f.rows = {}
    f.bg = bg
    Themed(f, bg, f.title)
    f.gear = LookGear(f, Nearby.LOOK, f.title)
    -- Zahnrad nur beim Drueberfahren, Rechtsklick auf den Titel -> Einstellungen (22.11.2026)
    if ONE.WindowLook and ONE.WindowLook.Attach then
        ONE.WindowLook:Attach(f, f.gear, {def = Nearby.LOOK, label = f.title, title = "In der Nähe"})
    end
    self.frame = f
    self:ApplyLook()
    -- Im Kampf ausblenden – ueber Blizzards sichere Zustandssteuerung
    if type(RegisterStateDriver) == "function" then pcall(RegisterStateDriver, f, "visibility", "[combat] hide; show") end
    self.frame = f
    return f
end

-- Fenster neu aufbauen (nur ausserhalb des Kampfes).
-- Maus ueber der Liste: nicht umsortieren, aber wer aus der Reichweite laeuft, wird grau und
-- nicht mehr klickbar (Nutzer 19.11.2026: nur wer im Wirkradius ist)
function Nearby:Recheck()
    local f = self.frame
    if not (f and f.rows) or InCombat() then return end
    local rangeFn = classes.Player.Path("C_Spell.IsSpellInRange") or rawget(_G, "IsSpellInRange")
    for _, b in ipairs(f.rows) do
        local e = b.entry
        if e and (not b.IsShown or b:IsShown()) and e.missing and e.missing[1] then
            local ok = e.unit and U("UnitExists", e.unit) and Nearby.InRange(rangeFn, e.missing[1].offer.name, e.unit) == true
            if ok and b.__oneOut then
                b.__oneOut = nil
                if b.SetAlpha then b:SetAlpha(1) end
                self:Bind(b, e)
            elseif not ok and not b.__oneOut then
                b.__oneOut = true
                if b.SetAlpha then b:SetAlpha(.35) end
                self:Bind(b, {name = e.name, missing = {}})
            end
        end
    end
end

function Nearby:Update()
    if InCombat() then self.dirty = true return end
    -- Maus auf der Liste: nichts umsortieren (sonst rutscht ein anderer Spieler unter den Mauszeiger).
    -- Ausnahme: gerade erfolgreich gebufft – dann darf der Spieler raus.
    local f0 = self.frame
    if f0 and not self.forceNext and f0.IsMouseOver and f0:IsShown() and (f0:GetAlpha() or 0) > 0 and f0:IsMouseOver() then
        self:Recheck()
        return self.shown
    end
    self.forceNext = nil
    self.dirty = false
    local list = {}
    if self:Enabled() then
        local p = classes.Player:Read(Store().spec)
        self.myOffers = self:MyOffers(p)
        list = self:Scan(self.myOffers)
    else
        self.myOffers = {}
    end
    -- Plaketten sind aus, obwohl wir sie eingeschaltet hatten: das warst du (Umschalt+V)
    if self.autoOn and GetCV(FriendCV()) == "0" then self:UserToggled() end
    -- "Immer zeigen" wieder aus (Strg+V oder WoW-Einstellung): ohne das bleibt die Liste ausserhalb des
    -- Kampfes leer -> still wieder an (Spieltest 18.11.2026: "jetzt muss ich doch Strg+V druecken")
    if self.autoOn and not InCombat() and GetCV("nameplateShowAll") ~= "1" then SetCV("nameplateShowAll", "1") self.reAll = (self.reAll or 0) + 1 end
    local want = self:Enabled() and self:AutoEnabled() and #self.myOffers > 0
    if want ~= (self.autoOn or false) then self:ApplyAuto(want)
    elseif self.hidePlates then for i = 1, 40 do self:StylePlate("nameplate" .. i) end end
    self.shown = list
    if #list == 0 and not self.frame then return list end
    local f = self:Frame()
    if not f then return list end
    local n = math.min(#list, self.rows)
    f.title:SetText(T("Buffen in der Nähe (%d)", #list))
    for i = 1, n do
        local e = list[i]
        local b = f.rows[i] or NewRow(f, self.width - 4, self.rowH)
        f.rows[i] = b
        b.entry = e
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -18 - (i - 1) * self.rowH)
        local c = e.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.classFile]
        local short = e.name:gsub("%-.*", "")
        local text = c and c.colorStr and ("|c" .. c.colorStr .. short .. "|r") or short
        if e.level then text = text .. " |cffaaaaaa" .. e.level .. "|r" end
        if e.tag then text = text .. " |cff66ccff" .. T(TAGS[e.tag]) .. "|r" end
        b.label:SetText(Ink(text))
        b.__oneOut = nil
        if b.SetAlpha then b:SetAlpha(e.unit and 1 or .7) end
        for k = 1, 3 do
            local m = e.missing[k]
            local t = b.icons[k]
            if m then t:SetTexture(m.offer.icon or "Interface\\Icons\\INV_Misc_QuestionMark") t:Show() else t:Hide() end
        end
        self:Bind(b, e)
        b:Show()
    end
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    f:SetHeight(20 + n * self.rowH)
    if n > 0 then f:SetAlpha(1) else f:SetAlpha(0) end
    if f.EnableMouse then f:EnableMouse(n > 0) end
    return list
end

-- Pruefung im Spiel: wo reisst die Kette? (/trip buffcheck – Nutzer 18.11.2026: Fenster kam nicht)
function Nearby:Diagnose()
    local say = function(t) ONE:Print("|cffffd100Buffcheck:|r " .. t) end
    local p = classes.Player:Read(Store().spec)
    local offers = self:MyOffers(p)
    local names = {}
    for _, o in ipairs(offers) do names[#names + 1] = (o.name or "?") .. " (" .. tostring(o.best) .. ")" end
    say(("an=%s, automatisch=%s, Klasse=%s, deine Buffs: %s"):format(tostring(self:Enabled()), tostring(self:AutoEnabled()),
        tostring(p.classFile), #names > 0 and table.concat(names, ", ") or "KEINE erkannt"))
    say(("Namensplaketten Freunde (" .. FriendCV() .. ")=%s, immer zeigen=%s, Reichweite=%s, Plaketten-Addon=%s, im Kampf=%s"):format(tostring(GetCV(FriendCV())),
        tostring(GetCV("nameplateShowAll")), tostring(GetCV("nameplateMaxDistance")), tostring(self.PlateAddon() or "nein"), tostring(InCombat() and true or false)))
    say(("Automatik: an=%s, gewollt=%s, eigene Buffs=%d, „immer zeigen“ neu gesetzt=%dx"):format(tostring(self.autoOn or false),
        tostring(self:AutoEnabled()), #(self.myOffers or {}), self.reAll or 0))
    -- alle Plaketten-Einstellungen, die dieser Client kennt (Namen weichen je Client ab)
    local found = {}
    local cons = rawget(_G, "C_Console")
    local all = cons and Call(cons.GetAllCommands)
    if type(all) == "table" then
        for _, c in ipairs(all) do
            local n = type(c) == "table" and c.command
            if type(n) == "string" and n:lower():find("plate") and (n:lower():find("show") or n:lower():find("friend")) then
                found[#found + 1] = n .. "=" .. tostring(GetCV(n))
            end
        end
    end
    say(#found > 0 and ("Plaketten-Werte: " .. table.concat(found, ", ")) or "Plaketten-Werte: Liste nicht abrufbar")
    local bind = rawget(_G, "GetBindingAction")
    say(("Tasten: Strg+V=%s, Umschalt+V=%s, V=%s · zuletzt geändert: %s"):format(tostring(Call(bind, "CTRL-V")), tostring(Call(bind, "SHIFT-V")),
        tostring(Call(bind, "V")), self.cvarLog and table.concat(self.cvarLog, ", ") or "nichts"))
    local lc = self.lastClick
    if lc then
        say(("Letzter Klick: %s auf %s (%s, gedrückt=%s): %s %s auf %s · WoW: %s"):format(tostring(lc.button), tostring(lc.name),
            ("vor %ds"):format(math.floor(Now() - lc.t)), tostring(lc.down), tostring(lc.type), tostring(lc.spell), tostring(lc.unit), lc.err or "kein Fehler"))
    else say("Letzter Klick: noch keiner auf die Liste") end
    local rangeFn = classes.Player.Path("C_Spell.IsSpellInRange") or rawget(_G, "IsSpellInRange")
    local plates, players = 0, 0
    for _, unit in ipairs(self:Units()) do
        if U("UnitExists", unit) then
            if unit:find("^nameplate") then plates = plates + 1 end
            if U("UnitIsPlayer", unit) and not U("UnitIsUnit", unit, "player") then
                players = players + 1
                local why = {}
                if not U("UnitCanAssist", "player", unit) then why[#why + 1] = "nicht unterstuetzbar" end
                if U("UnitIsDeadOrGhost", unit) then why[#why + 1] = "tot" end
                local range = offers[1] and Plain((Call(rangeFn, offers[1].name, unit)))
                if range == false or range == 0 then why[#why + 1] = "zu weit" end
                local e = {name = U("GetUnitName", unit, true), level = U("UnitLevel", unit), auras = UnitAuras(unit),
                    classFile = select(2, Call(rawget(_G, "UnitClass"), unit))}
                if #self:MissingFor(e, offers) == 0 then why[#why + 1] = "hat schon alle Buffs" end
                say(("%s (%s, Stufe %s): %s"):format(tostring(e.name), unit, tostring(e.level), #why > 0 and table.concat(why, ", ") or "PASST – sollte in der Liste stehen"))
            end
        end
    end
    say(("Plaketten sichtbar: %d, Spieler gefunden: %d, Fenster-Liste: %d"):format(plates, players, #(self.shown or {})))
end

function Nearby:Initialize()
    if ONE.RegisterSlash then ONE:RegisterSlash("buffcheck", function() Nearby:Diagnose() end, T("Prüfen, warum „Buffen in der Nähe“ niemanden zeigt")) end
    local events = CreateFrame("Frame")
    for _, ev in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "GROUP_ROSTER_UPDATE",
        "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UPDATE_MOUSEOVER_UNIT", "UNIT_AURA",
        "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_LOGOUT", "CVAR_UPDATE", "UI_ERROR_MESSAGE",
        "UNIT_SPELLCAST_FAILED"}) do
        pcall(events.RegisterEvent, events, ev)
    end
    local pending = false
    events:SetScript("OnEvent", function(_, event, a, b, c, d)
        if event == "UPDATE_MOUSEOVER_UNIT" then Nearby:Remember("mouseover") end
        -- Ausloggen: Namensplaketten wieder wie vorher (falls das Addon mal fehlt, bleibt nichts verstellt)
        if event == "PLAYER_LOGOUT" then if Nearby.autoOn then Nearby:ApplyAuto(false) end return end
        if event == "CVAR_UPDATE" then
            Nearby.cvarLog = Nearby.cvarLog or {}
            table.insert(Nearby.cvarLog, tostring(a) .. "=" .. tostring(b))
            while #Nearby.cvarLog > 6 do table.remove(Nearby.cvarLog, 1) end
            if type(a) == "string" and a:lower() == FriendCV():lower() then Nearby:UserToggled() end
            return
        end
        if event == "UI_ERROR_MESSAGE" or event == "UNIT_SPELLCAST_FAILED" then
            local lc = Nearby.lastClick
            if lc and Now() - lc.t <= 2 and not lc.err then lc.err = event == "UI_ERROR_MESSAGE" and tostring(b or a) or "Zauber fehlgeschlagen" end
            if event == "UI_ERROR_MESSAGE" then return end
        end
        if event == "UNIT_SPELLCAST_SENT" then Nearby:OnSent(a, b, c, d) return end
        if event == "NAME_PLATE_UNIT_ADDED" then Nearby:StylePlate(a) end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if a ~= "player" then return end
            Nearby:OnSucceeded(a, b)
        end
        if pending or InCombat() then if InCombat() then Nearby.dirty = true end return end
        pending = true
        local function Go() pending = false Nearby:Update() end
        if C_Timer and C_Timer.After then C_Timer.After(.3, Go) else Go() end
    end)
    -- Reichweite aendert sich beim Laufen: zweimal je Sekunde nachsehen
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(.5, function() if not InCombat() and not pending then Nearby:Update() end end)
    end
    self.events = events
end
