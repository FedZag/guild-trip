-- Offline-Test: Probe nativer Blizzard-Vorlagen. Echte Optik nur im Spiel pruefbar.
local root = arg[1] or "src"
local printed = {}
local known = {PortraitFrameTemplate = true, InsetFrameTemplate = true, UIPanelButtonTemplate = true,
    PanelTabButtonTemplate = true}
local function Region()
    local r = {}
    setmetatable(r, {__index = function(t, k)
        if k == "Inset" or k == "TitleText" or k == "portrait" or k == "TitleContainer" or k == "PortraitContainer" then return nil end
        return function(self, ...) self["_" .. k] = {...} return self end
    end})
    r.CreateFontString = function(self) local f = Region() f.SetText = function(s, t) s.text = t end return f end
    return r
end
CreateFrame = function(kind, _, parent, template)
    if template and not known[template] then error("unknown template " .. template) end
    local f = Region()
    f.template = template
    if template == "PortraitFrameTemplate" then
        f.SetTitle = function(self, t) self.title = t end
        f.SetPortraitToAsset = function(self, p) self.portraitPath = p end
    end
    return f
end
UIParent = Region()
PanelTemplates_SetNumTabs = function(f, n) f.numTabs = n end
PanelTemplates_SetTab = function(f, i) f.selectedTab = i end
local ONE = {db = {}}
function ONE:Print(m) printed[#printed + 1] = m end
assert(loadfile(root .. "/ONE_Dev/Native.lua"))("ONE_Dev", ONE)
local f = ONE.Native:OpenPreview()
assert(f and f.template == "PortraitFrameTemplate" and f.title:find("Guild Trip", 1, true))
assert(f.portraitPath:find("Emblem.tga", 1, true))
assert(f.numTabs == 3 and f.selectedTab == 1)
local d = ONE.db.nativeDiag
assert(d.templates.PortraitFrameTemplate == true and d.templates.ButtonFrameTemplate == false)
-- Ohne jede Vorlage: freundliche Meldung statt Fehler
ONE.Native.preview = nil
known = {}
assert(ONE.Native:OpenPreview() == nil and printed[#printed]:find("nicht möglich", 1, true))
local toc = assert(io.open(root .. "/ONE_Dev/ONE_Dev.toc")):read("*a")
assert(toc:find("Native.lua", 1, true))
print("OK: 0.4.3b - Probe nativer Look (Vorlagen, Titel, Portrait, Reiter)")
