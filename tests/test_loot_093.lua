-- Offline-Test: Beute-Fenster – Meldungen lesen (wer, was, Anzahl), Wuerfel-Zeilen ignorieren, Filter nach Qualitaet.
local root = arg[1] or "src"
LOOT_ITEM = "%s erhält Beute: %s."
LOOT_ITEM_MULTIPLE = "%s erhält Beute: %sx%d."
LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s."
UnitName = function() return "Ich" end
GetItemInfo = function(link) if link:find("1234") then return "Schwert", link, 4 end if link:find("5678") then return "Fetzen", link, 0 end return nil end
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {Chat = {}, UI = {}}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
assert(loadfile(root .. "/ONE_Chat/LootWindow.lua"))("ONE_Chat", c)
local L = c.Loot
local sword = "|cffa335ee|Hitem:1234::::::::|h[Schwert]|h|r"
local rag = "|cff9d9d9d|Hitem:5678::::::::|h[Fetzen]|h|r"
local e = L.Parse("Thrall-Forever erhält Beute: " .. sword .. ".", "Thrall-Forever", "G1")
assert(e and e.who == "Thrall" and e.link == sword and e.quality == 4 and e.count == 1, e and e.who)
e = L.Parse("Ihr erhaltet Beute: " .. rag .. ".", "", nil)
assert(e and e.who == "Ich" and e.quality == 0)
e = L.Parse("Jaina erhält Beute: " .. rag .. "x3.", "Jaina", nil)
assert(e and e.who == "Jaina" and e.count == 3, e and e.count)
assert(L.Parse("Thrall würfelt Bedarf für " .. sword, "Thrall", nil) == nil, "Wuerfeln ist keine Beute")
-- 0.7.0: Empfaenger aus dem Text, auch ohne Verfasser (vorher griff das Muster nie)
e = L.Parse("Jaina erhält Beute: " .. sword .. ".", "", nil)
assert(e and e.who == "Jaina", e and e.who)
assert(L.Parse("Hallo", "x", nil) == nil)
-- Verlauf und Mindestqualitaet
L:Add(L.Parse("Ihr erhaltet Beute: " .. rag .. ".", "", nil))
L:Add(L.Parse("Thrall erhält Beute: " .. sword .. ".", "Thrall", nil))
assert(#L.entries == 2 and L:MinQuality() == 2)
print("OK test_loot_093")
