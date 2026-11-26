-- Stufen-Abläufe beim Leveln (stages, Freigabe 21.11.2026 „gerne“: erst Magier, dann alle Klassen):
-- jede Klasse und Ausrichtung hat Abschnitte ab Stufe 1, lückenlos, aufsteigend; jede Platznummer im Text gibt es
-- auf der Kampfleiste, und ihr Zauber ist bis zum Ende des Abschnitts lernbar (Lernstufen aus den Spieldaten
-- 1.60.1.70959, SpellLevels – unten eingebettet, erzeugt am 25.11.2026).
local root = arg[1] or "src"
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
for _, f in ipairs({"Data.lua", "DataClasses.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
local D = c.Data
local LEARN = {[10] = 20, [17] = 6, [53] = 4, [71] = 10, [72] = 12, [78] = 1, [99] = 10, [100] = 4, [116] = 4, [118] = 8, [120] = 26, [122] = 10, [130] = 12, [133] = 1, [136] = 12, [139] = 8, [168] = 1, [172] = 4, [324] = 8, [331] = 1, [339] = 8, [348] = 1, [355] = 10, [403] = 1, [408] = 30, [421] = 32, [453] = 20, [465] = 1, [467] = 6, [475] = 18, [498] = 6, [526] = 16, [527] = 18, [528] = 14, [556] = 30, [586] = 8, [587] = 6, [588] = 12, [589] = 4, [596] = 30, [604] = 12, [633] = 10, [635] = 1, [642] = 34, [676] = 18, [678] = 12, [686] = 1, [687] = 1, [688] = 1, [689] = 14, [691] = 30, [693] = 18, [697] = 10, [706] = 20, [712] = 20, [755] = 12, [768] = 20, [770] = 18, [772] = 4, [774] = 4, [779] = 16, [781] = 20, [783] = 30, [845] = 20, [853] = 8, [871] = 28, [879] = 20, [883] = 10, [921] = 4, [976] = 30, [980] = 8, [982] = 10, [1008] = 18, [1022] = 10, [1044] = 18, [1064] = 40, [1066] = 16, [1079] = 20, [1082] = 20, [1120] = 10, [1126] = 1, [1130] = 6, [1152] = 8, [1160] = 14, [1243] = 1, [1449] = 14, [1454] = 6, [1459] = 1, [1463] = 20, [1464] = 30, [1494] = 1, [1495] = 16, [1499] = 20, [1515] = 10, [1680] = 36, [1719] = 50, [1725] = 22, [1752] = 1, [1766] = 12, [1776] = 6, [1784] = 1, [1804] = 1, [1822] = 24, [1833] = 26, [1842] = 30, [1850] = 26, [1856] = 22, [1953] = 20, [1966] = 16, [1978] = 4, [2006] = 10, [2008] = 12, [2050] = 1, [2054] = 16, [2061] = 20, [2094] = 34, [2098] = 1, [2120] = 16, [2136] = 6, [2139] = 24, [2457] = 1, [2458] = 30, [2484] = 6, [2565] = 16, [2637] = 18, [2641] = 10, [2643] = 18, [2645] = 20, [2687] = 10, [2782] = 24, [2836] = 24, [2912] = 20, [2944] = 20, [2948] = 22, [2973] = 1, [2974] = 12, [2983] = 10, [3044] = 6, [3045] = 26, [3599] = 10, [4987] = 42, [5116] = 8, [5118] = 20, [5143] = 8, [5171] = 10, [5176] = 1, [5185] = 1, [5209] = 28, [5211] = 14, [5215] = 20, [5217] = 24, [5221] = 20, [5229] = 12, [5246] = 22, [5277] = 8, [5308] = 24, [5384] = 30, [5394] = 20, [5484] = 40, [5487] = 10, [5504] = 4, [5570] = 20, [5675] = 26, [5676] = 18, [5697] = 16, [5782] = 8, [6117] = 34, [6201] = 10, [6229] = 32, [6343] = 6, [6552] = 38, [6572] = 14, [6673] = 1, [6770] = 10, [6785] = 32, [6789] = 42, [6795] = 10, [6807] = 10, [6991] = 10, [7294] = 16, [7328] = 12, [7384] = 12, [7386] = 10, [8004] = 20, [8017] = 1, [8024] = 10, [8042] = 4, [8050] = 10, [8056] = 20, [8071] = 4, [8075] = 10, [8092] = 10, [8122] = 14, [8143] = 18, [8232] = 30, [8676] = 18, [8921] = 4, [8936] = 12, [8946] = 14, [9484] = 20, [10060] = 40, [11113] = 30, [11129] = 40, [11366] = 20, [11426] = 40, [11958] = 4, [12043] = 1, [12051] = 20, [12292] = 30, [12294] = 40, [12323] = 20, [12328] = 1, [12472] = 1, [12809] = 30, [12975] = 1, [13163] = 4, [13165] = 10, [13795] = 16, [13877] = 1, [14914] = 20, [15237] = 20, [15286] = 30, [15407] = 20, [16166] = 1, [16188] = 1, [16190] = 1, [16511] = 30, [16914] = 40, [17116] = 1, [17364] = 40, [17877] = 20, [18265] = 30, [18499] = 30, [18562] = 1, [18960] = 10, [19028] = 1, [19263] = 20, [19306] = 30, [19434] = 20, [19503] = 30, [19574] = 40, [19577] = 30, [19740] = 4, [19742] = 14, [19746] = 22, [19750] = 20, [20066] = 20, [20217] = 20, [20230] = 20, [20252] = 30, [20271] = 4, [20375] = 20, [20484] = 20, [20554] = 1, [20925] = 30, [21082] = 6, [21084] = 1, [22568] = 32, [22812] = 44, [22842] = 36, [23881] = 40, [23922] = 40, [24275] = 44, [24858] = 40, [25780] = 10, [26573] = 20, [29166] = 40, [399956] = 40, [400574] = 20, [401859] = 40, [402174] = 30, [407995] = 40, [408120] = 40, [408510] = 20, [408521] = 40, [412758] = 40, [425336] = 1, [1238122] = 20, [1259686] = 1, [1277324] = 20, [1293241] = 25, [1293817] = 25, [1299346] = 25, [1310222] = 1, [1310687] = 40, [1310911] = 40, [1310994] = 1, [1311606] = 30, [1312002] = 20, [1316697] = 40, [1316709] = 40, [1317257] = 30, [1322605] = 1, [1326079] = 25, [1328617] = 25}
local function Fail(msg) error(msg, 2) end
local n = 0
for _, cls in ipairs({"PRIEST", "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PALADIN", "SHAMAN", "DRUID"}) do
    local def = D.classes[cls]
    for spec = 1, 3 do
        local b = def.build[spec]
        local who = cls .. " " .. spec
        if type(b.stages) ~= "table" or #b.stages < 2 then Fail(who .. ": keine Stufen-Abschnitte") end
        -- Original-Reihenfolge der Kampfleiste (vor der Umsortierung): slotMap alt -> neu
        local bar = b.bars[1]
        local orig = {}
        for old, new in pairs(b.slotMap or {}) do orig[old] = bar.slots[new] end
        local total = #bar.slots
        for i = (b.slotFixed or 0) + 1, total do orig[i] = bar.slots[i] end
        local from = 1
        for k, st in ipairs(b.stages) do
            if type(st.upTo) ~= "number" or st.upTo < from then Fail(who .. ": Abschnitt " .. k .. " upTo") end
            local a, z = st.flow:match("^Stufe (%d+)–(%d+) – ")
            if tonumber(a) ~= from or tonumber(z) ~= st.upTo then Fail(who .. ": Abschnitt " .. k .. " beginnt nicht mit „Stufe " .. from .. "–" .. st.upTo .. " – “") end
            -- Platz-Bezüge wie auf der Seite gelesen
            local text = st.flow:gsub("^Stufe %d+–%d+ – ", ""):gsub("^vorher:[^·]*·%s*", "")
            local pos = 1
            while true do
                local s, e, num = text:find("(%d+)", pos)
                if not s then break end
                local slot = tonumber(num)
                if D.IsSlotRef(text, s, e, slot, total) then
                    local step = orig[slot]
                    if not step then Fail(who .. ": Platz " .. slot .. " gibt es nicht") end
                    local id = type(step[1]) == "table" and step[1][1] or step[1]
                    local lvl = type(id) == "number" and LEARN[id]
                    -- Talente: Spieldaten nennen die alte Classic-Stufe; „(Talent)“ im selben Abschnitt-Teil ist erlaubt
                    local seg = text:sub(1, e):match("([^·]*)$") .. (text:sub(e + 1):match("^([^·]*)") or "")
                    if lvl and lvl > st.upTo and not step.talent and not seg:find("Talent", 1, true) then
                        Fail(("%s Abschnitt %d (bis %d): Platz %d (Zauber %d) erst ab Stufe %d"):format(who, k, st.upTo, slot, id, lvl))
                    end
                end
                pos = e + 1
            end
            from = st.upTo + 1
            n = n + 1
        end
        -- über dem letzten Abschnitt gilt der normale Ablauf
        assert(D:Build(def, spec, "solo", from).flow == b.flow, who .. ": normaler Ablauf danach")
        assert(D:Build(def, spec, "solo", 1).flow == b.stages[1].flow, who .. ": Stufe 1")
        assert(D:Build(def, spec, "dungeon", 1).flow ~= b.stages[1].flow or not b.situations, who .. ": Dungeon ohne Abschnitte")
    end
end
assert(n >= 60, "zu wenige Abschnitte: " .. n)
print("OK test_stages_175")
