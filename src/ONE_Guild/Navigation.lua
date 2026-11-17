-- Project ONE: own live compass + respectful updating of an explicitly selected
-- guild member's native waypoint. No TomTom/Shortest Path dependency.
-- A compass bearing is NOT a verified road/flight/continent route.
local _, guild = ...
local ONE = _G.ProjectONE
local Nav = {active=false,waypointEvery=4,compassEvery=.12}
guild.Navigation=Nav
local TAU=math.pi*2

local function Clock() return type(GetTime)=='function' and GetTime() or 0 end
local function ShortName(name) return (name or ''):match('^[^-]+') or (name or '') end
local function Atan2(y,x)
    if math.atan2 then return math.atan2(y,x) end
    if x==0 then return y>=0 and math.pi/2 or -math.pi/2 end
    local a=math.atan(y/x)
    if x<0 then a=a+(y>=0 and math.pi or -math.pi) end
    return a
end
local function WorldPoint(mapID,x,y)
    if not (C_Map and type(C_Map.GetWorldPosFromMapPos)=='function') then return end
    local ok,instance,pos=pcall(C_Map.GetWorldPosFromMapPos,mapID,{x=x,y=y})
    if ok and type(instance)=='number' and pos and
       type(pos.x)=='number' and type(pos.y)=='number' then
        return instance,pos.x,pos.y
    end
end
local function PlayerPosition()
    if not (C_Map and type(C_Map.GetBestMapForUnit)=='function' and
        type(C_Map.GetPlayerMapPosition)=='function') then return end
    local ok,id=pcall(C_Map.GetBestMapForUnit,'player')
    if not ok or not id then return end
    local good,p=pcall(C_Map.GetPlayerMapPosition,id,'player')
    if not good or not p then return end
    local x,y
    if type(p.GetXY)=='function' then
        local success,a,b=pcall(p.GetXY,p)
        if success then x,y=a,b end
    else x,y=p.x,p.y end
    if type(x)=='number' and type(y)=='number' then return id,x,y end
end
function Nav:GetLivePeer()
    return self.target and guild.Pins and guild.Pins:GetPeer(self.target)
end
function Nav:CreateCompass()
    if self.frame then return end
    local frame=CreateFrame('Frame','ProjectONENavigationCompass',UIParent)
    frame:SetSize(244,75)
    frame:SetPoint('TOP',UIParent,'TOP',0,-175)
    frame:SetFrameStrata('FULLSCREEN_DIALOG')
    frame:SetFrameLevel(2000)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart',function(f) if not (InCombatLockdown and InCombatLockdown()) then f:StartMoving() end end)
    frame:SetScript('OnDragStop',function(f) f:StopMovingOrSizing() end)
    local bg=frame:CreateTexture(nil,'BACKGROUND')
    bg:SetAllPoints()
    bg:SetColorTexture(.045,.085,.14,.91)
    local rim=frame:CreateTexture(nil,'BORDER')
    rim:SetColorTexture(.1,.7,.96,.8)
    rim:SetPoint('BOTTOMLEFT',0,0)
    rim:SetPoint('BOTTOMRIGHT',0,0)
    rim:SetHeight(2)
    local icon=frame:CreateTexture(nil,'ARTWORK')
    icon:SetSize(52,52)
    icon:SetPoint('LEFT',frame,'LEFT',10,0)
    icon:SetTexture('Interface\\AddOns\\ONE_Guild\\Textures\\CompassArrow.tga')
    self.arrow=icon
    local title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal')
    title:SetPoint('TOPLEFT',65,-10)
    title:SetWidth(155)
    title:SetJustifyH('LEFT')
    self.title=title
    local status=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    status:SetPoint('TOPLEFT',65,-33)
    status:SetWidth(165)
    status:SetJustifyH('LEFT')
    self.status=status
    local close=CreateFrame('Button',nil,frame)
    close:SetSize(19,19)
    close:SetPoint('TOPRIGHT',-2,-2)
    local cross=close:CreateFontString(nil,'OVERLAY','GameFontNormal')
    cross:SetAllPoints()
    cross:SetText('×')
    close:SetScript('OnClick',function() self:Stop() end)
    close:EnableMouse(true)
    frame:Hide()
    self.frame=frame
    self.elapsed=0
    self.frame:SetScript('OnUpdate',function(_,elapsed)
        self.elapsed=self.elapsed+(elapsed or 0)
        if self.elapsed<self.compassEvery then return end
        self.elapsed=0
        self:Tick()
    end)
