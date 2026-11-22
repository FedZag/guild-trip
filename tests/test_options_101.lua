-- Ausführen: lua5.1 tests/test_options_101.lua src
-- Der WoW-Client wird hier bewusst simuliert, kein echter Grafiktest.
local path = arg[0]:match("^(.*)/tests/test_theme_engine.lua$") or "."
local elements, eventFrame, sounds = {}, nil, {}
local unpack = table.unpack or unpack
local function Element(kind, parent, name)
    local o = {kind = kind, parent=parent, children = {}, visible = true, scripts = {}, text = "", name = name}
    if parent then parent.children[#parent.children + 1] = o end
    for _, m in ipairs({"SetSize", "SetPoint", "SetAllPoints", "SetWidth", "SetHeight",
        "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetFontString", "SetTexCoord", "SetAlpha", "SetFrameStrata", "SetToplevel", "SetMovable",
        "EnableMouse", "RegisterForDrag", "SetClampedToScreen", "SetBackdrop",
        "SetScrollChild", "ClearAllPoints", "SetAutoFocus", "SetNumeric", "SetMaxLetters", "ClearFocus",
        "SetVerticalScroll", "StartMoving", "StopMovingOrSizing", "SetEnabled",
        "SetScale", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag",
        "SetOrientation", "SetThumbTexture", "SetValue"}) do
        o[m] = function(self, ...) self["_" .. m] = {...} end
    end
    -- Midnight-Regression: Blizzard akzeptiert hier keinen nil-Assetwert.
    for _, setter in ipairs({"SetNormalTexture", "SetPushedTexture", "SetDisabledTexture"}) do
        o[setter] = function(self, asset)
            assert(asset ~= nil, setter .. ": ungültiger nil-Assetwert")
            self["_" .. setter] = asset
        end
    end
    if kind == "Button" then
        local texture = function()
            return {alpha=1, SetAlpha=function(self, alpha) self.alpha=alpha end}
        end
        o.Left, o.Middle, o.Right = texture(), texture(), texture()
        o._normal, o._pushed, o._disabled, o._highlight = texture(),texture(),texture(),texture()
        function o:GetNormalTexture() return self._normal end
        function o:GetPushedTexture() return self._pushed end
        function o:GetDisabledTexture() return self._disabled end
        function o:GetHighlightTexture() return self._highlight end
    end
    function o:GetChildren() return unpack(self.children) end
    function o:GetObjectType() return self.kind end
    function o:SetText(t) self.text = t end
    function o:GetText() return self.text end
    function o:SetTextColor(r,g,b) self.textColor = {r,g,b} end
    function o:SetColorTexture(r,g,b,a) self.color = {r,g,b,a} end
    function o:SetTexture(asset) assert(type(asset)=="string", "Texturpfad muss ein String sein"); self.texture=asset end
    function o:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a} end
    function o:SetBackdropColor(r,g,b,a) self.backdrop = {r,g,b,a} end
    function o:SetBackdropBorderColor(r,g,b,a) self.border = {r,g,b,a} end
    function o:GetFontString()
        if self.kind ~= "Button" then return nil end
        if not self.font then self.font = Element("FontString", nil, nil) end
        return self.font
    end
    function o:CreateTexture() return Element("Texture", nil, nil) end
    function o:CreateFontString() return Element("FontString", nil, nil) end
    function o:Hide() self.visible = false end
    function o:Show() self.visible = true end
    function o:IsShown() return self.visible end
    function o:SetScript(event, handler) self.scripts[event] = handler end
    function o:HookScript(event, handler) self.scripts["hook:" .. event] = handler end
    function o:RegisterEvent(event) if event == "ADDON_LOADED" then eventFrame = self end end
    function o:UnregisterEvent() end
    elements[#elements + 1] = o
    return o
end
CreateFrame = function(kind, name, parent) return Element(kind, parent, name) end
UIParent = Element("Frame", nil, "UIParent")
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
SOUNDKIT = {IG_MAINMENU_OPEN=850, IG_MAINMENU_OPTION_CHECKBOX_ON=856,
    IG_MAINMENU_OPTION_CHECKBOX_OFF=857, IG_CHARACTER_INFO_TAB=841, RAID_WARNING=8959}
PlaySound = function(id, channel) sounds[#sounds+1] = {id=id,channel=channel}; return true end
-- Grafik (0.7.8): zwei vorhandene CVars, Regler werden gebaut
local gfx = {groundEffectDensity = "48", ResampleAlwaysSharpen = "0"}
C_CVar = {GetCVar = function(n) return gfx[n] end, GetCVarDefault = function(n) return ({groundEffectDensity = "48", ResampleAlwaysSharpen = "0"})[n] end,
    SetCVar = function(n, v) gfx[n] = tostring(v) return true end}
local ONE = {}
for _, file in ipairs({"Core.lua", "Themes.lua", "Kit.lua", "Geometry.lua", "WindowScale.lua", "Widgets.lua", "Notifications.lua", "UI.lua", "Welcome.lua", "Vendor.lua", "Graphics.lua"}) do
    assert(loadfile(path .. "/src/ONE_Core/" .. file))("ONE_Core", ONE)
end
ProjectONEDB = {soundEnabled=false, guild={noticeHistory={}},theme={selected="hybrid",uiSounds=true}}

-- 0.6.9: Optionen zentral – Bereiche links, Einstellungen rechts, jeder Schalter genau einmal
_G.ProjectONE = ONE
eventFrame.scripts.OnEvent(eventFrame,"ADDON_LOADED","ONE_Core")
local UI = ONE.UI
local function Visible(e) while e do if e.visible==false then return false end e=e.parent end return true end
local function Boxes(label)
 local out={}
 for _,e in ipairs(elements) do if e.kind=="CheckButton" and e.label and e.label.text==label then out[#out+1]=e end end
 return out
end
local function VisibleBox(label)
 for _,b in ipairs(Boxes(label)) do if Visible(b) then return b end end
end
-- API: Pflichtfelder, keine doppelte id
assert(not UI:AddSetting({id="x"}), "ohne Bereich abgelehnt")
assert(not UI:AddSetting({id="x",category="general"}), "Haken ohne get/set abgelehnt")
local demo=false
assert(UI:AddSetting({id="demo.check",category="general",section="Probe",label="Probehaken",order=90,
 get=function() return demo end,set=function(v) demo=v end}))
assert(not UI:AddSetting({id="demo.check",category="general",label="nochmal",get=function() end,set=function() end}), "id nur einmal")
-- alter Weg (Spielhilfen) landet im Bereich des Moduls
assert(UI:AddOption({id="demo.legacy",section="Navi",label="Altlast",get=function() return true end,set=function() end}))
local legacy
for _,o in ipairs(UI.settingList) do if o.id=="demo.legacy" then legacy=o end end
assert(legacy.category=="nav" and legacy.section==nil)
-- Bereiche: Kern zuerst, Module in fester Reihenfolge
ONE:RegisterModule("nav",{title="Navigation"})
ONE:RegisterModule("chat",{title="Chat"})
ONE:RegisterModule("leveling",{title="Quest-Führung"})
local ids={}
for _,c in ipairs(UI:CategoryList()) do ids[#ids+1]=c.id end
assert(table.concat(ids,",")=="general,look,graphics,reminders,sharing,leveling,nav,chat", table.concat(ids,","))
-- Grafik: Seite baut, Schalter nur fuer vorhandene CVars, Haken setzt die CVar
UI:OpenOptions("graphics")
assert(UI.contextLabel.text=="Grafik")
assert(VisibleBox("Bild immer nachschärfen") and not VisibleBox("Zauberkreise auf dem Boden"))
assert(VisibleBox("Beim Einloggen neu setzen"))
do local b=VisibleBox("Bild immer nachschärfen") b.GetChecked=function() return true end b.scripts.OnClick(b) end
assert(gfx.ResampleAlwaysSharpen=="1", gfx.ResampleAlwaysSharpen)
assert(UI.categories.leveling.title=="Leveln" and UI.categories.nav.title=="Navi")
-- Kern-Funktionen in ihren Bereichen (Haendler unter Allgemein, Menueklaenge unter Darstellung)
UI:OpenOptions("general")
assert(UI.activeTab=="options" and UI.contextLabel.text=="Allgemein")
assert(VisibleBox("Beim Händler automatisch reparieren") and VisibleBox("Probehaken"))
assert(not VisibleBox("Menüklänge"))
local order={}
for _,o in ipairs(UI:CategoryEntries("general")) do order[#order+1]=o.section or "" end
local seen,last={},nil
for _,s in ipairs(order) do if s~=last then assert(not seen[s],"Abschnitt zerrissen: "..s) seen[s]=true last=s end end
assert(seen["Hinweise"] and seen["Händler"] and seen["Probe"])
-- Unterpunkt eingerueckt: Gildengeld
for _,o in ipairs(UI:CategoryEntries("general")) do if o.id=="f:core.autoRepairGuild" then assert(o.indent==1) end end
-- Modul: Hauptschalter oben, aus = nur Hinweis
ONE:RegisterFeature("nav.demo",{module="nav",section="Weg",label="Navi-Probe"})
UI:OpenOptions("nav")
assert(VisibleBox("Modul „Navigation“ eingeschaltet") and VisibleBox("Navi-Probe") and VisibleBox("Altlast"))
local entries=UI:CategoryEntries("nav")
assert(entries[1].master, "Hauptschalter zuerst")
ONE.db.modules.nav=false
UI:OpenOptions("nav")
assert(VisibleBox("Modul „Navigation“ eingeschaltet") and not VisibleBox("Navi-Probe"), "Modul aus: nur Hauptschalter")
ONE.db.modules.nav=nil
-- Teilen: gesammelt, unsichtbare bleiben weg
local devOnline=false
UI:AddShareOption({id="demoShare",label="Probe teilen",tooltip="Geht an die Gilde.",get=function() return false end,set=function() end})
UI:AddShareOption({id="demoHidden",label="Nur mit Entwickler",get=function() return false end,set=function() end,visible=function() return devOnline end})
UI:OpenOptions("sharing")
assert(VisibleBox("Probe teilen") and not VisibleBox("Nur mit Entwickler"))
devOnline=true UI:Refresh()
assert(VisibleBox("Nur mit Entwickler"))
-- Bereichsknopf links wechselt, Kopfzeile zeigt den Bereich
local btn
for _,e in ipairs(elements) do if e.categoryId=="look" then btn=e end end
btn.scripts.OnClick(btn)
assert(UI.optionsCategory=="look" and UI.contextLabel.text=="Darstellung" and VisibleBox("Menüklänge"))
-- Zahnrad-Spruenge
UI.frame:Hide()
UI:OpenOptions("leveling")
assert(UI.frame.visible and UI.activeTab=="options" and UI.optionsCategory=="leveling")
UI:OpenOptions("gibtsnicht")
assert(UI.optionsCategory=="leveling", "unbekannter Bereich: bleibt")
-- alte Unterseiten leiten weiter
UI:Navigate("sharing") assert(UI.activeTab=="options" and UI.optionsCategory=="sharing")
UI:Navigate("assists") assert(UI.optionsCategory=="general")
-- jeder Kern-Schalter genau einmal
for _,label in ipairs({"Menüklänge","Tagesüberblick beim Einloggen","Hinweisfenster anzeigen","Ton bei Benachrichtigungen","Hoher Kontrast"}) do
 for _,c in ipairs({"general","look"}) do UI:OpenOptions(c) end
 assert(#Boxes(label)==1,"doppelt oder fehlt: "..label.." "..#Boxes(label))
end
-- Haken schaltet wirklich
UI:OpenOptions("general")
local b=VisibleBox("Probehaken")
b.GetChecked=function() return true end
b.scripts.OnClick(b)
assert(demo==true)
print("OK test_options_101")
