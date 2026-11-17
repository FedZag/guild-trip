local _, ONE = ...

-- Gemeinsamer Benachrichtigungsdienst für ONE Core und alle Module.
-- Keine permanenten Spielerdaten; dieser Dienst zeigt nur In-Game-Hinweise an.
local Notifications = { queue = {}, currentToken = 0, showing = false }
ONE.Notifications = Notifications

local DISPLAY_SECONDS = 7
local MAX_QUEUE = 8

local function CleanText(value, maxLength)
    if type(value) ~= "string" or value == "" then return nil end
    if #value > maxLength then
        -- Nicht mitten in einem UTF-8-Zeichen abschneiden (Umlaute!).
        local cut = maxLength - 3
        while cut > 0 do
            local nextByte = value:byte(cut + 1)
            if not nextByte or nextByte < 128 or nextByte > 191 then break end
            cut = cut - 1
        end
        return value:sub(1, cut) .. "..."
    end
    return value
end

function Notifications:Initialize()
    if self.frame then return end
    local frame = CreateFrame("Frame", "ProjectONENotificationWindow", UIParent, "BackdropTemplate")
    frame:SetSize(440, 112)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -105)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 4, -4)
    background:SetPoint("BOTTOMRIGHT", -4, 4)
    background:SetColorTexture(0.04, 0.08, 0.13, 1)
    frame:SetBackdropColor(0.04, 0.08, 0.13, 1)
    frame:SetBackdropBorderColor(0.28, 0.55, 0.73, 1)

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 18, -15)
    header:SetWidth(375)
    header:SetJustifyH("LEFT")
    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    message:SetPoint("TOPLEFT", 18, -48)
    message:SetWidth(400)
    message:SetJustifyH("LEFT")
    message:SetJustifyV("TOP")
    message:SetText("")
    -- Benachrichtigungstexte folgen derselben Farbpalette wie die Zentrale.
    ONE.Themes:RegisterText(message,"text")

    ONE.Widgets:CloseButton(frame,"TOPLEFT",400,-8,function() self:Dismiss() end)

    self.frame, self.header, self.message = frame, header, message
    ONE.Themes:RegisterWindow(frame, background, header)
    ONE.Themes:StyleTree(frame)
    frame:Hide()
end

function Notifications:SettingsChanged()
    if not ONE.db or ONE.db.toastEnabled ~= false then return end
    -- Ein ausgeschaltetes Hinweisfenster bleibt wirklich geschlossen.
    self.queue = {}
    self:Dismiss(true)
end

function Notifications:Dismiss(clearOnly)
    self.currentToken = self.currentToken + 1
    self.showing = false
    if self.frame then self.frame:Hide() end
    if not clearOnly then self:ShowNext() end
end

function Notifications:ShowNext()
    if self.showing or not ONE.db or ONE.db.toastEnabled == false then return end
    local item = table.remove(self.queue, 1)
    if not item then return end
    if not self.frame then self:Initialize() end
    self.showing = true
    self.currentToken = self.currentToken + 1
    local token = self.currentToken
    self.header:SetText(item.source)
    self.message:SetText(item.message)
    self.frame:Show()

    -- Statt OnUpdate läuft nur ein Timer pro Anzeige; ältere Timer sind durch
    -- das Token entwertet, wenn ein Spieler das Fenster vorher schließt.
    if C_Timer and C_Timer.After then
        C_Timer.After(DISPLAY_SECONDS, function()
            if self.currentToken == token then self:Dismiss() end
        end)
    end
end

-- Modul-API: ONE:Notify("Text", { source = "ONE Guild", silent = false })
-- Nachrichten erscheinen weiterhin im Chat, auch wenn Popups deaktiviert sind.
function Notifications:Push(message, options)
    local cleanMessage = CleanText(message, 320)
    if not cleanMessage then return false end
    options = type(options) == "table" and options or {}
    local source = CleanText(options.source, 45) or "Guild Trip"

    ONE:Print("|cffffd166" .. cleanMessage .. "|r")
    -- Ton: eigener Klang (options.sound = "notify" | "trip"), sonst Raid-Warnung
    if ONE.db and ONE.db.soundEnabled and options.silent ~= true then
        if ONE.Sound and ONE.Sound.PlayAlert then ONE.Sound:PlayAlert(options.sound or "notify")
        elseif PlaySound and SOUNDKIT then
            local sound = SOUNDKIT.RAID_WARNING or SOUNDKIT.IG_MAINMENU_OPEN
            if sound then PlaySound(sound, "Master") end
        end
    end
    -- options.toast = false: nur Chatzeile (z. B. Gruppenfinder), kein Hinweisfenster
    if ONE.db and ONE.db.toastEnabled ~= false and options.toast ~= false then
        if #self.queue >= MAX_QUEUE then table.remove(self.queue, 1) end
        table.insert(self.queue, { message = cleanMessage, source = source })
        self:ShowNext()
    end
    return true
end
