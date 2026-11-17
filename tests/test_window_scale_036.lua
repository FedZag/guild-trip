-- Pure geometry + mocked interaction tests for the 0.3.6a WindowScale controller.
local path=arg[0]:match("^(.*)/tests/test_window_scale_036.lua$") or "."
local ONE={db={window={scale=1,x=0,y=0}}}
UIParent={GetWidth=function() return 1440 end,GetHeight=function() return 900 end,
    GetEffectiveScale=function() return .8 end}
local xmouse,ymouse=0,0
GetCursorPosition=function() return xmouse,ymouse end
InCombatLockdown=function() return false end
assert(loadfile(path.."/src/ONE_Core/WindowScale.lua"))("ONE_Core",ONE)
local S=ONE.WindowScale
S.WIDTH,S.HEIGHT=1010,670 -- Rechenbeispiele stammen aus 0.3.6; die Formeln sind groessenunabhaengig
local function Close(a,b) return math.abs(a-b)<.011 end
local mn,mx=S:Bounds(1440,900)
assert(Close(mn,.7) and Close(mx,1.25))
local a,b,c=S:ClampState(1.7,999,-999,1440,900)
assert(Close(a,1.25) and Close(b,70.75) and Close(c,-13.25))
a,b,c=S:ClampState(0.4,0,0,1440,900)
assert(Close(a,.70) and b==0 and c==0)
local tinyMin,tinyMax=S:Bounds(740,510)
assert(tinyMin==tinyMax and tinyMax<.70)
local sc,x,y=S:ClampState(1,10000,10000,740,510)
assert(Close(sc,tinyMax) and x==0 and y>=0 and y<4)
-- Saved variables cannot force NaN, infinity or off-screen window placement.
ONE.db.window={scale=0/0,x=math.huge,y=-math.huge}
a,b,c=S:Read()
assert(Close(a,1) and b==0 and c==0)
local frame={}
function frame:SetScale(s) self.scale=s end
function frame:ClearAllPoints() self.anchor=nil end
function frame:SetPoint(...) self.anchor={...} end
S.frame=frame
S:Apply(1,0,0,true)
assert(ONE.db.window.scale==1 and frame.scale==1)
assert(frame.anchor[1]=="CENTER" and frame.anchor[2]==UIParent)
assert(S:SetUserScale(1.16) and Close(S.scale,1.15))
assert(Close(ONE.db.window.scale,1.15))
assert(S:Reset() and Close(S.scale,1) and S.x==0 and S.y==0)
-- Corner drag: left/top boundary stays fixed until clamping is required.
xmouse,ymouse=400,500
assert(S:StartResize())
local left=S.drag.left
local top=S.drag.top
xmouse=480 -- grow by 80/1010
S:UpdateResize()
assert(S.scale>1)
assert(Close(S.x-S.WIDTH*S.scale/2,left))
assert(Close(S.y+S.HEIGHT*S.scale/2,top))
assert(ONE.db.window.scale==1,"Drag must not persist every frame")
S:StopResize()
assert(ONE.db.window.scale==S.scale and S.drag==nil)
-- Independently restore size and center after saved settings change.
S:Apply(1.05,40,-30,true)
assert(Close(S.scale,1.05) and S.x==40 and S.y==-30)
assert(S:Read()==S.scale)
-- Resizing must not touch the underlying calendar/guild state.
ONE.db.guild={noticeHistory={"marker"}}
S:SetUserScale(.85)
assert(ONE.db.guild.noticeHistory[1]=="marker")
-- Locked combat blocks both explicit resize actions and resets.
InCombatLockdown=function() return true end
local previous=S.scale
assert(S:SetUserScale(1.2)==false and S.scale==previous)
assert(S:Reset()==false and S.scale==previous)
assert(S:StartResize()==false)
InCombatLockdown=function() return false end
-- Position saved after normal window drag (frame GetCenter uses its own scale).
S:Apply(1,0,0,true)
frame.GetEffectiveScale=function() return .8 end
frame.GetCenter=function() return 720+130,450-45 end
assert(S:SavePosition(frame))
assert(Close(S.x,130) and Close(S.y,-45))
print("OK: bounds, screen clamping, persisted scale/position, corner drag, combat and reset")
