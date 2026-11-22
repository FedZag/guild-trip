-- Guild Trip: "Danke fuer den Buff" (Nutzer 19.11.2026: oeffentlich, automatisch, Standard an).
-- Bufft dich ein anderer Spieler, antwortet Guild Trip mit einem WoW-eigenen Emote an ihn (C_ChatInfo.PerformEmote)
-- ("Grimmbart dankt Lunara.", "… verbeugt sich vor Lunara.", "… jubelt Lunara zu.", "… winkt Lunara.").
-- Eigener Text (SendChatMessage) waere ohne Tastendruck gesperrt ("ONE_Classes wurde geblockt"),
-- WoW-eigene Emotes nicht (so macht es auch "Thanks for the Buff" auf Forever 1.60.1).
-- Neue Emotes kann ein Addon nicht anlegen – nur die eingebauten benutzen.
--   * mehrere Buffs derselben Person kurz hintereinander = ein Emote
--   * je Spieler hoechstens eins in COOLDOWN Sekunden, insgesamt hoechstens eins je GAP Sekunden
--   * nicht fuer Gruppen-/Schlachtzugsmitglieder, nicht fuer eigene Buffs, nicht im Kampf (danach, wenn noch frisch)
-- Schalter: Optionen › Klasse › "Für Buffs bedanken".
local _, classes = ...
local ONE = _G.ProjectONE

local Thanks = {COOLDOWN = 900, GAP = 20, BUNDLE = 4, LATE = 60}
classes.Thanks = Thanks
-- WoW-Emotes (Kennungen wie bei /danke, /verbeugen, /jubeln, /winken)
Thanks.EMOTES = {"THANK", "BOW", "CHEER", "WAVE"}

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function G(name) return rawget(_G, name) end
local function Now() return Call(G("GetTime")) or 0 end
local function InCombat() return Call(G("InCombatLockdown")) == true or Call(G("UnitAffectingCombat"), "player") == true end
-- Emotes an "Name-Realm" findet WoW nicht -> nur der Name
local function Short(name) return type(name) == "string" and (name:gsub("%-.*", "")) or name end

function Thanks:Enabled() return not ONE.FeatureOn or ONE:FeatureOn("classes.thanks") end

-- Darf sich bei diesem Spieler gerade bedankt werden?
function Thanks:Allowed(name, guid)
    if type(name) ~= "string" or name == "" then return false end
    if guid and type(guid) == "string" and not guid:find("^Player%-") then return false end
    local me = Call(G("UnitGUID"), "player")
    if guid and me and guid == me then return false end
    if Call(G("UnitInParty"), name) or Call(G("UnitInRaid"), name) then return false end
    local last = self.last and self.last[Short(name)]
    if last and Now() - last < self.COOLDOWN then return false end
    return true
end

-- Ein Buff ist angekommen (aus dem Kampflog): kurz sammeln, dann ein Emote
function Thanks:OnBuff(sourceName, sourceGUID)
    if not self:Enabled() or not self:Allowed(sourceName, sourceGUID) then return end
    self.pending = self.pending or {}
    local key = Short(sourceName)
    if self.pending[key] then return end
    self.pending[key] = {name = key, at = Now()}
    if C_Timer and C_Timer.After then C_Timer.After(self.BUNDLE, function() Thanks:Flush(key) end) end
end

function Thanks:Flush(key)
    local p = self.pending and self.pending[key]
    if not p then return end
    if Now() - p.at > self.LATE then self.pending[key] = nil return end
    if InCombat() then self.waiting = true return end
    if self.lastAny and Now() - self.lastAny < self.GAP then
        local wait = self.GAP - (Now() - self.lastAny) + .1
        if C_Timer and C_Timer.After then C_Timer.After(wait, function() Thanks:Flush(key) end) end
        return
    end
    self.pending[key] = nil
    if not self:Enabled() or not self:Allowed(p.name) then return end
    if self:Emote(p.name) then
        self.last = self.last or {}
        self.last[key] = Now()
        self.lastAny = Now()
    end
end

