-- Offline-Test 0.4.5a: Scroll-Liste (Kit) und neues Mitgliederverzeichnis.
local root = arg[1] or "src"
local made = {}
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, scroll = 0}
    made[#made + 1] = r
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then
            return function() end
        end
    end})
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:SetPoint(...) self.point = {...} end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text or "" end
    function r:SetTextColor(...) self.color = {...} end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:HookScript(e, fn) self.scripts["hook:" .. e] = fn end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetVerticalScroll(v) self.scroll = v end
    function r:GetVerticalScroll() return self.scroll end
    function r:GetChecked() return self.checked end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
IsInGuild = function() return true end
GetNumGuildMembers = function() return 79, 23 end
local classes = {"WARRIOR", "MAGE", "PRIEST", "WARLOCK"}
GetGuildRosterInfo = function(i)
    local zone = i % 2 == 0 and "Brachland" or "Durotar"
    return string.format("Spieler%02d-Realm", i), i == 1 and "Gildenmeister" or "Mitglied", 1, 10 + i % 30,
        "Klasse" .. (i % 4), zone, "", "", i <= 23, 0, classes[i % 4 + 1]
end
RAID_CLASS_COLORS = {MAGE = {r = .2, g = .8, b = 1}}
local ONE = {db = {}, modules = {}}
function ONE:Print() end
ONE.UI = {Layout = {width = 726}, Refresh = function() if ONE.refresh then ONE.refresh() end end}
_G.ProjectONE = ONE
for _, f in ipairs({"Themes.lua", "Kit.lua", "Geometry.lua", "Widgets.lua"}) do
    assert(loadfile(root .. "/ONE_Core/" .. f))("ONE_Core", ONE)
end
ONE.Themes:Initialize()
local guild = {}
assert(loadfile(root .. "/ONE_Guild/Roster.lua"))("ONE_Guild", guild)
assert(loadfile(root .. "/ONE_Guild/UI.lua"))("ONE_Guild", guild)
local page = Region("Frame")
ONE.refresh = guild.UI:BuildGuildMembers(page)
ONE.refresh()

-- Kein Blaettern mehr
for _, r in ipairs(made) do
    assert(r.text ~= "Vorherige" and r.text ~= "Nächste", "Blaetter-Knoepfe duerfen nicht mehr existieren")
end
local list
for _, r in ipairs(made) do if r.kind == "ScrollFrame" then list = r end end
assert(list, "Scrollleiste fehlt")
-- Spaltenkoepfe vorhanden und innerhalb der Breite
local heads = {}
for _, r in ipairs(made) do if r.kind == "FontString" and type(r.text) == "string" and r.text:match("^[A-Z]+$") then heads[r.text] = r end end
for _, h in ipairs({"NAME", "STUFE", "KLASSE", "RANG", "GEBIET"}) do assert(heads[h], "Spalte fehlt: " .. h) end
-- Sichtbare Zeilen: Online-Mitglieder zuerst, alphabetisch
local rows = {}
for _, r in ipairs(made) do if r.kind == "Button" and r.cells then rows[#rows + 1] = r end end
assert(#rows >= 12, "zu wenige sichtbare Zeilen: " .. #rows)
for _, row in ipairs(rows) do
    local right = 0
    for _, cell in pairs(row.cells) do right = math.max(right, (cell.point[4] or 0) + (cell.w or 0)) end
    assert(right <= row.w, "Text ragt aus der Zeile: " .. right .. " > " .. row.w)
end
assert(rows[1].cells.name.text == "Spieler01" and rows[1].item.online)
assert(rows[1].cells.zone.text == "Durotar")
-- Scrollen: Zeilen werden neu befuellt bis zum letzten Mitglied
local visible = #rows
list:SetVerticalScroll((79 - visible) * 22)
list.scripts["hook:OnVerticalScroll"]()
local last = rows[visible].item
assert(last and last.name == "Spieler79-Realm" and not last.online, "ans Ende scrollen: " .. tostring(last and last.name))
assert(rows[visible].cells.zone.text == "offline")
list:SetVerticalScroll(0)
list.scripts["hook:OnVerticalScroll"]()
-- Mausrad auf einer Zeile scrollt drei Zeilen
rows[1].scripts.OnMouseWheel(rows[1], -1)
assert(list.scroll == 3 * 22 and rows[1].item.name == "Spieler04-Realm")
list:SetVerticalScroll(0)
-- Nur online
local check
for _, r in ipairs(made) do if r.kind == "CheckButton" then check = r end end
check.checked = true
check.scripts.OnClick(check)
local count = 0
for _, row in ipairs(rows) do if row.shown and row.item then assert(row.item.online) count = count + 1 end end
assert(count == math.min(visible, 23))
-- Suche (Name, Gebiet, Klasse, Rang)
local search
for _, r in ipairs(made) do if r.kind == "EditBox" then search = r end end
search.text = "gildenmeister"
search.scripts["hook:OnTextChanged"]()
assert(rows[1].shown and rows[1].item.name == "Spieler01-Realm" and not rows[2].shown)
search.text = ""
check.checked = false
check.scripts.OnClick(check)
-- Sortieren per Klick auf STUFE (aufsteigend, dann absteigend)
local levelHead = heads.STUFE.parent
levelHead.scripts.OnClick(levelHead)
assert(rows[1].item.level <= rows[2].item.level)
levelHead.scripts.OnClick(levelHead)
assert(rows[1].item.level >= rows[2].item.level)
-- Scrollleiste nur bei Bedarf (0.4.7c)
local bar = {shown = true, Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end}
list.ScrollBar = bar
ONE.refresh()
assert(bar.shown, "79 Mitglieder: Scrollleiste noetig")
search.text = "gildenmeister"
search.scripts["hook:OnTextChanged"]()
assert(not bar.shown, "1 Treffer: keine Scrollleiste")
search.text = ""
print("OK: 0.4.5a - Mitgliederverzeichnis: Spalten, Scrollen, Mausrad, nur online, Suche, Sortierung")
