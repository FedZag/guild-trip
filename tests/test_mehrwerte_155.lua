-- Waechter (22.11.2026): "local a, b = x and f()" liefert nur EINEN Wert ('and'/'or' kuerzt auf den ersten).
-- Spieltest: Navi zum Questgeber (Way.lua) bekam nur die Karte ohne x/y, der Pfeil blieb beim alten Ziel.
local root = arg[1] or "src"
local function Files()
    local p = io.popen('find "' .. root .. '" -name "*.lua"')
    local out = {}
    for f in p:lines() do out[#out + 1] = f end
    p:close()
    return out
end
local bad = {}
for _, file in ipairs(Files()) do
    local n = 0
    for line in io.lines(file) do
        n = n + 1
        local lhs, rhs = line:match("^%s*local%s+([%w_]+%s*,%s*[%w_,%s]+)=%s*(.+)$")
        -- Kommas in Klammern zaehlen nicht (Argumente)
        local top = rhs and rhs:gsub("%b()", "()"):gsub("%b{}", "{}")
        if lhs and not top:find(",", 1, true) and not rhs:find("^pcall") and not rhs:find("function", 1, true) then
            -- rechte Seite: ... and/or Aufruf(...) am Ende
            if rhs:match("%f[%w]and%f[%W]%s+[%w_.:]+%b()%s*$") or rhs:match("%f[%w]or%f[%W]%s+[%w_.:]+%b()%s*$") then
                bad[#bad + 1] = file .. ":" .. n .. ": " .. line
            end
        end
    end
end
assert(#bad == 0, "mehrere Werte mit and/or gekuerzt:\n" .. table.concat(bad, "\n"))
print("OK test_mehrwerte_155")
