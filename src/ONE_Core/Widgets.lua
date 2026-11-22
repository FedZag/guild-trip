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
    if ONE.Fit then ONE.Fit:Line(label, button) end
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
    -- Glas-Look: eigene Pille statt roter Blizzard-Vorlage
    local glass = ONE.Glass and ONE.Glass:Active()
    local button = (not glass) and NativeButton(parent) or nil
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
    if glass then ONE.Glass:StyleButton(button, style) end
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
    if ONE.Glass and ONE.Glass:Active() then
        return self:IconButton(parent, "Interface\\AddOns\\ONE_Core\\Textures\\Common\\CloseGlyph.tga",
            26, point or "TOPLEFT", x or 0, y or 0, callback, "secondary", 11)
    end
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

-- An allen Kanten und Ecken groesser/kleiner ziehen (wie ein normales Fenster; Nutzer 18.11.2026).
-- Unsichtbare, schmale Griffe ueber den Raendern. opts = {size = Randbreite, onStart(), onStop(), onEnter(), onLeave()}
-- Der Rahmen braucht SetResizable(true) und Grenzen (SetResizeBounds). Rueckgabe: Liste der Griffe.
Widgets.RESIZE_SIDES = {
    {"TOPLEFT", "TOPLEFT", "TOPLEFT", 0, 0, true, true}, {"TOPRIGHT", "TOPRIGHT", "TOPRIGHT", 0, 0, true, true},
    {"BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, true, true}, {"BOTTOMRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, true, true},
    {"TOP", "TOPLEFT", "TOPRIGHT", 0, 0, false, true}, {"BOTTOM", "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, false, true},
    {"LEFT", "TOPLEFT", "BOTTOMLEFT", 0, 0, true, false}, {"RIGHT", "TOPRIGHT", "BOTTOMRIGHT", 0, 0, true, false},
}
-- Rueckmeldung beim Ueberfahren eines Griffs: Mauszeiger "Groesse aendern" (falls der Client ihn kennt)
-- und eine golden aufleuchtende Kante/Ecke (eigenes Zeichen, klappt immer). Nutzer 18.11.2026.
-- Eigene (kleine) Zeiger zeigt dieser Client nur als schwarzes Viereck (TGA und BLP getestet,
-- Spieltest 18.11.2026) – darum nur WoW-eigene Zeiger.
Widgets.RESIZE_CURSORS = {"UI_RESIZE_CURSOR", "Interface\\CURSOR\\UI-Cursor-SizeRight", "Interface\\CURSOR\\UI-Cursor-Move"}
function Widgets.ResizeCursor(on, side)
    if not on then
        if type(ResetCursor) == "function" then pcall(ResetCursor) end
        return
    end
    if type(SetCursor) ~= "function" then return end
    for _, c in ipairs(Widgets.RESIZE_CURSORS) do
        local ok, res = pcall(SetCursor, c)
        if ok and res ~= false then return c end
    end
end
local function Highlight(h, corner)
    if not h.CreateTexture then return end
    local t = h:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(h)
    t:SetColorTexture(1, .82, 0, corner and .55 or .45)
    t:Hide()
    h.glow = t
end
local function HoverOn(self) if self.glow then self.glow:Show() end Widgets.ResizeCursor(true, self.__oneSide) end
local function HoverOff(self) if self.glow then self.glow:Hide() end Widgets.ResizeCursor(false) end

function Widgets:ResizeHandles(frame, opts)
    opts = opts or {}
    local size = opts.size or 6
    local handles = {}
    for _, d in ipairs(Widgets.RESIZE_SIDES) do
        local side, a, b, corner = d[1], d[2], d[3], d[6] and d[7]
        local h = CreateFrame("Button", nil, frame)
        if h.SetFrameLevel then h:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + (corner and 12 or 10)) end
        if corner then
            h:SetSize(size * 2, size * 2)
            h:SetPoint(side, frame, side, 0, 0)
        else
            -- Kante: zwischen den Ecken, so breit wie der Rand
            local horizontal = side == "TOP" or side == "BOTTOM"
            h:SetPoint(a, frame, a, horizontal and size * 2 or 0, horizontal and 0 or -size * 2)
            h:SetPoint(b, frame, b, horizontal and -size * 2 or 0, horizontal and 0 or size * 2)
            if horizontal then h:SetHeight(size) else h:SetWidth(size) end
        end
        h.side = side
        h:SetScript("OnMouseDown", function(self, button)
            if button and button ~= "LeftButton" then return end
            if opts.onStart then opts.onStart(self.side) end
            frame:StartSizing(self.side)
        end)
        h:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            if opts.onStop then opts.onStop() end
        end)
        h.__oneSide = side
        Highlight(h, corner)
        h:SetScript("OnEnter", function(self) HoverOn(self) if opts.onEnter then opts.onEnter(self) end end)
        h:SetScript("OnLeave", function(self) HoverOff(self) if opts.onLeave then opts.onLeave(self) end end)
        handles[#handles + 1] = h
    end
    return handles
end

-- ===== Vergroessern durch Ziehen (Fenster mit fester Aufteilung: alles waechst mit, auch die Schrift) =====
-- An jeder Kante/Ecke ziehen: die gegenueberliegende Seite bleibt stehen, der Massstab folgt der Maus.
-- Gemerkt je Fenster in ONE.db.frameScales[key]. opts = {min, max, onStop(scale)}
local function Cursor()
    if not GetCursorPosition then return nil end
    local x, y = GetCursorPosition()
    local s = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not (x and y and s and s > 0) then return nil end
    return x / s, y / s
end
function Widgets:ScaleHandles(frame, key, opts)
    opts = opts or {}
    local minS, maxS = opts.min or .6, opts.max or 2
    local store = ONE.db and ONE.db.frameScales
    if ONE.db and not store then ONE.db.frameScales = {} store = ONE.db.frameScales end
    local saved = store and key and store[key]
    if type(saved) == "number" and not opts.noRestore then frame:SetScale(math.max(minS, math.min(maxS, saved))) end
    local drag
    local updater = CreateFrame("Frame", nil, frame)
    updater:Hide()
    updater:SetScript("OnUpdate", function()
        if not drag then updater:Hide() return end
        local mx, my = Cursor()
        if not mx then return end
        local sx, sy
        if drag.fx then sx = math.abs(mx - drag.fx) / drag.w end
        if drag.fy then sy = math.abs(my - drag.fy) / drag.h end
        local s = (sx and sy) and math.max(sx, sy) or sx or sy or drag.s
        s = math.max(minS, math.min(maxS, s))
        frame:SetScale(s)
        frame:ClearAllPoints()
        local px = drag.fx and drag.fx or drag.cx
        local py = drag.fy and drag.fy or drag.cy
        frame:SetPoint(drag.anchor, UIParent, "BOTTOMLEFT", px / s, py / s)
    end)
    local handles = {}
    for _, d in ipairs(Widgets.RESIZE_SIDES) do
        local side = d[1]
        local h = CreateFrame("Button", nil, frame)
        local corner = d[6] and d[7]
        local size = opts.size or 6
        if corner then
            h:SetSize(size * 2, size * 2)
            h:SetPoint(side, frame, side, 0, 0)
        else
            local horizontal = side == "TOP" or side == "BOTTOM"
            h:SetPoint(d[2], frame, d[2], horizontal and size * 2 or 0, horizontal and 0 or -size * 2)
            h:SetPoint(d[3], frame, d[3], horizontal and -size * 2 or 0, horizontal and 0 or size * 2)
            if horizontal then h:SetHeight(size) else h:SetWidth(size) end
        end
        h:SetScript("OnMouseDown", function(_, button)
            if button and button ~= "LeftButton" then return end
            if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
            local s = frame:GetScale() or 1
            local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
            if not (l and r and t and b) then return end
            l, r, t, b = l * s, r * s, t * s, b * s   -- in UIParent-Einheiten
            drag = {s = s, w = (r - l) / s, h = (t - b) / s, cx = (l + r) / 2, cy = (t + b) / 2}
            local horiz = side:find("LEFT") and "RIGHT" or side:find("RIGHT") and "LEFT" or nil
            local vert = side:find("TOP") and "BOTTOM" or side:find("BOTTOM") and "TOP" or nil
            if horiz == "LEFT" then drag.fx = l elseif horiz == "RIGHT" then drag.fx = r end
            if vert == "TOP" then drag.fy = t elseif vert == "BOTTOM" then drag.fy = b end
            drag.anchor = (vert or "") .. (horiz or "")
            if drag.anchor == "" then drag.anchor = "CENTER" end
            updater:Show()
        end)
        h:SetScript("OnMouseUp", function()
            if not drag then return end
            drag = nil
            updater:Hide()
            local s = frame:GetScale() or 1
            if store and key then store[key] = s end
            if opts.onStop then opts.onStop(s) end
        end)
        h.__oneSide = side
        Highlight(h, corner)
        h:SetScript("OnEnter", HoverOn)
        h:SetScript("OnLeave", HoverOff)
        handles[#handles + 1] = h
    end
    -- Griffe immer ueber dem Inhalt (auch wenn das Fenster spaeter seine Ebene aendert)
    local function Raise()
        local lvl = frame.GetFrameLevel and frame:GetFrameLevel() or 0
        for i, h in ipairs(handles) do if h.SetFrameLevel then h:SetFrameLevel(lvl + (i <= 4 and 30 or 28)) end end
    end
    Raise()
    if frame.HookScript then frame:HookScript("OnShow", Raise) end
    frame.__oneScaleHandles, frame.__oneScaleUpdater = handles, updater
    return handles
end

-- Kleine Fenster (Buff-Erinnerung, Buffen, Hinweise ...) bleiben fest (Nutzer 18.11.2026:
-- frei ziehbar nur Hauptfenster, Chat und Quest-Fuehrung). Liste bleibt fuer spaetere Wuensche.
Widgets.SCALABLE = {}
function Widgets:AttachScaling()
    for _, e in ipairs(Widgets.SCALABLE) do
        local f = rawget(_G, e[1])
        if type(f) == "table" and f.GetObjectType and not f.__oneScaleHandles then
            pcall(Widgets.ScaleHandles, Widgets, f, e[2])
        end
    end
end
function Widgets:StartAutoScaling()
    if self.autoScaling or not CreateFrame then return end
    self.autoScaling = true
    local w = CreateFrame("Frame")
    local acc = 0
    w:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < 2 then return end
        acc = 0
        Widgets:AttachScaling()
    end)
end
