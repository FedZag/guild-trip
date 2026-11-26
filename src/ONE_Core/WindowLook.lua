-- Guild Trip: eigenes Aussehen je Zusatzfenster (Nutzer 22.11.2026, Regel fuer alle Fenster ausserhalb des
-- Hauptfensters): das Zahnrad am Fenster oeffnet dessen Optionen – Stil-Vorlage, frei waehlbare Farben (z. B.
-- Questgeber-Namen), Hintergrund (unsichtbar / leichtes Glas / kraeftiges Glas / dunkel) mit Deckkraft-Regler.
-- Alles wirkt sofort, ohne /reload. Ein Fenster meldet sich mit einer Beschreibung (def) an:
--   def = {id, title, store = function() return tabelle end, key = "look",
--          presets = {{value, text, tooltip}}, defaultPreset,
--          roles = {{key, label, default = {r, g, b}}}, defaultBg = "dark",
--          scale = {get, set, step, min, max} (optional), extra = {{label, onClick}} (optional),
--          onChange = function() end}
local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local WL = {}
ONE.WindowLook = WL

-- Hintergrund-Stufen: Toenung, Standard-Deckkraft, helle Oberkante (Glas)
WL.BG = {
    none = {tint = {0, 0, 0}, alpha = 0},
    glassLight = {tint = {.16, .19, .25}, alpha = .22, edge = .22},
    glass = {tint = {.10, .13, .19}, alpha = .5, edge = .28},
    dark = {tint = {0, 0, 0}, alpha = .72},
}
WL.BG_ORDER = {"none", "glassLight", "glass", "dark"}
WL.BG_NAMES = {none = "Unsichtbar (nur Text)", glassLight = "Leichtes Glas", glass = "Kräftiges Glas", dark = "Dunkel"}

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- gespeicherte Einstellungen eines Fensters (angelegt bei Bedarf)
function WL.Look(def)
    local s = def.store and def.store()
    if type(s) ~= "table" then return {} end
    local key = def.key or "look"
    if type(s[key]) ~= "table" then s[key] = {} end
    return s[key]
end
function WL.Preset(def)
    local v = WL.Look(def).preset
    for _, p in ipairs(def.presets or {}) do if p.value == v then return v end end
    return def.defaultPreset or (def.presets and def.presets[1] and def.presets[1].value)
end
function WL.Bg(def)
    local v = WL.Look(def).bg
    if WL.BG[v] then return v end
    local d = def.defaultBg
    if type(d) == "function" then d = d() end
    return WL.BG[d] and d or "dark"
end
-- Deckkraft: eigener Wert (Regler) oder der der Stufe
function WL.Alpha(def)
    local bg = WL.Bg(def)
    if bg == "none" then return 0 end
    local a = WL.Look(def).alpha
    if type(a) == "number" then return Clamp(a, .05, 1) end
    -- eigener Standard des Fensters (z. B. "In der Naehe" etwas heller als dunkel)
    if type(def.defaultAlpha) == "number" and WL.Look(def).bg == nil then return def.defaultAlpha end
    return WL.BG[bg].alpha
end
function WL.RoleDefault(def, role)
    for _, r in ipairs(def.roles or {}) do if r.key == role then return r.default end end
end
function WL.Color(def, role)
    local c = WL.Look(def).colors
    c = type(c) == "table" and c[role]
    if type(c) == "table" and type(c[1]) == "number" then return c[1], c[2], c[3] end
    local d = WL.RoleDefault(def, role) or {1, 1, 1}
    return d[1], d[2], d[3]
end
-- Farbcode fuer Text ("|cffRRGGBB")
function WL.Code(def, role)
    local r, g, b = WL.Color(def, role)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5))
end
function WL.Paint(def, text, role)
    if not text or text == "" then return text end
    return WL.Code(def, role) .. text .. "|r"
end

local function Changed(def)
    if def.onChange then pcall(def.onChange) end
    if WL.panel and WL.panel:IsShown() and WL.panel.def == def then WL:Refresh() end
