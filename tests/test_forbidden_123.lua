-- Offline-Test 0.7.2: Guild Trip benutzt keine Funktionen, die WoW Forever fuer Addons sperrt
-- ("<Addon> wurde geblockt. Die angeforderte Funktion ist der Blizzard-UI vorbehalten").
-- Belegt im Spiel 19.11.2026 bzw. in der Doku von "Thanks for the Buff" (MIT): Kampflog anmelden/lesen
-- (pcall faengt das NICHT ab) und DoEmote (dafuer C_ChatInfo.PerformEmote).
local root = arg[1] or "src"
local banned = {
    {"COMBAT_LOG_EVENT", "Kampflog (Forever sperrt es fuer Addons)"},
    {"CombatLogGetCurrentEventInfo", "Kampflog lesen"},
    {"DoEmote(", "DoEmote – nur C_ChatInfo.PerformEmote ist erlaubt"},
}
local list = io.popen("cd " .. root .. " && find . -name '*.lua'")
local bad = {}
for file in list:lines() do
    file = file:gsub("^%./", "")
    local src = assert(io.open(root .. "/" .. file)):read("*a")
    src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")   -- Kommentare zaehlen nicht
    for _, b in ipairs(banned) do
        if src:find(b[1], 1, true) then bad[#bad + 1] = file .. ": " .. b[2] end
    end
end
list:close()
assert(#bad == 0, "Gesperrte Funktionen:\n" .. table.concat(bad, "\n"))
print("OK test_forbidden_123")
