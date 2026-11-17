local _, ONE = ...
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local UI = { tabs={}, views={}, order={}, history={}, forwardHistory={},
    backHandlers={}, optionsLinks={}, sidebarButtons={}, shareOptions={}, feeds={}, options={} }
ONE.UI=UI

-- Das feste Fenster ist 1010 UI-Einheiten breit. Der Inhalt liegt zwischen
-- x=251 und x=977, also 726 Einheiten. Alle Module benutzen dasselbe Raster.
-- Ein späteres Fenster-Resize muss diese Definition ebenfalls berücksichtigen.
local Layout = {width=ONE.Geometry.tokens.contentWidth, gutter=ONE.Geometry.tokens.columnGap}
UI.Layout = Layout

-- Keine mehrfachen, voneinander abweichenden Spalten-Berechnungen mehr.
function Layout:Columns(weights)
    if #weights==2 and ONE.Book and ONE.Book.Spread then
        local L,R=ONE.Book:Spread()
        if L then return {{x=L.x,width=L.width},{x=R.x,width=R.width}} end
    end
    return ONE.Geometry:Columns(self.width,weights,self.gutter)
end
function Layout:Actions(card,weights)
    return ONE.Geometry:Actions(card,weights)
end

local NAV_ORDER={home=1,guild=2,calendar=3,dungeons=4,groups=5,crafting=6,classes=7,quests=7.5,nav=8,options=9}
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
local VIEW_PARENT={modules="options",assists="options",sharing="options",themes="options",
    ["guild-reminder-settings"]="options",["guild-members"]="guild",today="home"}
UI.VIEW_PARENT=VIEW_PARENT
local function BookActive() return ONE.Book and ONE.Book.IsActive and ONE.Book:IsActive() end
local ICONS="Interface\\AddOns\\ONE_Core\\Textures\\Book\\TabIcons"
local ICON_INDEX={home=0,guild=1,calendar=2,dungeons=3,groups=3,crafting=4,classes=5,quests=6,nav=7,options=8}
local NAV_LABEL={home="Startseite",guild="Gilde",calendar="Kalender",today="Heute",
    dungeons=T("Dungeons"),groups=T("Gruppen"),crafting=T("Berufe"),classes=T("Klasse"),quests=T("Quests"),nav=T("Navi"),modules=T("Module"),options=T("Optionen"),themes=T("Farben & Klänge")}

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
        else tab:SetPoint("LEFT",tabs[i-1],"RIGHT",(ONE.Book and ONE.Book:IsActive()) and 2 or -14,0) end
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
    if ONE.Book then ONE.Book:UpdateTabs(self) end
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
    if ONE.Book then ONE.Book:PanelAdded(self) end
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
    if ONE.Book then ONE.Book:PanelAdded(self) end
    return true
