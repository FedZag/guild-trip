-- Offline-Test 0.7.2: Guild Trip benutzt keine Funktionen, die WoW Forever fuer Addons sperrt
-- ("<Addon> wurde geblockt. Die angeforderte Funktion ist der Blizzard-UI vorbehalten").
-- Belegt im Spiel 19.11.2026 bzw. in der Doku von "Thanks for the Buff" (MIT): Kampflog anmelden/lesen
-- (pcall faengt das NICHT ab) und DoEmote (dafuer C_ChatInfo.PerformEmote).
local root = arg[1] or "src"
local banned = {
    {"COMBAT_LOG_EVENT", "Kampflog (Forever sperrt es fuer Addons)"},
    {"CombatLogGetCurrentEventInfo", "Kampflog lesen"},
    {"DoEmote", "DoEmote (auch als Rueckfall) – nur C_ChatInfo.PerformEmote ist erlaubt"},
    {"PerformEmote(\"", "Emote ohne Ziel-Namen geht an das aktuelle Ziel"},
}
-- Chat senden geht nur mit Tastendruck/Klick. Diese Stellen sind geprueft (alle hinter einem Knopf
-- oder der Eingabe im Guild-Trip-Chat); jede neue Stelle muss hier bewusst eingetragen werden.
local chatSendAllowed = {
    ["ONE_Chat/Chat.lua"] = true,          -- Chat:Send, nur aus der Eingabezeile (Enter)
    ["ONE_Dungeons/Share.lua"] = true,     -- PostToGuildChat, Knopf "Im Gildenchat posten"
    ["ONE_Dungeons/Recap.lua"] = true,     -- R:Post, Knopf im Dungeon-Rueckblick
}
local chatSend = {"SendChatMessage", "ChatEdit_SendText"}
local list = io.popen("cd " .. root .. " && find . -name '*.lua'")
local bad = {}
for file in list:lines() do
    file = file:gsub("^%./", "")
    local src = assert(io.open(root .. "/" .. file)):read("*a")
    src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")   -- Kommentare zaehlen nicht
    for _, b in ipairs(banned) do
        if src:find(b[1], 1, true) then bad[#bad + 1] = file .. ": " .. b[2] end
    end
    local addonFile = file:gsub("^src/", "")
    if not addonFile:match("^ONE_Dev/") and not chatSendAllowed[addonFile] then
        for _, fn in ipairs(chatSend) do
            if src:find(fn, 1, true) then bad[#bad + 1] = file .. ": " .. fn .. " – Chat senden nur nach Tastendruck (Stelle pruefen und oben eintragen)" end
        end
    end
    -- eigener Text als Emote wird ohne Tastendruck geblockt
    if src:find("SendChatMessage[^\n]*\"EMOTE\"") then bad[#bad + 1] = file .. ": SendChatMessage mit EMOTE" end
    -- Zauber per SecureActionButton auf eine Namensplakette wirkt in Forever nicht (Makro /targetexact nehmen)
    for call in src:gmatch("SetAttribute(%b())") do
        if call:find("unit", 1, true) and call:find("nameplate", 1, true) then
            bad[#bad + 1] = file .. ": Zauber auf nameplateN (wirkt nicht – Makro /targetexact)"
        end
    end
end
list:close()
assert(#bad == 0, "Gesperrte Funktionen:\n" .. table.concat(bad, "\n"))
print("OK test_forbidden_123")
