-- Optionen in den Fenstern (25.11.2026, Nutzer: „Optionen in die jeweiligen Fenster einbinden“ → „ja, so bauen“):
-- WindowLook holt Schalter aus den Optionen (Funktions-Schalter + Einstellungen) ins Rechtsklick-Menue, derselbe
-- Schalter wie in den Optionen; Auswahlfelder als Untermenue; „Alle Optionen …“ oeffnet den Bereich.
local root = arg[1] or "src"
local db = {features = {}}
_G.ProjectONE = {db = db, features = {}, featureOrder = {}}
local ONE = _G.ProjectONE
function ONE:IsEnabled() return true end
assert(loadfile(root .. "/ONE_Core/Core.lua")) -- nur Syntax
-- FeatureOn/SetFeature wie im Kern
function ONE:FeatureOn(id) return not (db.features[id] == false) end
function ONE:SetFeature(id, on) db.features[id] = on and true or false end
ONE.features["nav.arrowCompanion"] = {label = "Am Pfeil: Gilde", tooltip = "Zeile", module = "nav"}
local style, opened = "one", nil
local checked = true
ONE.UI = {settingList = {
    {id = "navStyle", kind = "dropdown", label = "Aussehen des Pfeils", options = function() return {{value = "one", text = "Gold"}, {value = "glass", text = "Glas"}} end,
        get = function() return style end, set = function(v) style = v end},
    {id = "lev.autoNavi", kind = "check", label = "Navi folgt", get = function() return checked end, set = function(v) checked = v end},
    {id = "versteckt", kind = "check", label = "x", visible = function() return false end, get = function() return true end, set = function() end},
}, OpenOptions = function(_, cat) opened = cat end, Refresh = function() end}
assert(loadfile(root .. "/ONE_Core/WindowLook.lua"))("ONE_Core", ONE)
local WL = ONE.WindowLook

local items = WL.SettingItems({"nav.arrowCompanion", "navStyle", "lev.autoNavi", "versteckt", "gibtsnicht"})
assert(#items == 3, "unsichtbare und unbekannte fallen weg")
assert(items[1].checked() == true)
items[1].func()
assert(db.features["nav.arrowCompanion"] == false and items[1].checked() == false, "Funktions-Schalter wie in den Optionen")
assert(items[2].sub and #items[2].sub == 2 and items[2].sub[1].selected())
items[2].sub[2].func()
assert(style == "glass" and items[2].sub[2].selected(), "Auswahl als Untermenue")
items[3].func()
assert(checked == false and items[3].checked() == false)

-- Menue zeichnen (MenuUtil nachgebaut)
local log = {}
local function Desc(prefix)
    return {
        CreateTitle = function(_, t) log[#log + 1] = prefix .. "T:" .. t end,
        CreateDivider = function() log[#log + 1] = prefix .. "---" end,
        CreateCheckbox = function(_, t, get) log[#log + 1] = prefix .. "C:" .. t .. "=" .. tostring(get()) return {} end,
        CreateRadio = function(_, t, sel) log[#log + 1] = prefix .. "R:" .. t .. "=" .. tostring(sel()) end,
        CreateButton = function(_, t, fn) log[#log + 1] = prefix .. "B:" .. t if fn then log.fns = log.fns or {} log.fns[t] = fn end return Desc(prefix .. "  ") end,
    }
end
MenuUtil = {CreateContextMenu = function(owner, gen) gen(owner, Desc("")) return true end}
local e = {owner = {}, title = "Navi-Pfeil", settings = {"navStyle", "lev.autoNavi"}, category = "nav",
    menu = function() return {{text = "Navi beenden", func = function() end}} end}
assert(WL:ContextMenu(e))
local text = table.concat(log, "|")
assert(text:find("T:Navi-Pfeil|B:Navi beenden|---|B:Aussehen des Pfeils|  R:Gold=false|  R:Glas=true|C:Navi folgt=false|B:Alle Optionen …", 1, true), text)
log.fns["Alle Optionen …"]()
assert(opened == "nav")

-- Fenster: jede genannte id gibt es wirklich (Funktions-Schalter oder Einstellung)
local all = ""
for _, f in ipairs({"ONE_Nav/Init.lua", "ONE_Nav/Page.lua", "ONE_Nav/Companion.lua", "ONE_Leveling/Settings.lua", "ONE_Classes/Init.lua",
    "ONE_Nav/ChatLinks.lua", "ONE_Dungeons/Init.lua"}) do
    all = all .. assert(io.open(root .. "/" .. f)):read("*a")
end
local levKeys = {}
for k in assert(io.open(root .. "/ONE_Leveling/Settings.lua")):read("*a"):gmatch('key = "([%w]+)"') do levKeys["lev." .. k] = true end
local windows = {"/ONE_Nav/Arrow.lua", "/ONE_Leveling/Tracker.lua", "/ONE_Classes/Buffs.lua", "/ONE_Classes/Nearby.lua"}
local n = 0
for _, w in ipairs(windows) do
    local src = assert(io.open(root .. w)):read("*a")
    local list = src:match("settings = (%b{})")
    assert(list, w .. ": keine Schalter im Menue")
    for id in list:gmatch('"([%w%.]+)"') do
        n = n + 1
        local ok = levKeys[id] or all:find('RegisterFeature("' .. id .. '"', 1, true) or all:find('id = "' .. id .. '"', 1, true)
        assert(ok, w .. ": Schalter " .. id .. " gibt es nicht")
    end
    assert(src:find('category = "', 1, true), w .. ": „Alle Optionen …“ fehlt")
end
assert(n >= 20)
-- Chat: die beiden Link-Schalter im Chat-Zahnrad
local chat = assert(io.open(root .. "/ONE_Chat/Settings.lua")):read("*a")
assert(chat:find('Feat("dungeons.chatNames"', 1, true) and chat:find('Feat("nav.chatCoords"', 1, true))
print("OK test_fensteroptionen_177")
