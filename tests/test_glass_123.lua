-- 0.7.1 Glas-Aussehen: Skins, eigene Farben (lesbar gedeckelt), Deckkraft, Standard Glas.
local root = arg[1] or "src"
local ONE = { db = {} }
local Glass = assert(loadfile(root .. "/ONE_Core/Glass.lua"))("ONE_Core", ONE)
assert(ONE.Glass == Glass)
-- ohne gespeicherte Wahl: Glas, Skin Azeroth, 80 %
assert(Glass:Active(), "Glas ist Standard")
assert(Glass:SkinId() == "azeroth")
local p = Glass:Palette()
assert(math.abs(p.alpha - .80) < 1e-9)
assert(p.glow[1] == 1 and math.abs(p.glow[2] - 209 / 255) < 1e-9, "Blizzard-Gold")
-- Blizzard-Look waehlbar
ONE.db.theme.look = "native"
assert(not Glass:Active())
ONE.db.theme.look = "glass"
assert(Glass:Active())
-- alle fertigen Skins vollstaendig
for _, id in ipairs(Glass.order) do
    assert(Glass:SetSkin(id), id)
    local q = Glass:Palette()
    assert(q.tint and q.glow and q.title and q.onGlow, id)
end
assert(not Glass:SetSkin("gibtsnicht"))
-- eigene Farben: helle Toenung wird abgedunkelt (weisse Schrift bleibt lesbar)
Glass:SetCustom("tint", 1, 1, 1)
local c = Glass:Palette()
assert(Glass:SkinId() == "custom")
assert(Glass.Luma(c.tint) <= .2201, "Toenung gedeckelt")
-- dunkle Leuchtfarbe: Ueberschrift wird aufgehellt, Knopfschrift weiss
Glass:SetCustom("glow", .1, 0, .2)
c = Glass:Palette()
assert(Glass.Luma(c.title) > Glass.Luma(c.glow))
assert(c.onGlow[1] == 1)
-- helle Leuchtfarbe: dunkle Knopfschrift
Glass:SetCustom("glow", 1, .9, .3)
assert(Glass:Palette().onGlow[1] < .2)
-- Werte ausserhalb 0..1 werden begrenzt
Glass:SetCustom("glow", 5, -1, .5)
c = Glass:Palette()
assert(c.glow[1] == 1 and c.glow[2] == 0)
-- Deckkraft 40..100 %
Glass:SetAlpha(.1) assert(math.abs(Glass:Palette().alpha - .4) < 1e-9)
Glass:SetAlpha(2) assert(Glass:Palette().alpha == 1)
-- Zuruecksetzen
Glass:Reset()
assert(Glass:SkinId() == "azeroth" and math.abs(Glass:Palette().alpha - .8) < 1e-9)
assert(not Glass:SetCustom("rand", 1, 1, 1))
print("OK test_glass_123")
