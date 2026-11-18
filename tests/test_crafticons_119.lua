-- Berufe 0.8: Rezept-Symbole und Zutaten aus dem Berufsfenster, "wie oft herstellbar".
local root = arg[1] or "src"
local ONE = {db = {}}
_G.ProjectONE = ONE
local crafting = {}
local bag = {[2840] = 8, [1206] = 1, [2589] = 0}
C_Item = {
    GetItemIconByID = function(id) return id == 3473 and 135000 or nil end,
    GetItemCount = function(id) return bag[id] or 0 end,
}
C_Spell = {GetSpellTexture = function(id) return id == 7418 and 136244 or nil end}
-- neuer Weg: GetRecipeSchematic
C_TradeSkillUI = {GetRecipeSchematic = function(id)
    if id == 3328 then
        return {reagentSlotSchematics = {
            {reagents = {{itemID = 2840}}, quantityRequired = 6, reagentType = 1},
            {reagents = {{itemID = 1206}}, quantityRequired = 1, reagentType = 1},
            {reagents = {{itemID = 9999}}, quantityRequired = 1, reagentType = 0}, -- optional: weglassen
        }}
    end
end}
assert(loadfile(root .. "/ONE_Crafting/Recipes.lua"))("ONE_Crafting", crafting)
local R = crafting.Recipes

local list = R:ReadReagents(3328)
assert(#list == 2 and list[1][1] == 2840 and list[1][2] == 6 and list[2][1] == 1206, "Pflichtzutaten mit Menge")
R:Store().reagents[3328] = list
assert(R:Craftable(3328) == 1, "8 Kupferbarren / 6 und 1 Malachit -> einmal")
bag[2840] = 3
assert(R:Craftable(3328) == 0)
assert(R:Craftable(1) == nil, "unbekannte Zutaten -> nil")

-- alter Weg: Anzahl + Links
C_TradeSkillUI = {
    GetRecipeNumReagents = function() return 2 end,
    GetRecipeReagentInfo = function(_, i) return "x", 1, i == 1 and 2 or 1 end,
    GetRecipeReagentItemLink = function(_, i) return i == 1 and "|cffffffff|Hitem:2589::::|h[Leinenstoff]|h|r" or "|Hitem:2320:|h" end,
}
list = R:ReadReagents(2387)
assert(#list == 2 and list[1][1] == 2589 and list[1][2] == 2 and list[2][1] == 2320)

-- Symbole: Gegenstand, sonst gemerktes Rezeptsymbol, sonst Zaubersymbol (Verzauberungen)
assert(R:Icon(3326, 3473) == 135000)
R:Store().icons[7420] = 555
assert(R:Icon(7420, 0) == 555)
assert(R:Icon(7418, 0) == 136244, "Verzauberung ohne Gegenstand: Zaubersymbol statt Fragezeichen")
print("OK test_crafticons_119")
