-- Syntax-check only files actually loaded by Project ONE's .toc files.
local root=arg[1] or 'src'
local checked=0
for _,addon in ipairs({'ONE_Core','ONE_Guild','ONE_Nav','ONE_Dungeons','ONE_Crafting','ONE_Chat','ONE_QuestDB','ONE_Routes','ONE_Leveling'}) do
    local toc=assert(io.open(root..'/'..addon..'/'..addon..'.toc','r'))
    for line in toc:lines() do
        local name=line:match('^%s*([^#%s][^\r\n]-%.lua)%s*$')
        if name then
            local path=root..'/'..addon..'/'..name
            local code,err=loadfile(path)
            assert(code,'Syntaxfehler in '..path..': '..tostring(err))
            checked=checked+1
        end
    end
    toc:close()
end
assert(checked>15,'Unerwartet wenige Lua-Dateien geprüft: '..checked)
print('OK: '..checked..' Lua-Dateien gemäß TOCs geprüft')
