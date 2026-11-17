local _, ONE = ...

-- Project ONE: proportional scaling of the ONE main window.
-- Internal layout remains 774x548 (0.4.4 nativer Blizzard-Rahmen): no stretching.
-- Positions are offsets from UIParent's CENTER, measured in UIParent units.
local WindowScale = {WIDTH=774, HEIGHT=548, MARGIN=18, MIN=.70, MAX=1.25}
ONE.WindowScale = WindowScale

local function Finite(v)
    return type(v)=="number" and v==v and v > -math.huge and v < math.huge
end
local function Clamp(v,a,b)
    return math.max(a,math.min(b,v))
end
function WindowScale:ScreenSize()
    local w=UIParent and UIParent.GetWidth and UIParent:GetWidth() or nil
    local h=UIParent and UIParent.GetHeight and UIParent:GetHeight() or nil
    if not Finite(w) or w<=0 then w=1920 end
    if not Finite(h) or h<=0 then h=1080 end
    return w,h
end
function WindowScale:Bounds(w,h)
    -- Explicit size arguments allow client-independent geometry tests.
    if not Finite(w) or not Finite(h) then w,h=self:ScreenSize() end
    local maxFit=math.min(self.MAX,(w-2*self.MARGIN)/self.WIDTH,
        (h-2*self.MARGIN)/self.HEIGHT)
    -- Extremely tiny UI areas cannot fully contain the window; avoid negative scaling.
    local maximum=math.max(.25,maxFit)
    local minimum=math.min(self.MIN,maximum)
    return minimum,maximum
end
function WindowScale:ClampState(scale,x,y,w,h)
    if not Finite(w) or not Finite(h) then w,h=self:ScreenSize() end
    local minScale,maxScale=self:Bounds(w,h)
    scale=Clamp(Finite(scale) and scale or 1,minScale,maxScale)
    x=Finite(x) and x or 0
    y=Finite(y) and y or 0
    local halfW=self.WIDTH*scale/2
    local halfH=self.HEIGHT*scale/2
    local rangeX=math.max(0,w/2-self.MARGIN-halfW)
    local rangeY=math.max(0,h/2-self.MARGIN-halfH)
    return scale,Clamp(x,-rangeX,rangeX),Clamp(y,-rangeY,rangeY)
end
function WindowScale:Read()
    local saved=ONE.db and ONE.db.window or {}
    return self:ClampState(saved.scale,saved.x,saved.y)
end
function WindowScale:Apply(scale,x,y,save)
    scale,x,y=self:ClampState(scale,x,y)
    if self.frame then
        self.frame:SetScale(scale)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER",UIParent,"CENTER",x,y)
    end
    self.scale,self.x,self.y=scale,x,y
    if save and ONE.db then
        ONE.db.window=ONE.db.window or {}
        ONE.db.window.scale=scale
        ONE.db.window.x=x
        ONE.db.window.y=y
    end
    self:SyncControls()
    return scale,x,y
end
function WindowScale:IsCombatLocked()
    return InCombatLockdown and InCombatLockdown() or false
end
function WindowScale:SetUserScale(requested)
    if self:IsCombatLocked() then
        self:SyncControls()
        return false
    end
    requested=math.floor((tonumber(requested) or 1)*20+.5)/20 -- 5%-steps
    self:Apply(requested,self.x,self.y,true)
    return true
end
function WindowScale:Reset()
    if self:IsCombatLocked() then return false end
    self:Apply(1,0,0,true)
    return true
end
function WindowScale:SyncControls()
    if self.valueText then self.valueText:SetText(string.format("%d %%",math.floor((self.scale or 1)*100+.5))) end
    if self.slider then
        local minimum,maximum=self:Bounds()
        self.syncing=true
        self.slider:SetMinMaxValues(minimum,maximum)
        self.slider:SetValue(self.scale or 1)
        self.syncing=false
    end
end
function WindowScale:AttachControls(slider,valueText)
    self.slider,self.valueText=slider,valueText
    slider:SetScript("OnValueChanged",function(_,value)
        if not self.syncing then self:SetUserScale(value) end
    end)
    self:SyncControls()
end

