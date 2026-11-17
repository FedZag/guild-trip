-- Offline-Test: Navi-Pfeil-Baustein (Widgets:NaviArrow) – Klick, Tooltip, grau wenn abgeschaltet.
local root = arg[1] or "src"
local function Region(kind)
    local r = {kind = kind, scripts = {}, enabled = true}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:CreateTexture() return Region("Texture") end
    function r:SetVertexColor(a, b, c) self.color = {a, b, c} end
    function r:SetTexture(t) self.texture = t end
    function r:IsEnabled() return self.enabled end
    function r:Enable() self.enabled = true if self.scripts.OnEnable then self.scripts.OnEnable(self) end end
    function r:Disable() self.enabled = false if self.scripts.OnDisable then self.scripts.OnDisable(self) end end
    return r
end
CreateFrame = function(kind) return Region(kind) end
local tip = {}
-- wie im Spiel: SetText(text, r, g, b, alpha, wrap) – alpha muss eine Zahl sein (Fehler 15.11.: true an Stelle 5)
GameTooltip = {SetOwner = function() end, SetText = function(_, t, r, g, b, a)
        assert(a == nil or type(a) == "number", "bad argument #5 to 'SetText'") tip.title = t end,
    AddLine = function(_, t) tip.sub = t end, Show = function() tip.shown = true end, Hide = function() tip.shown = false end}
local ONE = {}
assert(loadfile(root .. "/ONE_Core/Widgets.lua"))("ONE_Core", ONE)

local clicked = 0
local nb = ONE.Widgets:NaviArrow(Region("Frame"), 18, "RIGHT", -2, 0, function() clicked = clicked + 1 end,
    function() return "Navi zu Sayoc", "Orgrimmar" end)
assert(nb.icon.texture:find("ONE_Nav\\Textures\\Arrow", 1, true))
assert(nb.icon.color[2] == 1 and nb.icon.color[1] < 1, "gruen")
nb.scripts.OnEnter(nb)
assert(tip.shown and tip.title == "Navi zu Sayoc" and tip.sub == "Orgrimmar")
assert(nb.icon.color[1] == 1, "beim Drueberfahren hell")
nb.scripts.OnLeave(nb)
assert(not tip.shown and nb.icon.color[1] < 1)
nb.scripts.OnClick(nb)
assert(clicked == 1)
nb:Disable()
assert(nb.icon.color[1] == nb.icon.color[2], "abgeschaltet grau")
nb.scripts.OnEnter(nb) nb.scripts.OnLeave(nb)
assert(nb.icon.color[1] == nb.icon.color[2], "bleibt grau")
nb:Enable()
assert(nb.icon.color[2] == 1)
-- fester Text als Tooltip, ohne Text: "Navi starten"
local plain = ONE.Widgets:NaviArrow(Region("Frame"), 16, nil, nil, nil, nil, nil)
plain.scripts.OnEnter(plain)
assert(tip.title == "Navi starten")
print("OK test_naviarrow_085")
