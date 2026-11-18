local _, ONE = ...

-- Gemeinsame Project-ONE-Schaltflächen. Ab 0.4.4 echte Blizzard-Knöpfe
-- (UIPanelButtonTemplate, rot mit Goldschrift wie im Spiel). Fehlt die Vorlage
-- (Tests, fremder Client), entsteht ein schlichter Knopf mit eigener Schrift.
local Widgets = {}
ONE.Widgets = Widgets

local function CreateLabel(button, text, alignment, leftInset, rightInset)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", button, "LEFT", leftInset, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -rightInset, 0)
    label:SetJustifyH(alignment)
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    button:SetFontString(label)
    button:SetText(ONE.T and ONE.T(text or "") or text or "")
    return label
end

local function NativeButton(parent, template)
    local ok, button = pcall(CreateFrame, "Button", nil, parent, template or "UIPanelButtonTemplate")
    if ok and button then return button end
end

function Widgets:Button(parent, text, width, height, point, x, y, callback, style)
    assert(parent and width and height, "ONE Button: Elternframe oder Maße fehlen")
    local button = NativeButton(parent)
    local native = button ~= nil
    button = button or CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:SetPoint(point or "TOPLEFT", parent, point or "TOPLEFT", x or 0, y or 0)
    button.__oneStyle = true
    button.__oneNative = native
    button.__oneVariant = style or "secondary"
    if native and button.GetFontString and button:GetFontString() then
        button:SetText(ONE.T and ONE.T(text or "") or text or "")
    else
        CreateLabel(button, text, "CENTER", 11, 11)
    end
    if callback then button:SetScript("OnClick", callback) end
    return button
end

-- Neue und bestehende Module benutzen denselben Layoutvertrag.
-- Die Region ist eine Seite/Spalte/Karte mit {x,y,width}; NICHT eine
-- willkuerliche Position mit freier Buttonbreite.
function Widgets:ActionButton(parent, text, region, callback, variant, profile, alignment)
    assert(ONE.Geometry and ONE.Geometry.ActionRect, "ONE Geometry fuer Aktionen fehlt")
    local rect=ONE.Geometry:ActionRect(region,profile,alignment)
    local button=self:Button(parent,text,rect.width,rect.height,"TOPLEFT",rect.x,rect.y,callback,variant or "secondary")
    button.__oneActionLayout={profile=profile or "card",align=alignment or "left",region=region}
    return button
end

-- Alle Seitentitel/Untertitel bekommen denselben Anker, dieselben
-- Schriftgroessen und dieselben Palettenrollen; Module benutzen diese API.
function Widgets:PageHeader(parent, title, subtitle, width, keepTop)
    local rect=ONE.Geometry:PageHeader(width)
    local function Line(text,font,y,role)
        local label=parent:CreateFontString(nil,"OVERLAY",font)
        label:SetPoint("TOPLEFT",parent,"TOPLEFT",rect.x,y)
        label:SetWidth(rect.width)
        label:SetJustifyH("LEFT")
        label:SetText(ONE.T and ONE.T(text) or text)
        if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(label,role) end
        return label
    end
    local heading=Line(title,"GameFontNormalLarge",rect.titleY,"text")
    local description=Line(subtitle,"GameFontHighlightSmall",rect.subtitleY,"soft")
    -- Blizzard-Aussehen mit Symbolleiste (0.6.8): Seitenname steht in der Kopfzeile,
    -- eigener Titel entfaellt, Seite rueckt nach oben
    -- keepTop: Seite hat neben dem Titel eigene Bedienelemente oben -> nicht hochruecken
    local sidebar = ONE.UI and ONE.UI.sidebar and parent and parent.__oneTopPanel
    if sidebar and (keepTop or ONE.UI:LiftPage(parent)) then
        heading:Hide() description:Hide()
        heading.Show=function() end description.Show=function() end
    end
    -- Buch: Titel nur auf der linken Seite, in Rubrik-Rot; die Unterzeile laeuft
    -- sonst ueber die Falz und steht ohnehin im Tooltip-Wissen der Seite
    return heading,description
end

-- Leere Listen / noch nicht installierte Module: kein grosser leerer Kasten.
-- Hier stehen nur passive Informationen, keine vorgetaeuschten Funktionen.
function Widgets:EmptyState(parent, region, title, description)
    ONE.Geometry:AssertEmptyRegion(region.parentWidth,region.parentHeight,region)
    local content=CreateFrame("Frame",nil,parent)
    content:SetPoint("TOPLEFT",parent,"TOPLEFT",region.x,region.y)
    content:SetSize(region.width,region.height)
    if content.SetFrameLevel and parent.GetFrameLevel then
        content:SetFrameLevel(parent:GetFrameLevel()+1)
    end
    local accent=content:CreateTexture(nil,"ARTWORK")
    accent:SetPoint("TOP",content,"TOP",0,-7)
    accent:SetSize(56,2)
    if ONE.Themes and ONE.Themes.RegisterRule then ONE.Themes:RegisterRule(accent,"accent") end
    local function Line(text,font,y,role)
        local label=content:CreateFontString(nil,"OVERLAY",font)
        label:SetPoint("TOP",content,"TOP",0,y)
        label:SetWidth(region.width-32)
        label:SetJustifyH("CENTER")
        label:SetText(ONE.T and ONE.T(text) or text)
        if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(label,role) end
        return label
    end
    local titleLabel=Line(title,"GameFontNormalLarge",-29,"text")
    local detailLabel=Line(description,"GameFontHighlightSmall",-66,"soft")
    function content:SetContent(newTitle,newDescription)
        titleLabel:SetText(ONE.T and ONE.T(newTitle) or newTitle)
        detailLabel:SetText(ONE.T and ONE.T(newDescription) or newDescription)
    end
    content.__oneEmptyTitle=titleLabel
    content.__oneEmptyDescription=detailLabel
    return content