end
function Nav:Start(name)
    if not guild.Pins or not guild.Pins:GetPeer(name) then return false end
    self:CreateCompass()
    self.target=name
    self.active=true
    self.lastWaypoint=nil
    self.lastWayTime=0
    self.lastWayTarget=nil
    self.lastAttempt=nil
    self.title:SetText('Zu '..ShortName(name))
    self.status:SetText('Richtung wird ermittelt ...')
    self.frame:Show()
    self:Tick(true)
    return true
end
function Nav:Stop()
    self.active=false
    self.target=nil
    self.lastWaypoint=nil
    self.lastWayTarget=nil
    if self.frame then self.frame:Hide() end
    -- Intentionally leave the game's user waypoint alone. It may have been
    -- replaced by the user or another addon; clearing would be intrusive.
    if guild.Pins then
        guild.Pins:SetStatus('ONE-Navigation beendet. Letzter Wegpunkt bleibt bestehen.')
        guild.Pins:RefreshSearch()
    end
end
local function SamePoint(a,b)
    return a and b and a.map==b.map and
        math.abs(a.x-b.x)<.0002 and math.abs(a.y-b.y)<.0002
end
function Nav:WaypointOwned()
    if not self.lastWaypoint or not C_Map or
        type(C_Map.GetUserWaypoint)~='function' then return true end
    local ok,point=pcall(C_Map.GetUserWaypoint)
    if not ok or not point then return true end -- client may not expose this
    local pos=point.position or point
    local map=point.uiMapID or point.mapID
    if map and pos and type(pos.x)=='number' and type(pos.y)=='number' then
        return SamePoint(self.lastWaypoint,{map=map,x=pos.x,y=pos.y})
    end
    return true
end
function Nav:UpdateWaypoint(peer)
    if not (C_Map and type(C_Map.SetUserWaypoint)=='function' and
        UiMapPoint and type(UiMapPoint.CreateFromCoordinates)=='function') then return end
    local nextPoint={map=peer.mapID,x=peer.x,y=peer.y}
    if SamePoint(nextPoint,self.lastWayTarget) then return end
    local now=Clock()
    if type(InCombatLockdown)=='function' and InCombatLockdown() then return end
    -- Also throttle FAILED placement attempts: restricted clients must not
    -- receive a protected API call on every compass render tick.
    if self.lastAttempt and now-self.lastAttempt<self.waypointEvery then return end
    self.lastAttempt=now
    if not self:WaypointOwned() then
        self:Stop()
        if guild.Pins then guild.Pins:SetStatus('Manueller Wegpunkt erkannt: ONE-Navigation gestoppt.') end
        return
    end
    if type(C_Map.CanSetUserWaypointOnMap)=='function' then
        local ok,can=pcall(C_Map.CanSetUserWaypointOnMap,peer.mapID)
        if not ok or can==false then return end
    end
    local ok,point=pcall(UiMapPoint.CreateFromCoordinates,peer.mapID,peer.x,peer.y)
    if not ok or not point then return end
    local accepted,set=pcall(C_Map.SetUserWaypoint,point)
    if not accepted or set==false then return end
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint)=='function' then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true)
    end
    self.lastWaypoint=nextPoint
    self.lastWayTarget=nextPoint
    self.lastWayTime=now
end
function Nav:Tick(force)
    if not self.active then return end
    local peer=self:GetLivePeer()
    if not peer then
        self.arrow:Hide()
        self.status:SetText('Keine aktuelle Guild-Trip-Position')
        return
    end
    local playerMap,px,py=PlayerPosition()
    if not playerMap then
        self.arrow:Hide()
        self.status:SetText('Eigener Standort nicht verfügbar')
        return
    end
    local fromID,fromX,fromY=WorldPoint(playerMap,px,py)
    local toID,toX,toY=WorldPoint(peer.mapID,peer.x,peer.y)
    local facing
    if type(GetPlayerFacing)=='function' then
        local ok,angle=pcall(GetPlayerFacing)
        if ok and type(angle)=='number' then facing=angle end
    end
    if fromID and toID and fromID==toID and facing then
        local dx,dy=toX-fromX,toY-fromY
        local distance=math.sqrt(dx*dx+dy*dy)
        local angle=Atan2(dy,dx)-facing
        if type(self.arrow.SetRotation)=='function' then self.arrow:SetRotation(angle) end
        self.arrow:Show()
        self.status:SetText(string.format('Luftlinie: ca. %.0f m · keine Straßenroute',distance*.9144))
    elseif fromID and toID and fromID~=toID then
        self.arrow:Hide()
        self.status:SetText('Anderer Kontinent – Route fehlt')
    else
        self.arrow:Hide()
        self.status:SetText('Richtung hier nicht verfügbar')
    end
    self:UpdateWaypoint(peer)
end
