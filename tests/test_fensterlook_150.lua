-- Offline-Test: eigenes Aussehen je Zusatzfenster (Nutzer 22.11.2026): Vorlagen, frei waehlbare Farben
-- (Questgeber-Namen), Hintergrund unsichtbar / leichtes Glas / kraeftiges Glas / dunkel mit Deckkraft.
local root = arg[1] or "src"
local ONE = {db = {}}
function ONE:Print() end
assert(loadfile(root .. "/ONE_Core/WindowLook.lua"))("ONE_Core", ONE)
local WL = ONE.WindowLook
local store, changed = {}, 0
local def = {key = "look", store = function() return store end, defaultPreset = "a", defaultBg = "dark",
    presets = {{value = "a", text = "A", bg = "dark"}, {value = "b", text = "B", bg = "none"}},
    roles = {{key = "giver", label = "Questgeber-Namen", default = {.45, .8, 1}}},
    onChange = function() changed = changed + 1 end}
-- Standard
assert(WL.Preset(def) == "a" and WL.Bg(def) == "dark" and math.abs(WL.Alpha(def) - .72) < 1e-9)
local r, g, b = WL.Color(def, "giver")
assert(r == .45 and g == .8 and b == 1)
assert(WL.Code(def, "giver") == "|cff73ccff", WL.Code(def, "giver"))
-- Vorlage schlaegt Hintergrund vor
WL.Set(def, "preset", "b")
assert(WL.Preset(def) == "b" and WL.Bg(def) == "none" and WL.Alpha(def) == 0 and changed == 1)
-- Glas mit eigener Deckkraft
WL.Set(def, "bg", "glassLight")
assert(math.abs(WL.Alpha(def) - WL.BG.glassLight.alpha) < 1e-9)
store.look.alpha = .4
assert(math.abs(WL.Alpha(def) - .4) < 1e-9)
WL.Set(def, "bg", "glass")
assert(math.abs(WL.Alpha(def) - WL.BG.glass.alpha) < 1e-9, "neue Stufe: deren Deckkraft")
-- eigene Farbe, zuruecksetzen
WL.SetColor(def, "giver", 1, 0, 0)
assert(WL.Code(def, "giver") == "|cffff0000")
WL.ResetColors(def)
assert(WL.Code(def, "giver") == "|cff73ccff")
WL.ResetAll(def)
assert(WL.Preset(def) == "a" and WL.Bg(def) == "dark")
-- unbekannte Werte fallen auf Standard
store.look = {preset = "x", bg = "y"}
assert(WL.Preset(def) == "a" and WL.Bg(def) == "dark")
-- Hintergrund auf Texturen
local function Tex()
    local t = {shown = true}
    function t:SetColorTexture(r2, g2, b2, a) self.c = {r2, g2, b2, a} end
    function t:SetShown(v) self.shown = v end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end
local bg, top, bottom = Tex(), Tex(), Tex()
store.look = {bg = "none"}
WL.ApplyBg(def, bg, {top, bottom})
assert(not bg.shown and not top.shown and not bottom.shown, "unsichtbar")
WL.ApplyBg(def, bg, {top, bottom}, true)
assert(bg.shown and top.shown, "beim Drueberfahren sichtbar (zum Verschieben)")
store.look = {bg = "glassLight"}
WL.ApplyBg(def, bg, {top, bottom})
assert(bg.shown and bg.c[4] < .3 and top.shown and not bottom.shown, "leichtes Glas: zart, helle Oberkante")
store.look = {bg = "dark"}
WL.ApplyBg(def, bg, {top, bottom})
assert(bg.shown and math.abs(bg.c[4] - .72) < 1e-9 and top.shown and bottom.shown)

