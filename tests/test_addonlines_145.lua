-- Offline-Test: Meldungen ANDERER Addons erscheinen im Guild-Trip-Chat, wenn der WoW-Chat ersetzt ist
-- (21.11.2026). Normale Chat-Nachrichten, Blizzard und Guild Trip selbst werden nicht doppelt geholt.
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
local clock = 100
GetTime = function() return clock end
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat
local hidden = true
c.Hider = {Enabled = function() return hidden end}

-- Aufrufstapel, wie WoW sie zeigt (beide Schreibweisen)
local hook = '[string "@Interface/AddOns/ONE_Chat/Chat.lua"]:275: in function <Interface/AddOns/ONE_Chat/Chat.lua:270>\n[C]: in function `AddMessage\'\n'
local fromDBM = hook .. 'Interface\\AddOns\\DBM-Core\\DBM-Core.lua:5120: in function `AddMsg\'\nInterface\\AddOns\\DBM-Core\\DBM-Core.lua:900: in function <...>\n'
local viaPrint = hook .. '[string "@Interface/AddOns/Blizzard_SharedXMLBase/Print.lua"]:7: in function <...>\n[C]: in function `print\'\n[string "@Interface/AddOns/Questie/Modules/Libs/QuestieLib.lua"]:44: in function `Print\'\n'
local event = hook .. '[string "@Interface/AddOns/Blizzard_ChatFrameBase/Mainline/ChatFrame.lua"]:3200: in function `ChatFrame_MessageEventHandler\'\n'
local hooked = hook .. 'Interface/AddOns/Stamps/Stamps.lua:10: in function `AddMessage\'\nInterface/FrameXML/ChatFrame.lua:3100: in function `ChatFrame_MessageEventHandler\'\n'
local own = hook .. 'Interface/AddOns/ONE_Core/Core.lua:80: in function `Print\'\nInterface/AddOns/ONE_Guild/Plan.lua:12: in function <...>\n'
local blizz = hook .. 'Interface/AddOns/Blizzard_UIParent/UIParent.lua:50: in function <...>\n'

assert(Chat.AddonFromStack(fromDBM) == "DBM-Core", "DBM erkannt")
assert(Chat.AddonFromStack(viaPrint) == "Questie", "print() ueber Blizzard-Weiterleitung")
assert(Chat.AddonFromStack(event) == nil, "Chat-Ereignis nicht doppelt")
assert(Chat.AddonFromStack(hooked) == nil, "fremder AddMessage-Haken bei Chat-Ereignis nicht doppelt")
assert(Chat.AddonFromStack(own) == nil, "Guild Trip selbst kommt ueber HookPrint")
assert(Chat.AddonFromStack(blizz) == nil, "Blizzard nicht")
assert(Chat.AddonFromStack(nil) == nil)

-- echter Weg: Haken an den WoW-Fenstern
local stack = fromDBM
debugstack = function() return stack end
local hooks = {}
hooksecurefunc = function(obj, name, fn)
    local orig = obj[name]
    obj[name] = function(...) orig(...) fn(...) end
    hooks[#hooks + 1] = name
end
NUM_CHAT_WINDOWS = 2
ChatFrame1 = {AddMessage = function() end}
ChatFrame2 = {AddMessage = function() end}
Chat.HookAddonLines()
Chat.HookAddonLines() -- doppelt: nur einmal
assert(#hooks == 2, "beide Fenster, nur einmal")
ChatFrame1:AddMessage("|cffff7d0aDBM:|r Pull in 10")
local all = Chat:Buffer("system")
assert(#all == 1 and all[1].kind == "system" and all[1].addon == "DBM-Core" and all[1].text:find("Pull in 10"), "im Guild-Trip-Chat")
ChatFrame2:AddMessage("|cffff7d0aDBM:|r Pull in 10") -- gleiche Zeile in zweitem Fenster
assert(#Chat:Buffer("system") == 1, "nicht doppelt")
clock = clock + 5
ChatFrame1:AddMessage("|cffff7d0aDBM:|r Pull in 10")
assert(#Chat:Buffer("system") == 2, "spaeter wiederholt: wieder zeigen")
ChatFrame1:AddMessage("   ")
assert(#Chat:Buffer("system") == 2, "leere Zeilen nicht")
stack = event
ChatFrame1:AddMessage("[Gilde] Bob: hallo")
assert(#Chat:Buffer("system") == 2, "Chat-Nachricht nicht doppelt")
-- WoW-Chat sichtbar: nichts holen
stack, hidden = fromDBM, false
ChatFrame1:AddMessage("noch eine")
assert(#Chat:Buffer("system") == 2, "ohne Ersetzen bleibt es im WoW-Chat")
print("OK test_addonlines_145")
