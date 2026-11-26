-- Offline-Test: Dungeon-Vorquests ohne Folgequests (Nutzer 26.11.2026: "Verborgene Feinde" im Flammenschlund
-- zeigte "Vorquests 2/4" – zwei davon sind die Abgaben NACH dem Dungeon). Mit echten Daten.
local root = arg[1] or "src"
ProjectONE = {}
assert(loadfile(root .. "/ONE_QuestDB/Data.lua"))()
local done = {}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return done[id] == true end,
    GetLogIndexForQuestID = function() return nil end,
}
local d = {}
assert(loadfile(root .. "/ONE_Dungeons/QuestData.lua"))(nil, d)
assert(loadfile(root .. "/ONE_Dungeons/Model.lua"))(nil, d)
local M = d.Model
local function Find(dungeon, id)
    for _, dg in ipairs(d.QuestData.dungeons) do
        if dg.name == dungeon then for _, q in ipairs(dg.quests) do if q.ids and q.ids[1] == id then return q end end end
    end
    error("nicht gefunden: " .. dungeon .. " " .. id)
end
-- Verborgene Feinde 5728: Kette 5726 -> 5727 -> 5728 (Dungeon) -> 5729 -> 5730
local hidden = Find("Ragefire Chasm", 5728)
local ids = {}
for _, p in ipairs(M:Prereqs(hidden)) do ids[#ids + 1] = p.ids[1] end
assert(#ids == 2 and ids[1] == 5726 and ids[2] == 5727, "nur 5726/5727 sind Vorquests: " .. table.concat(ids, ","))
local a, b = M:PrereqState(hidden)
assert(a == 0 and b == 2, "0/2 ohne erledigte")
assert(M:Status(hidden) == "locked", "ohne Vorquests gesperrt")
done[5726], done[5727] = true, true
a, b = M:PrereqState(hidden)
assert(a == 2 and b == 2, "2/2 statt 2/4")
assert(M:Status(hidden) == "open", "beide Vorquests erledigt -> annehmbar (vorher faelschlich gesperrt)")
-- Unending Torment 97290 (Ruinen von Lordaeron): 97291/97292 kommen danach
local torment = Find("Ruins of Lordaeron", 97290)
for _, p in ipairs(M:Prereqs(torment)) do
    assert(p.ids[1] ~= 97291 and p.ids[1] ~= 97292, "Folgequest als Vorquest: " .. p.ids[1])
end
-- Ohne Questdatenbank: Liste bleibt wie geliefert (nichts geht verloren)
local saved = GuildTripQuestDB
GuildTripQuestDB = nil
local d2 = {}
assert(loadfile(root .. "/ONE_Dungeons/QuestData.lua"))(nil, d2)
assert(loadfile(root .. "/ONE_Dungeons/Model.lua"))(nil, d2)
local h2
for _, q in ipairs(d2.QuestData.dungeons[1].quests) do if q.ids and q.ids[1] == 5728 then h2 = q end end
assert(#d2.Model:Prereqs(h2) == 4, "ohne Datenbank unveraendert")
GuildTripQuestDB = saved
-- Alle Dungeons: keine Vorquest liegt in der Folgekette ihrer Dungeonquest
for _, dg in ipairs(d.QuestData.dungeons) do for _, q in ipairs(dg.quests) do
    local after = {}
    for _, id in ipairs(q.ids or {}) do
        local e = GuildTripQuestDB.q[id]
        while e and e[12] and e[12] > 0 and not after[e[12]] do after[e[12]] = true e = GuildTripQuestDB.q[e[12]] end
    end
    for _, p in ipairs(M:Prereqs(q)) do
        for _, id in ipairs(p.ids or {}) do assert(not after[id], dg.name .. ": " .. (q.name or "?") .. " Vorquest " .. id .. " ist Folgequest") end
    end
end end
print("ok dungeonprereqs")
