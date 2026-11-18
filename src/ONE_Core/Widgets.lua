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
    if label.GetText and (label:GetText() or "") == "" then label:SetText(ONE.T and ONE.T(text or "") or text or "") end
    return label
end

-- Aussehen "Nachtroute" (0.8): eigene, flache Knoepfe mit runden Ecken.
-- Sichtbar hoechstens 26 px hoch; ist die vorgesehene Flaeche hoeher, steht der
-- Knopf mittig darin (die Klickflaeche bleibt so gross wie vorgesehen).
-- style: "primary" (Akzent), "secondary"/"tab"/"nav" (Flaeche), "ghost" (nur Rand),
-- "danger" (roter Rand, Hilferuf).
Widgets.maxButtonHeight = 26
local function Skin() return ONE.Skin end

local function PaintButton(b)
    local S, st = Skin(), b.__oneState
    if not (S and b.__oneSurface) then return end
    local p = S:Palette()
    local style = b.__oneVariant
    local on = not (b.IsEnabled and not b:IsEnabled())
    local fill, lift, alpha, text = "ctl", 0, 1, p.ctlText
    if style == "primary" then fill, text = "primary", p.primaryText
    elseif style == "ghost" or style == "danger" then fill, alpha = "ctl", (st.hover and on) and .6 or 0 end
    if st.hover and on and alpha > 0 then lift = .08 end
    if st.down and on then lift = -.06 end
    local s = b.__oneSurface
    s.opts.fill, s.opts.alpha, s.opts.lift = fill, on and alpha or alpha * .5, lift
    s.opts.borderRole = (st.locked and "accent") or (style == "danger" and "bad") or nil
    s.opts.borderAlways = st.locked
    S:Paint(s)
    if st.locked and style ~= "primary" then text = p.accent end
    if style == "danger" then text = p.bad end
    if not on then text = p.muted end
    if b.__oneLabel then b.__oneLabel:SetTextColor(text[1], text[2], text[3]) end
    if b.__oneGlyph then b.__oneGlyph:SetVertexColor(text[1], text[2], text[3]) end
end
Widgets.PaintButton = PaintButton

