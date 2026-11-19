-- Startseite: 100 Sprueche, taeglich ein neuer, je Charakter ein anderer, alle uebersetzt.
local root = arg[1] or "src"
local ONE = {}
assert(loadfile(root .. "/ONE_Core/Quips.lua"))("ONE_Core", ONE)
assert(#ONE.QUIPS == 100, "100 Sprueche")
local seen = {}
for _, q in ipairs(ONE.QUIPS) do assert(not seen[q], "doppelt: " .. q) seen[q] = true end
assert(ONE.QUIP_GHOST and not seen[ONE.QUIP_GHOST])

-- 100 Tage hintereinander: jeder Spruch genau einmal
local used = {}
for day = 20000, 20099 do used[ONE.QuipIndex(day, "Brakka-Forever", 100)] = true end
local n = 0 for _ in pairs(used) do n = n + 1 end
assert(n == 100, "100 Tage ohne Wiederholung")
-- naechster Tag = anderer Spruch
assert(ONE.QuipIndex(20000, "Brakka-Forever", 100) ~= ONE.QuipIndex(20001, "Brakka-Forever", 100))
-- verschiedene Charaktere sehen am selben Tag meist verschiedene Sprueche
local names = {"Brakka-Forever", "Rehgar-Forever", "Thrall-Forever", "Gildi-Forever", "Mirela-Forever", "Talan-Forever"}
local same = {}
for _, who in ipairs(names) do same[ONE.QuipIndex(20000, who, 100)] = true end
local k = 0 for _ in pairs(same) do k = k + 1 end
assert(k >= 5, "Gilde sieht verschiedene Sprueche")

-- alle Sprueche haben eine englische Fassung
local src = assert(io.open(root .. "/ONE_Core/Locale_enUS.lua")):read("*a")
for _, q in ipairs(ONE.QUIPS) do assert(src:find('EN["' .. q .. '"]', 1, true), "ohne Englisch: " .. q) end
assert(src:find('EN["' .. ONE.QUIP_GHOST .. '"]', 1, true))
print("OK test_quips_120")
