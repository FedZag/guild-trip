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

-- Darstellung des Wegs: "dots" (goldene Punkte, Standard) oder "feet" (Fussspuren, Nutzer-Wunsch 17.11.2026:
-- Abdruecke links/rechts im Wechsel, zur Laufrichtung gedreht, auf der Minimap Schritt fuer Schritt
-- aufleuchtend; Weltkarte ruhig). Gespeichert in ONE.db.nav.routeStyle.
function D:Style()
    local s = ONE.db and type(ONE.db.nav) == "table" and ONE.db.nav.routeStyle
    return s == "feet" and "feet" or "dots"
end
function D:SetStyle(v)
    if not ONE.db then return end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    ONE.db.nav.routeStyle = v == "feet" and "feet" or "dots"
    self:RefreshMinimap()
    self:RefreshMap()
end
D.stepsPerSecond, D.trail = 5, 6
-- Helligkeit des k-ten Abdrucks (1 = am Spieler): eine Welle laeuft vom Spieler zum Ziel,
-- frisch "gesetzte" Abdruecke leuchten, aeltere verblassen auf einen ruhigen Grundwert
function D.FootAlpha(k, count, now)
    local span = count + D.trail
    local head = math.floor((now or 0) * D.stepsPerSecond) % math.max(1, span) + 1
    local behind = head - k
    if behind >= 0 and behind < D.trail then return 1 - behind * (.6 / D.trail) end
    return .3
end
-- Drehwinkel fuer SetRotation (gegen den Uhrzeigersinn, 0 = Zehen nach oben) aus einer Richtung (y nach oben)
function D.Angle(dx, dy)
    if dx == 0 and dy == 0 then return 0 end
    return math.atan2(-dx, dy)
end

local function NewDot(parent, size)
    local dot = CreateFrame("Frame", nil, parent)
    dot:SetSize(size, size)
    dot.icon = dot:CreateTexture(nil, "OVERLAY")
    dot.icon:SetAllPoints()
    return dot
end
-- Kurven ohne eigenes Zeichen: Fussspur bzw. normaler Punkt, keine gelben Kreise (Nutzer 23.11.2026)
local function Style(dot, p, size, foot)
    if foot then
        dot.icon:SetTexture(TEX .. (foot.left and "RouteFootL.tga" or "RouteFootR.tga"))
        dot:SetSize(size, size)
        if dot.icon.SetRotation then dot.icon:SetRotation(foot.angle or 0) end
        dot:SetAlpha(foot.alpha or 1)
        return
    end
    -- Kurven nicht extra hervorheben (Nutzer 23.11.2026: "die Kurven muessen doch nicht angezeigt werden")
    dot.icon:SetTexture(TEX .. "RouteDot.tga")
    if dot.icon.SetRotation then dot.icon:SetRotation(0) end
    dot:SetAlpha(1)
    dot:SetSize(size, size)
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
            local feet = self:Style() == "feet"
            local samples = self.Sample(route, px, py, diameter / (feet and 22 or 28), 60, diameter)
            -- Fussspuren: Richtung je Abdruck aus dem vorigen Punkt (am Anfang: Spieler), Wechsel links/rechts
            local placed, lx, ly, count = {}, 0, 0, 0
            for _, p in ipairs(samples) do
                local sx, sy = P.MinimapOffset({pc, px, py}, {pc, p.x, p.y}, diameter, size, facing)
                if sx then
                    local e = {p = p, sx = sx, sy = sy}
                    if feet then
                        count = count + 1
                        local dx, dy = sx - lx, sy - ly
                        local len = math.sqrt(dx * dx + dy * dy)
                        local left = count % 2 == 1
                        if len > 0 then
                            local side = left and -1.6 or 1.6
                            e.sx, e.sy = sx + dy / len * side, sy - dx / len * side
                        end
                        e.foot = {left = left, angle = self.Angle(dx, dy), k = count}
                    end
                    lx, ly = sx, sy
                    placed[#placed + 1] = e
                end
            end
            local now = type(GetTime) == "function" and GetTime() or 0
            for _, e in ipairs(placed) do
                local sx, sy = e.sx, e.sy
                if sx * sx + sy * sy >= P.clearRadius * P.clearRadius then
                    n = n + 1
                    local dot = self.miniPool[n] or NewDot(mm, 7)
                    self.miniPool[n] = dot
                    dot:SetFrameLevel((mm.GetFrameLevel and mm:GetFrameLevel() or 1) + 4)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", mm, "CENTER", sx, sy)
                    if e.foot then e.foot.alpha = self.FootAlpha(e.foot.k, count, now) end
                    Style(dot, e.p, e.foot and 9 or 7, e.foot)
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
            local feet = self:Style() == "feet"
            local lastX, lastY, count = nil, nil, 0
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
                    -- Weltkarte: Fussspuren ruhig (ohne Aufleuchten), zur Laufrichtung gedreht
                    local foot
                    if feet then
                        count = count + 1
                        local dx, dy = lastX and (mx - lastX) * w or 0, lastY and -(my - lastY) * h or 1
                        foot = {left = count % 2 == 1, angle = self.Angle(dx, dy), alpha = .9}
                    end
                    lastX, lastY = mx, my
                    Style(dot, p, foot and 11 or 9, foot)
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
    -- nicht 'here and MapPos(...)': 'and' liefert nur den ersten Wert (my fehlte)
    local mx, my
    if here then mx, my = self.MapPos(route.continent, want.x, want.y, here) end
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
