-- Project ONE Kit: gemeinsame Gestaltungsgrundlage aller Module.
-- Teil 1: Schriftstufen. Statt verstreuter Blizzard-Schriften (10-12 pt) nutzt
-- ONE eigene, groessere Schriftobjekte mit Schatten. Eine Aenderung der
-- Schriftgroesse wirkt sofort auf alle Texte, weil WoW Schriftobjekte teilt.
local _, ONE = ...
local function Paint(tex, r, g, b, a) if ONE.Book and ONE.Book.Paint then return ONE.Book.Paint(tex, r, g, b, a) end tex:SetColorTexture(r, g, b, a) end
local Kit = {fonts = {}}
ONE.Kit = Kit

-- Stufen in Punkt bei 100 %. Blizzard-Standard zum Vergleich: Small 10, Normal 12.
Kit.levels = {
    title   = {size = 20, outline = "", weight = "bold"},
    heading = {size = 15, outline = "", weight = "bold"},
    body    = {size = 13, outline = ""},
    label   = {size = 12, outline = ""},
    small   = {size = 11.5, outline = ""},
    button  = {size = 12, outline = "", weight = "bold"},
}
-- Schrift des Aussehens "Nachtroute": Inter (SIL OFL, scripts/build_fonts.py)
Kit.fontFiles = {
    regular = "Interface\\AddOns\\ONE_Core\\Fonts\\Inter-Regular.ttf",
    bold = "Interface\\AddOns\\ONE_Core\\Fonts\\Inter-SemiBold.ttf",
}
Kit.scales = {.9, 1, 1.1, 1.25}

-- Welche Blizzard-Schrift wird durch welche ONE-Stufe ersetzt.
Kit.map = {
    GameFontNormalHuge = "title", GameFontHighlightHuge = "title",
    GameFontNormalLarge = "heading", GameFontHighlightLarge = "heading",
    GameFontNormal = "body", GameFontHighlight = "body", GameFontDisable = "body",
    GameFontNormalSmall = "label", GameFontHighlightSmall = "small",
    GameFontDisableSmall = "small",
}

local function Settings()
    if not ONE.db then return {} end
    ONE.db.kit = type(ONE.db.kit) == "table" and ONE.db.kit or {}
    local s = ONE.db.kit
    if type(s.fontScale) ~= "number" then s.fontScale = 1 end
    if s.contrast ~= "high" then s.contrast = "normal" end
    return s
end
Kit.Settings = Settings

local function BaseFontFile()
    local reference = _G.GameFontNormal
    if reference and reference.GetFont then
        local ok, file = pcall(reference.GetFont, reference)
        if ok and type(file) == "string" and file ~= "" then return file end
    end
    return "Fonts\\FRIZQT__.TTF"
end

function Kit:Font(level)
    if self.fonts[level] then return self.fonts[level] end
    if type(CreateFont) ~= "function" or not self.levels[level] then return nil end
    local font = CreateFont("ONEFont_" .. level)
    self.fonts[level] = font
    self:ApplyFont(level)
    return font
end

function Kit:ApplyFont(level)
    local font, def = self.fonts[level], self.levels[level]
    if not (font and def and font.SetFont) then return end
    local size = def.size * Settings().fontScale
    local file = Kit.fontFiles[def.weight == "bold" and "bold" or "regular"]
    if font:SetFont(file, size, def.outline) == false then font:SetFont(BaseFontFile(), size, def.outline) end
    if font.SetShadowOffset then font:SetShadowOffset(0, -1) end
    if font.SetShadowColor then font:SetShadowColor(0, 0, 0, .6) end
    -- Grundfarbe Weiss, voll deckend: frisch angelegte Schriftobjekte haben sonst eine
    -- dunkle Grundfarbe, auf die Texte beim Auffrischen zurueckfallen (Blizzard-Aussehen
    -- war dadurch kaum lesbar). Die Rollenfarben setzt Themes:ApplyAll danach neu.
    if font.SetTextColor then font:SetTextColor(1, 1, 1, 1) end
    if font.SetAlpha then font:SetAlpha(1) end
