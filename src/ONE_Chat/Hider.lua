-- Guild Trip Chat: WoW-Chat durch den Guild-Trip-Chat ersetzen (freiwillig, jederzeit zurueck).
-- Die WoW-Chatfenster werden nicht zerstoert, sondern nur in ein unsichtbares Fenster gehaengt (kein Eingriff in
-- die Nachrichten selbst) und beim Ausschalten zurueckgesetzt. Gesperrt, solange ElvUI, Prat & Co. den Chat verwalten.
-- Enter und "/" oeffnen dann das Eingabefeld des Guild-Trip-Chats.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI
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
    return can and Chat:Settings().hideBlizzard == true
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
        if UI.Show and not (UI.frame and UI.frame:IsShown()) then UI:Show() end
    end
    if UI.RefreshLauncher then UI:RefreshLauncher() end
end

-- Enter und "/" oeffnen das Eingabefeld des Guild-Trip-Chats
function Hider:Bind(on)
    if not self.opener then
        local b = CreateFrame("Button", "GuildTripChatOpener", UIParent)
        b:SetScript("OnClick", function(_, _, _, text)
            UI:Show()
            if UI.input then
                UI.input:SetFocus()
                if Hider.pendingText then UI.input:SetText(Hider.pendingText) Hider.pendingText = nil end
            end
        end)
        self.opener = b
        local slash = CreateFrame("Button", "GuildTripChatOpenerSlash", UIParent)
        slash:SetScript("OnClick", function()
            UI:Show()
            if UI.input then UI.input:SetFocus() UI.input:SetText("/") end
        end)
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

function Hider:Initialize()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function() if Hider.wantApply then Hider.wantApply = nil Hider:Apply() end end)
    if C_Timer and C_Timer.After then C_Timer.After(1, function() if Hider:Enabled() then Hider:Apply() end end) end
    if ONE.RegisterSlash then
        -- Notausgang: bringt den WoW-Chat zurueck (auch wenn das Chatfenster mal weg sein sollte)
        ONE:RegisterSlash("wowchat", function()
            Chat:Settings().hideBlizzard = not Hider:Enabled()
            Hider:Apply()
            ONE:Print(Hider:Enabled() and T("WoW-Chat ist ausgeblendet. /trip wowchat bringt ihn zurück.") or T("WoW-Chat ist wieder da."))
        end, T("WoW-Chat aus-/einblenden"))
    end
end
