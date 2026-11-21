-- Guild Trip Chat: Emojis und WoW-Zeichen (Nutzer 21.11.2026, Vorschau 2 `docs/vorschau_chat_messenger.html`).
-- Die Spielschrift kennt keine Emojis (wuerden zu Kaestchen). Deshalb:
--  * gesendet wird ein kurzer Text-Code (":daumen:", ":)", "<3") – wer Guild Trip nicht hat, liest den Code
--  * angezeigt wird ein eigenes Bild (Noto Emoji von Google, siehe THIRD_PARTY.md), nur im Guild-Trip-Chat
--  * WoW-Zeichen ({rt1} … {rt8} = Stern, Kreis …) sieht JEDER: die setzt WoW selbst in jedem Chat um
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Emoji = {}
chat.Emoji = Emoji

local DIR = "Interface\\AddOns\\ONE_Chat\\Textures\\Emoji\\"
Emoji.DIR = DIR

-- {Datei (Unicode), Code, Name, Smileys/Kurzformen …}
Emoji.GROUPS = {
    {key = "faces", label = "Gesichter", list = {
        {"1f60a", "laecheln", "Lächeln", ":)", ":-)"},
        {"1f603", "freude", "Freude", ":D", ":-D"},
        {"1f604", "lachen", "Lachen"},
        {"1f601", "grinsen", "Grinsen"},
        {"1f602", "traenenlachen", "Tränen lachen"},
        {"1f923", "rofl", "Kugeln vor Lachen", "xD", "XD"},
        {"1f609", "zwinkern", "Zwinkern", ";)", ";-)"},
        {"1f605", "puh", "Puh"},
        {"1f60d", "verliebt", "Verliebt"},
        {"1f618", "kuss", "Kuss", ":*"},
        {"1f61b", "zunge", "Zunge", ":P", ":p"},
        {"1f60e", "cool", "Cool"},
        {"1f914", "hmm", "Hmm"},
        {"1f644", "augenrollen", "Augenrollen"},
        {"1f62e", "staunen", "Staunen", ":O", ":o"},
        {"1f631", "schreck", "Schreck"},
        {"1f622", "traurig", "Traurig", ":(", ":-("},
        {"1f62d", "weinen", "Weinen", ":'("},
        {"1f621", "wuetend", "Wütend", ">:("},
        {"1f634", "schlafen", "Schlafen"},
        {"1f973", "party", "Party"},
        {"1f600", "froh", "Froh"},
    }},
    {key = "hands", label = "Gesten", list = {
        {"1f44d", "daumen", "Daumen hoch", "(y)"},
        {"1f44e", "daumenrunter", "Daumen runter"},
        {"1f44b", "winken", "Winken"},
        {"1f44f", "klatschen", "Klatschen"},
        {"1f64c", "jubel", "Jubel"},
        {"1f64f", "bitte", "Bitte / Danke"},
        {"1f4aa", "stark", "Stark"},
        {"1f44c", "ok", "Okay"},
        {"270c", "peace", "Peace"},
        {"1f91d", "deal", "Abgemacht"},
        {"1f91e", "daumendruecken", "Daumen drücken"},
        {"1f440", "augen", "Augen"},
    }},
    {key = "hearts", label = "Herzen", list = {
        {"2764", "herz", "Herz", "<3"},
        {"1f9e1", "herzorange", "Herz orange"},
        {"1f49b", "herzgelb", "Herz gelb"},
        {"1f49a", "herzgruen", "Herz grün"},
        {"1f499", "herzblau", "Herz blau"},
        {"1f49c", "herzlila", "Herz lila"},
        {"1f494", "herzbruch", "Gebrochenes Herz", "</3"},
    }},
    {key = "things", label = "WoW", list = {
        {"2694", "schwerter", "Schwerter"},
        {"1f6e1", "schild", "Schild"},
        {"1f480", "totenkopf", "Totenkopf"},
        {"1f525", "feuer", "Feuer"},
        {"2b50", "stern", "Stern"},
        {"1f4b0", "gold", "Gold"},
        {"1fa99", "muenze", "Münze"},
        {"1f37a", "bier", "Bier"},
        {"1f389", "konfetti", "Konfetti"},
        {"1f381", "geschenk", "Geschenk"},
        {"1f3c6", "pokal", "Pokal"},
        {"1f409", "drache", "Drache"},
        {"1f9d9", "magier", "Magier"},
        {"2705", "haken", "Haken"},
        {"274c", "kreuz", "Kreuz"},
        {"1f4af", "100", "Hundert"},
        {"1f4a4", "zzz", "Müde"},
        {"23f3", "warten", "Warten"},
    }},
}
-- englische Kurzformen (Locale enUS und Gewohnheit)
Emoji.ALIASES = {
    smile = "laecheln", laugh = "lachen", lol = "traenenlachen", wink = "zwinkern", cry = "weinen", sad = "traurig",
    angry = "wuetend", love = "verliebt", kiss = "kuss", think = "hmm", sleep = "schlafen", thumbsup = "daumen", ["+1"] = "daumen",
    thumbsdown = "daumenrunter", ["-1"] = "daumenrunter", wave = "winken", clap = "klatschen", pray = "bitte", thanks = "bitte",
    heart = "herz", swords = "schwerter", shield = "schild", skull = "totenkopf", fire = "feuer", star = "stern", coin = "muenze",
    beer = "bier", gift = "geschenk", trophy = "pokal", dragon = "drache", check = "haken", cross = "kreuz",
}

