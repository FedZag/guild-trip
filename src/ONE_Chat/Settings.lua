-- Guild Trip Chat: Einstellungen in Optionen › Chat (0.6.9, alle Einstellungen zentral, Nutzer 17.11.2026).
-- Das Zahnrad im Chatfenster springt direkt dorthin; ein eigenes Einstellungsfenster gibt es nicht mehr.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local UI, Chat = chat.UI, chat.Chat

-- Schalter: {Schluessel, Beschriftung, Tooltip, nach dem Umschalten, Spalte (1 = Verhalten & Toene, 2 = Aussehen)}
local function Look() UI:ApplyLook() end
UI.settingChecks = {
    {"openOnLogin", "Beim Einloggen öffnen", nil, nil, 1},
    {"launcher", "Chat-Knopf am WoW-Chat", "Kleine Sprechblase oben am WoW-Chat mit Zähler für ungelesene Flüsternachrichten. Umschalt+Ziehen verschiebt sie.",
        function() if chat.Launcher then chat.Launcher:Update() end end, 1},
    {"hideBlizzard", "WoW-Chat durch diesen ersetzen", "Blendet das WoW-Chatfenster aus; Enter und / öffnen dann dieses Fenster. Nicht angezeigt werden dabei u. a. Beute, Erfahrung und das Kampflog. Jederzeit zurück: Haken raus oder /trip wowchat. Gesperrt bei ElvUI & Co.",
        function() if chat.Hider then chat.Hider:Apply() end end, 1},
    {"keepHistory", "Verlauf nach Neustart behalten", "Die letzten 100 Nachrichten je Reiter und 50 je Flüstergespräch (höchstens 10 Gespräche, nicht älter als 7 Tage) bleiben nach /reload und Neueinloggen erhalten – je Charakter, nur auf diesem PC. Ausschalten löscht den gespeicherten Verlauf beim nächsten Ausloggen.", nil, 1},
    {"whisperHere", "Flüstern im Guild-Trip-Chat öffnen", "„Flüstern“ im Namens-Menü öffnet das Gespräch im Guild-Trip-Chat statt im WoW-Chat.", nil, 1},
    {"blink", "Neue Nachrichten blinken", "Gespräche mit ungelesenen Nachrichten blinken; bei Flüstern blinkt auch das WoW-Symbol in der Taskleiste.", function() UI:Refresh() end, 1},
    {"whisperSound", "Ton bei Flüsternachrichten", "Nur, wenn das Gespräch gerade nicht offen ist.", nil, 1},
    {"guildSound", "Ton bei Gildennachrichten", "Leises „Pling“, höchstens alle paar Sekunden einmal – nur, wenn die Gilde gerade nicht offen ist.", nil, 1},
    {"groupSound", "Ton bei Gruppennachrichten", "Leises „Pling“, höchstens alle paar Sekunden einmal – nur, wenn die Gruppe gerade nicht offen ist.", nil, 1},
    {"sentSound", "Ton beim Senden", nil, nil, 1},
    {"stamps", "Uhrzeit vor jeder Nachricht", nil, function() UI:Render() end, 2},
    {"fadeLines", "Alte Zeilen verblassen", "Wie im WoW-Chat: Zeilen verschwinden nach einer Minute. Mausrad holt sie zurück.", Look, 2},
    {"locked", "Fenster festsetzen", "Nicht mehr verschieben oder in der Größe ändern.", Look, 2},
    {"flat", "Schlichtes Aussehen (passend zu ElvUI & Co.)", "Flach und dunkel mit dünnem Rand statt Blizzard-Rahmen bzw. Pergament. Wirkt nach /reload.",
        function() ONE:Print(T("Das Aussehen des Chats ändert sich nach /reload.")) end, 2},
}
UI.fontSizes = {12, 13, 14, 16, 18, 20}
-- Auswahlfelder (Spalte Aussehen): {Schluessel, Beschriftung, Werte {Wert, Text}, nach dem Aendern}
local function Pct(list) local out = {} for _, v in ipairs(list) do out[#out + 1] = {v, v >= 1 and "100 %" or (math.floor(v * 100 + .5) .. " %")} end return out end
UI.settingDrops = {
    {"fontSize", "Schriftgröße", function() local o = {} for _, n in ipairs(UI.fontSizes) do o[#o + 1] = {n, tostring(n)} end return o end, function(v) UI:SetFontSize(v) end},
    {"spacing", "Zeilenabstand", function() return {{0, T("eng")}, {2, T("normal")}, {4, T("weit")}, {7, T("sehr weit")}} end, Look},
    {"opacity", "Hintergrund", function() return Pct({1, .85, .7, .55, .4, .25}) end, Look},
    {"idleAlpha", "Ohne Maus", function()
        local o = {{1, T("immer sichtbar")}}
        for _, v in ipairs({.6, .35, .15}) do o[#o + 1] = {v, T("auf %d %% ausblenden", math.floor(v * 100 + .5))} end
        return o
    end, Look},
}

-- Wert lesen (whisperHere ist "an", solange nicht ausdruecklich aus)
function UI.SettingOn(key)
    local s = Chat:Settings()
    if key == "whisperHere" or key == "launcher" or key == "keepHistory" then return s[key] ~= false end
    if key == "flat" then return Chat:Flat() end
    if key == "hideBlizzard" then return s.hideBlizzard == true and Chat:CanHideBlizzardChat() end
    return s[key] == true
end
function UI.SetSetting(key, on)
    if key == "hideBlizzard" and on then
        local ok, why = Chat:CanHideBlizzardChat()
        if not ok then ONE:Print(why) return end
    end
    Chat:Settings()[key] = on and true or false
end

function UI:SetFontSize(size)
    Chat:Settings().fontSize = size
    if self.log and self.log.GetFont then
        local file = self.log:GetFont()
        if file then pcall(self.log.SetFont, self.log, file, size, "") end
    end
end

-- In Optionen › Chat anmelden: Spalte 1 = "Verhalten & Töne", Spalte 2 = "Aussehen"
local SECTION = {"Verhalten & Töne", "Aussehen"}
function UI:RegisterSettings()
    local O = ONE.UI
    if not (O and O.AddSetting) then return false end
    local function Add(o) o.category, o.module = "chat", "chat" O:AddSetting(o) end
    -- Hinweis, wenn ElvUI & Co. laufen (doppelte Toene, Ausblenden gesperrt)
    Add({id = "chatOther", kind = "text", order = 1,
        visible = function() return Chat.OtherChatAddon() ~= nil end,
        label = function()
            local other = Chat.OtherChatAddon()
            return other and ("|cffffd100" .. T("%s erkannt:", other) .. "|r " .. T("Töne ggf. dort oder hier abschalten, sonst klingt es doppelt. „WoW-Chat ausblenden“ bleibt gesperrt.")) or ""
        end})
    for i, c in ipairs(self.settingChecks) do
        local key, after, col = c[1], c[4], c[5] or 1
        Add({id = "chat." .. key, section = SECTION[col], order = col * 100 + i, label = c[2], tooltip = c[3],
            get = function() return UI.SettingOn(key) end,
            set = function(on) UI.SetSetting(key, on) end,
            onChange = after})
    end
    for i, o in ipairs(self.settingDrops) do
        local key, values, after = o[1], o[3], o[4]
        Add({id = "chat." .. key, section = SECTION[2], order = 150 + i, kind = "dropdown", label = o[2], width = 180,
            options = function()
                local out = {}
                for _, v in ipairs(values()) do out[#out + 1] = {value = v[1], text = v[2]} end
                return out
            end,
            get = function() return Chat:Settings()[key] end,
            set = function(v) Chat:Settings()[key] = v if after then after(v) end end})
    end
    return true
end

-- Zahnrad im Chatfenster: Optionen › Chat
function UI:OpenSettings()
    if ONE.UI and ONE.UI.OpenOptions then ONE.UI:OpenOptions("chat") end
end
