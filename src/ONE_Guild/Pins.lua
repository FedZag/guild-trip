-- Project ONE Guild: passive pins on the built-in World Map (no replacement UI).
local _, guild = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Pins={pool={}, hooked=false}
guild.Pins=Pins

local function MapPosition(peer, viewedMap)
    if peer.mapID==viewedMap then return peer.x,peer.y end
    if not (C_Map and type(C_Map.GetMapInfo)=="function"
        and type(C_Map.GetMapRectOnMap)=="function") then return end
    -- Only use map rectangles for actual ancestors; unrelated map rectangles
    -- can produce values that look valid but are geographically wrong.
    local id=peer.mapID
    local ancestor=false
    for _=1,8 do
        local ok, info=pcall(C_Map.GetMapInfo,id)
        if not ok or not info or not info.parentMapID then break end
        id=info.parentMapID
        if id==viewedMap then ancestor=true; break end
        if id==0 then break end
    end
    if not ancestor then return end
    local ok,l,r,t,b=pcall(C_Map.GetMapRectOnMap,peer.mapID,viewedMap)
    if not ok or type(l)~="number" or type(r)~="number"
        or type(t)~="number" or type(b)~="number"
        or l<0 or t<0 or r>1 or b>1 or r<=l or b<=t then return end
    return l + peer.x*(r-l), t + peer.y*(b-t)
end
local function Canvas(map)
    if type(map.GetCanvas)=="function" then
        local ok,result=pcall(map.GetCanvas,map)
        if ok and result then return result end
    end
    return map.ScrollContainer and map.ScrollContainer.Child
end
local function NewPin(canvas)
    local pin=CreateFrame("Frame",nil,canvas)
    pin:SetSize(14,14)
    -- keine eigene Ebene (frueher HIGH): bei verkleinerter Karte (z. B. OpenMaps)
    -- lagen die Punkte sonst ueber anderen Fenstern
    pin:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1)+50)
    pin:EnableMouse(true)
    -- Transparente runde ONE-Pins statt einer quadratischen POI-Atlaszelle.
    local point=pin:CreateTexture(nil,"ARTWORK")
    point:SetTexture("Interface\\AddOns\\ONE_Guild\\Textures\\MemberPin.tga")
    point:SetAllPoints()
    pin.icon=point
    local text=pin:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetPoint("BOTTOM",pin,"TOP",0,3)
    text:SetTextColor(1,0.86,0.58)
    pin.text=text
    pin:SetScript("OnEnter",function(self)
        Pins:ShowMemberTooltip(self,self.peerName,self.peer)
    end)
    pin:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    pin:SetScript("OnMouseUp",function(self,button)
        if button=="LeftButton" and self.peerName then
            Pins:SelectMember(self.peerName,false)
        end
    end)
    return pin
end

-- Location names are resolved from the shared map ID, not inferred from
-- translated zone names or fake coordinates. A smaller 'Ort' is only shown if
-- a consenting peer sent it; old 0.3.7c peers still work without that field.
function Pins:LocationDetails(peer)
    if not peer then return {} end
    local result={}
    local infoByType={}
    local seen={}
    local mapID=peer.mapID
    if C_Map and type(C_Map.GetMapInfo)=="function" then
        for _=1,12 do
            if type(mapID)~="number" or mapID<=0 or seen[mapID] then break end
            seen[mapID]=true
            local ok,info=pcall(C_Map.GetMapInfo,mapID)
            if not ok or type(info)~="table" then break end
            if type(info.name)=="string" and info.name~="" then
                if type(info.mapType)=="number" then
                    infoByType[info.mapType]=info.name
                end
                if not result.map then result.map=info.name end
            end
            if type(info.parentMapID)~="number" or info.parentMapID<=0 then break end
            mapID=info.parentMapID
        end
    end
    result.world=infoByType[1]
    result.continent=infoByType[2]
    result.region=infoByType[3] or result.map
    if type(peer.subZone)=="string" and peer.subZone~=""
        and peer.subZone~=result.region and peer.subZone~=result.map
        and (not peer.subZoneSeen or not GetTime
             or GetTime()-peer.subZoneSeen<=90) then
        result.place=peer.subZone
    end
    if type(peer.x)=="number" and type(peer.y)=="number" then
        result.coordinates=string.format("%.1f / %.1f",peer.x*100,peer.y*100)
    end
    return result
