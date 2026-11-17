local _, ONE = ...

-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
-- Project ONE: one optional, moveable minimap access button.
-- Does not hook or modify the minimap or other addon buttons.
local Mini = { rimOffset = 3, alerts = {} }
ONE.MinimapButton = Mini

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x == 0 then return y >= 0 and math.pi/2 or -math.pi/2 end
    local a = math.atan(y/x)
    if x < 0 then a = a + (y >= 0 and math.pi or -math.pi) end
    return a
end

function Mini:Refresh()
    local button = self.button
    if not button or not ONE.db then return end
    if ONE.db.minimap.hidden then button:Hide(); return end
    button:Show()
    local angle = math.rad(tonumber(ONE.db.minimap.angle) or 225)
    -- Align the button CENTER close to the map rim, like ordinary addon icons.
    -- Using the icon half-width here left an entire empty button radius between
    -- the icon and the map, especially visible on scaled/custom minimaps.
    local w, h = Minimap:GetWidth(), Minimap:GetHeight()
    if not w or not h or w < 10 or h < 10 then return end
    local rim = math.min(w, h) * 0.5
    local radius = rim + self.rimOffset
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Neuigkeiten-Markierung: reason = Schluessel (z. B. "groups"), tab = Reiter zum Oeffnen.
function Mini:SetAlert(reason, text, tab)
    if type(reason) ~= "string" then return end
    self.alerts[reason] = {text = text or T("Neuigkeiten"), tab = tab}
    if self.badge then self.badge:Show() end
end
function Mini:ClearAlert(reason)
    self.alerts[reason] = nil
    if self.badge and not next(self.alerts) then self.badge:Hide() end
end
function Mini:AlertTab()
    for _, alert in pairs(self.alerts) do if alert.tab then return alert.tab end end
end

function Mini:SetVisible(visible)
    if not ONE.db then return end
    ONE.db.minimap.hidden = not visible
    self:Refresh()
end

function Mini:UpdateDrag()
    if not (self.dragging and self.button and GetCursorPosition) then return end
    local mx, my = GetCursorPosition()
    local cx, cy = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not (mx and my and cx and cy and scale and scale > 0) then return end
    local angle = math.deg(Atan2(my/scale - cy, mx/scale - cx))
    ONE.db.minimap.angle = angle
    self:Refresh()
end

function Mini:Initialize()
    if self.button or not Minimap or not ONE.db then return end
    ONE.db.minimap = ONE.db.minimap or { angle = 225, hidden = false }
    local button = CreateFrame("Button", "ProjectONEMinimapButton", Minimap)
    self.button = button
    -- Gleiche sichtbare Groesse wie die Minimap-Knoepfe anderer Addons (ca. 26 px).
    button:SetSize(26, 26)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    -- Das ONE-Logo bringt seinen eigenen Goldring mit; kein zusaetzlicher
    -- Blizzard-Tracking-Rahmen (der erschien als halber Bogen ueber dem Logo).
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\ONE_Core\\Textures\\Common\\ONE_Minimap.tga")
    icon:SetAllPoints(button)
    self.icon = icon
    -- Ausrufezeichen bei Neuigkeiten (z. B. neues Gruppengesuch), wie ein Questgeber-"!"
    local badge = button:CreateTexture(nil, "OVERLAY")
    badge:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    badge:SetSize(16, 16)
    badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)
    badge:Hide()
    self.badge = badge
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if self.menu:IsShown() then self.menu:Hide() else self.menu:Show() end
        elseif ONE.UI then
            self.menu:Hide()
            local tab = self:AlertTab()
            if tab and ONE.UI.Navigate then ONE.UI:Navigate(tab) else ONE.UI:Toggle() end
        end
    end)
    local menu = CreateFrame("Frame",nil,UIParent)
    self.menu=menu
    menu:SetSize(180,212)
    menu:SetPoint("TOPLEFT",button,"BOTTOMLEFT",0,-6)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    if ONE.Themes and ONE.Themes.RegisterPanel then ONE.Themes:RegisterPanel(menu) end
    local items={
        {T("Gilde"),function()
            if ONE.UI and ONE.UI.tabs.guild then ONE.UI:Navigate("guild")
            else ONE:Print(T("Das Gildenmodul ist nicht installiert.")) end
        end},
        {T("Gildenkarte"),function()
            local g=ONE.modules.guild
            if g and g.OpenMap then g:OpenMap() else ONE:Print(T("Das Gildenmodul fehlt.")) end
        end},
        -- Guild-Trip-Chat (Modul ONE_Chat) oeffnen/schliessen
        {T("Chat"),function()
            local c=ONE.modules.chat
            if c and c.Toggle and ONE:IsEnabled("chat") then c:Toggle() else ONE:Print(T("Das Chat-Modul ist nicht aktiv.")) end
        end},
        {T("Optionen"),function() if ONE.UI then ONE.UI:Navigate("options") end end},
    }
    for i,item in ipairs(items) do
        ONE.Widgets:Button(menu,item[1],154,34,"TOPLEFT",13,-12-(i-1)*47,function()
            menu:Hide()
            item[2]()
        end,"secondary")
    end
    menu:Hide()
    button:SetScript("OnDragStart", function()
        self.dragging = true
        button:SetScript("OnUpdate", function() self:UpdateDrag() end)
    end)
    button:SetScript("OnDragStop", function()
        self.dragging = false
        button:SetScript("OnUpdate", nil)
        self:UpdateDrag()
    end)
    button:SetScript("OnEnter", function(selfButton)
        if not GameTooltip then return end
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:SetText("Guild Trip |cffffffff" .. (ONE.version or "") .. "|r")
        GameTooltip:AddLine(T("Linksklick: Zentrale öffnen"), 0.85, 0.93, 1)
        GameTooltip:AddLine(T("Rechtsklick: Gildenkarte öffnen"), 0.85, 0.93, 1)
        GameTooltip:AddLine(T("Ziehen: am Minimap-Rand verschieben"), 0.7, 0.78, 0.84)
        for _, alert in pairs(self.alerts) do GameTooltip:AddLine("! " .. alert.text, 1, .82, 0, true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", function() self:Refresh() end)
    end
    self:Refresh()
end