end
function WL.Set(def, field, value)
    local look = WL.Look(def)
    look[field] = value
    if field == "bg" then look.alpha = nil end -- neue Stufe: deren Deckkraft
    -- neue Vorlage: deren vorgeschlagener Hintergrund (danach frei aenderbar)
    if field == "preset" then
        for _, pr in ipairs(def.presets or {}) do
            if pr.value == value and pr.bg then look.bg, look.alpha = pr.bg, nil end
        end
    end
    Changed(def)
end
function WL.SetColor(def, role, r, g, b)
    local look = WL.Look(def)
    look.colors = type(look.colors) == "table" and look.colors or {}
    look.colors[role] = {r, g, b}
    Changed(def)
end
function WL.ResetColors(def) WL.Look(def).colors = nil Changed(def) end
function WL.ResetAll(def)
    local s = def.store and def.store()
    if type(s) == "table" then s[def.key or "look"] = nil end
    Changed(def)
end

-- Hintergrund auf eine Flaeche legen: bg = Textur ueber die ganze Flaeche, edges = Liste von Kanten-Texturen
function WL.ApplyBg(def, bg, edges, hover)
    local mode = WL.Bg(def)
    local stage = WL.BG[mode]
    local a = WL.Alpha(def)
    if mode == "none" and hover then a, stage = .45, WL.BG.dark end -- zum Verschieben kurz sichtbar
    if bg then
        bg:SetColorTexture(stage.tint[1], stage.tint[2], stage.tint[3], a)
        bg:SetShown(a > 0)
    end
    for i, t in ipairs(edges or {}) do
        if stage.edge and i == 1 then
            t:SetColorTexture(1, 1, 1, stage.edge * math.min(1, a * 2.5))
            t:Show()
        elseif mode == "dark" or (mode == "none" and hover) then
            t:SetColorTexture(.36, .32, .25, 1)
            t:Show()
        else
            t:Hide()
        end
    end
end

-- ===== Zahnrad-Fenster =====
local function FS(parent, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    return fs
end

local function PickColor(def, role)
    local cpf = _G.ColorPickerFrame
    if not cpf then return end
    local r0, g0, b0 = WL.Color(def, role)
    local hadOwn = type(WL.Look(def).colors) == "table" and WL.Look(def).colors[role] ~= nil
    local function Current() local r, g, b = cpf:GetColorRGB() WL.SetColor(def, role, r, g, b) end
    local function Cancel()
        if hadOwn then WL.SetColor(def, role, r0, g0, b0)
        else local c = WL.Look(def).colors if type(c) == "table" then c[role] = nil end Changed(def) end
    end
    if cpf.SetupColorPickerAndShow then
        cpf:SetupColorPickerAndShow({r = r0, g = g0, b = b0, hasOpacity = false, swatchFunc = Current, cancelFunc = Cancel})
    else
        cpf.func, cpf.cancelFunc, cpf.hasOpacity = Current, Cancel, false
        if cpf.SetColorRGB then cpf:SetColorRGB(r0, g0, b0) end
        if ShowUIPanel then ShowUIPanel(cpf) else cpf:Show() end
    end
end

function WL:Build()
    if self.panel then return self.panel end
    local p = CreateFrame("Frame", "GuildTripWindowLook", UIParent)
    p:SetSize(300, 200)
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", function(self) self:StartMoving() end)
    p:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(p)
    bg:SetColorTexture(.05, .06, .08, .96)
    for _, side in ipairs({{"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"}}) do
        local t = p:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], p, side[1], 0, 0)
        t:SetPoint(side[2], p, side[2], 0, 0)
        t:SetHeight(2)
        t:SetColorTexture(.36, .32, .25, 1)
    end
    p.title = FS(p, "GameFontNormalLarge")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
    p.close = ONE.Widgets:Button(p, T("Fertig"), 64, 22, "TOPRIGHT", -8, -7, function() p:Hide() end, "primary")
    p.items = {}
    if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripWindowLook") end -- ESC schliesst
    p:Hide()
    self.panel = p
    return p
end

