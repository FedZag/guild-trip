-- Offline-Test 0.7.8: Zahnrad der Zusatzfenster nur beim Drueberfahren, Rechtsklick-Menue (22.11.2026).
local root = arg[1] or "src"
local function Frame(kind)
    local f = {kind = kind, scripts = {}, alpha = 1, mouse = true, visible = true, over = false}
    function f:SetAlpha(a) self.alpha = a end
    function f:EnableMouse(on) self.mouse = on end
    function f:IsVisible() return self.visible end
    function f:IsMouseOver() return self.over end
    function f:SetScript(e, fn) self.scripts[e] = fn end
    function f:HookScript(e, fn) local old = self.scripts[e] self.scripts[e] = old and function(...) old(...) fn(...) end or fn end
    function f:SetPoint() end
    function f:RegisterForClicks(...) self.clicks = {...} end
    return f
end
CreateFrame = function(kind) return Frame(kind) end
local ONE = {db = {}}
_G.ProjectONE = ONE
assert(loadfile(root .. "/ONE_Core/WindowLook.lua"))("ONE_Core", ONE)
local WL = ONE.WindowLook
local owner, gear, label = Frame("Frame"), Frame("Button"), {}
local toggled
WL.Toggle = function(_, def, o) toggled = {def, o} end
local def = {id = "test"}
local e = WL:Attach(owner, gear, {def = def, label = label, frameClick = true})
-- 1) unsichtbar, nimmt keine Maus
assert(gear.alpha == 0 and gear.mouse == false, "Zahnrad zuerst unsichtbar")
-- 2) Maus ueber dem Fenster -> sichtbar, weg -> wieder unsichtbar
owner.over = true
WL:UpdateGears()
assert(gear.alpha == 1 and gear.mouse == true)
owner.over = false
WL:UpdateGears()
assert(gear.alpha == 0)
-- verstecktes Fenster: nie sichtbar
owner.over, owner.visible = true, false
WL:UpdateGears()
assert(gear.alpha == 0)
owner.visible, owner.over = true, false
-- 3) Rechtsklick auf die Beschriftung nimmt nur den rechten Knopf; ohne MenuUtil -> Aussehen direkt
assert(e.hit and e.hit.clicks[1] == "RightButtonUp" and #e.hit.clicks == 1)
e.hit.scripts.OnClick(e.hit)
assert(toggled and toggled[1] == def and toggled[2] == owner)
-- 4) mit MenuUtil: Menue mit eigenen Eintraegen und "Aussehen …"
local made = {}
MenuUtil = {CreateContextMenu = function(_, build)
    local root = {}
    function root:CreateTitle(t) made[#made + 1] = "T:" .. t end
    function root:CreateButton(t, fn) made[#made + 1] = t self.last = fn end
    function root:CreateCheckbox(t) made[#made + 1] = "C:" .. t end
    build(nil, root)
end}
local locked = false
e.title = "Navi-Pfeil"
e.menu = function() return {{text = "Festsetzen", checked = function() return locked end, func = function() locked = not locked end},
    {text = "Navi beenden", func = function() end}} end
owner.scripts.OnMouseUp(owner, "RightButton")
assert(made[1] == "T:Navi-Pfeil" and made[2] == "C:Festsetzen" and made[3] == "Navi beenden" and made[4] == "Aussehen …", table.concat(made, ","))
made = {}
owner.scripts.OnMouseUp(owner, "LeftButton")
assert(#made == 0, "Linksklick oeffnet kein Menue")
print("OK test_hovergear_154")