-- WoW-Emote an den Spieler (nie ohne Ziel: ohne Namen ginge es an dein aktuelles Ziel)
function Thanks:Emote(name, pick)
    if type(name) ~= "string" or name == "" then return false end
    -- NUR C_ChatInfo.PerformEmote: das alte DoEmote sperrt der Forever-Client ("ONE_Classes wurde geblockt",
    -- Spieltest 19.11.2026); so macht es auch "Thanks for the Buff". Fehlt es, lieber kein Danke.
    local ci = G("C_ChatInfo")
    local fn = type(ci) == "table" and ci.PerformEmote
    if type(fn) ~= "function" then return false end
    local r = pick or math.random
    local token = self.EMOTES[r(#self.EMOTES)]
    local ok = pcall(fn, token, name)
    if ok then self.sent = {token, name} end
    return ok
end

-- Werte, die Forever im Kampf "geheim" macht, darf man weder vergleichen noch verketten
local function Plain(v) local f = G("issecretvalue") return not (type(f) == "function" and f(v)) end
local function AurasSecret()
    local cs = G("C_Secrets")
    return type(cs) == "table" and type(cs.ShouldAurasBeSecret) == "function" and Call(cs.ShouldAurasBeSecret) == true
end

-- Wer hat diesen neuen Buff gezaubert? -> Name, GUID (nur Spieler; Haustier zaehlt nicht)
function Thanks.Caster(aura)
    if type(aura) ~= "table" then return nil end
    local unit = aura.sourceUnit
    local guid, name
    if unit ~= nil then
        if not Plain(unit) then return nil end
        guid = Call(G("UnitGUID"), unit)
        name = Call(G("UnitName"), unit)
    else
        local id = aura.auraInstanceID
        local ua = G("C_UnitAuras")
        if not (id and Plain(id) and type(ua) == "table") then return nil end
        guid = Call(ua.GetAuraCasterGUID, "player", id)
        if guid and Plain(guid) then name = Call(G("UnitNameFromGUID"), guid) end
    end
    if not (guid and name and Plain(guid) and Plain(name)) or name == "" then return nil end
    return name, guid
end

-- UNIT_AURA (Spieler): nur neu hinzugekommene, hilfreiche Auren
function Thanks:OnAura(unit, info)
    if unit ~= "player" or not self.ready or InCombat() or AurasSecret() then return end
    if type(info) ~= "table" or not Plain(info.isFullUpdate) or info.isFullUpdate then return end
    local added = info.addedAuras
    if type(added) ~= "table" or not Plain(added) then return end
    for _, aura in ipairs(added) do
        if type(aura) == "table" and Plain(aura.isHelpful) and aura.isHelpful then
            local name, guid = Thanks.Caster(aura)
            if name then self:OnBuff(name, guid) end
        end
    end
end

-- Nach Einloggen/Ladebildschirm kurz nicht hinsehen (Auren werden dabei neu gesetzt, sind aber keine neuen Buffs)
Thanks.SAFETY = 6
function Thanks:Pause()
    self.ready = false
    self.token = (self.token or 0) + 1
    local t = self.token
    if C_Timer and C_Timer.After then C_Timer.After(self.SAFETY, function() if Thanks.token == t then Thanks.ready = true end end)
    else self.ready = true end
end

-- Forever sperrt das Kampflog fuer Addons (COMBAT_LOG_EVENT_UNFILTERED -> "wurde geblockt", pcall hilft nicht;
-- Spieltest 19.11.2026, belegt in der Doku von "Thanks for the Buff", MIT) – darum UNIT_AURA.
function Thanks:Initialize()
    local f = CreateFrame("Frame")
    pcall(f.RegisterUnitEvent or f.RegisterEvent, f, "UNIT_AURA", "player")
    for _, ev in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_DISABLED"}) do pcall(f.RegisterEvent, f, ev) end
    f:SetScript("OnEvent", function(_, event, a, b)
        if event == "UNIT_AURA" then Thanks:OnAura(a, b)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if Thanks.waiting then
                Thanks.waiting = nil
                for key in pairs(Thanks.pending or {}) do Thanks:Flush(key) end
            end
        else Thanks:Pause() end
    end)
    self:Pause()
    self.events = f
end
