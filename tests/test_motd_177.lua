-- Offline-Test 26.11.2026: Nachricht des Tages der Gilde im Gilden-Reiter (Spieltest: "auch das motd kommt irgendwie nicht an")
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
GUILD_MOTD_TEMPLATE = "Gildennachricht des Tages: %s"
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat
Chat:Settings()
local heard = {}
Chat.listeners[#Chat.listeners + 1] = function(e, views) heard[#heard + 1] = {e, views} end
local e = Chat:AddMotd("Raid am Freitag 20 Uhr!")
assert(e and e.kind == "guild" and e.text:find("Gildennachricht des Tages: Raid am Freitag 20 Uhr!", 1, true), tostring(e and e.text))
local inGuild = false
for _, v in ipairs(heard[1][2]) do if v == "guild" then inGuild = true end end
assert(inGuild, "im Gilden-Reiter")
assert(Chat.IsPlain(e), "schlichte Zeile (ohne Absender)")
assert((Chat.unread.guild or 0) == 0, "kein Zaehler")
Chat:Settings().guildSound = true
assert(Chat:SoundFor(e, {"guild"}) == nil, "kein Ton")
assert(Chat:AddMotd("Raid am Freitag 20 Uhr!") == nil, "gleicher Text: nur einmal")
assert(Chat:AddMotd("") == nil and Chat:AddMotd(nil) == nil, "leer: nichts")
-- nach /reload (neuer Sitzungs-Merker): steht schon im Verlauf -> nicht doppelt
Chat.lastMotd = nil
assert(Chat:AddMotd("Raid am Freitag 20 Uhr!") == nil, "nach Neuladen nicht doppelt")
-- neue Nachricht: kommt
assert(Chat:AddMotd("Neue Ränge ab heute") ~= nil, "geaenderte Nachricht kommt")
-- beim Einloggen selbst nachsehen
GetGuildRosterMOTD = function() return "Willkommen!" end
assert(Chat:CheckMotd() ~= nil, "Einloggen: aus GetGuildRosterMOTD")
print("OK test_motd_177")
