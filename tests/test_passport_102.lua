-- 0.6.8 Reisepass: Stempel fuer Dungeons und Gildenausfluege, Teilen mit der Gilde (PS-Nachricht)
local root = (arg[0]:match("^(.*)/tests/") or ".") .. "/src"
local now = 1763400000
GetServerTime = function() return now end
GetTime = function() return 100 end
UnitName = function() return "Testheld" end
local sent = {}
local ONE = {db = {}}
_G.ProjectONE = ONE
local dungeons = {}
dungeons.Share = {prefix = "ONEGRP1", Same = function(a, b) return a == b end,
    IsSharing = function() return true end,
    Send = function(_, msg) sent[#sent + 1] = msg return true end,
    Receive = function() return "alt" end, SendProgress = function() return true end,
    DungeonName = function(_, key) return key == "wc" and "Höhlen des Wehklagens" or key end}
local trips = {{id = "t1", start = now - 60, key = "dm", signups = {Testheld = {status = "yes"}}},
    {id = "t2", start = now + 3600, key = "rfc", signups = {Testheld = {status = "yes"}}},
    {id = "t3", start = now - 30, key = "sfk", signups = {Testheld = {status = "maybe"}}}}
dungeons.Trips = {List = function() return trips end, Now = function() return now end,
    Mine = function(_, t) return t.signups.Testheld end,
    Counts = function() return {yes = 7} end, Name = function(_, t) return "Ausflug " .. t.key end}
assert(loadfile(root .. "/ONE_Dungeons/Passport.lua"))("ONE_Dungeons", dungeons)
local P = dungeons.Passport

-- Dungeon betreten: Stempel; gleich danach nochmal (Neu laden) zaehlt nicht, eine Stunde spaeter schon
assert(P:Visit("wc", 5) and P:Mine().d.wc.runs == 1, "erster Stempel")
assert(not P:Visit("wc", 5, now + 60) and P:Mine().d.wc.runs == 1, "Neu laden zaehlt nicht")
assert(P:Visit("wc", 5, now + 7200) and P:Mine().d.wc.runs == 2, "zweiter Lauf")
P:Visit("dm", 4, now - 86400)

-- Ausfluege: nur begonnene mit Zusage, jeder nur einmal
assert(P:StampTrips(now) == 1 and #P:Mine().t == 1 and P:Mine().t[1].count == 7, "Ausflug gestempelt")
assert(P:StampTrips(now) == 0, "nicht doppelt")

-- Anzeige: neueste zuerst, Zaehler
local d, t = P.Stamps(P:Mine())
assert(#d == 2 and d[1].key == "wc" and #t == 1 and P.Count(P:Mine()) == 3)

-- Gilde: eigene Nachricht und fremder Pass ueber die vorhandene Gildennachricht
assert(P:Message() == "PS|dm,wc|1", P:Message())
local S = dungeons.Share
S:Receive("ONEGRP1", "PS|wc,sfk|4", "GUILD", "Brakka-Testrealm")
assert(P.peers.Brakka and P.peers.Brakka.d.sfk and P.peers.Brakka.trips == 4, "fremder Pass")
assert(S:Receive("ONEGRP1", "P0|20|WARRIOR", "GUILD", "Brakka-Testrealm") == "alt", "andere Nachrichten unveraendert")
local people = P:People()
assert(people[1].me and people[1].count == 3 and people[2].name == "Brakka" and people[2].count == 6, "Liste: du zuerst")
sent = {}
S:SendProgress()
assert(sent[1] == "PS|dm,wc|1", "Fortschritt teilen schickt den Pass mit")
print("OK test_passport_102")
