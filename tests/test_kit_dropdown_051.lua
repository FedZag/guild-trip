-- Offline-Test 0.5.2: Kit-Bausteine Dropdown (modern / alt / Knopf) und Haekchen.
local root = arg[1] or "src"
local made = {}
local function Region(kind, parent, name, template)
    local r = {kind = kind, parent = parent, name = name, template = template, shown = true, scripts = {}}
    made[#made + 1] = r
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetPoint(...) self.point = {...} end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:HookScript(e, fn) self.scripts["hook:" .. e] = fn end
    function r:GetChecked() return self.checked end
    function r:SetChecked(v) self.checked = v end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
local modern = true
CreateFrame = function(kind, name, parent, template)
    local r = Region(kind, parent, name, template)
    if kind == "DropdownButton" then
        if not modern then error("unbekannter Frametyp") end
        function r:SetupMenu(gen) self.gen = gen end
        function r:OverrideText(t) self.text = t end
    end
    return r
end
UIParent = Region("Frame")
local ONE = {}
_G.ProjectONE = ONE
local refreshed = 0
ONE.UI = {Refresh = function() refreshed = refreshed + 1 end}
for _, f in ipairs({"Kit.lua", "Geometry.lua", "Widgets.lua"}) do assert(loadfile(root .. "/ONE_Core/" .. f))("ONE_Core", ONE) end
local Kit = ONE.Kit
local value
local opts = {point = "TOPRIGHT", width = 170,
    options = function() return {{value = nil, text = "Alle"}, {value = "a", text = "A"}, {value = "b", text = "B"}} end,
    get = function() return value end, set = function(v) value = v end}

-- 1) Modernes Blizzard-Menue
MenuUtil = {}
local dd = Kit:Dropdown(UIParent, opts)
assert(dd.kind == "menu" and dd.frame.text == "Alle", "modernes Dropdown, Starttext")
local radios = {}
dd.frame.gen(nil, {CreateRadio = function(_, text, isSel, setSel, data) radios[#radios + 1] = {text = text, isSel = isSel, setSel = setSel, data = data} end})
assert(#radios == 3 and radios[1].isSel(radios[1].data) and not radios[2].isSel(radios[2].data), "Auswahl markiert")
radios[3].setSel(radios[3].data)
assert(value == "b" and dd.frame.text == "B" and refreshed == 1, "Auswahl gesetzt und Seite aktualisiert")
radios[1].setSel(radios[1].data)
assert(value == nil and dd.frame.text == "Alle", "„Alle“ setzt wieder nil")

-- 2) Altes UIDropDownMenu
modern, MenuUtil = false, nil
local init, texts, buttons = nil, {}, {}
UIDropDownMenu_Initialize = function(f, fn) init = fn end
UIDropDownMenu_CreateInfo = function() return {} end
UIDropDownMenu_AddButton = function(info) buttons[#buttons + 1] = info end
UIDropDownMenu_SetText = function(f, t) texts[#texts + 1] = t end
UIDropDownMenu_SetWidth = function() end
value = "a"
local legacy = Kit:Dropdown(UIParent, opts)
assert(legacy.kind == "legacy" and legacy.frame.name == "GuildTripDropdown1" and texts[#texts] == "A")
init(nil, 1)
assert(#buttons == 3 and buttons[2].checked and not buttons[1].checked)
buttons[3].func()
assert(value == "b" and texts[#texts] == "B")

-- 3) Rueckfall: Knopf schaltet weiter
UIDropDownMenu_Initialize = nil
local btn = Kit:Dropdown(UIParent, opts)
assert(btn.kind == "button" and btn.frame.text == "B")
btn.frame.scripts.OnClick(btn.frame)
assert(value == nil and btn.frame.text == "Alle", "nach B kommt wieder Alle")
btn.frame.scripts.OnClick(btn.frame)
assert(value == "a")

-- 4) Haekchen
local on = false
local box = Kit:Check(UIParent, {label = "Teilen", get = function() return on end, set = function(v) on = v end})
assert(box.kind == "CheckButton" and box.checked == false and box.label.text == "Teilen")
box.checked = true
box.scripts.OnClick(box)
assert(on == true)
print("OK: 0.5.2 - Kit: Dropdown (modern/alt/Knopf) und Haekchen")
