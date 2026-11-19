-- Offline-Test: Fenster an allen Kanten/Ecken ziehen (Groesse bzw. Massstab), 18.11.2026.
local root = arg[1] or "src"
local function Region()
    local r = {scripts = {}, points = {}, scale = 1, shown = true}
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:HookScript(e, fn) self.scripts["hook" .. e] = fn end
    function r:SetPoint(...) self.points[#self.points + 1] = {...} end
    function r:ClearAllPoints() self.points = {} end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:SetFrameLevel(l) self.level = l end
    function r:GetFrameLevel() return self.level or 1 end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetScale(s) self.scale = s end
    function r:GetScale() return self.scale end
    function r:StartSizing(side) self.sizing = side end
    function r:StopMovingOrSizing() self.sizing = nil end
    function r:GetObjectType() return "Frame" end
    function r:CreateTexture() local t = Region() function t:SetAllPoints() end function t:SetColorTexture() end return t end
    return r
end
CreateFrame = function() return Region() end
UIParent = Region()
UIParent.GetEffectiveScale = function() return 1 end
local cx, cy = 0, 0
GetCursorPosition = function() return cx, cy end
local ONE = {db = {}}
_G.ProjectONE = ONE
assert(loadfile(root .. "/ONE_Core/Widgets.lua"))("ONE_Core", ONE)
local W = ONE.Widgets
-- 1) Groesse: 8 Griffe, Kante startet StartSizing in ihre Richtung
local f = Region()
local stopped = false
local hs = W:ResizeHandles(f, {onStop = function() stopped = true end})
assert(#hs == 8, "4 Ecken + 4 Kanten")
local sides = {}
for _, h in ipairs(hs) do sides[h.side] = h end
sides.LEFT.scripts.OnMouseDown(sides.LEFT, "LeftButton")
assert(f.sizing == "LEFT")
sides.LEFT.scripts.OnMouseUp(sides.LEFT)
assert(f.sizing == nil and stopped)
-- Ueberfahren: Kante leuchtet, Mauszeiger "Groesse aendern"; Verlassen: alles zurueck
local cursor
SetCursor = function(c) if c == "UI_RESIZE_CURSOR" then cursor = c return true end return false end
ResetCursor = function() cursor = nil end
sides.RIGHT.scripts.OnEnter(sides.RIGHT)
assert(sides.RIGHT.glow.shown and cursor == "UI_RESIZE_CURSOR", "WoW-Zeiger beim Ueberfahren")
sides.RIGHT.scripts.OnLeave(sides.RIGHT)
assert(not sides.RIGHT.glow.shown and cursor == nil, "zurueck beim Verlassen")
SetCursor = function(c) cursor = c return c == "Interface\\CURSOR\\UI-Cursor-Move" end
assert(W.ResizeCursor(true) == "Interface\\CURSOR\\UI-Cursor-Move", "Ersatz-Zeiger, wenn der erste fehlt")
-- 2) Massstab: Fenster 100x50 bei (100..200, 100..150); rechte Kante nach rechts ziehen -> doppelt so gross, linke Seite bleibt
local g = Region()
function g:GetLeft() return 100 / self.scale end
function g:GetRight() return (100 + 100 * self.scale) / self.scale end
function g:GetTop() return 150 / self.scale end
function g:GetBottom() return 100 / self.scale end
local saved
local sh = W:ScaleHandles(g, "probe", {onStop = function(s) saved = s end})
assert(#sh == 8 and g.__oneScaleHandles)
local right
for i, d in ipairs(W.RESIZE_SIDES) do if d[1] == "RIGHT" then right = sh[i] end end
right.scripts.OnMouseDown(right, "LeftButton")
cx, cy = 300, 125                     -- Maus 200 rechts von der festen linken Kante (100) -> Massstab 2
g.__oneScaleUpdater.scripts.OnUpdate()
assert(math.abs(g.scale - 2) < 1e-9, "Massstab folgt der Maus: " .. g.scale)
local pt = g.points[1]
assert(pt[1] == "LEFT" and math.abs(pt[4] * 2 - 100) < 1e-9, "linke Kante bleibt stehen")
right.scripts.OnMouseUp(right)
assert(ONE.db.frameScales.probe == 2 and saved == 2, "Massstab gemerkt")
-- 3) gemerkter Massstab wird beim naechsten Mal gesetzt, in Grenzen
ONE.db.frameScales.probe2 = 5
local k = Region()
W:ScaleHandles(k, "probe2", {max = 1.5})
assert(k.scale == 1.5, "auf Hoechstwert begrenzt")
-- 4) Kleine Fenster bleiben fest (nur Hauptfenster, Chat, Quest-Fuehrung ziehbar)
_G.GuildTripBuffNearby = Region()
W:AttachScaling()
assert(not _G.GuildTripBuffNearby.__oneScaleHandles, "Buff-Fenster nicht ziehbar")
print("OK test_resize_116")
