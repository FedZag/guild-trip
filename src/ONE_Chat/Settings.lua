-- Guild Trip Chat: Einstellungen. Seit 21.11.2026 (Nutzer: "separate Einstellmöglichkeiten direkt im Chat")
-- direkt im Chatfenster (Zahnrad); Optionen › Chat im Hauptfenster fuehrt nur noch dorthin.
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
    {"jumpButton", "Knopf „Zum WoW-Chat“", "Kleiner Knopf oben im Chat: schließt diesen Chat und zeigt den WoW-Chat – auch wenn er ersetzt ist (nur vorübergehend). Zurück über die Sprechblase am WoW-Chat.",
        function() UI:RefreshJump() end, 1},
    {"whisperHere", "Flüstern im Guild-Trip-Chat öffnen", "„Flüstern“ im Namens-Menü öffnet das Gespräch im Guild-Trip-Chat statt im WoW-Chat.", nil, 1},
    {"blink", "Neue Nachrichten blinken", "Gespräche mit ungelesenen Nachrichten blinken; bei Flüstern blinkt auch das WoW-Symbol in der Taskleiste.", function() UI:Refresh() end, 1},
    {"whisperSound", "Ton bei Flüsternachrichten", "Nur, wenn das Gespräch gerade nicht offen ist.", nil, 1},
    {"guildSound", "Ton bei Gildennachrichten", "Leises „Pling“, höchstens alle paar Sekunden einmal – nur, wenn die Gilde gerade nicht offen ist.", nil, 1},
    {"groupSound", "Ton bei Gruppennachrichten", "Leises „Pling“, höchstens alle paar Sekunden einmal – nur, wenn die Gruppe gerade nicht offen ist.", nil, 1},
    {"sentSound", "Ton beim Senden", nil, nil, 1},
    {"stamps", "Uhrzeit vor jeder Nachricht", nil, function() UI:Render() end, 2},
    {"fadeLines", "Alte Zeilen verblassen", "Wie im WoW-Chat: Zeilen verschwinden nach einer Minute. Mausrad holt sie zurück.", Look, 2},
    {"locked", "Fenster festsetzen", "Nicht mehr verschieben oder in der Größe ändern.", Look, 2},
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
    if key == "whisperHere" or key == "launcher" or key == "keepHistory" or key == "jumpButton" then return s[key] ~= false end
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

