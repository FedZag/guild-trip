-- Guild Trip: Anfragen automatisch beantworten (Gesamtpruefung 23.11.2026, Ideen wie Leatrix Plus).
-- Alle Schalter Standard AUS (Nutzer: neue Automatiken aus). Nur C-Funktionen des Spiels (CancelDuel,
-- DeclineGroup, AcceptResurrect, C_SummonInfo.ConfirmSummon) – keine Blizzard-Fenster anfassen
-- (Forever sperrt sonst spaeter geschuetzte Aktionen, vgl. Einladen 22.11.2026). Das Spiel schliesst
-- seine Abfrage danach selbst (Duell) bzw. sie verfaellt.
-- "Bekannt" = Gilde, Freunde, Battle.net-Freunde (ihr WoW-Charakter), aktuelle Gruppe.
local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local K = {}
ONE.Comfort = K

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function Short(name) return type(name) == "string" and (name:match("^([^%-]+)") or name) or nil end
local function G(name) return rawget(_G, name) end

K.FEATURES = {
    {"core.declineDuels", "Duelle von Fremden ablehnen",
        "Lehnt Duelle sofort ab – außer von Gilde, Freunden und Battle.net-Freunden."},
    {"core.declineInvites", "Gruppeneinladungen von Fremden ablehnen",
        "Lehnt Gruppeneinladungen von Spielern ab, die nicht in deiner Gilde oder Freundesliste sind."},
    {"core.acceptRes", "Wiederbelebung automatisch annehmen",
        "Nimmt eine Wiederbelebung durch andere Spieler an – nicht, wenn der Helfer gerade kämpft."},
    {"core.acceptSummon", "Beschwörung automatisch annehmen",
        "Nimmt eine Beschwörung (z. B. Hexenmeister-Ritual) an – nicht im Kampf."},
}
if ONE.RegisterFeature then
    for _, f in ipairs(K.FEATURES) do
        local key = f[1]:gsub("^core%.", "")
        ONE:RegisterFeature(f[1], {label = f[2], tooltip = f[3],
            get = function() return ONE.db and ONE.db[key] == true end,
            set = function(on) if ONE.db then ONE.db[key] = on and true or false end end})
    end
end
local function On(id) return ONE.FeatureOn and ONE:FeatureOn(id) or false end

-- Ist der Name Gilde, Freund, Battle.net-Freund oder in der Gruppe?
function K.IsKnown(name)
    local short = Short(name)
    if not short then return false end
    -- Gilde
    local n = Try(G("GetNumGuildMembers")) or 0
    for i = 1, n do
        local full = Try(G("GetGuildRosterInfo"), i)
        if Short(full) == short then return true end
    end
    -- Freunde
    local FL = G("C_FriendList")
    if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
        for i = 1, Try(FL.GetNumFriends) or 0 do
            local info = Try(FL.GetFriendInfoByIndex, i)
            if type(info) == "table" and Short(info.name) == short then return true end
        end
    end
    -- Battle.net-Freunde (ihr gerade gespielter Charakter)
    local BN = G("C_BattleNet")
    local count = Try(G("BNGetNumFriends")) or 0
    if BN and BN.GetFriendAccountInfo then
        for i = 1, count do
            local info = Try(BN.GetFriendAccountInfo, i)
            local game = type(info) == "table" and info.gameAccountInfo
            if type(game) == "table" and Short(game.characterName) == short then return true end
        end
    end
    -- Gruppe
    local inGroup = G("UnitInParty") or G("UnitInRaid")
    if inGroup and Try(inGroup, short) then return true end
    return false
end

local function InCombat() return Try(G("InCombatLockdown")) == true or Try(G("UnitAffectingCombat"), "player") == true end

function K:OnEvent(event, a1)
    if event == "DUEL_REQUESTED" then
        if not On("core.declineDuels") or K.IsKnown(a1) then return false end
        Try(G("CancelDuel"))
        ONE:Print(T("Duell von %s abgelehnt (Optionen › Allgemein).", Short(a1) or "?"))
        return true
    elseif event == "PARTY_INVITE_REQUEST" then
        if not On("core.declineInvites") or K.IsKnown(a1) then return false end
        Try(G("DeclineGroup"))
        ONE:Print(T("Gruppeneinladung von %s abgelehnt (Optionen › Allgemein).", Short(a1) or "?"))
        return true
    elseif event == "RESURRECT_REQUEST" then
        if not On("core.acceptRes") then return false end
        if a1 and Try(G("UnitAffectingCombat"), a1) == true then return false end
        Try(G("AcceptResurrect"))
        return true
    elseif event == "CONFIRM_SUMMON" then
        if not On("core.acceptSummon") or InCombat() then return false end
        local SI = G("C_SummonInfo")
        if SI and SI.ConfirmSummon then Try(SI.ConfirmSummon) elseif G("ConfirmSummon") then Try(G("ConfirmSummon")) end
        return true
    end
    return false
end

function K:Initialize()
    if self.started then return end
    self.started = true
    local f = CreateFrame("Frame")
    for _, e in ipairs({"DUEL_REQUESTED", "PARTY_INVITE_REQUEST", "RESURRECT_REQUEST", "CONFIRM_SUMMON"}) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, event, ...) pcall(K.OnEvent, K, event, ...) end)
end
