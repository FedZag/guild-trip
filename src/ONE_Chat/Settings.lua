-- Guild Trip Chat: Einstellungen im Chatfenster (Zahnrad oben rechts), wie bei einem Messenger.
-- Frueher unter Optionen › Spielhilfen – dort lief die Seite im Buch ueber (15.11.2026).
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
        function() if chat.Hider then chat.Hider:Apply() end if UI.settings then for _, b in ipairs(UI.settings.checks) do if b.Refresh then b:Refresh() end end end end, 1},
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
    if key == "whisperHere" or key == "launcher" then return s[key] ~= false end
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

local COL_W, ROW = 300, 26
function UI:OpenSettings()
    local d = self.settings
    if not d then
        d = CreateFrame("Frame", "GuildTripChatSettings", UIParent, "BackdropTemplate")
        -- Hinweis oben, wenn ElvUI & Co. laufen (doppelte Toene, Ausblenden gesperrt)
        local other = Chat.OtherChatAddon()
        local top = other and 92 or 58
        local count = {0, 0}
        for _, c in ipairs(self.settingChecks) do count[c[5] or 1] = count[c[5] or 1] + 1 end
        local rows = math.max(count[1], count[2] + #self.settingDrops * 32 / ROW)
        d:SetSize(COL_W * 2 + 30, top + rows * ROW + 24)
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        d:SetFrameStrata("DIALOG")
        d:SetToplevel(true)
        d:EnableMouse(true)
        d:SetMovable(true)
        d:RegisterForDrag("LeftButton")
        d:SetScript("OnDragStart", function(f) f:StartMoving() end)
        d:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
        local bg = d:CreateTexture(nil, "BACKGROUND", nil, -7)
        bg:SetPoint("TOPLEFT", d, "TOPLEFT", 4, -4)
        bg:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -4, 4)
        bg:SetColorTexture(.04, .05, .07, .96)
        local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -12)
        title:SetText(T("Chat-Einstellungen"))
        ONE.Widgets:CloseButton(d, "TOPRIGHT", -4, -4, function() d:Hide() end)
        if other then
            local hint = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            hint:SetPoint("TOPLEFT", d, "TOPLEFT", 18, -34)
            hint:SetWidth(COL_W * 2 - 10)
            hint:SetJustifyH("LEFT")
            if hint.SetWordWrap then hint:SetWordWrap(true) end
            hint:SetText("|cffffd100" .. T("%s erkannt:", other) .. "|r " .. T("Töne ggf. dort oder hier abschalten, sonst klingt es doppelt. „WoW-Chat ausblenden“ bleibt gesperrt."))
            d.hint = hint
        end
        -- Spaltenkoepfe
        for col, label in ipairs({T("Verhalten & Töne"), T("Aussehen")}) do
            local h = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("TOPLEFT", d, "TOPLEFT", 18 + (col - 1) * (COL_W + 10), -top + 22)
            h:SetText(label)
            if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(h, "accent") end
        end
        d.checks = {}
        local y = {-top, -top}
        for i, c in ipairs(self.settingChecks) do
            local key, after, col = c[1], c[4], c[5] or 1
            d.checks[i] = ONE.Kit:Check(d, {point = "TOPLEFT", x = 14 + (col - 1) * (COL_W + 10), y = y[col], label = c[2], tooltip = c[3] and T(c[3]),
                get = function() return UI.SettingOn(key) end,
                set = function(on) UI.SetSetting(key, on) end,
                onChange = function() if after then after() end end})
            y[col] = y[col] - ROW
        end
        d.drops = {}
        local x2 = 14 + COL_W + 10
        for i, o in ipairs(self.settingDrops) do
            local key, values, after = o[1], o[3], o[4]
            local yy = y[2] - 6 - (i - 1) * 32
            local fl = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fl:SetPoint("TOPLEFT", d, "TOPLEFT", x2 + 4, yy - 6)
            fl:SetText(T(o[2]))
            d.drops[key] = ONE.Kit:Dropdown(d, {point = "TOPLEFT", x = x2 + 110, y = yy, width = 160,
                options = function()
                    local out = {}
                    for _, v in ipairs(values()) do out[#out + 1] = {value = v[1], text = v[2]} end
                    return out
                end,
                get = function() return Chat:Settings()[key] end,
                set = function(v) Chat:Settings()[key] = v if after then after(v) end end, onChange = function() end})
        end
        d.font = d.drops.fontSize
        ONE.Themes:RegisterWindow(d, bg, title)
        if ONE.Themes.StyleTree then ONE.Themes:StyleTree(d) end
        if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripChatSettings") end
        self.settings = d
    end
    for _, box in ipairs(d.checks) do if box.Refresh then box:Refresh() end end
    for _, dd in pairs(d.drops) do if dd.Refresh then dd:Refresh() end end
    d:Show()
end
