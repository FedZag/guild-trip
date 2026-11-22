-- Offline-Test: kein Addon ueberschreibt eine globale Tabelle eines anderen (Spieltest 22.11.2026: die festen
-- Quest-Routen hiessen wie das Wegenetz "GuildTripRoutes" – das Navi verlor sein Netz, keine Fussspuren mehr).
local root = arg[1] or "src"
local owner, clash = {}, {}
local p = assert(io.popen('find "' .. root .. '" -name "*.lua"'))
for path in p:lines() do
    local addon = path:sub(#root + 2):match("^([^/]+)/")
    local f = assert(io.open(path))
    for line in f:lines() do
        local name = line:match("^([%a_][%w_]*)%s*=[^=]")
        if name and name ~= "local" then
            local o = owner[name]
            if o and o ~= addon then clash[#clash + 1] = name .. " (" .. o .. " / " .. addon .. ")" end
            owner[name] = owner[name] or addon
        end
    end
    f:close()
end
p:close()
assert(owner.GuildTripRoutes == "ONE_Routes", "Wegenetz-Tabelle gehoert ONE_Routes")
assert(owner.GuildTripQuestRoutes == "ONE_Leveling", "Quest-Routen-Tabelle gehoert ONE_Leveling")
assert(#clash == 0, "gleiche globale Namen in zwei Addons: " .. table.concat(clash, ", "))
print("OK test_globals_148")
