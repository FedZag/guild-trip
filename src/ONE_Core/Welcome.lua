local _, ONE = ...

-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
-- Ein wiederverwendbarer Tagesüberblick: weitere Module können später
-- eigene Termine über RegisterProvider beisteuern.
local Welcome = {providers = {}, ready = {}, pendingLogin = false, shownAtLogin = false}
ONE.Welcome = Welcome

local function AddLabel(parent, text, font, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width or 520)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    if ONE.Themes and ONE.Themes.RegisterText then
        local role=(font=="GameFontNormalSmall" or font=="GameFontNormal") and "accent"
            or (font=="GameFontHighlightSmall" and "soft" or "text")
        ONE.Themes:RegisterText(label,role)
    end
    return label
end

local function AddButton(parent, text, width, x, y, callback)
    return ONE.Widgets:Button(parent,text,width,34,"TOPLEFT",x,y,callback,"secondary")
end

function Welcome:RegisterProvider(id, collect, getStatus)
    if type(id) ~= "string" or type(collect) ~= "function" then return end
    self.providers[id] = {collect = collect, getStatus = getStatus}
end

function Welcome:MarkReady(id)
    self.ready[id] = true
    self:TryLoginGreeting()
end

function Welcome:GetEvents()
    local events, loading, failures = {}, false, false
    local count = 0
    for id, provider in pairs(self.providers) do
        if ONE:IsEnabled(id) then
            count = count + 1
            local ready, status = true, nil
            if provider.getStatus then
                local success, a, b = pcall(provider.getStatus)
                if success then ready, status = a, b else ready = false end
            end
            if not ready then
                loading = true
            elseif type(status) == "string" and (status:find("nicht zur Verfügung", 1, true) or status:find("nicht verfügbar", 1, true) or status:find("not available", 1, true)) then
                failures = true
            end
            if ready then
                local ok, items = pcall(provider.collect)
                if ok and type(items) == "table" then
                    for _, entry in ipairs(items) do
                        if type(entry) == "table" and type(entry.title) == "string" then
                            events[#events + 1] = {
                                title = entry.title,
                                hour = tonumber(entry.hour) or 0,
                                minute = tonumber(entry.minute) or 0,
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(events, function(a, b)
        if a.hour ~= b.hour then return a.hour < b.hour end
        if a.minute ~= b.minute then return a.minute < b.minute end
        return a.title < b.title
    end)
    return events, loading, failures, count
end

function Welcome:Initialize()
    self:BuildUI()
    -- Derselbe Tagesüberblick als eigene Seite IN der ONE-Zentrale.
    ONE.UI:RegisterView("today", function(panel)
        return self:BuildCentralView(panel)
    end)
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_ENTERING_WORLD")
    login:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
        if isInitialLogin and not isReloadingUi and not self.shownAtLogin then
            self.pendingLogin = ONE.db.loginSummaryEnabled
            if self.pendingLogin then
                -- Der Blizzard-Kalender braucht nach dem Laden einige Sekunden.
                C_Timer.After(22, function()
                    if self.pendingLogin then self:TryLoginGreeting(true) end
                end)
            end
        end
    end)
end

function Welcome:TryLoginGreeting(forceTimeout)
    if not self.pendingLogin or self.shownAtLogin or not ONE.db.loginSummaryEnabled then return end
    if not forceTimeout then
        for id in pairs(self.providers) do
            if ONE:IsEnabled(id) and not self.ready[id] then return end
        end
    end
    if InCombatLockdown and InCombatLockdown() then
        C_Timer.After(5, function() self:TryLoginGreeting(true) end)
        return
    end
    self.shownAtLogin, self.pendingLogin = true, false
    self:Show()
end

local function Greeting()
    local hour
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local t = C_DateAndTime.GetCurrentCalendarTime()
        if t then hour = t.hour end
    end
    hour = hour or 12
    if hour < 11 then return T("Guten Morgen") end
    if hour < 18 then return T("Hallo") end
    return T("Guten Abend")
end