-- Alle Chat-Einstellungen als Liste (Nutzer 21.11.2026: "separate Einstellmöglichkeiten direkt im Chat und
-- nicht im Hauptfenster des Addons"). Die Liste zeigt das Zahnrad im Chatfenster (UI:OpenSettings);
-- Optionen › Chat im Hauptfenster hat nur noch einen Knopf, der dorthin fuehrt.
-- Spalte 1 = "Verhalten & Töne", Spalte 2 = "Aussehen"
local SECTION = {"Verhalten & Töne", "Aussehen"}
UI.SECTION = SECTION
local function Messenger() return Chat:Settings().style ~= "classic" end
local function Classic() return not Messenger() end
-- nur im alten Stil sinnvoll (Messenger zeigt Uhrzeit immer, verblasst nichts)
UI.classicOnly = {stamps = true, fadeLines = true, spacing = true, blink = true}
function UI:SettingDefs()
    local out = {}
    local function Add(o) o.category, o.module = "chat", "chat" out[#out + 1] = o end
    -- Hinweis, wenn ElvUI & Co. laufen (doppelte Toene, Ausblenden gesperrt)
    Add({id = "chatOther", kind = "text", order = 1,
        visible = function() return Chat.OtherChatAddon() ~= nil end,
        label = function()
            local other = Chat.OtherChatAddon()
            return other and ("|cffffd100" .. T("%s erkannt:", other) .. "|r " .. T("Töne ggf. dort oder hier abschalten, sonst klingt es doppelt. „WoW-Chat ausblenden“ bleibt gesperrt.")) or ""
        end})
    Add({id = "chat.style", section = "Stil", order = 5, kind = "dropdown", label = "Stil des Chats", width = 220,
        tooltip = "Messenger: Gesprächsliste und Sprechblasen. Klassisch: Reiter oben, Zeilen wie im WoW-Chat. Wirkt nach /reload.",
        options = function() return {{value = "messenger", text = T("Messenger")}, {value = "classic", text = T("Klassisch")}} end,
        get = function() return Chat:Settings().style end,
        set = function(v) Chat:Settings().style = v == "classic" and "classic" or "messenger" end,
        reload = true,
        onChange = function() ONE:Print(T("Der Stil des Chats ändert sich nach /reload.")) end})
    for i, c in ipairs(self.settingChecks) do
        local key, after, col = c[1], c[4], c[5] or 1
        Add({id = "chat." .. key, section = SECTION[col], order = col * 100 + i, label = c[2], tooltip = c[3],
            visible = UI.classicOnly[key] and Classic or nil,
            get = function() return UI.SettingOn(key) end,
            set = function(on) UI.SetSetting(key, on) end,
            onChange = after})
    end
    -- Emojis (Messenger)
    local function Emo(key, label, tip, order)
        Add({id = "chat." .. key, section = "Emojis", order = order, label = label, tooltip = tip, visible = Messenger,
            get = function() return Chat:Settings()[key] ~= false end,
            set = function(on) Chat:Settings()[key] = on and true or false end,
            onChange = function() UI:Render() UI:Refresh() end})
    end
    Emo("emojiImages", "Emojis als Bilder zeigen", "Codes wie :daumen: und WoW-Zeichen wie {Stern} erscheinen als Bild. Aus: der Text bleibt, wie er gesendet wurde.", 301)
    Emo("asciiSmileys", "Smileys wie :) als Bild", "Auch getippte Smileys (:) :D ;) <3 …) werden zum Bild – nur, wenn sie frei stehen.", 302)
    Emo("bigEmoji", "Nur Emojis: groß zeigen", "Besteht eine Nachricht nur aus 1–3 Emojis, werden sie groß und ohne Blase gezeigt – wie im Messenger.", 303)
    Add({id = "chat.bubbleColors", section = SECTION[2], order = 149, label = "Blasen farbig je Art", visible = Messenger,
        tooltip = "Sprechblasen der anderen leicht in der Farbe ihrer Art: Gilde grün, Gruppe blau, Flüstern rosa … Eigene bleiben in der Leuchtfarbe.",
        get = function() return Chat:Settings().bubbleColors ~= false end,
        set = function(on) Chat:Settings().bubbleColors = on and true or false end,
        onChange = function() UI:Render() end})
    -- Farben der Blasen (Nutzer 22.11.2026: "verschiedene Farbeinstellungen anbieten")
    local function Repaint() UI:Render() if chat.Messenger and chat.Messenger.LayoutLog then pcall(chat.Messenger.LayoutLog, chat.Messenger) end end
    Add({id = "chat.bubbleStrength", section = SECTION[2], order = 149.1, kind = "dropdown", label = "Stärke der Blasenfarbe", width = 180,
        visible = Messenger, tooltip = "Wie deutlich die Sprechblasen gefärbt sind.",
        options = function()
            local names = {T("dezent"), T("normal"), T("kräftig"), T("sehr kräftig")}
            local out = {}
            for i, v in ipairs(chat.Messenger and chat.Messenger.STRENGTHS or {1}) do out[#out + 1] = {value = v, text = names[i]} end
            return out
        end,
        get = function() return chat.Messenger and chat.Messenger.BubbleStrength() or 1 end,
        set = function(v) Chat:Settings().bubbleStrength = v ~= 1 and v or nil end,
        onChange = Repaint})
    Add({id = "chat.ownBubble", section = SECTION[2], order = 149.2, kind = "button", label = "Farbe meiner Blasen …", visible = Messenger,
        tooltip = "Farbe deiner eigenen Sprechblasen. Ohne Auswahl: die Leuchtfarbe des Chats.",
        onClick = function()
            local p = chat.Messenger and chat.Messenger:Palette()
            UI.PickChatColor("ownBubble", p and p.glow, Repaint)
        end})
    Add({id = "chat.bubbleText", section = SECTION[2], order = 149.3, kind = "button", label = "Textfarbe in den Blasen …", visible = Messenger,
        tooltip = "Farbe der Nachrichten in den Sprechblasen. Ohne Auswahl: weiß.",
        onClick = function() UI.PickChatColor("bubbleText", {1, 1, 1}, Repaint) end})
    Add({id = "chat.bubbleReset", section = SECTION[2], order = 149.4, kind = "button", label = "Blasenfarben zurücksetzen",
        visible = function() local s = Chat:Settings() return Messenger() and (s.ownBubble ~= nil or s.bubbleText ~= nil or s.bubbleStrength ~= nil) end,
        tooltip = "Eigene Blasenfarbe, Textfarbe und Stärke wieder wie am Anfang.",
        onClick = function()
            local s = Chat:Settings()
            s.ownBubble, s.bubbleText, s.bubbleStrength = nil, nil, nil
            Repaint()
            if UI.LayoutSettingsPanel then UI:LayoutSettingsPanel() end
        end})
    Add({id = "chat.classIcons", section = SECTION[2], order = 148, label = "Klassen-Symbol vor dem Namen", visible = Messenger,
        tooltip = "In den Sprechblasen ein kleines rundes Klassen-Symbol vor dem Namen – wenn WoW die Klasse kennt.",
        get = function() return Chat:Settings().classIcons ~= false end,
        set = function(on) Chat:Settings().classIcons = on and true or false end,
        onChange = function() UI:Render() end})
    self:RegisterLookSettings(Add, SECTION[2])
    for i, o in ipairs(self.settingDrops) do
        local key, values, after = o[1], o[3], o[4]
        Add({id = "chat." .. key, section = SECTION[2], order = 150 + i, kind = "dropdown", label = o[2], width = 180,
            visible = UI.classicOnly[key] and Classic or nil,
            options = function()
                local list = {}
                for _, v in ipairs(values()) do list[#list + 1] = {value = v[1], text = v[2]} end
                return list
            end,
            get = function() return Chat:Settings()[key] end,
            set = function(v) Chat:Settings()[key] = v if after then after(v) end end})
    end
    table.sort(out, function(a, b) return (a.order or 0) < (b.order or 0) end)
    return out
end

-- Farbwahl von WoW fuer eine Chat-Farbe (Schluessel in den Chat-Einstellungen); Abbrechen stellt zurueck
function UI.PickChatColor(key, default, after)
    local cpf = _G.ColorPickerFrame
    if not cpf then return false end
    local s = Chat:Settings()
    local old = s[key]
    local start = (chat.Messenger and chat.Messenger.ValidColor(old)) or default or {1, 1, 1}
    local function Done() if after then pcall(after) end if UI.LayoutSettingsPanel then pcall(UI.LayoutSettingsPanel, UI) end end
    local function Current()
        local r, g, b = cpf:GetColorRGB()
        s[key] = {r, g, b}
        Done()
    end
    local function Cancel() s[key] = old Done() end
    if cpf.SetupColorPickerAndShow then
        cpf:SetupColorPickerAndShow({r = start[1], g = start[2], b = start[3], hasOpacity = false, swatchFunc = Current, cancelFunc = Cancel})
    else
        cpf.func, cpf.cancelFunc, cpf.hasOpacity = Current, Cancel, false
        if cpf.SetColorRGB then cpf:SetColorRGB(start[1], start[2], start[3]) end
        if ShowUIPanel then ShowUIPanel(cpf) else cpf:Show() end
    end
    return true
end

-- Optionen › Chat im Hauptfenster: nur noch der Weg in den Chat
function UI:RegisterSettings()
    local O = ONE.UI
    if not (O and O.AddSetting) then return false end
    local function Add(o) o.category, o.module = "chat", "chat" O:AddSetting(o) end
    for _, d in ipairs(self:SettingDefs()) do if d.id == "chatOther" then Add(d) end end
    Add({id = "chat.openSettings", kind = "button", order = 2, label = "Chat-Einstellungen öffnen",
        tooltip = "Alle Einstellungen des Chats stehen jetzt direkt im Chatfenster (Zahnrad oben rechts).",
        onClick = function()
            if O.frame and O.frame.Hide then O.frame:Hide() end
            UI:Show()
            UI:OpenSettings(true)
        end})
    return true
end

-- Aussehen nur fuer den Chat (Nutzer 19.11.2026): Glas, Blizzard oder Schlicht – unabhaengig vom
-- Hauptfenster – und im Glas eigene Farben. Ersetzt den frueheren Schalter "Schlichtes Aussehen".
UI.lookOptions = {
    {"auto", "Wie das Hauptfenster"}, {"glass", "Glas"}, {"native", "Blizzard"}, {"flat", "Schlicht (passend zu ElvUI & Co.)"},
}
function UI.LookSetting()
    local s = Chat:Settings()
    if s.look == "glass" or s.look == "native" or s.look == "flat" then return s.look end
    if s.flat == true then return "flat" end
    return "auto"
end
function UI.SetLook(v)
    local s = Chat:Settings()
    s.look = (v == "glass" or v == "native" or v == "flat") and v or nil
    -- alter Schalter: "Wie das Hauptfenster" erkennt ElvUI & Co. wieder selbst
    s.flat = nil
end
-- Eigene Glas-Farben anlegen: startet mit den Farben des Hauptfensters
function UI.ChatGlass()
    local s = Chat:Settings()
    if type(s.glass) ~= "table" then
        local main = ONE.Glass and ONE.Glass.Store and ONE.Glass.Store() or {}
        local function Copy(c) return type(c) == "table" and {c[1], c[2], c[3]} or nil end
        s.glass = {skin = main.skin, tint = Copy(main.tint), glow = Copy(main.glow), alpha = main.alpha}
    end
    return s.glass
end
function UI.GlassSkinSetting()
    local g = Chat:GlassStore()
    return g and g.skin or "main"
end
function UI.SetGlassSkin(v)
    local G = ONE.Glass
    if v == "main" or not G then
        Chat:Settings().glass = nil
        if G and G.ApplyAll then G:ApplyAll() end
        return
    end
    G:SetSkin(v, UI.ChatGlass())
end
function UI:RegisterLookSettings(Add, section)
    -- Messenger ist immer Glas (eigene Farben moeglich); "Aussehen des Chats" gilt nur fuer den alten Stil
    local function IsGlass() return Messenger() or Chat:Look() == "glass" end
    Add({id = "chat.look", section = section, order = 140, kind = "dropdown", label = "Aussehen des Chats", width = 220,
        visible = Classic, reload = true,
        tooltip = "Nur für das Chatfenster. Wirkt nach /reload.",
        options = function()
            local out = {}
            for _, o in ipairs(UI.lookOptions) do out[#out + 1] = {value = o[1], text = T(o[2])} end
            return out
        end,
        get = function() return UI.LookSetting() end,
        set = function(v) UI.SetLook(v) end,
        onChange = function() ONE:Print(T("Das Aussehen des Chats ändert sich nach /reload.")) end})
    Add({id = "chat.glassSkin", section = section, order = 141, kind = "dropdown", label = "Glas-Farben des Chats", width = 220,
        visible = IsGlass,
        options = function()
            local out = {{value = "main", text = T("Wie das Hauptfenster")}}
            local G = ONE.Glass
            for _, id in ipairs(G and G.order or {}) do
                out[#out + 1] = {value = id, text = id == "custom" and T("Eigene Farben") or T(G.skins[id].name)}
            end
            return out
        end,
        get = function() return UI.GlassSkinSetting() end,
        set = function(v) UI.SetGlassSkin(v) end})
    Add({id = "chat.glassGlow", section = section, order = 142, kind = "button", label = "Leuchtfarbe des Chats …",
        visible = IsGlass, tooltip = "Farbe für Auswahl, Linien und Knöpfe – nur im Chat.",
        onClick = function() if ONE.Glass then ONE.Glass:PickColor("glow", UI.ChatGlass()) end end})
    Add({id = "chat.glassTint", section = section, order = 143, kind = "button", label = "Glasfarbe des Chats …",
        visible = IsGlass, tooltip = "Tönung des Chat-Glases. Die Deckkraft stellt „Hintergrund“ ein.",
        onClick = function() if ONE.Glass then ONE.Glass:PickColor("tint", UI.ChatGlass()) end end})
end

-- ===== Einstellungen im Chatfenster (Zahnrad) =====
-- Liegt ueber dem Gespraech, Glas wie der Chat. Mausrad blaettert. Schalter = Haken, Auswahl = Knopf zum
-- Durchschalten (Linksklick weiter, Rechtsklick zurueck), Farbknoepfe oeffnen die Farbwahl.
function UI:OpenSettings(force)
    local f = self.frame
    if not f then self:Show() f = self.frame end
    if not f then return end
    local panel = self:BuildSettingsPanel()
    if panel:IsShown() and not force then panel:Hide() return end
    self.settingsScroll = 0
    panel:Show()
    self:LayoutSettingsPanel()
end
function UI:BuildSettingsPanel()
    if self.settingsPanel then return self.settingsPanel end
    local f = self.frame
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -30)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    if panel.SetFrameLevel and f.GetFrameLevel then panel:SetFrameLevel((f:GetFrameLevel() or 1) + 40) end
    panel:EnableMouse(true)
    if panel.SetClipsChildren then panel:SetClipsChildren(true) end
    local G = ONE.Glass
    -- Glas nur, wenn der Chat Glas ist (Messenger immer); Knoepfe dann ebenfalls aus Glas
    local glass = G and G.Surface and (UI.glass or UI.style == "messenger")
    if glass then G.forceLook = "glass" end
    if glass then
        local sf = G:Surface(panel, "card")
        if sf then
            sf.store = function() return Chat:GlassStore() end
            sf.onPaint = function(s2, p) s2.fill:SetColor(p.tint[1], p.tint[2], p.tint[3], .97) end
            G:Paint(sf)
        end
    else
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(panel)
        bg:SetColorTexture(.05, .06, .08, .97)
    end
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -10)
    title:SetText(T("Chat-Einstellungen"))
    panel.title = title
    panel.done = ONE.Widgets:Button(panel, T("Fertig"), 70, 22, "TOPRIGHT", -10, -8, function() panel:Hide() end, "primary")
    if glass then G.forceLook = nil end
    panel.glass = glass
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        UI.settingsScroll = math.max(0, (UI.settingsScroll or 0) - delta * 40)
        UI:LayoutSettingsPanel()
    end)
    panel.rows = {}
    panel:Hide()
    self.settingsPanel = panel
    if chat.Messenger then chat.Messenger.settingsPanel = panel end
    return panel
end
-- Text eines Auswahlfeldes: "Schriftgröße: 14"
function UI.SettingValueText(d)
    local cur = d.get and d.get()
    for _, o in ipairs(d.options and d.options() or {}) do
        if o.value == cur then return o.text end
    end
    return tostring(cur or "–")
end
local function Label(v) if type(v) == "function" then return v() end return T(v or "") end
function UI:SettingsRow(i)
    local panel = self.settingsPanel
    local r = panel.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel)
    r:SetHeight(24)
    r.head = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.head:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 2, 2)
    local ok, cb = pcall(CreateFrame, "CheckButton", nil, r, "UICheckButtonTemplate")
    if not ok or not cb then cb = CreateFrame("CheckButton", nil, r) end
    cb:SetSize(22, 22)
    cb:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.check = cb
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.text:SetJustifyH("LEFT")
    if ONE.Fit then ONE.Fit:Line(r.text, r) end
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.label:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.label:SetJustifyH("LEFT")
    local G = ONE.Glass
    if panel.glass then G.forceLook = "glass" end
    r.button = ONE.Widgets:Button(r, "", 150, 22, "RIGHT", 0, 0, nil)
    if panel.glass then G.forceLook = nil end
    if r.button.RegisterForClicks then r.button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    r.note = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.note:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.note:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.note:SetJustifyH("LEFT")
    panel.rows[i] = r
    return r
end
local function RowTip(owner, d)
    owner:SetScript("OnEnter", function(btn)
        if not (GameTooltip and d.tooltip) then return end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(Label(d.label), 1, .82, 0)
        GameTooltip:AddLine(T(d.tooltip), .9, .9, .9, true)
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
-- Zeilen der Einstellungen: Abschnitt-Ueberschriften + Eintraege (nur sichtbare)
function UI:SettingsLines()
    local lines, last = {}, nil
    for _, d in ipairs(self:SettingDefs()) do
        if not d.visible or d.visible() then
            local sec = d.section
            if sec and sec ~= last then lines[#lines + 1] = {head = T(sec)} last = sec end
            lines[#lines + 1] = {def = d}
        end
    end
    if self.needReload then lines[#lines + 1] = {reload = true} end
    return lines
end
function UI:LayoutSettingsPanel()
    local panel = self.settingsPanel
    if not (panel and panel:IsShown()) then return end
    local W = (panel:GetWidth() or 300) - 28
    local H = panel:GetHeight() or 300
    local lines = self:SettingsLines()
    local y = 42 - (self.settingsScroll or 0)
    local n = 0
    for i, l in ipairs(lines) do
        n = i
        local r = self:SettingsRow(i)
        local h = l.head and 26 or 26
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -y)
        r:SetWidth(W)
        r:SetHeight(h)
        for _, part in ipairs({r.head, r.check, r.text, r.label, r.button, r.note}) do part:Hide() end
        if l.head then
            r.head:SetText(l.head)
            r.head:Show()
        elseif l.reload then
            r.note:SetText(T("Geändert: wirkt nach dem Neuladen."))
            r.note:Show()
            r.button:SetText(T("Jetzt neu laden"))
            r.button:SetWidth(130)
            r.button:SetScript("OnClick", function() if type(ReloadUI) == "function" then ReloadUI() end end)
            r.button:Show()
        else
            local d = l.def
            if d.kind == "text" then
                r.note:SetText(Label(d.label))
                r.note:Show()
            elseif d.kind == "dropdown" then
                r.label:SetText(Label(d.label))
                r.label:Show()
                local bw = math.min(170, math.max(110, math.floor(W * .45)))
                r.button:SetWidth(bw)
                r.button:SetText(UI.SettingValueText(d))
                r.button:SetScript("OnClick", function(_, button)
                    local opts = d.options()
                    local cur, idx = d.get(), 1
                    for k, o in ipairs(opts) do if o.value == cur then idx = k end end
                    idx = button == "RightButton" and ((idx - 2) % #opts + 1) or (idx % #opts + 1)
                    d.set(opts[idx].value)
                    if d.onChange then pcall(d.onChange, opts[idx].value) end
                    if d.reload then UI.needReload = true end
                    UI:LayoutSettingsPanel()
                end)
                RowTip(r.button, {label = d.label, tooltip = (d.tooltip and (T(d.tooltip) .. "\n") or "") .. T("Linksklick: weiter · Rechtsklick: zurück")})
                r.button:Show()
            elseif d.kind == "button" then
                r.button:SetWidth(math.min(W, 220))
                r.button:SetText(Label(d.label))
                r.button:ClearAllPoints()
                r.button:SetPoint("LEFT", r, "LEFT", 0, 0)
                r.button:SetScript("OnClick", function() if d.onClick then pcall(d.onClick) end end)
                RowTip(r.button, d)
                r.button:Show()
            else
                r.text:SetText(Label(d.label))
                r.text:Show()
                r.check:SetChecked(d.get() and true or false)
                r.check:SetScript("OnClick", function(btn)
                    d.set(btn:GetChecked() and true or false)
                    if d.onChange then pcall(d.onChange) end
                    UI:LayoutSettingsPanel()
                end)
                RowTip(r.check, d)
                r.check:Show()
            end
            if d.kind ~= "button" then
                r.button:ClearAllPoints()
                r.button:SetPoint("RIGHT", r, "RIGHT", 0, 0)
            end
        end
        r:SetShown(y >= 36 and y + h <= H + 2)
        y = y + h + (l.head and 0 or 2)
    end
    for i = n + 1, #panel.rows do panel.rows[i]:Hide() end
    -- nicht ueber das Ende hinaus blaettern
    local total = y + (self.settingsScroll or 0) - 42
    local maxScroll = math.max(0, total - (H - 50))
    if (self.settingsScroll or 0) > maxScroll then self.settingsScroll = maxScroll self:LayoutSettingsPanel() end
end
