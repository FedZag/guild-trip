-- Guild Trip Navi: der Weg aus dem Wegenetz als eigene goldene Punkte auf Minimap und Weltkarte,
-- die nächste Abbiegung als Ring. Optional zusätzlich als WoW-Wegpunkt (Markierung in der 3D-Welt –
-- Bodenspuren kann ein Addon nicht zeichnen). Grafiken: scripts/build_route_dots.py.
local _, nav = ...
local ONE = _G.ProjectONE
local D = {mapPool = {}, miniPool = {}, miniEvery = .05, mapEvery = .5}
nav.RouteDots = D
local TEX = "Interface\\AddOns\\ONE_Nav\\Textures\\"
local sqrt = math.sqrt

local function FeatureOn(id) return not (ONE.FeatureOn and not ONE:FeatureOn(id)) end

-- Laufende Route des Pfeils (nur wenn er gerade dem Wegenetz folgt)
function D:Route()
    local A = nav.Arrow
    local s = A and A.active and A.state
    if s and s.advice and s.advice.routed and A.route and A.route.points then return A.route end
end

-- Punkte entlang des restlichen Wegs: ab Spieler (px, py) alle step Yards, höchstens max Punkte,
-- höchstens bis range Yards Weg. Der nächste Wegpunkt (route.index) wird als turn markiert.
function D.Sample(route, px, py, step, max, range)
    local pts, out = route.points, {}
    local i = route.index or 2
    local ax, ay = px, py
    local carry, walked = step, 0
    while i <= #pts and #out < max do
        local b = pts[i]
        local dx, dy = b.x - ax, b.y - ay
        local len = sqrt(dx * dx + dy * dy)
        local pos = carry
        while pos < len and #out < max do
            out[#out + 1] = {x = ax + dx * pos / len, y = ay + dy * pos / len}
            pos = pos + step
        end
        carry = pos - len
        walked = walked + len
        if i == route.index and #out < max then out[#out + 1] = {x = b.x, y = b.y, turn = true} carry = step end
        if range and walked > range then break end
        ax, ay = b.x, b.y
        i = i + 1
    end
    return out
end

local function NewDot(parent, size)
    local dot = CreateFrame("Frame", nil, parent)
    dot:SetSize(size, size)
    dot.icon = dot:CreateTexture(nil, "OVERLAY")
    dot.icon:SetAllPoints()
    return dot
end
local function Style(dot, p, size)
    dot.icon:SetTexture(TEX .. (p.turn and "RouteTurn.tga" or "RouteDot.tga"))
    dot:SetSize(p.turn and size * 1.6 or size, p.turn and size * 1.6 or size)
end

-- ===== Minimap =====
function D:RefreshMinimap()
    local mm = _G.Minimap
    local route = self:Route()
    local n = 0
    if mm and route and FeatureOn("nav.routeDots") then
        local Travel, P = nav.Travel, nav.QuestPins
        local pc, px, py = Travel.PlayerWorld()
        if pc and pc == route.continent and P then
            local rotate = type(GetCVar) == "function" and GetCVar("rotateMinimap") == "1"
            local facing = rotate and Travel.Facing() or nil
            local size, diameter = mm:GetWidth(), P:Diameter()
            for _, p in ipairs(self.Sample(route, px, py, diameter / 28, 60, diameter)) do
                local sx, sy = P.MinimapOffset({pc, px, py}, {pc, p.x, p.y}, diameter, size, facing)
                if sx and sx * sx + sy * sy >= P.clearRadius * P.clearRadius then
                    n = n + 1
                    local dot = self.miniPool[n] or NewDot(mm, 7)
                    self.miniPool[n] = dot
                    dot:SetFrameLevel((mm.GetFrameLevel and mm:GetFrameLevel() or 1) + 4)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", mm, "CENTER", sx, sy)
                    Style(dot, p, 7)
                    dot:Show()
                end
            end
        end
    end
    for i = n + 1, #self.miniPool do self.miniPool[i]:Hide() end
end

-- ===== Weltkarte =====
local function Vector(x, y)
    if type(CreateVector2D) == "function" then
        local ok, v = pcall(CreateVector2D, x, y)
        if ok and v then return v end
    end
    return {x = x, y = y}
end
-- Weltpunkt -> Anteil auf der angezeigten Karte (oder nil)
function D.MapPos(continent, x, y, viewed)
    if not (C_Map and type(C_Map.GetMapPosFromWorldPos) == "function") then return end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, continent, Vector(x, y), viewed)
    if not ok or type(pos) ~= "table" then return end
    local mx, my = pos.x, pos.y
    if mx == nil and type(pos.GetXY) == "function" then
        local good, a, b = pcall(pos.GetXY, pos)
        if good then mx, my = a, b end
    end
    if type(mx) == "number" and type(my) == "number" and mx >= 0 and my >= 0 and mx <= 1 and my <= 1 then return mx, my end
