-- Guild Trip: Bedienelemente im Glas-Aussehen (Nutzer 19.11.2026: "UI fertig haben").
-- Statt jede Seite anzufassen, geht Themes:StyleTree (wird beim Aufbau und Auffrischen jedes eigenen Fensters
-- aufgerufen) einmal durch alle Kinder und gibt im Glas-Aussehen jedem Blizzard-Bedienelement seinen Glas-Stil:
--   Haekchen (CheckButton)  -> runde Glas-Kachel, an = in Leuchtfarbe gefuellt mit Punkt
--   Regler (Slider)         -> feine Spur, runder Knopf in Leuchtfarbe
--   Scrollleisten           -> ohne Pfeile, schmaler Schieber in Leuchtfarbe
--   Eingabefelder (EditBox) -> eingelassene Glasflaeche statt Blizzard-Rahmen
-- Jedes Element nur einmal (__oneGlassCtl). Auswahlfelder: Kit:Dropdown -> Glass:Dropdown (eigener Knopf + Menue).
local _, ONE = ...
local Glass = ONE.Glass
if not Glass then return end

local function Pass(ok, ...) if ok then return ... end end
-- Methode sicher aufrufen; ALLE Rueckgaben weiterreichen (GetChildren/GetRegions liefern viele)
local function Call(obj, m, ...)
    local f = obj and obj[m]
    if type(f) ~= "function" then return nil end
    return Pass(pcall(f, obj, ...))
end
local function Hide(t) if t and t.SetAlpha then t:SetAlpha(0) end end
local function Lift(c, k) return c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k end

-- ===== Haekchen =====
function Glass:StyleCheck(box)
    if not box or box.__oneGlassCtl or not box.CreateTexture then return box end
    box.__oneGlassCtl = "check"
    for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture"}) do
        Hide(Call(box, getter))
    end
    local size = 16
    local plate = box:CreateTexture(nil, "BACKGROUND", nil, -3)
    plate:SetSize(size, size)
    plate:SetPoint("CENTER", box, "CENTER", 0, 0)
    plate:SetColorTexture(0, 0, 0, 0)
    local fill = self:Nine(box, self.tex.round, .25, "BACKGROUND", -2):Place(5, 0, plate)
    local edge = self:Nine(box, self.tex.roundRing, .25, "BACKGROUND", -1):Place(5, 0, plate)
    local dot = box:CreateTexture(nil, "ARTWORK", nil, 3)
    dot:SetTexture(self.tex.circle)
    dot:SetSize(7, 7)
    dot:SetPoint("CENTER", plate, "CENTER", 0, 0)
    local function Paint()
        local p = Glass:Palette()
        local g, t = p.glow, p.tint
        local on = Call(box, "GetChecked") and true or false
        local enabled = Call(box, "IsEnabled") ~= false
        local a = enabled and 1 or .45
        if on then fill:SetColor(g[1], g[2], g[3], .85 * a)
        else local r, gg, b = Lift(t, .12) fill:SetColor(r, gg, b, .9 * a) end
        edge:SetColor(g[1], g[2], g[3], (on and .9 or (box.__oneHover and .7 or .4)) * a)
        local og = p.onGlow or {1, 1, 1}
        dot:SetVertexColor(og[1], og[2], og[3], a)
        if on then dot:Show() else dot:Hide() end
    end
    box.__oneGlassPaint = Paint
    if type(hooksecurefunc) == "function" and box.SetChecked then pcall(hooksecurefunc, box, "SetChecked", Paint) end
    if box.HookScript then
        box:HookScript("OnClick", Paint)
        box:HookScript("OnShow", Paint)
        box:HookScript("OnEnter", function() box.__oneHover = true Paint() end)
        box:HookScript("OnLeave", function() box.__oneHover = nil Paint() end)
    end
    self:OnChange(Paint)
    Paint()
    return box
end

