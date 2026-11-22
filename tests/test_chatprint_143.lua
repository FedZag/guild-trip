-- Offline-Test: Guild-Trip-Meldungen (ONE:Print, z. B. /trip planinfo) erscheinen im Guild-Trip-Chat, wenn der
-- WoW-Chat ersetzt ist (Spieltest 20.11.2026: "/trip planinfo" ohne Ausgabe – landete im versteckten WoW-Chat).
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
local blizz = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, t) blizz[#blizz + 1] = t end}
local ONE = {db = {}}
_G.ProjectONE = ONE
function ONE:Print(message) DEFAULT_CHAT_FRAME:AddMessage("[Guild Trip] " .. tostring(message)) end
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat
local hidden = true
c.Hider = {Enabled = function() return hidden end}
Chat.HookPrint()
Chat.HookPrint() -- doppelt: nur einmal
ONE:Print("Plan-Info: Stufe 15")
assert(#blizz == 1, "WoW-Chat bekommt sie weiter")
local all = Chat:Buffer("system")
assert(#all == 1 and all[1].kind == "system" and all[1].text:find("Plan%-Info: Stufe 15"), "im Guild-Trip-Chat")
-- 22.11.2026 (Nutzer): Guild-Trip-Meldungen nur unter "System & Addons", nicht in "Alle"
assert(#Chat:Buffer("all") == 0, "nicht in Alle")
-- WoW-Chat nicht ersetzt: keine Doppelung
hidden = false
ONE:Print("noch eine")
assert(#blizz == 2 and #Chat:Buffer("system") == 1, "ohne Ersetzen nur im WoW-Chat")
print("OK test_chatprint_143")
