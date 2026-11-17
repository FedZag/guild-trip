-- Project ONE: Probe fuer den "nativen" Look.
-- Statt eigene Grafiken nachzuzeichnen, laesst ONE das Spiel seine eigenen
-- Fensterbausteine zeichnen (Blizzard-Vorlagen wie PortraitFrameTemplate,
-- UIPanelButtonTemplate). Diese Grafiken liegen im Spiel selbst; ONE kopiert
-- nichts, sondern verweist nur darauf. So sieht ONE aus wie die Forever-Fenster
-- und folgt automatisch, wenn Blizzard sein Aussehen aendert.
-- /one nativ  oeffnet ein Probefenster und speichert, welche Vorlagen es gibt.
local _, ns = ...
local ONE = _G.ProjectONE or ns -- liegt in ONE_Dev
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end
local Native = {}
ONE.Native = Native

Native.windowTemplates = {"PortraitFrameTemplate", "ButtonFrameTemplate", "BasicFrameTemplateWithInset"}
Native.probeTemplates = {
    {"Frame", "PortraitFrameTemplate"}, {"Frame", "ButtonFrameTemplate"},
    {"Frame", "BasicFrameTemplateWithInset"}, {"Frame", "InsetFrameTemplate"},
    {"Button", "UIPanelButtonTemplate"}, {"Button", "UIPanelCloseButton"},
    {"Button", "PanelTabButtonTemplate"}, {"EditBox", "SearchBoxTemplate"},
    {"CheckButton", "UICheckButtonTemplate"}, {"Frame", "TooltipBackdropTemplate"},
}

local function TryCreate(kind, template, parent)
    if type(CreateFrame) ~= "function" then return nil end
    local ok, frame = pcall(CreateFrame, kind, nil, parent or UIParent, template)
    if ok and frame then return frame end
end

-- Welche Vorlagen gibt es in diesem Client? Ergebnis landet in ProjectONEDB.nativeDiag.
function Native:Probe()
    local result = {templates = {}, layouts = {}}
    for _, entry in ipairs(self.probeTemplates) do
        local frame = TryCreate(entry[1], entry[2])
        result.templates[entry[2]] = frame ~= nil
        if frame and frame.Hide then frame:Hide() end
    end
    if type(_G.NineSliceLayouts) == "table" then
        local count = 0
        for name in pairs(_G.NineSliceLayouts) do
            count = count + 1
            if count <= 80 then result.layouts[#result.layouts + 1] = name end
        end
        result.layoutCount = count
    end
    if DevDB() then DevDB().nativeDiag = result end
    return result
end

local function SetTitle(frame, text)
    if type(frame.SetTitle) == "function" and pcall(frame.SetTitle, frame, text) then return end
    local title = frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText)
    if title and title.SetText then title:SetText(text) end
end

local function SetPortrait(frame, path)
    for _, method in ipairs({"SetPortraitToAsset", "SetPortraitTextureRaw"}) do
        if type(frame[method]) == "function" and pcall(frame[method], frame, path) then return true end
    end
    local portrait = frame.portrait or (frame.PortraitContainer and frame.PortraitContainer.portrait)
    if portrait and portrait.SetTexture then portrait:SetTexture(path) return true end
end

local function Text(parent, font, x, y, text, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then fs:SetWidth(width) fs:SetJustifyH("LEFT") end
    fs:SetText(text)
    return fs
end

local function NativeButton(parent, text, width, x, y)
    local b = TryCreate("Button", "UIPanelButtonTemplate", parent)
    if not b then return end
    b:SetSize(width, 26)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", function() ONE:Print("Probe: '" .. text .. "' geklickt.") end)
    return b
end

function Native:OpenPreview()
    local report = self:Probe()
    if self.preview then self.preview:Show() return self.preview end
    local frame, used
    for _, template in ipairs(self.windowTemplates) do
        frame = TryCreate("Frame", template)
        if frame then used = template break end
    end
    if not frame then
        ONE:Print("Keine Blizzard-Fenstervorlage gefunden – nativer Look hier nicht möglich.")
        return nil
    end
    self.preview, self.usedTemplate = frame, used
    frame:SetSize(560, 420)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    SetTitle(frame, "Guild Trip – Probe nativer Look")
    SetPortrait(frame, "Interface\\AddOns\\ONE_Core\\Textures\\Common\\Emblem.tga")

    local inset = frame.Inset or TryCreate("Frame", "InsetFrameTemplate", frame)
    if inset and not frame.Inset then
        inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -64)
        inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 40)
    end
    local host = inset or frame
    Text(host, "GameFontNormalLarge", 16, -14, "Deine Zentrale")
    Text(host, "GameFontHighlight", 16, -40, "So würde Guild Trip mit Blizzards eigenen Fensterteilen aussehen.", 500)
    Text(host, "GameFontNormal", 16, -78, "DEINE NÄCHSTEN TERMINE")
    Text(host, "GameFontHighlight", 16, -98, "20:00  Gildenabend")
    Text(host, "GameFontNormal", 280, -78, "NAVI")
    Text(host, "GameFontHighlight", 280, -98, "2 Mitglieder live")
    NativeButton(host, "Kalender öffnen", 150, 16, -130)
    NativeButton(host, "Navi starten", 150, 280, -130)
    local ok = {}
    for name, present in pairs(report.templates) do if present then ok[#ok + 1] = name end end
    table.sort(ok)
    Text(host, "GameFontDisableSmall", 16, -180, "Vorlagen im Client: " .. table.concat(ok, ", "), 500)

    -- Reiter unten wie im Charakterfenster
    local tabs = {}
    for i, label in ipairs({"Startseite", "Gilde", "Navi"}) do
        local tab = TryCreate("Button", "PanelTabButtonTemplate", frame)
        if not tab then break end
        tab:SetID(i)
        tab:SetText(label)
        if i == 1 then tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
        else tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0) end
        tab:SetScript("OnClick", function(self)
            if type(PanelTemplates_SetTab) == "function" then pcall(PanelTemplates_SetTab, frame, self:GetID()) end
        end)
        tabs[i] = tab
        if type(PanelTemplates_TabResize) == "function" then pcall(PanelTemplates_TabResize, tab, 0) end
    end
    frame.Tabs = tabs
    if #tabs > 0 and type(PanelTemplates_SetNumTabs) == "function" then
        pcall(PanelTemplates_SetNumTabs, frame, #tabs)
        pcall(PanelTemplates_SetTab, frame, 1)
    end
    frame:Show()
    ONE:Print("Probefenster mit '" .. used .. "' geöffnet. Bitte Screenshot machen; danach /reload.")
    return frame
end
