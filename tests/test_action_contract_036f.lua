-- Layoutvertrag: semantische Aktionsgroessen, Bezugskanten und Negativfaelle.
-- Kann ohne WoW-Client ausgefuehrt werden.
local root=(arg[0]:match('^(.*)/tests/') or '.')
local ONE={}
assert(loadfile(root..'/src/ONE_Core/Geometry.lua'))('ONE_Core',ONE)
local G=ONE.Geometry
local function equal(a,b,msg) assert(a==b,(msg or 'Mismatch')..' '..tostring(a)..' / '..tostring(b)) end
local card={x=24,y=-140,width=300}
local a=G:ActionRect(card,'primary','left')
equal(a.x,24);equal(a.y,-140);equal(a.width,248);equal(a.height,34)
assert(G:AssertActionInside(card,a))
local b=G:ActionRect(card,'card','right')
equal(b.x,24+300-176);equal(b.width,176)
local c=G:ActionRect(card,'toolbar','center')
equal(c.x,24+(300-184)/2)
local d=G:ActionRect(card,'fill','left')
equal(d.x,24);equal(d.width,300)
local narrow={x=5,y=-90,width=120}
local n=G:ActionRect(narrow,'primary','left')
equal(n.width,120)
local full=G:ActionRect({x=371,y=-281,width=320},'fill','right')
equal(full.x,371);equal(full.width,320)
local calendar=G:ActionRect({x=8,y=-353,width=710},'toolbar','right')
equal(calendar.x,534);equal(calendar.x+calendar.width,718)
local safe,err=pcall(function()G:AssertActionInside(card,{x=card.x-1,width=220,height=34})end)
assert(not safe and err:find('links'),'Links ueberstehender Button nicht erkannt')
safe,err=pcall(function()G:AssertActionInside(card,{x=card.x+200,width=200,height=34})end)
assert(not safe and err:find('rechts'),'Rechts ueberstehender Button nicht erkannt')
safe=pcall(function()G:ActionRect({x=0,y=0,width=300},'bogus','left')end)
assert(not safe,'Unbekanntes Layoutprofil akzeptiert')
safe=pcall(function()G:ActionRect({x=0,y=0,width=300},'card','bottom')end)
assert(not safe,'Unbekannte Ausrichtung akzeptiert')

-- Realistische Widget-Positionierung im minimalen Frame-Mock.
local made={}
function CreateFrame(kind,_,parent)
    local f={kind=kind,parent=parent}
    function f:SetSize(w,h) self.w=w;self.h=h end
    function f:SetPoint(...) self.point={...} end
    function f:SetJustifyH(j) self.j=j end
    function f:SetJustifyV(j) self.v=j end
    function f:SetWordWrap() end
    function f:SetFontString(s) self.font=s end
    function f:SetText(s) self.text=s end
    function f:SetScript(k,fun) self[k]=fun end
    function f:CreateFontString()
        local label={}
        function label:SetPoint() end
        function label:SetJustifyH() end
        function label:SetJustifyV() end
        function label:SetWordWrap() end
        return label
    end
    made[#made+1]=f
    return f
end
assert(loadfile(root..'/src/ONE_Core/Widgets.lua'))('ONE_Core',ONE)
local parent={}
local calls=0
local btn=ONE.Widgets:ActionButton(parent,'Benachrichtigung testen',
    {x=0,y=-274,width=300},function() calls=calls+1 end,'secondary','fill')
assert(btn.w==300 and btn.h==34 and btn.point[4]==0 and btn.point[5]==-274)
assert(btn.__oneActionLayout.profile=='fill')
btn.OnClick();equal(calls,1)
print('OK: Aktionsprofile, buendige Kanten, Ueberstand-Erkennung, gemeinsames Widget')
