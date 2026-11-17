-- Offline-Test 0.6.0: Lern-Reihenfolge beim Klassenlehrer.
local root = arg[1] or "src"
local function Region(kind, parent, name, template)
    local r = {kind = kind, parent = parent, name = name, template = template, shown = true, scripts = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:SetPoint(...) self.point = {...} end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, name, parent, template) return Region(kind, parent, name, template) end
UIParent = Region("Frame")
UnitClass = function() return "Priester", "PRIEST" end
UnitLevel = function() return 22 end
local spells = {[8092] = "Gedankenschlag", [589] = "Schattenwort: Schmerz", [17] = "Machtwort: Schild", [2061] = "Blitzheilung",
    [1243] = "Machtwort: Seelenstärke", [585] = "Heilige Pein", [591] = "Göttliche Pein", [5019] = "Schießen", [139] = "Erneuerung"}
local book = {8092, 589, 17, 2061, 1243, 585, 139}
Enum = {SpellBookSpellBank = {Player = 0}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(t) if t == 1 then return {itemIndexOffset = 0, numSpellBookItems = 0} end
        return {itemIndexOffset = 0, numSpellBookItems = #book} end,
    GetSpellBookItemInfo = function(i) local id = book[i]; return {spellID = id, name = spells[id], iconID = id} end,
}
C_Spell = {GetSpellInfo = function(id) return spells[id] and {name = spells[id], iconID = id} end}
-- Lehrer-Angebot (inkl. Filter: "used" ist ausgeblendet, bis Guild Trip alles zeigt)
local services = {
    {"Priester", nil, "header"},
    {"Göttliche Pein", "Rang 4", "available", 900},
    {"Machtwort: Seelenstärke", "Rang 3", "available", 1200},
    {"Gedankenschlag", "Rang 3", "available", 1500},
    {"Blitzheilung", "Rang 2", "available", 1000},
    {"Schattenwort: Schmerz", "Rang 4", "available", 1300},
    {"Erneuerung", "Rang 4", "unavailable", 1100},
    {"Machtwort: Schild", "Rang 3", "used", 0},
}
local filter = {available = true, unavailable = true, used = false}
GetTrainerServiceTypeFilter = function(t) return filter[t] end
SetTrainerServiceTypeFilter = function(t, v) filter[t] = v == 1 end
local function Visible() local out = {} for _, s in ipairs(services) do if s[3] == "header" or filter[s[3]] then out[#out + 1] = s end end return out end
GetNumTrainerServices = function() return #Visible() end
GetTrainerServiceInfo = function(i) local s = Visible()[i]; if s then return s[1], s[2], s[3] end end
GetTrainerServiceCost = function(i) local s = Visible()[i]; return s and s[4] end
GetTrainerServiceLevelReq = function() return 22 end
local money = 4000
GetMoney = function() return money end
local bought = {}
BuyTrainerService = function(i) local s = Visible()[i]; bought[#bought + 1] = s[1]; s[3] = "used"; money = money - s[4] end

local ONE = {db = {}}
_G.ProjectONE = ONE
local printed = {}
function ONE:Print(m) printed[#printed + 1] = m end
local c = {}
for _, f in ipairs({"Data.lua", "Player.lua", "Trainer.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
local confirmText
c.Bars = {Confirm = function(_, text, ok) confirmText = text ok() end}
local Tr = c.Trainer

-- 1) Reihenfolge fuer Schatten: Leiste 1 (Schlag 1, Schmerz 2) > Leiste 2 (Blitzheilung) > Leiste 3 (Seelenstaerke) > optional
local list, m, isClass = Tr:Plan()
local names = {}
for i, s in ipairs(list) do names[i] = s.name .. (s.affordable and "+" or (s.recommended and "!" or "-")) end
assert(isClass and m == 4000)
assert(table.concat(names, ",") == "Gedankenschlag+,Schattenwort: Schmerz+,Blitzheilung+,Machtwort: Seelenstärke!,Göttliche Pein-",
    table.concat(names, ","))
assert(filter.used == false, "Filter des Spielers zurueckgestellt")

-- 2) Anzeige: Kosten, Gold, fehlendes Geld
local shown = Tr:Refresh()
local f = Tr.frame
assert(f.shown and f.rows[1].text:find("1  Gedankenschlag (Rang 3)", 1, true) and f.rows[5].text:find("optional", 1, true))
assert(f.summary.text:find("Empfohlen: 3 Zauber", 1, true) and f.summary.text:find("1 weitere empfohlen", 1, true))
assert(f.buy.shown)

-- 3) Kaufen: Rueckfrage, dann nacheinander (Nummern jedes Mal neu)
Tr:AskAndBuy()
assert(confirmText:find("3 empfohlene Zauber", 1, true))
assert(table.concat(bought, ",") == "Gedankenschlag,Schattenwort: Schmerz,Blitzheilung", table.concat(bought, ","))
assert(money == 200 and printed[#printed]:find("3 Zauber gelernt", 1, true))
assert(f.rows[1].text:find("Machtwort: Seelenstärke", 1, true), "danach steht Seelenstaerke oben")

-- 4) Berufslehrer: keine Anzeige
services = {{"Bergbau", "Geselle", "available", 500}}
f:Hide()
Tr:Refresh()
assert(not f.shown, "kein Klassenlehrer")

-- 5) Abschaltbar
services = {{"Gedankenschlag", "Rang 4", "available", 100}}
ONE.db.classGuide.trainerAdvice = false
Tr:Refresh()
assert(not f.shown)
print("OK test_trainer_060")
