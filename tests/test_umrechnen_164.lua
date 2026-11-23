-- Navi rechnet immer wieder vom Spielerpfeil aus neu (Nutzer 23.11.2026, als Geist: "erst zum gelben Punkt und
-- dann weiter"): ist der neue Weg spuerbar kuerzer als der Rest des alten, gilt der neue – auch ohne "abgekommen".
local root = arg[1] or "src"
_G.ProjectONE = {db = {}, modules = {}}
-- gerade Strasse von (0,0) nach (0,1000)
GuildTripRoutes = {R = {[1] = {nodes = "0 0 0 1000", edges = {{1, 2, 1000, ""}}}}}
local nav = {}
assert(loadfile(root .. "/ONE_Nav/Routes.lua"))("ONE_Nav", nav)
local R = nav.Routes
R.pull = 0
local tx, ty = 0, 1000
-- alter Weg (z. B. vorher geplant): erst 400 nach Osten zum "gelben Punkt", dann zurueck zur Strasse
local old = {continent = 1, tx = tx, ty = ty, index = 2, length = 1800,
    points = {{x = 0, y = 0}, {x = 40, y = 300}, {x = 40, y = 500}, {x = 400, y = 500}, {x = 0, y = 600}, {x = 0, y = 1000}}}
local h = {route = old}
assert(R:Steer(h, 1, 0, 0, tx, ty, 10) and h.route == old, "erster Aufruf: alter Weg, Uhr startet")
local p = R:Steer(h, 1, 30, 400, tx, ty, 11)
assert(p and h.route == old, "vor Ablauf der Wartezeit: alter Weg")
local rest
p, rest = R:Steer(h, 1, 30, 400, tx, ty, 10 + R.recheck + .1)
assert(p and h.route ~= old and rest < 700, "neu gerechnet vom Spieler aus: Rest " .. tostring(rest))
-- gleich langer Weg: nicht hin und her springen
local now = h.route
R:Steer(h, 1, 30, 420, tx, ty, 20)
assert(h.route == now, "kein Wechsel ohne spuerbaren Gewinn")
print("ok umrechnen")
