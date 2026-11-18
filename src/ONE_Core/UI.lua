local _, ONE = ...
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local UI = { tabs={}, views={}, order={}, history={}, forwardHistory={},
    backHandlers={}, sidebarButtons={}, shareOptions={}, feeds={} }
ONE.UI=UI

-- Das feste Fenster ist 1010 UI-Einheiten breit. Der Inhalt liegt zwischen
-- x=251 und x=977, also 726 Einheiten. Alle Module benutzen dasselbe Raster.
-- Ein späteres Fenster-Resize muss diese Definition ebenfalls berücksichtigen.
local Layout = {width=ONE.Geometry.tokens.contentWidth, gutter=ONE.Geometry.tokens.columnGap}
UI.Layout = Layout

-- Keine mehrfachen, voneinander abweichenden Spalten-Berechnungen mehr.
function Layout:Columns(weights)
    return ONE.Geometry:Columns(self.width,weights,self.gutter)
end
function Layout:Actions(card,weights)
    return ONE.Geometry:Actions(card,weights)
end

local NAV_ORDER={home=1,guild=2,calendar=3,dungeons=4,groups=5,crafting=6,classes=7,quests=7.5,leveling=7.5,nav=8,options=9}
-- 0.4.4 nativer Look: Blizzard-Fenster (PortraitFrameTemplate) mit eingelassener
-- Innenflaeche und Reitern unten wie im Charakterfenster. Die Inhaltsflaeche
-- bleibt 726x437, damit alle Seiten unveraendert hineinpassen.
local WINDOW={width=774,height=548,insetX=12,insetTop=60,insetBottom=28,contentX=24,contentY=72}
UI.WINDOW=WINDOW
-- 0.6.8 (Nutzer-Wunsch 17.11.2026): im Blizzard-Aussehen Hauptbereiche als Symbolleiste
-- links (eigene Goldsymbole) statt Reiter unten, Seitenname gross in der Kopfzeile.
-- Die Inhaltsflaeche bleibt 726x437, nur das Fenster wird breiter. Das Buch behaelt
-- seine Masse (Buchbild ist auf 774x548 gezeichnet).
local NATIVE_WINDOW={width=858,height=533,insetX=96,insetRight=12,insetTop=60,insetBottom=12,
    contentX=108,contentY=72,sideX=10,sideWidth=80,navHeight=44,navGap=2}
UI.NATIVE_WINDOW=NATIVE_WINDOW
-- Unterseiten markieren in der Leiste ihren Hauptbereich
local VIEW_PARENT={["guild-members"]="guild",today="home"}
UI.VIEW_PARENT=VIEW_PARENT
local function BookActive() return false end
local ICONS="Interface\\AddOns\\ONE_Core\\Textures\\Common\\TabIcons"
local ICON_INDEX={home=0,guild=1,calendar=2,dungeons=3,groups=3,crafting=4,classes=5,quests=6,nav=7,options=8,leveling=10}
local NAV_LABEL={home="Startseite",guild="Gilde",calendar="Kalender",today="Heute",
    dungeons=T("Dungeons"),groups=T("Gruppen"),crafting=T("Berufe"),classes=T("Klasse"),quests=T("Quests"),leveling=T("Leveln"),nav=T("Navi"),options=T("Optionen")}

local function Label(parent,content,font,x,y,width,roleOverride)
    local obj=parent:CreateFontString(nil,"OVERLAY",font or "GameFontNormal")
    obj:SetPoint("TOPLEFT",x,y)
    obj:SetWidth(width or 520)
    obj:SetJustifyH("LEFT")
    obj:SetText(T(content))
    local role="text"
    if font=="GameFontHighlightSmall" then role="soft"
    elseif font=="GameFontNormalSmall" or font=="GameFontNormal" then role="accent" end
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(obj,roleOverride or role) end
    return obj
end
local function Button(parent,text,width,x,y,callback,variant)
    -- Bestehende Listenelemente und Optionen nutzen ebenfalls den zentralen
    -- Vertrag; explizite Breiten sind nur eine im Layout definierte Region.
    return ONE.Widgets:ActionButton(parent,text,{x=x,y=y,width=width},callback,variant,"fill")
end
local function Action(parent,text,region,callback,variant,profile,align)
    return ONE.Widgets:ActionButton(parent,text,region,callback,variant,profile,align)
end
local function Panel(parent,x,y,w,h)
    local panel=CreateFrame("Frame",nil,parent)
    panel:SetPoint("TOPLEFT",x,y)
    panel:SetSize(w,h)
    ONE.Themes:RegisterPanel(panel)
    return panel
end

-- Reiter unten am Fenster, sortiert nach NAV_ORDER.
-- Knopf der Symbolleiste: Goldsymbol oben, Name darunter, Auswahl mit goldener Kante links
function UI:SideButton(id,title)
    local parent=self.sidebar or self.frame
    local b=CreateFrame("Button","ProjectONEMainWindowTab"..id,parent)
    local W=NATIVE_WINDOW
    b:SetSize(W.sideWidth-8,W.navHeight)
    local sel=b:CreateTexture(nil,"BACKGROUND")
    sel:SetAllPoints(b)
    sel:SetColorTexture(1,.82,0,.13)
    local bar=b:CreateTexture(nil,"BORDER")
    bar:SetPoint("TOPLEFT",b,"TOPLEFT",0,0)
    bar:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",0,0)
    bar:SetWidth(3)
    bar:SetColorTexture(1,.82,0,.95)
    local hover=b:CreateTexture(nil,"HIGHLIGHT")
    hover:SetAllPoints(b)
    hover:SetColorTexture(1,1,1,.07)
    local icon=b:CreateTexture(nil,"ARTWORK")
    icon:SetSize(24,24)
    icon:SetPoint("TOP",b,"TOP",0,-4)
    icon:SetTexture(ICONS)
    local idx=ICON_INDEX[id] or 9
    local col,row=idx%4,math.floor(idx/4)
    icon:SetTexCoord(col/4,(col+1)/4,row/4,(row+1)/4)
    local label=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    label:SetPoint("BOTTOM",b,"BOTTOM",0,4)
    label:SetWidth(W.sideWidth-8)
    label:SetJustifyH("CENTER")
    if label.SetWordWrap then label:SetWordWrap(false) end
    -- Name immer im eigenen Schriftfeld (kein Vorlagen-Text)
    b.SetText=function(_,text) label:SetText(text) end
    b.GetText=function() return label:GetText() end
    b.__oneSide={sel=sel,bar=bar,icon=icon,label=label}
    b:SetText(T(NAV_LABEL[id] or title))
    return b
end
function UI:StyleSideButton(b,selected)
    local r=b and b.__oneSide
    if not r then return end
    if selected then r.sel:Show() r.bar:Show() else r.sel:Hide() r.bar:Hide() end
    local k=selected and 1 or .72
    r.icon:SetVertexColor(k,k,k)
    if selected then r.label:SetTextColor(1,.82,0) else r.label:SetTextColor(.82,.76,.6) end