-- WoW-Zeichen (Zielmarkierungen): sieht jeder, WoW setzt {rt1} … {rt8} selbst um
Emoji.MARKS = {
    {1, "Stern", "star"}, {2, "Kreis", "circle"}, {3, "Diamant", "diamond"}, {4, "Dreieck", "triangle"},
    {5, "Mond", "moon"}, {6, "Quadrat", "square"}, {7, "Kreuz", "cross"}, {8, "Totenschädel", "skull"},
}
Emoji.MARK_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"

Emoji.byCode, Emoji.byFile, Emoji.ascii = {}, {}, {}
for _, g in ipairs(Emoji.GROUPS) do
    for _, e in ipairs(g.list) do
        local item = {file = e[1], code = e[2], name = e[3], group = g.key}
        Emoji.byCode[e[2]] = item
        Emoji.byFile[e[1]] = item
        for i = 4, #e do Emoji.ascii[#Emoji.ascii + 1] = {e[i], item} end
    end
end
for alias, code in pairs(Emoji.ALIASES) do Emoji.byCode[alias] = Emoji.byCode[alias] or Emoji.byCode[code] end
-- laengste Kurzform zuerst (":'(" vor ":(")
table.sort(Emoji.ascii, function(a, b) if #a[1] ~= #b[1] then return #a[1] > #b[1] end return a[1] < b[1] end)

function Emoji.Texture(item) return DIR .. item.file end
function Emoji.Tag(item, size)
    return "|T" .. DIR .. item.file .. ":" .. tostring(size or 0) .. ":" .. tostring(size or 0) .. "|t"
end
function Emoji.MarkTag(n, size)
    return "|T" .. Emoji.MARK_TEX .. tostring(n) .. ":" .. tostring(size or 0) .. "|t"
end
-- Text-Code zum Einfuegen ins Eingabefeld
function Emoji.CodeOf(item) return ":" .. item.code .. ":" end
function Emoji.MarkCode(n) return "{rt" .. tostring(n) .. "}" end

-- Name eines WoW-Zeichens in geschweiften Klammern -> Nummer (deutsch, englisch, rt1 … rt8, WoW-Liste)
function Emoji.MarkNumber(word)
    local low = tostring(word or ""):lower()
    local n = tonumber(low:match("^rt(%d)$"))
    if n and n >= 1 and n <= 8 then return n end
    local list = rawget(_G, "ICON_TAG_LIST")
    if type(list) == "table" and tonumber(list[low]) then return tonumber(list[low]) end
    for _, m in ipairs(Emoji.MARKS) do
        if low == m[2]:lower() or low == m[3] then return m[1] end
    end
    if low == "x" or low == "totenkopf" then return low == "x" and 7 or 8 end
end

-- Kurzform nur frei stehend ersetzen: davor Leerraum/Anfang, danach Leerraum, Satzzeichen oder Ende
function Emoji.FreeReplace(seg, short, repl)
    local pat = "(%s)" .. short:gsub("%p", "%%%0") .. "([%s%.,!%?])"
    local out = " " .. seg .. " "
    -- zweimal: direkt hintereinander (":) :)") teilen sich das Leerzeichen
    for _ = 1, 2 do out = out:gsub(pat, function(pre, post) return pre .. repl() .. post end) end
    return out:sub(2, -2)
end
local function Plain(seg, size, opts)
    -- {Stern} / {rt1}
    seg = seg:gsub("{([^{}]+)}", function(word)
        local n = Emoji.MarkNumber(word)
        if n then return Emoji.MarkTag(n, size) end
    end)
    -- :code:
    seg = seg:gsub(":([%w%+%-]+):", function(code)
        local item = Emoji.byCode[code:lower()]
        if item then return Emoji.Tag(item, size) end
    end)
    -- Smileys wie :) nur frei stehend (nicht in "Uhr:)" oder Adressen)
    if not (opts and opts.noAscii) then
        for _, a in ipairs(Emoji.ascii) do
            seg = Emoji.FreeReplace(seg, a[1], function() return Emoji.Tag(a[2], size) end)
        end
    end
    return seg
