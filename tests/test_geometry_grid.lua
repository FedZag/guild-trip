-- Rein geometrische Regressionstests. Kein laufender WoW-Client erforderlich.
local root=(arg[0]:match('^(.*)/tests/') or '.')
local ONE={}
assert(loadfile(root..'/src/ONE_Core/Geometry.lua'))('ONE_Core',ONE)
local G=ONE.Geometry
local W=G.tokens.contentWidth
assert(W==726)

local cols=G:Columns(W,{1,1})
assert(#cols==2 and cols[1].x==0 and cols[1].width==355)
assert(cols[2].x==371 and cols[2].width==355)
assert(cols[2].x+cols[2].width==W)

for _,col in ipairs(cols) do
    local actions=G:Actions(col,{1,1})
    assert(#actions==2)
    assert(G:AssertAligned(col,actions))
    assert(actions[2].x == actions[1].x+actions[1].width+G.tokens.actionGap)
    assert(actions[2].x+actions[2].width == col.x+col.width-G.tokens.panelStrokeInset)
end

local footer={x=0,width=W}
local row=G:Actions(footer,{2,1,1})
assert(#row==3 and G:AssertAligned(footer,row))
assert(row[2].x == row[1].x+row[1].width+G.tokens.actionGap)
assert(row[3].x == row[2].x+row[2].width+G.tokens.actionGap)

for _,h in ipairs({166,190}) do
    local y=G:BottomActionY(h)
    assert(-y+G.tokens.buttonHeight+G.tokens.cardBottomPadding==h)
end

-- Negative Testfälle muessen scheitern. Ein zu breiter Button wird erkannt.
local bad=G:Actions(cols[1],{1,1})
bad[2].width=bad[2].width+1
local ok=pcall(function() G:AssertAligned(cols[1],bad) end)
assert(not ok,'Ueberstand darf nie unbemerkt bleiben')

local tooWide=pcall(function() G:Columns(20,{1,1,1},16) end)
assert(not tooWide,'Unmoegliches Raster muss Fehler werfen')

print('OK: gemeinsame Spalten, visuelle Aussenkanten, Buttonreihen, Abstaende, Fehlererkennung')
