local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Buff-Erinnerung: kleine Symbolzeile ueber den Leisten, NUR ausserhalb des
-- Kampfes. Zeigt Buffs aus dem Bauplan, die fehlen oder bald auslaufen.
--  * Buffs von anderen Spielern zaehlen mit (Suche nach Name, auch Gebete).
--  * Klick auf ein Symbol wirkt den Buff auf dich (Blizzard-Knopf
--    SecureActionButtonTemplate – erlaubt, weil du selbst klickst).
--  * Im Kampf blendet Blizzards Zustandssteuerung die Zeile sicher aus.
--  * Alt + Ziehen verschiebt sie; Haekchen auf der Klasse-Seite schaltet ab.
local Buffs = {size = 32, gap = 6, soon = 60}
classes.Buffs = Buffs

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret == true
end

local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    return ONE.db.classGuide
end

-- Aussehen (Zahnrad neben der Beschriftung, Nutzer 22.11.2026): Hintergrund hinter den Symbolen, Farbe der Beschriftung
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
Buffs.LOOK = {
    id = "buffs", title = "Buff-Erinnerung: Aussehen", key = "buffLook",
    store = function() return Store() end,
    defaultBg = "none",
    roles = {{key = "head", label = "Beschriftung", default = {1, .82, 0}}},
    onChange = function() Buffs:ApplyLook() end,
}
function Buffs:ApplyLook()
    local f, WL = self.frame, ONE.WindowLook
    if not (f and WL) then return end
    WL.ApplyBg(self.LOOK, f.bg)
    if f.label and f.label.SetTextColor then f.label:SetTextColor(WL.Color(self.LOOK, "head")) end
end

local function InCombat() return type(InCombatLockdown) == "function" and InCombatLockdown() end
local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end

function Buffs:Enabled() return Store().buffReminder ~= false end
function Buffs:SetEnabled(on)
    Store().buffReminder = on and true or false
    self:Update()
end

-- Eigene Buffs: Name -> Restzeit in Sekunden (math.huge = ohne Ablauf).
-- Geheime Werte (falls Forever sie sperrt) werden uebersprungen.
function Buffs:Auras()
    local list = {}
    local get = classes.Player.Path("C_UnitAuras.GetAuraDataByIndex")
    for i = 1, 40 do
        local aura = get and Call(get, "player", i, "HELPFUL")
        if type(aura) ~= "table" then
            if get then break end
            -- aelterer Weg
            local name, _, _, _, _, expiration = Call(UnitBuff, "player", i)
            if not name then break end
            aura = {name = name, expirationTime = expiration}
        end
        local name, expiration = aura.name, aura.expirationTime
        if type(name) == "string" and not IsSecret(name) then
            local left = math.huge
            if type(expiration) == "number" and not IsSecret(expiration) and expiration > 0 then
                left = expiration - Now()
            end
            if not list[name] or left > list[name] then list[name] = left end
        end
    end
    return list
end

