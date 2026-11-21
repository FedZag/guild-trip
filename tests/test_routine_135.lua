-- Offline-Test: Lehrer, Flugpunkte, Ruhestein benutzen/setzen, Abbrechen-Hinweis, "bis Stufe X Monster hauen"
-- (Nutzer 20.11.2026: "baue bitte alles gleich und teste hinterher gruendlich"; Ideen aus Leveling-Routen)
local root = arg[1] or "src"
local function Fresh()
    GuildTripQuestDB = {
        q = {
            -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
            [1] = {10, 8, 0, 0, false, {11}, {11}, {}, false, false, 600, 0, 0, 1},
            [2] = {10, 8, 0, 0, false, {12}, {12}, {}, false, false, 600, 0, 0, 1},
            [3] = {10, 8, 0, 0, false, {13}, {13}, {}, false, false, 600, 0, 0, 1},
            [4] = {10, 8, 0, 0, false, {14}, {14}, {}, false, false, 600, 0, 0, 1},
        },
        n = {
            [11] = {0, 1, 100, 100},
            [12] = {0, 1, 140, 100},
            [13] = {0, 1, 180, 100},
            [14] = {0, 1, 220, 100},
        },
    }
end
Fresh()
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
-- Karte 1: 0..10000 Yards (x*10000), Karte 2 daneben
local function World(m, x, y) return 1, (m - 1) * 10000 + x * 10000, y * 10000 end
local function Ctx(extra)
    local c = {
        me = {level = 10, class = 128, faction = "Horde", mapID = 1, x = .01, y = .01},
        done = function() return false end, inLog = function() return false end, complete = function() return false end,
        world = World, tempo = "all", speed = 7,
    }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local function Kinds(plan)
    local t = {}
    for _, s in ipairs(plan.steps) do
        if s.kind == "travel" then t[#t + 1] = "travel:" .. tostring(s.via and s.via.kind)
        elseif #s.actions == 0 then t[#t + 1] = s.kind
        else for _, a in ipairs(s.actions) do t[#t + 1] = a.kind:sub(1, 1) .. a.id end end
    end
    return table.concat(t, " ")
end
local function Has(plan, kind)
    for i, s in ipairs(plan.steps) do if s.kind == kind then return i, s end end
end

-- ===== 1) Lehrer =====
do
    -- Lehrer mitten zwischen den Quests: jetzt lernbar -> Schritt "train" im Plan
    local plan = assert(P:Plan(Ctx({train = {now = 2, next = {}, spots = {{mapID = 1, x = .016, y = .01, name = "Lehrerin"}}}})))
    local i, st = Has(plan, "train")
    assert(i, "Lehrer im Plan: " .. Kinds(plan))
    assert(st.name == "Lehrerin" and st.mapID == 1 and st.stopKey == "train:10", "Lehrer-Schritt mit Ort und Name")
    assert(i <= 3, "Lehrer liegt am Weg -> frueh: " .. Kinds(plan))
    -- Lehrer sehr weit weg (anderes Ende der Karte): kein Umweg
    local far = assert(P:Plan(Ctx({train = {now = 1, next = {}, spots = {{mapID = 1, x = .9, y = .9}}}})))
    assert(not Has(far, "train"), "kein Riesen-Umweg zum Lehrer: " .. Kinds(far))
    -- nichts zu lernen: kein Schritt
    local none = assert(P:Plan(Ctx({train = {now = 0, next = {}, spots = {{mapID = 1, x = .016, y = .01}}}})))
    assert(not Has(none, "train"))
    -- erst ab Stufe 12 lernbar und im Plan keine neue Stufe: kein Schritt (Stufe wird nicht erreicht)
    local later = assert(P:Plan(Ctx({train = {now = 0, next = {[12] = 1}, spots = {{mapID = 1, x = .016, y = .01}}}})))
    assert(not Has(later, "train"), "Stufe 12 im Plan nicht erreicht")
    -- mit EP-Stand: Stufe 12 wird erreicht -> Lehrer danach, nie davor
    -- (Lehrer mitten in der Runde; Schleifen 21.11.2026: hinter dem Startpunkt waeren es 6,7 min Umweg)
    local c = Ctx({train = {now = 0, next = {[11] = 1}, spots = {{mapID = 1, x = .16, y = .1}}}})
    c.me.xp, c.me.xpMax = 7000, 7600
    local p2 = assert(P:Plan(c))
    local ti = Has(p2, "train")
    assert(ti, "Stufe 11 im Plan erreicht -> Lehrer: " .. Kinds(p2))
    local gained = 0
    for k = 1, ti - 1 do gained = gained + (p2.steps[k].gain or 0) end
    assert(7000 + gained >= 7600, "Lehrer erst nach der neuen Stufe: " .. Kinds(p2))
    -- zwei offene Stufen: ein Besuch deckt beide ab
    local c3 = Ctx({train = {now = 1, next = {[11] = 1}, spots = {{mapID = 1, x = .016, y = .01}}}})
    c3.me.xp, c3.me.xpMax = 7000, 7600
    local n = 0
    for _, s in ipairs(assert(P:Plan(c3)).steps) do if s.kind == "train" then n = n + 1 end end
    assert(n >= 1 and n <= 2, "hoechstens ein Besuch je neuer Stufe")
end

-- ===== 2) Flugpunkte =====
do
    local plan = assert(P:Plan(Ctx({fpSpots = {{1, 130, 160, id = 77, name = "Dorf, Gebiet"}}})))
    local i, st = Has(plan, "fp")
    assert(i and st.world and st.world[2] == 130 and st.stopKey == "fp:77", "naher Flugpunkt wird abgeholt: " .. Kinds(plan))
    local far = assert(P:Plan(Ctx({fpSpots = {{1, 5000, 5000, id = 78, name = "weit"}}})))
    assert(not Has(far, "fp"), "weit weg: kein Umweg fuer einen Flugpunkt")
    local other = assert(P:Plan(Ctx({fpSpots = {{0, 130, 160, id = 79, name = "anderer Kontinent"}}})))
    assert(not Has(other, "fp"), "anderer Kontinent nie")
    assert(#plan.left == #far.left, "Flugpunkte zaehlen nie als liegengeblieben")
end

-- ===== 3) Ruhestein benutzen =====
do
    -- Quests weit weg (3000 yd), Heimatort direkt daneben
    for nr, x in pairs({[11] = 3000, [12] = 3040, [13] = 3080, [14] = 3120}) do GuildTripQuestDB.n[nr] = {0, 1, x / 10, 300} end
    local home = {1, 3000, 3100, inn = 5, place = "Dorf"}
    local plan = assert(P:Plan(Ctx({home = home, hearthIn = 0})))
    local s1 = plan.steps[1]
    assert(s1.kind == "travel" and s1.via.kind == "hearth" and s1.via.place == "Dorf", "erst Ruhestein: " .. Kinds(plan))
    assert(plan.steps[2].walk < 2, "vom Heimatort nur kurz laufen")
    -- Ruhestein noch 30 min auf Abklingzeit: laufen
    local cd = assert(P:Plan(Ctx({home = home, hearthIn = 1800})))
    assert(cd.steps[1].kind ~= "travel", "Abklingzeit: laufen " .. Kinds(cd))
    -- kein Ruhestein / kein Heimatort: laufen
    assert(assert(P:Plan(Ctx({home = home}))).steps[1].kind ~= "travel")
    -- nur einmal je Plan (60 min Abklingzeit): hoechstens ein Ruhestein-Schritt
    local n = 0
    for _, s in ipairs(plan.steps) do if s.via and s.via.kind == "hearth" then n = n + 1 end end
    assert(n == 1, "einmal Ruhestein")
    -- Zeit stimmt: Summe der Kosten = Planminuten
    local sum = 0
    for _, s in ipairs(plan.steps) do sum = sum + (s.cost or 0) end
    assert(math.abs(sum - plan.minutes) < .01, ("Minuten %.2f / %.2f"):format(sum, plan.minutes))
    Fresh()
