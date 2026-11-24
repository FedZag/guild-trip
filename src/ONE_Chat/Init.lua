local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI
ONE.ns = ONE.ns or {}
ONE.ns.chat = chat

ONE:RegisterModule("chat", {
    title = "Chat",
    Initialize = function()
        local s = Chat:Settings()
        -- Messenger-Stil (Standard seit 21.11.2026) ersetzt die Fenster-Funktionen; "Klassisch" bleibt waehlbar
        if s.style ~= "classic" and chat.Messenger then chat.Messenger:Install() end
        -- Nachrichten empfangen (auch bei geschlossenem Fenster: Verlauf und Zaehler)
        -- Verlauf vom letzten Mal zurueckholen (Optionen › Chat › "Verlauf nach Neustart behalten")
        pcall(Chat.LoadHistory, Chat)
        local frame = CreateFrame("Frame")
        for event in pairs(Chat.kindByEvent) do pcall(frame.RegisterEvent, frame, event) end
        pcall(frame.RegisterEvent, frame, "PLAYER_LOGOUT")
        -- Online-Anzeige frisch halten (Gildenliste, Freunde, Battle.net)
        local presence = {GUILD_ROSTER_UPDATE = true, FRIENDLIST_UPDATE = true, BN_FRIEND_INFO_CHANGED = true,
            BN_FRIEND_INVITE_ADDED = true, BN_FRIEND_INVITE_REMOVED = true, BN_FRIEND_INVITE_LIST_INITIALIZED = true,
            BN_FRIEND_LIST_SIZE_CHANGED = true}
        for event in pairs(presence) do pcall(frame.RegisterEvent, frame, event) end
        Chat.presenceEvents = presence
        frame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_LOGOUT" then pcall(Chat.SaveHistory, Chat) return end
            if Chat.presenceEvents[event] then
                -- gebuendelt: WoW schickt diese Meldungen oft mehrmals hintereinander
                if Chat.visible and not Chat.presencePending and C_Timer and C_Timer.After then
                    Chat.presencePending = true
                    C_Timer.After(.5, function() Chat.presencePending = nil if Chat.visible and UI.Refresh then UI:Refresh() end end)
                end
                return
            end
            Chat:OnEvent(event, ...)
        end)
        chat.eventFrame = frame
        Chat.listeners[#Chat.listeners + 1] = function(entry, views, update) UI:OnMessage(entry, views, update) end

        ONE:RegisterSlash("chat", function() UI:Toggle() end, T("Guild-Trip-Chat öffnen/schließen"))
        ONE:RegisterSlash("chatdiag", function()
            local lines = UI:Diag()
            ONE.db.chatDiag = {time = time and time() or 0, lines = lines}
            for _, l in ipairs(lines) do ONE:Print(l) end
        end, T("Chat-Aussehen prüfen (für Fehlersuche)"))
        -- Minimap-Hinweis "neue Fluesternachricht" oeffnet das Chatfenster
        if ONE.UI and ONE.UI.AddAlias then
            ONE.UI:AddAlias("chat", "home", function()
                local function Open()
                    if ONE.UI.frame and ONE.UI.frame.Hide then ONE.UI.frame:Hide() end
                    UI:Show(Chat.lastWhisperFrom and Chat.WhisperView(Chat.lastWhisperFrom) or nil)
                end
                if C_Timer and C_Timer.After then C_Timer.After(0, Open) else Open() end
            end)
        end
        -- Namens-Menue: "Fluestern" oeffnet das Gespraech hier (abschaltbar)
        if ONE.PlayerMenu then
            ONE.PlayerMenu:Register({id = "whisper", order = 10, label = "Flüstern",
                available = function(_, ctx) return not (type(ctx) == "table" and ctx.online == false) end,
                run = function(name)
                    if Chat:Settings().whisperHere ~= false and ONE:IsEnabled("chat") then
                        UI:OpenInput(Chat:OpenWhisper(name))
                        return
                    end
                    if type(ChatFrame_SendTell) == "function" then return ChatFrame_SendTell(name) end
                end})
        end

        -- Sichtbarer Knopf am WoW-Chat (mit Zaehler); folgt dem Oeffnen/Schliessen und neuen Nachrichten
        local L = chat.Launcher
        if L then
            L:Build()
            L:Update()
            Chat.listeners[#Chat.listeners + 1] = function() L:Update() end
            local show, hide = UI.Show, UI.Hide
            UI.Show = function(...) local r = show(...) L:Update() return r end
            UI.Hide = function(...) local r = hide(...) L:Update() return r end
        end

        if chat.Hider then chat.Hider:Initialize() end
        -- Randleiste statt Fenster (Chat-Einstellungen, Standard aus)
        if chat.Rail then chat.Rail:Apply() Chat.listeners[#Chat.listeners + 1] = function() chat.Rail:Update() end end
        if chat.Loot then chat.Loot:Initialize() end
        -- Eigene Meldungen (/trip …) auch hier zeigen, wenn der WoW-Chat ersetzt ist – sonst landen sie im
        -- versteckten WoW-Chat (Spieltest 20.11.2026: "/trip planinfo" ohne Ausgabe)
        Chat.HookPrint()
        -- ... und die Meldungen ANDERER Addons (DBM, Questie …), die sonst im versteckten WoW-Chat verschwinden
        Chat.HookAddonLines()

        -- Einstellungen: Optionen › Chat (Zahnrad im Chatfenster springt dorthin)
        UI:RegisterSettings()
        if s.openOnLogin and not (chat.Rail and chat.Rail.Active()) and C_Timer and C_Timer.After then C_Timer.After(2, function() UI:Show() end) end
    end,
    -- Fuer andere Module: Gespraech mit einer Person oeffnen
    OpenWhisper = function(_, name) UI:Show(Chat:OpenWhisper(name)) end,
    -- Fluestern mit fertigem Text (Anfragen bei Herstellern, 22.11.2026): im Guild-Trip-Chat, wenn
    -- "Fluestern hier" an ist oder der WoW-Chat ersetzt ist (sonst oeffnete sich die versteckte WoW-Zeile)
    Compose = function(_, name, text)
        if not (name and ONE:IsEnabled("chat")) then return false end
        local hidden = chat.Hider and chat.Hider.Enabled and chat.Hider:Enabled()
        if Chat:Settings().whisperHere == false and not hidden then return false end
        UI:OpenInput(Chat:OpenWhisper(name))
        local box = UI.input
        if box then
            if box.SetText then box:SetText(text or "") end
            if box.SetFocus then box:SetFocus() end
            if box.SetCursorPosition and text then box:SetCursorPosition(#text) end
        end
        return true
    end,
    -- Link ins Eingabefeld (Quests aus Planer/Kasten, 23.11.2026): aktiv, offen oder WoW-Chat ersetzt
    InsertLink = function(_, text)
        if not (text and ONE:IsEnabled("chat")) then return false end
        if UI.WoWEditActive and UI.WoWEditActive() then return false end
        local hidden = chat.Hider and chat.Hider.Enabled and chat.Hider:Enabled()
        local rail = chat.Rail and chat.Rail.Active and chat.Rail.Active()
        if not Chat.visible and (hidden or rail) then UI:OpenInput() end
        return UI:TakeLink(text, true)
    end,
    Toggle = function() UI:Toggle() end,
})
