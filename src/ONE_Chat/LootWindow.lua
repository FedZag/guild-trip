-- Guild Trip Chat: eigenes Beute-Fenster – welcher Gegenstand ist gefallen und wer hat ihn bekommen.
-- Liest die Beute-Meldungen von WoW (CHAT_MSG_LOOT), nur fuer diese Sitzung. Namen in Klassenfarbe,
-- Gegenstaende anklickbar (Tooltip beim Drueberfahren). Fenster: /trip beute oder Knopf im Chat.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI
local Loot = {entries = {}, max = 300}
chat.Loot = Loot

-- Qualitaeten: 0 grau … 5 orange
Loot.QUALITIES = {{0, "Grau"}, {1, "Weiß"}, {2, "Grün"}, {3, "Blau"}, {4, "Episch"}, {5, "Legendär"}}
local HEX_QUALITY = {["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6}

local function Settings() return Chat:Settings() end

-- Format-Text von WoW ("%s erhält Beute: %s.") in ein Lua-Muster
local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local function Patterns()
    if Loot.patterns then return Loot.patterns end
    local list = {}
    -- {globaler Name, empfaengt "Du" (kein Namensfeld)}
    for _, def in ipairs({{"LOOT_ITEM_MULTIPLE", false}, {"LOOT_ITEM", false}, {"LOOT_ITEM_PUSHED_MULTIPLE", false}, {"LOOT_ITEM_PUSHED", false},
            {"LOOT_ITEM_SELF_MULTIPLE", true}, {"LOOT_ITEM_SELF", true}, {"LOOT_ITEM_PUSHED_SELF_MULTIPLE", true}, {"LOOT_ITEM_PUSHED_SELF", true}}) do
        local fmt = rawget(_G, def[1])
        local p = Pattern(fmt)
        if p then list[#list + 1] = {pattern = p, self = def[2]} end
    end
    Loot.patterns = list
    return list
end

local function QualityOf(link)
    local q
    if type(GetItemInfo) == "function" then
        local ok, _, _, quality = pcall(GetItemInfo, link)
        if ok and type(quality) == "number" then q = quality end
    end
    if q then return q end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)") or link:match("|cn(IQ%d):")
    if hex and hex:match("^IQ") then return tonumber(hex:sub(3)) end
    return HEX_QUALITY[(hex or ""):lower()] or 1
end

-- Beute-Meldung -> Eintrag {time, who, guid, link, count, quality}; nil, wenn es keine Beute-Zeile ist (Wuerfeln usw.)
function Loot.Parse(text, author, guid)
    if type(text) ~= "string" then return nil end
    local link = text:match("(|c.-|Hitem:.-|h%[.-%]|h|r)")
    if not link then return nil end
    local who, count = nil, 1
    local matched = false
    for _, p in ipairs(Patterns()) do
        local a = text:match(p.pattern)
        if a then
            matched = true
            if p.self then who = "|self" else who = a end
            break
        end
    end
    if not matched then
        -- Globale Texte unbekannt: Meldungen mit Verfasser und Link zaehlen, Wuerfel-Zeilen nicht
        if text:find("[Ww]ürfel") or text:lower():find("roll") then return nil end
        who = (author and author ~= "") and author or "|self"
    end
    local count2 = text:match("|rx(%d+)%.?$")
    if count2 then count = tonumber(count2) end
    if who == "|self" then who = (type(UnitName) == "function" and UnitName("player")) or T("Du") end
    who = chat.Chat.Short and chat.Chat.Short(who) or who
    return {time = (type(time) == "function" and time()) or 0, who = who, guid = guid, link = link, count = count, quality = QualityOf(link)}
end

function Loot:Add(entry)
    self.entries[#self.entries + 1] = entry
    if #self.entries > self.max then table.remove(self.entries, 1) end
    if self.frame and self.frame:IsShown() then self:Render() end
end

function Loot:OnEvent(_, text, author, _, _, _, _, _, _, _, _, _, guid)
    local entry = self.Parse(text, author, guid)
    if entry then self:Add(entry) end
end

function Loot:MinQuality() return tonumber(Settings().lootMinQuality) or 2 end

function Loot:Render()
    local log = self.log
    if not log then return end
    log:Clear()
    local min, shown = self:MinQuality(), 0
    local parchment = chat.Chat.parchment
    for i = #self.entries, 1, -1 do
        local e = self.entries[i]
        if e.quality >= min then
            shown = shown + 1
            local code = chat.Chat.ClassColorCode(e.guid, parchment)
            local name = code and (code .. e.who .. "|r") or e.who
            local link = e.link
            if parchment and ONE.Book and ONE.Book.InkCodes then link = ONE.Book.InkCodes(link) end
            local stamp = type(date) == "function" and ("|cff8a8a8a" .. date("%H:%M", e.time) .. "|r  ") or ""
            if parchment and ONE.Book and ONE.Book.InkCodes then stamp = ONE.Book.InkCodes(stamp) end
            local line = stamp .. link .. (e.count > 1 and (" x" .. e.count) or "") .. "  –  |Hplayer:" .. e.who .. ":0|h" .. name .. "|h"
            if self.modern then
                local id = tonumber(tostring(link):match("item:(%d+)"))
                local icon = id and C_Item and type(C_Item.GetItemIconByID) == "function" and select(2, pcall(C_Item.GetItemIconByID, id))
                local tex = (type(icon) == "number" or type(icon) == "string") and ("|T" .. icon .. ":20:20|t  ") or ""
                local when = type(date) == "function" and date("%H:%M", e.time) or ""
                line = tex .. link .. (e.count > 1 and (" x" .. e.count) or "") .. "\n|cff8a8a8a      |Hplayer:" .. e.who .. ":0|h" .. name .. "|h|cff8a8a8a  ·  " .. when .. "|r"
            end
            local r, g, b = 1, 1, 1
            if parchment and ONE.Book and ONE.Book.Ink then r, g, b = ONE.Book.Ink(1, 1, 1) end
            log:AddMessage(line, r, g, b)
        end
    end
    if self.empty then
        if shown == 0 then self.empty:Show() else self.empty:Hide() end
    end
    if self.count then self.count:SetText(T("%d Gegenstände", shown)) end
end

function Loot:Build()
    if self.frame then return self.frame end
    -- 0.6.8: im Blizzard-Aussehen derselbe Rahmen wie Hauptfenster und Chat
    local modern = not chat.Chat:Flat() and not (ONE.Book and ONE.Book.IsActive and ONE.Book:IsActive())
    local f
    if modern then
        local ok, fr = pcall(CreateFrame, "Frame", "GuildTripLootWindow", UIParent, "PortraitFrameTemplate")
        if ok and fr then f = fr else modern = false end
    end
    self.modern = modern
    f = f or CreateFrame("Frame", "GuildTripLootWindow", UIParent, "BackdropTemplate")
    self.frame = f
    local top = 38
    if modern then
        if f.SetTitle then pcall(f.SetTitle, f, T("Beute")) end
        local hidden = type(ButtonFrameTemplate_HidePortrait) == "function" and pcall(ButtonFrameTemplate_HidePortrait, f)
        if not hidden then
            for _, m in ipairs({"SetPortraitToAsset", "SetPortraitTextureRaw"}) do
                if type(f[m]) == "function" and pcall(f[m], f, "Interface\\AddOns\\ONE_Core\\Textures\\Common\\Emblem.tga") then break end
            end
        end
        top = hidden and 30 or 58
        if type(f.CloseButton) == "table" and f.CloseButton.SetScript then f.CloseButton:SetScript("OnClick", function() f:Hide() end) end
    end
    f:SetSize(Settings().lootWidth or 380, Settings().lootHeight or 300)
    f:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(280, 160, 800, 700) end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        Settings().lootWidth, Settings().lootHeight = math.floor(frame:GetWidth() + .5), math.floor(frame:GetHeight() + .5)
    end)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(.04, .05, .07, .94)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
    title:SetText(T("Beute"))
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(title, "accent") end
    if modern then
        bg:Hide() title:Hide()
        -- eingelassene Flaeche mit Kopf "Diese Sitzung" und Filter rechts
        local box = CreateFrame("Frame", nil, f)
        box:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -top)
        box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 38)
        if box.SetFrameLevel and f.GetFrameLevel then box:SetFrameLevel(f:GetFrameLevel()) end
        if ONE.Themes and ONE.Themes.RegisterPanel then ONE.Themes:RegisterPanel(box) end
        local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        head:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -10)
        head:SetText(T("Diese Sitzung"))
        local rule = f:CreateTexture(nil, "ARTWORK")
        rule:SetHeight(1)
        rule:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -32)
        rule:SetPoint("TOPRIGHT", box, "TOPRIGHT", -6, -32)
        rule:SetColorTexture(.79, .64, .29, .45)
        self.box = box
    else
        ONE.Widgets:CloseButton(f, "TOPRIGHT", -4, -4, function() f:Hide() end)
    end
    -- Qualitaet: Knopf wechselt ab welcher Seltenheit gezeigt wird
    local q = ONE.Widgets:Button(f, "", 130, 22, "TOPRIGHT", modern and -14 or -36, modern and -(top + 6) or -8, function()
        local n = (Loot:MinQuality() + 1) % 6
        Settings().lootMinQuality = n
        Loot:UpdateQualityButton()
        Loot:Render()
    end)
    self.quality = q
    local clear = ONE.Widgets:Button(f, T("Leeren"), 70, 22, "BOTTOMRIGHT", -12, 10, function() Loot.entries = {} Loot:Render() end)
    self.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.count:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 15)
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(self.count, "soft") end
    local log = CreateFrame("ScrollingMessageFrame", "GuildTripLootLog", f)
    log:SetPoint("TOPLEFT", f, "TOPLEFT", 14, modern and -(top + 38) or -38)
    log:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, modern and 44 or 40)
    log:SetFading(false)
    log:SetMaxLines(Loot.max)
    log:SetJustifyH("LEFT")
    if log.SetSpacing then log:SetSpacing(3) end
    if log.SetFontObject then log:SetFontObject(ChatFontNormal or GameFontHighlight) end
    log:SetHyperlinksEnabled(true)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(frame, delta) if delta > 0 then frame:ScrollUp() else frame:ScrollDown() end end)
    log:SetScript("OnHyperlinkEnter", function(frame, link)
        if GameTooltip and link and link:find("^item") then GameTooltip:SetOwner(frame, "ANCHOR_CURSOR") pcall(GameTooltip.SetHyperlink, GameTooltip, link) GameTooltip:Show() end
    end)
    log:SetScript("OnHyperlinkLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    log:SetScript("OnHyperlinkClick", function(frame, link, text, button)
        local kind, rest = link:match("^(%a+):(.*)$")
        if kind == "player" and ONE.PlayerMenu then
            ONE.PlayerMenu:Open(frame, rest:match("^([^:]+)"))
            return
        end
        if type(SetItemRef) == "function" then pcall(SetItemRef, link, text, button, frame) end
    end)
    self.log = log
    self.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.empty:SetPoint("CENTER", log, "CENTER", 0, 0)
    self.empty:SetText(T("Noch keine Beute in dieser Sitzung."))
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(self.empty, "soft") end
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    local gt = grip:CreateTexture(nil, "OVERLAY")
    gt:SetAllPoints(grip)
    gt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() Settings().lootWidth, Settings().lootHeight = math.floor(f:GetWidth() + .5), math.floor(f:GetHeight() + .5) end)
    if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripLootWindow") end
    if not modern then ONE.Themes:RegisterWindow(f, bg, title) end
    if ONE.Themes.StyleTree then ONE.Themes:StyleTree(f) end
    f:Hide()
    return f
end

function Loot:UpdateQualityButton()
    if not self.quality then return end
    local n = self:MinQuality()
    local name = Loot.QUALITIES[n + 1] and Loot.QUALITIES[n + 1][2] or "?"
    if self.quality.SetText then self.quality:SetText(T("ab %s", T(name))) end
end

function Loot:Show()
    local f = self:Build()
    chat.Chat.parchment = chat.UI.frame and ONE.Book and ONE.Book.IsActive and ONE.Book:IsActive() and not chat.UI.flat or false
    self:UpdateQualityButton()
    self:Render()
    f:Show()
end
function Loot:Toggle()
    if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

function Loot:Initialize()
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_LOOT")
    ev:SetScript("OnEvent", function(_, event, ...) Loot:OnEvent(event, ...) end)
    self.eventFrame = ev
    if ONE.RegisterSlash then ONE:RegisterSlash("beute", function() Loot:Toggle() end, T("Beute-Fenster öffnen/schließen")) end
end