-- ===== Quest-Kasten =====
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
GuildTripQuestDB = {q = {}, n = {}}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
ONE.modules, ONE.ns = {}, {}
_G.ProjectONE = ONE
local L = {}
for _, f in ipairs({"Planner", "Guide", "Tracker"}) do assert(loadfile(root .. "/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", L) end
local G, Tr = L.Guide, L.Tracker
local db = {}
G.DB = function() return db end
G.NodeName = function() return "Tonga" end
G.Title = function(id) return "Quest " .. id end
G.LevelTitle = function(id) return "[10] Quest " .. id end
G.ZoneName = function() return "Brachland" end
G.Distance = function() return 100 end
-- Questgeber-Namen farbig (Standard hellblau, frei waehlbar)
local who = Tr.NowWhoBase({kind = "accept", nr = 1, actions = {{kind = "accept", id = 5}}})
assert(who:find("|cff73ccffTonga|r", 1, true), who)
db.trackerLook = {colors = {giver = {0, 1, 0}}}
assert(Tr.NowWhoBase({kind = "turnin", nr = 1, actions = {{kind = "turnin", id = 5}}}):find("|cff00ff00Tonga|r", 1, true))
assert(select(2, Tr.RoleColor("giver")) == 1)
-- Vorlagen: Zeilen je Vorlage
local function Step(i) return {kind = "accept", nr = 1, mapID = 1413, x = .5, y = .5, actions = {{kind = "accept", id = i}}} end
local plan = {steps = {}, blocks = {{mapID = 1413, first = 1, last = 8, minutes = 30, xp = 0}}}
for i = 1, 8 do plan.steps[i] = Step(i) plan.steps[i].block = 1 end
local function Kinds(preset)
    db.trackerLook = {preset = preset}
    local rows = Tr:Rows(plan)
    local k, n = {}, 0
    for _, r in ipairs(rows) do k[r.kind] = (k[r.kind] or 0) + 1 end
    return k
end
local k = Kinds("guildtrip")
assert(k.zone == 1 and k.label == 2 and k.nxTitle == 3 and k.nxWho == 3, "Guild Trip wie bisher")
k = Kinds("compact")
assert(k.nxTitle == 6 and not k.nxWho and not k.nxWhere, "Kompakt: 6 naechste Schritte, nur Namen")
k = Kinds("wow")
assert(not k.label and k.nxTitle == 3 and k.nxWho == 3 and not k.nxWhere, "WoW-Look: ohne Ueberschriften")
k = Kinds("minimal")
assert(not k.zone and not k.label and not k.nxTitle and k.now == 1, "Minimal: nur der naechste Schritt")
-- Vorlage schlaegt Hintergrund vor; "Ohne Rahmen" alt = unsichtbar
db.trackerLook = nil
db.trackerBare = true
assert(Tr:Bare(), "alte Einstellung Ohne Rahmen")
db.trackerBare = nil
assert(not Tr:Bare())
WL.Set(Tr.LOOK, "preset", "minimal")
assert(Tr:Bare() and db.trackerLook.bg == "none")
WL.Set(Tr.LOOK, "preset", "compact")
assert(WL.Bg(Tr.LOOK) == "glassLight" and not Tr:Bare())
-- Schriften der Vorlage, Farben ueber Rollen
assert(Tr.St("now")[1] == "GameFontNormal" and Tr.St("now")[5] == 16)
db.trackerLook = nil
assert(Tr.St("now")[1] == "GameFontNormalLarge")
for kind, role in pairs(Tr.KIND_ROLE) do
    local found
    for _, r2 in ipairs(Tr.LOOK.roles) do if r2.key == role then found = true end end
    assert(found, "Rolle fehlt: " .. role .. " (" .. kind .. ")")
end
-- Zahnrad oeffnet die eigenen Optionen (nicht das Hauptfenster)
local f = assert(io.open(root .. "/ONE_Leveling/Tracker.lua")) local src = f:read("*a") f:close()
assert(src:find("ONE.WindowLook:Toggle(Tr.LOOK, f)", 1, true), "Zahnrad = eigenes Aussehen")
-- eigener Standard je Fenster (In der Naehe: etwas heller als dunkel)
local st2 = {}
local d2 = {store = function() return st2 end, defaultBg = "dark", defaultAlpha = .55}
assert(math.abs(WL.Alpha(d2) - .55) < 1e-9)
WL.Set(d2, "bg", "dark")
assert(math.abs(WL.Alpha(d2) - .72) < 1e-9, "ausdruecklich gewaehlt: Stufe")
-- Regel: jedes Zusatzfenster hat ein Zahnrad mit eigenem Aussehen
for _, file in ipairs({"ONE_Leveling/Tracker.lua", "ONE_Nav/Arrow.lua", "ONE_Chat/LootWindow.lua", "ONE_Classes/Buffs.lua", "ONE_Classes/Nearby.lua"}) do
    local h = assert(io.open(root .. "/" .. file)) local code = h:read("*a") h:close()
    assert(code:find("WindowLook:Toggle(", 1, true) and code:find("UI-OptionsButton", 1, true), "Zahnrad fehlt: " .. file)
end
-- mehrere Quests beim selben NPC: Name vorn (sonst abgeschnitten), in Questgeber-Farbe
db.trackerLook = {colors = {giver = {1, 0, 0}}}
local at = Tr.AtNPC({kind = "turnin", nr = 1, actions = {{kind = "turnin", id = 1}, {kind = "accept", id = 2}}})
assert(at:find("|cffff0000Tonga|r: abgeben + annehmen", 1, true), at)
-- darunter die Questnamen in Questnamen-Farbe
db.trackerLook = {colors = {title = {0, 0, 1}}}
G.Title = function(id) return "Quest " .. id end
local who2 = Tr.NowWhoBase({kind = "turnin", nr = 1, actions = {{kind = "turnin", id = 1}, {kind = "accept", id = 2}}})
assert(who2 == "|cff0000ffQuest 1|r · |cff0000ffQuest 2|r", who2)
print("OK test_fensterlook_150")
