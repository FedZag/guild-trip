local _, guild = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Guild = {}
guild.Guild = Guild

function Guild:GetInfo()
    if not IsInGuild() then
        return {name = T("Keine Gilde"), rank = "", members = "-"}
    end
    local name, rank = GetGuildInfo("player")
    local members = GetNumGuildMembers and GetNumGuildMembers() or nil
    return {
        name = name or T("Gildeninformationen werden geladen ..."),
        rank = rank or "",
        members = members and tostring(members) or "-",
    }
end

function Guild:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:SetScript("OnEvent", function()
        if ONE.UI then ONE.UI:Refresh() end
    end)
end
