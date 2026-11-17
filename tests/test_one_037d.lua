-- Offline tests for ONE 0.3.7d. Run: texlua tests/test_one_037d.lua src
local root=arg[1] or 'src'
local Mock={}
Mock.__index=Mock
function Mock:SetSize(w,h) self.w,self.h=w,h end
function Mock:GetWidth()return self.w or 720 end
function Mock:GetHeight()return self.h or 540 end
function Mock:SetHeight(v)self.h=v end
function Mock:SetWidth(v)self.w=v end
function Mock:SetPoint(...)self.point={...} end
function Mock:ClearAllPoints()self.point=nil end
function Mock:SetAllPoints()self.allpoints=true end
function Mock:SetFrameStrata(v)self.strata=v end
function Mock:SetFrameLevel(v)self.level=v end
function Mock:GetFrameLevel()return self.level or 1 end
function Mock:EnableMouse(v)self.mouse=v end
function Mock:SetPropagateMouseClicks(v)self.propagate=v end
function Mock:SetClampedToScreen(v)self.clamped=v end
function Mock:SetMovable(v)self.movable=v end
function Mock:RegisterForDrag(v)self.drag=v end
function Mock:RegisterForClicks(...)end
function Mock:GetEffectiveScale()return 1 end
function Mock:GetCenter()return 100,100 end
function Mock:StartMoving()self.moving=true end
function Mock:StopMovingOrSizing()self.moving=false end
function Mock:SetTexture(t)self.texture=t end
function Mock:SetRotation(t)self.rotation=t end
function Mock:SetTexCoord(...)self.texcoords={...} end
function Mock:SetColorTexture(...)self.color={...} end
function Mock:SetTextColor(...)self.textColor={...} end
function Mock:SetTextInsets(...)end
function Mock:SetFontObject(...)end
function Mock:SetAutoFocus(...)end
function Mock:SetMaxLetters(...)end
function Mock:SetJustifyH(...)end
function Mock:SetEnabled(v)self.enabled=v end
function Mock:GetParent()return self.parent end
function Mock:SetParent(v)self.parent=v end
function Mock:SetScript(e,fn)self.scripts[e]=fn end
function Mock:HookScript(e,fn)self.hooks[e]=fn end
function Mock:SetShown(v)self.shown=v end
function Mock:Show()self.shown=true end
function Mock:Hide()self.shown=false end
function Mock:IsShown()return self.shown~=false end
function Mock:ClearFocus()end
function Mock:GetText()return self.text or '' end
function Mock:SetText(t)
    self.text=t
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function Mock:CreateTexture(_,layer)
    return setmetatable({parent=self,layer=layer,scripts={},hooks={}},Mock)
end
function Mock:CreateFontString(_,layer,font)
    return setmetatable({parent=self,layer=layer,font=font,scripts={},hooks={}},Mock)
end
CreateFrame=function(kind,_,parent)
    return setmetatable({kind=kind,parent=parent,scripts={},hooks={}},Mock)
end
UIParent=CreateFrame('Frame')
Minimap=CreateFrame('Frame',nil,UIParent)
Minimap:SetSize(180,180)
WorldMapFrame=CreateFrame('Frame',nil,UIParent)
WorldMapFrame:SetSize(1260,680)
local canvas=CreateFrame('Frame',nil,WorldMapFrame)
canvas:SetSize(690,500)
WorldMapFrame.GetCanvas=function()return canvas end
WorldMapFrame.GetMapID=function()return 84 end
GameFontHighlight={}
local time=100
GetTime=function()return time end
GetPlayerFacing=function()return 0 end
UnitFullName=function()return 'Tester','Realm' end
GetTaxiMapID=function()return 100 end
InCombatLockdown=function()return false end

