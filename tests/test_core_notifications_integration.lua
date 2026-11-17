-- Test: texlua tests/test_core_notifications_integration.lua
-- Prüft die Verbindung des bestehenden ONE:Notify zur neuen zentralen API.
local registered = {}
SlashCmdList = {}
local ONE = {
    UI = {Initialize = function() end, Refresh = function() end},
    Themes = {Initialize = function() end},
    Welcome = {Initialize = function() end},
    Notifications = {Initialize = function(self) self.ready = true end, Push = function(self, message, options)
        self.received = {message = message, options = options}
        return true
    end},
}
CreateFrame = function()
    local f = {}
    function f:RegisterEvent(ev) registered[ev] = self end
    function f:UnregisterEvent(ev) registered[ev] = nil end
    function f:SetScript(ev, func) self[ev] = func end
    return f
end
local path = arg and arg[0] and arg[0]:match("^(.*)/tests/test_core_notifications_integration.lua$") or "."
assert(loadfile(path .. "/src/ONE_Core/Core.lua"))("ONE_Core", ONE)
assert(registered.ADDON_LOADED)
ProjectONEDB = {soundEnabled = false}
local eventFrame = registered.ADDON_LOADED
eventFrame.OnEvent(eventFrame, "ADDON_LOADED", "ONE_Core")
assert(ONE.started and ONE.Notifications.ready and ONE.db.toastEnabled == true)
assert(ONE.db.soundEnabled == false) -- alte Einstellung erhalten
assert(ONE:Notify("Terminerinnerung", {source = "ONE Calendar"}))
assert(ONE.Notifications.received.message == "Terminerinnerung")
assert(ONE.Notifications.received.options.source == "ONE Calendar")
assert(type(SlashCmdList.PROJECTONE) == "function")
print("OK: Core-Start, SavedVariables-Migration und Benachrichtigungs-API")
