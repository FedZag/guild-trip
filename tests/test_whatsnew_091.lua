-- Offline-Test: Neu-Fenster beim Einloggen (einmal je Version) + Teilen-Hinweis.
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, text = ""}
    setmetatable(r, {__index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:SetText(t) self.text = t end
    function r:GetStringHeight() return 18 end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
C_Timer = {After = function(_, fn) fn() end}
local printed = {}
local ONE = {db = {}, version = "0.6.6-alpha", slashes = {}}
function ONE:Print(m) printed[#printed + 1] = m end
function ONE:IsEnabled() return true end
function ONE:RegisterSlash(n, fn) self.slashes[n] = fn return true end
ONE.Themes = setmetatable({}, {__index = function() return function() end end})
local buttons, checks = {}, {}
ONE.Widgets = {
    Button = function(_, parent, text, w, h, point, x, y, cb) local b = Region("Button", parent) b.text, b.click = text, cb buttons[#buttons + 1] = b return b end,
    CloseButton = function() return Region("Button") end,
}
ONE.Kit = {Check = function(_, parent, o) local b = Region("CheckButton", parent) b.o = o checks[#checks + 1] = b function b:Refresh() end return b end}
local state = {a = false, b = false}
ONE.UI = {shareOptions = {
    {id = "a", label = "Teilen A", get = function() return state.a end, set = function(v) state.a = v end},
    {id = "b", label = "Teilen B", get = function() return state.b end, set = function(v) state.b = v end},
}}
assert(loadfile(root .. "/ONE_Core/WhatsNew.lua"))("ONE_Core", ONE)
local W = ONE.WhatsNew
assert(W:SharesOff() == 2)

-- 1) Neue Version: Fenster mit Teilen-Haekchen, "Alles einschalten" schaltet alles an
W:Check()
assert(W.frame and W.frame.shown and #W.frame.checks == 2 and ONE.db.seenVersion == "0.6.6-alpha")
local all
for _, b in ipairs(buttons) do if b.text == "Alles einschalten" then all = b end end
assert(all)
all.click()
assert(state.a and state.b and W:SharesOff() == 0)

-- 2) Gleiche Version, alles an: kein Fenster, kein Hinweis
W.frame:Hide()
printed = {}
W:Check()
assert(not W.frame.shown and #printed == 0)

-- 3) Gleiche Version, Teilen aus: nur Chat-Hinweis
state.a = false
W:Check()
assert(not W.frame.shown and #printed == 1 and printed[1]:find("Teilen"))

-- 4) Befehle da
W:Initialize()
assert(ONE.slashes.neu and ONE.slashes.teilen)
print("OK test_whatsnew_091")
