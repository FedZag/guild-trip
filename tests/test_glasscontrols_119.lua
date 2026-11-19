-- Offline-Test 0.7.2: Bedienelemente im Glas-Aussehen (Haekchen, Regler, Scrollleisten, Eingabefelder, Auswahlfeld)
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, children = {}, regions = {}, shown = true, alpha = 1, hooks = {}, scripts = {}}
    function r:GetObjectType() return self.kind end
    function r:GetParent() return self.parent end
    function r:GetChildren() return unpack(self.children) end
    function r:GetRegions() return unpack(self.regions) end
    function r:CreateTexture()
        local t = Region("Texture", self)
        function t:SetTexture(x) self.tex = x end
        function t:SetColorTexture() end
        function t:SetVertexColor(...) self.color = {...} end
        function t:SetTexCoord() end
        self.regions[#self.regions + 1] = t
        return t
    end
    function r:CreateFontString()
        local f = Region("FontString", self)
        function f:SetText(x) self.text = x end
        function f:SetJustifyH() end
        return f
    end
    function r:SetAlpha(a) self.alpha = a end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetSize() end
    function r:SetWidth() end
    function r:SetHeight() end
    function r:SetPoint() end
    function r:ClearAllPoints() end
    function r:EnableMouse() end
    function r:SetFrameStrata() end
    function r:SetClampedToScreen() end
    function r:SetAllPoints() end
    function r:HookScript(ev, fn) self.hooks[ev] = fn end
    function r:SetScript(ev, fn) self.scripts[ev] = fn end
    return r
end
CreateFrame = function(kind, _, parent) local f = Region(kind, parent) if parent and parent.children then parent.children[#parent.children + 1] = f end return f end
UIParent = Region("Frame")
UISpecialFrames = {}
hooksecurefunc = function(obj, name, fn) local old = obj[name] obj[name] = function(...) local a = old(...) fn() return a end end
local ONE = {db = {theme = {look = "glass"}}}
ONE.Themes = {StyleTree = function() end}
assert(loadfile(root .. "/ONE_Core/Glass.lua"))("ONE_Core", ONE)
local Glass = ONE.Glass
assert(loadfile(root .. "/ONE_Core/GlassControls.lua"))("ONE_Core", ONE)

-- Fenster mit Blizzard-Bedienelementen
local win = Region("Frame")
local panel = CreateFrame("Frame", nil, win)
local check = CreateFrame("CheckButton", nil, panel)
local normal, checked = Region("Texture"), Region("Texture")
check.checked = false
function check:GetNormalTexture() return normal end
function check:GetCheckedTexture() return checked end
function check:GetChecked() return self.checked end
function check:SetChecked(v) self.checked = v end
local slider = CreateFrame("Slider", nil, panel)
local thumbOld = Region("Texture")
slider.regions = {Region("Texture"), thumbOld}
function slider:GetThumbTexture() return self.thumb or thumbOld end
function slider:SetThumbTexture(t) self.thumb = t end
local scroll = CreateFrame("ScrollFrame", nil, panel)
local bar = CreateFrame("Slider", nil, scroll)
bar.ScrollUpButton, bar.ScrollDownButton = Region("Button"), Region("Button")
function bar:GetThumbTexture() return self.thumb end
function bar:SetThumbTexture(t) self.thumb = t end
scroll.ScrollBar = bar
local edit = CreateFrame("EditBox", nil, panel)
edit.Left, edit.Middle, edit.Right = Region("Texture"), Region("Texture"), Region("Texture")

-- im Glas-Aussehen: StyleTree kleidet alles ein
ONE.Themes:StyleTree(win)
assert(check.__oneGlassCtl == "check" and normal.alpha == 0 and checked.alpha == 0, "Haekchen ohne Blizzard-Bild")
assert(slider.__oneGlassCtl == "slider" and slider.thumb ~= thumbOld, "Regler mit rundem Knopf")
assert(scroll.__oneGlassCtl == "scroll" and not bar.ScrollUpButton.shown and not bar.ScrollDownButton.shown and bar.thumb, "Scrollleiste ohne Pfeile")
assert(bar.__oneGlassCtl == nil, "Schieber der Scrollleiste ist kein eigener Regler")
assert(edit.__oneGlassCtl == "edit" and edit.Left.alpha == 0 and edit.Middle.alpha == 0, "Eingabefeld ohne Blizzard-Rahmen")
-- Haekchen: an = Punkt sichtbar, aus = weg
check:SetChecked(true)
local dot
for _, r in ipairs(check.regions) do if r.tex == Glass.tex.circle then dot = r end end
assert(dot and dot.shown, "an: Punkt")
check:SetChecked(false)
assert(not dot.shown, "aus: kein Punkt")
-- zweiter Durchlauf aendert nichts (nur einmal einkleiden)
local n = #check.regions
ONE.Themes:StyleTree(win)
assert(#check.regions == n, "nur einmal")
-- Blizzard-Aussehen: nichts anfassen
ONE.db.theme.look = "native"
local other = Region("Frame")
local c2 = CreateFrame("CheckButton", nil, other)
function c2:GetNormalTexture() return Region("Texture") end
ONE.Themes:StyleTree(other)
assert(c2.__oneGlassCtl == nil, "Blizzard-Look bleibt")
ONE.db.theme.look = "glass"

-- Auswahlfeld: eigener Knopf, Menue mit Markierung, Klick waehlt
local Widgets = {}
function Widgets:Button(parent, text, w, h, point, x, y, cb)
    local b = CreateFrame("Button", nil, parent)
    local fs = b:CreateFontString()
    function b:GetFontString() return fs end
    function b:SetText(t) fs.text = t end
    return b
end
ONE.Widgets = Widgets
local chosen
local list = {{value = "a", text = "Alpha"}, {value = "b", text = "Beta", tooltip = "Tipp"}}
local btn = Glass:Dropdown(UIParent, {width = 160}, function() return list end, function() return "Beta" end, function(v) chosen = v end)
btn.scripts.OnClick(btn)
local m = Glass.menu
assert(m and m.shown and #m.rows == 2, "Menue offen")
assert(not m.rows[1].mark.shown and m.rows[2].mark.shown, "aktuelle Wahl markiert")
m.rows[1].scripts.OnClick()
assert(chosen == "a" and not m.shown, "Klick waehlt und schliesst")
-- runde Symbole: Ring in Leuchtfarbe, nur einmal; im Blizzard-Look nichts
local row = Region("Button")
local ic = row:CreateTexture()
function ic:SetTexCoord(...) self.coords = {...} end
Glass:RoundIcon(row, ic)
assert(ic.__oneRound and ic.__oneRing and ic.coords[1] == .08, "rund mit Ring")
local n2 = #row.regions
Glass:RoundIcon(row, ic)
assert(#row.regions == n2, "nur einmal")
ONE.db.theme.look = "native"
local ic2 = row:CreateTexture()
Glass:RoundIcon(row, ic2)
assert(not ic2.__oneRound, "Blizzard-Look: eckig")
print("OK test_glasscontrols_119")