end

function D:RefreshMap()
    local map = _G.WorldMapFrame
    local route = self:Route()
    local n = 0
    if map and map:IsShown() and route and FeatureOn("nav.routeDots") then
        local canvas = (map.GetCanvas and map:GetCanvas()) or (map.ScrollContainer and map.ScrollContainer.Child)
        local viewed = map.GetMapID and map:GetMapID() or map.mapID
        local w, h = canvas and canvas:GetWidth(), canvas and canvas:GetHeight()
        local pc, px, py = nav.Travel.PlayerWorld()
        if canvas and viewed and w and h and w > 0 and pc == route.continent then
            local step = math.max(15, (route.length or 0) / 140)
            for _, p in ipairs(self.Sample(route, px, py, step, 180)) do
                local mx, my = self.MapPos(route.continent, p.x, p.y, viewed)
                if mx then
                    n = n + 1
                    local dot = self.mapPool[n] or NewDot(canvas, 9)
                    self.mapPool[n] = dot
                    if dot:GetParent() ~= canvas then dot:SetParent(canvas) end
                    dot:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 38)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", canvas, "TOPLEFT", mx * w, -my * h)
                    Style(dot, p, 9)
                    dot:Show()
                end
            end
        end
    end
    for i = n + 1, #self.mapPool do self.mapPool[i]:Hide() end
end

-- ===== Nächste Abbiegung als WoW-Wegpunkt (Markierung in der Welt) =====
-- Nur, wenn kein eigener Wegpunkt des Spielers gesetzt ist; unserer wird beim Ende wieder entfernt.
function D:UpdateWaypoint()
    local route = self:Route()
    local want = route and FeatureOn("nav.routeWaypoint") and route.points[route.index or 2]
    if not (C_Map and type(C_Map.SetUserWaypoint) == "function" and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
    if not want then
        if self.ours then
            if type(C_Map.ClearUserWaypoint) == "function" then pcall(C_Map.ClearUserWaypoint) end
            self.ours = nil
        end
        return
    end
    if self.ours and self.ours.x == want.x and self.ours.y == want.y then return end
    -- eigener Wegpunkt des Spielers? Dann nichts überschreiben
    if not self.ours and type(C_Map.HasUserWaypoint) == "function" then
        local ok, has = pcall(C_Map.HasUserWaypoint)
        if ok and has then return end
    end
    local here = nav.Travel.PlayerMapPosition()
    local mx, my = here and self.MapPos(route.continent, want.x, want.y, here)
    if not mx then return end
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, here, mx, my)
    if not (ok and point) then return end
    if pcall(C_Map.SetUserWaypoint, point) then
        self.ours = {x = want.x, y = want.y}
        if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
    end
end

function D:Initialize()
    if not CreateFrame then return false end
    local frame = CreateFrame("Frame")
    local mini, mapT, wp = 0, 0, 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        elapsed = elapsed or 0
        mini, mapT, wp = mini + elapsed, mapT + elapsed, wp + elapsed
        local active = self:Route() ~= nil
        if not active and not self.shown then return end
        if mini >= self.miniEvery then mini = 0 self:RefreshMinimap() end
        if mapT >= self.mapEvery then mapT = 0 self:RefreshMap() end
        if wp >= 1 then wp = 0 self:UpdateWaypoint() end
        self.shown = active
    end)
    local wm = _G.WorldMapFrame
    if wm and wm.HookScript then wm:HookScript("OnShow", function() D:RefreshMap() end) end
    if wm and type(hooksecurefunc) == "function" and type(wm.OnMapChanged) == "function" then
        hooksecurefunc(wm, "OnMapChanged", function() D:RefreshMap() end)
    end
    self.frame = frame
    return true
end
