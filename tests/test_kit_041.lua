-- Offline-Test: ONE Kit Schriftstufen und Kontrast (0.4.1a). Run: lua tests/test_kit_041.lua src
local root = arg[1] or "src"
local fonts = {}
CreateFont = function(name)
    local f = {name = name}
    function f:SetFont(file, size, flags) self.file, self.size, self.flags = file, size, flags end
    function f:SetShadowOffset(x, y) self.shadow = {x, y} end
    function f:SetShadowColor(...) self.shadowColor = {...} end
    function f:GetName() return self.name end
    fonts[name] = f
    return f
end
GameFontNormal = {GetFont = function() return "Fonts\\FRIZQT__.TTF", 12 end}
local function FontString(blizzard)
    local s = {object = {GetName = function() return blizzard end}}
    function s:GetFontObject() return self.object end
    function s:SetFontObject(o) self.object = o end
    function s:SetTextColor(r, g, b) self.color = {r, g, b} end
    return s
end
local ONE = {db = {theme = {selected = "forge", foreverIntroduced = true}}}
assert(loadfile(root .. "/ONE_Core/Skin.lua"))("ONE_Core", ONE)
assert(loadfile(root .. "/ONE_Core/Themes.lua"))("ONE_Core", ONE)
assert(loadfile(root .. "/ONE_Core/Kit.lua"))("ONE_Core", ONE)
ONE.Themes:Initialize()
local toc = assert(io.open(root .. "/ONE_Core/ONE_Core.toc")):read("*a")
assert(toc:find("Themes.lua\nKit.lua", 1, true), "Kit laedt direkt nach Themes")

-- Kleine Blizzard-Schrift wird zur groesseren ONE-Stufe mit Schatten
local small = FontString("GameFontHighlightSmall")
ONE.Themes:RegisterText(small, "soft")
assert(small.object == fonts.ONEFont_small and small.__oneKitLevel == "small")
assert(fonts.ONEFont_small.size == 11.5 and fonts.ONEFont_small.file:find("Inter", 1, true), "Inter 11,5 pt statt Blizzard 10 pt")
local huge = FontString("GameFontNormalHuge")
ONE.Themes:RegisterText(huge, "text")
assert(huge.object == fonts.ONEFont_title and fonts.ONEFont_title.size == 20)
-- Unbekannte Schrift bleibt unangetastet
local other = FontString("NumberFontNormal")
ONE.Themes:RegisterText(other, "text")
assert(other.object.GetName() == "NumberFontNormal")

-- Schriftgroesse im Kreis 100 -> 110 -> 125 -> 90 -> 100, wirkt auf alle Stufen
assert(ONE.Kit:CycleFontScale() == 1.1 and math.abs(fonts.ONEFont_small.size - 12.65) < .001)
assert(ONE.Kit:CycleFontScale() == 1.25)
assert(ONE.Kit:CycleFontScale() == .9)
assert(ONE.Kit:CycleFontScale() == 1 and ONE.db.kit.fontScale == 1)

-- Kontrast: Nebentext wird hell, Fliesstext weiss
local forge = ONE.Themes:Get()
local normalSoft = small.color
assert(math.abs(normalSoft[1] - forge.soft[1]) < .001)
assert(ONE.Kit:ToggleContrast() == "high")
assert(small.color[1] == forge.text[1], "Kontrast hoch: Nebentext = Fliesstextfarbe")
local body = FontString("GameFontHighlight")
ONE.Themes:RegisterText(body, "text")
assert(body.color[1] == 1 and body.color[2] == 1 and body.color[3] == 1)
assert(ONE.Kit:ToggleContrast() == "normal")
assert(math.abs(small.color[1] - forge.soft[1]) < .001)

-- Native Palette: Fliesstext weiss, Nebentext hell (Lesbarkeit)
assert(forge.text[1] > .9 and forge.soft[1] > .7, "Nachtroute: Fliesstext fast weiss, Nebentext hell")
print("OK: 0.4.1a - Kit: groessere Schriftstufen mit Schatten, Schriftgroesse, Kontrast")