end

function Pins:ShowMemberTooltip(owner,name,peer)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    GameTooltip:SetText((name or T("Gildenmitglied")):match("^[^-]+"))
    if peer then
        local where=self:LocationDetails(peer)
        local function Line(label,value)
            if value and value~="" then
                GameTooltip:AddDoubleLine(label,value,0.58,0.79,0.97,1,0.96,0.83)
            end
        end
        Line(T("Welt"),where.world)
        Line(T("Kontinent"),where.continent)
        Line(T("Region"),where.region)
        Line(T("Ort / Untergebiet"),where.place)
        Line(T("Kartenkoordinaten (%)"),where.coordinates)
        local age=type(GetTime)=="function" and peer.seen
            and math.max(0,math.floor(GetTime()-peer.seen)) or nil
        GameTooltip:AddLine(age and T("Guild-Trip-Standort: vor %d Sek. empfangen", age)
            or T("Guild-Trip-Standort freiwillig geteilt"),0.64,0.86,0.74)
    else
        GameTooltip:AddLine(T("Keine aktuelle Guild-Trip-Position verfügbar"),1,0.73,0.42)
    end
    GameTooltip:Show()
end

function Pins:Attach()
    local wm=_G.WorldMapFrame
    if not wm then return end
    if self.hooked then return end
    self.hooked=true
    self:CreateMapSearch()
    if wm.HookScript then
        wm:HookScript("OnShow",function()
            if guild.Roster then guild.Roster:Request() end
            self:SyncSearchVisibility()
            self:Refresh()
        end)
        wm:HookScript("OnHide",function() self:SyncSearchVisibility() end)
    end
    self:SyncSearchVisibility()
    if type(hooksecurefunc)=="function" and type(wm.OnMapChanged)=="function" then
        hooksecurefunc(wm,"OnMapChanged",function() self:Refresh() end)
    end
end
function Pins:Refresh()
    local map=_G.WorldMapFrame
    if not map or not map:IsShown() or (ONE.FeatureOn and not ONE:FeatureOn("guild.mapPins")) then
        for _,pin in ipairs(self.pool) do pin:Hide() end
        if self.searchPanel then self:SyncSearchVisibility() end
        return
    end
    local canvas=Canvas(map)
    local mapID=type(map.GetMapID)=="function" and map:GetMapID() or map.mapID
    local w,h=canvas and canvas:GetWidth(),canvas and canvas:GetHeight()
    if not mapID or not canvas or not w or not h or w<=0 or h<=0 then return end
    local n=0
    for _,peer in ipairs(guild.Presence:ActivePeers()) do
        local x,y=MapPosition(peer,mapID)
        if x and y and x>=0 and y>=0 and x<=1 and y<=1 then
            n=n+1
            local pin=self.pool[n]
            if not pin then pin=NewPin(canvas); self.pool[n]=pin end
            if pin:GetParent()~=canvas then pin:SetParent(canvas) end
            pin:ClearAllPoints()
            pin:SetPoint("CENTER",canvas,"TOPLEFT",x*w,-y*h)
            pin.peerName=peer.name
            pin.peer=peer
            local active=self.selected and self:PeerNamesMatch(self.selected,peer.name)
            -- dezent wie Blizzards Gruppenpunkte; ausgewaehlt etwas groesser
            pin:SetSize(active and 20 or 14,active and 20 or 14)
            pin.icon:SetTexture("Interface\\AddOns\\ONE_Guild\\Textures\\"..
                (active and "MemberPinSelected.tga" or "MemberPin.tga"))
            pin.text:SetText(active and ((peer.name:match("^[^-]+")) or peer.name) or "")
            pin:Show()
        end
    end
    for i=n+1,#self.pool do self.pool[i]:Hide() end
    self:RefreshSearch()