end

function Kit:ApplyAllFonts()
    for level in pairs(self.fonts) do self:ApplyFont(level) end
    if ONE.Themes and ONE.Themes.ApplyAll then ONE.Themes:ApplyAll() end
end

-- Ersetzt die Blizzard-Schrift eines FontStrings durch die passende ONE-Stufe.
function Kit:Upgrade(fontString, level)
    if not (fontString and fontString.SetFontObject) then return end
    if not level and fontString.GetFontObject then
        local ok, object = pcall(fontString.GetFontObject, fontString)
        local name = ok and object and object.GetName and object:GetName()
        level = name and self.map[name]
    end
    local font = level and self:Font(level)
    if font then
        fontString:SetFontObject(font)
        fontString.__oneKitLevel = level
    end
end

function Kit:SetFontScale(scale)
    local s = Settings()
    s.fontScale = scale
    self:ApplyAllFonts()
    if ONE.UI and ONE.UI.Refresh then ONE.UI:Refresh() end
end

-- Naechste Stufe im Kreis (90 -> 100 -> 110 -> 125 -> 90 %).
function Kit:CycleFontScale()
    local current, nextScale = Settings().fontScale, self.scales[1]
    for i, scale in ipairs(self.scales) do
        if math.abs(scale - current) < .01 then
            nextScale = self.scales[i % #self.scales + 1]
            break
        end
    end
    self:SetFontScale(nextScale)
    return nextScale
end

function Kit:IsHighContrast() return Settings().contrast == "high" end

function Kit:ToggleContrast()
    local s = Settings()
    s.contrast = s.contrast == "high" and "normal" or "high"
    if ONE.Themes then ONE.Themes:ApplyAll() end
    if ONE.UI and ONE.UI.Refresh then ONE.UI:Refresh() end
    return s.contrast
end

-- Textfarben mit Kontrast-Modus: Nebentext wird fast so hell wie Fliesstext.
function Kit:TextColor(palette, role)
    local c = palette[role] or palette.text
    -- auf Pergament (Aussehen "Altes Buch") nie weisse Schrift
    if self:IsHighContrast() and palette.skin ~= "book" then
        if role == "soft" then return palette.text end
        if role == "text" then return {1, 1, 1} end
    end
    return c
end

-- Teil 2: Kacheln fuer die Startseite. Jedes Modul darf eine Kachel
-- beisteuern; fehlt das Modul, fehlt einfach seine Kachel.
-- def = {title="TITEL", order=10, build=function(card, body) return refresh end}
Kit.tiles, Kit.tileOrder, Kit.tilesVersion = {}, {}, 0
function Kit:RegisterTile(id, def)
    if type(id) ~= "string" or type(def) ~= "table" or type(def.build) ~= "function"
        or self.tiles[id] then return false end
    def.id, def.order = id, type(def.order) == "number" and def.order or 50
    self.tiles[id] = def
    self.tileOrder[#self.tileOrder + 1] = def
    table.sort(self.tileOrder, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    self.tilesVersion = self.tilesVersion + 1
    return true
end
function Kit:Tiles() return self.tileOrder end

-- Teil 3: Stapel. Elemente werden untereinander angeordnet; jedes Element
-- bekommt seinen Platz aus der Schriftstufe statt aus festen Pixelwerten.
local Stack = {}
Stack.__index = Stack
function Kit:Stack(parent, x, y, width, gap)
    return setmetatable({parent = parent, x = x, y = y, width = width, gap = gap or 6, cursor = 0}, Stack)
end
function Stack:LineHeight(level)
    local def = Kit.levels[level or "body"] or Kit.levels.body
    return math.ceil(def.size * 1.3 * Settings().fontScale)
end
function Stack:Text(text, level, role, lines)
    local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x, self.y - self.cursor)
    fs:SetWidth(self.width)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap((lines or 1) > 1) end
    fs:SetText(ONE.T and ONE.T(text or "") or text or "")
    if ONE.Themes then ONE.Themes:RegisterText(fs, role or "text") end
    Kit:Upgrade(fs, level or "body")
    self.cursor = self.cursor + self:LineHeight(level) * (lines or 1) + self.gap
    return fs
end
function Stack:Space(height) self.cursor = self.cursor + height end
function Stack:Height() return self.cursor end

-- Teil 4: Liste mit Scrollleiste und Spaltenkoepfen (statt Blaetter-Knoepfen).
-- Nur so viele Zeilen wie sichtbar werden gebaut; beim Scrollen werden sie
-- neu befuellt. Die Scrollleiste ist Blizzards UIPanelScrollFrameTemplate.
-- opts = {x, y, width, height, rowHeight, columns={{key,title,width,align}},
--         render=function(row, item, cells), onSort=function(key, ascending),
--         onEnter=function(row, item), onClick=function(row, item, button)}
local List = {}
List.__index = List
local HEADER, SCROLLBAR = 20, 24

local function CreateScroll(box)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    if not ok or not scroll then scroll = CreateFrame("ScrollFrame", nil, box) end
    Kit.StyleScroll(scroll)
    return scroll
end

-- Blizzard-Scrollleiste im Aussehen "Nachtroute": ohne Pfeile und Rinne, nur ein
-- schmaler, runder Schieber (heller beim Darueberfahren).
function Kit.StyleScroll(scroll)
    local bar = scroll and (scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"]))
    if type(bar) ~= "table" or bar.__oneStyled then return end
    bar.__oneStyled = true
    for _, key in ipairs({"ScrollUpButton", "ScrollDownButton"}) do
        local b = bar[key] or (bar.GetName and bar:GetName() and _G[bar:GetName() .. key:gsub("Scroll", "")])
        if type(b) == "table" and b.SetAlpha then b:SetAlpha(0) if b.EnableMouse then b:EnableMouse(false) end end
    end
    if bar.GetRegions then
        for _, r in ipairs({bar:GetRegions()}) do
            if r and r.SetAlpha and r ~= (bar.GetThumbTexture and bar:GetThumbTexture()) then r:SetAlpha(0) end
        end
    end
    local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
    if thumb and ONE.Skin then
        thumb:SetTexture(ONE.Skin.tex.round)
        if thumb.SetTexCoord then thumb:SetTexCoord(.25, .75, .25, .75) end
        thumb:SetSize(5, 36)
        thumb:SetVertexColor(1, 1, 1, .2)
        if bar.HookScript then
            bar:HookScript("OnEnter", function() thumb:SetVertexColor(1, 1, 1, .35) end)
            bar:HookScript("OnLeave", function() thumb:SetVertexColor(1, 1, 1, .2) end)
        end
    end
end

function Kit:List(parent, opts)
    -- Buch: Texte brechen zweizeilig um statt abgeschnitten zu werden ("alles vollstaendig lesbar")
    local book = ONE.Book and ONE.Book.IsActive and ONE.Book:IsActive()
    local list = setmetatable({opts = opts, items = {}, rows = {}, rowHeight = book and math.max(opts.rowHeight or 22, 32) or opts.rowHeight or 22}, List)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 0, opts.y or 0)
    box:SetSize(opts.width, opts.height)
    list.box = box
    local usable = opts.width - SCROLLBAR
    -- Spaltenkoepfe (anklickbar zum Sortieren)
    local x = 6
    list.headers = {}
    for _, col in ipairs(opts.columns) do
        local head = CreateFrame("Button", nil, box)
        head:SetPoint("TOPLEFT", box, "TOPLEFT", x, 0)
        head:SetSize(col.width, HEADER)
        local label = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints(head)
        label:SetJustifyH(col.align or "LEFT")
        label:SetText(ONE.T and ONE.T(col.title or "") or col.title or "")
        if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(label, "muted") end
        Kit:Upgrade(label, "small")
        head:SetScript("OnClick", function()
            if not opts.onSort then return end
            if list.sortKey == col.key then list.ascending = not list.ascending
            else list.sortKey, list.ascending = col.key, true end
            opts.onSort(list.sortKey, list.ascending)
        end)
        list.headers[col.key] = label
        col.x = x
        x = x + col.width + 8
    end
    local rule = box:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -HEADER)
    rule:SetSize(usable, 1)
    Paint(rule, 1, 1, 1, .08)
    -- Scrollbereich: das Kind ist nur so hoch wie alle Zeilen zusammen.
    local scroll = CreateScroll(box)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -HEADER - 2)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -SCROLLBAR, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(usable, 1)
    if scroll.SetScrollChild then scroll:SetScrollChild(child) end
    list.scroll, list.child = scroll, child
    if scroll.HookScript then
        scroll:HookScript("OnVerticalScroll", function() list:Update() end)
    end
    -- Sichtbare Zeilen liegen ueber dem Scrollbereich und werden neu befuellt.
    local visible = math.floor((opts.height - HEADER - 2) / list.rowHeight)
    for i = 1, visible do
        local row = CreateFrame("Button", nil, box)
        row:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -HEADER - 2 - (i - 1) * list.rowHeight)
        row:SetSize(usable, list.rowHeight)
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints(row)
        Paint(stripe, 1, 1, 1, i % 2 == 0 and .025 or 0)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(1, 1, 1, .06)
        if row.EnableMouseWheel then
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta) list:ScrollBy(-delta * 3) end)
        end
        row.cells = {}
        for _, col in ipairs(opts.columns) do
            local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            Kit:Upgrade(cell, "label")
            cell:SetPoint("LEFT", row, "LEFT", col.x + (col.indent or 0), 0)
            cell:SetWidth(col.width - (col.indent or 0))
            cell:SetJustifyH(col.align or "LEFT")
            if book and (col.width or 0) >= 60 then
                if cell.SetWordWrap then cell:SetWordWrap(true) end
                if cell.SetMaxLines then cell:SetMaxLines(2) end
            elseif cell.SetWordWrap then cell:SetWordWrap(false) end
            row.cells[col.key] = cell
        end
        if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        row:SetScript("OnClick", function(self, button)
            if opts.onClick and self.item then opts.onClick(self, self.item, button) end
        end)
        row:SetScript("OnEnter", function(self)
            if opts.onEnter and self.item then opts.onEnter(self, self.item) end
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        list.rows[i] = row
    end
    return list
end

-- Blizzard-Scrollleiste (UIPanelScrollFrameTemplate) nur zeigen, wenn es etwas zu scrollen gibt.
function Kit.ShowScrollBar(scroll, needed)
    local bar = scroll and (scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"]))
    if type(bar) ~= "table" or type(bar.Show) ~= "function" then return end
    if needed then bar:Show() else bar:Hide() end
end

function List:Offset()
    local scroll = self.scroll
    local pos = scroll.GetVerticalScroll and scroll:GetVerticalScroll() or 0
    return math.max(0, math.floor((pos or 0) / self.rowHeight + .5))
end

function List:MaxOffset() return math.max(0, #self.items - #self.rows) end

function List:ScrollBy(rows)
    local target = math.max(0, math.min(self:MaxOffset(), self:Offset() + rows))
    if self.scroll.SetVerticalScroll then self.scroll:SetVerticalScroll(target * self.rowHeight) end
    self:Update()
end

function List:SetItems(items)
    self.items = items or {}
    self.child:SetHeight(math.max(1, #self.items * self.rowHeight))
    -- opts.noScrollBar: Liste scrollt nur per Mausrad/gekoppelt (z. B. linke Buchseite)
    Kit.ShowScrollBar(self.scroll, not self.opts.noScrollBar and #self.items > #self.rows)
    if self:Offset() > self:MaxOffset() and self.scroll.SetVerticalScroll then
        self.scroll:SetVerticalScroll(self:MaxOffset() * self.rowHeight)
    end
    self:Update()
end

function List:Update()
    local offset = math.min(self:Offset(), self:MaxOffset())
    for i, row in ipairs(self.rows) do
        local item = self.items[offset + i]
        row.item = item
        if item then
            self.opts.render(row, item, row.cells)
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ===== Auswahl-Baustein: Blizzard-Dropdown =====
-- opts = {point="TOPRIGHT", x=0, y=-2, width=170,
--         options=function() return {{value=..., text=...}, ...} end,
--         get=function() return value end, set=function(value) end, tooltip="..."}
-- Reihenfolge: modernes Blizzard-Menue (WowStyle1DropdownTemplate) -> altes UIDropDownMenu
-- -> einfacher Knopf, der weiterschaltet. Ein Wert nil wird intern als "__all" gefuehrt.
local NIL = "__all"
local dropdownCount = 0
local function Wrap(v) if v == nil then return NIL end return v end
local function Unwrap(v) if v == NIL then return nil end return v end

function Kit:Dropdown(parent, opts)
    local dd = {opts = opts}
    -- Texte der Auswahl gehen durch die Uebersetzung (ONE.T)
    local function Options()
        local out = {}
        for i, o in ipairs(opts.options() or {}) do
            -- tooltip je Eintrag (z. B. Vor-/Nachteile eines Spielstils), nur beim Drueberfahren
            out[i] = {value = o.value, text = ONE.T and ONE.T(o.text) or o.text,
                tooltip = o.tooltip and (ONE.T and ONE.T(o.tooltip) or o.tooltip) or nil}
        end
        return out
    end
    local function CurrentText()
        local current = Wrap(opts.get())
        for _, o in ipairs(Options()) do if Wrap(o.value) == current then return o.text end end
        local first = Options()[1]
        return first and first.text or ""
    end
    -- Fuer alle Varianten gleich: Wert setzen und Seite neu zeichnen.
    function dd:Select(value)
        opts.set(Unwrap(value))
        if dd.Refresh then dd:Refresh() end
        if opts.onChange then opts.onChange(Unwrap(value)) elseif ONE.UI and ONE.UI.Refresh then ONE.UI:Refresh() end
    end
    function dd:Text() return CurrentText() end

    local width = opts.width or 170
    -- Aussehen "Nachtroute": eigenes Auswahlfeld (Knopf mit Pfeil) und eigenes Menue
    local own = ONE.Skin and ONE.Widgets and ONE.Widgets.SkinButton and UIParent
    local ok, frame
    if not own then ok, frame = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate") end
    if own then
        dd.kind = "own"
        frame = ONE.Widgets:Button(parent, "", width, 24, opts.point or "TOPLEFT", opts.x or 0, opts.y or 0, nil, "secondary")
        if frame.AlignLeft then frame:AlignLeft() end
        local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", frame, "RIGHT", -9, 0)
        arrow:SetText("▼")
        Kit:Upgrade(arrow, "small")
        if arrow.SetScale then arrow:SetScale(.7) end
        frame.__oneArrow = arrow
        frame:SetScript("OnClick", function(self)
            local list = {}
            for i, o in ipairs(Options()) do list[i] = {value = Wrap(o.value), text = o.text, tooltip = o.tooltip} end
            Kit:OpenMenu(self, list, Wrap(opts.get()), function(v) dd:Select(v) end)
        end)
        function dd:Refresh() frame:SetText(CurrentText()) end
    elseif ok and frame and type(frame.SetupMenu) == "function" and type(MenuUtil) == "table" then
        dd.kind = "menu"
        frame:SetPoint(opts.point or "TOPLEFT", parent, opts.point or "TOPLEFT", opts.x or 0, opts.y or 0)
        frame:SetWidth(width)
        frame:SetupMenu(function(_, root)
            for _, o in ipairs(Options()) do
                local value = Wrap(o.value)
                local item = root:CreateRadio(o.text, function(v) return Wrap(opts.get()) == v end,
                    function(v) dd:Select(v) end, value)
                if o.tooltip and item and type(item.SetTooltip) == "function" then
                    pcall(item.SetTooltip, item, function(tooltip)
                        if tooltip.SetText then tooltip:SetText(o.text, 1, .82, 0) end
                        if tooltip.AddLine then tooltip:AddLine(o.tooltip, 1, 1, 1, true) end
                    end)
                end
            end
        end)
        function dd:Refresh()
            if frame.GenerateMenu then pcall(frame.GenerateMenu, frame) end
            if frame.OverrideText then pcall(frame.OverrideText, frame, CurrentText()) end
        end
    elseif type(UIDropDownMenu_Initialize) == "function" then
        dd.kind = "legacy"
        dropdownCount = dropdownCount + 1
        frame = CreateFrame("Frame", "GuildTripDropdown" .. dropdownCount, parent, "UIDropDownMenuTemplate")
        -- Das alte Dropdown hat links/rechts unsichtbaren Rand (~16 px).
        local dx = (opts.point or "TOPLEFT"):find("RIGHT") and 16 or -16
        frame:SetPoint(opts.point or "TOPLEFT", parent, opts.point or "TOPLEFT", (opts.x or 0) + dx, (opts.y or 0) + 2)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(frame, width - 30) end
        UIDropDownMenu_Initialize(frame, function(_, level)
            for _, o in ipairs(Options()) do
                local info = UIDropDownMenu_CreateInfo()
                local value = Wrap(o.value)
                info.text = o.text
                info.checked = Wrap(opts.get()) == value
                info.func = function() dd:Select(value) end
                if o.tooltip then info.tooltipTitle, info.tooltipText, info.tooltipOnButton = o.text, o.tooltip, true end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        function dd:Refresh() if UIDropDownMenu_SetText then UIDropDownMenu_SetText(frame, CurrentText()) end end
    else
        dd.kind = "button"
        frame = ONE.Widgets:Button(parent, "", width, 24, opts.point or "TOPLEFT", opts.x or 0, opts.y or 0, function()
            local list, current, nextIndex = Options(), Wrap(opts.get()), 1
            for i, o in ipairs(list) do if Wrap(o.value) == current then nextIndex = i % #list + 1 end end
            if list[nextIndex] then dd:Select(Wrap(list[nextIndex].value)) end
        end)
        function dd:Refresh() frame:SetText(CurrentText()) end
    end
    if opts.tooltip and frame.SetScript and frame.HookScript then
        frame:HookScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(opts.tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        frame:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    dd.frame = frame
    frame.__oneDropdown = dd
    dd:Refresh()
    return dd
end

-- ===== Eingabefeld (Aussehen "Nachtroute") =====
-- Blizzard-Rahmen (Left/Middle/Right) ausblenden; dunkle, eingelassene Flaeche mit
-- feinem Rahmen, Akzentrahmen solange das Feld den Fokus hat. Suchlupe bleibt.
function Kit.StyleEdit(box)
    local S = ONE.Skin
    if not (box and S and box.CreateTexture) or box.__oneEdit then return box end
    box.__oneEdit = true
    for _, key in ipairs({"Left", "Middle", "Right", "Mid"}) do
        local t = box[key] or (box.GetName and box:GetName() and _G[box:GetName() .. key])
        if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
    end
    local frame = box:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame:SetPoint("TOPLEFT", box, "TOPLEFT", -5, 0)
    frame:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    frame:SetColorTexture(0, 0, 0, 0)
    local surface = S:Surface(box, {fill = "top", radius = 4, anchor = frame, border = false, sheen = false, outline = true})
    local function Paint(focus)
        surface.opts.borderRole = focus and "accent" or nil
        S:Paint(surface)
    end
    if box.HookScript then
        box:HookScript("OnEditFocusGained", function() Paint(true) end)
        box:HookScript("OnEditFocusLost", function() Paint(false) end)
    end
    local font = Kit:Font("label")
    if font and box.SetFontObject then box:SetFontObject(font) end
    if box.SetTextInsets then box:SetTextInsets(4, 4, 0, 0) end
    S:OnChange(function() Paint(box.HasFocus and box:HasFocus()) end)
    Paint(false)
    return box
end

-- ===== Auswahlmenue (Aussehen "Nachtroute") =====
-- Ein gemeinsames Menue fuer alle Auswahlfelder: runde Flaeche mit Schatten, je Eintrag
-- eine Zeile, aktueller Wert mit Akzentpunkt. Klick daneben oder Esc schliesst.
local MENU_ROW = 22
function Kit:OpenMenu(owner, list, current, onPick)
    local S = ONE.Skin
    local m = self.menu
    if not m then
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:SetScript("OnClick", function() Kit:CloseMenu() end)
        catcher:Hide()
        m = CreateFrame("Frame", "GuildTripMenu", UIParent)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        if m.SetFrameLevel and catcher.GetFrameLevel then m:SetFrameLevel(catcher:GetFrameLevel() + 5) end
        m:EnableMouse(true)
        S:Surface(m, {fill = "panel", radius = 6, shadow = "float", sheen = false, lift = .04})
        m.catcher, m.rows = catcher, {}
        m:Hide()
        if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripMenu") end
        m:SetScript("OnHide", function() catcher:Hide() end)
        self.menu = m
    end
    local width = math.max(owner.GetWidth and owner:GetWidth() or 160, 140)
    for i, it in ipairs(list) do
        local row = m.rows[i]
        if not row then
            row = CreateFrame("Button", nil, m)
            row:SetHeight(MENU_ROW)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetPoint("TOPLEFT", row, "TOPLEFT", 4, 0) hl:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
            hl:SetColorTexture(1, 1, 1, .07)
            local dot = row:CreateTexture(nil, "ARTWORK")
            dot:SetTexture(S.tex.dot) dot:SetSize(6, 6)
            dot:SetPoint("LEFT", row, "LEFT", 12, 0)
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", row, "LEFT", 24, 0) text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            text:SetJustifyH("LEFT")
            if text.SetWordWrap then text:SetWordWrap(false) end
            Kit:Upgrade(text, "label")
            row.dot, row.text = dot, text
            row:SetScript("OnEnter", function(self)
                if not (GameTooltip and self.tip) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.text:GetText() or "", 1, 1, 1)
                GameTooltip:AddLine(self.tip, .85, .85, .85, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            m.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", m, "TOPLEFT", 0, -6 - (i - 1) * MENU_ROW)
        row:SetWidth(width)
        row.text:SetText(it.text)
        row.tip = it.tooltip
        local sel = it.value == current
        local r, g, b = S:Color(sel and "text" or "soft")
        row.text:SetTextColor(r, g, b)
        local ar, ag, ab = S:Color("accent")
        row.dot:SetVertexColor(ar, ag, ab, sel and 1 or 0)
        row:SetScript("OnClick", function() Kit:CloseMenu() onPick(it.value) end)
        row:Show()
    end
    for i = #list + 1, #m.rows do m.rows[i]:Hide() end
    m:SetSize(width, #list * MENU_ROW + 12)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    m.catcher:Show()
    m:Show()
    return m
end
function Kit:CloseMenu() if self.menu then self.menu:Hide() end end

-- ===== Schiebeschalter (Aussehen "Nachtroute") =====
-- Macht aus einem CheckButton (mit oder ohne Blizzard-Vorlage) einen Schalter:
-- Spur 28x16 mit runden Enden, Knopf links (aus) oder rechts (an, Akzentfarbe).
function Kit:StyleCheck(box)
    if not box or box.__oneSwitch or not box.CreateTexture then return box end
    local S = ONE.Skin
    for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture"}) do
        local t = box[getter] and box[getter](box)
        if t and t.SetAlpha then t:SetAlpha(0) end
    end
    local track = box:CreateTexture(nil, "BACKGROUND", nil, -8)
    track:SetSize(28, 16)
    track:SetPoint("LEFT", box, "LEFT", 2, 0)
    track:SetColorTexture(0, 0, 0, 0)
    local surface = S and S:Surface(box, {fill = "ctl", radius = 8, anchor = track, border = false, sheen = false})
    local knob = box:CreateTexture(nil, "ARTWORK", nil, 2)
    knob:SetTexture(S and S.tex.dot or nil)
    knob:SetSize(12, 12)
    local function Paint()
        if not S then return end
        local on = box.GetChecked and box:GetChecked() and true or false
        local enabled = not (box.IsEnabled and not box:IsEnabled())
        if surface then
            surface.opts.fill = on and "accent" or "ctl"
            surface.opts.lift = on and 0 or .1
            surface.opts.alpha = enabled and 1 or .45
            S:Paint(surface)
        end
        local r, g, b = S:Color(on and "onAccent" or "soft")
        knob:SetVertexColor(r, g, b, enabled and 1 or .5)
        knob:ClearAllPoints()
        knob:SetPoint("CENTER", track, on and "RIGHT" or "LEFT", on and -8 or 8, 0)
    end
    box.__oneSwitch = Paint
    if hooksecurefunc then hooksecurefunc(box, "SetChecked", Paint)
    else
        local set = box.SetChecked
        if set then box.SetChecked = function(self, v) set(self, v) Paint() end end
    end
    if box.HookScript then
        box:HookScript("OnClick", Paint)
        box:HookScript("OnShow", Paint)
        box:HookScript("OnEnable", Paint)
        box:HookScript("OnDisable", Paint)
    end
    if S then S:OnChange(Paint) end
    Paint()
    return box
end

-- ===== An/Aus-Baustein: Schalter mit Beschriftung =====
-- opts = {point="TOPLEFT", x=0, y=0, label="...", tooltip="...", get=function() end, set=function(on) end}
function Kit:Check(parent, opts)
    local ok, box = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if not ok or not box then box = CreateFrame("CheckButton", nil, parent) end
    box:SetSize(32, 24)
    box:SetPoint(opts.point or "TOPLEFT", parent, opts.point or "TOPLEFT", opts.x or 0, opts.y or 0)
    self:StyleCheck(box)
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if (opts.point or "TOPLEFT"):find("RIGHT") then
        text:SetPoint("RIGHT", box, "LEFT", -4, 0)
        text:SetJustifyH("RIGHT")
    else
        text:SetPoint("LEFT", box, "RIGHT", 4, 0)
    end
    text:SetText(ONE.T and ONE.T(opts.label) or opts.label)
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(text, "text") end
    box.label = text
    box.__oneLabel = opts.label
    box:SetScript("OnClick", function(self)
        local on = self.GetChecked and self:GetChecked() and true or false
        if ONE.Sound then ONE.Sound:Play(on and "checkOn" or "checkOff") end
        opts.set(on)
        if opts.onChange then opts.onChange() elseif ONE.UI and ONE.UI.Refresh then ONE.UI:Refresh() end
    end)
    if opts.tooltip then
        box:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(ONE.T and ONE.T(opts.label) or opts.label)
            GameTooltip:AddLine(ONE.T and ONE.T(opts.tooltip) or opts.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    function box:Refresh() if self.SetChecked then self:SetChecked(opts.get() and true or false) end end
    box:Refresh()
    return box
end