end

-- ===== 4) Ruhestein setzen =====
do
    -- Gastwirt bei der ersten Quest, die naechsten Quests ringsum; Heimatort weit weg
    GuildTripQuestDB.q[5] = {10, 8, 0, 0, false, {15}, {15}, {}, false, false, 600, 0, 0, 1}
    GuildTripQuestDB.n[15] = {0, 1, 260, 100}
    local inns = {{1, 1010, 1010, id = 9, name = "Gastwirtin Hier"}}
    local plan = assert(P:Plan(Ctx({inns = inns, home = {1, 9000, 9000, inn = 1, place = "Weit"}})))
    local i, st = Has(plan, "bind")
    assert(i and st.name == "Gastwirtin Hier" and st.stopKey == "bind:9", "Ruhestein setzen im Plan: " .. Kinds(plan))
    local sum = 0
    for _, s in ipairs(plan.steps) do sum = sum + (s.cost or 0) end
    assert(math.abs(sum - plan.minutes) < .01, "Zeit fuer das Setzen zaehlt")
    -- schon dort gebunden: nichts
    local same = assert(P:Plan(Ctx({inns = inns, home = {1, 1010, 1010, inn = 9, place = "Hier"}})))
    assert(not Has(same, "bind"))
    -- Heimatort ist ohnehin nah an den Quests: nichts
    local near = assert(P:Plan(Ctx({inns = inns, home = {1, 1500, 1000, inn = 3, place = "Nah"}})))
    assert(not Has(near, "bind"), "Heimatort nah genug")
    -- Heimatort unbekannt (Ruhestein nicht erkannt): nichts vorschlagen
    assert(not Has(assert(P:Plan(Ctx({inns = inns}))), "bind"), "unbekannter Heimatort: nicht setzen")
    -- kein Gastwirt am Weg: nichts
    local none = assert(P:Plan(Ctx({inns = {{1, 8000, 8000, id = 10}}, home = {1, 9000, 9000, inn = 1}})))
    assert(not Has(none, "bind"))
    Fresh()
end