end
function UI:IsSidebar() return self.sidebar~=nil end
function UI:RelayoutNavigation()
    local keys={}
    for id in pairs(self.sidebarButtons) do keys[#keys+1]=id end
    table.sort(keys,function(a,b) return (NAV_ORDER[a] or 90)<(NAV_ORDER[b] or 90) end)
    local tabs={}
    local W=NATIVE_WINDOW
    local row=0
    for i,id in ipairs(keys) do
        local tab=self.sidebarButtons[id]
        if tab.SetID then tab:SetID(i) end
        if tab.ClearAllPoints then tab:ClearAllPoints() end
        if self.sidebar then
            -- Optionen unten in der Leiste, alles andere von oben
            if id=="options" then tab:SetPoint("BOTTOMLEFT",self.sidebar,"BOTTOMLEFT",4,22)
            else tab:SetPoint("TOPLEFT",self.sidebar,"TOPLEFT",4,-6-row*(W.navHeight+W.navGap)) row=row+1 end
        elseif i==1 then tab:SetPoint("TOPLEFT",self.frame,"BOTTOMLEFT",12,2)
        else tab:SetPoint("LEFT",tabs[i-1],"RIGHT",(false) and 2 or -14,0) end
        tabs[i]=tab
        tab.__oneSelected=(id==self.activeTab)
    end
    self.frame.Tabs=tabs
    self.tabIds=keys
    self:SelectNativeTab()
end
function UI:SelectNativeTab()
    if not self.tabIds then return end
    if self.sidebar then
        local active=VIEW_PARENT[self.activeTab] or self.activeTab
        for _,id in ipairs(self.tabIds) do self:StyleSideButton(self.sidebarButtons[id],id==active) end
        return
    end
    local selected
    for i,id in ipairs(self.tabIds) do if id==self.activeTab then selected=i end end
    if type(PanelTemplates_SetNumTabs)=="function" then pcall(PanelTemplates_SetNumTabs,self.frame,#self.tabIds) end
    if selected and type(PanelTemplates_SetTab)=="function" then
        pcall(PanelTemplates_SetTab,self.frame,selected)
    elseif not selected and type(PanelTemplates_DeselectTab)=="function" then
        for _,tab in ipairs(self.frame.Tabs or {}) do pcall(PanelTemplates_DeselectTab,tab) end
    end
end
function UI:AddNavButton(id,title)
    if not NAV_ORDER[id] or self.sidebarButtons[id] then return end
    local ok,tab
    if self.sidebar then ok,tab=pcall(self.SideButton,self,id,title)
    else ok,tab=pcall(CreateFrame,"Button","ProjectONEMainWindowTab"..id,self.frame,"PanelTabButtonTemplate") end
    if not ok or not tab then
        tab=ONE.Widgets:Button(self.frame,NAV_LABEL[id] or title,96,26,"TOPLEFT",0,0)
    end
    tab:SetText(T(NAV_LABEL[id] or title))
    tab:SetScript("OnClick",function() self:Navigate(id) end)
    if not self.sidebar and type(PanelTemplates_TabResize)=="function" then pcall(PanelTemplates_TabResize,tab,0) end
    self.sidebarButtons[id]=tab
    self:RelayoutNavigation()
    return tab
end
function UI:AddTab(id,title,builder)
    if self.tabs[id] or #self.order>=9 then return false end
    local panel=CreateFrame("Frame",nil,self.frame)
    panel:SetPoint("TOPLEFT",WINDOW.contentX,-WINDOW.contentY)
    panel:SetSize(ONE.Geometry.tokens.contentWidth,ONE.Geometry.tokens.contentHeight)
    panel:Hide()
    panel.__oneTopPanel=true
    local button=self:AddNavButton(id,title)
    self.tabs[id]={button=button,panel=panel,refresh=builder(panel) or function() end}
    self.order[#self.order+1]=id
    return true
end
function UI:RegisterView(id,builder)
    if type(id)~="string" or type(builder)~="function" then return false end
    if self.tabs[id] or self.views[id] then return false end
    local panel=CreateFrame("Frame",nil,self.frame)
    panel:SetPoint("TOPLEFT",WINDOW.contentX,-WINDOW.contentY)
    panel:SetSize(ONE.Geometry.tokens.contentWidth,ONE.Geometry.tokens.contentHeight)
    panel:Hide()
    panel.__oneTopPanel=true
    self.views[id]={panel=panel,refresh=builder(panel) or function() end}
    self:AddNavButton(id,id)
    return true
end
-- Alles, was an die Gilde geteilt wird, als Haekchen gesammelt unter
-- Optionen -> "Teilen". Module melden ihre Schalter hier an:
-- {id, label, tooltip, get, set, order, visible}
function UI:AddShareOption(opts)
    if type(opts)~="table" or type(opts.id)~="string" or type(opts.get)~="function" or type(opts.set)~="function" then return false end
    for _,o in ipairs(self.shareOptions) do if o.id==opts.id then return false end end
    self.shareOptions[#self.shareOptions+1]=opts
    table.sort(self.shareOptions,function(a,b) return (a.order or 50)<(b.order or 50) end)
    return true
end
-- "Was steht an": Module liefern kurze Eintraege fuer die Gilde-Seite.
-- fn() -> {{icon=, text=, link=, sort=}, ...}; kleiner sort = weiter oben.
function UI:AddFeed(id,fn)
    if type(id)~="string" or type(fn)~="function" then return false end
    self.feeds[id]=fn
    return true
end
function UI:FeedItems()
    local out={}
    for _,fn in pairs(self.feeds) do
        local ok,items=pcall(fn)
        if ok and type(items)=="table" then for _,it in ipairs(items) do if type(it.text)=="string" then out[#out+1]=it end end end
    end
    table.sort(out,function(a,b) if (a.sort or 50)~=(b.sort or 50) then return (a.sort or 50)<(b.sort or 50) end return a.text<b.text end)
    return out
end
function UI:SelectTab(id) return self:Navigate(id) end
function UI:RegisterBackHandler(id,canBack,goBack)
    if type(id)~="string" or type(canBack)~="function" or type(goBack)~="function" then return false end
    self.backHandlers[id]={canBack=canBack,goBack=goBack}
    self:UpdateBackButton()
    return true
end
function UI:CanGoBack()
    local handler=self.backHandlers[self.activeTab]
    if handler and handler.canBack() then return true end
    for i=#self.history,1,-1 do
        local id=self.history[i]
        if id~=self.activeTab and (self.tabs[id] or self.views[id]) then return true end
    end
    return false
end
function UI:UpdateBackButton()
    if self.backButton then
        local can=self:CanGoBack()
        self.backButton:SetEnabled(can)
        if can then self.backButton:Show() else self.backButton:Hide() end
    end
    if self.forwardButton then self.forwardButton:SetEnabled(#self.forwardHistory>0) end
end
function UI:GoBack()
    local handler=self.backHandlers[self.activeTab]
    if handler and handler.canBack() then
        handler.goBack()
        self:UpdateBackButton()
        return true
    end
    while #self.history>0 do
        local previous=table.remove(self.history)
        if previous~=self.activeTab and (self.tabs[previous] or self.views[previous]) then
            table.insert(self.forwardHistory,self.activeTab)
            return self:Navigate(previous,"history")
        end
    end
    self:UpdateBackButton()
    return false
end
function UI:GoForward()
    while #self.forwardHistory>0 do
        local nextId=table.remove(self.forwardHistory)
        if nextId~=self.activeTab and (self.tabs[nextId] or self.views[nextId]) then
            table.insert(self.history,self.activeTab)
            return self:Navigate(nextId,"history")
        end
    end
    self:UpdateBackButton()
    return false
end
function UI:OpenLink(id) return self:Navigate(id) end
-- Weiterleitung: ein frueherer Reiter (z. B. "groups") oeffnet jetzt eine
-- Ansicht in einem anderen Reiter. onOpen stellt die Ansicht ein.
function UI:AddAlias(id,target,onOpen)
    self.aliases=self.aliases or {}
    self.aliases[id]={target=target,onOpen=onOpen}
    return true
end
function UI:Navigate(id,origin)
    local alias=self.aliases and self.aliases[id]
    if alias and not self.tabs[id] and not self.views[id] then
        if alias.onOpen then pcall(alias.onOpen) end
        if ONE.MinimapButton and ONE.MinimapButton.ClearAlert then ONE.MinimapButton:ClearAlert(id) end
        if self.activeTab==alias.target and self.tabs[alias.target] then
            self.tabs[alias.target].refresh()
            return true
        end
        return self:Navigate(alias.target,origin)
    end
    if not self.tabs[id] and not self.views[id] then return false end
    if self.activeTab and self.activeTab~=id and origin~="history" then
        table.insert(self.history,self.activeTab)
        if #self.history>40 then table.remove(self.history,1) end
        self.forwardHistory={}
    end
    self.activeTab=id
    -- Wer den Reiter oeffnet, hat die Neuigkeit gesehen: "!" an der Minimap weg.
    if ONE.MinimapButton and ONE.MinimapButton.ClearAlert then ONE.MinimapButton:ClearAlert(id) end
    for key,tab in pairs(self.tabs) do
        if key==id then tab.panel:Show() else tab.panel:Hide() end
    end
    for key,view in pairs(self.views) do
        if key==id then view.panel:Show() else view.panel:Hide() end
    end
    if self.pathLabel then self.pathLabel:SetText(T(NAV_LABEL[id] or (self.sidebar and NAV_LABEL[VIEW_PARENT[id] or ""]) or "")) end
    self:UpdateContext()
    self:UpdateViews()
    for key,btn in pairs(self.sidebarButtons) do btn.__oneSelected=(key==id) end
    self:SelectNativeTab()
    self:Show()
    if ONE.Themes then
        ONE.Themes:StyleTree(self.frame)
        if self.frame:IsShown() and self.__hasNavigated then ONE.Themes:PlaySound("open") end
    end
    self.__hasNavigated=true
    self:UpdateBackButton()
    return true
end
-- Seiten mit eigenem Titel (PageHeader): mit Symbolleiste steht der Seitenname schon
-- gross in der Kopfzeile. Der eigene Titel entfaellt, die Seite rueckt um dy nach oben
-- (der freie Titelbereich liegt dann unter der Kopfzeile). Unten wird es entsprechend frei.
UI.LIFT=54
function UI:LiftPage(panel,dy)
    if not (self.sidebar and panel and panel.__oneTopPanel) or panel.__oneLifted then return false end
    panel.__oneLifted=dy or self.LIFT
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT",self.frame,"TOPLEFT",WINDOW.contentX,-(WINDOW.contentY-panel.__oneLifted))
    -- die Seite reicht weiter nach unten bis zur alten Unterkante
    panel:SetSize(ONE.Geometry.tokens.contentWidth,ONE.Geometry.tokens.contentHeight+panel.__oneLifted)
    return true
end
-- Ansichten-Umschalter oben rechts in der Kopfzeile (gleiche Stelle auf jeder Seite).
-- items = {{key=, label=, onClick=function(key) end}, ...}; active = key der aktiven Ansicht.
-- Liefert false ohne Symbolleiste (Buch): dann behaelt die Seite ihre eigenen Knoepfe.
function UI:SetViews(id,items,active)
    if not self.sidebar then return false end
    self.viewSets=self.viewSets or {}
    self.viewSets[id]=items and {items=items,active=active} or nil
    if id==self.activeTab or (VIEW_PARENT[self.activeTab]==id) then self:UpdateViews() end
    return true
end
-- Alte Seitenknoepfe, die durch die Kopfzeile ersetzt sind: ausblenden (bleiben als
-- Objekte erhalten, damit Seiten sie weiter beschriften/markieren duerfen)
function UI:RetireButtons(...)
    for i=1,select("#",...) do
        local b=select(i,...)
        if b then b:Hide() b.Show=function() end end
    end
end
function UI:SetActiveView(id,active)
    local set=self.viewSets and self.viewSets[id]
    if not set then return end
    set.active=active
    self:UpdateViews()
end
function UI:UpdateViews()
    if not self.sidebar then return end
    self.viewButtons=self.viewButtons or {}
    local set=self.viewSets and (self.viewSets[self.activeTab] or self.viewSets[VIEW_PARENT[self.activeTab] or ""])
    local items=set and set.items or {}
    -- Ansichten, die eigene Seiten sind, folgen der offenen Seite
    if set then for _,it in ipairs(items) do if it.key==self.activeTab then set.active=it.key end end end
    local right=-118
    for i=#items,1,-1 do
        local it=items[i]
        local b=self.viewButtons[i]
        if not b then
            b=ONE.Widgets:Button(self.frame,"",90,22,"TOPRIGHT",0,0)
            self.viewButtons[i]=b
        end
        local label=T(it.label)
        b:SetText(label)
        local w=math.max(64,math.floor(#label*6.2+26))
        b:SetSize(w,22)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT",self.frame,"TOPRIGHT",right,-(WINDOW.insetTop-27))
        right=right-w-2
        local on=(it.key==set.active)
        if on then
            if b.LockHighlight then b:LockHighlight() end
            local fs=b.GetFontString and b:GetFontString()
            if fs and fs.SetTextColor then fs:SetTextColor(1,1,1) end
        else
            if b.UnlockHighlight then b:UnlockHighlight() end
            local fs=b.GetFontString and b:GetFontString()
            if fs and fs.SetTextColor then fs:SetTextColor(1,.82,0) end
        end
        b.__oneViewOn=on
        b:SetScript("OnClick",function()
            set.active=it.key
            if it.onClick then it.onClick(it.key) end
            self:UpdateViews()
        end)
        b:Show()
    end
    for i=#items+1,#self.viewButtons do self.viewButtons[i]:Hide() end
end
-- Kurze Zusatzangabe in der Kopfzeile neben dem Seitennamen (z. B. "5 von 23 online").
-- Module rufen UI:SetContext(id, text) in ihrer Aktualisierung auf; nil loescht.
function UI:SetContext(id,text)
    self.contexts=self.contexts or {}
    self.contexts[id]=text
    if id==self.activeTab then self:UpdateContext() end
end
function UI:UpdateContext()
    if not self.contextLabel then return end
    local text=self.contexts and self.contexts[self.activeTab]
    self.contextLabel:SetText(text or "")
end
function UI:Refresh()
    local active=self.tabs[self.activeTab] or self.views[self.activeTab]
    if active and active.refresh then active.refresh() end
    -- Angabe der tatsaechlich aktiven gespeicherten Farbpalette.
    if self.themeStatus then self.themeStatus:SetText("v" .. ONE.version) end
    if ONE.Themes and self.frame then ONE.Themes:StyleTree(self.frame) end
end
function UI:Show()
    if not self.frame then return end
    self.frame:Show()
    self:Refresh()
end
function UI:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

-- Freche Sprueche (Quips.lua): jeden Tag ein neuer; jeder Charakter hat einen eigenen
-- Startpunkt in der Liste, so sieht jeder einen anderen und 100 Tage wiederholt sich nichts.
-- Als Geist gibt es immer den Geist-Spruch.
function UI:Quip()
    if type(UnitIsDeadOrGhost)=="function" and UnitIsDeadOrGhost("player") and ONE.QUIP_GHOST then return ONE.QUIP_GHOST end
    local list=ONE.QUIPS
    if type(list)~="table" or #list==0 then return "" end
    local now=(type(time)=="function" and time()) or 0
    -- Tag nach Ortszeit (Wechsel um Mitternacht)
    local offset=0
    if type(date)=="function" then
        local u, l = date("!*t", now), date("*t", now)
        if type(u)=="table" and type(l)=="table" and type(time)=="function" then
            l.isdst=false offset=time(l)-time(u)
        end
    end
    local day=math.floor((now+offset)/86400)
    local name=UnitName and UnitName("player") or ""
    local realm=type(GetRealmName)=="function" and GetRealmName() or ""
    return list[ONE.QuipIndex(day, (name or "").."-"..(realm or ""), #list)]
end

local function BuildHome(panel)
    -- Buch-Aussehen: eigene Doppelseite (Initiale, Siegel, Inhaltsverzeichnis)
    local W=UI.Layout.width
    local cols=UI.Layout:Columns({5,4})
    -- Einheitliche Seiteneinfuehrung; alle Karten liegen innerhalb der 726er Spur.
    -- Buch-Aussehen: Doppelseite – links Begruessung, rechts die Kacheln
    local L,R=nil,nil
    local LW=L and L.width or W
    if not UI:LiftPage(panel) then
        Label(panel,T("Deine Zentrale"),"GameFontNormalLarge",0,-4,LW)
        Label(panel,T("Dein Gildenalltag. Ein klarer Überblick."),"GameFontHighlight",0,-34,LW,"soft")
    end

    -- mit Symbolleiste ohne eigenen Titel: das Bild bekommt den frei gewordenen Platz
    local lift=panel.__oneLifted or 0
    local heroH=190+lift
    local hero
    if L then
        hero=CreateFrame("Frame",nil,panel)
        hero:SetPoint("TOPLEFT",panel,"TOPLEFT",L.x,-62)
        hero:SetSize(L.width,190)
    else
        hero=Panel(panel,0,-62,W,heroH)
    end
    local heroHeader=ONE.Geometry:CardHeader(LW)
    if L then heroHeader.x=0 heroHeader.width=L.width end
    local textW=L and L.width or 415
    -- Reiseroute (eigene Zeichnung, scripts/build_textures.py) ist eine reine dekorative TEXTUR. Darueber liegen echte,
    -- frei aktualisierbare WoW-Labels und -Schaltflaechen. Gleiche Layoutmaße.
    -- Ein anderes TGA je Farbpalette verhindert Farbkonflikte auf allen Skins.
    local art=hero:CreateTexture(nil,"ARTWORK",nil,-7)
    -- Die Festung liegt hinter der gemeinsamen Lichtreflexion (-6),
    -- aber vor dem einfachen Kartenhintergrund (BACKGROUND).
    art:SetPoint("TOPLEFT",hero,"TOPLEFT",2,-2)
    art:SetPoint("BOTTOMRIGHT",hero,"BOTTOMRIGHT",-2,2)
    -- Ein Bild fuer den nativen Look; der Inset-Rahmen bleibt sichtbar.
    local heroTexture="Interface\\AddOns\\ONE_Core\\Textures\\Hero\\TripHero.tga"
    local artReady=false
    local function RefreshArt()
        if artReady then return end
        art:SetTexture(heroTexture)
        -- im Buch-Aussehen kein dunkles Bild hinter der Tinte
        art:ClearAllPoints()
        art:SetPoint("TOPLEFT",hero,"TOPLEFT",4,-4)
        art:SetPoint("BOTTOMRIGHT",hero,"BOTTOMRIGHT",-4,4)
        artReady=true
    end
    RefreshArt()
    Label(hero,"DEIN TAG IN AZEROTH","GameFontNormalSmall",heroHeader.x,heroHeader.y,textW)
    -- Begruessung mit Namen und einem frechen Spruch (wechselt je Sitzung, manche passen zur Lage)
    local heading=Label(hero,T("Willkommen zurück!"),"GameFontNormalHuge",heroHeader.x,-54,textW)
    local quip=Label(hero,"","GameFontHighlight",heroHeader.x,-90,L and textW or 430,"soft")
    if quip.SetWordWrap then quip:SetWordWrap(true) end
    Action(hero,T("Heutige Termine ansehen"),{
        x=heroHeader.x,y=ONE.Geometry:BottomActionY(heroH),width=heroHeader.width,
    },function() ONE.UI:OpenLink("today") end,"primary","primary","left")

    -- Kachelreihe: jedes installierte Modul steuert eine Kachel bei
    -- (Kit:RegisterTile). Bis zu drei Kacheln teilen sich die Breite.
    local tileCards,builtVersion={},nil
    local function BuildTiles()
        if ONE.Kit==nil or builtVersion==ONE.Kit.tilesVersion then return end
        for _,card in ipairs(tileCards) do card.frame:Hide() end
        tileCards={}
        local defs={}
        for i,def in ipairs(ONE.Kit:Tiles()) do if i<=4 then defs[i]=def end end
        if #defs==0 then builtVersion=ONE.Kit.tilesVersion return end
        local weights={}
        for i=1,#defs do weights[i]=1 end
        local tileCols=UI.Layout:Columns(weights)
        if R then
            -- rechte Buchseite: Kacheln zu zweit nebeneinander
            local cw=math.floor((R.width-12)/2)
            for i=1,#defs do
                tileCols[i]={x=R.x+((i-1)%2)*(cw+12),y=-4-math.floor((i-1)/2)*178,width=cw}
            end
        end
        for i,def in ipairs(defs) do
            local col=tileCols[i]
            local frame=Panel(panel,col.x,col.y or (-267-lift),col.width,166)
            local header=ONE.Geometry:CardHeader(col.width)
            Label(frame,def.title or def.id,"GameFontNormal",header.x,header.y,header.width)
            local rule=frame:CreateTexture(nil,"ARTWORK")
            if ONE.Themes.RegisterRule then ONE.Themes:RegisterRule(rule,"border") end
            rule:SetPoint("TOPLEFT",header.ruleX,header.ruleY)
            rule:SetSize(header.ruleWidth,header.ruleHeight)
            local body=ONE.Kit:Stack(frame,header.x,-66,header.width,4)
            -- Gemeinsamer Aktionsplatz unten in jeder Kachel
            body.Action=function(_,label,handler,variant)
                return Action(frame,label,{x=header.x,y=ONE.Geometry:BottomActionY(166),width=header.width},
                    handler,variant or "secondary","card","left")
            end
            local ok,refresh=pcall(def.build,frame,body,col.width)
            tileCards[#tileCards+1]={frame=frame,refresh=ok and refresh or nil}
            if not ok then ONE:Print(T("Kachel '%s' fehlerhaft: %s", def.id, tostring(refresh))) end
        end
        builtVersion=ONE.Kit.tilesVersion
    end

    return function()
        local name=UnitName and UnitName("player") or nil
        heading:SetText(name and T("Na %s!",name) or T("Willkommen zurück!"))
        quip:SetText(UI:Quip())
        RefreshArt()
        BuildTiles()
        for _,card in ipairs(tileCards) do
            if card.refresh then
                local ok,err=pcall(card.refresh)
                if not ok then ONE:Print(T("Kachel-Aktualisierung fehlgeschlagen: %s", tostring(err))) end
            end
        end
    end
end

-- Kachel "Termine" (Core): naechste Termine aus allen Kalender-Anbietern.
local function TermineTile(card,body)
    local first=body:Text("","body","text")
    local second=body:Text("","small","soft")
    body:Action(T("Kalender öffnen"),function()
        if not ONE.UI:OpenLink("calendar") then ONE:Print(T("Das Gildenmodul ist nicht installiert.")) end
    end)
    return function()
        local events,loading={},false
        if ONE.Welcome and ONE.Welcome.GetEvents then
            events,loading=ONE.Welcome:GetEvents()
        end
        local function Line(ev) return string.format("|cffffd100%02d:%02d|r  %s",ev.hour,ev.minute,ev.title) end
        first:SetText(events[1] and Line(events[1]) or (loading and T("Kalender wird geladen ...") or T("Heute keine weiteren Termine")))
        if events[2] then second:SetText(Line(events[2]))
        else second:SetText(#events==0 and (loading and T("Termine werden eingelesen.") or T("Dein Kalender ist für heute frei."))
            or T("Weitere Informationen im Kalender.")) end
    end
end

local function OptionSlider(parent,x,y,width)
    local ok,slider=pcall(CreateFrame,"Slider",nil,parent,"OptionsSliderTemplate")
    if not ok or not slider then
        slider=CreateFrame("Slider",nil,parent)
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local rail=slider:CreateTexture(nil,"BACKGROUND")
        rail:SetPoint("LEFT",slider,"LEFT",0,0)
        rail:SetPoint("RIGHT",slider,"RIGHT",0,0)
        rail:SetHeight(4)
        if ONE.Themes and ONE.Themes.RegisterRule then ONE.Themes:RegisterRule(rail,"border") end
    end
    slider:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    slider:SetSize(width,17)
    slider:SetOrientation("HORIZONTAL")
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    -- Beschriftungen der Vorlage (Low/High/Text) leeren; ONE setzt eigene.
    for _,key in ipairs({"Low","High","Text"}) do
        local fs=slider[key]
        if type(fs)=="table" and fs.SetText then fs:SetText("") end
    end
    return slider
end

-- Sprachwechsel greift erst nach dem Neuladen der Oberflaeche (alle Texte
-- werden beim Aufbau gesetzt). Blizzard-Dialog mit Rueckfrage.
function UI:AskReload(look)
    local text=look=="modules" and T("Guild Trip: Module geändert. Oberfläche jetzt neu laden?")
        or look and T("Guild Trip: Aussehen geändert. Oberfläche jetzt neu laden?")
        or T("Guild Trip: Sprache geändert. Oberfläche jetzt neu laden?")
    if type(StaticPopupDialogs)~="table" or type(StaticPopup_Show)~="function" then
        ONE:Print(look and T("Aussehen geändert – bitte /reload eingeben.") or T("Sprache geändert – bitte /reload eingeben."))
        return
    end
    StaticPopupDialogs.GUILDTRIP_RELOAD={text=text,button1=T("Neu laden"),button2=T("Später"),
        OnAccept=function() if type(ReloadUI)=="function" then ReloadUI() end end,
        timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3}
    StaticPopup_Show("GUILDTRIP_RELOAD")
end

-- ===== Optionen: ALLE Einstellungen an einem Ort (0.6.9, Nutzer-OK 17.11.2026) =====
-- Links die Bereiche (wie Blizzards Einstellungen), rechts die Einstellungen des Bereichs
-- mit Zwischenueberschriften (scrollbar). Module melden ihre Bedienelemente hier an und
-- haben selbst keine Einstellungsfenster mehr; jeden Schalter gibt es genau einmal.
--   UI:AddCategory(id, {title=, order=})
--   UI:AddSetting{id=, category=, section=, kind="check"|"dropdown"|"button"|"radio"|"text"|"custom",
--       label=, tooltip=, note=, get=, set=, options=, onClick=, width=, indent=, order=,
--       module=, visible=function, enabled=function, onChange=, build=function(row, width) -> refresh, height}
--   UI:OpenOptions(categoryId)   -- Zahnraeder der Module springen direkt in ihren Bereich
-- Einzelfunktionen (ONE:RegisterFeature) erscheinen als Haken im Bereich ihres Moduls
-- (Kern-Funktionen unter "Allgemein"; def.category/def.section/def.indent/def.order lenken um).
-- Teilen-Schalter (UI:AddShareOption) stehen gesammelt unter "Teilen".
UI.categories={}
UI.settingList={}
local CORE_CATEGORIES={
    {id="general",title="Allgemein",order=1},
    {id="look",title="Darstellung",order=2},
    {id="reminders",title="Erinnerungen",order=3},
    {id="sharing",title="Teilen",order=4},
}
-- Module: Name im Bereich (kurz, wie die Leiste) und Reihenfolge
local MODULE_CATEGORY={guild={"Gilde",10},dungeons={"Dungeons",20},crafting={"Berufe",30},
    classes={"Klasse",40},leveling={"Leveln",50},nav={"Navi",60},chat={"Chat",70}}
UI.MODULE_CATEGORY=MODULE_CATEGORY
for _,c in ipairs(CORE_CATEGORIES) do UI.categories[c.id]={id=c.id,title=c.title,order=c.order,core=true} end

function UI:AddCategory(id,def)
    if type(id)~="string" or type(def)~="table" then return false end
    local c=self.categories[id] or {id=id}
    c.title=def.title or c.title or id
    c.order=def.order or c.order or 80
    c.module=def.module or c.module
    self.categories[id]=c
    return true
end
function UI:AddSetting(opts)
    if type(opts)~="table" or type(opts.id)~="string" or type(opts.category)~="string" then return false end
    local kind=opts.kind or "check"
    if (kind=="check" or kind=="dropdown" or kind=="radio") and (type(opts.get)~="function" or type(opts.set)~="function") then return false end
    if kind=="custom" and type(opts.build)~="function" then return false end
    for _,o in ipairs(self.settingList) do if o.id==opts.id then return false end end
    opts.kind=kind
    opts.seq=#self.settingList+1
    self.settingList[#self.settingList+1]=opts
    return true
end
-- Frueher Optionen › Spielhilfen; bleibt als Weiterleitung fuer aeltere Aufrufe
local LEGACY_SECTION={Navi="nav",Klasse="classes",Gruppen="dungeons"}
function UI:AddOption(opts)
    if type(opts)~="table" or type(opts.id)~="string" then return false end
    opts.category=opts.category or LEGACY_SECTION[opts.section or ""] or "general"
    if LEGACY_SECTION[opts.section or ""] then opts.section=nil end
    return self:AddSetting(opts)
end

-- Bereiche in Reihenfolge: Kern-Bereiche, dann je geladenem Modul einer
function UI:CategoryList()
    local list,seen={},{}
    for id,c in pairs(self.categories) do list[#list+1]=c seen[id]=true end
    for _,mid in ipairs(ONE.moduleOrder or {}) do
        if not seen[mid] then
            local def=ONE.modules[mid] or {}
            local m=MODULE_CATEGORY[mid]
            local c={id=mid,title=m and m[1] or def.title or mid,order=m and m[2] or 80,module=mid}
            self.categories[mid]=c
            list[#list+1]=c
        else
            self.categories[mid].module=mid
        end
    end
    table.sort(list,function(a,b) if a.order~=b.order then return a.order<b.order end return a.id<b.id end)
    return list
end

local function ModuleOn(mid) return not mid or not ONE.IsEnabled or ONE:IsEnabled(mid) end
-- Alles, was im Bereich steht: Modul-Hauptschalter, Einstellungen, Funktionen, Teilen
function UI:CategoryEntries(cat)
    local out={}
    self:PlaceFeatures()
    local c=self.categories[cat]
    if c and c.module and ONE.modules then
        local title=c.title
        out[#out+1]={id="m:"..c.module,kind="check",order=-100,seq=0,master=true,
            label=T("Modul „%s“ eingeschaltet",T((ONE.modules[c.module] or {}).title or title)),
            tooltip=T("Ganzes Modul an oder aus. Wirkt nach dem Neuladen."),
            get=function() return ONE:IsEnabled(c.module) end,
            set=function(on) ONE.db.modules[c.module]=on and true or false UI.moduleReload=true UI:AskReload("modules") end}
        if not ONE:IsEnabled(c.module) then
            out[#out+1]={id="m:"..c.module..":off",kind="text",order=-99,seq=0,
                label=T("Das Modul ist aus. Nach dem Einschalten und Neuladen stehen hier seine Einstellungen.")}
            return out
        end
    end
    for _,o in ipairs(self.settingList) do
        if o.category==cat and ModuleOn(o.module) then out[#out+1]=o end
    end
    for i,fid in ipairs(ONE.featureOrder or {}) do
        local f=ONE.features and ONE.features[fid]
        if not f then break end
        local fcat=f.category or f.module or "general"
        if fcat==cat and ModuleOn(f.module) then
            f.__entry=f.__entry or {id="f:"..fid,kind="check",label=f.label,tooltip=f.tooltip,
                section=f.section or (f.module and "Funktionen" or "Weiteres"),indent=f.indent,order=f.order or 60,seq=1000+i,
                get=function() return ONE:FeatureOn(fid) end,
                set=function(on) ONE:SetFeature(fid,on) if f.reload then UI.moduleReload=true UI:AskReload("modules") end end}
            out[#out+1]=f.__entry
        end
    end
    if cat=="sharing" then
        for i,s in ipairs(self.shareOptions) do
            if ModuleOn(s.module) then
                s.__entry=s.__entry or {id="s:"..s.id,kind="check",label=s.label,note=s.tooltip,
                    order=s.order or 50,seq=2000+i,get=s.get,set=s.set,visible=s.visible}
                out[#out+1]=s.__entry
            end
        end
    end
    -- Abschnitte in der Reihenfolge ihres ersten Eintrags, darin nach order
    local first={}
    for _,o in ipairs(out) do
        local key=o.section or ""
        local rank=(o.order or 50)*10000+(o.seq or 0)
        if not first[key] or rank<first[key] then first[key]=rank end
    end
    table.sort(out,function(a,b)
        local sa,sb=first[a.section or ""],first[b.section or ""]
        if sa~=sb then return sa<sb end
        local oa,ob=a.order or 50,b.order or 50
        if oa~=ob then return oa<ob end
        return (a.seq or 0)<(b.seq or 0)
    end)
    return out
end

function UI:OpenOptions(cat)
    if type(cat)=="string" then
        self:CategoryList()
        if self.categories[cat] then self.optionsCategory=cat end
    end
    if self.frame and self.frame.Show and not self.frame:IsShown() then self.frame:Show() end
    self:Navigate("options")
    self:Refresh()
    return true
end

-- Ein Bedienelement in eigener Zeile (Frame), damit Ein-/Ausblenden und Verschieben einfach bleiben
local ROW_H={check=26,dropdown=34,button=32,text=20}
local function BuildRow(child,o,W)
    local row=CreateFrame("Frame",nil,child)
    row:SetSize(W,ROW_H[o.kind] or 26)
    local x=(o.indent or 0)*22
    local function Changed() if o.onChange then o.onChange() end UI:Refresh() end
    if o.kind=="check" then
        row.box=ONE.Kit:Check(row,{point="TOPLEFT",x=x,y=0,label=o.label,tooltip=o.tooltip,get=o.get,set=o.set,onChange=Changed})
        -- lange Beschriftungen umbrechen (Buch: nur 286 breit)
        if row.box.label and row.box.label.SetWidth then
            row.box.label:SetWidth(W-x-34)
            if row.box.label.SetJustifyH then row.box.label:SetJustifyH("LEFT") end
            if row.box.label.SetWordWrap then row.box.label:SetWordWrap(true) end
        end
        if o.master and row.box.label and row.box.label.SetFontObject then
            pcall(row.box.label.SetFontObject,row.box.label,"GameFontNormal")
            if row.box.label.SetTextColor then row.box.label:SetTextColor(1,.82,0) end
        end
        if o.note then
            row.note=Label(row,o.note,"GameFontHighlightSmall",x+30,-24,W-x-40,"soft")
            if row.note.SetWordWrap then row.note:SetWordWrap(true) end
        end
        row.refresh=function()
            row.box:Refresh()
            if row.box.SetEnabled then row.box:SetEnabled(not o.enabled or o.enabled() and true or false) end
        end
    elseif o.kind=="dropdown" then
        local dx,dy=x,-2
        if o.label then
            -- schmal (Buch): Auswahl unter die Beschriftung
            local narrow=W-x<460
            row.label=Label(row,o.label,"GameFontHighlight",x+4,-7,narrow and W-x-8 or 200,"text")
            if narrow then dx,dy,row.height=x+4,-26,60 else dx=x+210 end
        end
        row.dd=ONE.Kit:Dropdown(row,{point="TOPLEFT",x=dx,y=dy,width=math.min(o.width or 240,W-dx),tooltip=o.tooltip and T(o.tooltip),
            options=o.options,get=o.get,set=o.set,onChange=Changed})
        row.refresh=function() if row.dd.Refresh then row.dd:Refresh() end end
    elseif o.kind=="button" then
        row.button=ONE.Widgets:Button(row,T(o.label),o.width or 220,24,"TOPLEFT",x+2,-2,function() if o.onClick then o.onClick() end UI:Refresh() end)
        if o.tooltip and row.button.HookScript then
            row.button:HookScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:AddLine(T(o.tooltip),1,1,1,true)
                GameTooltip:Show()
            end)
            row.button:HookScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        end
    elseif o.kind=="radio" then
        row.checks={}
        local list=o.options()
        for i,opt in ipairs(list) do
            row.checks[i]=ONE.Kit:Check(row,{point="TOPLEFT",x=x,y=-(i-1)*26,label=opt.text,tooltip=opt.tooltip,
                get=function() return o.get()==opt.value end,
                set=function() o.set(opt.value) end,onChange=Changed})
        end
        row.height=#list*26
        row.refresh=function() for _,b in ipairs(row.checks) do b:Refresh() end end
    elseif o.kind=="text" then
        row.text=Label(row,"","GameFontHighlightSmall",x+4,-2,W-x-12,"soft")
        if row.text.SetWordWrap then row.text:SetWordWrap(true) end
        row.refresh=function()
            local t=type(o.label)=="function" and o.label() or o.label or ""
            row.text:SetText(T(t))
        end
    elseif o.kind=="custom" then
        local refresh,height=o.build(row,W-x)
        row.refresh=refresh
        row.height=height or o.height
    end
    return row
end
local function StringHeight(fs,fallback)
    local sh=fs and fs.GetStringHeight and fs:GetStringHeight()
    if type(sh)~="number" or sh<=0 then sh=fallback end
    return sh
end
local function RowHeight(row,o)
    if row.height then return row.height end
    local h=ROW_H[o.kind] or 26
    if o.kind=="text" then return StringHeight(row.text,14)+8 end
    if o.kind=="check" then
        -- umgebrochene Beschriftung: Zeile waechst mit
        local lh=StringHeight(row.box.label,12)
        if lh>16 then h=lh+12 end
        if row.note then
            row.note:ClearAllPoints()
            row.note:SetPoint("TOPLEFT",row,"TOPLEFT",(o.indent or 0)*22+30,-h+2)
            h=h+StringHeight(row.note,14)+8
        end
    end
    return h
end

local function BuildOptions(panel)
    local W=UI.Layout.width
    local H=ONE.Geometry.tokens.contentHeight or 437
    local L,R
    -- Buch: links die Bereiche, rechts die Einstellungen; sonst Liste 150 breit links
    local listX,listW=L and L.x or 0,L and math.min(L.width,220) or 150
    local paneX=R and R.x or listW+10
    local paneW=R and R.width or W-listW-10
    local top=0
    if L then
        Label(panel,T("Optionen"),"GameFontNormalLarge",listX,-4,L.width,"accent")
        top=-34
    end
    local list=L and CreateFrame("Frame",nil,panel) or Panel(panel,listX,top,listW,H+top)
    if L then list:SetPoint("TOPLEFT",panel,"TOPLEFT",listX,top) list:SetSize(listW,H+top) end
    local pane=R and CreateFrame("Frame",nil,panel) or Panel(panel,paneX,0,paneW,H)
    if R then pane:SetPoint("TOPLEFT",panel,"TOPLEFT",paneX,0) pane:SetSize(paneW,H) end
    -- rechts scrollbar (Mausrad); die Leiste der Vorlage sitzt rechts innen
    local innerW=paneW-44
    local ok,scroll=pcall(CreateFrame,"ScrollFrame",nil,pane,"UIPanelScrollFrameTemplate")
    if not ok or not scroll then scroll=CreateFrame("ScrollFrame",nil,pane) end
    scroll:SetPoint("TOPLEFT",pane,"TOPLEFT",12,-10)
    scroll:SetSize(innerW,H-20)
    if scroll.EnableMouseWheel and not scroll.ScrollBar then
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel",function(self,delta)
            local cur=self.GetVerticalScroll and self:GetVerticalScroll() or 0
            local max=self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0,math.min(max,cur-delta*40)))
        end)
    end
    local child=CreateFrame("Frame",nil,scroll)
    child:SetSize(innerW,10)
    scroll:SetScrollChild(child)
    UI.optionsScroll,UI.optionsChild=scroll,child
    local catButtons,rows,heads={},{},{}
    local shownCat
    local function CatButton(i)
        local b=catButtons[i]
        if b then return b end
        b=CreateFrame("Button",nil,list)
        b:SetSize(listW-8,22)
        local sel=b:CreateTexture(nil,"BACKGROUND")
        sel:SetAllPoints(b)
        sel:SetColorTexture(1,.82,0,.15)
        local hover=b:CreateTexture(nil,"HIGHLIGHT")
        hover:SetAllPoints(b)
        hover:SetColorTexture(1,1,1,.07)
        local text=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        text:SetPoint("LEFT",b,"LEFT",10,0)
        text:SetJustifyH("LEFT")
        if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(text,"accent") end
        b.caption,b.sel=text,sel
        b.SetText=function(_,t) text:SetText(t) end
        b.GetText=function() return text:GetText() end
        catButtons[i]=b
        return b
    end
    local function Head(key,title)
        local h=heads[key]
        if not h then
            h=Label(child,title,"GameFontNormal",2,0,innerW-4,"accent")
            heads[key]=h
        end
        return h
    end
    local function Layout(cat)
        local y=0
        local used={}
        local lastSection
        for _,o in ipairs(UI:CategoryEntries(cat)) do
            if not o.visible or o.visible() then
                local sec=o.section or ""
                if sec~=lastSection then
                    lastSection=sec
                    if sec~="" then
                        if y<0 then y=y-10 end
                        local h=Head(cat.."|"..sec,T(sec))
                        h:ClearAllPoints() h:SetPoint("TOPLEFT",child,"TOPLEFT",2,y) h:Show()
                        used[h]=true
                        y=y-22
                    end
                end
                local row=rows[o.id]
                if not row then row=BuildRow(child,o,innerW) rows[o.id]=row end
                if row.refresh then row.refresh() end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",child,"TOPLEFT",0,y)
                row:Show()
                used[row]=true
                y=y-RowHeight(row,o)
                if o.master then y=y-6 end
            end
        end
        for _,row in pairs(rows) do if not used[row] then row:Hide() end end
        for _,h in pairs(heads) do if not used[h] then h:Hide() end end
        child:SetHeight(math.max(10,-y+10))
        if shownCat~=cat then
            shownCat=cat
            if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
    end
    return function()
        local cats=UI:CategoryList()
        local cat=UI.optionsCategory
        if not (cat and UI.categories[cat]) then cat="general" UI.optionsCategory=cat end
        local y,title=-6,""
        for i,c in ipairs(cats) do
            local b=CatButton(i)
            if i>1 and c.core~=cats[i-1].core then y=y-10 end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",list,"TOPLEFT",4,y)
            b:SetText(T(c.title))
            b.categoryId=c.id
            b:SetScript("OnClick",function()
                UI.optionsCategory=c.id
                UI:Refresh()
            end)
            if c.id==cat then b.sel:Show() if b.caption.SetTextColor then b.caption:SetTextColor(1,1,1) end
            else b.sel:Hide() if b.caption.SetTextColor then b.caption:SetTextColor(1,.82,0) end end
            b:Show()
            y=y-24
            if c.id==cat then title=c.title end
        end
        for i=#cats+1,#catButtons do catButtons[i]:Hide() end
        UI:SetContext("options",T(title))
        Layout(cat)
    end
end

-- Kern-Einstellungen (Allgemein, Darstellung)
local function RegisterCoreSettings()
    local function Set(cat,section,o) o.category,o.section=cat,section UI:AddSetting(o) end
    -- Allgemein › Hinweise
    Set("general","Hinweise",{id="toast",label="Hinweisfenster anzeigen",order=10,
        tooltip="Ein kleines Fenster zusätzlich zur Chatzeile.",
        get=function() return ONE.db.toastEnabled end,
        set=function(v) ONE.db.toastEnabled=v ONE.Notifications:SettingsChanged() end})
    Set("general","Hinweise",{id="noticeSound",label="Ton bei Benachrichtigungen",order=11,
        get=function() return ONE.db.soundEnabled end,set=function(v) ONE.db.soundEnabled=v end})
    Set("general","Hinweise",{id="noticeTest",kind="button",label="Benachrichtigung testen",order=19,
        onClick=function() ONE:Notify(T("Guild Trip: Dies ist eine Testbenachrichtigung."),{source=T("Guild Trip Test")}) end})
    Set("general",nil,{id="noticeHint",kind="text",order=1,
        label="Benachrichtigungen funktionieren nur, während WoW läuft."})
    -- Darstellung
    Set("look","Fenster",{id="windowScale",kind="custom",order=10,build=function(row,w)
        local sw=math.min(w-80,300)
        Label(row,T("Fenstergröße"),"GameFontHighlight",4,-2,sw-60,"text")
        local value=Label(row,"","GameFontHighlight",sw-56,-2,60,"text")
        if value.SetJustifyH then value:SetJustifyH("RIGHT") end
        local slider=OptionSlider(row,4,-22,sw)
        slider:SetValueStep(.05)
        ONE.WindowScale:AttachControls(slider,value)
        return nil,48
    end})
    Set("look","Fenster",{id="windowReset",kind="button",label="Fenstergröße zurücksetzen",order=11,
        onClick=function() ONE.WindowScale:Reset() end})
    local scales=ONE.Kit and ONE.Kit.scales or {1}
    Set("look","Schrift",{id="fontScale",kind="custom",order=20,build=function(row,w)
        local sw=math.min(w-80,300)
        Label(row,T("Schriftgröße"),"GameFontHighlight",4,-2,sw-60,"text")
        local value=Label(row,"","GameFontHighlight",sw-56,-2,60,"text")
        if value.SetJustifyH then value:SetJustifyH("RIGHT") end
        local slider=OptionSlider(row,4,-22,sw)
        slider:SetMinMaxValues(1,#scales)
        slider:SetValueStep(1)
        slider:SetScript("OnValueChanged",function(_,v)
            local scale=scales[math.floor((v or 1)+.5)]
            if ONE.Kit and scale and math.abs(ONE.Kit.Settings().fontScale-scale)>.001 then ONE.Kit:SetFontScale(scale) end
        end)
        return function()
            if not ONE.Kit then return end
            local kit=ONE.Kit.Settings()
            value:SetText(math.floor(kit.fontScale*100+.5).." %")
            for i,s in ipairs(scales) do if math.abs(s-kit.fontScale)<.001 and slider.SetValue then slider:SetValue(i) end end
        end,48
    end})
    Set("look","Schrift",{id="contrast",label="Hoher Kontrast",order=21,
        tooltip="Nebentexte werden so hell wie normaler Text.",
        get=function() return ONE.Kit and ONE.Kit.Settings().contrast=="high" end,
        set=function() if ONE.Kit then ONE.Kit:ToggleContrast() end end})
    Set("look","Sprache und Aussehen",{id="language",kind="dropdown",label="Sprache / Language",order=30,width=220,
        options=function() return {{value=nil,text="Automatisch (Spielsprache)"},{value="de",text="Deutsch"},{value="en",text="English"}} end,
        get=function() return ONE.db.language end,set=function(v) ONE.db.language=v end,
        onChange=function() UI:AskReload() end})
end
-- Kern-Funktionen in ihre Bereiche lenken (stehen in Core.lua/Vendor.lua/Book.lua)
local CORE_FEATURE_PLACE={
    ["core.loginSummary"]={"general","Hinweise",12},
    ["core.sounds"]={"look","Klänge",40},
    ["core.autoRepair"]={"general","Händler",30},
    ["core.autoRepairGuild"]={"general","Händler",31,1},
    ["core.sellJunk"]={"general","Händler",32},
}
UI.CORE_FEATURE_PLACE=CORE_FEATURE_PLACE
function UI:PlaceFeatures()
    for fid,p in pairs(CORE_FEATURE_PLACE) do
        local f=ONE.features and ONE.features[fid]
        if f and not f.category then f.category,f.section,f.order,f.indent=p[1],p[2],p[3],p[4] end
    end
end

function UI:Initialize()
    local ok,frame=pcall(CreateFrame,"Frame","ProjectONEMainWindow",UIParent,"PortraitFrameTemplate")
    if not ok or not frame then frame=CreateFrame("Frame","ProjectONEMainWindow",UIParent) end
    self.frame=frame
    if not BookActive() then
        for k,v in pairs(NATIVE_WINDOW) do WINDOW[k]=v end
        ONE.WindowScale.WIDTH,ONE.WindowScale.HEIGHT=WINDOW.width,WINDOW.height
    end
    frame:SetSize(WINDOW.width,WINDOW.height)
    ONE.WindowScale:Initialize(frame)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        ONE.WindowScale:SavePosition(self)
    end)
    frame:SetClampedToScreen(true)
    -- Titel und rundes Portrait (ONE-Logo) wie bei Blizzard-Fenstern.
    -- Titel: "Guild Trip" plus der Name der eigenen Gilde (fuer jede Gilde passend).
    local function TitleText()
        local guildName=type(GetGuildInfo)=="function" and GetGuildInfo("player")
        if type(guildName)=="string" and guildName~="" then return "Guild Trip  ·  "..guildName end
        return T("Guild Trip")
    end
    local fallbackTitle
    local function ApplyTitle()
        local text=TitleText()
        if type(frame.SetTitle)=="function" and pcall(frame.SetTitle,frame,text) then return end
        if not fallbackTitle then
            fallbackTitle=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
            fallbackTitle:SetPoint("TOP",frame,"TOP",0,-6)
        end
        fallbackTitle:SetText(text)
    end
    ApplyTitle()
    if frame.HookScript then frame:HookScript("OnShow",ApplyTitle) end
    self.ApplyTitle=ApplyTitle
    local logo="Interface\\AddOns\\ONE_Core\\Textures\\Common\\Emblem.tga"
    local portrait=false
    for _,method in ipairs({"SetPortraitToAsset","SetPortraitTextureRaw"}) do
        if not portrait and type(frame[method])=="function" then portrait=pcall(frame[method],frame,logo) end
    end
    if not portrait then
        local icon=frame:CreateTexture(nil,"ARTWORK")
        icon:SetTexture(logo)
        icon:SetSize(54,54)
        icon:SetPoint("TOPLEFT",frame,"TOPLEFT",-6,8)
        self.portraitIcon=icon
    end
    -- Eingelassene Innenflaeche wie im Charakterfenster.
    local insetOk,inset=pcall(CreateFrame,"Frame",nil,frame,"InsetFrameTemplate")
    if not insetOk or not inset then
        inset=CreateFrame("Frame",nil,frame)
        ONE.Themes:RegisterPanel(inset)
    end
    inset:SetPoint("TOPLEFT",frame,"TOPLEFT",WINDOW.insetX,-WINDOW.insetTop)
    inset:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-(WINDOW.insetRight or WINDOW.insetX),WINDOW.insetBottom)
    self.inset=inset
    if WINDOW.sideWidth then
        -- Symbolleiste links: eigene eingelassene Flaeche wie die Innenflaeche
        local sok,side=pcall(CreateFrame,"Frame",nil,frame,"InsetFrameTemplate")
        if not sok or not side then side=CreateFrame("Frame",nil,frame) ONE.Themes:RegisterPanel(side) end
        side:SetPoint("TOPLEFT",frame,"TOPLEFT",WINDOW.sideX,-WINDOW.insetTop)
        side:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",WINDOW.sideX,WINDOW.insetBottom)
        side:SetWidth(WINDOW.sideWidth)
        self.sidebar=side
    end
    -- Blizzard-Aussehen: beim Oeffnen alle Textfarben (Gold/Weiss/Grau) neu setzen,
    -- falls das Spiel Schriften inzwischen aufgefrischt hat
    if frame.HookScript then
        frame:HookScript("OnShow",function()
            if ONE.Themes and ONE.Themes.IsNative and ONE.Themes:IsNative() then ONE.Themes:ApplyAll() end
        end)
    end
    self.closeButton=frame.CloseButton
    if not self.closeButton then
        self.closeButton=ONE.Widgets:CloseButton(frame,"TOPRIGHT",-2,-2,function() frame:Hide() end)
    end
    -- Kopfleiste ueber der Innenflaeche: Seitenname links, Zurueck rechts.
    if self.sidebar then
        -- Kopfzeile: Seitenname gross, daneben grau die Zusatzangabe
        self.pathLabel=Label(frame,T("Startseite"),"GameFontNormalLarge",WINDOW.insetX+4,-(WINDOW.insetTop-29),360)
        self.pathLabel:SetWidth(0)
        if self.pathLabel.SetWordWrap then self.pathLabel:SetWordWrap(false) end
        self.contextLabel=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        self.contextLabel:SetPoint("BOTTOMLEFT",self.pathLabel,"BOTTOMRIGHT",10,1)
        self.contextLabel:SetJustifyH("LEFT")
        if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(self.contextLabel,"soft") end
    else
        self.pathLabel=Label(frame,T("Startseite"),"GameFontNormal",WINDOW.insetX+58,-(WINDOW.insetTop-24),300)
    end
    self.backButton=ONE.Widgets:Button(frame,T("Zurück"),96,22,"TOPRIGHT",-12,-(WINDOW.insetTop-27),function() self:GoBack() end)
    self.forwardButton=ONE.Widgets:Button(frame,T("Weiter"),96,22,"TOPRIGHT",-112,-(WINDOW.insetTop-27),function() self:GoForward() end)
    self.forwardButton:Hide()
    -- Fussleiste: Version
    -- endet links neben dem Groessen-Griff unten rechts (26 px)
    if self.sidebar then
        -- Version klein unten in der Symbolleiste
        self.themeStatus=self.sidebar:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        self.themeStatus:SetPoint("BOTTOM",self.sidebar,"BOTTOM",0,7)
        self.themeStatus:SetWidth(WINDOW.sideWidth-6)
        self.themeStatus:SetJustifyH("CENTER")
    else
        self.themeStatus=Label(frame,"","GameFontDisableSmall",WINDOW.width-262,-(WINDOW.height-WINDOW.insetBottom+7),220)
        if self.themeStatus.SetJustifyH then self.themeStatus:SetJustifyH("RIGHT") end
    end
    if UISpecialFrames then table.insert(UISpecialFrames,"ProjectONEMainWindow") end
    if ONE.Kit then
        ONE.Kit:RegisterTile("termine",{title="TERMINE",order=10,build=TermineTile})
    end
    self:AddTab("home",T("Startseite"),BuildHome)
    -- Alle Einstellungen in Optionen (Bereiche links); fruehere Unterseiten leiten dorthin
    RegisterCoreSettings()
    for old,cat in pairs({modules="general",assists="general",sharing="sharing",["guild-reminder-settings"]="reminders"}) do
        self:AddAlias(old,"options",function() UI.optionsCategory=cat end)
    end
    self:AddTab("options",T("Optionen"),BuildOptions)
    self:SelectTab("home")
    self:UpdateBackButton()
    frame:Hide()
end
