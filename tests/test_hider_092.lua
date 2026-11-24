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
CreateFrame = function(kind, _, parent) local r = Region(kind, parent or UIParent) r.CreateTexture = function() return Region("Texture") end return r end
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
-- Makro-Sperre (24.11.2026): Eingabefeld muss VOR dem Umhaengen von ChatFrame1 versteckt sein, sonst setzt
-- Blizzards OnHide aus unserem Aufruf heraus die Chat-Art (SetLastActiveWindow -> Deactivate)
local boxShownWhenMoved
local setParent = ChatFrame1.SetParent
function ChatFrame1:SetParent(p) boxShownWhenMoved = ChatFrame1EditBox.shown setParent(self, p) end
H:Apply()
assert(boxShownWhenMoved == false, "Eingabefeld war beim Umhaengen noch sichtbar (Makros wuerden geblockt)")
ChatFrame1.SetParent = setParent
-- ein gerade benutztes Feld (Fokus) wird nicht angefasst
ChatFrame1EditBox.shown, ChatFrame1EditBox.HasFocus = true, function() return true end
H.HideEditBoxes()
assert(ChatFrame1EditBox.shown, "Feld mit Fokus bleibt")
ChatFrame1EditBox.HasFocus = nil
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
-- Springen zwischen Guild-Trip-Chat und WoW-Chat (Nutzer 22.11.2026)
C_AddOns = nil
local hidden = 0
c.UI.Hide = function() hidden = hidden + 1 end
Chat:Settings().hideBlizzard = true
H:Apply()
assert(ChatFrame1.parent ~= UIParent, "ersetzt")
assert(H:ToWoW() and hidden == 1, "eigener Chat zu")
assert(ChatFrame1.parent == UIParent and next(binds) == nil, "WoW-Chat voruebergehend da, Enter wieder fuer WoW")
assert(Chat:Settings().hideBlizzard == true, "Einstellung bleibt")
H:OnChatShown()
assert(ChatFrame1.parent ~= UIParent and binds.ENTER == "GuildTripChatOpener", "zurueck: WoW-Chat wieder weg")
-- im Kampf: nichts umhaengen, eigener Chat bleibt offen, danach erledigt
InCombatLockdown = function() return true end
assert(H:ToWoW() == false and hidden == 1 and ChatFrame1.parent ~= UIParent, "im Kampf nichts")
assert(ONE.printed and ONE.printed:find("Kampf"), "Hinweis im Kampf")
InCombatLockdown = function() return false end
local ev
local cf = CreateFrame
CreateFrame = function(...) local r = cf(...) ev = ev or r return r end
H:Initialize()
CreateFrame = cf
ev.scripts.OnEvent(ev, "PLAYER_REGEN_ENABLED")
assert(ChatFrame1.parent == UIParent and hidden == 2, "nach dem Kampf: WoW-Chat da, eigener zu")
H:OnChatShown()
assert(ChatFrame1.parent ~= UIParent, "wieder ersetzt")
-- ohne Ersetzen: nur eigener Chat zu, nichts umhaengen
Chat:Settings().hideBlizzard = false
H:Apply()
assert(H:ToWoW() and hidden == 3 and not H.peek and ChatFrame1.parent == UIParent)
-- Knopf abschaltbar, Standard an
assert(H.JumpShown())
Chat:Settings().jumpButton = false
assert(not H.JumpShown())
UIParent.CreateTexture = function() return Region("Texture") end
local jp = Region("Frame") jp.CreateTexture = UIParent.CreateTexture
local b = H:JumpButton(jp)
assert(b.scripts.OnClick, "Knopf klickbar")
print("OK test_hider_092")