-- ===== 5) Abbrechen-Hinweis =====
do
    GuildTripQuestDB.q[6] = {1, 1, 0, 0, false, {11}, {12}, {16}, false, false, 100, 0, 0, 1}  -- grau, im Log, offen
    GuildTripQuestDB.n[16] = {0, 1, 300, 300}
    local plan = assert(P:Plan(Ctx({inLog = function(id) return id == 6 end})))
    assert(#plan.abandon == 1 and plan.abandon[1].id == 6, "graue Quest im Log: abbrechen vorschlagen")
    -- fertig im Log: abgeben statt abbrechen
    local fin = assert(P:Plan(Ctx({inLog = function(id) return id == 6 end, complete = function(id) return id == 6 end})))
    assert(#fin.abandon == 0, "fertige Quest nie abbrechen")
    -- abgewaehlt: kein Hinweis (eigene Entscheidung)
    local off = assert(P:Plan(Ctx({inLog = function(id) return id == 6 end, override = {[6] = "no"}})))
    assert(#off.abandon == 0)
    Fresh()
end

-- ===== 5b) Fortschritt im Log (Nutzer 20.11.2026) =====
do
    -- Sammelquest mit viel Aufwand (60 Gegner) im Log
    GuildTripQuestDB.q[7] = {10, 8, 0, 0, false, {11}, {12}, {17}, false, false, 600, 0, 0, 1}
    GuildTripQuestDB.n[17] = {0, 1, 300, 100}
    GuildTripLeveling.r[7] = "0|60|0||"
    local function With(have) return Ctx({inLog = function(id) return id == 7 end,
        progress = function(id) if id == 7 then return have, 15 end end}) end
    local p0 = assert(P:Plan(With(0)))
    assert(p0.info[7].work == 60 and p0.abandon[1] and p0.abandon[1].id == 7, "nicht angefangen + viel Aufwand: abbrechen vorschlagen")
    -- 12 von 15: nur noch der Rest zaehlt (12 Gegner) -> lohnt wieder, kein Abbrechen
    local p12 = assert(P:Plan(With(12)))
    assert(math.abs(p12.info[7].work - 12) < .01 and p12.info[7].progress == .8, "Rest-Aufwand")
    assert(#p12.abandon == 0 and p12.chosen[7], "fast fertig: weitermachen")
    -- fast fertig, aber grau (kaum EP): Abbrechen darf trotzdem vorgeschlagen werden
    GuildTripQuestDB.q[7][1] = 1
    local grey = assert(P:Plan(With(12)))
    assert(grey.abandon[1] and grey.abandon[1].id == 7, "grau: trotz Fortschritt vorschlagen")
    -- ohne Fortschrittsangabe: wie bisher
    GuildTripQuestDB.q[7][1] = 10
    local none = assert(P:Plan(Ctx({inLog = function(id) return id == 7 end})))
    assert(none.info[7].work == 60 and none.info[7].progress == 0)
    -- nicht im Log: Fortschritt zaehlt nie
    local out = assert(P:Plan(Ctx({progress = function() return 14, 15 end})))
    assert(out.info[1].progress == 0)
    GuildTripLeveling.r[7] = nil
    Fresh()
end

-- ===== 6) Bis Stufe X Monster hauen =====
do
    -- alle Quests erst ab Stufe 11, ich bin 10 mit 7000/7600 EP: erst 600 EP Monster hauen
    for id = 1, 4 do GuildTripQuestDB.q[id][2] = 11 end
    local c = Ctx()
    c.me.xp, c.me.xpMax = 7000, 7600
    local plan = assert(P:Plan(c))
    local i, st = Has(plan, "grind")
    assert(i == 1 and st.lvl == 11 and st.stopKey == "grind:11", "erst Monster hauen: " .. Kinds(plan))
    assert(st.work > 0 and st.work < 10 and math.abs(st.xp - 600) < 1, ("600 EP, %.1f min"):format(st.work))
    assert(plan.steps[2] and plan.steps[2].kind == "accept", "danach geht es mit Quests weiter: " .. Kinds(plan))
    assert(not st.world, "kein Navi-Ziel fuer Monster hauen")
    -- zu weit (mehr als P.GRIND_MAX Minuten): kein Schritt
    for id = 1, 4 do GuildTripQuestDB.q[id][2] = 20 end
    local far = assert(P:Plan(c))
    assert(not Has(far, "grind"), "nicht 10 Stufen hauen")
    -- ohne EP-Angabe (Tests, alte Daten): nie
    for id = 1, 4 do GuildTripQuestDB.q[id][2] = 11 end
    assert(not Has(assert(P:Plan(Ctx())), "grind"))
    Fresh()
end

-- ===== EP-Hilfe =====
assert(P.XPTo(10, 7000, 7600, 0, 11) == 600)
assert(P.XPTo(10, 7000, 7600, 0, 12) == 600 + P.XP_NEED[11])
assert(P.XPTo(10, 7000, 7600, 1000, 11) == 0)
assert(P.XPTo(10, 0, 7600, 0, 10) == 0)
print("OK test_routine_135")