-- GetCenter returns frame-local units. Convert to UIParent units using the
-- effective-scale ratio. This also works when the global WoW UI scale changes.
function WindowScale:SavePosition(frame)
    if self:IsCombatLocked() then return false end
    if not frame or not frame.GetCenter or not frame.GetEffectiveScale then return false end
    local cx,cy=frame:GetCenter()
    local effective=frame:GetEffectiveScale()
    local parentEffective=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local w,h=self:ScreenSize()
    if not (Finite(cx) and Finite(cy) and Finite(effective)
        and Finite(parentEffective) and parentEffective>0) then return false end
    local x=cx*effective/parentEffective-w/2
    local y=cy*effective/parentEffective-h/2
    self:Apply(self.scale,x,y,true)
    return true
end
local function MousePosition()
    if not GetCursorPosition then return nil,nil end
    local x,y=GetCursorPosition()
    local s=UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not Finite(s) or s<=0 then s=1 end
    if Finite(x) and Finite(y) then return x/s,y/s end
    return nil,nil
end
function WindowScale:StartResize()
    if self:IsCombatLocked() then return false end
    local mx,my=MousePosition()
    if not mx then return false end
    self.drag={mouseX=mx,mouseY=my,scale=self.scale,
        left=self.x-self.WIDTH*self.scale/2,
        top=self.y+self.HEIGHT*self.scale/2}
    return true
end
function WindowScale:UpdateResize()
    local d=self.drag
    if not d then return end
    if self:IsCombatLocked() then self:StopResize(); return end
    local mx,my=MousePosition()
    if not mx then return end
    local dx=(mx-d.mouseX)/self.WIDTH
    local dy=(d.mouseY-my)/self.HEIGHT
    -- Take the dominant axis: horizontal and vertical corner drags feel natural.
    local delta=math.abs(dx)>math.abs(dy) and dx or dy
    local nextScale=math.floor((d.scale+delta)*100+.5)/100
    local minScale,maxScale=self:Bounds()
    nextScale=Clamp(nextScale,minScale,maxScale)
    if math.abs(nextScale-(self.scale or 0))<.009 then return end
    local x=d.left+self.WIDTH*nextScale/2
    local y=d.top-self.HEIGHT*nextScale/2
    self:Apply(nextScale,x,y,false)
end
function WindowScale:StopResize()
    if not self.drag then return end
    self:UpdateResizeFinal()
    self.drag=nil
    self:Apply(self.scale,self.x,self.y,true)
end
function WindowScale:UpdateResizeFinal()
    -- Explicit method for tests; UpdateResize doesn't write saved variables.
    self:UpdateResize()
end
function WindowScale:Initialize(frame)
    self.frame=frame
    local scale,x,y=self:Read()
    self:Apply(scale,x,y,true)
    local grip=CreateFrame("Button",nil,frame)
    grip:SetSize(26,26)
    grip:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-6,6)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    -- Three small steps form a corner grip without font-dependent glyphs.
    for i=1,3 do
        local seg=grip:CreateTexture(nil,"OVERLAY")
        seg:SetPoint("BOTTOMRIGHT",grip,"BOTTOMRIGHT",-2,-2+(i-1)*6)
        seg:SetSize(4+i*5,2)
        ONE.Themes:RegisterRule(seg,"accent")
    end
    grip:SetScript("OnDragStart",function(self)
        if WindowScale:StartResize() then
            self:SetScript("OnUpdate",function() WindowScale:UpdateResize() end)
        end
    end)
    grip:SetScript("OnDragStop",function(self)
        self:SetScript("OnUpdate",nil)
        WindowScale:StopResize()
    end)
    grip:SetScript("OnHide",function(self)
        self:SetScript("OnUpdate",nil)
        WindowScale:StopResize()
    end)
    frame:HookScript("OnHide",function() WindowScale:StopResize() end)
    self.grip=grip
    local watcher=CreateFrame("Frame")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:SetScript("OnEvent",function()
        if WindowScale.drag then WindowScale:StopResize() end
        -- Restore saved center and clamp after display-scale/resolution changes.
        WindowScale:Apply(WindowScale.scale,WindowScale.x,WindowScale.y,true)
    end)
    self.watcher=watcher
end