-- Beide Darstellungen verwenden exakt dieselbe Daten- und Begrüßungslogik.
-- So sehen Login-Popup und Zentrale niemals unterschiedliche Tagesdaten.
function Welcome:Populate(view)
    if not view then return end
    local name = UnitName and UnitName("player") or nil
    view.heading:SetText(Greeting() .. (name and (", " .. name) or "") .. "!")
    -- Tagesspruch (derselbe wie auf der Startseite)
    if view.quip then view.quip:SetText(ONE.UI and ONE.UI.Quip and ONE.UI:Quip() or "") end
    local now = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if now then
        view.date:SetText(string.format(T("Dein Tagesüberblick für den %02d.%02d.%04d"), now.monthDay, now.month, now.year))
    else
        view.date:SetText(T("Dein Tagesüberblick"))
    end

    local events, loading, failures, providers = self:GetEvents()
    local maxRows = #view.rows
    for i, label in ipairs(view.rows) do
        local event = events[i]
        if event then
            label:SetText(string.format("|cffffd166%02d:%02d|r  %s", event.hour, event.minute, event.title))
        else
            label:SetText("")
        end
    end
    if #events > maxRows then
        view.summary:SetText(T("Weitere %d Termine findest du im Kalender.", #events - maxRows))
    elseif loading then
        view.summary:SetText(T("Weitere Kalenderdaten werden noch geladen. Bitte später erneut öffnen."))
    elseif failures then
        view.summary:SetText(T("Ein Teil der Kalenderdaten ist derzeit nicht verfügbar."))
    elseif #events == 0 and providers == 0 then
        view.summary:SetText(T("Noch kein Modul mit Tagesereignissen aktiviert."))
    elseif #events == 0 then
        view.summary:SetText(T("Heute stehen keine weiteren Kalender- oder Gildentermine an."))
    else
        view.summary:SetText(#events == 1 and T("Heute steht 1 Termin an.") or T("Heute stehen %d Termine an.", #events))
    end
end

-- Wird ausschließlich automatisch beim Charakter-Login als Pop-up geöffnet.
function Welcome:Show()
    if not self.frame then return end
    self:Populate(self.popup)
    self.frame:Show()
end

-- Bewusst eine Unterseite in der Zentrale, kein zweites Fenster.
function Welcome:BuildCentralView(panel)
    local view = {}
    AddLabel(panel, T("Deine Termine heute"), "GameFontNormalLarge", 0, -4, 650)
    view.heading = AddLabel(panel, "", "GameFontNormal", 0, -36, 650)
    view.quip = AddLabel(panel, "", "GameFontHighlight", 0, -58, 650)
    if view.quip.SetWordWrap then view.quip:SetWordWrap(true) end
    view.date = AddLabel(panel, "", "GameFontHighlightSmall", 0, -90, 650)
    AddLabel(panel, T("Deine nächsten Termine heute"), "GameFontNormal", 0, -118, 650)
    view.rows = {}
    for i = 1, 6 do
        view.rows[i] = AddLabel(panel, "", "GameFontHighlight", 6, -144 - (i - 1) * 27, 665)
    end
    view.summary = AddLabel(panel, "", "GameFontHighlightSmall", 0, -310, 665)
    AddLabel(panel, T("Blizzard-Weltereignisse folgen in einer späteren Version."), "GameFontDisableSmall", 0, -334, 650)
    AddButton(panel, T("Kalender öffnen"), 180, 0, -367, function()
        if not ONE.UI:OpenLink("calendar") then
            ONE:Print(T("Das Kalendermodul ist nicht installiert."))
        end
    end)
    AddButton(panel, T("Zurück"), 145, 202, -367, function()
        if not ONE.UI:GoBack() then ONE.UI:Navigate("home") end
    end)
    return function() self:Populate(view) end
end

function Welcome:BuildUI()
    local frame = CreateFrame("Frame", "ProjectONETodayWindow", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(590, 440)
    frame:SetPoint("CENTER", 0, 80)
    frame:SetFrameStrata("DIALOG")
    -- Eigenständige Fenster müssen bei Klick/Öffnen vor anderen ONE-Fenstern liegen.
    -- Andernfalls können Texte des hinteren Fensters vor unserem Hintergrund landen.
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        insets = {left=0, right=0, top=0, bottom=0},
    })
    -- Wirklich deckender Hintergrund: keine durchscheinenden Fensterinhalte.
    -- Die explizite Textur bleibt auch bei abweichender Backdrop-Darstellung sichtbar.
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    background:SetColorTexture(0.04, 0.08, 0.13, 1)
    frame:SetBackdropColor(0.04, 0.08, 0.13, 1)
    frame:SetBackdropBorderColor(0.28, 0.55, 0.73, 1)
    local title = AddLabel(frame, "GUILD TRIP  |  TAGESÜBERBLICK", "GameFontNormalSmall", 22, -18, 520)
    self.popup = {}
    self.popup.heading = AddLabel(frame, "", "GameFontNormalLarge", 22, -49, 510)
    self.popup.quip = AddLabel(frame, "", "GameFontHighlight", 22, -76, 540)
    if self.popup.quip.SetWordWrap then self.popup.quip:SetWordWrap(true) end
    self.popup.date = AddLabel(frame, "", "GameFontHighlightSmall", 22, -108, 510)
    AddLabel(frame, T("Deine nächsten Termine heute"), "GameFontNormal", 22, -131, 520)
    self.popup.rows = {}
    for i = 1, 6 do
        self.popup.rows[i] = AddLabel(frame, "", "GameFontHighlight", 26, -158 - (i - 1) * 29, 530)
    end
    self.popup.summary = AddLabel(frame, "", "GameFontHighlightSmall", 22, -337, 545)
    AddLabel(frame, T("Blizzard-Weltereignisse folgen in einer späteren Version."), "GameFontDisableSmall", 22, -358, 540)
    AddButton(frame, T("Kalender öffnen"), 180, 22, -381, function()
        frame:Hide()
        if not ONE.UI:OpenLink("calendar") then
            ONE:Print(T("Das Kalendermodul ist nicht installiert."))
        end
    end)
    AddButton(frame, T("Schließen"), 120, 225, -381, function() frame:Hide() end)
    ONE.Widgets:CloseButton(frame,"TOPLEFT",547,-9,function() frame:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ProjectONETodayWindow") end
    ONE.Themes:RegisterWindow(frame, background, title)
    ONE.Themes:StyleTree(frame)
    frame:Hide()
end
