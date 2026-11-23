-- Offline-Test: Quest-Links per Umschalt+Klick aus Planer/Kasten in den Chat (Nutzer 23.11.2026)
local root = arg[1] or "src"
local ONE = {modules = {}}
assert(loadfile(root .. "/ONE_Core/PlayerMenu.lua"))("ONE_Core", ONE)

-- 1) Link vom Spiel, sonst selbst gebaut; ohne Titel keiner
GetQuestLink = function(id) if id == 7 then return "|cffffff00|Hquest:7:5|h[Kobolde]|h|r" end end
assert(ONE:QuestLink(7, "egal", 3) == "|cffffff00|Hquest:7:5|h[Kobolde]|h|r", "Link vom Spiel")
assert(ONE:QuestLink(8, "Die [Volks]miliz|r", 12) == "|cffffff00|Hquest:8:12|h[Die Volksmiliz]|h|r", "selbst gebaut, Zeichen bereinigt")
assert(ONE:QuestLink(9, "Ohne Stufe") == "|cffffff00|Hquest:9:-1|h[Ohne Stufe]|h|r")
assert(ONE:QuestLink(10, "#10") == nil and ONE:QuestLink(11, "") == nil and ONE:QuestLink(nil, "x") == nil, "kein Titel: kein Link")

-- 2) Reihenfolge: Guild-Trip-Chat -> offenes WoW-Feld -> WoW-Chat oeffnen
local got = {}
ONE.modules.chat = {InsertLink = function(_, t) got.gt = t return got.gtOk end}
ChatFrameUtil = {
    InsertLink = function(t) got.wow = t return got.wowOk end,
    OpenChat = function(t) got.open = t end,
}
got.gtOk = true
assert(ONE:LinkToChat("A") and got.gt == "A" and not got.wow, "Guild-Trip-Chat zuerst")
got = {wowOk = true}
assert(ONE:LinkToChat("B") and got.wow == "B" and not got.open, "dann WoW-Feld")
got = {}
assert(ONE:LinkToChat("C") and got.open == "C", "sonst WoW-Chat oeffnen")
assert(not ONE:LinkToChat(""), "leer: nichts")

-- 3) Mehrere Quests einer Zeile hintereinander, unbekannte fallen weg
got = {gtOk = true}
assert(ONE:LinkQuests({7, 8, 99}, function(id) return id == 8 and "Miliz" or ("#" .. id) end, function() return 4 end))
assert(got.gt == "|cffffff00|Hquest:7:5|h[Kobolde]|h|r |cffffff00|Hquest:8:4|h[Miliz]|h|r", tostring(got.gt))
assert(not ONE:LinkQuests({99}, function() return "#99" end), "nichts Verlinkbares")

-- 4) Umschalt erkannt (IsModifiedClick bevorzugt, sonst Umschalt)
IsModifiedClick = function(k) return k == "CHATLINK" end
assert(ONE:ChatLinkClick())
IsModifiedClick, IsShiftKeyDown = nil, function() return false end
assert(not ONE:ChatLinkClick())

-- 5) Planer und Kasten rufen es bei Umschalt+Klick auf (Quelltext-Pruefung)
for _, f in ipairs({"ONE_Leveling/Page.lua", "ONE_Leveling/Tracker.lua"}) do
    local src = assert(io.open(root .. "/" .. f)):read("*a")
    assert(src:find("ONE:ChatLinkClick()", 1, true) and src:find("G.LinkQuests(", 1, true), f .. ": Umschalt+Klick")
end
print("OK test_questlink_165")
