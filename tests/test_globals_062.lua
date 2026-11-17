-- Offline-Test: Keine versehentlich globalen Namen (z. B. eine lokale Variable,
-- die benutzt wird, bevor sie angelegt ist – so landete ein Haekchen ohne
-- Fenster am Bildschirmrand). Liest den Bytecode ueber luac5.1 -l; ohne luac
-- wird der Test uebersprungen.
local root = arg[1] or "src"
local probe = io.popen("command -v luac5.1 2>/dev/null")
local luac = probe and probe:read("*l")
if probe then probe:close() end
if not luac or luac == "" then print("OK test_globals_062 (luac5.1 fehlt – uebersprungen)") return end

-- Kleingeschriebene Globale, die es wirklich gibt (Lua und WoW)
local allowed = {}
for name in ([[assert error ipairs pairs next pcall select setmetatable getmetatable rawget rawset tonumber tostring
    type unpack print string table math os date time io loadfile issecretvalue geterrorhandler seterrorhandler
    debugstack strsplit strtrim wipe tinsert tremove format floor hooksecurefunc _G]]):gmatch("%S+") do allowed[name] = true end

local list = io.popen("find " .. root .. " -name '*.lua' -not -path '*/ONE_Guild/Navigation.lua' -not -path '*/ONE_Guild/RouteGraph.lua' -not -path '*/ONE_Guild/FlightPoints.lua'")
local bad = {}
for file in list:lines() do
    local out = io.popen(luac .. " -p -l '" .. file .. "' 2>&1")
    for line in out:lines() do
        local name = line:match("[GS]ETGLOBAL%s+%S+%s+%S+%s*;%s*([%w_]+)")
        if name and name:match("^%l") and not allowed[name] then
            bad[#bad + 1] = file .. ": " .. name .. "  (" .. (line:match("%[(%d+)%]") or "?") .. ")"
        end
    end
    out:close()
end
list:close()
assert(#bad == 0, "versehentlich globale Namen:\n" .. table.concat(bad, "\n"))
print("OK test_globals_062")
