-- Offline-Test 0.6.0: Buff-Erinnerung ueber den Leisten.
local root = arg[1] or "src"
local function Region(kind, parent, name, template)
    local r = {kind = kind, parent = parent, name = name, template = template, shown = true, scripts = {}, attr = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:SetTexture(t) self.texture = t end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:SetPoint(...) self.point = {...} end
    function r:SetAttribute(k, v) self.attr[k] = v end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    function r:GetParent() return self.parent end
    function r:GetPoint() return "BOTTOM", UIParent, "BOTTOM", 12, 250 end
    return r
end
local created = {}
CreateFrame = function(kind, name, parent, template)
    local r = Region(kind, parent, name, template)
    created[#created + 1] = r
    return r
end
UIParent = Region("Frame")
local drivers = {}
RegisterStateDriver = function(frame, state, rule) drivers[#drivers + 1] = {frame = frame, state = state, rule = rule} end
GetTime = function() return 1000 end
local combat = false
InCombatLockdown = function() return combat end
UnitClass = function() return "Priester", "PRIEST" end
UnitLevel = function() return 20 end
local spells = {
    [1243] = "Machtwort: Seelenstärke", [21562] = "Gebet der Seelenstärke", [588] = "Inneres Feuer",
    [976] = "Schattenschutz", [27683] = "Gebet des Schattenschutzes", [15473] = "Schattengestalt",
}
local book = {1243, 588}
Enum = {SpellBookSpellBank = {Player = 0}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #book} end,
    GetSpellBookItemInfo = function(i) local id = book[i]; return {spellID = id, name = spells[id], iconID = id} end,
}
local auras = {}
C_Spell = {GetSpellInfo = function(id) return spells[id] and {name = spells[id], iconID = id} end}
C_UnitAuras = {GetAuraDataByIndex = function(_, i) return auras[i] end}
issecretvalue = function(v) return v == "GEHEIM" end

local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
for _, f in ipairs({"Data.lua", "Player.lua", "Buffs.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
c.Player.maxAge = 0 -- Test aendert Zauber/Talente ohne Spielereignisse: Zwischenspeicher aus
local B = c.Buffs

local function Names(list) local out = {} for i, e in ipairs(list) do out[i] = e.name end return table.concat(out, ",") end

-- 1) Nichts aktiv: Seelenstaerke und Inneres Feuer fehlen (Schattenschutz/-gestalt noch nicht gelernt)
local list = B:Update()
assert(Names(list) == "Machtwort: Seelenstärke,Inneres Feuer", Names(list))
local f = B.frame
assert(f and f.label.text == "Buffs fehlen" and #drivers == 1 and drivers[1].rule == "[combat] hide; show", "Zeile + Kampf-Ausblendung")
local b1 = f.buttons[1]
assert(b1.template == "SecureActionButtonTemplate" and b1.attr.type == "spell" and b1.attr.spell == "Machtwort: Seelenstärke"
    and b1.attr.unit == "player", "Klick wirkt den Buff auf dich")

-- 2) Gebet der Seelenstaerke von einem anderen Priester zaehlt; Inneres Feuer laeuft bald aus
auras = {{name = "Gebet der Seelenstärke", expirationTime = 4000}, {name = "Inneres Feuer", expirationTime = 1030}}
list = B:Update()
assert(Names(list) == "Inneres Feuer" and list[1].left == 30 and f.buttons[1].time.text == "30s", "bald auslaufend mit Restzeit")
assert(not f.buttons[2].shown, "zweiter Knopf ausgeblendet")
-- 3) Alles da (ohne Ablauf oder lange genug): Zeile leer
auras = {{name = "Machtwort: Seelenstärke", expirationTime = 0}, {name = "Inneres Feuer", expirationTime = 1700}}
list = B:Update()
assert(#list == 0 and f.label.text == "" and not f.buttons[1].shown, "nichts fehlt")

-- 4) Schattengestalt gelernt: nur bei Schatten
book[#book + 1] = 15473
list = B:Update()
assert(Names(list) == "Schattengestalt", "Schatten: Gestalt fehlt")
ONE.db.classGuide.spec = 2
list = B:Update()
assert(#list == 0, "Heilig: keine Schattengestalt")
ONE.db.classGuide.spec = nil
auras[3] = {name = "Schattengestalt", expirationTime = 0}
assert(#B:Update() == 0)

-- 5) Gesperrte (geheime) Werte werden uebersprungen, kein Absturz
auras = {{name = "GEHEIM", expirationTime = "GEHEIM"}}
list = B:Update()
assert(#list == 3, "geheim = wie nicht vorhanden")

-- 6) Im Kampf: nichts aendern, danach nachholen
combat = true
auras = {}
assert(B:Update() == nil and B.dirty == true and #B.shown == 3, "im Kampf unveraendert")
combat = false
assert(#B:Update() == 3 and not B.dirty)

-- 7) Abschalten
B:SetEnabled(false)
assert(#B.shown == 0 and not f.buttons[1].shown and ONE.db.classGuide.buffReminder == false)
B:SetEnabled(true)
assert(#B.shown == 3)

-- 8) Verschieben merkt die Position
f.buttons[1].scripts.OnDragStop(f.buttons[1])
assert(ONE.db.classGuide.buffPos.x == 12 and ONE.db.classGuide.buffPos.y == 250)
print("OK test_buffs_058")