local function SkinButton(parent, text, width, height, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local vh = math.min(height, Widgets.maxButtonHeight)
    b.__oneVariant = style or "secondary"
    b.__oneState = {}
    local box = b.CreateTexture and b:CreateTexture(nil, "BACKGROUND", nil, -8)
    if box then
        box:SetPoint("LEFT", b, "LEFT", 0, 0)
        box:SetPoint("RIGHT", b, "RIGHT", 0, 0)
        box:SetHeight(vh)
        box:SetColorTexture(0, 0, 0, 0)
    end
    local outline = style == "ghost" or style == "danger"
    b.__oneSurface = box and Skin() and Skin():Surface(b, {fill = "ctl", radius = 4, anchor = box, outline = outline,
        shadow = (not outline) and "button" or nil, sheenHeight = vh, sheenAlpha = .1})
    local label = CreateLabel(b, text, "CENTER", 10, 10)
    if ONE.Kit and ONE.Kit.Font then
        local font = ONE.Kit:Font("button")
        if font and label.SetFontObject then label:SetFontObject(font) end
    end
    b.__oneLabel = label
    if b.HookScript and b.__oneSurface then
        b:HookScript("OnEnter", function(self) self.__oneState.hover = true PaintButton(self) end)
        b:HookScript("OnLeave", function(self) self.__oneState.hover, self.__oneState.down = nil, nil PaintButton(self) end)
        b:HookScript("OnMouseDown", function(self) self.__oneState.down = true PaintButton(self) end)
        b:HookScript("OnMouseUp", function(self) self.__oneState.down = nil PaintButton(self) end)
        b:HookScript("OnEnable", PaintButton)
        b:HookScript("OnDisable", PaintButton)
    end
    -- Umschalter: ausgewaehlt = Akzentrand und Akzentschrift
    function b:LockHighlight() self.__oneState.locked = true PaintButton(self) end
    function b:UnlockHighlight() self.__oneState.locked = nil PaintButton(self) end
    function b:AlignLeft() label:SetJustifyH("LEFT") end
    if Skin() then Skin():OnChange(function() PaintButton(b) end) end
    PaintButton(b)
    return b
end
Widgets.SkinButton = SkinButton

function Widgets:Button(parent, text, width, height, point, x, y, callback, style)
    assert(parent and width and height, "ONE Button: Elternframe oder Maße fehlen")
    local button = SkinButton(parent, text, width, height, style)
    button:SetPoint(point or "TOPLEFT", parent, point or "TOPLEFT", x or 0, y or 0)
    button.__oneStyle = true
    button.__oneNative = false
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

-- Schliessen: kleines rundes Kreuz, hell beim Darueberfahren.
function Widgets:CloseButton(parent, point, x, y, callback)
    local close = CreateFrame("Button", nil, parent)
    close:SetSize(24, 24)
    close:SetPoint(point or "TOPLEFT", parent, point or "TOPLEFT", x or 0, y or 0)
    local S = ONE.Skin
    close.__oneSurface = S and S:Surface(close, {fill = "ctl", radius = 12, border = false, sheen = false, alpha = 0})
    local glyph = close:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture("Interface\\AddOns\\ONE_Core\\Textures\\Common\\CloseGlyph.tga")
    glyph:SetSize(11, 11)
    glyph:SetPoint("CENTER", close, "CENTER", 0, 0)
    close.__oneGlyph = glyph
    local function Paint(hover)
        if not S then return end
        local r, g, b = S:Color(hover and "text" or "soft")
        glyph:SetVertexColor(r, g, b)
        if close.__oneSurface then S:Refill(close.__oneSurface, "ctl", hover and 1 or 0) end
    end
    close:SetScript("OnEnter", function() Paint(true) end)
    close:SetScript("OnLeave", function() Paint(false) end)
    if S then S:OnChange(function() Paint(false) end) end
    Paint(false)
    if callback then close:SetScript("OnClick", callback)
    else close:SetScript("OnClick", function() parent:Hide() end) end
    return close
end

-- ===== Spiel-Symbol (Gegenstand, Zauber, Rezept) =====
-- Echte Symbole aus dem Client, im Aussehen "Nachtroute": abgerundet (Maske, sonst
-- Blizzard-Rand abgeschnitten), feiner Ring in Qualitaetsfarbe, kleine Anzahl-Plakette
-- unten rechts, weiches Leuchten in Akzentfarbe, wenn ausgewaehlt.
-- icon = Widgets:Icon(parent, size); icon:SetItem(itemID) / :SetSpell(id) / :SetIcon(tex)
-- icon:SetQuality(q) icon:SetCount(n) icon:SetSelected(on) icon:SetMissing(on)
local QUALITY = {[0] = {.62, .62, .62}, {1, 1, 1}, {.12, 1, 0}, {0, .44, .87}, {.64, .21, .93}, {1, .5, 0}}
Widgets.QUALITY = QUALITY
local Icon = {}
Icon.__index = Icon
-- Macht aus einer Symbol-Textur ein abgerundetes Symbol mit feinem Ring.
-- Runde Ecken per Maske (wenn der Client Masken kann), sonst nur Blizzard-Rand abschneiden.
-- -> ring (Neun-Teile, :SetColor), masked
function Widgets.RoundIcon(frame, tex)
    local S = ONE.Skin
    local masked = false
    if S and frame.CreateMaskTexture and tex.AddMaskTexture then
        local ok, mask = pcall(frame.CreateMaskTexture, frame)
        if ok and mask then
            pcall(mask.SetTexture, mask, S.tex.round, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(tex)
            masked = pcall(tex.AddMaskTexture, tex, mask)
        end
    end
    if tex.SetTexCoord then tex:SetTexCoord(.08, .92, .08, .92) end
    local ring = S and S:Nine(frame, S.tex.ring, .25, "OVERLAY", 1):Place(4, 1, tex)
    if ring then ring:SetColor(1, 1, 1, .18) end
    return ring, masked
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end
function Widgets:Icon(parent, size)
    local S = ONE.Skin
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local o = setmetatable({frame = f, size = size}, Icon)
    o.glow = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    o.glow:SetTexture(S and S.tex.glow or nil)
    o.glow:SetPoint("CENTER", f, "CENTER")
    o.glow:SetSize(size * 2.2, size * 2.2)
    o.glow:Hide()
    o.tex = f:CreateTexture(nil, "ARTWORK")
    o.tex:SetAllPoints(f)
    o.ring, o.masked = Widgets.RoundIcon(f, o.tex)
    o.badge = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    o.badge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -1)
    if ONE.Kit then ONE.Kit:Upgrade(o.badge, "small") end
    if o.badge.SetShadowOffset then o.badge:SetShadowOffset(1, -1) end
    o:SetQuality(nil)
    return o
end
function Icon:SetIcon(tex)
    self.tex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    return self
end
function Icon:SetItem(itemID)
    local tex = itemID and itemID > 0 and C_Item and Call(C_Item.GetItemIconByID, itemID)
    if not tex and type(GetItemIcon) == "function" and itemID then tex = Call(GetItemIcon, itemID) end
    local q = itemID and itemID > 0 and C_Item and Call(C_Item.GetItemQualityByID, itemID)
    self:SetIcon(tex)
    self:SetQuality(q)
    return tex ~= nil
end
function Icon:SetSpell(spellID)
    local tex = spellID and ((C_Spell and Call(C_Spell.GetSpellTexture, spellID)) or Call(GetSpellTexture, spellID))
    self:SetIcon(tex)
    self:SetQuality(nil)
    return tex ~= nil
end
function Icon:SetQuality(q)
    self.quality = q
    if not self.ring then return self end
    local c = QUALITY[q or -1]
    if c then self.ring:SetColor(c[1], c[2], c[3], .9)
    else self.ring:SetColor(1, 1, 1, .18) end
    return self
end
function Icon:SetCount(n)
    self.badge:SetText((n and n > 1) and tostring(n) or (n == 1 and "1") or "")
    return self
end
function Icon:SetSelected(on)
    if on and ONE.Skin then
        local r, g, b = ONE.Skin:Color("accent")
        self.glow:SetVertexColor(r, g, b, .5)
        self.glow:Show()
        if self.ring then self.ring:SetColor(r, g, b, 1) end
    else
        self.glow:Hide()
        self:SetQuality(self.quality)
    end
    return self
end
function Icon:SetMissing(on)
    if self.tex.SetDesaturated then self.tex:SetDesaturated(on and true or false) end
    self.tex:SetAlpha(on and .5 or 1)
    return self
end
function Icon:SetPoint(...) self.frame:SetPoint(...) return self end
function Icon:ClearAllPoints() self.frame:ClearAllPoints() return self end
function Icon:Show() self.frame:Show() end
function Icon:Hide() self.frame:Hide() end

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
