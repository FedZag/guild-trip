-- Guild Trip Chat: sichtbarer Knopf zum Oeffnen (15.11.2026, "ich finde nicht, wo der Chat aufgeht").
-- Kleine Sprechblase oben am WoW-Chatfenster (bei ElvUI & Co. frei unten links), mit Zaehler fuer
-- ungelesene Fluesternachrichten. Linksklick: Chat auf/zu. Nur sichtbar, solange der Guild-Trip-Chat zu ist. Umschalt+Ziehen: verschieben.
-- Dazu eine Taste unter Tastaturbelegung › AddOns (Bindings.xml).
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI
local Launcher = {}
chat.Launcher = Launcher

-- Ungelesene Fluesternachrichten (die zaehlen; Handel & Co. waeren zu viel)
function Launcher.WhisperUnread()
    local n = 0
    for view, c in pairs(Chat.unread) do
        if type(view) == "string" and view:find("^w:") then n = n + c end
    end
    return n
end

function Launcher:Build()
    if self.button then return self.button end
    local b = CreateFrame("Button", "GuildTripChatLauncher", UIParent)
    b:SetSize(26, 26)
    b:SetFrameStrata("MEDIUM")
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetClampedToScreen(true)
    b:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    b:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    -- Zaehler (rotes Kreischen mit Zahl)
    local badgeBg = b:CreateTexture(nil, "OVERLAY")
    badgeBg:SetSize(16, 16)
    badgeBg:SetPoint("TOPRIGHT", b, "TOPRIGHT", 5, 4)
    badgeBg:SetTexture("Interface\\Common\\Indicator-Red")
    local badge = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("CENTER", badgeBg, "CENTER", 0, 0)
    b.badgeBg, b.badge = badgeBg, badge

    b:SetScript("OnClick", function() UI:Toggle() Launcher:Update() end)
    b:SetScript("OnDragStart", function(f) if IsShiftKeyDown and IsShiftKeyDown() then f:StartMoving() end end)
    b:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, rel, x, y = f:GetPoint()
        Chat:Settings().launcherPos = {point, rel, x, y}
    end)
    b:SetScript("OnEnter", function(f)
        if not GameTooltip then return end
        GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("Guild-Trip-Chat"), 1, .82, 0)
        local n = Launcher.WhisperUnread()
        if n > 0 then GameTooltip:AddLine(T("%d ungelesene Flüsternachrichten", n), 1, 1, 1) end
        GameTooltip:AddLine(T("Klick: öffnen/schließen"), .8, .8, .8)
        GameTooltip:AddLine(T("Umschalt+Ziehen: verschieben"), .8, .8, .8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.button = b
    self:Place()
    return b
end

-- Platz: gespeichert, sonst oben rechts am WoW-Chat; bei ElvUI & Co. unten links
function Launcher:Place()
    local b = self.button
    b:ClearAllPoints()
    local pos = Chat:Settings().launcherPos
    if type(pos) == "table" and pos[1] then
        b:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    elseif not Chat.OtherChatAddon() and _G.ChatFrame1 then
        b:SetPoint("BOTTOMRIGHT", _G.ChatFrame1, "TOPRIGHT", 2, 6)
    else
        b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 12, 230)
    end
end

function Launcher:Update()
    local b = self.button
    if not b then return end
    -- Nutzer 22.11.2026: bei offenem Guild-Trip-Chat ueberfluessig (dort gibt es "Zum WoW-Chat")
    if Chat:Settings().launcher == false or Chat.visible then b:Hide() return end
    b:Show()
    local n = self.WhisperUnread()
    b.badge:SetText(n > 0 and tostring(math.min(n, 99)) or "")
    if n > 0 then b.badgeBg:Show() b.badge:Show() else b.badgeBg:Hide() b.badge:Hide() end
end

-- Taste (Bindings.xml ruft das auf)
_G.BINDING_HEADER_GUILDTRIPCHAT = "Guild Trip"
_G.BINDING_NAME_GUILDTRIPCHAT_TOGGLE = T("Guild-Trip-Chat öffnen/schließen")
function _G.GuildTripChat_Toggle() UI:Toggle() Launcher:Update() end