end

-- ONE's map controls are drawn in a separate UIParent overlay (not the
-- scrollable WorldMapFrame canvas). This is essential: the map must NOT take
-- the mouse clicks intended for our search EditBox and suggestion buttons.
local function DisplayName(s)
    return (s or ""):match("^[^-]+") or (s or "")
end
local function Key(s)
    return type(s)=="string" and s:lower() or ""
end
function Pins:PeerNamesMatch(a,b)
    if Key(a)==Key(b) then return true end
    -- A realm-less roster name may match one unique live peer. Full realm names
    -- never silently map to a player on a different realm.
    return type(a)=="string" and type(b)=="string"
        and not a:find("-",1,true) and Key(a)==Key(DisplayName(b))
end
function Pins:SearchMatches(query,limit)
    query=Key(query):gsub("^%s+",""):gsub("%s+$","")
    local candidates,added={},{}
    local peers=guild.Presence and guild.Presence:ActivePeers() or {}
    local function MatchingPeer(name)
        for _,peer in ipairs(peers) do
            if Key(peer.name)==Key(name) then return peer end
        end
        if name:find("-",1,true) then return end
        local found
        for _,peer in ipairs(peers) do
            if Key(DisplayName(peer.name))==Key(name) then
                if found then return nil end -- ambiguous cross-realm names
                found=peer
            end
        end
        return found
    end
    local function Add(member,livePeer)
        if type(member.name)~="string" or member.name=="" then return end
        local name=livePeer and livePeer.name or member.name
        local k=Key(name)
        if added[k] then return end
        if query~="" and not (Key(DisplayName(name)):find(query,1,true)
            or (query:find("-",1,true) and k:find(query,1,true))) then return end
        candidates[#candidates+1]={
            name=name,online=true,zone=member.zone or "",live=livePeer~=nil,
            class=member.class,level=member.level,
        }
        added[k]=true
        added[Key(member.name)]=true
    end
    if guild.Roster then
        for _,member in ipairs(guild.Roster:Members()) do
            if member.online and type(member.name)=="string" then
                Add(member,MatchingPeer(member.name))
            end
        end
    end
    -- Roster data may be missing or delayed when the map first opens.
    for _,peer in ipairs(peers) do
        if not added[Key(peer.name)] then Add({name=peer.name},peer) end
    end
    table.sort(candidates,function(a,b)
        if a.live~=b.live then return a.live end
        return Key(a.name)<Key(b.name)
    end)
    local result={}
    for i=1,math.min(#candidates,limit or 5) do result[i]=candidates[i] end
    return result
end
function Pins:GetPeer(name)
    if type(name)~="string" or not guild.Presence then return end
    local peers=guild.Presence:ActivePeers()
    for _,peer in ipairs(peers) do
        if Key(peer.name)==Key(name) then return peer end
    end
    if name:find("-",1,true) then return end
    local found
    for _,peer in ipairs(peers) do
        if Key(DisplayName(peer.name))==Key(name) then
            if found then return nil end -- never guess between same-name realms
            found=peer
        end
    end
    return found
end
function Pins:SetStatus(message)
    if self.mapStatus then self.mapStatus:SetText(message or "") end
end
function Pins:SyncSearchVisibility()
    if not self.searchPanel then return end
    local wm=_G.WorldMapFrame
    local on=not ONE.FeatureOn or ONE:FeatureOn("guild.mapSearch")
    if on and wm and wm:IsShown() then
        self.searchPanel:Show()
    else
        self.searchPanel:Hide()
        if self.searchBox then self.searchBox:ClearFocus() end
    end
end
function Pins:FocusMember(name)
    if type(InCombatLockdown)=="function" and InCombatLockdown() then
        self:SetStatus(T("Bitte nach dem Kampf erneut versuchen."))
        return false
    end
    local peer=self:GetPeer(name)
    if not peer then
        self:SetStatus("Keine aktuelle Guild-Trip-Position von "..DisplayName(name).." empfangen.")
        return false
    end
    self.selected=peer.name
    if C_Map and type(C_Map.OpenWorldMap)=="function" then
        C_Map.OpenWorldMap(peer.mapID)
    elseif type(ToggleWorldMap)=="function" and not (_G.WorldMapFrame and _G.WorldMapFrame:IsShown()) then
        ToggleWorldMap()
    end
    self:SetStatus("Position von "..DisplayName(peer.name).." hervorgehoben.")
    self:Refresh()
    if C_Timer and C_Timer.After then C_Timer.After(.15,function() self:Refresh() end) end
    return true
end
function Pins:SelectMember(name,openMap)
    if not name then return false end
    local peer=self:GetPeer(name)
    if not peer then
        self.selected=nil
        self:SetStatus(T("Mitglied online, aber noch keine Guild-Trip-Position empfangen."))
        self:RefreshSearch()
        return false
    end
    if self.searchBox then
        self.suppressTextChange=true
        self.searchBox:SetText(DisplayName(peer.name))
        self.suppressTextChange=false
        self.searchBox:ClearFocus()
    end
    self.selected=peer.name
    if openMap~=false then return self:FocusMember(peer.name) end
    self:Refresh()
    self:RefreshSearch()
    self:SetStatus(DisplayName(peer.name).." auf der Karte ausgewählt.")
    return true
end
function Pins:CreateMapSearch()
    local wm=_G.WorldMapFrame
    if not wm or self.searchPanel then return end
    -- Compact, collapsible ONE tool on the LEFT (map) side. The Blizzard
    -- quest column lives on the RIGHT and must never be covered.
    -- Haengt direkt an der Weltkarte: gleiche Ebene, gleiche Groesse (auch bei verkleinerter
    -- Karte, z. B. OpenMaps), liegt sicher ueber der Kartenflaeche (+500), aber unter
    -- Fenstern anderer Addons in hoeheren Ebenen (frueher FULLSCREEN_DIALOG).
    -- Eigener dunkler Kasten, unabhaengig vom Aussehen: im Buch-Aussehen stand sonst
    -- rote Tinte ohne Hintergrund auf der Karte (unlesbar, Meldung 14.11.).
    ONE.Widgets.forceNative=true
    local panel=CreateFrame("Frame",nil,wm)
    panel:SetSize(236,220)
    panel:SetPoint("TOPLEFT",wm,"TOPLEFT",70,-115)
    panel:SetFrameLevel(math.min(9000,(wm:GetFrameLevel() or 1)+500))
    panel:EnableMouse(true)
    if panel.SetPropagateMouseClicks then panel:SetPropagateMouseClicks(false) end
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
    local bg=panel:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints()
    if bg.SetColorTexture then bg:SetColorTexture(.05,.04,.03,.88) end
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",0,1},{"BOTTOMLEFT","BOTTOMRIGHT",0,1},{"TOPLEFT","BOTTOMLEFT",1,0},{"TOPRIGHT","BOTTOMRIGHT",1,0}}) do
        local line=panel:CreateTexture(nil,"BORDER")
        line:SetPoint(edge[1],panel,edge[1],0,0)
        line:SetPoint(edge[2],panel,edge[2],0,0)
        if edge[3]==1 then line:SetWidth(1) else line:SetHeight(1) end
        if line.SetColorTexture then line:SetColorTexture(.85,.68,.3,.8) end
    end
    self.searchPanel=panel
    -- Standard: eingeklappt (nur die Titelzeile) – die Karte bleibt frei; Wahl wird gemerkt
    local db=ONE.db and ONE.db.guild
    self.collapsed=not (db and db.mapSearchOpen==true)
    local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOPLEFT",11,-10)
    title:SetText(T("Guild Trip · Gildenkarte"))
    title:SetTextColor(1,.82,0)
    self.mapTitle=title

    local toggle=CreateFrame("Button",nil,panel)
    toggle:SetSize(25,23)
    toggle:SetPoint("TOPRIGHT",-5,-3)
    local toggleText=toggle:CreateFontString(nil,"OVERLAY","GameFontNormal")
    toggleText:SetAllPoints()
    toggleText:SetText(self.collapsed and "+" or "−")
    self.collapseButton=toggle
    self.collapseText=toggleText
    toggle:SetScript("OnClick",function()
        self.collapsed=not self.collapsed
        if ONE.db and ONE.db.guild then ONE.db.guild.mapSearchOpen=not self.collapsed end
        toggleText:SetText(self.collapsed and "+" or "−")
        self:RefreshSearch()
    end)
    -- Dragging the header does not interfere with interactive search rows.
    if panel.SetMovable and panel.RegisterForDrag then
        panel:SetMovable(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart",function(f)
            if not (InCombatLockdown and InCombatLockdown()) then f:StartMoving() end
        end)
        panel:SetScript("OnDragStop",function(f) f:StopMovingOrSizing() end)
    end

    local field=CreateFrame("Frame",nil,panel)
    field:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-38)
    field:SetSize(216,27)
    local fieldBg=field:CreateTexture(nil,"BACKGROUND")
    fieldBg:SetAllPoints()
    if fieldBg.SetColorTexture then fieldBg:SetColorTexture(1,1,1,.08) end
    local border=field:CreateTexture(nil,"ARTWORK")
    border:SetPoint("BOTTOMLEFT",field,"BOTTOMLEFT",0,0)
    border:SetPoint("BOTTOMRIGHT",field,"BOTTOMRIGHT",0,0)
    border:SetHeight(2)
    if border.SetColorTexture then border:SetColorTexture(1,.82,0,.7) end
    local input=CreateFrame("EditBox",nil,field)
    input:SetAllPoints(field)
    input:SetFrameLevel(field:GetFrameLevel()+3)
    input:EnableMouse(true)
    if GameFontHighlight and input.SetFontObject then input:SetFontObject(GameFontHighlight) end
    if input.SetTextInsets then input:SetTextInsets(8,8,0,0) end
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)
    input:SetText("")
    input:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    input:SetScript("OnEnterPressed",function(self)
        local matches=Pins:SearchMatches(self:GetText(),5)
        if matches[1] then Pins:SelectMember(matches[1].name,true) end
        self:ClearFocus()
    end)
    if input.SetTextColor then input:SetTextColor(1,1,1) end
    self.searchBox=input
    self.searchField=field
    local suggestionLabel=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    suggestionLabel:SetPoint("TOPLEFT",11,-74)
    suggestionLabel:SetText("ONLINE · SPIELER SUCHEN")
    suggestionLabel:SetTextColor(.75,.75,.75)
    self.suggestionLabel=suggestionLabel
    self.searchRows={}
    for i=1,5 do
        local row=ONE.Widgets:Button(panel,"",216,26,"TOPLEFT",10,-94-(i-1)*29,function()
            local item=self.searchRows[i]
            if item and item.name then self:SelectMember(item.name,true) end
        end,"secondary")
        self.searchRows[i]={button=row}
        row:HookScript("OnEnter",function(button)
            local item=self.searchRows[i]
            if item and item.name then
                self:ShowMemberTooltip(button,item.name,self:GetPeer(item.name))
            end
        end)
        row:HookScript("OnLeave",function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end
    local status=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    status:SetPoint("TOPLEFT",panel,"TOPLEFT",11,-108)
    status:SetWidth(214)
    status:SetJustifyH("LEFT")
    status:SetText("")
    status:SetTextColor(.75,.75,.75)
    self.mapStatus=status
    -- Optionaler Navi-Start; erscheint nur, wenn ONE_Nav installiert und aktiv ist.
    -- kleiner Navi-Pfeil (wie ueberall im Addon), Name im Tooltip
    local navButton=ONE.Widgets:NaviArrow(panel,22,"TOPLEFT",10,-130,function()
        local navModule=ONE.modules and ONE.modules.nav
        if self.selected and navModule and type(navModule.StartTo)=="function" then
            navModule:StartTo(self.selected)
        end
    end,function(btn) return btn.label end)
    navButton:Hide()
    self.navButton=navButton
    ONE.Widgets.forceNative=false
    input:SetScript("OnTextChanged",function()
        if self.suppressTextChange then return end
        -- Writing a new query is not an explicit destination choice.
        self.selected=nil
        self:RefreshSearch()
    end)
    self:SyncSearchVisibility()
    self:RefreshSearch()
end
function Pins:RefreshSearch()
    if not self.searchRows then return end
    local isCollapsed=self.collapsed
    local liveCount=guild.Presence and #guild.Presence:ActivePeers() or 0
    if self.mapTitle then self.mapTitle:SetText(T("Guild Trip · Gildenkarte (%d)", liveCount)) end
    self.searchField:SetShown(not isCollapsed)
    self.suggestionLabel:SetShown(not isCollapsed)
    local query=self.searchBox and self.searchBox:GetText() or ""
    local members=self:SearchMatches(query,5)
    local shown=isCollapsed and 0 or #members
    for i,item in ipairs(self.searchRows) do
        local member=members[i]
        item.name=member and member.name or nil
        if member and not isCollapsed then
            item.button:SetText(DisplayName(member.name)..(member.live and " · LIVE" or " · online"))
            item.button:Show()
        else item.button:Hide() end
    end
    if self.mapStatus then
        self.mapStatus:SetShown(not isCollapsed)
        self.mapStatus:ClearAllPoints()
        self.mapStatus:SetPoint("TOPLEFT",self.searchPanel,"TOPLEFT",11,-103-shown*29)
    end
    local navModule=ONE.modules and ONE.modules.nav
    local selectedPeer=self.selected and self:GetPeer(self.selected)
    local canNavigate=not isCollapsed and selectedPeer~=nil and navModule~=nil
        and type(navModule.StartTo)=="function" and ONE:IsEnabled("nav")
    if self.navButton then
        if canNavigate then
            self.navButton.label=T("Navi zu %s", DisplayName(selectedPeer.name))
            self.navButton:ClearAllPoints()
            self.navButton:SetPoint("TOPLEFT",self.searchPanel,"TOPLEFT",10,-124-shown*29)
            self.navButton:Show()
        else
            self.navButton:Hide()
        end
    end
    if self.searchPanel then
        self.searchPanel:SetHeight(isCollapsed and 31 or (133+shown*29+(canNavigate and 32 or 0)))
    end
    if not isCollapsed and self.searchPanel and self.searchPanel:IsShown() and #members==0 then
        self:SetStatus(T("Keine passenden Online-Spieler."))
    end
end
function Pins:Initialize()
    self:Attach()
    local rosterEvents=CreateFrame("Frame")
    rosterEvents:RegisterEvent("GUILD_ROSTER_UPDATE")
    rosterEvents:SetScript("OnEvent",function()
        if self.searchPanel and self.searchPanel:IsShown() then self:RefreshSearch() end
    end)
    if C_Timer and type(C_Timer.NewTicker)=="function" then
        C_Timer.NewTicker(3,function()
            self:Attach()
            if _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then self:Refresh() end
        end)
    end
end
function Pins:OpenMap()
    if type(InCombatLockdown)=="function" and InCombatLockdown() then
        ONE:Print(T("Die Weltkarte bitte nach dem Kampf öffnen."))
        return
    end
    if C_Map and type(C_Map.OpenWorldMap)=="function" then
        C_Map.OpenWorldMap()
    elseif type(ToggleWorldMap)=="function" then
        ToggleWorldMap()
    else
        ONE:Print(T("Öffne die Weltkarte mit M."))
    end
    self:Refresh()
end
