-- Guild Trip: Quest-Symbole auf Weltkarte und Minimap (0.6.5, Etappe 2 von "Quests wie Questie").
-- Orte wie auf der Quest-Seite: eigene Orte aus C_QuestLog.GetQuestsOnMap (nur mitten in
-- der Zone, Randpunkte zeigen nur die Richtung), sonst der Ort eines Gildenmitglieds.
-- Goldring mit Punkt = Zielgebiet, Goldring mit Haken = fertig, zurueck zum Questgeber.
-- Goldring mit "!" = Questgeber mit neuer Quest fuer mich (gesammelt, QuestGivers.lua).
-- Klick auf ein Symbol startet das Navi. Alles abschaltbar (Optionen › Navi).
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local P = {mapPool = {}, miniPool = {}}
nav.QuestPins = P
local TEX = "Interface\\AddOns\\ONE_Nav\\Textures\\"

-- Minimap-Durchmesser in Yards je Zoomstufe (draussen / drinnen)
P.OUTDOOR = {466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3}
P.INDOOR = {300, 240, 180, 120, 80, 50}
-- Abstand zur Minimap-Mitte (Pixel), in dem keine Symbole gezeichnet werden (Spielerpfeil)
P.clearRadius = 11

function P:Settings()
    if not ONE.db then return {} end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    local s = type(ONE.db.nav.questPins) == "table" and ONE.db.nav.questPins or {}
    ONE.db.nav.questPins = s
    if s.map == nil then s.map = true end
    if s.minimap == nil then s.minimap = true end
    if s.givers == nil then s.givers = true end
    return s
end

-- Questgeber anzeigen? Mit Questie nicht (Questie zeigt eigene "!")
function P:ShowGivers()
    local G = nav.QuestGivers
    -- ein Schalter fuer Sammeln und Zeigen: Funktion "nav.givers" (frueher doppelt)
    local on = not ONE.FeatureOn or ONE:FeatureOn("nav.givers")
    return on and G and not G:QuestieLoaded() or false
end

