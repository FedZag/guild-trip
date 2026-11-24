-- Guild Trip Chat: Randleiste statt Fenster (Nutzerwunsch 23.11.2026, Messenger-Stil, Standard aus)
-- Links am Bildschirmrand nur eine schmale Leiste: jedes Gespräch als eigenes Symbol, Gruppen (Angeheftet,
-- Gespräche, Flüstern, System) mit Abstand. Klick = aktiv machen, nochmal Klick = schreiben, Rechtsklick = Menü.
-- Neue Nachrichten im aktiven Gespräch (und Flüstern) steigen als einzelne Blasen neben der Leiste auf und
-- verblassen nach oben. Enter öffnet NUR die Eingabezeile mit dem Emoji-Knopf (dieselbe wie im Fenster).
-- Ziehen verschiebt die Leiste.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI

local TAIL_TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\BubbleTail"
local TAIL_RING_TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\BubbleTailRing"
local BUBBLE_R = 10
local R = {bubbles = {}, icons = {},
    BUBBLE_MAX = 6, BUBBLE_W = 300, COLUMN_W = 400, RISE_H = 420, BUBBLE_GAP = 28, REPLAY = 10, STATIC_MAX = 10, INPUT_CLOSE = 3, ANIM = .25,
    ICON = 28, GAP = 12, WIDTH = 38, QUICK_W = 380, QUICK_H = 54, SNAP = 60, EDGE = 2}
chat.Rail = R
local function M() return chat.Messenger end
local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end
local function Over(f) return f and f.IsShown and f:IsShown() and f.IsMouseOver and f:IsMouseOver() or false end

-- Gruppen wie in der Gesprächsliste des Fensters
R.GROUPS = {{key = "pinned"}, {key = "talk"}, {key = "whisper"}, {key = "system"}}

function R.Active()
    local s = Chat:Settings()
    return s.rail == true and s.style ~= "classic" and UI.style == "messenger" and M() ~= nil
end
function R.BubbleTime() return tonumber(Chat:Settings().railTime) or 20 end
-- Aktives Gespraech: auch ohne je geoeffnetes Fenster (nach dem Einloggen war UI.current leer -> keine Blasen,
-- Spieltest 23.11.2026); zuletzt aktives bleibt ueber /reload
function R.ActiveView()
    local v = UI.current or Chat:Settings().railView
    if type(v) == "string" and (Chat:Tab(v) or v:sub(1, 2) == "w:") then return v end
    return "guild"
end
function R:RememberView()
    if UI.current then Chat:Settings().railView = UI.current end
end
function R.WhisperBubbles() return Chat:Settings().railWhisper ~= false end
function R.Blink() return Chat:Settings().railBlink ~= false end
-- Fenster schliesst sich nach so vielen Sekunden ohne Maus/Tippen (0 = nie, Standard)
function R.AutoClose() return tonumber(Chat:Settings().railAutoClose) or 0 end

-- ===== Einrasten am Bildschirmrand (Nutzer 24.11.2026: "egal an welcher stelle? oben, unten oder rechts") =====
-- Losgelassen nahe einem Rand: rastet dort ein (Stelle entlang des Rands bleibt), sonst frei.
-- Links/rechts senkrecht, oben/unten waagerecht. Blasen, Eingabezeile, Fenster und Wappen gehen immer
-- zur Bildschirmmitte hin; oben sinken die Blasen nach unten statt zu steigen.
R.SIDES = {left = true, right = true, top = true, bottom = true}
function R.Side()
    local s = Chat:Settings().railSide
    return R.SIDES[s] and s or nil
end
function R.Horizontal() local s = R.Side() return s == "top" or s == "bottom" end
-- Seite, nach der sich alles richtet: eingerastet = der Rand; frei = die naehere Bildschirmhaelfte
function R.Layout()
    local side = R.Side()
    if side then return side end
    local f = R.frame
    local W = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    local l, w = f and f.GetLeft and f:GetLeft(), f and f.GetWidth and f:GetWidth()
    if l and w and W and W > 0 and l + w / 2 > W / 2 then return "right" end
    return "left"
end
-- Naechster Rand nach dem Loslassen (Masse in Bildschirm-Einheiten): Seite und Anker {Punkt, Punkt, x, y}
-- oder nil (frei). Entlang des Rands: oberes/unteres (linkes/rechtes) Drittel haelt die Ecke, sonst Mitte.
function R.SnapPoint(l, b, w, h, W, H, horiz)
    local d = {left = l, right = W - (l + w), top = H - (b + h), bottom = b}
    -- In einer Ecke liegen zwei Raender nah: dann bleibt die Leiste, wie sie ist (waagerecht bleibt waagerecht,
    -- Spieltest 24.11.2026: "in die ecken setzen (oben und unten) und sie waagerecht bleiben")
    local side, best
    local same = horiz and {top = true, bottom = true} or {left = true, right = true}
    for _, k in ipairs({"left", "right", "top", "bottom"}) do
        if d[k] <= R.SNAP and same[k] and (not best or d[k] < best) then side, best = k, d[k] end
    end
    if not side then
        for _, k in ipairs({"left", "right", "top", "bottom"}) do
            if not best or d[k] < best then side, best = k, d[k] end
        end
        if best > R.SNAP then return nil end
    end
    local E = R.EDGE
    if side == "left" or side == "right" then
        local cy, v, y = b + h / 2
        -- nah an der Ecke: ganz in die Ecke
        if cy > H * 2 / 3 then v, y = "TOP", (d.top <= R.SNAP) and -E or (b + h) - H
        elseif cy < H / 3 then v, y = "BOTTOM", (d.bottom <= R.SNAP) and E or b
        else v, y = "", cy - H / 2 end
        local pt = v .. (side == "left" and "LEFT" or "RIGHT")
        return side, {pt, pt, side == "left" and E or -E, y}
    end
    local cx, hz, x = l + w / 2
    if cx < W / 3 then hz, x = "LEFT", (d.left <= R.SNAP) and E or l
    elseif cx > W * 2 / 3 then hz, x = "RIGHT", (d.right <= R.SNAP) and -E or (l + w) - W
    else hz, x = "", cx - W / 2 end
    local pt = (side == "top" and "TOP" or "BOTTOM") .. hz
    return side, {pt, pt, x, side == "top" and -E or E}
