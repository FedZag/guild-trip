-- Guild Trip Chat: Fenster wie ein Messenger.
-- Links: Reiter (Alle, Gilde, Gruppe, Handel, In der Naehe, eigene) und darunter die
-- Fluestergespraeche, je mit Zaehler fuer Ungelesenes (blinkt). Rechts: Kopfzeile, Verlauf
-- (Blizzard-ScrollingMessageFrame: Links zu Gegenstaenden/Quests/Spielern klickbar) und
-- Eingabe mit festem Ziel ("An: Thrall") – Enter schickt genau dorthin.
-- Aussehen folgt dem Thema (Blizzard-Rahmen bzw. Pergamentblatt im Buch).
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local UI = {rows = {}}
chat.UI = UI
local Chat = chat.Chat

local LIST_W, ROW_H, HEAD_H, INPUT_H, TOP = 156, 24, 30, 28, 42
-- 0.6.8: Blizzard-Aussehen wie das Hauptfenster (Rahmen mit Titel, Kanaele mit Goldsymbolen,
-- Wappenschilde beim Fluestern, grosse Kopfzeile, Senden-Knopf). Buch und schlichter Stil bleiben.
local TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\"
local TAB_ICONS = "Interface\\AddOns\\ONE_Core\\Textures\\Common\\TabIcons"
local TAB_ICON = {all = 9, guild = 1, group = 3, trade = 4, near = 7}
local WHISPER_H, HEADROW_H = 32, 22
local function Modern() return UI.modern == true end

local function Text(parent, font, role)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH("LEFT")
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end
local function Color(r, g, b) return r, g, b end
local function Ink(text) return text end
-- Hervorhebung (z. B. Ungelesen-Zaehler) in der Akzentfarbe des Skins
local function RedCode()
    local c = ONE.Skin and {ONE.Skin:Color("accent")} or {1, .82, 0}
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end
UI.RedCode = RedCode