-- Alle Symbole: {q, mapID, x, y, from} bzw. Questgeber {giver, mapID, x, y}
-- viewed = gerade angezeigte Weltkarte (Questgeber aus der Datenbank nur fuer diese + die eigene Karte)
function P:Points(viewed)
    local Q, out = nav.Quests, {}
    if not Q then return out end
    local locs = Q:Locations()
    local here = nav.Travel and nav.Travel.PlayerMapPosition and nav.Travel.PlayerMapPosition()
    for _, q in ipairs(Q:Log()) do
        local loc = locs[q.id]
        if not loc or loc.edge then loc = nav.QuestShare and nav.QuestShare:Location(q.id) or loc end
        if (not loc or loc.edge) and nav.QuestDB and nav.QuestDB:Available() then loc = nav.QuestDB:Location(q, here) or loc end
        if loc then out[#out + 1] = {q = q, mapID = loc.mapID, x = loc.x, y = loc.y, from = loc.from} end
    end
    if self:ShowGivers() then
        local maps = {}
        if here then maps[#maps + 1] = here end
        if viewed and viewed ~= here then maps[#maps + 1] = viewed end
        for _, g in ipairs(nav.QuestGivers:Available(maps)) do
            out[#out + 1] = {giver = g, mapID = g.mapID, x = g.x, y = g.y}
        end
    end
    return out
end

-- Position auf der angezeigten Karte (gleiche Karte oder uebergeordnete, z. B. Kontinent)
function P.OnMap(mapID, x, y, viewed)
    if mapID == viewed then return x, y end
    if not (C_Map and C_Map.GetMapInfo and C_Map.GetMapRectOnMap) then return end
    local id, ancestor = mapID, false
    for _ = 1, 8 do
        local ok, info = pcall(C_Map.GetMapInfo, id)
        if not ok or type(info) ~= "table" or not info.parentMapID or info.parentMapID == 0 then break end
        id = info.parentMapID
        if id == viewed then ancestor = true break end
    end
    if not ancestor then return end
    local ok, l, r, t, b = pcall(C_Map.GetMapRectOnMap, mapID, viewed)
    if not ok or type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" or r <= l or b <= t then return end
    return l + x * (r - l), t + y * (b - t)
end

-- Versatz auf der Minimap in Pixeln (rechts, oben) oder nil, wenn ausserhalb
-- player/target = {continent, x(Nord), y(West)} in Yards
function P.MinimapOffset(player, target, diameter, size, facing)
    if not (player and target and player[1] == target[1]) then return end
    local north, west = target[2] - player[2], target[3] - player[3]
    local scale = size / diameter
    local sx, sy = -west * scale, north * scale
    if facing then
        local c, s = math.cos(-facing), math.sin(-facing)
        sx, sy = sx * c - sy * s, sx * s + sy * c
    end
    local r = size / 2 - 6
    if sx * sx + sy * sy > r * r then return end
    return sx, sy
end

local function Tooltip(pin)
    if not GameTooltip or not pin.point then return end
    local p = pin.point
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    if p.giver then
        GameTooltip:SetText(p.giver.name ~= "" and p.giver.name or T("Questgeber"), 1, .82, 0)
        for i, q in ipairs(p.giver.quests) do
            if i > 8 then GameTooltip:AddLine(T("… und %d weitere", #p.giver.quests - 8), .7, .7, .7) break end
            GameTooltip:AddLine("!  " .. (q.title or "?") .. (q.level and (" (" .. q.level .. ")") or ""), 1, 1, 1)
        end
        if p.giver.db then GameTooltip:AddLine(T("Aus der Questdatenbank (Questie) – im Einzelfall kann es abweichen."), .6, .6, .6, true) end
        GameTooltip:AddLine(T("Klick: Navi starten"), .6, .8, 1)
        return GameTooltip:Show()
    end
    GameTooltip:SetText(p.q.title, 1, .82, 0)
    if p.q.complete then GameTooltip:AddLine(T("fertig – abgeben"), .4, 1, .4)
    else
        local progress = nav.Quests:Progress(p.q)
        if progress ~= "" then GameTooltip:AddLine(progress, 1, 1, 1, true) end
    end
    if p.from then GameTooltip:AddLine(T("Ort von %s (Gilde).", p.from), .7, .7, .7) end
    GameTooltip:AddLine(T("Klick: Navi starten"), .6, .8, 1)
    GameTooltip:Show()
end

local function NewPin(parent, size)
    local pin = CreateFrame("Frame", nil, parent)
    pin:SetSize(size, size)
    pin:EnableMouse(true)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin:SetScript("OnEnter", Tooltip)
    pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    pin:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.point then
            local navi = ONE.modules and ONE.modules.nav
            local p = self.point
            local label = p.giver and (p.giver.name ~= "" and p.giver.name or T("Questgeber")) or p.q.title
            if navi and navi.PointTo then navi:PointTo(label, p.mapID, p.x, p.y) end
        end
    end)
    return pin
end
local function Style(pin, point, mini)
    pin.point = point
    -- Minimap: Questgeber als schlichtes "!" ohne Ring (0.7.1, weniger Unruhe)
    local giverTex = mini and "QuestAvailableSmall.tga" or "QuestAvailable.tga"
    pin.icon:SetTexture(TEX .. (point.giver and giverTex or point.q.complete and "QuestDone.tga" or "QuestGoal.tga"))
    pin:SetAlpha(point.from and .65 or 1)

end

-- ===== Weltkarte =====
function P:RefreshMap()
    local map = _G.WorldMapFrame
    local function HideAll() for _, pin in ipairs(self.mapPool) do pin:Hide() end end
    if not (map and map:IsShown()) or not self:Settings().map or not ONE:IsEnabled("nav") then return HideAll() end
    local canvas = (map.GetCanvas and map:GetCanvas()) or (map.ScrollContainer and map.ScrollContainer.Child)
    local viewed = map.GetMapID and map:GetMapID() or map.mapID
    local w, h = canvas and canvas:GetWidth(), canvas and canvas:GetHeight()
    if not (canvas and viewed and w and h and w > 0 and h > 0) then return HideAll() end
    local n = 0
    for _, point in ipairs(self:Points(viewed)) do
        local x, y = P.OnMap(point.mapID, point.x, point.y, viewed)
        if x and y and x >= 0 and y >= 0 and x <= 1 and y <= 1 then
            n = n + 1
            local pin = self.mapPool[n] or NewPin(canvas, 18)
            self.mapPool[n] = pin
            if pin:GetParent() ~= canvas then pin:SetParent(canvas) end
            pin:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 40)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
            Style(pin, point)
            pin:Show()
        end
    end
    for i = n + 1, #self.mapPool do self.mapPool[i]:Hide() end
end

-- ===== Minimap =====
-- 0.7.1 (Nutzer: zu viele "!" auf der Minimap): Questgeber dort nur, wenn die Quest-Fuehrung
-- eine ihrer Quests als Naechstes annehmen laesst, hoechstens MINI_GIVERS, die naechsten zuerst.
-- Ohne Quest-Fuehrung: die naechsten MINI_GIVERS. Alle zeigen: Funktion "nav.giversMinimapAll".
P.MINI_GIVERS = 3
P.MINI_GIVER_SIZE = 12
-- Quest-IDs, die der Plan annehmen laesst (nil = keine Quest-Fuehrung aktiv)
function P.PlannedAccepts()
    local lev = ONE.ns and ONE.ns.leveling
    local plan = lev and lev.Guide and lev.Guide.plan
    if not (plan and plan.steps) or (ONE.IsEnabled and not ONE:IsEnabled("leveling")) then return nil end
    local set = {}
    for _, s in ipairs(plan.steps) do
        for _, a in ipairs(s.actions or {}) do if a.kind == "accept" and a.id then set[a.id] = true end end
    end
    return set
end
function P.GiverPlanned(giver, set)
    for _, q in ipairs(giver.quests or {}) do if q.id and set[q.id] then return true end end
    return false
end
local function Indoors()
    -- Trick wie bei vielen Addons: drinnen weicht minimapInsideZoom vom aktuellen Zoom ab
    if type(GetCVar) ~= "function" or not _G.Minimap then return false end
    local ok, inside = pcall(GetCVar, "minimapInsideZoom")
    local ok2, outside = pcall(GetCVar, "minimapZoom")
    local zoom = _G.Minimap.GetZoom and _G.Minimap:GetZoom()
    if not (ok and ok2) then return false end
    if tonumber(inside) == zoom and tonumber(outside) ~= zoom then return true end
    return false
end
function P:Diameter()
    local zoom = (_G.Minimap and _G.Minimap.GetZoom and _G.Minimap:GetZoom() or 0) + 1
    local list = Indoors() and P.INDOOR or P.OUTDOOR
    return list[zoom] or list[1]
end

function P:RefreshMinimap()
    local mm = _G.Minimap
    local function HideAll() for _, pin in ipairs(self.miniPool) do pin:Hide() end end
    if not mm or not self:Settings().minimap or not ONE:IsEnabled("nav") or not (self.points and self.points[1]) then return HideAll() end
    local Travel = nav.Travel
    local pc, px, py = Travel.PlayerWorld()
    if not pc then return HideAll() end
    local rotate = type(GetCVar) == "function" and GetCVar("rotateMinimap") == "1"
    local facing = rotate and Travel.Facing() or nil
    local size, diameter = mm:GetWidth(), self:Diameter()
    local n = 0
    local givers = {}
    local function Place(i, point, sx, sy, pinSize)
        local pin = self.miniPool[i] or NewPin(mm, pinSize)
        self.miniPool[i] = pin
        pin:SetSize(pinSize, pinSize)
        pin:SetFrameLevel((mm.GetFrameLevel and mm:GetFrameLevel() or 1) + 5)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", mm, "CENTER", sx, sy)
        Style(pin, point, true)
        pin:Show()
    end
    self.worldCache = self.worldCache or {}
    for _, point in ipairs(self.points or {}) do
        local key = point.mapID .. ":" .. point.x .. ":" .. point.y
        local world = self.worldCache[key]
        if not world then
            local c, x, y = Travel.World(point.mapID, point.x, point.y)
            world = c and {c, x, y} or false
            self.worldCache[key] = world
        end
        -- eigene if-Zeile: "world and f()" liefert nur den ersten Rueckgabewert (sy waere nil)
        local sx, sy
        if world then sx, sy = P.MinimapOffset({pc, px, py}, world, diameter, size, facing) end
        -- Nie auf dem Spielerpfeil: wer schon am Ziel steht, braucht kein Symbol darueber
        -- (sah als "Punkt ueber dem Pfeil" unschoen aus – der WoW-Pfeil bleibt frei)
        if sx and sx * sx + sy * sy < P.clearRadius * P.clearRadius then sx = nil end
        if sx then
            if point.giver then
                givers[#givers + 1] = {point = point, sx = sx, sy = sy, d = sx * sx + sy * sy}
            else
                n = n + 1
                Place(n, point, sx, sy, 14)
            end
        end
    end
    -- Questgeber: nur aus dem Plan (oder alle, wenn eingeschaltet), die naechsten zuerst
    local all = ONE.FeatureOn and ONE:FeatureOn("nav.giversMinimapAll")
    local planned = not all and P.PlannedAccepts() or nil
    local shown = {}
    for _, g in ipairs(givers) do
        if all or not planned or P.GiverPlanned(g.point.giver, planned) then shown[#shown + 1] = g end
    end
    table.sort(shown, function(a, b) return a.d < b.d end)
    for i, g in ipairs(shown) do
        if not all and i > P.MINI_GIVERS then break end
        n = n + 1
        Place(n, g.point, g.sx, g.sy, P.MINI_GIVER_SIZE)
    end
    for i = n + 1, #self.miniPool do self.miniPool[i]:Hide() end
end

-- Questorte neu lesen (nach Quest-Aenderungen), Minimap laeuft im Takt nach
function P:Refresh()
    self.points = self:Points()
    self:RefreshMap()
    self:RefreshMinimap()
end

function P:Initialize()
    -- Schalter: Funktionen "nav.questMap", "nav.questMinimap", "nav.givers" (Optionen › Navi)
    if not CreateFrame then return false end
    local frame = CreateFrame("Frame")
    for _, e in ipairs({"QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD"}) do
        pcall(frame.RegisterEvent, frame, e)
    end
    -- Quest-Ereignisse kommen oft in Schauern: hoechstens alle 2 Sekunden neu lesen
    local pending = false
    frame:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        local function Run() pending = false nav.Quests.dirty = true P:Refresh() end
        if C_Timer and C_Timer.After then C_Timer.After(3.5, Run) else Run() end
    end)
    local wm = _G.WorldMapFrame
    if wm and wm.HookScript then wm:HookScript("OnShow", function() P:RefreshMap() end) end
    if wm and type(hooksecurefunc) == "function" and type(wm.OnMapChanged) == "function" then
        hooksecurefunc(wm, "OnMapChanged", function() P:RefreshMap() end)
    end
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        local ticks = 0
        C_Timer.NewTicker(.2, function()
            ticks = ticks + 1
            -- alle 10 Sekunden auch neue Orte aus der Gilde uebernehmen
            if ticks % 50 == 0 then P:Refresh() else P:RefreshMinimap() end
        end)
    end
    self.frame = frame
    return true
end
