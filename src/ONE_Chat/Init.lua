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
        -- Nachrichten empfangen (auch bei geschlossenem Fenster: Verlauf und Zaehler)
        -- Verlauf vom letzten Mal zurueckholen (Optionen › Chat › "Verlauf nach Neustart behalten")
        pcall(Chat.LoadHistory, Chat)
        local frame = CreateFrame("Frame")
        for event in pairs(Chat.kindByEvent) do pcall(frame.RegisterEvent, frame, event) end
        pcall(frame.RegisterEvent, frame, "PLAYER_LOGOUT")
        frame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_LOGOUT" then pcall(Chat.SaveHistory, Chat) return end
            Chat:OnEvent(event, ...)
        end)
        chat.eventFrame = frame
        Chat.listeners[#Chat.listeners + 1] = function(entry, views) UI:OnMessage(entry, views) end

        ONE:RegisterSlash("chat", function() UI:Toggle() end, T("Guild-Trip-Chat öffnen/schließen"))
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
                        UI:Show(Chat:OpenWhisper(name))
                        if UI.input then UI.input:SetFocus() end
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
        if chat.Loot then chat.Loot:Initialize() end

        -- Einstellungen: Optionen › Chat (Zahnrad im Chatfenster springt dorthin)
        UI:RegisterSettings()
        if s.openOnLogin and C_Timer and C_Timer.After then C_Timer.After(2, function() UI:Show() end) end
    end,
    -- Fuer andere Module: Gespraech mit einer Person oeffnen
    OpenWhisper = function(_, name) UI:Show(Chat:OpenWhisper(name)) end,
    Toggle = function() UI:Toggle() end,
})