end
function UI:AddOptionsLink(id,title,viewId)
    if type(id)~="string" or type(title)~="string" or type(viewId)~="string" then return false end
    for _,link in ipairs(self.optionsLinks) do if link.id==id then return false end end
    if #self.optionsLinks>=4 then return false end
    self.optionsLinks[#self.optionsLinks+1]={id=id,title=title,viewId=viewId}
    self:Refresh()
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
-- Einstellungen aus Modulen fuer Optionen › Spielhilfen, nach Abschnitt (section) gruppiert
-- opts = {id, section, kind="check"|"dropdown"|"button", label, tooltip, get, set, options, onClick, width}
function UI:AddOption(opts)
    if type(opts)~="table" or type(opts.id)~="string" or type(opts.get)~="function" or type(opts.set)~="function" then return false end
    for _,o in ipairs(self.options) do if o.id==opts.id then return false end end
    self.options[#self.options+1]=opts
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
    if ONE.Book then ONE.Book:UpdateBack(self) end
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
    if ONE.Book then
        local entry=self.tabs[id] or self.views[id]
        if self.__hasNavigated and self.frame:IsShown() then ONE.Book:TurnPage(entry and entry.panel) end
        if entry and entry.panel then ONE.Book:InkTree(entry.panel,0) end
    end
    if self.pathLabel then self.pathLabel:SetText(T(NAV_LABEL[id] or (self.sidebar and NAV_LABEL[VIEW_PARENT[id] or ""]) or "")) end
    self:UpdateContext()
    self:UpdateViews()
    -- Buch: "Guild Trip · Gildenname" links oben nur auf der Startseite (Nutzer-Wunsch 15.11.2026)
    if ONE.Book and ONE.Book.leftHead then
        if id=="home" then ONE.Book.leftHead:Show() else ONE.Book.leftHead:Hide() end
    end
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
    if not set and (self.activeTab=="options" or VIEW_PARENT[self.activeTab]=="options") then
        -- Optionen: Unterseiten der Module als Ansichten
        local items={{key="options",label="Allgemein"}}
        local SHORT={["Module verwalten"]="Module",["Erinnerungszeiten einstellen"]="Erinnerungen"}
        for _,link in ipairs(self.optionsLinks) do items[#items+1]={key=link.viewId,label=SHORT[link.title] or link.title} end
        for _,it in ipairs(items) do it.onClick=function(key) self:Navigate(key) end end
        set={items=items}
    end
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
    if ONE.Book then ONE.Book:InkPages(self) end
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

local function BuildHome(panel)
    -- Buch-Aussehen: eigene Doppelseite (Initiale, Siegel, Inhaltsverzeichnis)
    if ONE.Book and ONE.Book:Spread() then return ONE.Book:BuildHome(panel) end
    local W=UI.Layout.width
    local cols=UI.Layout:Columns({5,4})
    -- Einheitliche Seiteneinfuehrung; alle Karten liegen innerhalb der 726er Spur.
    -- Buch-Aussehen: Doppelseite – links Begruessung, rechts die Kacheln
    local L,R=nil,nil
    if ONE.Book then L,R=ONE.Book:Spread() end
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
        if ONE.Book and ONE.Book:IsActive() then art:Hide() end
        art:ClearAllPoints()
        art:SetPoint("TOPLEFT",hero,"TOPLEFT",4,-4)
        art:SetPoint("BOTTOMRIGHT",hero,"BOTTOMRIGHT",-4,4)
        artReady=true
    end
    RefreshArt()
    Label(hero,"DEIN TAG IN AZEROTH","GameFontNormalSmall",heroHeader.x,heroHeader.y,textW)
    local heading=Label(hero,T("Willkommen zurück!"),"GameFontNormalHuge",heroHeader.x,-54,textW)
    local playerName=Label(hero,"","GameFontHighlight",heroHeader.x,-90,textW)
    Label(hero,T("Termine und Gilde – übersichtlich an einem Ort."),
        "GameFontHighlight",heroHeader.x,-114,L and textW or 430,"soft")
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
        playerName:SetText(name or T("Dein Abenteuer geht weiter"))
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

-- ===== Blaettern (Nutzer-Wunsch 15.11.2026) =====
-- Wird eine Seite zu voll, geht es im selben Reiter auf einer neuen Seite weiter:
-- unten rechts "‹  Seite 1 von 2  ›". Elemente melden sich mit ihrer Seitennummer an.
function UI:Pager(panel,x,y,width)
    local p={page=1,count=1,items={}}
    p.prev=ONE.Widgets:Button(panel,"‹",28,22,"TOPLEFT",x,y,function() p:Go(p.page-1) end)
    p.next=ONE.Widgets:Button(panel,"›",28,22,"TOPLEFT",x+width-28,y,function() p:Go(p.page+1) end)
    p.label=Label(panel,"","GameFontHighlightSmall",x+34,y-5,width-68,"soft")
    if p.label.SetJustifyH then p.label:SetJustifyH("CENTER") end
    function p:Reset() self.items,self.count={},1 end
    function p:Add(widget,page)
        self.items[#self.items+1]={w=widget,page=page or 1}
        if (page or 1)>self.count then self.count=page end
    end
    function p:Go(n)
        self.page=math.max(1,math.min(self.count,n or self.page))
        for _,it in ipairs(self.items) do
            if it.page==self.page then it.w:Show() else it.w:Hide() end
        end
        local many=self.count>1
        for _,w in ipairs({self.prev,self.next,self.label}) do if many then w:Show() else w:Hide() end end
        self.label:SetText(T("Seite %d von %d",self.page,self.count))
        if self.prev.SetEnabled then self.prev:SetEnabled(self.page>1) end
        if self.next.SetEnabled then self.next:SetEnabled(self.page<self.count) end
        if ONE.Sound and many and self.turned then ONE.Sound:Play("page") end
        self.turned=true
    end
    return p
end

local function BuildModules(panel)
    -- Haekchen-Liste: je Modul ein Haekchen, darunter eingerueckt seine Funktionen.
    -- Zwei Spalten (im Buch = zwei Seiten). Modul aus = nach dem Neuladen gar nicht gestartet.
    local W=UI.Layout.width
    local L,R
    if ONE.Book then L,R=ONE.Book:Spread() end
    local cols={{x=L and L.x or 0,w=L and L.width or math.floor(W/2)-10},{x=R and R.x or math.floor(W/2)+10,w=R and R.width or math.floor(W/2)-10}}
    ONE.Widgets:PageHeader(panel,T("Module & Funktionen"),
        T("Haken weg = aus. Ein Modul aus schaltet auch alle seine Funktionen ab."),L and L.width or W)
    local status=Label(panel,"","GameFontHighlightSmall",cols[2].x,-372,cols[2].w,"soft")
    local pager=UI:Pager(panel,cols[2].x,-400,cols[2].w)
    if status.SetWordWrap then status:SetWordWrap(true) end
    local boxes={}
    local reloadNeeded=false
    local coreHead=Label(panel,T("Guild Trip (Grundfunktionen)"),"GameFontNormal",0,0,cols[1].w,"accent")
    local function Box(key,opts)
        local b=boxes[key]
        if not b then
            b=ONE.Kit:Check(panel,opts)
            boxes[key]=b
        end
        return b
    end
    return function()
        local y,col,top,maxY,page=-64,1,-64,-360,1
        local used={}
        pager:Reset()
        pager:Add(coreHead,1)
        -- naechste Spalte, nach der rechten eine neue Seite
        local function NextColumn()
            if col==1 then col,y=2,top else col,y,page=1,top,page+1 end
        end
        local function Place(b,indent)
            if y<maxY then NextColumn() end
            pager:Add(b,page)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",panel,"TOPLEFT",cols[col].x+indent,y)
            if b.label and b.label.SetWidth then b.label:SetWidth(cols[col].w-indent-34) end
            -- linksbuendig direkt neben dem Haekchen (mit fester Breite sonst mittig)
            if b.label and b.label.SetJustifyH then b.label:SetJustifyH("LEFT") end
            -- Module als goldene Ueberschrift, Funktionen in normaler Schrift
            if b.label and b.label.SetFontObject then
                pcall(b.label.SetFontObject,b.label,indent>0 and "GameFontHighlight" or "GameFontNormal")
                if indent==0 and b.label.SetTextColor then b.label:SetTextColor(1,.82,0) end
            end
            b:Show()
            y=y-(indent>0 and 21 or 26)
        end
        -- Kern-Funktionen (ohne Modul) zuerst
        coreHead:ClearAllPoints() coreHead:SetPoint("TOPLEFT",panel,"TOPLEFT",cols[1].x+4,y-4)
        y=y-24
        for _,fid in ipairs(ONE.featureOrder) do
            local f=ONE.features[fid]
            if not f.module then
                local fb=Box("f:"..fid,{label=T(f.label),tooltip=f.tooltip and T(f.tooltip),
                    get=function() return ONE:FeatureOn(fid) end,
                    set=function(on) ONE:SetFeature(fid,on) if f.reload then reloadNeeded=true end end})
                fb:Refresh() Place(fb,22) used["f:"..fid]=true
            end
        end
        y=y-6
        for _,id in ipairs(ONE.moduleOrder) do
            local def=ONE.modules[id]
            local feats={}
            for _,fid in ipairs(ONE.featureOrder) do if ONE.features[fid].module==id then feats[#feats+1]=fid end end
            -- Modul und seine Funktionen moeglichst in einer Spalte halten
            if y-28-#feats*24<maxY and y<top then NextColumn() end
            local mb=Box("m:"..id,{label=T(def.title or id),
                tooltip=T("Ganzes Modul an oder aus. Wirkt nach dem Neuladen."),
                get=function() return ONE:IsEnabled(id) end,
                set=function(on) ONE.db.modules[id]=on and true or false reloadNeeded=true end})
            mb:Refresh() Place(mb,0) used["m:"..id]=true
            for _,fid in ipairs(feats) do
                local f=ONE.features[fid]
                local fb=Box("f:"..fid,{label=T(f.label),tooltip=f.tooltip and T(f.tooltip),
                    get=function() return ONE:FeatureOn(fid) end,
                    set=function(on) ONE:SetFeature(fid,on) if f.reload then reloadNeeded=true end end})
                fb:Refresh()
                if fb.SetEnabled then fb:SetEnabled(ONE:IsEnabled(id)) end
                Place(fb,22) used["f:"..fid]=true
            end
        end
        for key,b in pairs(boxes) do if not used[key] then b:Hide() end end
        pager:Go(pager.page)
        status:SetText(reloadNeeded and ("|cffff8060"..T("Änderung wirkt nach dem Neuladen (/reload).").."|r")
            or (#ONE.moduleOrder==0 and T("Der Kern von Guild Trip funktioniert auch ohne weitere Module.") or ""))
        if reloadNeeded and not UI.moduleReloadAsked then UI.moduleReloadAsked=true UI:AskReload("modules") end
    end
end

-- Optionen im Blizzard-Stil: drei Karten, Haekchen statt AN/AUS-Knoepfen,
-- Schieberegler fuer Groessen, Links zu Unterseiten unten.
local function CheckBox(parent,x,y,label,tooltip,onClick)
    local ok,box=pcall(CreateFrame,"CheckButton",nil,parent,"UICheckButtonTemplate")
    if not ok or not box then box=CreateFrame("CheckButton",nil,parent) end
    box:SetSize(26,26)
    box:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    local text=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    text:SetPoint("LEFT",box,"RIGHT",4,0)
    text:SetText(T(label))
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(text,"text") end
    box.label=text
    box:SetScript("OnClick",function(self)
        onClick(self.GetChecked and self:GetChecked() and true or false)
        ONE.UI:Refresh()
    end)
    if tooltip then
        box:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(T(label))
            GameTooltip:AddLine(T(tooltip),1,1,1,true)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
    return box
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
local function OptionCard(parent,x,y,w,h,title)
    local card=Panel(parent,x,y,w,h)
    local label=Label(card,title,"GameFontNormalSmall",16,-14,w-32)
    if ONE.Themes and ONE.Themes.PanelTitle then ONE.Themes:PanelTitle(card,label) end
    return card
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

local function BuildOptions(panel)
    local W=UI.Layout.width
    ONE.Widgets:PageHeader(panel,T("Einstellungen"),
        T("Benachrichtigungen funktionieren nur, während WoW läuft."),W)
    local cols=UI.Layout:Columns({1,1})
    local cardH=250

    -- Benachrichtigungen
    -- Buch: links Benachrichtigungen + Verzeichnis der Unterseiten, rechts die ganze
    -- Darstellung (inkl. Sprache und Aussehen) ueber die volle Seitenhoehe
    local bookL,bookR=nil,nil
    if ONE.Book and ONE.Book.Spread then bookL,bookR=ONE.Book:Spread() end
    local notes=OptionCard(panel,cols[1].x,-62,cols[1].width,bookL and 190 or cardH,"BENACHRICHTIGUNGEN")
    local reminders=CheckBox(notes,14,-36,"Kalender-Erinnerungen",
        T("Erinnert dich vor Gildenterminen (Zeiten unter „Erinnerungszeiten“)."),
        function(v) ONE.db.remindersEnabled=v end)
    local sound=CheckBox(notes,14,-66,T("Ton bei Benachrichtigungen"),nil,
        function(v) ONE.db.soundEnabled=v end)
    local welcome=CheckBox(notes,14,-96,T("Tagesübersicht beim Login"),
        T("Zeigt beim Einloggen die Termine des Tages."),
        function(v) ONE.db.loginSummaryEnabled=v end)
    local toast=CheckBox(notes,14,-126,T("Hinweisfenster anzeigen"),
        T("Ein kleines Fenster zusätzlich zur Chatzeile."),
        function(v) ONE.db.toastEnabled=v ONE.Notifications:SettingsChanged() end)
    ONE.Widgets:Button(notes,T("Benachrichtigung testen"),200,24,"TOPLEFT",16,-158,function()
        ONE:Notify(T("Guild Trip: Dies ist eine Testbenachrichtigung."), { source = T("Guild Trip Test") })
    end)

    -- Darstellung
    local look=OptionCard(panel,cols[2].x,-62,cols[2].width,bookL and 375 or cardH,"DARSTELLUNG")
    local inner=cols[2].width-32
    Label(look,T("Fenstergröße"),"GameFontHighlight",16,-38,inner-60,"text")
    local scaleValue=Label(look,"","GameFontHighlight",16+inner-60,-38,60,"text")
    if scaleValue.SetJustifyH then scaleValue:SetJustifyH("RIGHT") end
    local slider=OptionSlider(look,16,-60,inner)
    slider:SetValueStep(.05)
    ONE.WindowScale:AttachControls(slider,scaleValue)
    Label(look,T("Schriftgröße"),"GameFontHighlight",16,-92,inner-60,"text")
    local fontValue=Label(look,"","GameFontHighlight",16+inner-60,-92,60,"text")
    if fontValue.SetJustifyH then fontValue:SetJustifyH("RIGHT") end
    local fontSlider=OptionSlider(look,16,-114,inner)
    local scales=ONE.Kit and ONE.Kit.scales or {1}
    fontSlider:SetMinMaxValues(1,#scales)
    fontSlider:SetValueStep(1)
    fontSlider:SetScript("OnValueChanged",function(_,value)
        local index=math.floor((value or 1)+.5)
        local scale=scales[index]
        if ONE.Kit and scale and math.abs(ONE.Kit.Settings().fontScale-scale)>.001 then ONE.Kit:SetFontScale(scale) end
    end)
    local contrast=CheckBox(look,14,-144,T("Hoher Kontrast"),
        T("Nebentexte werden so hell wie normaler Text."),
        function() if ONE.Kit then ONE.Kit:ToggleContrast() end end)
    local clicks=CheckBox(look,14,-174,T("Menüklänge"),
        T("Leise Klicks beim Wechseln der Guild-Trip-Seiten."),
        function(v) ONE.db.theme.uiSounds=v end)
    ONE.Widgets:Button(look,T("Fenstergröße zurücksetzen"),200,24,"TOPLEFT",16,-214,function()
        ONE.WindowScale:Reset()
    end)

    -- Weitere Einstellungen (Unterseiten der Module)
    local moreY,moreH=-62-cardH-12,437-62-cardH-12
    if bookL then moreY,moreH=-62-190-12,437-62-190-12 end
    local headerViews=UI.sidebar~=nil
    if headerViews then moreH=moreH+(panel.__oneLifted or 0) end
    local more=OptionCard(panel,0,moreY,bookL and bookL.width or W,moreH,
        bookL and "WEITERE SEITEN" or (headerViews and "SPRACHE & AUSSEHEN" or "WEITERE EINSTELLUNGEN"))
    local langCard=more
    if bookL then
        langCard=look
        Label(look,"Sprache / Language","GameFontHighlight",16,-252,cols[2].width-32,"text")
    else
        -- Sprache: Automatisch (Spielsprache) / Deutsch / English – wirkt nach Neuladen
        -- Beschriftung direkt ueber dem Auswahlfeld (rechts), damit sie nicht hinter den Knoepfen liegt
        Label(more,"Sprache / Language","GameFontNormal",W-226,-16,210,"accent")
    end
    ONE.Kit:Dropdown(langCard,{point=bookL and "TOPLEFT" or "TOPRIGHT",x=bookL and 16 or -16,y=bookL and -272 or -36,width=bookL and 240 or 210,
        options=function() return {{value=nil,text="Automatisch (Spielsprache)"},{value="de",text="Deutsch"},{value="en",text="English"}} end,
        get=function() return ONE.db.language end,
        set=function(v) ONE.db.language=v end,
        onChange=function() UI:AskReload() end})
    -- Aussehen: Blizzard oder "Altes Buch" (Probe)
    local lookChoice=ONE.Kit:Dropdown(langCard,{point=bookL and "TOPLEFT" or "TOPRIGHT",x=bookL and 16 or -16,y=bookL and -312 or -72,width=bookL and 240 or 210,
        options=function() return {{value="native",text=T("Aussehen: Blizzard")},{value="book",text=T("Aussehen: Altes Buch (Probe)")}} end,
        get=function() return ONE.db.theme and ONE.db.theme.selected=="book" and "book" or "native" end,
        set=function(v) if ONE.Book then ONE.Book:SetEnabled(v=="book") end end})
    local links={}
    for i=1,4 do
        -- Buch: Verzeichnis, eine Zeile je Unterseite, linksbuendig
        local lw=bookL and 260 or 230
        local lx=bookL and 16 or 16+((i-1)%2)*(lw+16)
        local ly=bookL and (-36-(i-1)*28) or (-40-math.floor((i-1)/2)*32)
        links[i]=ONE.Widgets:Button(more,"",lw,24,"TOPLEFT",lx,ly,function()
            local action=ONE.UI.optionsLinks[i]
            if action then ONE.UI:OpenLink(action.viewId) end
        end)
        if links[i].AlignLeft then links[i]:AlignLeft() end
        links[i]:Hide()
    end
    return function()
        local function Set(box,value) if box.SetChecked then box:SetChecked(value and true or false) end end
        Set(reminders,ONE.db.remindersEnabled)
        Set(sound,ONE.db.soundEnabled)
        Set(welcome,ONE.db.loginSummaryEnabled)
        Set(toast,ONE.db.toastEnabled)
        Set(clicks,ONE.db.theme and ONE.db.theme.uiSounds)
        if lookChoice.Refresh then lookChoice:Refresh() end
        if ONE.Kit then
            local kit=ONE.Kit.Settings()
            Set(contrast,kit.contrast=="high")
            fontValue:SetText(math.floor(kit.fontScale*100+.5).." %")
            for i,scale in ipairs(scales) do
                if math.abs(scale-kit.fontScale)<.001 and fontSlider.SetValue then fontSlider:SetValue(i) end
            end
        end
        for i,button in ipairs(links) do
            local action=ONE.UI.optionsLinks[i]
            -- mit Symbolleiste stehen die Unterseiten oben als Ansichten
            if action and not headerViews then button:SetText((bookL and "›  " or "")..T(action.title)) button:Show() else button:Hide() end
        end
    end
end

-- Unterseite "Teilen": ein Haekchen je Modul, darunter kurz, was geteilt wird
-- Unterseite "Spielhilfen": Einstellungen der Module (Klasse, Navi ...), je Abschnitt
-- eine Karte; im Buch links/rechts. Neue Optionen erscheinen beim naechsten Aktualisieren.
local function BuildAssists(panel)
    local W=UI.Layout.width
    ONE.Widgets:PageHeader(panel,T("Spielhilfen"),T("Einstellungen für Klassen-Ratgeber und Navi."),W)
    local cols=UI.Layout:Columns({1,1})
    local widgets,count={},0
    local empty=Label(panel,T("Keine Module mit Einstellungen aktiv."),"GameFontHighlightSmall",0,-80,W,"soft")
    local H={check=28,dropdown=36,button=32}
    -- zu voll? weiterblaettern (unten rechts)
    local pager=UI:Pager(panel,cols[2].x,-400,cols[2].width)
    local BOTTOM=-388
    -- Abschnitte werden auf einmal aufgebaut (Hoehe aus den Eintraegen) und in die
    -- jeweils kuerzere Spalte gelegt; kommen spaeter Optionen dazu, wird neu aufgebaut.
    local function Build()
        local order,groups={},{}
        for _,o in ipairs(UI.options) do
            local name=o.section or "Module"
            if not groups[name] then groups[name]={} order[#order+1]=name end
            table.insert(groups[name],o)
        end
        local cursor,page={-70,-70},1
        pager:Reset()
        for _,name in ipairs(order) do
            local list=groups[name]
            local height=48
            for _,o in ipairs(list) do height=height+H[o.kind or "check"] end
            local c=(cursor[1]>=cursor[2]) and 1 or 2
            -- passt nicht mehr: andere Spalte, sonst neue Seite
            if cursor[c]-height<BOTTOM then c=(c==1) and 2 or 1 end
            if cursor[c]-height<BOTTOM and (cursor[1]<-70 or cursor[2]<-70) then page,cursor,c=page+1,{-70,-70},1 end
            local col=cols[c]
            local card=OptionCard(panel,col.x,cursor[c],col.width,height,name)
            pager:Add(card,page)
            cursor[c]=cursor[c]-height-12
            local y=-40
            for _,o in ipairs(list) do
                local kind=o.kind or "check"
                local w
                if kind=="dropdown" then
                    w=ONE.Kit:Dropdown(card,{point="TOPLEFT",x=16,y=y,width=o.width or 220,tooltip=o.tooltip and T(o.tooltip),
                        options=o.options,get=o.get,set=o.set,onChange=function() end})
                elseif kind=="button" then
                    w=ONE.Widgets:Button(card,o.label,220,24,"TOPLEFT",16,y-2,o.onClick)
                else
                    w=ONE.Kit:Check(card,{point="TOPLEFT",x=14,y=y,label=o.label,tooltip=o.tooltip,
                        get=o.get,set=o.set,onChange=function() end})
                end
                y=y-H[kind]
                widgets[#widgets+1]=w
            end
        end
        count=#UI.options
    end
    return function()
        if count==0 and #UI.options>0 then Build() end
        for _,w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
        pager:Go(pager.page)
        if count>0 then empty:Hide() else empty:Show() end
    end
end

local function BuildSharing(panel)
    local W=UI.Layout.width
    ONE.Widgets:PageHeader(panel,T("Teilen"),
        T("Hier schaltest du alles an oder aus, was Guild Trip mit deiner Gilde teilt. Ohne Häkchen wird nichts gesendet."),W)
    if ONE.Book and ONE.Book.Spread and ONE.Book:Spread() then W=ONE.Book.left.width end
    local card=Panel(panel,0,-70,W,360)
    local rows={}
    local empty=Label(card,T("Keine Module mit Teilen-Funktion aktiv."),"GameFontHighlightSmall",16,-16,W-32,"soft")
    return function()
        local y=-14
        local shown=0
        for _,opt in ipairs(UI.shareOptions) do
            local row=rows[opt.id]
            if not row then
                row={}
                row.box=ONE.Kit:Check(card,{point="TOPLEFT",x=12,y=0,label=opt.label,
                    get=opt.get,set=opt.set,onChange=function() UI:Refresh() end})
                row.note=Label(card,"","GameFontHighlightSmall",42,0,W-60,"soft")
                rows[opt.id]=row
            end
            local visible=(not opt.module or ONE:IsEnabled(opt.module)) and (not opt.visible or opt.visible())
            if visible then
                row.box:ClearAllPoints() row.box:SetPoint("TOPLEFT",card,"TOPLEFT",12,y)
                row.note:ClearAllPoints() row.note:SetPoint("TOPLEFT",card,"TOPLEFT",42,y-24)
                row.note:SetText(opt.tooltip and T(opt.tooltip) or "")
                row.box:Refresh() row.box:Show() row.note:Show()
                -- Hoehe nach Text (frueher fest 62 – lange Beschreibungen liefen aus dem Fenster)
                local h=row.note.GetStringHeight and row.note:GetStringHeight() or 0
                if type(h)~="number" or h<=0 then h=26 end
                y=y-24-h-12
                shown=shown+1
            else
                row.box:Hide() row.note:Hide()
            end
        end
        if shown==0 then empty:Show() else empty:Hide() end
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
    -- Module als Unterseite der Optionen (spart einen Reiter)
    self:RegisterView("modules",BuildModules)
    self:AddOptionsLink("modules",T("Module verwalten"),"modules")
    self:RegisterView("assists",BuildAssists)
    self:RegisterView("sharing",BuildSharing)
    self:AddOptionsLink("sharing",T("Teilen"),"sharing")
    self:AddOptionsLink("assists",T("Spielhilfen"),"assists")
    self:AddTab("options",T("Optionen"),BuildOptions)
    self:SelectTab("home")
    self:UpdateBackButton()
    if ONE.Book then ONE.Book:Attach(self) end
    frame:Hide()
end
