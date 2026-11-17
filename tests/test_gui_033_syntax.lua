local root=arg[0]:match('^(.*)/tests/test_gui_033_syntax.lua$') or '.'
local p=io.popen('find "'..root..'/src" -type f -name "*.lua"')
local count=0
for f in p:lines() do
    local fn,err=loadfile(f)
    assert(fn,err)
    count=count+1
end
p:close()
assert(count>=10,'Zu wenige Lua-Dateien')
print('OK: Lua-Syntax ('..count..' Dateien)')
