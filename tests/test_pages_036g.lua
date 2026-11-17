-- Seiteneinheit: echte Widget-Konstruktion mit Minimal-WoW-Mock,
-- inkl. Leerdaten im Gildenkalender. Kein grafischer Client-Test.
local root=(arg[0]:match('^(.*)/tests/') or '.')
local ONE={}
assert(loadfile(root..'/src/ONE_Core/Geometry.lua'))('ONE_Core',ONE)
local G=ONE.Geometry
local R=G:PageHeader(726)
assert(R.x==0 and R.titleY==-4 and R.subtitleY==-35 and R.width==726)
assert(G:AssertEmptyRegion(726,437,{x=24,y=-152,width=678,height=114}))
local ok=pcall(function() G:AssertEmptyRegion(726,437,{x=600,y=-152,width=130,height=114})end)
assert(not ok,'Zu breiter Leerzustand nicht abgefangen')
ok=pcall(function() G:AssertEmptyRegion(726,437,{x=24,y=-380,width=678,height=114})end)
assert(not ok,'Zu tief liegender Leerzustand nicht abgefangen')
ok=pcall(function() G:AssertEmptyRegion(726,437,{x=24,y=-100,width=678,height=20})end)
assert(not ok,'Unlesbar niedriger Leerzustand erlaubt')

local made={}
local function Element(kind,parent)
 local f=setmetatable({kind=kind,parent=parent,visible=true},{__index=function(_,k) if type(k)=="string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end end})
 function f:SetPoint(...)self.point={...}end
 function f:SetSize(w,h)self.w=w;self.h=h end
 function f:SetWidth(w)self.w=w end
 function f:SetHeight(h)self.h=h end
 function f:SetAllPoints()end
 function f:SetText(v)self.text=v end
 function f:GetText()return self.text end
 function f:SetJustifyH(v)self.align=v end
 function f:SetJustifyV()end
 function f:SetWordWrap()end
 function f:SetFontString(v)self.fontString=v end
 function f:SetScript(k,v)self[k]=v end
 function f:Show()self.visible=true end
 function f:Hide()self.visible=false end
 function f:SetTexture(v)self.texture=v end
 function f:SetScrollChild()end
 function f:SetVerticalScroll()end
 function f:GetStringHeight()return 20 end
 function f:GetFrameLevel()return 2 end
 function f:SetFrameLevel(level)self.level=level end
 function f:CreateTexture()return Element('Texture',self)end
 function f:CreateFontString(_,_,font)
  local str=Element('FontString',self);str.font=font;return str
 end
 made[#made+1]=f
 return f
end
CreateFrame=function(kind,_,parent)return Element(kind,parent)end
local registered={}
ONE.Themes={
 RegisterText=function(_,font,role)registered[#registered+1]={font=font,role=role}end,
 RegisterRule=function(_,tex,role)registered[#registered+1]={texture=tex,role=role}end,
 RegisterPanel=function()end,StyleButton=function()end,ApplyButton=function()end,
}
assert(loadfile(root..'/src/ONE_Core/Widgets.lua'))('ONE_Core',ONE)
local parent=Element('Frame')
local title,desc=ONE.Widgets:PageHeader(parent,'Titel','Beschreibung',726)
assert(title.font=='GameFontNormalLarge' and title.point[5]==-4)
assert(desc.font=='GameFontHighlightSmall' and desc.point[5]==-35)
assert(title.w==desc.w and title.w==726)
local empty=ONE.Widgets:EmptyState(parent,
 {x=24,y=-152,width=678,height=114,parentWidth=726,parentHeight=437},
 'Noch keine Termine','Später aktualisieren')
assert(empty.w==678 and empty.h==114 and empty.point[4]==24 and empty.point[5]==-152)
assert(empty.__oneEmptyTitle.align=='CENTER' and empty.__oneEmptyDescription.align=='CENTER')
assert(empty.__oneEmptyTitle.text=='Noch keine Termine')
empty:SetContent('Lade...','Einen Moment')
assert(empty.__oneEmptyTitle.text=='Lade...' and empty.__oneEmptyDescription.text=='Einen Moment')

ONE.UI={Layout={width=726,Columns=function(_,weights) return G:Columns(726,weights) end},
 RegisterBackHandler=function()end,UpdateBackButton=function()end}
_G.ProjectONE=ONE
local guild={Calendar={events={},status='Keine Termine',RequestRefresh=function(self) self.refreshed=true end,
 GetCurrentTime=function() return {year=2026,month=11,monthDay=12,hour=10,minute=0} end},
 Guild={GetInfo=function()return {name='',rank='',members=0}end},
 Reminders={GetThresholds=function()return {15,5,0}end}}
assert(loadfile(root..'/src/ONE_Core/Kit.lua'))('ONE_Core',ONE)
assert(loadfile(root..'/src/ONE_Guild/UI.lua'))('ONE_Guild',guild)
local page=Element('Frame')
local refresh=guild.UI:BuildCalendar(page)
local calendarEmpty
for _,e in ipairs(made)do
 if e.__oneEmptyTitle and e.__oneEmptyTitle.text=='Kein Eintrag' then calendarEmpty=e end
end
assert(calendarEmpty,'Kalender-Leerzustand (Tagesansicht) nicht erstellt')
refresh();assert(calendarEmpty.visible,'Keine Termine: Leerzustand fehlt')
-- 0.4.9f: Tagesansicht fragt den Kalender nach dem ausgewaehlten Tag (heute)
local entry={key='alpha',title='Gildenabend',calendarType='GUILD_EVENT',startTime={year=2026,month=11,monthDay=12,hour=19,minute=45}}
guild.Calendar.GetCurrentTime=function() return {year=2026,month=11,monthDay=12,hour=10,minute=0} end
guild.Calendar.GetDay=function(_,y,m,d) if y==2026 and m==11 and d==12 then return {entry} end return {} end
guild.Calendar.events={entry}
refresh();assert(not calendarEmpty.visible,'Mit Termin muss Leerzustand verschwinden')
guild.Calendar.GetDay=function() return {} end
guild.Calendar.events={}
refresh();assert(calendarEmpty.visible,'Leerer Kalender muss Leerzustand wieder einblenden')
local refreshButton
for _,e in ipairs(made) do if e.kind=='Button' and e.text=='Jetzt aktualisieren' then refreshButton=e end end
assert(refreshButton and refreshButton.OnClick,'Kalender-Aktion verschwunden')
refreshButton.OnClick();assert(guild.Calendar.refreshed,'Kalender-Aktualisierung wurde beschaedigt')
print('OK: zentrale Seitentitel, Leerzustandsgeometrie, Kalender leer/voll, Aktualisierung')
