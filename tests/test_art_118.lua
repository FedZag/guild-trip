-- Dungeon-Bilder (Art.lua): Ausschnitt passt zur Flaeche, bleibt im Bildbereich, jeder
-- Katalog-Dungeon hat ein Bild, Aufhellung nur fuer dunkle Bilder.
local root = arg[1] or "src"
local dungeons = {}
assert(loadfile(root .. "/ONE_Dungeons/Art.lua"))("ONE_Dungeons", dungeons)
local Art = dungeons.Art

local function near(a, b) return math.abs(a - b) < 1e-6 end
local ratio = {classic = 4 / 3, forever = 2992 / 1684}
local band = {classic = {.17, .80}, forever = {266 / 1684, 1418 / 1684}}
for key, e in pairs(Art.data) do
    for _, aspect in ipairs({1, 4.75, 150 / 84, 2.24}) do
        local l, r, t, b = Art.Crop(e, aspect)
        assert(l >= 0 and r <= 1 + 1e-9 and l < r, key .. ": links/rechts")
        assert(t >= band[e[4]][1] - 1e-9 and b <= band[e[4]][2] + 1e-9 and t < b, key .. ": ausserhalb des Gemaeldes")
        assert(near((r - l) * ratio[e[4]] / (b - t), aspect), key .. ": Seitenverhaeltnis verzerrt")
    end
end

-- Jeder Dungeon im Katalog hat ein Bild
local src = assert(io.open(root .. "/ONE_Dungeons/Catalog.lua")):read("*a")
local n = 0
for key in src:gmatch('key = "([%w]+)"') do
    n = n + 1
    assert(Art:Has(key), "kein Bild fuer " .. key)
end
assert(n >= 30)

-- Apply: Textur, Ausschnitt, Aufhellung
local function Tex()
    local t = {shown = true}
    function t:SetTexture(f) self.file = f end
    function t:SetTexCoord(...) self.tc = {...} end
    function t:SetVertexColor(...) self.v = {...} end
    function t:SetBlendMode(m) self.blend = m end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end
local pic, lift = Tex(), Tex()
assert(Art:Apply(pic, "stocks", 4, lift))
assert(pic.file == 131870 and #pic.tc == 4 and lift.shown and lift.blend == "ADD" and lift.v[4] == 1)
assert(Art:Apply(pic, "dm", 4, lift) and not lift.shown, "helles Bild ohne Aufhellung")
assert(not Art:Apply(pic, "gibtsnicht", 4, lift))
print("OK test_art_118")