end

-- Text mit Bildern statt Codes. Links (|H…|h…|h), Farbcodes und Bilder bleiben unberuehrt.
-- size: Bildgroesse (0 = so hoch wie die Schrift). opts.noAscii: Smileys wie :) nicht umsetzen.
function Emoji.Render(text, size, opts)
    text = tostring(text or "")
    if text == "" then return text end
    local out, i = {}, 1
    while i <= #text do
        local s, e = text:find("|[HTcr]", i)
        if not s then out[#out + 1] = Plain(text:sub(i), size, opts) break end
        if s > i then out[#out + 1] = Plain(text:sub(i, s - 1), size, opts) end
        local kind = text:sub(s + 1, s + 1)
        local stop
        if kind == "H" then
            -- |Hdaten|hText|h – komplett uebernehmen
            local a = text:find("|h", s + 2, true)
            local b = a and text:find("|h", a + 2, true)
            stop = b and (b + 1) or #text
        elseif kind == "T" then
            local a = text:find("|t", s + 2, true)
            stop = a and (a + 1) or #text
        elseif kind == "c" then
            stop = math.min(#text, s + 9)
        else
            stop = s + 1
        end
        out[#out + 1] = text:sub(s, stop)
        i = stop + 1
    end
    return table.concat(out)
end

-- Besteht der Text nur aus 1–3 Emojis/Zeichen? (dann gross zeigen, wie im Messenger)
function Emoji.OnlyEmoji(text)
    local rest, n = tostring(text or ""), 0
    rest = rest:gsub("{([^{}]+)}", function(w) if Emoji.MarkNumber(w) then n = n + 1 return "" end end)
    rest = rest:gsub(":([%w%+%-]+):", function(c) if Emoji.byCode[c:lower()] then n = n + 1 return "" end end)
    for _, a in ipairs(Emoji.ascii) do
        rest = Emoji.FreeReplace(rest, a[1], function() n = n + 1 return "" end)
    end
    return n >= 1 and n <= 3 and not rest:find("%S")
end

-- Zuletzt benutzt (je Charakter in den Chat-Einstellungen, hoechstens 20)
function Emoji.Recent(settings)
    if type(settings.recentEmoji) ~= "table" then settings.recentEmoji = {} end
    return settings.recentEmoji
end
function Emoji.Remember(settings, code)
    local list = Emoji.Recent(settings)
    for i = #list, 1, -1 do if list[i] == code then table.remove(list, i) end end
    table.insert(list, 1, code)
    while #list > 20 do table.remove(list) end
end

-- Liste fuer die Auswahl: {kind = "emoji"/"mark", item/n, code, name}
function Emoji.PickerItems(group, settings)
    local out = {}
    if group == "recent" then
        for _, code in ipairs(Emoji.Recent(settings)) do
            local n = tonumber(code:match("^{rt(%d)}$"))
            if n then out[#out + 1] = {kind = "mark", n = n, code = code, name = T(Emoji.MARKS[n][2])}
            elseif Emoji.byCode[code:match("^:(.-):$") or ""] then
                local item = Emoji.byCode[code:match("^:(.-):$")]
                out[#out + 1] = {kind = "emoji", item = item, code = code, name = T(item.name)}
            end
        end
        -- leer: die beliebtesten
        if #out == 0 then
            for _, c in ipairs({"daumen", "traenenlachen", "herz", "feuer", "laecheln", "zwinkern", "bitte", "schwerter", "totenkopf", "winken"}) do
                local item = Emoji.byCode[c]
                out[#out + 1] = {kind = "emoji", item = item, code = Emoji.CodeOf(item), name = T(item.name)}
            end
        end
        return out
    end
    if group == "marks" then
        for _, m in ipairs(Emoji.MARKS) do out[#out + 1] = {kind = "mark", n = m[1], code = Emoji.MarkCode(m[1]), name = T(m[2])} end
        return out
    end
    for _, g in ipairs(Emoji.GROUPS) do
        if g.key == group then
            for _, e in ipairs(g.list) do
                local item = Emoji.byCode[e[2]]
                out[#out + 1] = {kind = "emoji", item = item, code = Emoji.CodeOf(item), name = T(item.name)}
            end
        end
    end
    return out
end
