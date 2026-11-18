-- Guild Trip Chat: eigene Reiter anlegen und aendern (Name, welche Arten hinein, wohin man schreibt).
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local UI, Chat = chat.UI, chat.Chat

function UI:EditTab(tab)
    local d = self.editor
    if not d then
        d = CreateFrame("Frame", "GuildTripChatTabEditor", UIParent, "BackdropTemplate")
        d:SetSize(320, 330)
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
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
        d.title = title
        ONE.Widgets:CloseButton(d, "TOPRIGHT", -4, -4, function() d:Hide() end)
        local nameLabel = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLabel:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -42)
        nameLabel:SetText(T("Name"))
        local ok, name = pcall(CreateFrame, "EditBox", nil, d, "InputBoxTemplate")
        if not ok or not name then name = CreateFrame("EditBox", nil, d) end
        name:SetPoint("TOPLEFT", d, "TOPLEFT", 96, -38)
        name:SetSize(200, 22)
        name:SetAutoFocus(false)
        name:SetMaxLetters(20)
        name:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
        name:SetScript("OnEnterPressed", function(f) f:ClearFocus() end)
        d.name = name
        local kindsLabel = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        kindsLabel:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -72)
        kindsLabel:SetText(T("Was hinein soll"))
        d.state = {kinds = {}, send = nil}
        d.checks = {}
        for i, k in ipairs(Chat.KINDS) do
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            local box = ONE.Kit:Check(d, {point = "TOPLEFT", x = 14 + col * 150, y = -90 - row * 24, label = k.label,
                get = function() return d.state.kinds[k.key] == true end,
                set = function(on) d.state.kinds[k.key] = on and true or nil end,
                onChange = function() end})
            d.checks[#d.checks + 1] = box
        end
        local sendLabel = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sendLabel:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -246)
        sendLabel:SetText(T("Schreiben in"))
        d.send = ONE.Kit:Dropdown(d, {point = "TOPLEFT", x = 96, y = -242, width = 200,
            options = function()
                local out = {{value = "", text = T("nur lesen")}}
                for _, k in ipairs(Chat.KINDS) do
                    if k.send and k.key ~= "whisper" then out[#out + 1] = {value = k.key, text = k.label} end
                end
                return out
            end,
            get = function() return d.state.send or "" end,
            set = function(v) d.state.send = v ~= "" and v or nil end})
        d.save = ONE.Widgets:Button(d, T("Speichern"), 92, 24, "BOTTOMRIGHT", -16, 14, function()
            local saved = Chat:SaveTab({id = d.tabId, label = d.name:GetText() or "", kinds = d.state.kinds, send = d.state.send})
            if not saved then ONE:Print(T("Gib dem Reiter einen Namen.")) return end
            d:Hide()
            UI:Show(saved.id)
        end, "primary")
        d.remove = ONE.Widgets:Button(d, T("Löschen"), 92, 24, "BOTTOMLEFT", 16, 14, function()
            if d.tabId and Chat:RemoveTab(d.tabId) then
                if UI.current == d.tabId then UI.current = "all" end
                d:Hide()
                UI:Show()
            end
        end)
        ONE.Themes:RegisterWindow(d, bg, title)
        if ONE.Themes.StyleTree then ONE.Themes:StyleTree(d) end
        if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripChatTabEditor") end
        self.editor = d
    end
    d.tabId = tab and tab.id or nil
    d.title:SetText(tab and T("Reiter ändern") or T("Neuer Reiter"))
    d.name:SetText(tab and tab.label or "")
    d.state.kinds = {}
    for k, on in pairs(tab and tab.kinds or {guild = true}) do d.state.kinds[k] = on end
    d.state.send = tab and tab.send or nil
    for _, box in ipairs(d.checks) do if box.Refresh then box:Refresh() end end
    if d.send.Refresh then d.send:Refresh() end
    if tab then d.remove:Show() else d.remove:Hide() end
    d:Show()
    d.name:SetFocus()
end
