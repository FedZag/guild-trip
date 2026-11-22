-- Offline-Test 0.7.8: keine abgeschnittenen Saetze (Nutzerwunsch 22.11.2026).
-- 1) Waechter: einzeilige Texte nur ueber ONE.Fit:Line – nirgends sonst SetWordWrap(false).
-- 2) Fit:Line setzt die Schrift enger (hoechstens 2 Punkte) und zeigt den vollen Text im Tooltip.
-- 3) Fit:Wrap bricht um; spaeteres SetWordWrap(true) hebt die Einzeiligkeit wirklich auf.
local root = arg[1] or "src"

-- 1) Waechter ueber alle Lua-Dateien
local files = {}
local p = io.popen('find "' .. root .. '" -name "*.lua"')
for f in p:lines() do files[#files + 1] = f end
p:close()
assert(#files > 50, "Quelldateien gefunden")
local bad = {}
for _, f in ipairs(files) do
    if not f:match("ONE_Core/Fit%.lua$") then
        local n = 0
        for line in io.lines(f) do
            n = n + 1
            if line:find("SetWordWrap%(%s*false%s*%)") and not line:match("^%s*%-%-") then bad[#bad + 1] = f .. ":" .. n end
        end
    end
end
assert(#bad == 0, "einzeilige Texte bitte ueber ONE.Fit:Line (sonst „…“ ohne Tooltip):\n" .. table.concat(bad, "\n"))
local toc = assert(io.open(root .. "/ONE_Core/ONE_Core.toc")):read("*a")
assert(toc:find("Fit.lua", 1, true) and toc:find("Fit.lua", 1, true) < toc:find("Glass.lua", 1, true), "Fit laedt frueh")

-- 2) Schrift enger, Tooltip
local tip = {lines = {}, shown = false}
GameTooltip = {
    SetOwner = function(self, o) self.owner = o self.lines = {} end,
    SetText = function(self, t) self.lines = {t} end,
    AddLine = function(self, t) self.lines[#self.lines + 1] = t end,
    Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
    IsOwned = function(self, o) return self.owner == o end, IsShown = function(self) return self.shown end,
    NumLines = function(self) return #self.lines end,
}
tip = GameTooltip
local function Frame(kind, parent)
    local f = {kind = kind or "Frame", parent = parent, scripts = {}, mouse = false}
    function f:GetObjectType() return self.kind end
    function f:SetScript(e, fn) self.scripts[e] = fn end
    function f:HookScript(e, fn)
        local old = self.scripts[e]
        self.scripts[e] = old and function(...) old(...) fn(...) end or fn
    end
    function f:EnableMouse(on) self.mouse = on end
    function f:IsMouseEnabled() return self.mouse end
    function f:SetPoint() end
    return f
end
CreateFrame = function(kind, _, parent) return Frame(kind, parent) end
-- Schrift: 7 Pixel je Zeichen und Punkt/10 (Groesse 12 -> 8,4 px je Zeichen)
local function FontString(parent, width)
    local fs = {parent = parent, width = width, size = 12, text = "", wrap = true, maxLines = 0, shown = true}
    function fs:GetParent() return self.parent end
    function fs:SetWordWrap(on) self.wrap = on end
    function fs:SetMaxLines(n) self.maxLines = n end
    function fs:SetText(t) self.text = t or "" end
    function fs:GetText() return self.text end
    function fs:GetFont() return "font", self.size, "" end
    function fs:SetFont(_, s) self.size = s end
    function fs:GetWidth() return self.width end
    function fs:GetStringWidth() return #self.text * self.size * .7 end
    function fs:IsTruncated() return self.maxLines == 1 and self:GetStringWidth() > self.width end
    function fs:IsVisible() return self.shown end
    function fs:SetHeight(h) self.height = h end
    function fs:SetJustifyV() end
    return fs
end
local ONE = {}
assert(loadfile(root .. "/ONE_Core/Fit.lua"))("ONE_Core", ONE)
local Fit = ONE.Fit

-- passt mit 1 Punkt weniger: kein Tooltip noetig
local row = Frame("Button")
local cell = FontString(row, 90)
Fit:Line(cell, row)
assert(cell.wrap == false and cell.maxLines == 1)
cell:SetText("Kochkunst ab")      -- 12 Zeichen: 100,8 px bei 12, 92,4 bei 11, 84 bei 10
assert(cell.size == 10 and not Fit.Truncated(cell), "etwas enger statt abschneiden")
cell:SetText("Kurz")
assert(cell.size == 12, "kurzer Text wieder in voller Groesse")
-- passt auch 2 Punkte kleiner nicht: Tooltip mit vollem Text
cell:SetText("Schneiderei: Experte ab Fertigkeit 125")
assert(cell.size == 10 and Fit.Truncated(cell))
row.scripts.OnEnter(row)
assert(tip.shown and tip.lines[1] == "Schneiderei: Experte ab Fertigkeit 125", "voller Text im Tooltip")
row.scripts.OnLeave(row)
assert(not tip.shown)
-- eigener Tooltip des Knopfes (spaeter gesetzt): voller Text kommt dazu, nicht doppelt
row:SetScript("OnEnter", function(self) tip:SetOwner(self) tip:SetText("Lehrer") tip:Show() end)
row.scripts.OnEnter(row)
assert(tip.lines[1] == "Lehrer" and tip.lines[2] == "Schneiderei: Experte ab Fertigkeit 125" and #tip.lines == 2)
-- Text auf einem Knopf ohne Angabe: der Knopf zeigt den Tooltip (keine Flaeche, die Klicks schluckt)
local btn = Frame("Button")
local label = FontString(btn, 40)
Fit:Line(label)
assert(btn.__fitTexts and btn.__fitTexts[1] == label and not label.__fitOverlay)
-- freistehende Zeile: unsichtbare Flaeche ueber dem Text
local card = Frame("Frame")
local line = FontString(card, 40)
Fit:Line(line)
assert(line.__fitOverlay and not line.__fitOverlay.mouse and not card.mouse, "Flaeche nur ueber dem Text, erst bei Bedarf")
line:SetText("viel zu langer Text")
assert(line.__fitOverlay.mouse, "gekuerzt: Flaeche nimmt die Maus")
line:SetText("ok")
assert(not line.__fitOverlay.mouse, "passt: Flaeche verdeckt nichts")
-- false = kein Tooltip
local free = FontString(card, 40)
Fit:Line(free, false)
assert(not free.__fitOverlay)

-- 3) Umbrechen
local hint = FontString(card, 200)
Fit:Wrap(hint)
assert(hint.wrap and hint.maxLines == 0 and hint.height == 0)
local helper = FontString(card, 200)
Fit:Line(helper)
helper:SetWordWrap(true)
assert(helper.maxLines == 0 and not helper.__fitLine, "spaeter umbrechen = wirklich umbrechen")
helper:SetText(string.rep("lang ", 40))
assert(helper.size == 12, "umbrochener Text wird nicht verkleinert")
print("OK test_fit_152")
