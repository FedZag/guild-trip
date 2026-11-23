-- Guild Trip: Koordinaten (Gesamtpruefung 23.11.2026, Idee wie TomTom; stand auch auf der alten Roadmap).
-- * Weltkarte: unten "Du: 45.2, 60.1  ·  Maus: 30.0, 22.4" (Standard an)
-- * Minimap: kleine Zahl unten in der Minimap (Standard aus)
-- Nur eigene Frames (an WorldMapFrame/Minimap gehaengt), keine Blizzard-Lua-Aufrufe ausser GetMapID
-- (wie Pins/RouteDots). Mauslage selbst gerechnet: GetCursorPosition gegen die Kartenflaeche.
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local C = {INTERVAL = .1}
nav.Coords = C

if ONE.RegisterFeature then
    ONE:RegisterFeature("nav.coordsMap", {module = "nav", section = "Koordinaten", order = 50,
        label = "Koordinaten auf der Weltkarte",
        tooltip = "Unten auf der Weltkarte: deine Position und die Stelle unter der Maus (z. B. für /trip way 45.2 60.1)."})
    ONE:RegisterFeature("nav.coordsMinimap", {module = "nav", section = "Koordinaten", order = 51,
        label = "Koordinaten an der Minimap",
        tooltip = "Deine Position klein unten in der Minimap.",
        get = function() return ONE.db and ONE.db.coordsMinimap == true end,
        set = function(on) if ONE.db then ONE.db.coordsMinimap = on and true or false end C:Refresh() end})
end

local function On(id) return not ONE.FeatureOn or ONE:FeatureOn(id) end

-- "45.2, 60.1" aus 0..1; nil ausserhalb
function C.Format(x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x <= 0 or y <= 0 or x >= 1 or y >= 1 then return nil end
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

function C.Player(mapID)
    local CM = rawget(_G, "C_Map")
    if not (CM and CM.GetBestMapForUnit and CM.GetPlayerMapPosition) then return nil end
    local okM, best = pcall(CM.GetBestMapForUnit, "player")
    mapID = mapID or (okM and best)
    if not mapID then return nil end
    local ok, pos = pcall(CM.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    return x, y
end

-- Mauslage auf der Kartenflaeche (0..1), nil ausserhalb
function C.Cursor(canvas)
    if not (canvas and canvas.GetLeft and canvas.GetTop and canvas.GetWidth and canvas.GetHeight) then return nil end
    local gc = rawget(_G, "GetCursorPosition")
    if type(gc) ~= "function" then return nil end
    local cx, cy = gc()
    local scale = canvas.GetEffectiveScale and canvas:GetEffectiveScale() or 1
    local left, top, w, h = canvas:GetLeft(), canvas:GetTop(), canvas:GetWidth(), canvas:GetHeight()
    if not (cx and left and top and w and h) or w <= 0 or h <= 0 or scale <= 0 then return nil end
    local x, y = (cx / scale - left) / w, (top - cy / scale) / h
    if x <= 0 or x >= 1 or y <= 0 or y >= 1 then return nil end
    return x, y
end

function C.MapText(playerXY, cursorXY)
    local parts = {}
    if playerXY then parts[#parts + 1] = T("Du: %s", playerXY) end
    if cursorXY then parts[#parts + 1] = T("Maus: %s", cursorXY) end
    return table.concat(parts, "  ·  ")
end

function C:BuildMap()
    local wm = rawget(_G, "WorldMapFrame")
    if self.mapFrame or not wm then return end
    local holder = wm.ScrollContainer or wm
    local f = CreateFrame("Frame", nil, wm)
    f:SetSize(320, 20)
    f:SetPoint("BOTTOM", holder, "BOTTOM", 0, 4)
    if f.SetFrameStrata then f:SetFrameStrata("HIGH") end
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, .55)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.text = text
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < C.INTERVAL then return end
        acc = 0
        C:UpdateMap()
    end)
    self.mapFrame = f
end

function C:UpdateMap()
    local f, wm = self.mapFrame, rawget(_G, "WorldMapFrame")
    if not (f and wm) then return end
    -- aus: nur unsichtbar (der Rahmen laeuft nur bei offener Karte, so wirkt Wiedereinschalten sofort)
    if not On("nav.coordsMap") then f:SetAlpha(0) return end
    local mapID = wm.GetMapID and wm:GetMapID() or wm.mapID
    local canvas = wm.ScrollContainer and wm.ScrollContainer.Child
    local text = C.MapText(C.Format(C.Player(mapID)), C.Format(C.Cursor(canvas)))
    f.text:SetText(text)
    if text == "" then f:SetAlpha(0) else f:SetAlpha(1) f:SetWidth((f.text.GetStringWidth and f.text:GetStringWidth() or 200) + 20) end
end

function C:BuildMinimap()
    local mm = rawget(_G, "Minimap")
    if self.miniFrame or not mm then return end
    local f = CreateFrame("Frame", nil, mm)
    f:SetSize(70, 14)
    f:SetPoint("BOTTOM", mm, "BOTTOM", 0, 8)
    if f.SetFrameLevel and mm.GetFrameLevel then f:SetFrameLevel((mm:GetFrameLevel() or 1) + 5) end
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", f, "CENTER", 0, 0)
    if text.SetShadowOffset then text:SetShadowOffset(1, -1) end
    f.text = text
    self.miniFrame = f
end

function C:UpdateMinimap()
    local f = self.miniFrame
    if not f then return end
    if not On("nav.coordsMinimap") then f:Hide() return end
    local xy = C.Format(C.Player())
    if xy then f.text:SetText(xy) f:Show() else f:Hide() end
end

function C:Refresh()
    self:UpdateMinimap()
end

function C:Initialize()
    if self.started then return end
    self.started = true
    pcall(self.BuildMap, self)
    pcall(self.BuildMinimap, self)
    self:Refresh()
    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(.5, function() if On("nav.coordsMinimap") then C:UpdateMinimap() end end)
    end
end