-- ===== Regler =====
function Glass:StyleSlider(slider)
    if not slider or slider.__oneGlassCtl or not slider.CreateTexture then return slider end
    slider.__oneGlassCtl = "slider"
    -- Blizzard-Rahmen/Hintergrund weg (OptionsSliderTemplate: NineSlice oder Backdrop)
    if slider.NineSlice and slider.NineSlice.Hide then slider.NineSlice:Hide() end
    if slider.SetBackdrop then pcall(slider.SetBackdrop, slider, nil) end
    for _, r in ipairs({Call(slider, "GetRegions")}) do
        if r and r.GetObjectType and r:GetObjectType() == "Texture" and r ~= Call(slider, "GetThumbTexture") then Hide(r) end
    end
    local track = slider:CreateTexture(nil, "BACKGROUND", nil, 1)
    track:SetHeight(4)
    track:SetPoint("LEFT", slider, "LEFT", 4, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", -4, 0)
    track:SetTexture(self.tex.round)
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(self.tex.circle)
    thumb:SetSize(14, 14)
    if slider.SetThumbTexture then pcall(slider.SetThumbTexture, slider, thumb) end
    local function Paint()
        local g = Glass:Palette().glow
        track:SetVertexColor(g[1], g[2], g[3], .35)
        thumb:SetVertexColor(g[1], g[2], g[3], 1)
    end
    self:OnChange(Paint)
    Paint()
    return slider
end

-- ===== Scrollleisten =====
local function ScrollBarOf(scroll)
    local bar = scroll.ScrollBar
    if not bar and scroll.GetName and scroll:GetName() then bar = rawget(_G, scroll:GetName() .. "ScrollBar") end
    return type(bar) == "table" and bar or nil
end
function Glass:StyleScroll(scroll)
    if not scroll or scroll.__oneGlassCtl then return scroll end
    local bar = ScrollBarOf(scroll)
    if not bar then return scroll end
    scroll.__oneGlassCtl = "scroll"
    local name = bar.GetName and bar:GetName()
    for _, key in ipairs({"ScrollUpButton", "ScrollDownButton", "Back", "Forward"}) do
        local b = bar[key] or (name and rawget(_G, name .. key))
        if b and b.Hide then b:Hide() b:SetAlpha(0) if b.EnableMouse then b:EnableMouse(false) end end
    end
    local thumbTex = Call(bar, "GetThumbTexture")
    for _, r in ipairs({Call(bar, "GetRegions")}) do
        if r and r ~= thumbTex and r.GetObjectType and r:GetObjectType() == "Texture" then Hide(r) end
    end
    if bar.Background then Hide(bar.Background) end
    if bar.Track then Hide(bar.Track) end
    local rail = bar:CreateTexture(nil, "BACKGROUND")
    rail:SetWidth(2)
    rail:SetPoint("TOP", bar, "TOP", 0, 0)
    rail:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    rail:SetTexture(self.tex.round)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(self.tex.round)
    thumb:SetSize(6, 36)
    if bar.SetThumbTexture then pcall(bar.SetThumbTexture, bar, thumb) end
    local function Paint()
        local g = Glass:Palette().glow
        rail:SetVertexColor(g[1], g[2], g[3], .12)
        thumb:SetVertexColor(g[1], g[2], g[3], .65)
    end
    self:OnChange(Paint)
    Paint()
    return scroll
end

-- ===== Eingabefelder =====
function Glass:StyleEdit(edit)
    if not edit or edit.__oneGlassCtl or not edit.CreateTexture then return edit end
    edit.__oneGlassCtl = "edit"
    for _, key in ipairs({"Left", "Middle", "Right", "Mid"}) do Hide(edit[key]) end
    local name = edit.GetName and edit:GetName()
    if name then for _, key in ipairs({"Left", "Middle", "Right", "Mid"}) do Hide(rawget(_G, name .. key)) end end
    local s = self:Surface(edit, "select")
    if s then
        local focus = false
        s.onPaint = function(surface, p)
            local g, t = p.glow, p.tint
            local r, gg, b = Lift(t, .06)
            surface.fill:SetColor(r, gg, b, .85)
            if surface.edge then surface.edge:SetColor(g[1], g[2], g[3], focus and .8 or .3) end
        end
        if edit.HookScript then
            edit:HookScript("OnEditFocusGained", function() focus = true Glass:Paint(s) end)
            edit:HookScript("OnEditFocusLost", function() focus = false Glass:Paint(s) end)
        end
        self:Paint(s)
    end
    return edit
end

-- ===== Runde Spielsymbole in Listen =====
-- Macht aus einem eckigen Symbol (Textur einer Listenzeile) ein rundes mit feinem Ring in Leuchtfarbe.
-- Nur im Glas-Aussehen; im Blizzard-Look bleibt es eckig.
function Glass:RoundIcon(holder, icon)
    if not (icon and holder and self:Active()) or icon.__oneRound then return icon end
    icon.__oneRound = true
    if icon.SetTexCoord then icon:SetTexCoord(.08, .92, .08, .92) end
    if holder.CreateMaskTexture and icon.AddMaskTexture then
        local ok, m = pcall(holder.CreateMaskTexture, holder)
        if ok and m then
            m:SetTexture(self.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(icon)
            pcall(icon.AddMaskTexture, icon, m)
        end
    end
    local ring = holder:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(self.tex.ring)
    ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    local function Paint() local g = Glass:Palette().glow ring:SetVertexColor(g[1], g[2], g[3], .55) end
    self:OnChange(Paint)
    Paint()
    icon.__oneRing = ring
    return icon
end

-- ===== Durch einen Fenster-Baum gehen =====
function Glass:StyleControl(f)
    local kind = Call(f, "GetObjectType")
    if kind == "CheckButton" then
        -- nur Haekchen mit Blizzard-Bild (keine eigenen Kacheln/Schalter)
        if Call(f, "GetCheckedTexture") or Call(f, "GetNormalTexture") then self:StyleCheck(f) end
    elseif kind == "Slider" then
        -- Scrollleisten-Schieber gehoeren zur Scrollleiste
        local parent = Call(f, "GetParent")
        if not (parent and Call(parent, "GetObjectType") == "ScrollFrame") then self:StyleSlider(f) end
    elseif kind == "ScrollFrame" then
        self:StyleScroll(f)
    elseif kind == "EditBox" then
        self:StyleEdit(f)
    end
end
function Glass:StyleTree(root, depth)
    depth = depth or 0
    if not root or depth > 14 or type(root.GetChildren) ~= "function" then return end
    for _, child in ipairs({Call(root, "GetChildren")}) do
        if type(child) == "table" then
            if not child.__oneGlassCtl then self:StyleControl(child) end
            self:StyleTree(child, depth + 1)
        end
    end
end

-- Themes:StyleTree war bisher leer: im Glas-Aussehen jetzt die Bedienelemente einkleiden
if ONE.Themes then
    function ONE.Themes:StyleTree(frame)
        if Glass:Active() and frame then pcall(Glass.StyleTree, Glass, frame) end
    end
end

-- ===== Auswahlfeld (Glas): eigener Knopf mit Pfeil + eigenes Menue =====
-- dd = Rahmen aus Kit:Dropdown (Options(), CurrentText(), Select()) – hier nur das Aussehen
function Glass:Dropdown(parent, opts, Options, CurrentText, Select)
    local width = opts.width or 170
    local b = ONE.Widgets:Button(parent, "", width, 24, opts.point or "TOPLEFT", opts.x or 0, opts.y or 0, nil)
    local fs = b.GetFontString and b:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", b, "LEFT", 10, 0)
        fs:SetPoint("RIGHT", b, "RIGHT", -22, 0)
        fs:SetJustifyH("LEFT")
    end
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", b, "RIGHT", -8, -2)
    b:SetScript("OnClick", function(self) Glass:OpenMenu(self, Options(), CurrentText, Select, width) end)
    return b
end

-- ein Menue fuer alle Auswahlfelder; Klick daneben oder Esc schliesst
function Glass:OpenMenu(owner, list, CurrentText, Select, width)
    local m = self.menu
    if not m then
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN")
        catcher:SetScript("OnClick", function() Glass:CloseMenu() end)
        catcher:Hide()
        m = CreateFrame("Frame", "GuildTripGlassMenu", UIParent)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        m.surface = self:Surface(m, "window")
        m.rows = {}
        m.catcher = catcher
        m:SetScript("OnHide", function() catcher:Hide() end)
        if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripGlassMenu") end
        self.menu = m
    end
    local current = CurrentText()
    local rowH = 20
    for i, o in ipairs(list) do
        local r = m.rows[i]
        if not r then
            r = CreateFrame("Button", nil, m)
            r.sel = self:Surface(r, "select")
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", r, "LEFT", 22, 0)
            r.text:SetPoint("RIGHT", r, "RIGHT", -8, 0)
            r.text:SetJustifyH("LEFT")
            r.mark = r:CreateTexture(nil, "OVERLAY")
            r.mark:SetTexture(self.tex.circle)
            r.mark:SetSize(6, 6)
            r.mark:SetPoint("LEFT", r, "LEFT", 9, 0)
            r:SetScript("OnEnter", function(self2)
                self2.sel.hover = true Glass:Paint(self2.sel)
                if self2.tip and GameTooltip then
                    GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self2.label or "", 1, .82, 0)
                    GameTooltip:AddLine(self2.tip, 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end)
            r:SetScript("OnLeave", function(self2) self2.sel.hover = false Glass:Paint(self2.sel) if GameTooltip then GameTooltip:Hide() end end)
            m.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -6 - (i - 1) * rowH)
        r:SetSize(width - 12, rowH)
        r.label, r.tip = o.text, o.tooltip
        r.text:SetText(o.text)
        local on = o.text == current
        r.sel.on = on
        Glass:Paint(r.sel)
        local g = Glass:Palette().glow
        r.mark:SetVertexColor(g[1], g[2], g[3], 1)
        if on then r.mark:Show() else r.mark:Hide() end
        r:SetScript("OnClick", function() Glass:CloseMenu() Select(o.value) end)
        r:Show()
    end
    for i = #list + 1, #m.rows do m.rows[i]:Hide() end
    m:SetSize(width, 12 + #list * rowH)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    m.catcher:Show()
    m:Show()
end
function Glass:CloseMenu() if self.menu then self.menu:Hide() end end