-- 1-Pixel-Rahmen um ein Fenster/Feld (dunkles Thema); gibt die vier Linien zurueck
local function Border(frame, r, g, b, a, inset)
    inset = inset or 0
    local out = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local e = frame:CreateTexture(nil, "BORDER")
        e:SetColorTexture(r, g, b, a)
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT", frame, side .. "LEFT", inset, 0)
            e:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -inset, 0)
            e:SetHeight(1)
        else
            e:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, -inset)
            e:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, inset)
            e:SetWidth(1)
        end
        out[#out + 1] = e
    end
    return out
end
UI.Border = Border

-- Farbe des Punktes vor einem Gespraech (Art des Kanals)
local function DotColor(e)
    local key
    if e.whisper then key = "whisper"
    elseif e.tab and e.tab.id ~= "all" then
        key = Chat.kindByKey[e.tab.id] and e.tab.id or e.tab.send
        if not key and type(e.tab.kinds) == "table" then
            local n, only = 0, nil
            for k in pairs(e.tab.kinds) do n = n + 1 only = k end
            if n == 1 then key = only end
        end
        if key == "say" then key = "emote" end -- "In der Naehe": Sagen waere weiss = unsichtbar auf Pergament
    end
    local kind = key and Chat.kindByKey[key]
    local c = kind and kind.color or {.65, .65, .7}
    return c[1], c[2], c[3]
end

-- Titel einer Ansicht
function UI.Title(view)
    if type(view) == "string" and view:sub(1, 2) == "w:" then return view:sub(3) end
    local tab = Chat:Tab(view)
    return tab and T(tab.label) or "?"
end

function UI:Build()
    if self.frame then return self.frame end
    local s = Chat:Settings()
    self.flat = Chat:Flat() -- vor allem anderen: entscheidet ueber Tinte/Pergament
    local modern = not self.flat and not (false)
    local f
    if modern then
        local ok, fr = pcall(CreateFrame, "Frame", "GuildTripChatWindow", UIParent, "PortraitFrameTemplate")
        if ok and fr then f = fr else modern = false end
    end
    self.modern = modern
    f = f or CreateFrame("Frame", "GuildTripChatWindow", UIParent, "BackdropTemplate")
    self.frame = f
    if modern then
        -- Blizzard-Rahmen: Titel oben, ohne grosses Portrait (sonst ragt es in die Kanalliste)
        if f.SetTitle then pcall(f.SetTitle, f, T("Guild Trip · Chat")) end
        local hidden = type(ButtonFrameTemplate_HidePortrait) == "function" and pcall(ButtonFrameTemplate_HidePortrait, f)
        if not hidden then
            for _, m in ipairs({"SetPortraitToAsset", "SetPortraitTextureRaw"}) do
                if type(f[m]) == "function" and pcall(f[m], f, "Interface\\AddOns\\ONE_Core\\Textures\\Common\\Emblem.tga") then break end
            end
            TOP = 58
        else
            TOP = 30
        end
        if type(f.CloseButton) == "table" and f.CloseButton.SetScript then f.CloseButton:SetScript("OnClick", function() UI:Hide() end) end
    end
    f:SetSize(s.width or 700, s.height or 400)
    if s.point then f:SetPoint(s.point[1], UIParent, s.point[2], s.point[3], s.point[4]) else f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 160) end
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(440, 240, 1200, 900) end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(self) if not Chat:Settings().locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() UI:SaveGeometry() end)
    if f.SetBackdrop then f:SetBackdrop({bgFile = "Interface/Buttons/WHITE8X8"}) end
    local background = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    background:SetColorTexture(.04, .05, .07, .92)
    local title = Text(f, "GameFontNormal", "accent")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
    title:SetText(T("Guild Trip Chat"))
    if modern then
        background:Hide() title:Hide()
    else
        ONE.Widgets:CloseButton(f, "TOPRIGHT", -4, -4, function() UI:Hide() end)
    end
    -- Zahnrad: Optionen › Chat (Settings.lua)
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(18, 18)
    gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, modern and -3 or -9)
    local gt0 = gear:CreateTexture(nil, "ARTWORK")
    gt0:SetAllPoints(gear)
    gt0:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function() UI:OpenSettings() end)
    gear:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT") GameTooltip:SetText(T("Chat-Einstellungen")) GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.gear = gear
    -- Beute-Fenster (wer hat was bekommen)
    local loot = CreateFrame("Button", nil, f)
    loot:SetSize(18, 18)
    loot:SetPoint("RIGHT", gear, "LEFT", -6, 0)
    local lt = loot:CreateTexture(nil, "ARTWORK")
    lt:SetAllPoints(loot)
    lt:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    loot:SetScript("OnClick", function() if chat.Loot then chat.Loot:Toggle() end end)
    loot:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT") GameTooltip:SetText(T("Beute-Fenster")) GameTooltip:AddLine(T("Wer hat welchen Gegenstand bekommen"), .8, .8, .8) GameTooltip:Show()
    end)
    loot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.lootButton = loot
    if modern then
        -- Blizzard-Rahmen: Rand und Titelleiste liegen hoeher als normale Kinder -> Knoepfe darueber
        -- legen und gut sichtbar links neben das Schliessen-X setzen
        local level = (f.GetFrameLevel and f:GetFrameLevel() or 1) + 20
        for _, b in ipairs({gear, loot}) do
            if b.SetFrameLevel then b:SetFrameLevel(level) end
            b:SetSize(16, 16)
        end
        gear:ClearAllPoints()
        gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -4)
        loot:ClearAllPoints()
        loot:SetPoint("RIGHT", gear, "LEFT", -6, 0)
    end
    if UISpecialFrames then table.insert(UISpecialFrames, "GuildTripChatWindow") end

    -- Groesse aendern: Griff unten rechts
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    local gt = grip:CreateTexture(nil, "OVERLAY")
    gt:SetAllPoints(grip)
    gt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() UI:SaveGeometry() UI:Refresh() end)

    -- Links: Liste der Reiter und Gespraeche
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TOP)
    list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, modern and 10 or 12)
    list:SetWidth(modern and LIST_W + 14 or LIST_W)
    self.list = list

    -- Rechts: Kopfzeile, Verlauf, Eingabe
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", list, "TOPRIGHT", modern and 10 or 14, modern and -2 or 0)
    head:SetPoint("TOPRIGHT", f, "TOPRIGHT", modern and -12 or -14, -TOP - (modern and 2 or 0))
    head:SetHeight(modern and 40 or HEAD_H)
    self.headText = Text(head, modern and "GameFontNormalLarge" or "GameFontNormal", "accent")
    self.headText:SetPoint("LEFT", head, "LEFT", 4, 0)
    self.headMenu = ONE.Widgets:Button(head, modern and "···" or T("Menü"), modern and 30 or 64, modern and 22 or 20, "RIGHT", modern and -8 or 0, 0, function(btn)
        local view = UI.current
        if view and view:sub(1, 2) == "w:" and ONE.PlayerMenu then ONE.PlayerMenu:Open(btn, view:sub(3)) end
    end)
    if modern then
        -- Wappenschild (Fluestern), Zusatzangabe und Schnellknoepfe
        self.headShield = head:CreateTexture(nil, "ARTWORK")
        self.headShield:SetSize(18, 18)
        self.headShield:SetPoint("LEFT", head, "LEFT", 6, 0)
        self.headShield:SetTexture(TEX .. "Shield")
        self.headContext = Text(head, "GameFontHighlightSmall", "soft")
        self.headContext:SetPoint("LEFT", self.headText, "RIGHT", 10, -1)
        self.headInvite = ONE.Widgets:Button(head, T("Einladen"), 78, 22, "RIGHT", -42, 0, function()
            UI:RunPlayerAction("invite")
        end)
        self.headNavi = ONE.Widgets:Button(head, T("Navi"), 64, 22, "RIGHT", -124, 0, function()
            UI:RunPlayerAction("navi")
        end)
        local band = head:CreateTexture(nil, "BACKGROUND")
        band:SetAllPoints(head)
        band:SetColorTexture(1, .82, 0, .05)
    end

    local log = CreateFrame("ScrollingMessageFrame", "GuildTripChatLog", f)
    log:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 4, -10)
    log:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 12 + INPUT_H + (modern and 14 or 18))
    log:SetFading(false)
    log:SetMaxLines(Chat.maxLines)
    log:SetJustifyH("LEFT")
    if log.SetFontObject then log:SetFontObject(ChatFontNormal or GameFontHighlight) end
    log:SetHyperlinksEnabled(true)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    log:SetScript("OnHyperlinkClick", function(self, link, text, button)
        local kind, rest = link:match("^(%a+):(.*)$")
        -- Spielername: unser Namens-Menue (Navi, Fluestern, Einladen, Ignorieren, Melden …)
        if kind == "player" and ONE.PlayerMenu then
            local name, lineID = rest:match("^([^:]+):?(%d*)")
            ONE.PlayerMenu:Open(self, name, {lineID = tonumber(lineID)})
            return
        end
        if type(SetItemRef) == "function" then pcall(SetItemRef, link, text, button, self) end
    end)
    self.log = log

    -- Eingabe: "An: …" + Feld; Enter sendet, Tab springt zum naechsten Fluestergespraech
    local to = ONE.Widgets:Button(f, "", 110, modern and 24 or INPUT_H - 2, "BOTTOMLEFT", 10 + LIST_W + (modern and 14 + 16 or 14), modern and 16 or 13, function(btn) UI:ChooseTarget(btn) end)
    self.toButton = to
    if modern then
        self.sendButton = ONE.Widgets:Button(f, T("Senden"), 76, 24, "BOTTOMRIGHT", -18, 16, function()
            if UI.input then
                local handler = UI.input:GetScript("OnEnterPressed")
                if handler then handler(UI.input) end
            end
        end, "primary")
    end
    local ok, box = pcall(CreateFrame, "EditBox", "GuildTripChatInput", f, "InputBoxTemplate")
    if not ok or not box then box = CreateFrame("EditBox", "GuildTripChatInput", f) end
    if ONE.Kit and ONE.Kit.StyleEdit then ONE.Kit.StyleEdit(box) end
    box:SetPoint("BOTTOMLEFT", to, "BOTTOMRIGHT", 10, 0)
    if modern then
        box:SetPoint("BOTTOMRIGHT", self.sendButton, "BOTTOMLEFT", -10, 0)
        box:SetHeight(24)
    else
        box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 13)
        box:SetHeight(INPUT_H)
    end
    box:SetAutoFocus(false)
    box:SetMaxLetters(1020)
    box:SetScript("OnEnterPressed", function(self)
        local sent, err = Chat:Send(UI.current, self:GetText())
        if sent then
            if self.AddHistoryLine then self:AddHistoryLine(self:GetText()) end
            self:SetText("")
        elseif err then ONE:Print(err) end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Eigener Feldhintergrund statt Blizzard-InputBox (wirkte unfertig) + Platzhalter wie im Messenger
    for _, key in ipairs({"Left", "Right", "Middle", "LeftDisabled", "RightDisabled", "MiddleDisabled"}) do
        local t = rawget(box, key)
        if type(t) == "table" and t.Hide then t:Hide() end
    end
    if box.SetTextInsets then box:SetTextInsets(8, 8, 0, 0) end
    local placeholder = Text(f, "GameFontHighlightSmall", "soft")
    placeholder:SetPoint("LEFT", box, "LEFT", 10, 0)
    placeholder:SetText(T("Nachricht schreiben …"))
    self.placeholderDefault = true
    self.placeholder = placeholder
    local function Placeholder()
        local empty = (box:GetText() or "") == "" and not (box.HasFocus and box:HasFocus())
        if empty then placeholder:Show() else placeholder:Hide() end
    end
    self.UpdatePlaceholder = Placeholder
    box:SetScript("OnTextChanged", Placeholder)
    box:SetScript("OnEditFocusGained", Placeholder)
    box:SetScript("OnEditFocusLost", Placeholder)
    if not self.flat then
        local inbg = f:CreateTexture(nil, "BACKGROUND", nil, -5)
        inbg:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 1)
        inbg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -1)
        inbg:SetColorTexture(0, 0, 0, .5)
        Border(box, .35, .35, .4, .9, -2)
        if modern then
            -- rechte Seite als eingelassene Flaeche wie im Hauptfenster
            local box2 = CreateFrame("Frame", nil, f)
            box2:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
            box2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 10)
            -- unter Kopf, Verlauf und Eingabe (die liegen eine Ebene hoeher)
            if box2.SetFrameLevel and f.GetFrameLevel then box2:SetFrameLevel(f:GetFrameLevel()) end
            if ONE.Themes and ONE.Themes.RegisterPanel then ONE.Themes:RegisterPanel(box2) end
            self.mainBox = box2
            local sep = f:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", head, "BOTTOMLEFT", -4, 0)
            sep:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 4, 0)
            sep:SetColorTexture(.79, .64, .29, .45)
            local sep2 = f:CreateTexture(nil, "ARTWORK")
            sep2:SetHeight(1)
            sep2:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 10, INPUT_H + 18)
            sep2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, INPUT_H + 18)
            sep2:SetColorTexture(1, 1, 1, .08)
        else
            local logbg = f:CreateTexture(nil, "BACKGROUND", nil, -5)
            logbg:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
            logbg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12 + INPUT_H + 12)
            logbg:SetColorTexture(0, 0, 0, .3)
        end
    end
    Placeholder()
    box:SetScript("OnTabPressed", function() UI:CycleWhisper(IsShiftKeyDown and IsShiftKeyDown()) end)
    self.input = box

    -- Bereiche klar trennen (17.11.2026): Titelleiste | Seitenleiste | Kopf, Verlauf, Eingabe.
    -- Doppelte Linien (kraeftig + fein) wie in einem Kassenbuch; im Buch Tinte, sonst helles Grau.
    if not self.flat and not modern then
        local function Tex(a)
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(1, 1, 1, a * .3)
            return t
        end
        -- waagerecht: von (fromFrame, fromPoint, x1) bis (toFrame, toPoint, x2) auf Hoehe y
        local function HRule(from, fp, x1, to, tp, x2, y)
            local a, b = Tex(.5), Tex(.22)
            a:SetHeight(1) b:SetHeight(1)
            a:SetPoint("TOPLEFT", from, fp, x1, y) a:SetPoint("TOPRIGHT", to, tp, x2, y)
            b:SetPoint("TOPLEFT", from, fp, x1, y - 3) b:SetPoint("TOPRIGHT", to, tp, x2, y - 3)
            return {a, b}
        end
        local lines = {}
        -- unter der Titelleiste, ueber die ganze Breite
        for _, t in ipairs(HRule(f, "TOPLEFT", 12, f, "TOPRIGHT", -12, -TOP + 8)) do lines[#lines + 1] = t end
        -- rechts neben der Seitenleiste (senkrecht, doppelt)
        local v1, v2 = Tex(.5), Tex(.22)
        v1:SetWidth(1) v2:SetWidth(1)
        v1:SetPoint("TOPLEFT", list, "TOPRIGHT", 5, 0) v1:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 5, 0)
        v2:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0) v2:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 8, 0)
        lines[#lines + 1], lines[#lines + 2] = v1, v2
        -- unter der Kopfzeile
        for _, t in ipairs(HRule(head, "BOTTOMLEFT", 0, head, "BOTTOMRIGHT", 0, -2)) do lines[#lines + 1] = t end
        -- ueber der Eingabe
        for _, t in ipairs(HRule(list, "BOTTOMRIGHT", 14, f, "BOTTOMRIGHT", -14, INPUT_H + 14)) do lines[#lines + 1] = t end
        self.lines = lines
    end
    Chat.parchment = false
    -- Aussehen: schlicht (ElvUI & Co.) oder wie das gewaehlte Thema (Blizzard-Rahmen / Pergament)
    if self.flat then
        UI.FlatSkin(f, background, title)
        UI.FlatSkin(list)
    else
        if ONE.Themes and ONE.Themes.RegisterPanel then ONE.Themes:RegisterPanel(list) end
        if not modern then ONE.Themes:RegisterWindow(f, background, title) end
        if ONE.Themes.StyleTree then ONE.Themes:StyleTree(f) end
    end
    -- Schrift: im Buch die alte Druckschrift, sonst die Chatschrift in gewaehlter Groesse
    if log.SetFont then
        local file = log.GetFont and log:GetFont()
        if file then pcall(log.SetFont, log, file, Chat:Settings().fontSize, "") end
    end
    f:SetScript("OnSizeChanged", function() UI:LayoutRows() end)
    self.grip = grip
    self:ApplyLook()
    f:Hide()
    self.current = self.current or "all"
    return f
end

-- ===== Einstellbares Aussehen (Zahnrad) =====
-- Hintergrund-Teile: Texturen im Hintergrund/Rahmen von Fenster und Liste (Pergament, Blizzard-Rahmen,
-- Schatten) – Schrift, Linien und Knoepfe bleiben voll sichtbar.
function UI:BackgroundParts()
    local out = {}
    local function Collect(frame)
        if not (frame and frame.GetRegions) then return end
        for _, r in ipairs({frame:GetRegions()}) do
            local layer = r.GetDrawLayer and r:GetDrawLayer()
            if r.GetObjectType and r:GetObjectType() == "Texture" and (layer == "BACKGROUND" or layer == "BORDER") then out[#out + 1] = r end
        end
        if type(frame.NineSlice) == "table" then out[#out + 1] = frame.NineSlice end
    end
    Collect(self.frame)
    Collect(self.list)
    return out
end
function UI:ApplyLook()
    local f, s = self.frame, Chat:Settings()
    if not f then return end
    local op = tonumber(s.opacity) or 1
    for _, part in ipairs(self:BackgroundParts()) do if part.SetAlpha then part:SetAlpha(op) end end
    if self.log then
        if self.log.SetSpacing then self.log:SetSpacing(tonumber(s.spacing) or 0) end
        if self.log.SetFading then self.log:SetFading(s.fadeLines == true) end
        if self.log.SetTimeVisible then self.log:SetTimeVisible(60) end
    end
    -- Sperren: nicht verschieben, keine Groesse aendern
    if self.grip then if s.locked then self.grip:Hide() else self.grip:Show() end end
    f:SetMovable(not s.locked)
    -- Ausblenden, wenn die Maus weg ist (sanft; Eingabe aktiv oder Maus drueber = voll sichtbar)
    local idle = tonumber(s.idleAlpha) or 1
    if idle >= 1 then
        f:SetScript("OnUpdate", nil)
        f:SetAlpha(1)
    else
        f.__fadeWait = 0
        f:SetScript("OnUpdate", function(frame, elapsed) UI:FadeStep(frame, elapsed or 0) end)
    end
end
function UI:FadeStep(frame, elapsed)
    local s = Chat:Settings()
    local idle = tonumber(s.idleAlpha) or 1
    local busy = (frame.IsMouseOver and frame:IsMouseOver()) or (self.input and self.input.HasFocus and self.input:HasFocus())
        or (ONE.UI and ONE.UI.frame and ONE.UI.frame.IsShown and ONE.UI.frame:IsShown() and ONE.UI.activeTab == "options" and ONE.UI.optionsCategory == "chat")
    if busy then frame.__fadeWait = 0 else frame.__fadeWait = (frame.__fadeWait or 0) + elapsed end
    local target = (busy or frame.__fadeWait < 4) and 1 or idle
    local now = frame.GetAlpha and frame:GetAlpha() or 1
    local step = elapsed * 2.5
    if math.abs(target - now) <= step then now = target elseif target > now then now = now + step else now = now - step end
    frame:SetAlpha(now)
end
-- Neue Nachricht im offenen Fenster: kurz wieder voll sichtbar
function UI:WakeUp()
    if self.frame then self.frame.__fadeWait = 0 end
end

-- Schlichtes Aussehen: flache dunkle Flaeche mit 1-Pixel-Rand (passt neben ElvUI, Tukui …)
function UI.FlatSkin(frame, background, title)
    local bg = background or frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    if not background then bg:SetAllPoints(frame) end
    bg:ClearAllPoints()
    bg:SetAllPoints(frame)
    bg:SetColorTexture(.06, .06, .07, background and .88 or .55)
    local c = {.22, .22, .25, 1}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local e = frame:CreateTexture(nil, "BORDER")
        e:SetColorTexture(c[1], c[2], c[3], c[4])
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT", frame, side .. "LEFT", 0, 0)
            e:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", 0, 0)
            e:SetHeight(1)
        else
            e:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, 0)
            e:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, 0)
            e:SetWidth(1)
        end
    end
    if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0) end
    if title and title.SetTextColor then title:SetTextColor(.9, .9, .9) end
end

function UI:SaveGeometry()
    local f, s = self.frame, Chat:Settings()
    if not f then return end
    s.width, s.height = math.floor(f:GetWidth() + .5), math.floor(f:GetHeight() + .5)
    local point, _, rel, x, y = f:GetPoint(1)
    if point then s.point = {point, rel, math.floor(x + .5), math.floor(y + .5)} end
end

-- ===== Liste links =====
-- Eintraege: Kopf "Reiter" (+), Reiter, Kopf "Fluestern" (+), Gespraeche
function UI:Entries()
    local out = {{head = true, text = T("Reiter"), add = "tab"}}
    for _, t in ipairs(Chat:Tabs()) do out[#out + 1] = {view = t.id, text = T(t.label), tab = t} end
    out[#out + 1] = {head = true, text = T("Flüstern"), add = "whisper"}
    for _, w in ipairs(Chat.whispers) do out[#out + 1] = {view = Chat.WhisperView(w.name), text = w.name, whisper = w.name} end
    return out
end

local function NewRow(list)
    local b = CreateFrame("Button", nil, list)
    b:SetHeight(ROW_H)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:SetColorTexture(1, .82, 0, .10)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(1, 1, 1, .06)
    -- Blinken bei Ungelesenem
    b.flash = b:CreateTexture(nil, "BORDER")
    b.flash:SetAllPoints(b)
    b.flash:SetColorTexture(1, .55, .1, .28)
    b.flash:Hide()
    if b.CreateAnimationGroup then
        local g = b:CreateAnimationGroup()
        local a = g:CreateAnimation("Alpha")
        a:SetFromAlpha(1) a:SetToAlpha(.15) a:SetDuration(.6)
        g:SetLooping("BOUNCE")
        g.target = b.flash
        a:SetTarget(b.flash)
        b.pulse = g
    end
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetSize(6, 6)
    b.dot:SetPoint("LEFT", b, "LEFT", 9, 0)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetSize(2, ROW_H - 6)
    b.bar:SetPoint("LEFT", b, "LEFT", 2, 0)
    b.bar:SetColorTexture(1, .82, 0, .9)
    b.bar:Hide()
    b.pill = b:CreateTexture(nil, "ARTWORK")
    b.pill:SetSize(20, 14)
    b.pill:SetPoint("RIGHT", b, "RIGHT", -21, 0)
    b.pill:SetColorTexture(.78, .22, .08, .95)
    b.pill:Hide()
    b.text = Text(b, "GameFontHighlightSmall", "text")
    b.text:SetPoint("LEFT", b, "LEFT", 22, 0)
    b.badge = Text(b, "GameFontNormalSmall", "accent")
    b.badge:SetPoint("RIGHT", b, "RIGHT", -24, 0)
    b.badge:SetJustifyH("RIGHT")
    -- "+" bei Koepfen bzw. "×" bei Fluestergespraechen
    b.side = CreateFrame("Button", nil, b)
    b.side:SetSize(16, 16)
    b.side:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.side.text = Text(b.side, "GameFontNormal", "accent")
    b.side.text:SetPoint("CENTER", b.side, "CENTER", 0, 0)
    if Modern() then
        -- Symbol (Kanal: Goldsymbol, Fluestern: Wappenschild in Klassenfarbe), zweite Zeile,
        -- Online-Punkt und Zahl-Pille aus eigenen Grafiken
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.online = b:CreateTexture(nil, "OVERLAY")
        b.online:SetSize(7, 7)
        b.online:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
        b.online:SetTexture(TEX .. "Dot")
        b.online:SetVertexColor(.25, .85, .25)
        b.sub = Text(b, "GameFontDisableSmall", "soft")
        b.sub:SetPoint("TOPLEFT", b, "LEFT", 32, -1)
        b.sub:SetPoint("RIGHT", b, "RIGHT", -28, 0)
        if b.sub.SetWordWrap then b.sub:SetWordWrap(false) end
        b.pill:SetTexture(TEX .. "Pill")
        b.pill:SetSize(26, 14)
        b.badge:ClearAllPoints()
        b.badge:SetPoint("CENTER", b.pill, "CENTER", 0, 0)
        b.badge:SetJustifyH("CENTER")
        b.rule = b:CreateTexture(nil, "ARTWORK")
        b.rule:SetHeight(1)
        b.rule:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 2)
        b.rule:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 2)
        b.rule:SetColorTexture(.79, .64, .29, .4)
        b.sel:SetColorTexture(1, .82, 0, .14)
        b.flash:SetColorTexture(1, .82, 0, .12)
        b.bar:SetSize(3, ROW_H)
        b.bar:ClearAllPoints()
        b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return b
end

-- Gildenliste: Klasse, Stufe, Gebiet und online fuer einen Namen (fuer Fluestern)
function UI.MemberInfo(name)
    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then return nil end
    local short = Chat.Short(name)
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local full, _, _, level, class, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if full and Chat.Short(full) == short then
            return {level = level, class = class, zone = zone, online = online and true or false, classFile = classFile}
        end
    end
end
local function ClassRGB(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return .75, .75, .75
end

-- Blizzard-Aussehen: Zeile fuer einen Eintrag einrichten; liefert die Zeilenhoehe
function UI:StyleModernRow(b, e, selected, unread)
    b.dot:Hide()
    b.rule:SetShown(e.head == true)
    b.online:Hide()
    b.sub:SetText("")
    b.text:ClearAllPoints()
    if e.head then
        b.icon:Hide()
        b.text:SetPoint("LEFT", b, "LEFT", 8, 1)
        -- string.upper kennt keine Umlaute (UTF-8): selbst ersetzen
        local label = string.upper(e.add == "tab" and T("Kanäle") or T("Flüstern")):gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü")
        b.text:SetText("|cffffd100" .. label .. "|r")
        return HEADROW_H
    end
    b.icon:Show()
    if e.whisper then
        local info = UI.MemberInfo(e.whisper)
        local r, g, bl = ClassRGB(info and info.classFile)
        b.icon:SetTexture(TEX .. "Shield")
        b.icon:SetTexCoord(0, 1, 0, 1)
        b.icon:SetVertexColor(r, g, bl)
        b.text:SetPoint("BOTTOMLEFT", b, "LEFT", 32, 1)
        b.text:SetText(string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, bl * 255, e.text))
        if info then
            b.sub:SetText(info.online and string.format("%s %s · %s", info.class or "", tostring(info.level or ""), info.zone or "")
                or T("offline"))
            if info.online then b.online:Show() end
        end
        b:SetAlpha(info and not info.online and .6 or 1)
        return WHISPER_H
    end
    b:SetAlpha(1)
    local idx = TAB_ICON[e.view] or 9
    local col, row = idx % 4, math.floor(idx / 4)
    b.icon:SetTexture(TAB_ICONS)
    b.icon:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
    local k = selected and 1 or .75
    b.icon:SetVertexColor(k, k, k)
    b.text:SetPoint("LEFT", b, "LEFT", 32, 0)
    b.text:SetText(selected and ("|cffffd100" .. e.text .. "|r") or e.text)
    return ROW_H
end

function UI:LayoutRows()
    if not self.list then return end
    local entries = self:Entries()
    local maxRows = math.max(1, math.floor((self.list:GetHeight() - 8) / ROW_H))
    local listH = (self.list:GetHeight() or 0) - 8
    local y = 4
    for i, e in ipairs(entries) do
        local b = self.rows[i] or NewRow(self.list)
        self.rows[i] = b
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.list, "TOPLEFT", 4, -y)
        b:SetPoint("RIGHT", self.list, "RIGHT", -4, 0)
        b.entry = e
        local unread = e.view and Chat.unread[e.view] or 0
        b.dot:SetShown(not e.head)
        if not e.head then
            local r, g, bl = Color(DotColor(e))
            b.dot:SetColorTexture(r, g, bl, .95)
        end
        if e.head then
            b.text:SetText("|cff9d9d9d" .. e.text .. "|r")
            b.sel:Hide()
            b.bar:Hide()
            b.pill:Hide()
            b.badge:SetText("")
            b.side.text:SetText("+")
            b.side:Show()
            b.side:SetScript("OnClick", function() if e.add == "tab" then UI:EditTab() else UI:AskWhisper() end end)
        else
            local selected = e.view == self.current
            b.text:SetText(Ink(e.text))
            if selected then b.sel:Show() else b.sel:Hide() end
            if selected then b.bar:Show() else b.bar:Hide() end
            if unread > 0 then
                b.pill:Show()
                b.badge:SetText("|cffffffff" .. tostring(math.min(unread, 99)) .. "|r")
            else
                b.pill:Hide()
                b.badge:SetText(unread > 0 and (RedCode() .. tostring(unread)) or "")
            end
            if e.whisper then
                b.side.text:SetText("×")
                b.side:Show()
                b.side:SetScript("OnClick", function() Chat:CloseWhisper(e.whisper) if UI.current == e.view then UI.current = "all" end UI:Refresh() end)
            elseif e.tab and not e.tab.builtin then
                b.side.text:SetText("…")
                b.side:Show()
                b.side:SetScript("OnClick", function() UI:EditTab(e.tab) end)
            else
                b.side:Hide()
            end
        end
        if Modern() then
            local h = self:StyleModernRow(b, e, e.view == self.current, unread)
            if e.head then b.side.text:SetText("|cffc9b48a+|r") end
            if not e.head and unread > 0 then
                -- Handel & Co. gedaempft, sonst rot
                local quiet = e.tab and (e.tab.id == "trade" or e.tab.send == "trade" or e.tab.send == "general")
                if quiet then b.pill:SetVertexColor(.35, .29, .2) else b.pill:SetVertexColor(.62, .1, .06) end
            end
            b:SetHeight(h)
            maxRows = (y + h <= listH + 4) and math.huge or 0
            y = y + h + (e.head and 2 or 0)
        else
            y = y + ROW_H
        end
        local blink = unread > 0 and Chat:Settings().blink and not e.head
        if blink then b.flash:Show() if b.pulse and not b.pulse:IsPlaying() then b.pulse:Play() end
        else if b.pulse then b.pulse:Stop() end b.flash:Hide() end
        b:SetScript("OnClick", function(_, button)
            if e.head then return end
            if button == "RightButton" and e.whisper and ONE.PlayerMenu then ONE.PlayerMenu:Open(b, e.whisper) return end
            UI:Show(e.view)
        end)
        if Modern() then if maxRows > 0 then b:Show() else b:Hide() end
        elseif i <= maxRows then b:Show() else b:Hide() end
    end
    for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
end

-- ===== Verlauf =====
function UI:Render()
    local log, view = self.log, self.current
    if not log then return end
    log:Clear()
    local showKind = view == "all"
    local buf = Chat:Buffer(view)
    for _, entry in ipairs(buf) do self:AddLine(entry, showKind) end
    if not self.empty then
        self.empty = Text(self.frame, "GameFontHighlight", "soft")
        self.empty:SetPoint("CENTER", log, "CENTER", 0, 0)
        self.empty:SetJustifyH("CENTER")
    end
    if #buf == 0 then
        self.empty:SetText(view and tostring(view):sub(1, 2) == "w:" and T("Noch keine Nachrichten – schreib unten los.") or T("Noch keine Nachrichten."))
        self.empty:Show()
    else
        self.empty:Hide()
    end
end
function UI:AddLine(entry, showKind)
    local k = Chat.kindByKey[entry.kind]
    local c = k and k.color or {1, 1, 1}
    if Modern() then
        self.log:AddMessage(UI.FormatModern(entry, showKind), .93, .93, .93)
        return
    end
    local r, g, b = Color(c[1], c[2], c[3])
    self.log:AddMessage(Ink(Chat:Format(entry, showKind)), r, g, b)
end
-- Blizzard-Aussehen: graue Uhrzeit, farbige Kanal-Marke (ohne Klammern), Name in Klassenfarbe,
-- heller Text; wer dich erwaehnt, wird gold hervorgehoben (» am Anfang)
local function Hex(c) return string.format("|cff%02x%02x%02x", (c[1] or 1) * 255, (c[2] or 1) * 255, (c[3] or 1) * 255) end
function UI.FormatModern(entry, showKind)
    local kind = Chat.kindByKey[entry.kind]
    local color = kind and kind.color or {1, 1, 1}
    local s = Chat:Settings()
    local parts = {}
    local me = type(UnitName) == "function" and UnitName("player") or nil
    local text = entry.text or ""
    local mention = me and me ~= "" and not entry.inform and Chat.Short(entry.author) ~= me and text:find(me, 1, true)
    if mention then
        parts[#parts + 1] = "|cffffd100»|r "
        text = text:gsub(me:gsub("%p", "%%%0"), "|cffffd100" .. me .. "|r")
    end
    if s.stamps and type(date) == "function" then parts[#parts + 1] = "|cff7a7a7a" .. date("%H:%M", entry.time) .. "|r  " end
    if entry.kind == "system" then
        parts[#parts + 1] = "|cff99bb99" .. text .. "|r"
        return table.concat(parts)
    end
    if showKind and kind then parts[#parts + 1] = Hex(color) .. T(kind.label) .. "|r  " end
    local name = Chat.Short(entry.author)
    local code = Chat.ClassColorCode(entry.guid, false)
    local shown = code and (code .. name .. "|r") or (Hex(color) .. name .. "|r")
    local link = "|Hplayer:" .. (entry.author or name) .. ":" .. tostring(entry.lineID or 0) .. "|h" .. shown .. "|h"
    if entry.inform then
        parts[#parts + 1] = "|cff9a9a9a" .. T("Du an %s", "|r" .. link .. "|cff9a9a9a") .. ":|r  "
    elseif entry.event == "CHAT_MSG_TEXT_EMOTE" or entry.kind == "emote" then
        parts[#parts + 1] = (entry.kind == "emote" and (link .. " ") or "") .. Hex(color) .. text .. "|r"
        return table.concat(parts)
    else
        parts[#parts + 1] = link .. "  "
    end
    -- Fluestern bleibt in seiner Farbe erkennbar
    if entry.kind == "whisper" then parts[#parts + 1] = Hex(color) .. text .. "|r" else parts[#parts + 1] = text end
    return table.concat(parts)
end

function UI:RefreshHead()
    local view = self.current
    local chatType, target = Chat:Target(view)
    local whisper = view:sub(1, 2) == "w:"
    self.headText:SetText(UI.Title(view))
    if whisper then self.headMenu:Show() else self.headMenu:Hide() end
    local to = whisper and view:sub(3) or (chatType and UI.Title(view)) or T("nur lesen")
    self.toButton:SetText(T("An: %s", to))
    if Modern() then self:RefreshModernHead(view, whisper, to, chatType ~= nil) end
end

-- Blizzard-Aussehen: Wappenschild + Angabe (Klasse/Stufe/Gebiet bzw. wer online ist),
-- Navi/Einladen nur, wenn das Namens-Menue sie gerade anbietet
function UI:RefreshModernHead(view, whisper, to, canSend)
    local name = whisper and view:sub(3) or nil
    local info = name and UI.MemberInfo(name)
    self.headText:ClearAllPoints()
    if whisper then
        local r, g, b = ClassRGB(info and info.classFile)
        self.headShield:SetVertexColor(r, g, b)
        self.headShield:Show()
        self.headText:SetPoint("LEFT", self.headShield, "RIGHT", 6, 0)
        self.headText:SetTextColor(r, g, b)
        self.headContext:SetText(info and (info.online and string.format("%s · %s %s · %s", info.class or "", T("Stufe"), tostring(info.level or "?"), info.zone or "")
            or T("offline")) or T("Flüstern"))
    else
        self.headShield:Hide()
        self.headText:SetPoint("LEFT", self.headText:GetParent(), "LEFT", 6, 0)
        self.headText:SetTextColor(1, .82, 0)
        local ctx = ""
        if view == "guild" and type(GetNumGuildMembers) == "function" then
            local total, online = GetNumGuildMembers()
            if total and total > 0 then ctx = T("%d von %d online", online or 0, total) end
            local g = ONE.modules and ONE.modules.guild
            local live = g and g.LivePeers and #g:LivePeers() or 0
            if live > 0 then ctx = ctx .. "  ·  " .. T("%d teilen Position", live) end
        elseif not canSend then
            ctx = T("nur lesen")
        end
        self.headContext:SetText(ctx)
    end
    local function Offer(button, id)
        local ok = false
        if name and ONE.PlayerMenu and ONE.PlayerMenu.Items then
            for _, it in ipairs(ONE.PlayerMenu:Items(name, {})) do if it.id == id then ok = true end end
        end
        if ok then button:Show() else button:Hide() end
        return ok
    end
    local inviteShown = Offer(self.headInvite, "invite")
    Offer(self.headNavi, "navi")
    self.headNavi:ClearAllPoints()
    self.headNavi:SetPoint("RIGHT", self.headNavi:GetParent(), "RIGHT", inviteShown and -124 or -42, 0)
    if self.placeholder then
        self.placeholder:SetText(canSend and T("Nachricht an %s …", to) or T("Hier kann man nur lesen."))
    end
end
function UI:RunPlayerAction(id)
    local view = self.current or ""
    if view:sub(1, 2) ~= "w:" or not (ONE.PlayerMenu and ONE.PlayerMenu.Items) then return end
    local name = view:sub(3)
    for _, it in ipairs(ONE.PlayerMenu:Items(name, {})) do
        if it.id == id then ONE.PlayerMenu:Run(it, name, {}) return true end
    end
end

function UI:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    self:LayoutRows()
    self:RefreshHead()
end

-- Ansicht zeigen (und Fenster oeffnen)
function UI:Show(view)
    self:Build()
    if view then self.current = view end
    Chat.current, Chat.visible = self.current, true
    Chat:MarkRead(self.current)
    self.frame:Show()
    self:ApplyLook()
    self:Render()
    self:Refresh()
    if ONE.MinimapButton and ONE.MinimapButton.ClearAlert then pcall(ONE.MinimapButton.ClearAlert, ONE.MinimapButton, "chat") end
end
function UI:Hide()
    if self.frame then self.frame:Hide() end
    Chat.visible = false
end
function UI:Toggle()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end

-- Neue Nachricht: sichtbare Ansicht ergaenzen, Liste/Zaehler auffrischen, Hinweise
function UI:OnMessage(entry, views)
    local shown = self.frame and self.frame:IsShown()
    if shown then
        if Chat:Settings().wakeOnMessage ~= false then self:WakeUp() end
        for _, v in ipairs(views) do
            if v == self.current then self:AddLine(entry, v == "all") Chat:MarkRead(v) end
        end
        self:Refresh()
    end
    local sound = Chat:SoundFor(entry, views)
    if sound then Chat:PlaySound(sound) end
    if entry.kind == "whisper" and not entry.inform then
        local s = Chat:Settings()
        if s.blink and type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
        if not shown and ONE.MinimapButton and ONE.MinimapButton.SetAlert then
            pcall(ONE.MinimapButton.SetAlert, ONE.MinimapButton, "chat", T("Neue Flüsternachricht von %s", Chat.Short(entry.author)), "chat")
        end
    end
end

-- Tab im Eingabefeld: naechstes (Umschalt: vorheriges) Fluestergespraech
function UI:CycleWhisper(back)
    local list = Chat.whispers
    if #list == 0 then return end
    local idx = 0
    for i, w in ipairs(list) do if Chat.WhisperView(w.name) == self.current then idx = i end end
    idx = back and (idx - 2) % #list + 1 or idx % #list + 1
    self:Show(Chat.WhisperView(list[idx].name))
    if self.input then self.input:SetFocus() end
end

-- "An: …" anklicken: Ziel waehlen (Reiter mit Schreibrecht und Gespraeche)
function UI:ChooseTarget(owner)
    local list = {}
    for _, t in ipairs(Chat:Tabs()) do if Chat:Target(t.id) then list[#list + 1] = {value = t.id, text = T(t.label)} end end
    for _, w in ipairs(Chat.whispers) do list[#list + 1] = {value = Chat.WhisperView(w.name), text = T("Flüstern: %s", w.name)} end
    if ONE.Kit and ONE.Kit.OpenMenu and ONE.Skin then
        ONE.Kit:OpenMenu(owner, list, self.current, function(v) UI:Show(v) end)
    elseif MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, o in ipairs(list) do root:CreateButton(o.text, function() UI:Show(o.value) end) end
        end)
    end
end

-- Neues Fluestergespraech: Name eingeben (kleines Feld ueber der Liste)
function UI:AskWhisper()
    if not self.askBox then
        local ok, b = pcall(CreateFrame, "EditBox", nil, self.frame, "InputBoxTemplate")
        if not ok or not b then b = CreateFrame("EditBox", nil, self.frame) end
        if ONE.Kit and ONE.Kit.StyleEdit then ONE.Kit.StyleEdit(b) end
        b:SetSize(LIST_W - 16, 20)
        b:SetPoint("BOTTOMLEFT", self.list, "BOTTOMLEFT", 10, 6)
        b:SetAutoFocus(true)
        b:SetScript("OnEnterPressed", function(self)
            local name = (self:GetText() or ""):match("^%s*(.-)%s*$")
            self:SetText("") self:Hide()
            if name ~= "" then UI:Show(Chat:OpenWhisper(name)) if UI.input then UI.input:SetFocus() end end
        end)
        b:SetScript("OnEscapePressed", function(self) self:SetText("") self:Hide() end)
        self.askBox = b
    end
    self.askBox:Show()
    self.askBox:SetFocus()
end
