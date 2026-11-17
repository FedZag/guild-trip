local root=arg[0]:match('^(.*)/tests/') or '.'
local folders={'ONE_Core','ONE_Guild'}
local checked=0
for _,folder in ipairs(folders) do
    local toc=assert(io.open(root..'/src/'..folder..'/'..folder..'.toc','r'))
    for line in toc:lines() do
        local file=line:match('^%s*([%w_]+%.lua)%s*$')
        if file then
            local path=root..'/src/'..folder..'/'..file
            local chunk,err=loadfile(path)
            assert(chunk,err)
            checked=checked+1
        end
    end
    toc:close()
end
assert(checked>15,'Unerwartet wenige Lua-Dateien')
print('OK: '..checked..' Lua-Dateien in Forever-Ladereihenfolge syntaxgeprüft')