-- Inhalt neu aufbauen (je Fenster anders)
function WL:Fill(def)
    local p = self.panel
    for _, it in ipairs(p.items) do if it.Hide then it:Hide() end end
    p.items, p.refresh = {}, {}
    local function Keep(x) p.items[#p.items + 1] = x return x end
    local y = -40
    local W = p:GetWidth()
    local function Head(text)
        local h = Keep(FS(p, "GameFontNormal"))
        h:SetPoint("TOPLEFT", p, "TOPLEFT", 12, y)
        h:SetText(T(text))
        y = y - 20
    end
    local function Dropdown(label, opts)
        local l = Keep(FS(p))
        l:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y - 5)
        l:SetText(T(label))
        local dd = ONE.Kit:Dropdown(p, {point = "TOPLEFT", x = 110, y = y, width = W - 124,
            options = opts.options, get = opts.get, set = opts.set, onChange = function() WL:Refresh() end})
        Keep(dd.frame)
        p.refresh[#p.refresh + 1] = function() dd:Refresh() end
        y = y - 30
    end
    -- Stil-Vorlage
    if def.presets and #def.presets > 1 then
        Head("Stil")
        Dropdown("Vorlage", {
            options = function()
                local out = {}
                for _, pr in ipairs(def.presets) do out[#out + 1] = {value = pr.value, text = pr.text, tooltip = pr.tooltip} end
                return out
            end,
            get = function() return WL.Preset(def) end, set = function(v) WL.Set(def, "preset", v) end})
    end
    -- Hintergrund + Deckkraft
    Head("Hintergrund")
    Dropdown("Art", {
        options = function()
            local out = {}
            for _, k in ipairs(WL.BG_ORDER) do out[#out + 1] = {value = k, text = WL.BG_NAMES[k]} end
            return out
        end,
        get = function() return WL.Bg(def) end, set = function(v) WL.Set(def, "bg", v) end})
    do
        local l = Keep(FS(p))
        l:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y - 2)
        l:SetText(T("Deckkraft"))
        local value = Keep(FS(p))
        value:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, y - 2)
        value:SetJustifyH("RIGHT")
        local ok, slider = pcall(CreateFrame, "Slider", nil, p, "OptionsSliderTemplate")
        if not ok or not slider then slider = CreateFrame("Slider", nil, p) end
        Keep(slider)
        slider:SetPoint("TOPLEFT", p, "TOPLEFT", 110, y - 2)
        slider:SetWidth(W - 170)
        if slider.SetHeight then slider:SetHeight(16) end
        if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
        slider:SetMinMaxValues(5, 100)
        slider:SetValueStep(5)
        if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
        for _, key in ipairs({"Low", "High", "Text"}) do
            local fs = slider[key]
            if type(fs) == "table" and fs.SetText then fs:SetText("") end
        end
        if ONE.Glass and ONE.Glass.StyleSlider and ONE.Glass.Active and ONE.Glass:Active() then pcall(ONE.Glass.StyleSlider, ONE.Glass, slider) end
        local busy = false
        slider:SetScript("OnValueChanged", function(_, v)
            if busy then return end
            v = math.floor((v or 50) / 5 + .5) * 5
            value:SetText(v .. " %")
            if WL.Bg(def) ~= "none" and math.abs(WL.Alpha(def) * 100 - v) > .5 then
                WL.Look(def).alpha = v / 100
                if def.onChange then pcall(def.onChange) end
            end
        end)
        p.refresh[#p.refresh + 1] = function()
            local none = WL.Bg(def) == "none"
            busy = true
            local a = math.floor(WL.Alpha(def) * 100 + .5)
            if slider.SetValue then slider:SetValue(none and 5 or a) end
            busy = false
            value:SetText(none and "–" or (a .. " %"))
            if slider.SetEnabled then slider:SetEnabled(not none) end
            if slider.SetAlpha then slider:SetAlpha(none and .4 or 1) end
        end
        y = y - 30
    end
    -- Schriftgroesse
    if def.scale then
        local sc = def.scale
        local l = Keep(FS(p))
        l:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y - 5)
        l:SetText(T("Schriftgröße"))
        Keep(ONE.Widgets:Button(p, "A −", 40, 22, "TOPLEFT", 110, y, function() sc.set(sc.get() - (sc.step or .05)) WL:Refresh() end))
        local v = Keep(FS(p))
        v:SetPoint("TOPLEFT", p, "TOPLEFT", 154, y - 5)
        v:SetWidth(50)
        v:SetJustifyH("CENTER")
        Keep(ONE.Widgets:Button(p, "A +", 40, 22, "TOPLEFT", 208, y, function() sc.set(sc.get() + (sc.step or .05)) WL:Refresh() end))
        p.refresh[#p.refresh + 1] = function() v:SetText(math.floor(sc.get() * 100 + .5) .. " %") end
        y = y - 30
    end
    -- Farben je Rolle: Feld anklicken = Farbwaehler des Spiels
    if def.roles and #def.roles > 0 then
        Head("Farben")
        for i, r in ipairs(def.roles) do
            local col = (i - 1) % 2
            local b = Keep(CreateFrame("Button", nil, p))
            b:SetSize((W - 28) / 2, 20)
            b:SetPoint("TOPLEFT", p, "TOPLEFT", 12 + col * (W - 24) / 2, y)
            local sw = b:CreateTexture(nil, "ARTWORK")
            sw:SetSize(14, 14)
            sw:SetPoint("LEFT", b, "LEFT", 2, 0)
            local edge = b:CreateTexture(nil, "BORDER")
            edge:SetPoint("TOPLEFT", sw, "TOPLEFT", -1, 1)
            edge:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 1, -1)
            edge:SetColorTexture(.6, .6, .6, 1)
            local t = FS(b, "GameFontHighlightSmall")
            t:SetPoint("LEFT", sw, "RIGHT", 6, 0)
            t:SetPoint("RIGHT", b, "RIGHT", -2, 0)
            if ONE.Fit then ONE.Fit:Line(t, b) end
            t:SetText(T(r.label))
            b:SetScript("OnClick", function() PickColor(def, r.key) end)
            b:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(T(r.label), 1, .82, 0)
                GameTooltip:AddLine(T("Klicken: Farbe wählen"), 1, 1, 1)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            p.refresh[#p.refresh + 1] = function() sw:SetColorTexture(WL.Color(def, r.key)) end
            if col == 1 or i == #def.roles then y = y - 22 end
        end
        y = y - 6
    end
    -- Knoepfe: zuruecksetzen, weitere Einstellungen
    local bw = (W - 30) / 2
    Keep(ONE.Widgets:Button(p, T("Farben zurücksetzen"), bw, 22, "TOPLEFT", 12, y, function() WL.ResetColors(def) end))
    Keep(ONE.Widgets:Button(p, T("Alles zurücksetzen"), bw, 22, "TOPLEFT", 18 + bw, y, function() WL.ResetAll(def) end))
    y = y - 28
    for _, e in ipairs(def.extra or {}) do
        Keep(ONE.Widgets:Button(p, T(e.label), W - 24, 22, "TOPLEFT", 12, y, function() p:Hide() e.onClick() end))
        y = y - 28
    end
    p:SetHeight(-y + 6)
end

function WL:Refresh()
    local p = self.panel
    if not (p and p:IsShown()) then return end
    for _, fn in ipairs(p.refresh or {}) do pcall(fn) end
end

-- ===== Zahnrad nur beim Drueberfahren, Einstellungen per Rechtsklick (Nutzer 22.11.2026) =====
-- WL:Attach(owner, gear, opts) fuer schwebende Fenster (Buffs, In der Naehe, Pfeil, Beute, Quest-Kasten):
--   * Zahnrad unsichtbar, erscheint nur, solange die Maus ueber dem Fenster ist (oder sein Aussehen offen ist)
--   * Rechtsklick auf die Beschriftung (opts.label) bzw. aufs Fenster (opts.frameClick) -> Kontextmenue
--     mit opts.menu() = {{text=, func=, checked=function}} und "Aussehen …"
-- opts.def = Aussehen-Definition, opts.title = Menue-Ueberschrift, opts.inset = {oben, unten, links, rechts}
WL.attached = {}
local function Over(e)
    local o = e.owner
    if not (o and o.IsVisible and o:IsVisible()) then return false end
    local p = WL.panel
    if p and p.IsShown and p:IsShown() and p.def == e.def then return true end
    if e.gear.IsMouseOver and e.gear:IsMouseOver() then return true end
    if e.hit and e.hit.IsMouseOver and e.hit:IsMouseOver() then return true end
    if not o.IsMouseOver then return false end
    local i = e.inset or {}
    local ok, over = pcall(o.IsMouseOver, o, i[1] or 0, i[2] or 0, i[3] or 0, i[4] or 0)
    return ok and over or false
end
WL.Over = Over
function WL:UpdateGears()
    for _, e in ipairs(self.attached) do
        local show = Over(e)
        if e.shown ~= show then
            e.shown = show
            if e.gear.SetAlpha then e.gear:SetAlpha(show and 1 or 0) end
            if e.gear.EnableMouse then e.gear:EnableMouse(show) end
        end
    end
end
-- Schalter aus den Optionen direkt im Rechtsklick-Menue eines Fensters (Nutzer 25.11.2026: „Optionen in die
-- jeweiligen Fenster einbinden“). ids = Funktions-Schalter (ONE:RegisterFeature) oder Einstellungen (UI:AddSetting).
-- Derselbe Schalter wie in den Optionen – egal, wo man ihn umstellt. Unbekannte/unsichtbare ids fallen weg.
function WL.FindSetting(id)
    local UI = ONE.UI
    for _, o in ipairs(UI and UI.settingList or {}) do if o.id == id then return o end end
end
function WL.SettingItems(ids)
    local items = {}
    for _, id in ipairs(ids or {}) do
        local f = ONE.features and ONE.features[id]
        local o = not f and WL.FindSetting(id)
        if f and (not f.module or not ONE.IsEnabled or ONE:IsEnabled(f.module)) then
            items[#items + 1] = {text = f.label, tooltip = f.tooltip, setting = id,
                checked = function() return ONE:FeatureOn(id) end,
                func = function() ONE:SetFeature(id, not ONE:FeatureOn(id)) end}
        elseif o and not (type(o.visible) == "function" and not o.visible()) then
            local function After() if o.onChange then pcall(o.onChange) end if ONE.UI and ONE.UI.Refresh then pcall(ONE.UI.Refresh, ONE.UI) end end
            if o.kind == "check" then
                items[#items + 1] = {text = o.label, tooltip = o.tooltip, setting = id,
                    checked = function() local ok, v = pcall(o.get) return ok and v and true or false end,
                    func = function() local ok, v = pcall(o.get) pcall(o.set, not (ok and v)) After() end}
            elseif o.kind == "dropdown" or o.kind == "radio" then
                local okOpts, opts = pcall(function() return type(o.options) == "function" and o.options() or o.options end)
                local sub = {}
                for _, opt in ipairs(okOpts and type(opts) == "table" and opts or {}) do
                    sub[#sub + 1] = {text = opt.text or tostring(opt.value),
                        selected = function() local ok, v = pcall(o.get) return ok and v == opt.value end,
                        func = function() pcall(o.set, opt.value) After() end}
                end
                if #sub > 0 then items[#items + 1] = {text = o.label, setting = id, sub = sub} end
            elseif o.kind == "button" and o.onClick then
                items[#items + 1] = {text = o.label, setting = id, func = function() pcall(o.onClick) After() end}
            end
        end
    end
    return items
end

function WL:ContextMenu(e)
    local items = e.menu and e.menu() or {}
    -- Schalter aus den Optionen (opts.settings), danach „Alle Optionen …“ (opts.category)
    local extra = WL.SettingItems(e.settings)
    if #extra > 0 then
        items[#items + 1] = {divider = true}
        for _, it in ipairs(extra) do items[#items + 1] = it end
    end
    if e.category and ONE.UI and ONE.UI.OpenOptions then
        items[#items + 1] = {text = "Alle Optionen …", func = function() ONE.UI:OpenOptions(e.category) end}
    end
    if type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, e.owner, function(_, root)
            if e.title and root.CreateTitle then root:CreateTitle(T(e.title)) end
            for _, it in ipairs(items) do
                if it.divider then
                    if root.CreateDivider then root:CreateDivider() end
                elseif it.sub then
                    local d = root:CreateButton(T(it.text))
                    for _, s in ipairs(it.sub) do
                        if d and d.CreateRadio then d:CreateRadio(T(s.text), function() return s.selected() and true or false end, function() s.func() end)
                        elseif d and d.CreateButton then d:CreateButton(T(s.text), function() s.func() end) end
                    end
                elseif it.checked and root.CreateCheckbox then
                    local d = root:CreateCheckbox(T(it.text), function() return it.checked() and true or false end, function() it.func() end)
                    if it.tooltip and d and d.SetTooltip then
                        pcall(d.SetTooltip, d, function(tt) if tt.AddLine then tt:AddLine(T(it.tooltip), 1, 1, 1, true) end end)
                    end
                else
                    root:CreateButton(T(it.text), function() it.func() end)
                end
            end
            if e.def then root:CreateButton(T("Aussehen …"), function() WL:Toggle(e.def, e.owner) end) end
        end)
        if ok then return true end
    end
    if e.def then self:Toggle(e.def, e.owner) return true end
    return false
end
function WL:Attach(owner, gear, opts)
    opts = opts or {}
    local e = {owner = owner, gear = gear, def = opts.def, menu = opts.menu, title = opts.title, inset = opts.inset,
        settings = opts.settings, category = opts.category}
    self.attached[#self.attached + 1] = e
    if gear.SetAlpha then gear:SetAlpha(0) end
    if gear.EnableMouse then gear:EnableMouse(false) end
    e.shown = false
    -- Rechtsklick auf die Beschriftung: kleine Flaeche nur ueber dem Text, nimmt nur den rechten Klick
    if opts.label and CreateFrame then
        local ok, hit = pcall(CreateFrame, "Button", nil, owner)
        if ok and hit then
            hit:SetPoint("TOPLEFT", opts.label, "TOPLEFT", -2, 2)
            hit:SetPoint("BOTTOMRIGHT", opts.label, "BOTTOMRIGHT", 2, -2)
            if hit.RegisterForClicks then hit:RegisterForClicks("RightButtonUp") end
            if hit.SetPropagateMouseClicks then pcall(hit.SetPropagateMouseClicks, hit, false) end
            hit:SetScript("OnClick", function() WL:ContextMenu(e) end)
            hit:SetScript("OnEnter", function(b)
                if not GameTooltip then return end
                GameTooltip:SetOwner(b, "ANCHOR_TOP")
                GameTooltip:AddLine(T("Rechtsklick: Einstellungen"), .8, .8, .8)
                GameTooltip:Show()
            end)
            hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            e.hit = hit
        end
    end
    if opts.frameClick and owner.HookScript then
        owner:HookScript("OnMouseUp", function(_, button) if button == "RightButton" then WL:ContextMenu(e) end end)
    end
    -- ein gemeinsamer, gebremster Takt fuer alle Zahnraeder
    if not self.gearTicker and CreateFrame then
        local ok, t = pcall(CreateFrame, "Frame")
        if ok and t then
            local acc = 0
            t:SetScript("OnUpdate", function(_, dt)
                acc = acc + (dt or 0)
                if acc < .15 then return end
                acc = 0
                WL:UpdateGears()
            end)
            self.gearTicker = t
        end
    end
    return e
end

-- Zahnrad: oeffnen/schliessen, neben dem Fenster (Seite mit mehr Platz)
function WL:Toggle(def, owner)
    local p = self:Build()
    if p:IsShown() and p.def == def then p:Hide() return end
    p.def = def
    p.title:SetText(T(def.title or "Aussehen"))
    self:Fill(def)
    p:ClearAllPoints()
    local left = owner and owner.GetLeft and owner:GetLeft()
    local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920
    local scale = owner and owner.GetEffectiveScale and owner:GetEffectiveScale() or 1
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if owner and left then
        local mid = (left + (owner:GetWidth() or 0) / 2) * scale / uiScale
        if mid > sw / 2 then p:SetPoint("TOPRIGHT", owner, "TOPLEFT", -6, 0)
        else p:SetPoint("TOPLEFT", owner, "TOPRIGHT", 6, 0) end
    else
        p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    p:Show()
    self:Refresh()
end

return WL
