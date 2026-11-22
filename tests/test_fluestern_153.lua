-- Offline-Test: Fluester-Knoepfe (Anfragen, Mitgliederliste, Gildenhilfe, Dungeons) gehen in den
-- Guild-Trip-Chat, wenn er an ist (Nutzer 22.11.2026: "Anfragen – passiert nichts im Messenger").
local root = arg[1] or "src"
local ONE = {modules = {}}
assert(loadfile(root .. "/ONE_Core/PlayerMenu.lua"))("ONE_Core", ONE)
local wow
ChatFrame_OpenChat = function(t) wow = t end
-- ohne Chat-Modul: WoW-Chat mit Text
assert(ONE:Whisper("Staub", "Hallo") and wow == "/w Staub Hallo")
-- Chat-Modul uebernimmt
local got
ONE.modules.chat = {Compose = function(_, n, t) got = {n, t} return true end}
wow = nil
assert(ONE:Whisper("Staub", "Hallo") and got[1] == "Staub" and got[2] == "Hallo" and not wow, "Guild-Trip-Chat zuerst")
-- Chat lehnt ab (aus): WoW-Chat
ONE.modules.chat.Compose = function() return false end
assert(ONE:Whisper("Staub", "Hallo") and wow == "/w Staub Hallo")
assert(not ONE:Whisper(nil))
-- keine Stelle oeffnet die WoW-Eingabezeile direkt zum Fluestern (die ist bei ersetztem Chat versteckt)
for _, file in ipairs({"ONE_Crafting/Page.lua", "ONE_Leveling/Way.lua", "ONE_Core/Glass.lua", "ONE_Guild/Help.lua", "ONE_Dungeons/Share.lua"}) do
    local h = assert(io.open(root .. "/" .. file)) local code = h:read("*a") h:close()
    assert(not code:find('ChatFrame_OpenChat("/w', 1, true) and not code:find("ChatFrame_OpenChat, \"/w", 1, true)
        and not code:find("ChatFrame_SendTell", 1, true), "direkt WoW-Fluestern: " .. file)
    assert(code:find("ONE:Whisper(", 1, true), "gemeinsames Fluestern fehlt: " .. file)
end
-- Chat-Modul bietet Compose an
local h = assert(io.open(root .. "/ONE_Chat/Init.lua")) local init = h:read("*a") h:close()
assert(init:find("Compose = function", 1, true))
print("OK test_fluestern_153")
