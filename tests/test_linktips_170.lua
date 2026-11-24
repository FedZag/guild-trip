-- Offline-Test: Link-Tooltips mit Guild-Trip-Wissen (Chat-Ideen 24.11.2026)
-- Gegenstand: Hersteller in der Gilde + Knopf "Bei … anfragen"; Waffe: Klasse kann sie nicht fuehren / erst lernen.
-- Quest: erledigt / im Log / Stufe / Start + Knopf "Navi zum Start". Gilt fuer Maus-Tooltip und Klick-Tooltip.
local root = arg[1] or "src"
local ONE = {db = {}, modules = {}}
_G.ProjectONE = ONE
function ONE:FeatureOn() return true end
function ONE:Whisper(name, text) self.whispered = {name, text} return true end

-- Tooltips und Knoepfe
local hooks = {}
hooksecurefunc = function(t, name, fn) hooks[#hooks + 1] = {t = t, name = name, fn = fn} end
local function Tip(name)
    local tt = {name = name, lines = {}, scripts = {}}
    function tt:SetHyperlink(link) self.lines = {} self.link = link
        for _, h in ipairs(hooks) do if h.t == self and h.name == "SetHyperlink" then h.fn(self, link) end end
    end
    function tt:AddLine(text, r, g, b) self.lines[#self.lines + 1] = {text, r, g, b} end
    function tt:Show() self.shown = true end
    function tt:HookScript(k, fn) self.scripts[k] = fn end
    return tt
end
GameTooltip, ItemRefTooltip = Tip("GameTooltip"), Tip("ItemRefTooltip")
CreateFrame = function(kind)
    local b = {scripts = {}, kind = kind}
    function b:SetHeight() end function b:SetWidth(w) self.w = w end function b:SetPoint() end
    function b:SetScript(k, fn) self.scripts[k] = fn end
    function b:SetText(t) self.text = t end function b:GetFontString() return nil end
    function b:Show() self.shown = true end function b:Hide() self.shown = false end
    return b
end
assert(loadfile(root .. "/ONE_Core/LinkTips.lua"))("ONE_Core", ONE)
local LT = ONE.LinkTips
assert(LT and #hooks == 2, "beide Tooltips eingehakt")
assert(LT.Raw("|cffffffff|Hitem:2589::::|h[Leinenstoff]|h|r") == "item:2589::::", "Link aus Chattext")

-- ===== Hersteller (ONE_Crafting/ItemTip.lua) =====
local crafting = {}
local catalog = {
    {recipeID = 1, itemID = 2580, prof = "Schneiderei", crafters = {{name = "Aventorin-Forever"}, {name = "Brakk", chat = true}}},
    {recipeID = 2, itemID = 2580, prof = "Schneiderei", crafters = {{name = "Ich", me = true}, {name = "Mira"}}},
    {recipeID = 3, itemID = 0, prof = "Schneiderei", trade = true, crafters = {{name = "Zed"}}},
}
crafting.Recipes = {Catalog = function() return catalog end}
local asked
crafting.Page = {OnlineSet = function() return {mira = true} end, Ask = function(_, entry, crafter) asked = {entry, crafter} end}
assert(loadfile(root .. "/ONE_Crafting/ItemTip.lua"))("ONE_Crafting", crafting)
GameTooltip:SetHyperlink("item:2580::::::::")
local all = {}
for _, l in ipairs(GameTooltip.lines) do all[#all + 1] = l[1] end
local text = table.concat(all, "\n")
assert(text:find("Das kannst du selbst herstellen", 1, true), text)
assert(text:find("Herstellen kann Mira |cff40ff40(online)|r, Aventorin, Brakk |cff9d9d9d(Chat)|r", 1, true), "online zuerst, Chat zuletzt: " .. text)
assert(not LT.button or not LT.button.shown, "Maus-Tooltip: kein Knopf")
ItemRefTooltip:SetHyperlink("item:2580::::::::")
assert(LT.button and LT.button.shown and LT.button.text == "Bei Mira anfragen", "Klick-Tooltip: Knopf " .. tostring(LT.button and LT.button.text))
LT.button.scripts.OnClick(LT.button)
assert(asked and asked[2].name == "Mira", "Anfrage an Mira")
ItemRefTooltip:SetHyperlink("item:9999")
assert(not LT.button.shown and #ItemRefTooltip.lines == 0, "anderer Gegenstand: nichts")
ItemRefTooltip:SetHyperlink("item:2580")
ItemRefTooltip.scripts.OnHide()
assert(not LT.button.shown, "Tooltip zu: Knopf weg")

-- ===== Quests (ONE_Nav/QuestTip.lua) =====
GuildTripQuestDB = {
    q = {
        [100] = {12, 9, 77, 0, false, {500}, {500}, {}, false, false, 900},
        [101] = {30, 25, 77, 0, false, {500}, {500}, {}, false, false, 900},
        [102] = {10, 1, 178, 0, false, {500}, {500}, {}, false, false, 900},
        [103] = {12, 9, 77, 0, false, {500}, {500}, {501}, false, false, 900},
    },
    n = {[500] = {3, 1429, 420, 655}, [501] = {3, 1429, 300, 300}},
    names = {[500] = "Marschall Dughan"},
    titles = {[100] = "Die Volksmiliz", [103] = "Wölfe jagen"},
}
local done, inlog = {}, {}
C_QuestLog = {IsQuestFlaggedCompleted = function(id) return done[id] == true end,
    GetLogIndexForQuestID = function(id) return inlog[id] end, IsComplete = function() return false end}
C_Map = {GetMapInfo = function(id) return id == 1429 and {name = "Wald von Elwynn"} or nil end,
    GetBestMapForUnit = function() return 1429 end}
UnitLevel = function() return 11 end
UnitFactionGroup = function() return "Alliance" end
UnitRace = function() return "Human", "Human" end
UnitClass = function() return "Krieger", "WARRIOR" end
UnitXPMax = function() return 5000 end
local pointed
ONE.modules.nav = {PointTo = function(_, label, map, x, y) pointed = {label, map, x, y} return true end}
local nav = {}
assert(loadfile(root .. "/ONE_Nav/QuestDB.lua"))("ONE_Nav", nav)
assert(loadfile(root .. "/ONE_Nav/QuestLevels.lua"))("ONE_Nav", nav)
assert(loadfile(root .. "/ONE_Nav/QuestTip.lua"))("ONE_Nav", nav)
local function Lines(tt) local o = {} for _, l in ipairs(tt.lines) do o[#o + 1] = l[1] end return table.concat(o, "\n") end
ItemRefTooltip:SetHyperlink("quest:100:12")
local q = Lines(ItemRefTooltip)
assert(q:find("Stufe 12 – passt zu dir", 1, true) and q:find("EP", 1, true), q)
assert(q:find("Beginnt bei Marschall Dughan (Wald von Elwynn)", 1, true), q)
assert(LT.button.shown and LT.button.text == "Navi zum Start", "Navi-Knopf")
LT.button.scripts.OnClick(LT.button)
assert(pointed and pointed[1] == "Marschall Dughan" and pointed[2] == 1429 and math.abs(pointed[3] - .42) < 1e-9, "Navi zum Questgeber")
GameTooltip:SetHyperlink("quest:101:30")
assert(Lines(GameTooltip):find("erst ab Stufe 25 (du bist 11)", 1, true), Lines(GameTooltip))
GameTooltip:SetHyperlink("quest:102:10")
assert(Lines(GameTooltip):find("Quest der anderen Fraktion", 1, true), Lines(GameTooltip))
done[100] = true
GameTooltip:SetHyperlink("quest:100:12")
assert(Lines(GameTooltip):find("hast du schon erledigt", 1, true) and not Lines(GameTooltip):find("Beginnt", 1, true))
inlog[103] = 4
pointed = nil
ItemRefTooltip:SetHyperlink("quest:103:12")
assert(Lines(ItemRefTooltip):find("steht in deinem Questlog", 1, true))
assert(LT.button.shown and LT.button.text == "Navi zum Ziel", "im Log: Navi zum Ziel")
LT.button.scripts.OnClick(LT.button)
assert(pointed and pointed[1] == "Wölfe jagen" and math.abs(pointed[3] - .3) < 1e-9, "Navi zum Ziel")
-- Funktion aus: nichts
function ONE:FeatureOn(id) return id ~= "nav.questTip" end
GameTooltip:SetHyperlink("quest:101:30")
assert(#GameTooltip.lines == 0, "Quest-Tooltip abschaltbar")

-- ===== Waffen (ONE_Classes/Gear.lua + Weapons.lua) =====
local c = {}
assert(loadfile(root .. "/ONE_Classes/Data.lua"))("ONE_Classes", c)
assert(loadfile(root .. "/ONE_Classes/DataClasses.lua"))("ONE_Classes", c)
assert(loadfile(root .. "/ONE_Classes/Gear.lua"))("ONE_Classes", c)
assert(loadfile(root .. "/ONE_Classes/Weapons.lua"))("ONE_Classes", c)
local G = c.Gear
-- 1: Einhandaxt (Waffe 2/0), 2: Stangenwaffe (2/6), 3: Dolch (2/15)
local info = {[1] = {"INVTYPE_WEAPON", 2, 0}, [2] = {"INVTYPE_2HWEAPON", 2, 6}, [3] = {"INVTYPE_WEAPON", 2, 15}}
GetItemInfoInstant = function(id) local i = info[tonumber(id)] return id, "", "", i[1], 0, i[2], i[3] end
GetItemStats = function() return {ITEM_MOD_STRENGTH_SHORT = 3} end
GetInventoryItemLink = function() return nil end
local mdef = c.Data.classes.MAGE
local r = G:Judge("item:1", {classFile = "MAGE", spec = 1}, mdef, c.Data:Build(mdef, 1, "solo"))
assert(r and r.verdict == "cannot" and r.weapon == "Einhandäxte", "Magier: keine Aexte")
assert(G:Line(r):find("Einhandäxte kann deine Klasse nicht führen", 1, true), G:Line(r))
assert(G:Judge("item:3", {classFile = "MAGE", spec = 1}, mdef, c.Data:Build(mdef, 1, "solo")).verdict ~= "cannot", "Dolch geht")
local known = {[200] = false}
IsPlayerSpell = function(id) return known[id] == true end
local w = G.WeaponToLearn("item:2", "WARRIOR")
assert(w and w.key == "polearm", "Krieger: Stangenwaffen erst lernen")
known[200] = true
assert(G.WeaponToLearn("item:2", "WARRIOR") == nil, "schon gelernt: kein Hinweis")
assert(G.WeaponToLearn("item:1", "MAGE") == nil, "kann es nie: kein Lern-Hinweis (dafuer 'nicht fuehren')")
print("OK test_linktips_170")