end
-- Unten eingerastet: ueber den Aktionsleisten statt dahinter (Spieltest 24.11.2026: "verschwindet hinter der
-- skillleiste am unteren bildschirmrand"). Hoechste Oberkante der sichtbaren Blizzard-Leisten im unteren
-- Viertel, die waagerecht mit der Leiste [l, r] ueberlappen (Bildschirm-Einheiten); 0 = keine.
R.BOTTOM_BARS = {"MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBar5", "MultiBar6",
    "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar", "OverrideActionBar", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer", "StatusTrackingBarManager", "MicroMenuContainer", "BagsBar"}
-- dazu die einzelnen Knoepfe (falls ein Client die Leisten anders nennt; Spieltest 24.11.2026: Leiste
-- blieb trotzdem dahinter)
R.BOTTOM_BUTTONS = {"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button", "StanceButton", "PetActionButton", "PossessButton"}
function R.BottomFrames()
    local out = {}
    for _, name in ipairs(R.BOTTOM_BARS) do out[#out + 1] = name end
    for _, pre in ipairs(R.BOTTOM_BUTTONS) do for i = 1, 12 do out[#out + 1] = pre .. i end end
    return out
end
function R.BottomInset(l, r, found)
    local H = UIParent and UIParent.GetHeight and UIParent:GetHeight()
    if not (H and H > 0) then return 0 end
    local pes = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local top = 0
    for _, name in ipairs(R.BottomFrames()) do
        local bar = rawget(_G, name)
        if type(bar) == "table" and bar.IsVisible and bar.GetTop then
            local ok, vis, bt, bb, bl, br, es = pcall(function()
                return bar:IsVisible(), bar:GetTop(), bar:GetBottom(), bar:GetLeft(), bar:GetRight(),
                    bar.GetEffectiveScale and bar:GetEffectiveScale()
            end)
            if ok and vis and type(bt) == "number" and type(bb) == "number" and type(bl) == "number" and type(br) == "number" then
                local k = (es or pes) / pes
                bt, bb, bl, br = bt * k, bb * k, bl * k, br * k
                if bb < H * .25 and br > l - 10 and bl < r + 10 then
                    if found then found[#found + 1] = name .. "=" .. math.floor(bt + .5) end
                    if bt > top then top = bt end
                end
            end
        end
    end
    return top
end
-- Notausgang /trip leiste: zurueck an den linken Rand (Spieltest 24.11.2026: "wie bekomme ich sie wieder vor?")
function R:Reset()
    local s = Chat:Settings()
    local f = self.frame
    local found = {}
    local W = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local inset = R.BottomInset(0, W, found)
    s.railSide, s.railPoint = nil, nil
    self.liftY = nil
    if f then
        f:ClearAllPoints()
        f:SetPoint("LEFT", UIParent, "LEFT", 2, -40)
        self:Update()
    end
    ONE:Print(T("Chat-Leiste ist wieder am linken Rand."))
    ONE:Print(T("Leisten unten erkannt: %s (Oberkante %d)", #found > 0 and table.concat(found, ", ", 1, math.min(#found, 8)) or "-", math.floor(inset + .5)))
end
-- Hoehe einer unten eingerasteten Leiste (Anker pt, Laenge w): ueber den Leisten, die sie ueberlappt
function R.BottomY(pt, w)
    local W = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    if not (W and W > 0) then return R.EDGE end
    local x = tonumber(pt[3]) or 0
    local l = pt[1] == "BOTTOMLEFT" and x or pt[1] == "BOTTOMRIGHT" and (W + x - w) or (W / 2 + x - w / 2)
    local ok, inset = pcall(R.BottomInset, l, l + w)
    return R.EDGE + (ok and inset or 0)
end
function R:LiftBottom()
    local f = self.frame
    local pt = Chat:Settings().railPoint
    if not (f and R.Side() == "bottom" and type(pt) == "table") or self.dragging then return end
    local x = tonumber(pt[3]) or 0
    local y = R.BottomY(pt, f:GetWidth() or 0)
    if y == self.liftY and not self.liftDirty then return end
    self.liftY, self.liftDirty = y, nil
    f:ClearAllPoints()
    f:SetPoint(pt[1], UIParent, pt[2], x, y)
end
-- Leuchtstrich des aktiven Symbols: aussen (zum Bildschirmrand), quer zur Leiste
R.DIM, R.MARK_LEN, R.MARK_W = .72, 18, 3
function R.PlaceMark(b)
    local t = b.sel
    if not t then return end
    local side = R.Layout()
    t:ClearAllPoints()
    if side == "top" or side == "bottom" then t:SetSize(R.MARK_LEN, R.MARK_W) else t:SetSize(R.MARK_W, R.MARK_LEN) end
    if side == "right" then t:SetPoint("LEFT", b, "RIGHT", 1, 0)
    elseif side == "top" then t:SetPoint("BOTTOM", b, "TOP", 0, 1)
    elseif side == "bottom" then t:SetPoint("TOP", b, "BOTTOM", 0, -1)
    else t:SetPoint("RIGHT", b, "LEFT", -1, 0) end
end
-- Tooltip zur Bildschirmmitte hin
function R.TipAnchor()
    local side = R.Layout()
    return side == "right" and "ANCHOR_LEFT" or side == "top" and "ANCHOR_BOTTOM" or side == "bottom" and "ANCHOR_TOP" or "ANCHOR_RIGHT"
end
-- Blasen, Eingabezeile neben die Leiste (zur Mitte hin); force = auch wenn die Seite gleich blieb
function R:PlaceAround(force)
    local f, host = self.frame, self.host
    if not (f and host) then return end
    local side = R.Layout()
    if side == self.placedSide and not force then return end
    self.placedSide = side
    local function At(x, gap)
        x:ClearAllPoints()
        if side == "right" then x:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -gap, 0)
        elseif side == "bottom" then x:SetPoint("BOTTOM", f, "TOP", 0, gap)
        elseif side == "top" then x:SetPoint("TOP", f, "BOTTOM", 0, -gap)
        else x:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", gap, 0) end
    end
    At(host, self.BUBBLE_GAP)
    if self.quick then At(self.quick, 10) end
    local m = M()
    if self.docked and m then
        if m.picker then m:PlaceOverlay(m.picker, 20) end
        if chat.SlashList and chat.SlashList.frame then m:PlaceOverlay(chat.SlashList.frame, 25) end
        if chat.ItemList and chat.ItemList.frame then m:PlaceOverlay(chat.ItemList.frame, 26) end
    end
    self:LayoutBubbles()
end

function R.GroupOf(c)
    local m = M()
    if c.pinned then return "pinned" end
    if c.whisper then return "whisper" end
    if m and m.SYSTEM_VIEWS[c.view] then return "system" end
    return "talk"
end
-- {key = {convs …, unread = n}}; stumme Gespräche zählen nicht mit
function R.Groups()
    local out = {}
    for _, g in ipairs(R.GROUPS) do out[g.key] = {unread = 0} end
    for _, c in ipairs(M().Conversations()) do
        local g = out[R.GroupOf(c)]
        g[#g + 1] = c
        if not c.muted then g.unread = g.unread + (c.unread or 0) end
    end
    return out
end

local function IconPath(list)
    for _, name in ipairs(list) do
        local path = name:find("\\", 1, true) and name or ("Interface\\Icons\\" .. name)
        local ok, id = true, true
        if type(GetFileIDFromPath) == "function" then ok, id = pcall(GetFileIDFromPath, path) end
        if ok and id then return path end
    end
end
local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    return fs
end
local function GlassCard(frame, alpha)
    local G = ONE.Glass
    if not (G and G.Surface) then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(frame)
        bg:SetColorTexture(.04, .05, .07, alpha or .9)
        return nil
    end
    G.forceLook = "glass"
    local sf = G:Surface(frame, "card")
    G.forceLook = nil
    if sf then
        sf.store = function() return Chat:GlassStore() end
        if alpha then sf.onPaint = function(s2, p) s2.fill:SetColor(p.tint[1], p.tint[2], p.tint[3], alpha) end end
        if G.Paint then G:Paint(sf) end
    end
    return sf
end

-- ===== Leiste =====
function R:Build()
    if self.frame then return self.frame end
    local m = M()
    local s = Chat:Settings()
    local f = CreateFrame("Frame", "GuildTripChatRail", UIParent)
    f:SetWidth(self.WIDTH)
    f:SetHeight(self.WIDTH)
    local pt = type(s.railPoint) == "table" and s.railPoint
    if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("LEFT", UIParent, "LEFT", 2, -40) end
    -- ueber den Aktionsleisten (MEDIUM): nie dahinter verschwinden
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    -- Ziehen (auch an den Symbolen) verschiebt die Leiste (Spieltest 23.11.2026)
    f:SetScript("OnDragStart", function() R:StartDrag() end)
    f:SetScript("OnDragStop", function() R:StopDrag() end)
    self.surface = GlassCard(f)
    self.frame = f
    local tick = CreateFrame("Frame", nil, UIParent)
    tick:SetScript("OnUpdate", function(_, elapsed) R:Tick(elapsed or 0) end)
    -- Klick irgendwo ins Spiel schliesst den geoeffneten Reiter (Nutzer 23.11.2026)
    if tick.RegisterEvent then pcall(tick.RegisterEvent, tick, "GLOBAL_MOUSE_DOWN") end
    tick:SetScript("OnEvent", function(_, event) if event == "GLOBAL_MOUSE_DOWN" then R:GlobalClick() end end)
    self.ticker = tick
    -- Freunde: oeffnet das Fenster mit der Freundesliste
    self.friendsButton = self:NewIcon()
    self.friendsButton.iconPath = IconPath({"Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon"})
    self.friendsButton.onClick = function() R:OpenFriends() end
    self.friendsButton.tip = function()
        local m = M()
        local out = {{T("Freunde")}, {T("%d online", m.FriendsOnline and m.FriendsOnline() or 0)}}
        local req = m.FriendRequests and #m.FriendRequests() or 0
        if req > 0 then out[#out + 1] = {T("%d Freundschaftsanfragen", req), 1, .4, .4} end
        out[#out + 1] = {T("Klick: Freundesliste im Chatfenster"), .6, .6, .6}
        return out
    end
    -- unten: ganzes Fenster öffnen
    self.windowButton = self:NewIcon()
    self.windowButton.iconPath = IconPath({"Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up"})
    self.windowButton.onClick = function() R:OpenWindow() end
    self.windowButton.tip = function()
        return {{T("Chatfenster öffnen")}, {T("Enter öffnet nur die Eingabezeile.")}, {T("Ziehen verschiebt die Leiste."), .6, .6, .6},
            {T("Am Bildschirmrand rastet sie ein – links, rechts, oben oder unten."), .6, .6, .6}}
    end
    self:BuildBubbleHost()
    return f
end
-- Kreis wie in der Gesprächsliste: Bild/Buchstabe, Zähler, Leuchtring für das aktive Gespräch
function R:NewIcon()
    local f, m = self.frame, M()
    local b = CreateFrame("Button", nil, f)
    b:SetSize(self.ICON, self.ICON)
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    -- aktives Gespraech: kurzer Leuchtstrich aussen an der Leiste (Nutzer 24.11.2026 statt Ring, wie Discord)
    b.sel = b:CreateTexture(nil, "OVERLAY", nil, 7)
    b.sel:SetTexture(ONE.Glass and ONE.Glass.tex.circle or "Interface\\Buttons\\WHITE8X8")
    b.sel:Hide()
    b.av = b:CreateTexture(nil, "ARTWORK")
    b.av:SetAllPoints(b)
    b.av:SetTexture(ONE.Glass and ONE.Glass.tex.circle or "Interface\\Buttons\\WHITE8X8")
    b.letter = Text(b, "GameFontNormal")
    b.letter:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.letter:SetJustifyH("CENTER")
    b.glass = m.GlassAvatar(b, b.av, 2)
    b.badge = b:CreateTexture(nil, "OVERLAY", nil, 6)
    b.badge:SetSize(18, 14)
    b.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", 5, 3)
    b.badge:SetTexture("Interface\\AddOns\\ONE_Chat\\Textures\\Pill")
    b.badge:Hide()
    -- online: gruener Punkt unten rechts wie in der Gespraechsliste (Spieltest 23.11.2026)
    local circle = ONE.Glass and ONE.Glass.tex.circle or "Interface\\Buttons\\WHITE8X8"
    b.onlineRim = b:CreateTexture(nil, "OVERLAY", nil, 5)
    b.onlineRim:SetSize(11, 11)
    b.onlineRim:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    b.onlineRim:SetTexture(circle)
    b.onlineRim:SetVertexColor(.05, .06, .07, 1)
    b.onlineRim:Hide()
    b.online = b:CreateTexture(nil, "OVERLAY", nil, 6)
    b.online:SetSize(7, 7)
    b.online:SetPoint("CENTER", b.onlineRim, "CENTER", 0, 0)
    b.online:SetTexture(circle)
    b.online:SetVertexColor(.30, .90, .35)
    b.online:Hide()
    -- kleine Zahl unten rechts (Freunde online)
    b.sub = Text(b, "GameFontHighlightSmall")
    b.sub:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -3)
    b.sub:Hide()
    b.count = Text(b, "GameFontHighlightSmall")
    b.count:SetPoint("CENTER", b.badge, "CENTER", 0, 0)
    b.count:SetJustifyH("CENTER")
    if ONE.Fit then ONE.Fit:Line(b.count, false) end
    b:SetScript("OnClick", function(btn, button)
        -- Loslassen nach dem Ziehen ist kein Klick
        if R.draggedAt and Now() - R.draggedAt < .3 then return end
        if btn.onClick then btn.onClick(btn, button) end
    end)
    b:SetScript("OnDoubleClick", function(btn, button)
        if R.draggedAt and Now() - R.draggedAt < .3 then return end
        if button ~= "RightButton" and btn.onDouble then btn.onDouble(btn) end
    end)
    if b.RegisterForDrag then b:RegisterForDrag("LeftButton") end
    b:SetScript("OnDragStart", function() R:StartDrag() end)
    b:SetScript("OnDragStop", function() R:StopDrag() end)
    b:SetScript("OnEnter", function(btn)
        R:ShowCrest(btn)
        -- Drueberfahren: kurz verweilen zeigt die letzten Nachrichten (Nutzer 23.11.2026)
        if btn.conv then
            R.hoverIcon, R.hoverAt = btn, Now()
            if R.PREVIEW_DELAY <= 0 then R:StartPreview(btn) end
        end
        if not (GameTooltip and btn.tip) then return end
        GameTooltip:SetOwner(btn, R.TipAnchor())
        for i, l in ipairs(btn.tip() or {}) do
            if i == 1 then GameTooltip:SetText(l[1], l[2] or 1, l[3] or 1, l[4] or 1)
            else GameTooltip:AddLine(l[1], l[2] or .8, l[3] or .8, l[4] or .8, true) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end
function R:StartDrag()
    self.dragging = true
    self.frame:StartMoving()
end
-- Wohin die Leiste jetzt einrasten wuerde (Seite, Anker) – beim Ziehen fuer den Umriss, beim Loslassen
function R:SnapTarget()
    local f = self.frame
    local W, H = UIParent and UIParent.GetWidth and UIParent:GetWidth(), UIParent and UIParent.GetHeight and UIParent:GetHeight()
    local l, b = f and f.GetLeft and f:GetLeft(), f and f.GetBottom and f:GetBottom()
    if not (l and b and W and H and W > 0 and H > 0) then return nil end
    return R.SnapPoint(l, b, f:GetWidth(), f:GetHeight(), W, H, R.Horizontal())
end
-- Umriss beim Ziehen (Nutzer 24.11.2026: "waagerecht und senkrecht schon als Vorschau"): zeigt, wo und wie
-- die Leiste landet; weg, wenn sie frei bliebe
function R:BuildGhost()
    if self.ghost then return self.ghost end
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetFrameStrata("DIALOG")
    if g.EnableMouse then g:EnableMouse(false) end
    g.fill = g:CreateTexture(nil, "BACKGROUND")
    g.fill:SetAllPoints(g)
    g.fill:SetColorTexture(1, 1, 1, 1)
    g.edges = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local t = g:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            t:SetHeight(1)
            t:SetPoint(side .. "LEFT", g, side .. "LEFT", 0, 0)
            t:SetPoint(side .. "RIGHT", g, side .. "RIGHT", 0, 0)
        else
            t:SetWidth(1)
            t:SetPoint("TOP" .. side, g, "TOP" .. side, 0, 0)
            t:SetPoint("BOTTOM" .. side, g, "BOTTOM" .. side, 0, 0)
        end
        t:SetColorTexture(1, 1, 1, 1)
        g.edges[#g.edges + 1] = t
    end
    g:Hide()
    self.ghost = g
    return g
end
function R:UpdateGhost()
    local f = self.frame
    local side, pt = self:SnapTarget()
    if not side then
        if self.ghost then self.ghost:Hide() end
        return
    end
    local g = self:BuildGhost()
    local len = R.Horizontal() and f:GetWidth() or f:GetHeight()
    local horiz = side == "top" or side == "bottom"
    if horiz then g:SetSize(len, self.WIDTH) else g:SetSize(self.WIDTH, len) end
    local y = pt[4]
    if side == "bottom" then y = R.BottomY(pt, len) end
    local key = pt[1] .. ":" .. pt[3] .. ":" .. y .. ":" .. len .. ":" .. side
    if key ~= g.key then
        g.key = key
        g:ClearAllPoints()
        g:SetPoint(pt[1], UIParent, pt[2], pt[3], y)
        local m = M()
        local gl = m and m.Palette and m:Palette().glow or {1, .82, 0}
        g.fill:SetVertexColor(gl[1], gl[2], gl[3], .16)
        for _, t in ipairs(g.edges) do t:SetVertexColor(gl[1], gl[2], gl[3], .75) end
    end
    g:Show()
end
function R:StopDrag()
    local f = self.frame
    local s = Chat:Settings()
    -- erst messen (noch an der Maus), dann loslassen
    local side, pt = self:SnapTarget()
    f:StopMovingOrSizing()
    self.dragging = nil
    self.draggedAt = Now()
    if self.ghost then self.ghost:Hide() self.ghost.key = nil end
    s.railSide = side
    if pt then
        f:ClearAllPoints()
        f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
        s.railPoint = pt
        self.liftDirty = true
    else
        local p1, _, p2, x, y = f:GetPoint()
        if p1 then s.railPoint = {p1, p2, x, y} end
    end
    if not (InCombatLockdown and InCombatLockdown()) then self:HideCrest() end
    self:Update()
end
-- Jedes Gespräch ein eigenes Symbol, Gruppen (Angeheftet, Gespräche, Flüstern, System) mit Abstand
-- und feiner Linie dazwischen (Nutzer 23.11.2026)
function R:Update()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    local m = M()
    local p = m:Palette()
    local gl = p.glow
    local active = R.ActiveView()
    local groups = R.Groups()
    self.lines = self.lines or {}
    local y, n, nl = 5, 0, 0
    -- oben/unten eingerastet: Symbole nebeneinander, sonst untereinander
    local horiz = R.Horizontal()
    local function Put(w, off)
        w:ClearAllPoints()
        if horiz then w:SetPoint("LEFT", f, "LEFT", off, 0) else w:SetPoint("TOP", f, "TOP", 0, -off) end
    end
    local function Line()
        nl = nl + 1
        local t = self.lines[nl]
        if not t then
            t = f:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(1, 1, 1, .18)
            self.lines[nl] = t
        end
        if horiz then t:SetSize(1, self.ICON - 6) else t:SetSize(self.ICON - 6, 1) end
        Put(t, y + self.GAP / 2 - 2)
        t:Show()
        y = y + self.GAP
    end
    for _, def in ipairs(self.GROUPS) do
        local g = groups[def.key]
        if #g > 0 then
            if n > 0 then Line() end
            for _, c in ipairs(g) do
                n = n + 1
                local b = self.icons[n] or self:NewIcon()
                self.icons[n] = b
                b.conv = c
                b.onClick = function(btn, button) R:ClickConv(btn, c, button) end
                b.onDouble = function() R:OpenTab(c) end
                b.tip = function() return R.ConvTip(c) end
                Put(b, y)
                -- aktiv: etwas groesser (gleiche Mitte), Strich am Aussenrand
                local isActive = c.view == active
                local size = isActive and self.ICON + 4 or self.ICON
                b:SetSize(size, size)
                Put(b, y - (size - self.ICON) / 2)
                R.PlaceMark(b)
                local cr, cg, cb = m.AvatarColor(c)
                local icon, coords = m.AvatarIcon(c)
                m.PaintAvatar(b.glass, p, cr, cg, cb, icon, coords, b.letter, UI.First and UI.First(c.title) or c.title:sub(1, 1))
                b.base = {cr, cg, cb, icon and (m.iconDim[icon] or 1) or nil}
                -- Grundfarbe des Glaskreises merken (fuer das Atmen)
                local ar, ag, ab, aa
                if b.av.GetVertexColor then ar, ag, ab, aa = b.av:GetVertexColor() end
                b.baseAv = {ar or .2, ag or .2, ab or .22, aa or .55}
                b.sel:SetVertexColor(gl[1], gl[2], gl[3], 1)
                b.sel:SetShown(isActive)
                local unread = c.unread or 0
                if unread > 0 then
                    if c.muted then b.badge:SetVertexColor(.38, .38, .4) else b.badge:SetVertexColor(gl[1] * .8, gl[2] * .8, gl[3] * .8) end
                    local dark = not c.muted and p.onGlow and p.onGlow[1] < .5
                    b.count:SetText((dark and "|cff111111" or "|cffffffff") .. tostring(math.min(unread, 99)) .. "|r")
                    b.badge:SetWidth(unread > 9 and 22 or 16)
                    b.badge:Show() b.count:Show()
                else
                    b.badge:Hide() b.count:Hide()
                end
                -- die anderen leicht abgedunkelt; mit neuen Nachrichten voll (das rote Atmen soll kraeftig bleiben)
                b:SetAlpha(isActive and 1 or c.muted and .5 or unread > 0 and 1 or R.DIM)
                local info = c.whisper and m.PersonInfo(c.whisper)
                local on = info and info.online and true or false
                b.online:SetShown(on)
                b.onlineRim:SetShown(on)
                b.blink = unread > 0 and not c.muted and R.Blink()
                -- gleich im aktuellen Atemzug zeichnen: das Neuzeichnen jede Sekunde darf nicht dazwischenfunken
                -- (Spieltest 23.11.2026: "kein ruhiges atmen sondern ein unkontrolliertes zucken")
                if b.blink then R.Breathe(b, R.BreathX(Now()), gl) end
                b:Show()
                y = y + self.ICON + 4
            end
        end
    end
    for i = n + 1, #self.icons do self.icons[i]:Hide() end
    Line()
    for i = nl + 1, #self.lines do self.lines[i]:Hide() end
    -- vorletztes: Freunde (wie der Freunde-Knopf im Messenger, Nutzer 23.11.2026)
    local fb = self.friendsButton
    Put(fb, y)
    m.PaintAvatar(fb.glass, p, .30, .70, 1, fb.iconPath, fb.iconPath and {0, 1, 0, 1} or nil, fb.letter, "F")
    fb.sel:Hide() fb.online:Hide() fb.onlineRim:Hide() fb.blink = nil
    local fOn = m.FriendsOnline and m.FriendsOnline() or 0
    fb.sub:SetText(fOn > 0 and tostring(fOn) or "")
    fb.sub:SetShown(fOn > 0)
    local req = m.FriendRequests and #m.FriendRequests() or 0
    if req > 0 then
        fb.badge:SetVertexColor(.85, .15, .15)
        fb.count:SetText("|cffffffff" .. req .. "|r")
        fb.badge:Show() fb.count:Show()
    else
        fb.badge:Hide() fb.count:Hide()
    end
    fb:Show()
    y = y + self.ICON + 4
    local w = self.windowButton
    Put(w, y)
    m.PaintAvatar(w.glass, p, .6, .6, .65, w.iconPath, w.iconPath and {0, 1, 0, 1} or nil, w.letter, "+")
    w.sel:Hide() w.badge:Hide() w.count:Hide() w.online:Hide() w.onlineRim:Hide() w.blink = nil
    if horiz then f:SetSize(y + self.ICON + 6, self.WIDTH) else f:SetSize(self.WIDTH, y + self.ICON + 6) end
    self:LiftBottom()
    self:PlaceAround()
end
-- Wappen zum Gilden-Einladen neben einem Fluester-Symbol, nur beim Drueberfahren (Nutzer 23.11.2026:
-- "das Wappen zum Einladen dezent mit einfügen"). Sicherer Makro-Knopf (/ginvite), nur ausserhalb des Kampfs;
-- ein einziger Knopf, der zum Symbol wandert – feste sichere Knoepfe liessen sich im Kampf nicht umordnen.
R.CREST_LEAVE = .6
function R.CrestTarget(c)
    local m = M()
    local name = c and c.whisper
    if not name or (Chat.IsBN and Chat.IsBN(name)) then return nil end
    if not (m.CanInvite and m.CanInvite()) then return nil end
    local info = m.RosterInfo and m.RosterInfo(name)
    if info and info.inGuild then return nil end
    return name
end
function R:BuildCrest()
    if self.crest then return self.crest end
    local ok, b = pcall(CreateFrame, "Button", "GuildTripRailInvite", UIParent, "SecureActionButtonTemplate")
    if not ok or not b then return nil end
    b:SetSize(18, 18)
    b:SetFrameStrata("HIGH")
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b:SetAttribute("type", "macro")
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexture("Interface\\GossipFrame\\TabardGossipIcon")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    if hl.SetBlendMode then hl:SetBlendMode("ADD") end
    b:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, R.TipAnchor())
        GameTooltip:SetText(T("In die Gilde einladen"))
        GameTooltip:AddLine(T("Lädt %s in deine Gilde ein.", btn.target or "?"), .8, .8, .8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("PostClick", function() if not (InCombatLockdown and InCombatLockdown()) then R:HideCrest() end end)
    -- Kampfbeginn (kommt kurz bevor WoW sperrt): weg und vom Symbol loesen, sonst gaelte die Leiste als geschuetzt
    local ev = CreateFrame("Frame")
    if ev.RegisterEvent then ev:RegisterEvent("PLAYER_REGEN_DISABLED") end
    ev:SetScript("OnEvent", function() R:HideCrest() end)
    b:Hide()
    self.crest = b
    return b
end
function R:HideCrest()
    local b = self.crest
    if not b then return end
    self.crestLeft = nil
    b:Hide()
    b.icon = nil
    b:ClearAllPoints()
    b:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end
function R:ShowCrest(icon)
    if InCombatLockdown and InCombatLockdown() then return end
    local name = R.CrestTarget(icon.conv)
    if not name then self:HideCrest() return end
    local b = self:BuildCrest()
    if not b then return end
    b.target, b.icon = name, icon
    b:SetAttribute("macrotext", "/ginvite " .. name)
    b:ClearAllPoints()
    local side = R.Layout()
    if side == "right" then b:SetPoint("RIGHT", icon, "LEFT", -6, 0)
    elseif side == "top" then b:SetPoint("TOP", icon, "BOTTOM", 0, -6)
    elseif side == "bottom" then b:SetPoint("BOTTOM", icon, "TOP", 0, 6)
    else b:SetPoint("LEFT", icon, "RIGHT", 6, 0) end
    b:Show()
end
-- Tooltip: Name, letzte Nachricht, was Klicks tun
function R.ConvTip(c)
    local m = M()
    local cr, cg, cb = m.AvatarColor(c)
    local out = {{c.title, cr, cg, cb}}
    local last = m.LastEntry(c.view)
    if last then out[#out + 1] = {m.Preview(last), .9, .9, .9} end
    if (c.unread or 0) > 0 then out[#out + 1] = {T("%d ungelesen", c.unread), 1, .82, 0} end
    if c.view == R.openView then
        out[#out + 1] = {T("Offen: die Blasen bleiben stehen, Enter schreibt hierhin."), .6, .9, .6}
        out[#out + 1] = {T("Klick: schließen"), .6, .6, .6}
    else
        if c.view == R.ActiveView() then out[#out + 1] = {T("Aktiv: neue Nachrichten steigen als Blasen auf, Enter schreibt hierhin."), .6, .9, .6} end
        if c.view ~= R.ActiveView() then out[#out + 1] = {T("Klick: aktiv machen (Enter schreibt hierhin)"), .6, .6, .6} end
        out[#out + 1] = {T("Doppelklick: öffnen – die letzten Nachrichten bleiben als Blasen stehen"), .6, .6, .6}
    end
    out[#out + 1] = {T("Rechtsklick: Fenster öffnen, Anheften, Stumm …"), .6, .6, .6}
    return out
end
-- Klick: aktiv machen; nochmal Klick auf das aktive: Eingabezeile. Rechtsklick: Menü
-- Klick: Reiter oeffnen (aktiv, letzte Nachrichten stehen als Blasen da), nochmal Klick: schliessen
-- Klick: nur aktiv machen (Enter schreibt hierhin, Leuchtring); offener Reiter: Klick schliesst ihn.
-- Doppelklick: Reiter oeffnen (letzte Nachrichten stehen als Blasen da). Nutzer 23.11.2026
function R:ClickConv(owner, c, button)
    if button == "RightButton" then return self:ConvMenu(owner, c) end
    if self.openView == c.view then return self:CloseTab() end
    if self.openView then self:CloseTab() end
    self:SetActive(c.view)
end
function R:OpenTab(c)
    self.previewView, self.previewIcon = nil, nil
    self:SetActive(c.view)
    self.openView = c.view
    self:Replay(c.view)
end
-- Mausklick irgendwo: nicht auf Leiste, Blasen oder Eingabezeile -> offenen Reiter schliessen
function R:GlobalClick()
    if not (self.openView and R.Active()) then return end
    if Over(self.frame) or Over(self.quick) or Over(M().picker) then return end
    for _, b in ipairs(self.bubbles) do if Over(b) then return end end
    self:CloseTab()
end
-- Vorschau beim Verweilen ueber einem Symbol: dessen letzte Nachrichten stehen da, solange die Maus auf dem
-- Symbol (oder den Blasen) bleibt; danach wieder wie vorher (offener Reiter kommt zurueck)
-- sofort (Nutzer 23.11.2026: "darf gerne instant sein")
R.PREVIEW_DELAY, R.PREVIEW_LEAVE = 0, .25
function R:StartPreview(icon)
    local view = icon.conv and icon.conv.view
    if not view or view == self.openView or view == self.previewView then return end
    self.previewView, self.previewIcon, self.previewLeft = view, icon, nil
    self:Replay(view)
end
function R:EndPreview()
    if not self.previewView then return end
    self.previewView, self.previewIcon, self.previewLeft = nil, nil, nil
    self:ClearBubbles(true)
    if self.openView then self:Replay(self.openView) end
end
function R:CloseTab()
    self.openView = nil
    self:ClearBubbles(true)
    self:Update()
end
function R:SetActive(view)
    M():SwitchView(view)
    if self.quick and self.quick:IsShown() then self:PaintQuick() end
    self:Update()
end
-- Klick auf ein Symbol: die letzten Nachrichten dort steigen noch einmal als Blasen auf
-- (Spieltest 23.11.2026: "müssen wieder sichtbar sein, wenn man den Reiter anklickt"); gilt als gelesen
function R:Replay(view)
    local buf = Chat:Buffer(view)
    self:ClearBubbles(true)
    for i = math.max(1, #buf - self.REPLAY + 1), #buf do self:AddBubble(buf[i], view, true) end
    if (Chat.unread[view] or 0) > 0 then Chat:MarkRead(view) end
    self:Update()
end
function R:ConvMenu(owner, c)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local m = M()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if root.CreateTitle then root:CreateTitle(c.title) end
        root:CreateButton(T("Im Fenster öffnen"), function() R:OpenWindow(c.view) end)
        root:CreateButton(T("Hierhin schreiben"), function() UI:OpenInput(c.view) end)
        root:CreateButton(c.pinned and T("Lösen") or T("Anheften"), function() m.SetPinned(c.view, not c.pinned) R:Update() end)
        root:CreateButton(c.muted and T("Ton an") or T("Stummschalten"), function() m.SetMuted(c.view, not c.muted) R:Update() end)
        if (Chat.unread[c.view] or 0) > 0 then
            root:CreateButton(T("Als gelesen markieren"), function() Chat:MarkRead(c.view) R:Update() end)
        end
        if c.whisper then
            root:CreateButton(T("Gespräch schließen"), function()
                Chat:CloseWhisper(c.whisper)
                if UI.current == c.view then m:SwitchView("guild") end
                R:Update()
            end)
        end
    end)
end

-- ===== Blasen =====
function R:BuildBubbleHost()
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetSize(self.COLUMN_W, 10)
    host:SetFrameStrata("HIGH")
    if host.SetClampedToScreen then host:SetClampedToScreen(true) end
    self.host = host
    -- Abstand zur Leiste (Spieltest 23.11.2026: "zu nah an der Leiste"), auf der Seite zur Bildschirmmitte
    self:PlaceAround(true)
end
function R:NewBubble()
    local b = CreateFrame("Button", nil, self.host)
    b:SetWidth(self.BUBBLE_W)
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    -- Sprechblase wie im Messenger (Spieltest 23.11.2026: "sieht nicht mehr wie Blasen aus", "nicht durchsichtig"):
    -- durchscheinendes Glas, heller Rand, Glanz oben, Zipfel oben links zur Leiste hin
    local G = ONE.Glass
    if G and G.Nine then
        b.bg = G:Nine(b, G.tex.round, .25, "BACKGROUND", 1)
        b.edge = G:Nine(b, G.tex.roundRing, .25, "BACKGROUND", 2)
    end
    b.tail = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.tail:SetTexture(TAIL_TEX)
    b.tailEdge = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.tailEdge:SetTexture(TAIL_RING_TEX)
    b.sheen = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    if G and G.tex then b.sheen:SetTexture(G.tex.sheen) end
    -- Glas-Teile nicht ans Pixelraster haengen, sonst springen sie beim Steigen
    local parts = {b.tail, b.tailEdge, b.sheen}
    for _, nine in ipairs({b.bg, b.edge}) do for _, t in ipairs(nine.pieces or {}) do parts[#parts + 1] = t end end
    for _, rg in ipairs(parts) do
        if rg.SetSnapToPixelGrid then pcall(rg.SetSnapToPixelGrid, rg, false) end
        if rg.SetTexelSnappingBias then pcall(rg.SetTexelSnappingBias, rg, 0) end
    end
    b.name = Text(b, "GameFontNormalSmall")
    b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -8)
    if ONE.Fit then ONE.Fit:Line(b.name, false) end
    b.text = Text(b, "GameFontHighlight")
    b.text:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    -- Uhrzeit unten rechts wie im Fenster (Spieltest 23.11.2026: "keine Zeiten in den Blasen")
    b.time = Text(b, "GameFontDisableSmall")
    b.time:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 5)
    b.time:SetJustifyH("RIGHT")
    if ONE.Fit then ONE.Fit:Line(b.time, false) end
    if b.text.SetWordWrap then b.text:SetWordWrap(true) end
    b:SetScript("OnClick", function(btn, button)
        if button == "RightButton" then R:DropBubble(btn) return end
        -- Alt+Klick: Absender in die Gilde einladen (sicherer Knopf an der Maus)
        local e = btn.entry
        if e and not e.inform and not (Chat.IsPlain and Chat.IsPlain(e)) and UI.AltInvite and UI:AltInvite(e.author) then return end
        R:OpenWindow(btn.view)
    end)
    -- Drueberfahren: steht ein Gegenstand (Zauber, Quest …) in der Nachricht, gleich dessen Tooltip zeigen
    -- (Nutzer 23.11.2026: "einfach nur über einen geposteten Link fürs Gear drüberhovern"). Echte Link-Ereignisse
    -- kommen in Forever bei eigenen Rahmen nicht zuverlaessig an (Spieltest 22.11.) -> ganze Blase zaehlt,
    -- bei mehreren Links blaettert das Mausrad.
    b:SetScript("OnEnter", function(btn) R:BubbleTip(btn) end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if b.EnableMouseWheel then b:EnableMouseWheel(true) end
    b:SetScript("OnMouseWheel", function(btn, delta)
        local n = #(btn.links or {})
        if n < 2 then return end
        btn.linkIndex = ((btn.linkIndex or 1) - (delta > 0 and 1 or -1) - 1) % n + 1
        R:BubbleTip(btn)
    end)
    return b
end
-- Links mit Tooltip: gemeinsam mit dem Fenster (Messenger.TipLinks)
function R.TipLinks(text) return M().TipLinks(text) end
function R:BubbleTip(btn)
    if not GameTooltip then return end
    GameTooltip:SetOwner(btn, R.TipAnchor())
    local links = btn.links or {}
    local l = links[btn.linkIndex or 1]
    if l and pcall(GameTooltip.SetHyperlink, GameTooltip, l.link) then
        if #links > 1 then
            GameTooltip:AddLine(T("Mausrad: nächster Link (%d/%d)", btn.linkIndex or 1, #links), .6, .6, .6, true)
        end
        GameTooltip:AddLine(T("Klick: Gespräch öffnen"), .6, .6, .6, true)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetText(T("Klick: Gespräch öffnen"))
    GameTooltip:AddLine(T("Rechtsklick: Blase wegklicken"), .8, .8, .8, true)
    GameTooltip:Show()
end
local function ClassRGB(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 1, .82, 0
end
-- "14:05"; aelter als heute: "22.11. 14:05"
function R.TimeText(t)
    if type(t) ~= "number" or t <= 0 or type(date) ~= "function" then return "" end
    local now = type(time) == "function" and time() or t
    if date("%Y%m%d", t) == date("%Y%m%d", now) then return date("%H:%M", t) end
    return date("%d.%m. %H:%M", t)
end
-- Eigene Nachricht? Auch eigene Emotes ("Ihr winkt …", von Hand oder automatisch; Nutzer 23.11.2026: "der
-- Übersicht halber rechts")
-- gemeinsam mit dem Fenster (Messenger.IsOwn), damit beide dieselben Nachrichten rechts zeigen
function R.IsOwn(entry) return M().IsOwn(entry) end
-- Kopf der Blase: "Du", "Thorgrim", "Thorgrim flüstert", "[Gilde] Thorgrim"
function R.BubbleHead(entry, view)
    local m = M()
    local me = type(UnitName) == "function" and UnitName("player") or nil
    local who = Chat.Short(entry.author or "")
    local out = R.IsOwn(entry)
    local r, g, b = ClassRGB(m.ClassOfGuid(entry.guid, entry.author))
    local name = out and T("Du") or who
    -- Meldung ohne Absender (System, NPC-Emote …): nur die Art, nicht der Reitername als Absender
    -- (Spielbild 23.11.2026: "[System] Alle")
    if Chat.IsPlain and Chat.IsPlain(entry) then
        local k = Chat.kindByKey and Chat.kindByKey[entry.kind]
        local c = k and type(k.color) == "table" and k.color or {1, 1, .45}
        return k and T(k.label) or T("System"), c[1] or 1, c[2] or 1, c[3] or .45
    end
    if entry.kind == "whisper" and not out then name = T("%s flüstert", who)
    elseif entry.kind == "whisper" then name = T("Du an %s", Chat.Short(m.ViewTitle(view)))
    elseif view ~= R.ActiveView() or view == "all" then
        local k = Chat.kindByKey and Chat.kindByKey[entry.kind]
        if k then name = "[" .. T(k.label) .. "] " .. name end
    end
    return name, r, g, b
end
-- static = Blase des geoeffneten Reiters: steht still, verblasst nicht (Spieltest 23.11.2026: "wenn der
-- tab offen ist, müssen die blasen nicht wandern und verblassen")
function R:AddBubble(entry, view, static)
    local m = M()
    local b = table.remove(self.spare or {}) or self:NewBubble()
    b.view, b.entry = view, entry
    b.links, b.linkIndex = R.TipLinks(entry.text), 1
    -- eigene rechts, empfangene links (Nutzer 23.11.2026: "wie im Messenger links und rechts");
    -- eigene im offenen Reiter ohne Namenszeile
    local me = type(UnitName) == "function" and UnitName("player") or nil
    b.out = R.IsOwn(entry)
    local showName = not (b.out and static)
    local name, r, g, bl = R.BubbleHead(entry, view)
    b.name:SetText(showName and name or "")
    b.name:SetShown(showName)
    b.name:SetTextColor(r, g, bl)
    b.text:ClearAllPoints()
    if showName then b.text:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    else b.text:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -9) end
    local W = self.BUBBLE_W - 20
    -- aufsteigende kurz (4 Zeilen), im offenen Reiter ganz (Spielbild 23.11.2026: Text mit "..." abgeschnitten)
    local maxLines = static and 12 or 4
    if b.text.SetMaxLines then pcall(b.text.SetMaxLines, b.text, maxLines) end
    b.text:SetWidth(W)
    b.text:SetText(m.Show(entry.text or "", 14))
    local nw = showName and b.name.GetStringWidth and b.name:GetStringWidth() or 0
    local tw = math.min(W, math.max(b.text.GetStringWidth and b.text:GetStringWidth() or W, nw))
    b.text:SetWidth(math.max(30, tw))
    local th = math.min(maxLines * 16, b.text.GetStringHeight and b.text:GetStringHeight() or 16)
    b.time:SetText(R.TimeText(entry.time))
    local timeW = (b.time.GetStringWidth and b.time:GetStringWidth() or 30) + 6
    b:SetWidth(math.max(showName and 80 or 60, tw + 24, timeW + 24))
    b:SetHeight(th + (showName and 34 or 20) + 11)
    self:PaintBubble(b, entry)
    b.rise = 0
    b.static = static and true or false
    b:SetAlpha(1)
    b:Show()
    table.insert(self.bubbles, b)
    if static then
        -- hoechstens BUBBLE_MAX stehende, aelteste fallen weg
        local n = 0
        for i = #self.bubbles, 1, -1 do
            local o = self.bubbles[i]
            if o.static then n = n + 1 if n > self.STATIC_MAX then self:DropBubble(o) end end
        end
    else
        -- aeltere weiter nach oben schieben, damit die neue unten Platz hat
        local need = (b:GetHeight() or 40) + 6
        for i = #self.bubbles - 1, 1, -1 do
            local o = self.bubbles[i]
            if not o.static then
                if (o.rise or 0) < need then o.rise = need end
                need = o.rise + (o:GetHeight() or 40) + 6
            end
        end
        local n = 0
        for i = #self.bubbles, 1, -1 do
            local o = self.bubbles[i]
            if not o.static then n = n + 1 if n > self.BUBBLE_MAX then self:DropBubble(o) end end
        end
    end
    self:LayoutBubbles()
    return b
end
-- Farben wie die Blasen im Fenster (Art-Farbe, eigene in der Leuchtfarbe), Flaeche durchscheinend
function R:PaintBubble(b, entry)
    local m = M()
    local p = m:Palette()
    local out = b.out
    local cr, cg, cb, ca, er, eg, eb, ea = m.BubbleColor(p, out, entry.failed, entry.kind)
    -- Zipfel aussen oben: empfangene links (Ecke 1), eigene rechts (Ecke 3)
    local ci = out and 3 or 1
    b.alphaFill = ca
    if b.bg then
        b.bg:SetColor(cr, cg, cb, ca)
        b.bg:Place(BUBBLE_R, 0, b)
        for i, piece in ipairs(b.bg.pieces or {}) do if i == ci then piece:Hide() else piece:Show() end end
    end
    b.tail:ClearAllPoints()
    b.tail:SetSize(2 * BUBBLE_R, BUBBLE_R)
    if out then
        b.tail:SetPoint("TOPLEFT", b, "TOPRIGHT", -BUBBLE_R, 0)
        b.tail:SetTexCoord(1, 0, 0, 1)
    else
        b.tail:SetPoint("TOPRIGHT", b, "TOPLEFT", BUBBLE_R, 0)
        b.tail:SetTexCoord(0, 1, 0, 1)
    end
    b.tail:SetVertexColor(cr, cg, cb, ca)
    if b.edge then
        b.edge:SetColor(er, eg, eb, ea)
        b.edge:Place(BUBBLE_R, 0, b)
        for i, piece in ipairs(b.edge.pieces or {}) do if i == ci then piece:Hide() else piece:Show() end end
    end
    b.tailEdge:ClearAllPoints()
    b.tailEdge:SetAllPoints(b.tail)
    b.tailEdge:SetTexCoord(out and 1 or 0, out and 0 or 1, 0, 1)
    b.tailEdge:SetVertexColor(er, eg, eb, ea)
    b.sheen:ClearAllPoints()
    b.sheen:SetPoint("TOPLEFT", b, "TOPLEFT", BUBBLE_R - 2, -1)
    b.sheen:SetPoint("TOPRIGHT", b, "TOPRIGHT", -(BUBBLE_R - 2), -1)
    b.sheen:SetHeight(math.max(6, math.floor((b:GetHeight() or 40) * .45)))
    b.sheen:SetVertexColor(1, 1, 1, out and .06 or .04)
end
function R:DropBubble(b)
    for i, x in ipairs(self.bubbles) do if x == b then table.remove(self.bubbles, i) break end end
    b:Hide()
    self.spare = self.spare or {}
    table.insert(self.spare, b)
    self:LayoutBubbles()
end
function R:ClearBubbles(staticOnly)
    for i = #self.bubbles, 1, -1 do
        local b = self.bubbles[i]
        if b and (not staticOnly or b.static) then self:DropBubble(b) end
    end
end
-- Blasen steigen von unten nach oben und verblassen, je hoeher sie kommen (Spieltest 23.11.2026);
-- ueber der Eingabezeile, wenn die offen ist
-- untere Haelfte voll sichtbar, erst darueber blasser (Spieltest 23.11.2026: "verblassen zu schnell")
function R.RiseAlpha(rise, height)
    local top = (rise or 0) + (height or 40)
    local from = R.RISE_H * .5
    local a = 1 - math.max(0, top - from) / (R.RISE_H - from)
    return math.max(0, math.min(1, a))
end
-- unten die stehenden Blasen des geoeffneten Reiters, darueber steigen die anderen auf
function R:LayoutBubbles()
    if not self.host then return end
    local y = (self.quick and self.quick:IsShown()) and (self.QUICK_H + 6) or 0
    -- Leiste oben: Blasen haengen darunter und sinken nach unten (gespiegelt)
    local down = R.Layout() == "top"
    local v, sign = down and "TOP" or "BOTTOM", down and -1 or 1
    local pl, pr = v .. "LEFT", v .. "RIGHT"
    for i = #self.bubbles, 1, -1 do
        local b = self.bubbles[i]
        if b.static then
            b:ClearAllPoints()
            if b.out then b:SetPoint(pr, self.host, pr, 0, sign * y)
            else b:SetPoint(pl, self.host, pl, 0, sign * y) end
            b:SetAlpha(1)
            y = y + (b:GetHeight() or 40) + 6
        end
    end
    for i = #self.bubbles, 1, -1 do
        local b = self.bubbles[i]
        if not b.static then
            b:ClearAllPoints()
            -- ohne Runden: fliessend statt in Pixel-Spruengen (Spieltest 23.11.2026: "sehr ruckelig")
            if b.out then b:SetPoint(pr, self.host, pr, 0, sign * (y + (b.rise or 0)))
            else b:SetPoint(pl, self.host, pl, 0, sign * (y + (b.rise or 0))) end
            b:SetAlpha(R.RiseAlpha(b.rise, b:GetHeight()))
        end
    end
end
-- Steiggeschwindigkeit: in "Blasen sichtbar" Sekunden ganz nach oben
function R.RiseSpeed() return R.RISE_H / math.max(2, R.BubbleTime()) end
-- Neue Nachricht, während das Fenster zu ist
function R:OnMessage(entry, views)
    if not (R.Active() and self.frame and self.frame:IsShown()) then return end
    local here
    local active = R.ActiveView()
    for _, v in ipairs(views or {}) do if v == active then here = v end end
    local view = here
    if not view and entry.kind == "whisper" and not entry.inform and R.WhisperBubbles() then
        for _, v in ipairs(views or {}) do if type(v) == "string" and v:sub(1, 2) == "w:" then view = v end end
    end
    -- geoeffneter Reiter: Blase bleibt stehen und gilt als gelesen
    local standing = self.previewView or self.openView
    if standing then
        for _, v in ipairs(views or {}) do
            if v == standing then
                self:AddBubble(entry, v, true)
                Chat:MarkRead(v)
                self:Update()
                return
            end
        end
    end
    if not view or M().IsMuted(view) then self:Update() return end
    self:AddBubble(entry, view)
    self:Update()
end

-- ===== Eingabezeile (Enter) =====
-- Die Eingabezeile des Fensters (Emoji-Knopf, Feld, Senden) wandert in einen kleinen Rahmen neben der Leiste.
function R:BuildQuick()
    if self.quick then return self.quick end
    local m = M()
    m:Build()
    local q = CreateFrame("Frame", "GuildTripChatQuickInput", UIParent)
    q:SetSize(self.QUICK_W, self.QUICK_H)
    q:SetFrameStrata("HIGH")
    if q.SetClampedToScreen then q:SetClampedToScreen(true) end
    q:EnableMouse(true)
    -- kein Hintergrund, nur ein leichter Rand (Spielbild 23.11.2026: "nur ein leichter rand drumherum")
    q.border = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local t = q:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            t:SetHeight(1)
            t:SetPoint(side .. "LEFT", q, side .. "LEFT", 0, 0)
            t:SetPoint(side .. "RIGHT", q, side .. "RIGHT", 0, 0)
        else
            t:SetWidth(1)
            t:SetPoint("TOP" .. side, q, "TOP" .. side, 0, 0)
            t:SetPoint("BOTTOM" .. side, q, "BOTTOM" .. side, 0, 0)
        end
        t:SetColorTexture(1, 1, 1, .18)
        q.border[#q.border + 1] = t
    end
    -- "An: Gilde" – Klick wählt das Ziel
    local to = CreateFrame("Button", nil, q)
    to:SetPoint("TOPLEFT", q, "TOPLEFT", 8, -3)
    to:SetSize(self.QUICK_W - 16, 14)
    to.text = Text(to, "GameFontNormalSmall")
    to.text:SetAllPoints(to)
    if ONE.Fit then ONE.Fit:Line(to.text, false) end
    to:SetScript("OnClick", function(btn) R:TargetMenu(btn) end)
    q.to = to
    q:Hide()
    self.quick = q
    self:PlaceAround(true)
    -- Fokus weg (Esc, Senden, Klick ins Spiel): Zeile schließt sich kurz danach
    local box = m.input
    local lost = box:GetScript("OnEditFocusLost")
    box:SetScript("OnEditFocusLost", function(b, ...)
        if lost then lost(b, ...) end
        R:FocusLost()
    end)
    -- Tab: Ziel wechseln statt Fenster öffnen
    local tab = box:GetScript("OnTabPressed")
    box:SetScript("OnTabPressed", function(b, ...)
        if R.docked then
            if chat.ItemList and chat.ItemList:Complete() then return end
            if chat.SlashList and chat.SlashList:Complete() then return end
            R:CycleTarget(IsShiftKeyDown and IsShiftKeyDown())
            return
        end
        if tab then tab(b, ...) end
    end)
    return q
end
-- Ziele zum Schreiben: Reiter mit Schreibrecht und Flüstergespräche
function R.Targets()
    local out = {}
    for _, t in ipairs(Chat:Tabs()) do if Chat:Target(t.id) then out[#out + 1] = t.id end end
    for _, w in ipairs(Chat.whispers) do out[#out + 1] = Chat.WhisperView(w.name) end
    return out
end
function R:CycleTarget(back)
    local list = R.Targets()
    if #list == 0 then return end
    local idx = 0
    for i, v in ipairs(list) do if v == UI.current then idx = i end end
    idx = back and ((idx - 2) % #list + 1) or (idx % #list + 1)
    self:SetTarget(list[idx])
end
function R:TargetMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return self:CycleTarget() end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, v in ipairs(R.Targets()) do
            local m = M()
            local label = v:sub(1, 2) == "w:" and T("Flüstern: %s", v:sub(3)) or m.ViewTitle(v)
            root:CreateButton(label, function() R:SetTarget(v) end)
        end
    end)
end
function R:SetTarget(view)
    local m = M()
    m:SwitchView(view)
    self:PaintQuick()
    if m.input and m.input.SetFocus then m.input:SetFocus() end
end
function R:PaintQuick()
    local q, m = self.quick, M()
    if not q then return end
    local view = UI.current or "guild"
    local whisper = view:sub(1, 2) == "w:"
    local label = whisper and view:sub(3) or (Chat:Target(view) and m.SendLabel(view)) or nil
    local p = m:Palette()
    q.to.text:SetText(label and (T("An: %s", label) .. "  |cff8a8a8a" .. T("(Tab wechselt)") .. "|r") or T("Hier kann man nur lesen."))
    q.to.text:SetTextColor(p.title[1], p.title[2], p.title[3])
    m:RefreshHead()
end
-- Zeile des Fensters hierher holen (on) oder zurück ins Fenster
function R:Dock(on)
    local m = M()
    local foot = m.foot
    if not foot then return end
    foot:ClearAllPoints()
    if on then
        foot:SetParent(self.quick)
        foot:SetPoint("BOTTOMLEFT", self.quick, "BOTTOMLEFT", 6, 1)
        foot:SetPoint("BOTTOMRIGHT", self.quick, "BOTTOMRIGHT", -6, 1)
    else
        foot:SetParent(m.main)
        foot:SetPoint("BOTTOMLEFT", m.main, "BOTTOMLEFT", 0, 0)
        foot:SetPoint("BOTTOMRIGHT", m.main, "BOTTOMRIGHT", 0, 0)
    end
    self.docked = on and true or false
    if m.picker then m:PlaceOverlay(m.picker, 20) end
    if chat.SlashList and chat.SlashList.frame then m:PlaceOverlay(chat.SlashList.frame, 25) end
    if chat.ItemList and chat.ItemList.frame then m:PlaceOverlay(chat.ItemList.frame, 26) end
end
function R:OpenInput(view, text)
    local m = M()
    self:Build()
    self:BuildQuick()
    if view then m:SwitchView(view)
    elseif not Chat:Target(UI.current or "") and not (UI.current or ""):find("^w:") then m:SwitchView("guild") end
    if not self.docked then self:Dock(true) end
    self.quick:Show()
    self.quickLeft = nil
    self:PaintQuick()
    self:LayoutBubbles()
    local box = m.input
    if box then
        if box.SetFocus then box:SetFocus() end
        if text and text ~= "" then box:SetText(text) if box.SetCursorPosition then box:SetCursorPosition(#text) end end
    end
    return true
end
function R:CloseInput()
    local m = M()
    if m.picker then m.picker:Hide() end
    if chat.SlashList then chat.SlashList:Hide() end
    if chat.ItemList then chat.ItemList:Hide() end
    if self.quick then self.quick:Hide() end
    if self.docked then self:Dock(false) end
    self.quickLeft = nil
    self:LayoutBubbles()
end
function R:FocusLost()
    if not self.docked then return end
    local function Check()
        local m = M()
        if not self.docked or (m.input and m.input.HasFocus and m.input:HasFocus()) then return end
        -- Klick in die Emoji-Auswahl oder auf "An:": offen lassen (Tick schließt später)
        if Over(self.quick) or Over(m.picker) or Over(chat.SlashList and chat.SlashList.frame) or Over(chat.ItemList and chat.ItemList.frame) then return end
        self:CloseInput()
    end
    if C_Timer and C_Timer.After then C_Timer.After(.2, Check) else Check() end
end

-- ===== Fenster (Nutzer 23.11.2026: "fenster auf = leiste von links nach rechts in ein fenster öffnen") =====
-- Randleiste an: das Fenster geht an der Leiste auf (linker Rand = Leiste), klappt nach rechts auf, die Leiste
-- ist solange weg. Schliessen klappt nach links zu, dann ist die Leiste wieder da.
function R:OpenWindow(view)
    UI:Show(view)
end
local function ES(f) return (f and f.GetEffectiveScale and f:GetEffectiveScale()) or 1 end
function R:OpenFriends()
    UI:Show()
    local m = M()
    if m.ToggleFriends then m:ToggleFriends(true) end
end
function R:PlaceWindow(f)
    local r = self.frame
    local rl, rb, rh = r and r.GetLeft and r:GetLeft(), r and r.GetBottom and r:GetBottom(), r and r.GetHeight and r:GetHeight()
    if not (rl and rb and rh) then return false end
    local rw = (r.GetWidth and r:GetWidth()) or 0
    local k = ES(r) / ES(f)
    local side = R.Layout()
    f:ClearAllPoints()
    -- Fenster beginnt dort, wo die Leiste war (gleicher Rand), Mitte auf Mitte der Leiste
    if side == "right" then f:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", (rl + rw) * k, (rb + rh / 2) * k)
    elseif side == "top" then f:SetPoint("TOP", UIParent, "BOTTOMLEFT", (rl + rw / 2) * k, (rb + rh) * k)
    elseif side == "bottom" then f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", (rl + rw / 2) * k, rb * k)
    else f:SetPoint("LEFT", UIParent, "BOTTOMLEFT", rl * k, (rb + rh / 2) * k) end
    return true
end
-- ShowView ruft das zuerst: Zeile zurück ins Fenster, Blasen weg; frisch geoeffnet -> an die Leiste
function R:OnWindowShown()
    if self.docked or (self.quick and self.quick:IsShown()) then self:CloseInput() end
    self:ClearBubbles()
    self.openView = nil
    local f = M().frame
    self.openFresh = R.Active() and self.frame ~= nil and f and not f:IsShown() and not self.anim
    if self.openFresh then self:PlaceWindow(f) end
end
-- ShowView ruft das zuletzt: Leiste weg, aufklappen
function R:AfterWindowShown()
    if not self.openFresh then return end
    self.openFresh = nil
    self.idle = 0
    if self.frame then self.frame:Hide() end
    self:Animate(true)
end
-- M:Hide fragt zuerst hier: Randleiste an -> erst zuklappen (true = Hide kommt spaeter)
function R:CloseWindow()
    local f = M().frame
    if not (R.Active() and f and f:IsShown()) or self.anim then return false end
    return self:Animate(false, function() M():Hide(true) end)
end
-- Fenster versteckt: Leiste wieder zeigen
function R:OnWindowHidden()
    if R.Active() and self.frame and not self.frame:IsShown() then
        self.frame:Show()
        self:Update()
    end
end
-- Vorhang: das Fenster haengt kurz in einem Rahmen, der nur seinen linken Teil zeigt, und dieser waechst
-- (oeffnen) oder schrumpft (schliessen). Ohne Masse (noch nicht angeordnet) sofort fertig.
function R:Animate(opening, done)
    local f = M().frame
    local L, Tp, W, H = f.GetLeft and f:GetLeft(), f.GetTop and f:GetTop(), f:GetWidth(), f:GetHeight()
    if not (L and Tp and W and W > 0 and H and H > 0) or self.ANIM <= 0 then
        if done then done() end
        return done ~= nil
    end
    local c = self.clip
    if not c then
        c = CreateFrame("Frame", nil, UIParent)
        if c.SetClipsChildren then c:SetClipsChildren(true) end
        self.clip = c
    end
    local fs = (f.GetScale and f:GetScale()) or 1
    if c.SetScale then c:SetScale(ES(f) / (ES(UIParent) * fs)) end
    c:SetFrameStrata("MEDIUM")
    c:ClearAllPoints()
    -- der Rahmen waechst von der Leistenseite aus (links/rechts in der Breite, oben/unten in der Hoehe)
    local side = R.Layout()
    local vertical = side == "top" or side == "bottom"
    local anchor = side == "right" and "TOPRIGHT" or side == "bottom" and "BOTTOMLEFT" or "TOPLEFT"
    local ax = side == "right" and (L + W) or L
    local ay = side == "bottom" and (Tp - H) or Tp
    c:SetPoint(anchor, UIParent, "BOTTOMLEFT", ax * fs, ay * fs)
    if vertical then
        c:SetWidth(W * fs)
        c:SetHeight(opening and 1 or H * fs)
    else
        c:SetHeight(H * fs)
        c:SetWidth(opening and 1 or W * fs)
    end
    c:Show()
    f:SetParent(c)
    f:ClearAllPoints()
    f:SetPoint(anchor, c, anchor, 0, 0)
    local anim = {t = 0, opening = opening, W = (vertical and H or W) * fs, vertical = vertical, L = L, Tp = Tp, done = done}
    self.anim = anim
    c:SetScript("OnUpdate", function(_, elapsed) R:AnimStep(elapsed or 0) end)
    return true
end
function R:AnimStep(elapsed)
    local a, c = self.anim, self.clip
    if not a then return end
    a.t = a.t + elapsed
    local p = math.min(1, a.t / self.ANIM)
    local e = 1 - (1 - p) * (1 - p)     -- weich auslaufen
    local w = a.opening and e or (1 - e)
    if a.vertical then c:SetHeight(math.max(1, a.W * w)) else c:SetWidth(math.max(1, a.W * w)) end
    if p >= 1 then self:EndAnim() end
end
function R:EndAnim()
    local a, c = self.anim, self.clip
    if not a then return end
    self.anim = nil
    local f = M().frame
    c:SetScript("OnUpdate", nil)
    f:SetParent(UIParent)
    f:SetFrameStrata("MEDIUM")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", a.L, a.Tp)
    c:Hide()
    if a.done then a.done() end
end

-- Atmen (Nutzer 23.11.2026: Symbole selbst aufleuchten lassen statt eines Rings): 0 = normal, 1 = hell.
-- Kosinus, ein ruhiger Atemzug alle R.BLINK_T Sekunden.
R.BLINK_T = 2.0
function R.BreathX(now)
    return (1 - math.cos(2 * math.pi * (now % R.BLINK_T) / R.BLINK_T)) / 2
end
-- Bild heller, Glanz staerker, eigener Rand in Richtung Leuchtfarbe – nichts kommt dazu
-- Rand atmet in kraeftigem Rot (Nutzer 24.11.2026: "umrandungen ... in einem kräftigen rot atmen"),
-- der Glaskreis faerbt sich leicht mit, Bild heller, Glanz
R.BREATH_RED = {1, .1, .1}
function R.Breathe(b, x, glow)
    local a, base = b.glass, b.base
    if not (a and base) then return end
    local red = R.BREATH_RED
    a.ring:SetVertexColor(base[1] + (red[1] - base[1]) * x, base[2] + (red[2] - base[2]) * x, base[3] + (red[3] - base[3]) * x, .65 + .35 * x)
    local av = b.baseAv
    if av and a.av then
        local k = .45 * x
        a.av:SetVertexColor(av[1] + (red[1] - av[1]) * k, av[2] + (red[2] - av[2]) * k, av[3] + (red[3] - av[3]) * k, av[4] + (.9 - av[4]) * x)
    end
    a.shine:SetVertexColor(1, 1, 1, .30 + .45 * x)
    if base[4] then
        local v = base[4] + (1 - base[4]) * x
        a.icon:SetVertexColor(v, v, v, .92 + .08 * x)
    end
    b.breath = x
end
-- ===== Takt: Blasen steigen, Eingabe zu, Zähler, Blinken, Fenster von selbst zu =====
function R:Tick(elapsed)
    if not R.Active() then return end
    local now = Now()
    if self.dragging then self:UpdateGhost() end
    -- Vorschau: verweilen startet, Maus weg (nicht Symbol, nicht eine stehende Blase) beendet
    local hi = self.hoverIcon
    if hi then
        if not Over(hi) then self.hoverIcon = nil
        elseif now - (self.hoverAt or now) >= self.PREVIEW_DELAY and hi.conv and hi.conv.view ~= self.previewView then
            self:StartPreview(hi)
        end
    end
    if self.previewView then
        local keep = Over(self.previewIcon)
        if not keep then for _, b in ipairs(self.bubbles) do if b.static and Over(b) then keep = true end end end
        if keep then self.previewLeft = nil
        else
            self.previewLeft = self.previewLeft or now
            if now - self.previewLeft >= self.PREVIEW_LEAVE then self:EndPreview() end
        end
    end
    local crest = self.crest
    if crest and crest:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
        -- kurze Gnadenfrist: der Weg vom Symbol zum Wappen fuehrt ueber eine Luecke (Spieltest 24.11.2026:
        -- "sobald ich mit der Maus vom Icon gehe, verschwindet auch das Wappen")
        if not (self.frame and self.frame:IsShown()) then self:HideCrest()
        elseif Over(crest) or Over(crest.icon) then self.crestLeft = nil
        else
            self.crestLeft = self.crestLeft or now
            if now - self.crestLeft >= self.CREST_LEAVE then self:HideCrest() end
        end
    end
    -- Blinken: Ring um Symbole mit wartenden Nachrichten pulsiert
    if self.frame and self.frame:IsShown() then
        local x = R.BreathX(now)
        local col
        for _, b in ipairs(self.icons) do
            if b.blink and b:IsShown() then
                col = col or M():Palette().glow
                R.Breathe(b, x, col)
            end
        end
    end
    -- Fenster von selbst zu (Einstellung, Standard aus)
    local f = M() and M().frame
    local limit = R.AutoClose()
    if limit > 0 and f and f:IsShown() and not self.anim then
        local m = M()
        local busy = Over(f) or (m.input and m.input.HasFocus and m.input:HasFocus())
            or (m.searchBox and m.searchBox.HasFocus and m.searchBox:HasFocus())
            or (m.settingsPanel and m.settingsPanel:IsShown())
        if busy then self.idle = 0 else self.idle = (self.idle or 0) + elapsed end
        if self.idle > limit then self.idle = 0 m:Hide() end
    else
        self.idle = 0
    end
    if #self.bubbles > 0 then
        -- Maus auf einer Blase: alle halten an
        local hold = false
        for _, b in ipairs(self.bubbles) do if not b.static and Over(b) then hold = true end end
        if not hold then
            local step = R.RiseSpeed() * math.min(elapsed, .1)
            for i = #self.bubbles, 1, -1 do
                local b = self.bubbles[i]
                if b and not b.static then
                    b.rise = (b.rise or 0) + step
                    if R.RiseAlpha(b.rise, b:GetHeight()) <= 0 then self:DropBubble(b) end
                end
            end
            self:LayoutBubbles()
        end
    end
    if self.docked then
        local m = M()
        local busy = (m.input and m.input.HasFocus and m.input:HasFocus()) or Over(self.quick) or Over(m.picker) or Over(chat.ItemList and chat.ItemList.frame)
        if busy then self.quickLeft = nil
        else
            self.quickLeft = self.quickLeft or now
            if now - self.quickLeft > self.INPUT_CLOSE then self:CloseInput() end
        end
    end
    self.tickWait = (self.tickWait or 0) + elapsed
    if self.tickWait >= 1 then self.tickWait = 0 self:Update() end
end

-- Schalter an/aus (Einstellungen, Einloggen)
function R:Apply()
    if R.Active() then
        if not UI.current then UI.current = R.ActiveView() end
        self:Build()
        if chat.Launcher and chat.Launcher.Update then chat.Launcher:Update() end
        -- bei offenem Fenster bleibt die Leiste weg, bis es zu ist
        local f = M().frame
        if f and f:IsShown() then self.frame:Hide() else self.frame:Show() end
        self:Update()
    else
        if self.anim then self:EndAnim() end
        if self.docked then self:CloseInput() end
        if self.frame then self.frame:Hide() end
        self:ClearBubbles()
        if chat.Launcher and chat.Launcher.Update then chat.Launcher:Update() end
    end
end
