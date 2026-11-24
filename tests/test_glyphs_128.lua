-- Offline-Test 0.7.3: Zeichen, die die Spielschrift nicht kennt, und Glas-Deckkraft (Nutzer 19.11.2026:
-- "kannst du solche Fehler vorher sehen?").
-- 1) Nur Zeichen aus der Liste OK in Lua-Texten (früher: kein "→"/"×"): Die Schrift in Fenstern und auf Knoepfen zeigt dafuer ein
--    leeres Feld bzw. Kaestchen (Spielbilder 17.11. "→", 19.11. "×" am Gespraech-schliessen-Knopf).
--    Stattdessen: "–", "x" oder ein Symbol (CloseGlyph.tga). Kommentare sind erlaubt.
-- 2) Glas: Texture:SetAlpha ist bei Texturen dieselbe Deckkraft wie die Farbe (SetColorTexture,
--    SetVertexColor, SetBackdropColor). Wer Hintergrund-Teile per GetRegions sammelt und SetAlpha setzt,
--    muss das Glas ausnehmen (Spieltest 19.11.: Chat-Glas wurde beim Reiterwechsel schwarz).
local root = arg[1] or "src"
-- Erlaubt sind nur Zeichen, die die Forever-Spielschrift sicher kennt (Nutzer 20.11.2026: "schau vor dem
-- Programmieren, ob die Zeichen von Forever unterstützt werden"). Neues Sonderzeichen? ERST im Spiel prüfen
-- (Spielbild), dann hier eintragen – sonst lieber ein WoW-Symbol |T…|t oder ein Zeichen aus der Liste nehmen.
-- Bekannt FEHLEND (Kästchen im Spiel): → × ▶ (Spielbilder 17.11., 19.11., 20.11.).
local OK = {}
for ch in ("äöüÄÖÜß·–…„“"):gmatch("[\192-\244][\128-\191]*") do OK[ch] = "im Spiel gesehen" end
-- schon länger benutzt, ohne Meldung – nicht ausdrücklich bestätigt
for ch in ("›‹’”−»•Ø\194\160"):gmatch("[\192-\244][\128-\191]*") do OK[ch] = OK[ch] or "ungeprüft" end
-- alte, nicht geladene Dateien, Entwickler-Werkzeuge und Spieldaten (Namen aus Questie usw.)
local SKIP = {["ONE_Dev"] = true, ["ONE_Guild/Navigation.lua"] = true, ["ONE_QuestDB"] = true, ["ONE_Routes"] = true,
    ["ONE_Chat/ItemNames.lua"] = true} -- Gegenstandsnamen aus den Spieldaten (schreibt das Spiel selbst so)

local p = io.popen('find "' .. root .. '" -name "*.lua" | sort')
local files = {}
for line in p:lines() do files[#files + 1] = line end
p:close()
assert(#files > 50, "keine Quelldateien gefunden")

local bad = {}
for _, path in ipairs(files) do
    local rel = path:sub(#root + 2)
    local mod = rel:match("^([^/]+)/")
    if not SKIP[mod] and not SKIP[rel] then
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            -- Kommentar am Zeilenende grob abschneiden (nicht in Texten mit "--")
            local code = line:gsub("^%s*%-%-.*$", ""):gsub("%s%-%-%s.*$", "")
            for ch in code:gmatch("[\192-\244][\128-\191]*") do
                if not OK[ch] then bad[#bad + 1] = rel .. ":" .. n .. " (" .. ch .. ")" end
            end
        end
    end
end
assert(#bad == 0, "Zeichen, die die Spielschrift nicht kennt:\n" .. table.concat(bad, "\n"))

-- 2) SetAlpha auf gesammelte Hintergrund-Teile nur mit Glas-Ausnahme
local ALLOWED = {
    ["ONE_Core/GlassControls.lua"] = "versteckt Blizzard-Teile von Reglern/Leisten (Alpha 0), kein Glas",
}
local found = 0
for _, path in ipairs(files) do
    local rel = path:sub(#root + 2)
    local mod = rel:match("^([^/]+)/")
    if not SKIP[mod] then
        local src = io.open(path):read("*a")
        if src:find("GetRegions", 1, true) and src:find(":SetAlpha(", 1, true) and not ALLOWED[rel] then
            found = found + 1
            assert(src:find("glassTex", 1, true) and src:find("if not self.glass then", 1, true),
                rel .. ": sammelt Regionen und setzt SetAlpha ohne Glas-Ausnahme")
        end
    end
end
assert(found >= 1, "Chat-Fenster nicht gefunden – Test pruefen")
print("OK test_glyphs_128")
