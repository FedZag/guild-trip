-- Offline-Test: WoW-Chat ersetzen – ausblenden, zuruecksetzen, Sperre bei ElvUI & Co., Enter/Slash-Tasten.
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, text = ""}
    setmetatable(r, {__index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:SetParent(p) self.parent = p end
    function r:GetParent() return self.parent end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent or UIParent) end
UIParent = Region("Frame")
C_Timer = {After = function() end}
ChatFrame1, ChatFrame1Tab, GeneralDockManager = Region("Frame", UIParent), Region("Button", UIParent), Region("Frame", UIParent)
ChatFrame1EditBox = Region("EditBox", UIParent)
NUM_CHAT_WINDOWS = 2
local binds = {}
SetOverrideBindingClick = function(_, _, key, btn) binds[key] = btn end
ClearOverrideBindings = function() binds = {} end
local ONE = {db = {}, slashes = {}}
_G.ProjectONE = ONE
function ONE:Print(m) self.printed = m end
function ONE:RegisterSlash(n, fn) self.slashes[n] = fn return true end
local shown = 0
local c = {Chat = {}, UI = {Show = function() shown = shown + 1 end}}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
c.UI = {Show = function() shown = shown + 1 end}
assert(loadfile(root .. "/ONE_Chat/Hider.lua"))("ONE_Chat", c)
local Chat, H = c.Chat, c.Hider
Chat:Settings().hideBlizzard = true
H:Apply()
assert(ChatFrame1.parent ~= UIParent and not ChatFrame1.parent.shown, "WoW-Chat unsichtbar")
assert(ChatFrame1Tab.parent == ChatFrame1.parent and GeneralDockManager.parent == ChatFrame1.parent)
assert(ChatFrame1EditBox.parent == ChatFrame1.parent, "WoW-Eingabefeld auch weg")
assert(binds.ENTER == "GuildTripChatOpener" and binds["/"] == "GuildTripChatOpenerSlash", "Tasten")
assert(shown == 1, "eigener Chat geht auf")
-- zurueck
Chat:Settings().hideBlizzard = false
H:Apply()
assert(ChatFrame1.parent == UIParent and ChatFrame1Tab.parent == UIParent and ChatFrame1EditBox.parent == UIParent and next(binds) == nil, "zurueckgesetzt")
-- Sperre mit ElvUI
C_AddOns = {IsAddOnLoaded = function(n) return n == "ElvUI" end}
Chat:Settings().hideBlizzard = true
H:Apply()
assert(ChatFrame1.parent == UIParent, "bei ElvUI nie ausblenden")
assert(not H:Enabled())
print("OK test_hider_092")
