-- Offline-Test: Stuetzpunkt-Fuehrung mit echten Daten nachgespielt (scripts/sim_leveling.lua SIM_HUB=1 SIM_HUB_HART=1).
-- Harte Pruefungen je Lage (Nutzer 26.11.2026):
--  * kein Gebietswechsel, solange im angefangenen Gebiet passende Quests offen sind (unabhaengige Gegenprobe)
--  * keine Quest mehr als 2 Stufen ueber der Spielerstufe erledigt (im Notfall die erlaubten +3; Nutzer 26.11.: 2 Stufen)
--  * kein Hin und Her zwischen Gebieten (A -> B -> A -> B), kein Gebietsbesuch ohne abgegebene Quest
--  * Monster hauen nie mehr als ein paar tausend EP am Stueck; kein Leerlauf (Fuehrung zeigt nichts)
-- Braucht die Wegdaten von Shortest Path (Kartenrahmen): SPF=<Ordner> oder ../quellen/shortest-path-forever.
-- Fehlen sie, wird der Test uebersprungen (nur auf dem Rechner des Nutzers vorhanden).
local root = arg[1] or "src"
local spf = os.getenv("SPF") or (root .. "/../../quellen/shortest-path-forever")
local f = io.open(spf .. "/Data/Zones.lua")
if not f then
    print("OK test_hubs_sim_179 (übersprungen: keine Shortest-Path-Daten unter " .. spf .. ")")
    return
end
f:close()
local LAGEN = {
    {"h-barrens-12", 220},     -- Orc-Magier im Brachland (wie der Nutzer)
    {"h-durotar-1", 160},      -- Start Durotar -> Brachland
    {"a-westfall-12", 160},    -- Allianz Westfall
    {"h-needles-27", 120},     -- Tausend Nadeln
}
local bad = {}
for _, l in ipairs(LAGEN) do
    local cmd = ("cd %q/.. && SIM_HUB=1 SIM_HUB_HART=1 lua5.1 scripts/sim_leveling.lua %q %s %d 2>&1"):format(root, spf, l[1], l[2])
    local p = assert(io.popen(cmd))
    local out = p:read("*a")
    local ok = p:close()
    local line = out:match("STUETZPUNKT:[^\n]*") or "?"
    print(l[1] .. "  " .. line:sub(1, 160))
    if out:find("HARTE PRUEFUNG NICHT BESTANDEN", 1, true) or not out:find("STUETZPUNKT:", 1, true) then
        bad[#bad + 1] = l[1] .. ": " .. line
    end
end
assert(#bad == 0, "harte Pruefung der Stuetzpunkt-Fuehrung:\n" .. table.concat(bad, "\n"))
print("OK test_hubs_sim_179")
