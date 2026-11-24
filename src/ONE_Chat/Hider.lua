-- Guild Trip Chat: WoW-Chat durch den Guild-Trip-Chat ersetzen (freiwillig, jederzeit zurueck).
-- Die WoW-Chatfenster werden nicht zerstoert, sondern nur in ein unsichtbares Fenster gehaengt (kein Eingriff in
-- die Nachrichten selbst) und beim Ausschalten zurueckgesetzt. Gesperrt, solange ElvUI, Prat & Co. den Chat verwalten.
-- Enter und "/" oeffnen dann das Eingabefeld des Guild-Trip-Chats.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local Hider = {saved = {}}
chat.Hider = Hider

-- Was zum WoW-Chat gehoert (nach Namen; fehlt etwas, wird es uebersprungen)
function Hider.Names()
    local out = {"GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
        "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton"}
    local n = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    for i = 1, n do
        out[#out + 1] = "ChatFrame" .. i
        out[#out + 1] = "ChatFrame" .. i .. "Tab"
        out[#out + 1] = "ChatFrame" .. i .. "ButtonFrame"
        -- Eingabefeld haengt im klassischen Chat-Stil nicht am Chatfenster und bliebe sonst stehen
        out[#out + 1] = "ChatFrame" .. i .. "EditBox"
    end
    return out
end

function Hider:Enabled()
    local can = Chat:CanHideBlizzardChat()
    return can and Chat:Settings().hideBlizzard == true and not self.peek
end

-- ===== Springen zwischen Guild-Trip-Chat und WoW-Chat (Nutzer 22.11.2026) =====
-- Knopf im Chat: Guild-Trip-Chat zu, WoW-Chat sichtbar. Ist "WoW-Chat ersetzen" an, wird er nur
-- voruebergehend eingeblendet (self.peek, nicht gespeichert); die Einstellung bleibt. Zurueck: Sprechblase am
-- WoW-Chat, Taste oder /trip chat – sobald der Guild-Trip-Chat aufgeht, ist der WoW-Chat wieder weg.
function Hider:ToWoW()
    local replacing = Chat:CanHideBlizzardChat() and Chat:Settings().hideBlizzard == true
    if replacing then
        self.peek = true
        if InCombatLockdown and InCombatLockdown() then
            -- im Kampf nichts umhaengen: erst danach, solange bleibt der Guild-Trip-Chat offen
            self.wantApply, self.hideAfterCombat = true, true
            ONE:Print(T("Im Kampf geht das nicht – der WoW-Chat kommt gleich nach dem Kampf."))
            return false
        end
        self:Apply()
    end
    if UI.Hide then UI:Hide() end
    return true
end
-- Guild-Trip-Chat geht auf: voruebergehend gezeigten WoW-Chat wieder ausblenden
function Hider:OnChatShown()
    if not self.peek then return end
    self.peek, self.hideAfterCombat = nil, nil
    self:Apply()
end
-- kleiner Knopf in der Titelleiste des Chats (abschaltbar: Einstellung "jumpButton")
function Hider:JumpButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", function() Hider:ToWoW() end)
    b:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText(T("Zum WoW-Chat"))
        GameTooltip:AddLine(T("Schließt diesen Chat und zeigt den WoW-Chat. Zurück: Sprechblase am WoW-Chat."), .8, .8, .8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end
function Hider.JumpShown() return Chat:Settings().jumpButton ~= false end

-- Makros geblockt (Spieltest 24.11.2026: Wappen + Alt+Klick trotz eigenem Befehlsfeld): Haengen wir ChatFrame1
-- unter den versteckten Halter, feuert OnHide des noch sichtbaren Eingabefelds IN UNSEREM Aufruf. Blizzards
-- OnHide sieht "LAST_ACTIVE und IsShown()" und ruft SetLastActiveWindow -> Show + Deactivate -> SetChatType:
-- die Chat-Art wird aus Addon-Code gesetzt, jedes Makro kopiert sie (MacroExecutionManager) und gilt als
-- beruehrt - bis /reload. Darum die Eingabefelder vorher selbst verstecken: dann ist IsShown() in OnHide
-- falsch und Blizzard setzt nichts. Ein gerade benutztes Feld (Fokus) bleibt unangetastet.
function Hider.HideEditBoxes()
    local n = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    for i = 1, n do
        local box = rawget(_G, "ChatFrame" .. i .. "EditBox")
        if type(box) == "table" and box.IsShown and box.Hide and box:IsShown()
            and not (box.HasFocus and box:HasFocus()) then
            box:Hide()
        end
    end
end

function Hider:Apply()
    if InCombatLockdown and InCombatLockdown() then
        self.wantApply = true
        return
    end
    local on = self:Enabled()
    if not self.holder then
        self.holder = CreateFrame("Frame", "GuildTripHiddenChat", UIParent)
        self.holder:Hide()
    end
    if on then Hider.HideEditBoxes() end
    for _, name in ipairs(Hider.Names()) do
        local f = rawget(_G, name)
        if type(f) == "table" and f.SetParent and f.GetParent then
            if on and not self.saved[name] then
                self.saved[name] = f:GetParent() or UIParent
                f:SetParent(self.holder)
            elseif not on and self.saved[name] then
                f:SetParent(self.saved[name])
                self.saved[name] = nil
            end
        end
    end
    self:Bind(on)
    if on then
        -- Ohne WoW-Chat muss der eigene Chat da sein
        local rail = chat.Rail and chat.Rail.Active and chat.Rail.Active()
        if UI.Show and not rail and not (UI.frame and UI.frame:IsShown()) then UI:Show() end
    end
    if UI.RefreshLauncher then UI:RefreshLauncher() end
end

-- Enter und "/" oeffnen das Eingabefeld des Guild-Trip-Chats
function Hider:Bind(on)
    if not self.opener then
        local b = CreateFrame("Button", "GuildTripChatOpener", UIParent)
        b:SetScript("OnClick", function()
            local text = Hider.pendingText
            Hider.pendingText = nil
            UI:OpenInput(nil, text)
        end)
        self.opener = b
        local slash = CreateFrame("Button", "GuildTripChatOpenerSlash", UIParent)
        slash:SetScript("OnClick", function() UI:OpenInput(nil, "/") end)
        self.openerSlash = slash
    end
    if not (SetOverrideBindingClick and ClearOverrideBindings) then return end
    ClearOverrideBindings(self.opener)
    if on then
        pcall(SetOverrideBindingClick, self.opener, false, "ENTER", "GuildTripChatOpener")
        pcall(SetOverrideBindingClick, self.opener, false, "NUMPADENTER", "GuildTripChatOpener")
        pcall(SetOverrideBindingClick, self.opener, false, "/", "GuildTripChatOpenerSlash")
    end
end

-- ===== WoW will sein (verstecktes) Eingabefeld oeffnen (22.11.2026) =====
-- Antworten-Taste (R), "Fluestern" im WoW-Rechtsklick-Menue, Freundesliste, andere Addons (ChatFrame_OpenChat):
-- Ist der WoW-Chat ersetzt, landet die Eingabe sonst im unsichtbaren WoW-Feld. Stiller Nach-Hook: stattdessen
-- das passende Gespraech hier oeffnen und den Text in unser Eingabefeld.
function Hider.WhisperFromText(text) return Chat.WhisperCommand(text) end
function Hider:TakeInput(text, whisperTo)
    if not self:Enabled() then return false end
    local function Go()
        local name, rest = whisperTo, nil
        if not name then name, rest = Hider.WhisperFromText(text) end
        if name and name ~= "" then
            UI:OpenInput(Chat:OpenWhisper(name), rest or "")
        else
            UI:OpenInput(nil, text)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Go) else Go() end
    return true
end
function Hider:HookOpeners()
    if self.openersHooked or type(hooksecurefunc) ~= "function" then return end
    self.openersHooked = true
    if type(ChatFrame_OpenChat) == "function" then
        hooksecurefunc("ChatFrame_OpenChat", function(text) Hider:TakeInput(text) end)
    end
    if type(ChatFrame_SendTell) == "function" then
        hooksecurefunc("ChatFrame_SendTell", function(name) if type(name) == "string" then Hider:TakeInput("", name) end end)
    end
    for _, fn in ipairs({"ChatFrame_ReplyTell", "ChatFrame_ReplyTell2"}) do
        if type(rawget(_G, fn)) == "function" then
            hooksecurefunc(fn, function()
                local last = Chat.lastWhisperFrom
                if not last and type(ChatEdit_GetLastTellTarget) == "function" then last = Call(ChatEdit_GetLastTellTarget) end
                Hider:TakeInput("", last)
            end)
        end
    end
end

function Hider:Initialize()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
        if Hider.wantApply then
            Hider.wantApply = nil
            Hider:Apply()
            if Hider.hideAfterCombat and Hider.peek then Hider.hideAfterCombat = nil if UI.Hide then UI:Hide() end end
        end
    end)
    if C_Timer and C_Timer.After then C_Timer.After(1, function() if Hider:Enabled() then Hider:Apply() end end) end
    self:HookOpeners()
    if ONE.RegisterSlash then
        -- Notausgang: bringt den WoW-Chat zurueck (auch wenn das Chatfenster mal weg sein sollte)
        ONE:RegisterSlash("wowchat", function()
            Chat:Settings().hideBlizzard = not Hider:Enabled()
            Hider.peek = nil
            Hider:Apply()
            ONE:Print(Hider:Enabled() and T("WoW-Chat ist ausgeblendet. /trip wowchat bringt ihn zurück.") or T("WoW-Chat ist wieder da."))
        end, T("WoW-Chat aus-/einblenden"))
    end
end