end

-- Zentrierte Icon-Schaltfläche: Symbole sind Texturen statt Schriftzeichen.
-- Bei kleinen Buttons ist die Text-Baseline kein verlässlicher visueller Mittelpunkt.
function Widgets:IconButton(parent, texturePath, size, point, x, y, callback, variant, glyphSize)
    local button = self:Button(parent, "", size, size, point, x, y, callback, variant or "secondary")
    local glyph = button:CreateTexture(nil, "OVERLAY")
    glyph:SetTexture(texturePath)
    glyph:SetSize(glyphSize or 14, glyphSize or 14)
    glyph:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.__oneGlyph = glyph
    if ONE.Themes then ONE.Themes:ApplyButton(button) end
    return button
end

function Widgets:CloseButton(parent, point, x, y, callback)
    local ok, close = pcall(CreateFrame, "Button", nil, parent, "UIPanelCloseButton")
    if ok and close then
        close:SetPoint(point or "TOPLEFT", parent, point or "TOPLEFT", x or 0, y or 0)
        if callback then close:SetScript("OnClick", callback) end
        return close
    end
    return self:IconButton(parent,
        "Interface\\AddOns\\ONE_Core\\Textures\\Common\\CloseGlyph.tga",
        34, point or "TOPLEFT", x or 0, y or 0, callback, "primary", 14)
end

-- Kleiner Navi-Pfeil statt "Navi"-Knopf (Nutzer-Wunsch 15.11.2026: durchweg im ganzen Addon).
-- Startet das Navi nur beim Klick auf den Pfeil; der Tooltip sagt, wohin.
-- tip: Text oder Funktion(self) -> Titel, Zusatzzeile. callback(self) wie bei Button.
Widgets.naviTexture = "Interface\\AddOns\\ONE_Nav\\Textures\\Arrow"
local NAVI_COLOR, NAVI_HOVER, NAVI_OFF = {.4, 1, .6}, {1, 1, 1}, {.45, .45, .45}
local function NaviTint(btn, hover)
    local on = not btn.IsEnabled or btn:IsEnabled()
    local c = not on and NAVI_OFF or (hover and NAVI_HOVER or NAVI_COLOR)
    btn.icon:SetVertexColor(c[1], c[2], c[3])
end
function Widgets:NaviArrow(parent, size, point, x, y, callback, tip)
    local nb = CreateFrame("Button", nil, parent)
    size = size or 16
    nb:SetSize(size, size)
    nb:SetPoint(point or "RIGHT", parent, point or "RIGHT", x or 0, y or 0)
    if nb.SetFrameLevel and parent.GetFrameLevel then nb:SetFrameLevel(parent:GetFrameLevel() + 2) end
    nb.icon = nb:CreateTexture(nil, "ARTWORK")
    nb.icon:SetAllPoints(nb)
    nb.icon:SetTexture(self.naviTexture)
    nb.icon:SetVertexColor(NAVI_COLOR[1], NAVI_COLOR[2], NAVI_COLOR[3])
    nb.tip = tip
    nb:SetScript("OnClick", function(btn)
        if ONE.Sound and ONE.Sound.Play then ONE.Sound:Play("seal") end
        if callback then callback(btn) end
    end)
    -- abgeschaltet (kein Ziel bekannt) = grau, Tooltip erklaert weiter, warum
    nb:SetScript("OnEnable", function(btn) NaviTint(btn) end)
    nb:SetScript("OnDisable", function(btn) NaviTint(btn) end)
    nb:SetScript("OnEnter", function(btn)
        NaviTint(btn, true)
        if not GameTooltip then return end
        local title, sub = btn.tip, nil
        if type(title) == "function" then title, sub = title(btn) end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or (ONE.T and ONE.T("Navi starten") or "Navi starten"), 1, 1, 1, 1, true) -- (Text, r, g, b, alpha, umbrechen)
        if sub then GameTooltip:AddLine(sub, .8, .8, .8, true) end
        GameTooltip:Show()
    end)
    if nb.SetMotionScriptsWhileDisabled then nb:SetMotionScriptsWhileDisabled(true) end
    nb:SetScript("OnLeave", function(btn)
        NaviTint(btn)
        if GameTooltip then GameTooltip:Hide() end
    end)
    return nb
end
