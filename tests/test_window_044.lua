-- Ausführen: texlua tests/test_theme_engine.lua
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
local ONE = {}
for _, file in ipairs({"Core.lua", "Themes.lua", "Kit.lua", "Geometry.lua", "WindowScale.lua", "Widgets.lua", "Notifications.lua", "UI.lua", "Welcome.lua"}) do
    assert(loadfile(path .. "/src/ONE_Core/" .. file))("ONE_Core", ONE)
end
ProjectONEDB = {soundEnabled=false, guild={noticeHistory={}},theme={selected="hybrid",uiSounds=true}}
assert(eventFrame and eventFrame.scripts.OnEvent)
eventFrame.scripts.OnEvent(eventFrame,"ADDON_LOADED","ONE_Core")
assert(ONE.started and ONE.UI.activeTab=="home")
-- 0.4.4: alle frueheren Designs gehen im nativen Blizzard-Look auf
assert(ONE.db.theme.selected=="native", "Altes Design muss zu native migrieren")
assert(not ONE.UI.views.themes, "Designauswahl entfaellt im nativen Look")
assert(ONE.UI.sidebarButtons.home and ONE.UI.frame.Tabs and #ONE.UI.frame.Tabs>=2, "Reiter unten fehlen")
-- 0.6.9: alle Einstellungen in Optionen (Bereiche links), keine Unterseiten mehr
assert(not ONE.UI.views.modules and not ONE.UI.tabs.modules and ONE.UI.tabs.options, "Module stehen in den Optionen")
assert(ONE.UI.inset, "Eingelassene Innenflaeche fehlt")
-- 0.6.8: Blizzard-Aussehen mit Symbolleiste links, breiteres Fenster, Inhaltsflaeche bleibt 726x437
assert(ONE.UI.frame._SetSize[1]==858 and ONE.UI.frame._SetSize[2]==533)
assert(ONE.UI.sidebar, "Symbolleiste links fehlt")
assert(ONE.WindowScale.WIDTH==858 and ONE.WindowScale.HEIGHT==533, "Fensterskalierung kennt die neue Groesse")
local function Click(label, idx)
 local count=0
 for _,e in ipairs(elements) do
  if e.kind=="Button" and e.text==label then
   count=count+1
   if count==(idx or 1) then
    assert(e.scripts.OnClick,"Button ohne Handler: "..label)
    e.scripts.OnClick(e)
    return e
   end
  end
 end
 error("Button fehlt: "..label)
end
-- Menueklaenge in den Optionen statt eigener Designseite (0.6.9: Bereich Darstellung)
ONE.UI:OpenOptions("look")
assert(ONE.UI.activeTab=="options" and ONE.UI.optionsCategory=="look")
-- 0.4.9d: Haekchen statt AN/AUS-Knoepfe
local function CheckByLabel(text)
 for _,e in ipairs(elements) do
  if e.kind=="CheckButton" and e.label and e.label.text==text then return e end
 end
 error("Haekchen fehlt: "..text)
end
local function Visible(e) while e do if e.visible==false then return false end e=e.parent end return true end
local soundBefore=ONE.db.theme.uiSounds
local clicks=CheckByLabel("Menüklänge")
assert(Visible(clicks),"Menüklänge im Bereich Darstellung sichtbar")
ONE.UI:OpenOptions("general")
clicks.GetChecked=function() return not soundBefore end
clicks.scripts.OnClick(clicks)
assert(ONE.db.theme.uiSounds==not soundBefore)
local toastBox=CheckByLabel("Hinweisfenster anzeigen")
toastBox.GetChecked=function() return false end
toastBox.scripts.OnClick(toastBox)
assert(ONE.db.toastEnabled==false)
toastBox.GetChecked=function() return true end
toastBox.scripts.OnClick(toastBox)
assert(ONE.db.toastEnabled==true)
for _,label in ipairs({"Ton bei Benachrichtigungen","Tagesüberblick beim Einloggen","Hinweisfenster anzeigen"}) do assert(Visible(CheckByLabel(label)),label) end
assert(not Visible(clicks),"anderer Bereich: Menüklänge ausgeblendet")
-- jeden Schalter nur einmal (frueher doppelt: Menueklaenge, Tagesueberblick, Kalender-Erinnerungen)
for _,label in ipairs({"Menüklänge","Tagesüberblick beim Einloggen"}) do
 local n=0
 for _,e in ipairs(elements) do if e.kind=="CheckButton" and e.label and e.label.text==label then n=n+1 end end
 assert(n==1,"doppelt: "..label)
end
ONE.UI:OpenOptions("look")
assert(Visible(CheckByLabel("Hoher Kontrast")))
for _,e in ipairs(elements) do assert(not (e.kind=="Button" and type(e.text)=="string" and e.text:find(": AN$")), "kein AN/AUS-Knopf mehr: "..tostring(e.text)) end
assert(ONE.UI.themeStatus.text:find("v",1,true),"Versionsanzeige fehlt")
assert(ONE.db.soundEnabled==false)
local guild = {
 Calendar={events={},status="Keine Termine"},
 Guild={GetInfo=function() return {name="Gilde",rank="Mitglied",members=4} end},
 Reminders={GetThresholds=function() return {60,15,5,0} end},
}
assert(loadfile(path.."/src/ONE_Guild/UI.lua"))("ONE_Guild",guild)
guild.UI:RegisterTabs()
assert(ONE.UI.tabs.guild and ONE.UI.tabs.calendar)
assert(#ONE.Themes.panels>=7,"Gilden-Karten nicht zentral registriert")
ONE.UI:Navigate("guild")
assert(ONE.UI.sidebarButtons.guild.__oneSelected and ONE.UI.pathLabel.text=="Gilde")
-- 0.6.8: Symbolknopf der Leiste zeigt die Auswahl, Unterseiten markieren ihren Hauptbereich
do
 local side=ONE.UI.sidebarButtons.guild.__oneSide
 assert(side and side.bar.visible~=false and side.label.text=="Gilde", "Gilde in der Leiste markiert")
 assert(ONE.UI.sidebarButtons.home.__oneSide.bar.visible==false, "Startseite nicht markiert")
 ONE.UI:Navigate("modules")
 assert(ONE.UI.activeTab=="options" and ONE.UI.optionsCategory=="general", "alte Unterseite Module leitet in Optionen")
 assert(ONE.UI.sidebarButtons.options.__oneSide.bar.visible~=false, "Optionen markiert")
 assert(ONE.UI.contextLabel.text=="Allgemein", "Bereich in der Kopfzeile")
 ONE.UI:SetContext("calendar","November 2026")
 ONE.UI:Navigate("calendar")
 assert(ONE.UI.contextLabel.text=="November 2026", "Zusatzangabe in der Kopfzeile")
 ONE.UI:Navigate("guild")
 assert(ONE.UI.contextLabel.text:find("Gilde",1,true), "Gildenseite schreibt Name und Zahlen in die Kopfzeile")
end
ONE.UI:Navigate("calendar")
assert(ONE.UI:GoBack() and ONE.UI.activeTab=="guild")
assert(ONE.UI:GoForward() and ONE.UI.activeTab=="calendar")
local former=0
for _,e in ipairs(elements) do
 if e.kind=="Button" and e.__oneStyle and e._SetSize and e.parent~=ONE.UI.frame then -- Kopfleiste (Zurueck) ist bewusst Blizzard-klein
   assert(e._SetSize[2]>=22,"Knopf flacher als ein Blizzard-Knopf (22)")
   former=former+1
 end
end
assert(former>15,"Zu wenige gemeinsame Buttons registriert")
-- Geometrie-Runtimecheck: Jeder gemeinsame Button, dessen Elternframe feste Maße
-- besitzt, muss vollständig im sichtbaren Frame liegen (nicht nur im Rastermodell).
local checkedBounds=0
for _,e in ipairs(elements) do
 if e.kind=="Button" and e.__oneStyle and e.parent and e.parent._SetSize and e._SetSize and e._SetPoint then
  local pw,ph=unpack(e.parent._SetSize)
  local bw,bh=unpack(e._SetSize)
  local args=e._SetPoint
  if type(pw)=="number" and type(ph)=="number" and type(bw)=="number" and type(bh)=="number"
      and args[1]=="TOPLEFT" and args[2]==e.parent and args[3]=="TOPLEFT" then
   local x,y=args[4],args[5]
   assert(x>=0 and y<=0 and x+bw<=pw and -y+bh<=ph,
     string.format("Button %s ragt aus Elternframe: (%s,%s) %sx%s in %sx%s",
       e.text or "",tostring(x),tostring(y),bw,bh,pw,ph))
   checkedBounds=checkedBounds+1
  end
 end
end
assert(checkedBounds>=7,"Zu wenige Button-Aussenkanten geprueft")
assert(ONE.Themes:Current().name=="Blizzard")
assert(ONE.Themes:PlaySound("preview",nil,true))
assert(#sounds>0)
ONE.UI:Navigate("home")
local heroFound=false
for _,e in ipairs(elements) do
 if type(e.texture)=="string" and e.texture:find("TripHero.tga",1,true) then heroFound=true end
end
assert(heroFound,"Startbild fehlt")
-- 0.3.6f: Reale Erzeugung im WoW-Mock, nicht nur Quelltextsuche.
-- Diese vier gemeldeten Aktionen duerfen ihre berechneten Bezugskanten
-- bei neuen Modulen / Farbpaletten nicht verlassen.
local function ActionGeometry(label,expectX,expectW)
 local found
 for _,e in ipairs(elements) do
  if e.kind=='Button' and e.text==label then found=e;break end
 end
 assert(found,'Aktionsbutton fehlt: '..label)
 assert(found.__oneActionLayout,'Kein gemeinsamer Aktionsvertrag: '..label)
 assert(found._SetPoint and found._SetSize,'Aktionsmaße fehlen: '..label)
 assert(found._SetPoint[4]==expectX,'Falsche linke Kante: '..label)
 assert(found._SetSize[1]==expectW,'Falsche Aktionsbreite: '..label)
 assert(found._SetSize[2]==ONE.Geometry.tokens.buttonHeight,'Falsche Hoehe: '..label)
 return found
end
ActionGeometry('Heutige Termine ansehen',24,248)
-- 15.11.2026: Kalender-Fusszeile mit zwei gleich grossen Knoepfen (150 breit, rechts buendig)
do
 local refresh,create
 for _,e in ipairs(elements) do
  if e.kind=='Button' and e.text=='Jetzt aktualisieren' then refresh=e end
  if e.kind=='Button' and e.text=='Termin erstellen' then create=e end
 end
 assert(refresh and create,'Kalender-Knoepfe fehlen')
 local inset=ONE.Geometry.tokens.panelStrokeInset
 assert(refresh._SetSize[1]==150 and create._SetSize[1]==150,'gleich breit')
 assert(refresh._SetPoint[4]==726-inset-150 and create._SetPoint[4]==726-inset-300-8,'rechts buendig nebeneinander')
end
ActionGeometry('Kalender öffnen',24,176)
ActionGeometry('Gildenübersicht',24,176)
-- 0.4.3: Startseite aus Modul-Kacheln, Navi-Seite aus ONE_Nav
assert(ONE.Kit.tiles.termine and ONE.Kit.tiles.gilde, "Kacheln Termine und Gilde fehlen")
local nav={}
local navToc=assert(io.open(path.."/src/ONE_Nav/ONE_Nav.toc")):read("*a")
for name in navToc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(path.."/src/ONE_Nav/"..name))("ONE_Nav",nav) end
assert(ONE.UI.tabs.nav and ONE.Kit.tiles.navi, "Navi-Seite und -Kachel fehlen")
assert(ONE.UI.sidebarButtons.nav, "Navi im Menue fehlt")
ONE.UI:Navigate("home")
local tileButtons=0
for _,label in ipairs({"Kalender öffnen","Gildenübersicht","Navi öffnen"}) do
 for _,e in ipairs(elements) do
  if e.kind=="Button" and e.text==label and e.visible~=false and e.__oneActionLayout then tileButtons=tileButtons+1 break end
 end
end
assert(tileButtons==3, "Drei Kacheln mit Aktion erwartet, gefunden: "..tileButtons)
Click("Navi öffnen")
assert(ONE.UI.activeTab=="nav")
local navTexts=""
for _,e in ipairs(elements) do if e.kind=="FontString" and e.text then navTexts=navTexts.."|"..e.text end end
assert(navTexts:find("Kein Navi aktiv.",1,true) and navTexts:find("Das Gildenmodul ist nicht installiert.",1,true))
-- Mit Gildenmodul: live teilende Mitglieder erscheinen mit Navi-Knopf
ONE.modules.guild={LivePeers=function() return {{name="Beta-Realm",mapID=1411,x=.5,y=.5,seen=0}} end,
  DescribePeer=function() return {region="Durotar"} end, GetPeer=function() return nil end}
ONE.UI:Refresh()
local found=false
for _,e in ipairs(elements) do if e.kind=="FontString" and e.text=="Beta" then found=true end end
assert(found, "Live-Mitglied fehlt auf der Navi-Seite")
-- 0.5.0: Fenstertitel "Guild Trip" plus eigener Gildenname
local titleTexts={}
local function Titles() titleTexts={} for _,e in ipairs(elements) do if e.kind=="FontString" and type(e.text)=="string" and e.text:find("^Guild Trip") then titleTexts[#titleTexts+1]=e.text end end return titleTexts end
local oldGuildInfo=GetGuildInfo
GetGuildInfo=function() return "Die Testgilde" end
ONE.UI.ApplyTitle()
local hasGuild=false
for _,t in ipairs(Titles()) do if t=="Guild Trip  ·  Die Testgilde" then hasGuild=true end end
assert(hasGuild, "Titel mit Gildenname fehlt")
GetGuildInfo=oldGuildInfo
-- 0.6.9: lange Bereiche scrollen statt blaettern; Bereichsliste links, Module mit Hauptschalter
do
 for i=1,40 do ONE:RegisterFeature("core.scrolltest"..i,{label="Scrolltest "..i}) end
 ONE.UI:OpenOptions("general")
 local last
 for _,e in ipairs(elements) do if e.kind=="CheckButton" and e.label and e.label.text=="Scrolltest 40" then last=e end end
 assert(last and Visible(last),"alle Eintraege im Bereich (scrollbar)")
 assert(ONE.UI.optionsChild._SetHeight[1]>40*26,"Scrollflaeche waechst mit")
 ONE:RegisterModule("demo",{title="Demo"})
 ONE.UI:OpenOptions("demo")
 local master=CheckByLabel("Modul „Demo“ eingeschaltet")
 assert(Visible(master),"Modul-Hauptschalter oben im Bereich")
 -- Bereichsknoepfe links: Klick wechselt
 local btn
 for _,e in ipairs(elements) do if e.categoryId=="sharing" then btn=e end end
 assert(btn,"Bereich Teilen in der Liste")
 btn.scripts.OnClick(btn)
 assert(ONE.UI.optionsCategory=="sharing" and not Visible(master))
end
-- Ansicht, die wie ihr Reiter heisst (Dungeons › Dungeons): Wechsel zu einer anderen Ansicht bleibt markiert
do
    local before=ONE.UI.activeTab
    ONE.UI.activeTab="probe"
    ONE.UI:SetViews("probe",{{key="probe",label="Probe"},{key="b",label="B"}},"b")
    assert(ONE.UI.viewSets.probe.active=="b","aktive Ansicht springt nicht auf den Reiternamen zurueck")
    ONE.UI.viewSets.probe=nil
    ONE.UI.activeTab=before
end
assert(not ONE.UI.frame.__oneScaleHandles, "Hauptfenster: Groesse nur ueber Optionen (Prozent), nicht per Ziehen")
print("OK: 0.5.0 - Fenstertitel Guild Trip mit Gildenname")
print("OK: 0.4.4a - natives Fenster, Reiter, Migration, Optionen, Guild, Navigation, Kacheln und Buttons")
