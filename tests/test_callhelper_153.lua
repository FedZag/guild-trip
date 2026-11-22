-- Offline-Test 0.7.8: Hilfsfunktion Call/Try reicht alle Rueckgabewerte durch, liefert aber immer
-- mindestens einen Wert (22.11.2026: Funktion ohne Rueckgabe -> type() ohne Argument -> Lua-Fehler
-- in Nearby.lua, 50x je Minute). Prueft jede Datei mit diesem Muster.
local root = arg[1] or "src"
local p = io.popen('grep -rl "table.maxn(r)" "' .. root .. '"')
local n = 0
for f in p:lines() do
    local src = io.open(f):read("*a")
    for line in src:gmatch("[^\n]*table%.maxn%(r%)[^\n]*") do
        n = n + 1
        assert(line:find("math.max(2, table.maxn(r))", 1, true) and line:find("return nil", 1, true),
            f .. ": Call muss immer einen Wert liefern (math.max(2, ...) und return nil):\n" .. line)
    end
end
p:close()
assert(n > 30, "Hilfsfunktionen gefunden")
-- Verhalten an einem echten Beispiel
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
assert(select("#", Call(function() end)) == 1 and type(Call(function() end)) == "nil", "ohne Rueckgabe: nil")
assert(select("#", Call(function() error("x") end)) == 1, "Fehler: nil")
assert(select(9, Call(function() return 1, 2, 3, 4, 5, 6, 7, 8, true end)) == true, "9. Wert kommt an")
assert(Call(function() return 1, nil, nil end) == 1)
print("OK test_callhelper_153")
