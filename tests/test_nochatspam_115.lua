-- Offline-Test 0.7.0: Guild Trip schreibt NIE von selbst in den Chat (Nutzer 17.11.2026: "Im Chat soll
-- nichts gepostet werden, wenn nicht ausdruecklich gewuenscht"). Erlaubt sind nur Stellen, die auf
-- einen Klick hin senden. Kommt eine neue Stelle dazu, muss sie hier bewusst eingetragen werden.
local root = arg[1] or "src"
-- Datei -> Funktionen, in denen gesendet werden darf (jeweils nur auf Knopfdruck)
local allowed = {
    ["ONE_Chat/Chat.lua"] = "eigene, selbst getippte Nachrichten im Guild-Trip-Chat",
    ["ONE_Dungeons/Share.lua"] = "Knopf: Gruppengesuch in den Gildenchat",
    ["ONE_Dungeons/Recap.lua"] = "Knopf: Dungeon-Rueckblick in den Gildenchat",
    ["ONE_Core/PlayerMenu.lua"] = "Namensmenue: Anstupsen (Emote) auf Klick",
    -- einzige automatische Stelle: vom Nutzer ausdruecklich gewuenscht (19.11.2026), Schalter, Standard an
    ["ONE_Classes/Thanks.lua"] = "WoW-Emote (/danke, /verbeugen …), wenn dich jemand bufft – kein eigener Text",
}
local found = {}
local list = io.popen("cd " .. root .. " && find . -name '*.lua' -not -path './ONE_Dev/*'")
for file in list:lines() do
    file = file:gsub("^%./", "")
    local src = assert(io.open(root .. "/" .. file)):read("*a"):gsub("%-%-[^\n]*", "")
    for _, api in ipairs({"SendChatMessage", "DoEmote", "SendEmote", "PerformEmote"}) do
        if src:find(api, 1, true) then
            assert(allowed[file], file .. " benutzt " .. api .. " – Guild Trip darf nicht von selbst in den Chat schreiben")
            found[file] = true
        end
    end
end
list:close()
-- Die erlaubten Stellen senden nur aus Funktionen, die ein Klick ausloest (Stichprobe: Rueckblick/Gesuch)
local recap = assert(io.open(root .. "/ONE_Dungeons/Recap.lua")):read("*a")
assert(recap:find("function R:Post%(%)") and recap:find('f.post:SetScript%("OnClick", function%(%) R:Post%(%) end%)'), "Rueckblick nur per Knopf")
local share = assert(io.open(root .. "/ONE_Dungeons/Share.lua")):read("*a")
assert(share:find("Nur auf Knopfdruck", 1, true), "Gesuch nur per Knopf")
local th = assert(io.open(root .. "/ONE_Classes/Thanks.lua")):read("*a"):gsub("%-%-[^\n]*", "")
assert(not th:find("SendChatMessage", 1, true), "Danke nur als WoW-Emote, nie eigener Text (WoW blockt das)")
assert(not th:find("DoEmote", 1, true), "nicht das gesperrte DoEmote, nur C_ChatInfo.PerformEmote")
print("OK test_nochatspam_115")