-- Was fehlt oder laeuft bald aus? Liste {id, name, icon, left}
function Buffs:Missing(p, def)
    local out = {}
    if not (p and def and def.buffs) then return out end
    local auras = self:Auras()
    for _, b in ipairs(def.buffs) do
        if not b.spec or b.spec == p.spec then
            local own = p:Spell(b.ids)
            if own.known and own.name then
                local best = auras[own.name]
                for _, id in ipairs(b.also or {}) do
                    local other = classes.Player.SpellInfo(id)
                    if other and auras[other] and (not best or auras[other] > best) then best = auras[other] end
                end
                if not best or best < self.soon then
                    out[#out + 1] = {id = own.id, name = own.name, icon = own.icon, left = best}
                end
            end
        end
    end
    return out
end

-- ===== Begleiter (0.6.5) =====
-- Jaeger: Tier rufen / wiederbeleben / fuettern; Hexenmeister: Daemon beschwoeren;
-- Magier mit Forever-Talent: Wasserelementar. Nur ausserhalb von Kampf, Flug und Reittier.
Buffs.pets = {
    HUNTER = {call = {883}, revive = {982}, feed = {6991}},
    WARLOCK = {summon = {697, 688}},          -- Leerwandler (braucht Seelensplitter), sonst Wichtel
    MAGE = {summon = {31687}},                -- Wasserelementar, nur wenn als Talent gelernt
}
local SOUL_SHARD = 6265
local function UnitCall(fn, unit) return type(fn) == "function" and Call(fn, unit) end

function Buffs:PetMissing(p)
    local cfg = p and self.pets[p.classFile or ""]
    if not cfg then return {} end
    if UnitCall(UnitOnTaxi, "player") or (type(IsMounted) == "function" and Call(IsMounted)) then return {} end
    local exists = UnitCall(UnitExists, "pet")
    local dead = exists and UnitCall(UnitIsDead, "pet")
    if exists and not dead then self.petDied = false end
    if dead then self.petDied = true end
    local function Entry(ids, note)
        local s = p:Spell(ids)
        if s.known and s.name then return {id = s.id, name = s.name, icon = s.icon, pet = true, note = note} end
    end
    local out = {}
    if cfg.call then
        if not exists or dead then
            -- tot (gerade gesehen oder gemerkt) -> wiederbeleben, sonst rufen
            local e = (dead or self.petDied) and Entry(cfg.revive, T("Begleiter ist tot")) or Entry(cfg.call, T("Kein Begleiter da"))
            out[#out + 1] = e
        elseif type(GetPetHappiness) == "function" and Call(GetPetHappiness) == 1 then
            out[#out + 1] = Entry(cfg.feed, T("Begleiter ist unglücklich – füttern"))
        end
    elseif cfg.summon and (not exists or dead) then
        for _, id in ipairs(cfg.summon) do
            -- Leerwandler nur mit Seelensplitter
            local shard = id ~= 697 or (type(GetItemCount) == "function" and (Call(GetItemCount, SOUL_SHARD) or 0) > 0)
            local e = shard and Entry({id}, T("Kein Begleiter da"))
            if e then out[#out + 1] = e break end
        end
    end
    return out
end

local function NewButton(parent, size)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "SecureActionButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(size, size)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(b)
    if b.tex.SetTexCoord then b.tex:SetTexCoord(.07, .93, .07, .93) end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    if hl.SetTexture then hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square") end
    if hl.SetBlendMode then hl:SetBlendMode("ADD") end
    b.time = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.time:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not pcall(GameTooltip.SetSpellByID, GameTooltip, self.entry.id) then GameTooltip:SetText(self.entry.name or "?") end
        if GameTooltip.AddLine then
            GameTooltip:AddLine(self.entry.note or (self.entry.left and T("Läuft bald aus") or T("Fehlt")), 1, .5, .3)
            GameTooltip:AddLine(T("Klicken zum Wirken · Alt + Ziehen: verschieben"), .7, .7, .7)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if b.RegisterForDrag then b:RegisterForDrag("LeftButton") end
    b:SetScript("OnDragStart", function(self)
        if type(IsAltKeyDown) == "function" and IsAltKeyDown() and not InCombat() then self:GetParent():StartMoving() end
    end)
    b:SetScript("OnDragStop", function(self)
        local f = self:GetParent()
        f:StopMovingOrSizing()
        local _, _, _, x, y = f:GetPoint()
        Store().buffPos = {x = x, y = y}
    end)
    return b
end

function Buffs:Frame()
    if self.frame then return self.frame end
    if InCombat() then return nil end -- Blizzard-Knoepfe nur ausserhalb des Kampfes anlegen
    local f = CreateFrame("Frame", "GuildTripBuffReminder", UIParent)
    f:SetSize(self.size, self.size)
    local pos = Store().buffPos
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", pos and pos.x or 0, pos and pos.y or 230)
    if f.SetMovable then f:SetMovable(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("BOTTOM", f, "TOP", 0, 2)
    f.buttons = {}
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 18)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
    f.gear = LookGear(f, Buffs.LOOK, f.label)
    -- Im Kampf ausblenden – ueber Blizzards sichere Zustandssteuerung
    if type(RegisterStateDriver) == "function" then pcall(RegisterStateDriver, f, "visibility", "[combat] hide; show") end
    self.frame = f
    self:ApplyLook()
    return f
end

-- Zeile neu aufbauen (nur ausserhalb des Kampfes).
function Buffs:Update()
    if InCombat() then self.dirty = true return end
    self.dirty = false
    local f = self:Frame()
    if not f then return end
    local list = {}
    if self:Enabled() then
        local store = Store()
        local p = classes.Player:Read(store.spec)
        local def = classes.Data.classes[p.classFile or ""]
        list = self:Missing(p, def)
        for _, e in ipairs(self:PetMissing(p)) do list[#list + 1] = e end
    end
    for i, e in ipairs(list) do
        local b = f.buttons[i] or NewButton(f, self.size)
        f.buttons[i] = b
        b.entry = e
        b:ClearAllPoints()
        b:SetPoint("LEFT", f, "LEFT", (i - 1) * (self.size + self.gap), 0)
        b.tex:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.time:SetText(e.left and string.format("%ds", math.max(0, math.floor(e.left))) or "")
        if b.SetAttribute then
            b:SetAttribute("type", "spell")
            b:SetAttribute("spell", e.name)
            b:SetAttribute("unit", "player")
        end
        b:Show()
    end
    for i = #list + 1, #f.buttons do f.buttons[i]:Hide() end
    f:SetWidth(math.max(1, #list * (self.size + self.gap) - self.gap))
    local pets, buffs = 0, 0
    for _, e in ipairs(list) do if e.pet then pets = pets + 1 else buffs = buffs + 1 end end
    f.label:SetText(buffs > 0 and T("Buffs fehlen") or pets > 0 and T("Begleiter fehlt") or "")
    self.shown = list
    return list
end

function Buffs:Initialize()
    local events = CreateFrame("Frame")
    for _, ev in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_LEVEL_UP",
        "UNIT_PET", "UNIT_HEALTH", "UNIT_HAPPINESS", "PLAYER_MOUNT_DISPLAY_CHANGED", "BAG_UPDATE"}) do
        pcall(events.RegisterEvent, events, ev)
    end
    local pending = false
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit ~= "player" then return end
        if (event == "UNIT_HEALTH" or event == "UNIT_HAPPINESS") and unit ~= "pet" then return end
        if pending then return end
        pending = true
        local function Go() pending = false Buffs:Update() end
        if C_Timer and C_Timer.After then C_Timer.After(.3, Go) else Go() end
    end)
    -- Ablaufende Buffs: alle 10 Sekunden nachsehen
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(10, function() if not InCombat() then Buffs:Update() end end)
    end
    self.events = events
end
