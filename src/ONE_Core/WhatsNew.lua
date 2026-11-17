-- Guild Trip: "Neu in dieser Version" beim Einloggen (einmal je Version) + Hinweis aufs Teilen.
-- Guild Trip lebt davon, dass alle etwas teilen (Position, Rezepte, Quests, Funde). Standardmaessig ist alles aus –
-- darum zeigt dieses Fenster die Teilen-Haekchen gleich mit und bietet "Alles einschalten" an.
-- Ist nach dem Fenster noch etwas aus, kommt bei jedem Einloggen ein kurzer Chat-Hinweis (/trip teilen).
local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local WhatsNew = {}
ONE.WhatsNew = WhatsNew

-- Neuigkeiten je Version (kurz, fuer Spieler). Neue Versionen oben ergaenzen.
WhatsNew.notes = {
    ["0.6.6-alpha"] = {
        "Neuer Guild-Trip-Chat (freiwillig): Sprechblase am WoW-Chat, Reiter, Flüstern als eigene Gespräche",
        "Termine und Gildenausflüge planst und beantwortest du komplett in Guild Trip",
        "Klassen-Seite: Bewaffnung – welche Waffen du kannst und wo du sie lernst",
        "Klick auf einen Charakternamen öffnet ein Menü (Navi, Flüstern, Einladen …)",
        "Ausrüstung bewerten im Tooltip, Klassen-Ratgeber für Krieger, Paladin, Schamane nachgeschärft",
        "Buch-Aussehen: Daumenregister, gealterte Tinte, Blättern auf vollen Seiten",
    },
}

local function Notes()
    return WhatsNew.notes[ONE.version]
end

-- Alle Teilen-Schalter, die gerade zu sehen sind
function WhatsNew:ShareOptions()
    local out = {}
    if not (ONE.UI and ONE.UI.shareOptions) then return out end
    for _, opt in ipairs(ONE.UI.shareOptions) do
        local on = (not opt.module or ONE:IsEnabled(opt.module)) and (not opt.visible or opt.visible())
        if on then out[#out + 1] = opt end
    end
    return out
end
function WhatsNew:SharesOff()
    local n = 0
    for _, opt in ipairs(self:ShareOptions()) do
        local ok, state = pcall(opt.get)
        if ok and not state then n = n + 1 end
    end
    return n
end

function WhatsNew:Build()
    if self.frame then return self.frame end
    local opts = self:ShareOptions()
    local notes = Notes() or {}
    local W = 560
    local noteH = 0
    local f = CreateFrame("Frame", "GuildTripWhatsNew", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", 0, 40)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(0.04, 0.08, 0.13, 1)
    local function Label(text, font, x, y, width, role)
        local fs = f:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        fs:SetWidth(width or W - 44)
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        fs:SetText(text)
        if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(fs, role or "text") end
        return fs
    end
    local title = Label("GUILD TRIP  |  " .. T("NEU IN %s", ONE.version or ""), "GameFontNormal", 22, -16, W - 70, "accent")
    ONE.Widgets:CloseButton(f, "TOPRIGHT", -6, -6, function() f:Hide() end)

    local y = -46
    for _, line in ipairs(notes) do
        local bullet = Label("•  " .. T(line), "GameFontHighlight", 26, y, W - 56)
        local h = bullet.GetStringHeight and bullet:GetStringHeight() or 18
        if type(h) ~= "number" or h < 16 then h = 18 end
        y = y - h - 6
    end
    f.checks = {}
    if #opts > 0 then
        y = y - 8
        Label(T("Teilen – damit alle etwas davon haben"), "GameFontNormal", 22, y, W - 44, "accent")
        y = y - 26
        local intro = Label(T("Guild Trip wird besser, wenn deine Gilde zusammenlegt: Ihr seht euch auf der Karte, wisst, wer welches Rezept kann, und die Funde (Lehrer, Händler, Questgeber) landen im Startpaket für alle. Es wird nichts gesendet, solange ein Häkchen fehlt."),
            "GameFontHighlightSmall", 22, y, W - 44, "soft")
        local h = intro.GetStringHeight and intro:GetStringHeight() or 44
        if type(h) ~= "number" or h < 20 then h = 44 end
        y = y - h - 10
        for _, opt in ipairs(opts) do
            f.checks[#f.checks + 1] = ONE.Kit:Check(f, {point = "TOPLEFT", x = 18, y = y, label = opt.label,
                tooltip = opt.tooltip and T(opt.tooltip), get = opt.get, set = opt.set})
            y = y - 26
        end
        y = y - 8
        f.all = ONE.Widgets:Button(f, T("Alles einschalten"), 190, 32, "TOPLEFT", 22, y, function()
            for _, o in ipairs(opts) do pcall(o.set, true) end
            for _, b in ipairs(f.checks) do if b.Refresh then b:Refresh() end end
            ONE:Print(T("Teilen ist an – danke! Du kannst es jederzeit unter Optionen › Teilen ändern."))
        end, "primary")
        ONE.Widgets:Button(f, T("Später"), 120, 32, "TOPLEFT", 226, y, function() f:Hide() end, "secondary")
        y = y - 42
    else
        ONE.Widgets:Button(f, T("Verstanden"), 140, 32, "TOPLEFT", 22, y - 6, function() f:Hide() end, "primary")
        y = y - 48
    end
    f:SetSize(W, -y + 14)
    if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripWhatsNew") end
    ONE.Themes:RegisterWindow(f, bg, title)
    if ONE.Themes.StyleTree then ONE.Themes:StyleTree(f) end
    f:Hide()
    self.frame = f
    return f
end

function WhatsNew:Show()
    local f = self:Build()
    for _, b in ipairs(f.checks) do if b.Refresh then b:Refresh() end end
    f:Show()
end

-- Beim Einloggen: neue Version → Fenster; sonst, wenn Teilen noch aus ist → Chat-Hinweis
function WhatsNew:Check()
    if not ONE.db then return end
    if ONE.db.seenVersion ~= ONE.version and Notes() then
        ONE.db.seenVersion = ONE.version
        self:Show()
        return
    end
    ONE.db.seenVersion = ONE.version
    local off = self:SharesOff()
    if off > 0 then
        ONE:Print(T("%d Teilen-Funktionen sind noch aus – Guild Trip ist besser, wenn die Gilde teilt. /trip teilen öffnet die Einstellungen.", off))
    end
end

function WhatsNew:Initialize()
    if ONE.RegisterSlash then
        ONE:RegisterSlash("neu", function() WhatsNew:Show() end, T("Neuigkeiten dieser Version zeigen"))
        ONE:RegisterSlash("teilen", function()
            if ONE.UI then ONE.UI:Navigate("sharing") end
        end, T("Teilen-Einstellungen öffnen"))
    end
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_ENTERING_WORLD")
    login:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
        if not isInitialLogin or isReloadingUi or WhatsNew.started then return end
        WhatsNew.started = true
        local tries = 0
        local function Try()
            tries = tries + 1
            local blocked = (InCombatLockdown and InCombatLockdown())
                or (ONE.Welcome and ONE.Welcome.frame and ONE.Welcome.frame:IsShown())
                or (ONE.Welcome and ONE.Welcome.pendingLogin)
            if blocked and tries < 30 then C_Timer.After(3, Try) return end
            WhatsNew:Check()
        end
        C_Timer.After(5, Try)
    end)
end
