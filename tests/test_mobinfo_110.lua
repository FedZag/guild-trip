-- Offline-Test 0.7.0: Questgegner im Tooltip und an der Namensplakette.
local root = arg[1] or "src"
local now = 100
GetTime = function() return now end
GuildTripQuestDB = {
    q = {
        [1] = {5, 1, 0, 0, false, {}, {}, {500, 501, -77}, false, false, 0, 0, 0, 1}, -- Wolfsjagd: Woelfe 500/501
        [2] = {5, 1, 0, 0, false, {}, {}, {600}, false, false, 0, 0, 0, 1},          -- Bobs Quest: Kobold 600
        [3] = {5, 1, 0, 0, false, {}, {}, {500}, false, false, 0, 0, 0, 1},          -- fertig im Log
    },
    titles = {[2] = "Koboldplage"},
}
local log = {
    {id = 1, title = "Wolfsjagd", complete = false, objectives = {{text = "Wolf getötet: 3/10", finished = false}, {text = "Fell: 2/2", finished = true}}},
    {id = 3, title = "Erledigt", complete = true, objectives = {}},
}
local peers = {
    {name = "Bob", quests = {[1] = {done = false}, [2] = {done = false}}},
}
-- Bob ist in meiner Gruppe (nur Gruppenmitglieder zaehlen, Nutzer 22.11.2026)
local group = {party1 = "Bob"}
UnitName = function(u) return group[u] end
IsInRaid = function() return false end
local nav = {
    Quests = {Log = function() return log end},
    QuestShare = {
        Peers = function() return peers end,
        Holders = function(_, id)
            local out = {}
            for _, p in ipairs(peers) do
                local e = p.quests[id]
                if e then out[#out + 1] = {name = p.name, done = e.done, f = id == 1 and 7 or 1, r = id == 1 and 10 or 5} end
            end
            return out
        end,
    },
}
local ONE = {db = {}}
_G.ProjectONE = ONE
assert(loadfile(root .. "/ONE_Nav/MobInfo.lua"))("ONE_Nav", nav)
local M = nav.MobInfo

-- 1) Gegner-Nummer aus der GUID
assert(M.NpcID("Creature-0-5250-1-123-500-0000ABCD") == 500)
assert(M.NpcID("Player-5250-0ABC") == nil and M.NpcID(nil) == nil)

-- 2) Tooltip-Zeilen: meine offenen Ziele + Bob
local lines = M:Lines(500)
assert(#lines == 2 and lines[1][1] == "Guild Trip: Wolfsjagd – Wolf getötet: 3/10", lines[1][1])
assert(lines[2][1] == "   Bob 7/10", lines[2][1])
-- nur Bob braucht den Kobold (nicht in meinem Log)
lines = M:Lines(600)
assert(#lines == 2 and lines[1][1] == "Guild Trip: Koboldplage" and lines[2][1] == "   Bob 1/5")
-- niemand
assert(#M:Lines(999) == 0)

-- 3) Namensplakette: gelb (ich), blau (andere), nichts
assert(M:Need(500) == "me" and M:Need(501) == "me" and M:Need(600) == "other" and M:Need(999) == nil)
local tex = {}
local function Plate()
    local p = {}
    function p:CreateTexture()
        local t = {shown = true}
        function t:SetSize() end function t:SetPoint() end function t:SetTexture() end
        function t:SetVertexColor(r, g, b) self.color = {r, g, b} end
        function t:Show() self.shown = true end function t:Hide() self.shown = false end
        tex[#tex + 1] = t
        return t
    end
    return p
end
local plates = {nameplate1 = Plate(), nameplate2 = Plate(), nameplate3 = Plate()}
local guids = {nameplate1 = "Creature-0-1-1-1-500-1", nameplate2 = "Creature-0-1-1-1-600-1", nameplate3 = "Creature-0-1-1-1-999-1"}
C_NamePlate = {GetNamePlateForUnit = function(u) return plates[u] end}
UnitGUID = function(u) return guids[u] end
UnitIsPlayer = function() return false end
M:RefreshPlates()
assert(plates.nameplate1.guildTripQuest.shown and plates.nameplate1.guildTripQuest.color[3] == 1 and plates.nameplate1.guildTripQuest.color[1] == 1)
assert(plates.nameplate2.guildTripQuest.color[1] == .4, "blau")
assert(plates.nameplate3.guildTripQuest == nil)
-- Quest erledigt -> Symbol weg (nach Neuaufbau)
log[1].complete = true
peers = {}
M:Rebuild()
M:RefreshPlates()
assert(not plates.nameplate1.guildTripQuest.shown and not plates.nameplate2.guildTripQuest.shown)

-- 4) Tooltip-Haken
log[1].complete = false
M:Rebuild()
local added = {}
local tt = {GetUnit = function() return "Wolf", "mouseover" end, AddLine = function(_, t) added[#added + 1] = t end, Show = function() end}
guids.mouseover = "Creature-0-1-1-1-500-1"
M:OnTooltip(tt)
assert(added[1] == "Guild Trip: Wolfsjagd – Wolf getötet: 3/10")
-- 4b) je Ziel (Nutzer 22.11.2026: Niere gesammelt -> kein Ausrufezeichen mehr ueber den Schreitern, Loewen bleiben)
GuildTripQuestDB.q[4] = {5, 1, 0, 0, false, {}, {}, {700, 701, 800}, false, false, 0, 0, 0, 1}
GuildTripQuestDB.obj = {[4] = {i = {{700, 701}, {800}}}}
log[#log + 1] = {id = 4, title = "Chens Fass", complete = false, objectives = {
    {text = "Loewenhauer: 4/5", type = "item", finished = false}, {text = "Niere: 5/5", type = "item", finished = true}}}
peers = {}
M:Rebuild()
assert(M:Need(700) == "me" and M:Need(701) == "me", "Loewen: Ziel offen")
assert(M:Need(800) == nil, "Schreiter: Ziel erfuellt -> kein Zeichen")
assert(#M:Lines(800) == 0, "Tooltip: nichts mehr fuer den Schreiter")
-- Gruppenmitglied braucht die Quest noch: blau, auch wenn mein Ziel erledigt ist; nicht in der Gruppe: nichts
peers = {{name = "Bob", quests = {[4] = {done = false}}}}
M:Rebuild()
assert(M:Need(800) == "other", "Gruppe braucht ihn noch -> blau")
group = {}
M:Rebuild()
assert(M:Need(800) == nil and #M:Lines(800) == 0, "Gildenkollege ausserhalb der Gruppe zaehlt nicht")
group = {party1 = "Bob"}
peers = {}
M:Rebuild()
-- ohne Zuordnung (andere Art/fehlend): wie frueher alle Ziel-Gegner
log[#log].objectives[1].type = "event"
M:Rebuild()
assert(M:Need(800) == "me", "unbekannte Zuordnung: lieber markieren")
table.remove(log)
GuildTripQuestDB.obj = nil
M:Rebuild()

-- 5) Abgeschaltet
ONE.FeatureOn = function(_, id) return id ~= "nav.mobInfo" end
assert(#M:Lines(500) == 0 and M:Need(500) == nil)
print("OK test_mobinfo_110")
