-- Offline-Test 0.7.2: Im Glas-Aussehen hat KEIN eigenes Fenster einen Blizzard-Holzrahmen
-- (Nutzer 19.11.2026: "Glas fertig machen"). Jede Stelle, die ein Blizzard-Fensterrahmen-Template
-- (BasicFrameTemplateWithInset, PortraitFrameTemplate, ButtonFrameTemplate) anlegt, muss im Glas-Aussehen
-- uebersprungen werden – erkennbar an einer Glas-Bedingung in derselben oder den 3 Zeilen davor.
local root = arg[1] or "src"
local TEMPLATES = {"BasicFrameTemplateWithInset", "PortraitFrameTemplate", "ButtonFrameTemplate\""}
-- alte, nicht mehr geladene Dateien und Entwickler-Werkzeuge ausgenommen
local SKIP = {["ONE_Dev"] = true, ["ONE_Guild/Navigation.lua"] = true, ["ONE_Guild/RouteGraph.lua"] = true,
    ["ONE_Guild/FlightPoints.lua"] = true}

local p = io.popen('find "' .. root .. '" -name "*.lua" | sort')
local files = {}
for line in p:lines() do files[#files + 1] = line end
p:close()
assert(#files > 50, "keine Quelldateien gefunden")

local bad, found = {}, 0
for _, path in ipairs(files) do
    local rel = path:sub(#root + 2)
    local mod = rel:match("^([^/]+)/")
    if not SKIP[mod] and not SKIP[rel] then
        local lines = {}
        for l in io.lines(path) do lines[#lines + 1] = l end
        for i, l in ipairs(lines) do
            local code = l:gsub("%-%-.*$", "")
            for _, t in ipairs(TEMPLATES) do
                if code:find("CreateFrame", 1, true) and code:find(t, 1, true) then
                    found = found + 1
                    local ok = false
                    for k = math.max(1, i - 3), i do
                        local c = lines[k]:gsub("%-%-.*$", "")
                        if c:find("not glass", 1, true) or c:find("if modern", 1, true) or c:find("else ok", 1, true) then ok = true end
                    end
                    if not ok then bad[#bad + 1] = rel .. ":" .. i end
                end
            end
        end
    end
end
assert(found >= 5, "zu wenige Fensterrahmen gefunden (" .. found .. ") – Test pruefen")
assert(#bad == 0, "Blizzard-Fensterrahmen ohne Glas-Weiche: " .. table.concat(bad, ", "))

-- Die zwei zuletzt umgestellten Fenster melden sich im Glas-Aussehen als Glasfenster an
for _, f in ipairs({root .. "/ONE_Classes/Trainer.lua", root .. "/ONE_Dungeons/Page.lua"}) do
    local s = assert(io.open(f)):read("*a")
    assert(s:find("RegisterWindow", 1, true), f .. ": kein Glasfenster")
    assert(s:find("StyleTree", 1, true), f .. ": Bedienelemente nicht eingekleidet")
end
print("ok", found .. " Fensterrahmen geprueft")