local mapOpened, sent={},{ }
local subZone='Brill'
local zoneText='Tirisfal'
GetSubZoneText=function()return subZone end
GetZoneText=function()return zoneText end
GetGuildInfo=function()return 'Testgilde' end
UnitName=function()return 'Tester' end
IsInGuild=function()return true end
local details={
    [84]={name='Silberwald',mapType=3,parentMapID=13},
    [13]={name='Östliche Königreiche',mapType=2,parentMapID=947},
    [947]={name='Azeroth',mapType=1,parentMapID=0},
    [99]={name='Durotar',mapType=3,parentMapID=12},
    [12]={name='Kalimdor',mapType=2,parentMapID=947},
}
C_Map={
    OpenWorldMap=function(map)mapOpened=map end,
    GetMapInfo=function(map)return details[map] end,
    GetBestMapForUnit=function(unit) return 84 end,
    GetPlayerMapPosition=function(map,unit) return {GetXY=function() return .4,.5 end} end,
}
C_ChatInfo={SendAddonMessage=function(prefix,message,channel)
    assert(prefix=='ONEGEO1' and channel=='GUILD')
    sent[#sent+1]=message
    return true
end}
C_Timer={After=function(_,fn)fn() end,NewTicker=function(_,fn)end}
GameTooltip={lines={}}
function GameTooltip:SetOwner(owner,anchor)self.owner=owner;self.anchor=anchor;self.lines={} end
function GameTooltip:SetText(s)self.title=s end
function GameTooltip:AddLine(s)self.lines[#self.lines+1]=s end
function GameTooltip:AddDoubleLine(a,b)self.lines[#self.lines+1]=a..': '..b end
function GameTooltip:Show()self.shown=true end
function GameTooltip:Hide()self.shown=false end
local ONE={db={minimap={angle=225,hidden=false},guild={locationConsent={}}},Themes={},Widgets={},modules={}}
ONE.db.guild.locationConsent['Testgilde|Tester-Realm']=true
function ONE.Themes:RegisterPanel()end
function ONE.Themes:RegisterText()end
function ONE.Themes:RegisterRule()end
function ONE.Widgets:Button(parent,title,w,h,point,x,y,click)
    local b=CreateFrame('Button',nil,parent)
    b:SetText(title);b:SetSize(w,h);b:SetPoint(point,parent,point,x,y)
    b:SetScript('OnClick',click)
    return b
end
function ONE.Widgets:NaviArrow(parent,size,point,x,y,click,tip)
    local b=CreateFrame('Button',nil,parent)
    b:SetSize(size,size);b:SetPoint(point,parent,point,x,y)
    b:SetScript('OnClick',click)
    b.tip=tip
    return b
end
_G.ProjectONE=ONE
local guild={}
guild.Roster={Members=function()return {{name='Beta',online=true},
    {name='Alice',online=true},{name='Offline',online=false}} end,
    Request=function(self)self.requested=true end}
assert(loadfile(root..'/ONE_Guild/Presence.lua'))('ONE_Guild',guild)
assert(loadfile(root..'/ONE_Guild/Pins.lua'))('ONE_Guild',guild)
assert(loadfile(root..'/ONE_Core/MinimapButton.lua'))('ONE_Core',ONE)

-- Minimap icon should be bigger AND its center near the rim, NOT one
-- entire button radius outside it (the exact issue from the screenshot).
ONE.MinimapButton:Initialize()
local b=ONE.MinimapButton.button
local x,y=b.point[4],b.point[5]
local d=math.sqrt(x*x+y*y)
assert(math.abs(d-(90+3))<0.01,'Minimap icon still too far from rim')
assert(b.w==26,'Minimap-Knopf soll so gross sein wie andere Addon-Knoepfe (26)')
-- 0.4.8: Ausrufezeichen bei Neuigkeiten, verschwindet beim Oeffnen des Reiters
local mini=ONE.MinimapButton
assert(mini.badge and mini.badge.shown==false,'Ausrufezeichen anfangs aus')
mini:SetAlert('groups','Boo sucht eine Gruppe','groups')
assert(mini.badge.shown and mini:AlertTab()=='groups')
mini:ClearAlert('groups')
assert(mini.badge.shown==false and mini:AlertTab()==nil)
Minimap:SetSize(220,220)
ONE.MinimapButton:Refresh()
local x2,y2=b.point[4],b.point[5]
assert(math.abs(math.sqrt(x2*x2+y2*y2)-(110+3))<.01,'Minimap scaling broken')

-- Old 0.3.7c position packets must still be supported; new location
-- label supplements those packets and does not prolong a live presence.
local presence=guild.Presence
presence:Receive('ONEGEO1','P:84:4000:5000','GUILD','Beta-Realm')
assert(#presence:ActivePeers()==1)
local peer=presence:ActivePeers()[1]
assert(peer.mapID==84 and peer.x==.4 and peer.y==.5)
local original=peer.seen
presence:Receive('ONEGEO1','L:Brill','GUILD','Beta-Realm')
peer=presence:ActivePeers()[1]
assert(peer.subZone=='Brill' and peer.seen==original,'Location label incorrectly extends presence')
local where=guild.Pins:LocationDetails(peer)
assert(where.world=='Azeroth' and where.continent=='Östliche Königreiche'
    and where.region=='Silberwald' and where.place=='Brill')
assert(where.coordinates=='40.0 / 50.0')
presence:Receive('ONEGEO1','P:84:4100:5000','GUILD','Beta-Realm')
assert(presence:ActivePeers()[1].subZone=='Brill','Location lost during movement')
presence:Receive('ONEGEO1','P:99:4200:5100','GUILD','Beta-Realm')
assert(presence:ActivePeers()[1].subZone==nil,'Old subzone leaked across zones')
presence:Receive('ONEGEO1','P:84:4000:5000','GUILD','Beta-Realm')
presence:Receive('ONEGEO1','L:Brill','GUILD','Beta-Realm')

-- 0.4.9c: eigene Positionsmeldung (Absender mit Realm) erzeugt keinen eigenen Punkt
local beforeOwn=#presence:ActivePeers()
presence:Receive('ONEGEO1','P:84:1000:1000','GUILD','Tester-Realm')
assert(#presence:ActivePeers()==beforeOwn,'eigener Punkt darf nicht erscheinen')
local savedFull=UnitFullName
UnitFullName=function() return 'Tester',nil end
GetNormalizedRealmName=function() return 'Realm' end
presence:Receive('ONEGEO1','P:84:1000:1000','GUILD','Tester-Realm')
assert(#presence:ActivePeers()==beforeOwn,'auch ohne Realm im eigenen Namen erkannt')
presence:Receive('ONEGEO1','P:84:1000:1000','GUILD','Tester-Anderswo')
assert(#presence:ActivePeers()==beforeOwn+1,'gleicher Name auf anderem Realm ist jemand anderes')
presence:Receive('ONEGEO1','OFF','GUILD','Tester-Anderswo')
UnitFullName=savedFull
-- Search panel and marker tooltip on the Blizzard world map.
guild.Pins:Attach()
local pins=guild.Pins
assert(pins.collapsed==true,'Kartensuche startet eingeklappt (Karte frei fuer andere Addons)')
pins.collapsed=false -- wie nach Klick auf "+"
assert(pins.searchPanel.parent==WorldMapFrame and pins.searchPanel.point[1]=='TOPLEFT','Kartensuche haengt an der Karte')
assert(pins.searchPanel.point[2]==WorldMapFrame and pins.searchPanel.point[4]==70)
assert(pins.searchPanel.w==236 and pins.searchPanel.h<220,'Panel still too large')
assert(not pins.waypointButton and not guild.Navigation,'No dead navigation control allowed')
assert(#pins:SearchMatches('bet',5)==1)
pins.searchBox:SetText('be')
assert(pins.searchRows[1].name=='Beta-Realm')
pins.searchRows[1].button.scripts.OnClick()
assert(pins.selected=='Beta-Realm' and mapOpened==84,'Search selection broken')
pins:Refresh()
assert(pins.pool[1] and pins.pool[1].peerName=='Beta-Realm','Marker missing')
pins.pool[1].scripts.OnEnter(pins.pool[1])
assert(GameTooltip.title=='Beta' and GameTooltip.shown)
local lines=table.concat(GameTooltip.lines,' | ')
assert(lines:find('Welt: Azeroth',1,true) and lines:find('Kontinent: Östliche Königreiche',1,true)
    and lines:find('Region: Silberwald',1,true) and lines:find('Ort / Untergebiet: Brill',1,true),lines)
pins.pool[1].scripts.OnLeave()
assert(not GameTooltip.shown)
pins.searchRows[1].button.hooks.OnEnter(pins.searchRows[1].button)
assert(GameTooltip.shown,'Search row hover missing')

-- 0.3.8b: Navi-Knopf nur mit installiertem, aktivem ONE_Nav und Live-Auswahl.
pins:RefreshSearch()
assert(not pins.navButton:IsShown(),'Navi button without ONE_Nav')
local navTarget
ONE.modules.nav={StartTo=function(_,name) navTarget=name end}
function ONE:IsEnabled(id) return self.db.modules==nil or self.db.modules[id]~=false end
local before=pins.searchPanel.h
pins:RefreshSearch()
assert(pins.navButton:IsShown() and pins.navButton.tip(pins.navButton)=='Navi zu Beta','Navi-Pfeil fehlt')
assert(pins.searchPanel.h==before+32,'Panel must grow for Navi button')
pins.navButton.scripts.OnClick()
assert(navTarget=='Beta-Realm','Navi button must start ONE_Nav for selected member')
ONE.db.modules={nav=false}
pins:RefreshSearch()
assert(not pins.navButton:IsShown(),'Paused ONE_Nav must hide Navi button')
ONE.db.modules=nil
ONE.modules.nav=nil
pins:RefreshSearch()

-- Sender emits normal positions and a separate optional name; old receivers
-- ignore L packets but still receive valid P packets.
presence:Broadcast(true)
assert(sent[1]=='P:84:4000:5000' or sent[1]:sub(1,2)=='P:')
assert(sent[2]=='L:Brill','Missing optional subzone transmission')
-- OFF removes position and all optional details.
presence:Receive('ONEGEO1','OFF','GUILD','Beta-Realm')
assert(#presence:ActivePeers()==0)
assert(pins:LocationDetails(nil) and #presence:ActivePeers()==0)
pins.collapseButton.scripts.OnClick()
assert(pins.searchPanel.h==31 and not pins.searchField:IsShown())
pins.collapseButton.scripts.OnClick()
assert(pins.searchPanel.h>31 and pins.searchField:IsShown())
WorldMapFrame:Hide()
WorldMapFrame.hooks.OnHide()
assert(not pins.searchPanel:IsShown())
print('OK: 0.3.7d - Minimap, Karte, Standort-Tooltip, Live-Daten, Kompatibilität, Datenschutz')
