-- Project ONE Guild: read-only guild roster and safe links to Blizzard guild actions.
local _, guild = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Roster = {}
guild.Roster = Roster

local function SortRoster(a, b)
    if a.online ~= b.online then return a.online end
    return string.lower(a.name) < string.lower(b.name)
end

function Roster:Request()
    if not (IsInGuild and IsInGuild()) then return end
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        pcall(C_GuildInfo.GuildRoster)
    elseif type(GuildRoster) == "function" then
        pcall(GuildRoster)
    end
end

function Roster:Members()
    if not (IsInGuild and IsInGuild()) then return {} end
    local info = type(GetGuildRosterInfo) == "function" and GetGuildRosterInfo
        or (C_GuildInfo and C_GuildInfo.GetGuildRosterInfo)
    if not info or type(GetNumGuildMembers) ~= "function" then return {} end
    -- GetNumGuildMembers() liefert (gesamt, online, ...). In Klammern nur den
    -- ersten Wert nehmen, sonst wird "online" als Zahlenbasis an tonumber uebergeben.
    local total = tonumber((GetNumGuildMembers())) or 0
    local members = {}
    for i = 1, math.min(total, 1000) do
        local name, rank, rankIndex, level, classLabel, zone,
            note, officerNote, online, status, class = info(i)
        if type(name) == "string" and name ~= "" then
            members[#members+1] = {
                name=name, rank=rank or "", rankIndex=rankIndex,
                level=tonumber(level) or 0, classLabel=classLabel or class or "",
                class=class or "", zone=zone or "", online=online==true,
            }
        end
    end
    table.sort(members, SortRoster)
    return members
end

function Roster:OnlineCount()
    local count = 0
    for _, player in ipairs(self:Members()) do
        if player.online then count = count + 1 end
    end
    return count
end

function Roster:OpenNativeGuildUI()
    -- Management actions that are protected by Forever are always left to
    -- Blizzard's native interface, which enforces guild permissions.
    if type(ToggleGuildFrame) == "function" then
        ToggleGuildFrame()
        return true
    end
    if type(GuildFrame) == "table" and type(GuildFrame.Show) == "function" then
        GuildFrame:Show()
        return true
    end
    ONE:Print(T("Öffne die Blizzard-Gildenverwaltung mit J. Geschützte Rang- und Rechteaktionen bleiben dort."))
    return false
end

function Roster:PrepareInvite()
    -- Protected C_GuildInfo.Invite cannot reliably be invoked by a Forever
    -- addon. Only PREPARE chat input; the user must type the name and press Enter.
    if type(ChatFrame_OpenChat) == "function" then
        ChatFrame_OpenChat("/ginvite ")
        return true
    end
    ONE:Print(T("Einladung manuell über /ginvite Name im Spielchat ausführen."))
    return false
end
