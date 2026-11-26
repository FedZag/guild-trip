-- Guild Trip Navi: eigene Wegpunkte und Leichenlauf (17.11.2026, Ideen u. a. aus Polestar, eigener Code).
-- * Umschalt+Klick auf die Weltkarte: Navi genau dorthin
-- * /trip way 45.2 60.1 [Gebiet]  (und /way, solange kein anderes Addon den Befehl hat, z. B. TomTom)
-- * Nach dem Tod (als Geist): Pfeil zur Leiche, danach weiter zum vorherigen Ziel
-- * Laeuft Polestar (eigener Navi-Pfeil), startet Guild Trip seinen Pfeil nie von selbst – nur auf Klick.
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Waypoints = {}
nav.Waypoints = Waypoints

-- Andere Navi-Addons mit eigenem Pfeil (dann keine automatischen Starts)
Waypoints.others = {{"Polestar", "Polestar"}, {"TomTom", "TomTom"}}
function Waypoints.OtherNavAddon()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
    if type(loaded) ~= "function" then return nil end
    for _, a in ipairs(Waypoints.others) do
        local ok, on = pcall(loaded, a[1])
        if ok and on then return a[2] end
    end
end
-- Darf Guild Trip den Pfeil von selbst starten (Leiche, Ausflugsbeginn)?
function Waypoints.AutoAllowed()
    return Waypoints.OtherNavAddon() ~= "Polestar"
end

-- "45.2 60.1", "45,2 60,1", "45.2, 60.1 Brachland" -> x, y (0..1), Gebietsname
function Waypoints.Parse(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local zoneFirst, a, b = text:match("^(.-)%s*(%d+[%.,]?%d*)[%s,;]+(%d+[%.,]?%d*)$")
    local zone = zoneFirst
    if not a then
        a, b, zone = text:match("^(%d+[%.,]?%d*)[%s,;]+(%d+[%.,]?%d*)%s*(.*)$")
    end
    if not a then return nil end
    local x, y = tonumber((a:gsub(",", "."))), tonumber((b:gsub(",", ".")))
    if not (x and y) or x < 0 or y < 0 or x > 100 or y > 100 then return nil end
    zone = zone and zone:gsub("^%s+", ""):gsub("%s+$", "") or ""
    return x / 100, y / 100, zone ~= "" and zone or nil
end

-- Gebiet nach Namen (Teilwort reicht) – zuerst auf dem eigenen Kontinent, dann ueberall
function Waypoints.FindZone(name)
    if not (C_Map and C_Map.GetMapInfo) then return nil end
    local want = name:lower()
    local best
    local function Look(parent)
        if not C_Map.GetMapChildrenInfo then return end
        local ok, list = pcall(C_Map.GetMapChildrenInfo, parent, nil, true)
        if not ok or type(list) ~= "table" then return end
        for _, info in ipairs(list) do
            local n = type(info.name) == "string" and info.name:lower() or ""
            if n == want then best = info.mapID return true end
            if not best and n:find(want, 1, true) then best = info.mapID end
        end
    end
    local here = nav.Travel.PlayerMapPosition and nav.Travel.PlayerMapPosition()
    local info = here and C_Map.GetMapInfo(here)
    local continent = info and info.parentMapID
    if continent and Look(continent) then return best end
    if not best then Look(947) Look(1414) Look(1415) end -- Azeroth, Kalimdor, Oestliche Koenigreiche
    return best
end

function Waypoints:Way(text)
    local x, y, zone = self.Parse(text)
    if not x then
        ONE:Print(T("Wegpunkt: /trip way 45.2 60.1 – oder mit Gebiet: /trip way Brachland 45.2 60.1"))
        return false
    end
    local mapID
    if zone then
        mapID = self.FindZone(zone)
        if not mapID then ONE:Print(T("Gebiet „%s“ nicht gefunden.", zone)) return false end
    else
        mapID = nav.Travel.PlayerMapPosition and nav.Travel.PlayerMapPosition()
        if not mapID then ONE:Print(T("Deine Position ist hier nicht verfügbar (Instanz?)")) return false end
    end
    local label = string.format("%s %.1f, %.1f", zone or T("Wegpunkt"), x * 100, y * 100)
    return nav.Arrow:StartPoint(label, mapID, x, y)
end

-- Umschalt+Klick auf die Weltkarte
function Waypoints:HookMap()
    if self.mapHooked then return end
    local map = rawget(_G, "WorldMapFrame")
    local canvas = map and map.ScrollContainer
    if not (canvas and canvas.HookScript and map.GetMapID) then return end
    self.mapHooked = true
    canvas:HookScript("OnMouseUp", function(container, button)
        if button ~= "LeftButton" or not (IsShiftKeyDown and IsShiftKeyDown()) then return end
        if not ONE:IsEnabled("nav") then return end
        local x, y
        if container.GetNormalizedCursorPosition then x, y = container:GetNormalizedCursorPosition() end
        local mapID = map:GetMapID()
        if not (mapID and x and y) or x < 0 or y < 0 or x > 1 or y > 1 then return end
        -- tippst du gerade im Guild-Trip-Chat: Kartenmarkierung + Link ins Feld statt Navi (ChatLinks.lua)
        if nav.ChatLinks and nav.ChatLinks.MapClickToChat(mapID, x, y) then return end
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local label = string.format("%s %.1f, %.1f", info and info.name or T("Kartenpunkt"), x * 100, y * 100)
        nav.Arrow:StartPoint(label, mapID, x, y)
    end)
end

-- ===== Leichenlauf =====
function Waypoints:OnDeath()
    local mapID, x, y = nav.Travel.PlayerMapPosition()
    self.corpse = mapID and {mapID = mapID, x = x, y = y} or nil
end
function Waypoints:CorpsePosition()
    local c = self.corpse
    if c and C_DeathInfo and C_DeathInfo.GetCorpseMapPosition then
        local ok, pos = pcall(C_DeathInfo.GetCorpseMapPosition, c.mapID)
        if ok and type(pos) == "table" then
            local px, py = pos.x, pos.y
            if px == nil and pos.GetXY then px, py = pos:GetXY() end
            if type(px) == "number" and type(py) == "number" and (px > 0 or py > 0) then return c.mapID, px, py end
        end
    end
    if c then return c.mapID, c.x, c.y end
    -- Tod nicht mitbekommen (z. B. /reload als Geist): Leiche auf der aktuellen Karte erfragen
    if C_DeathInfo and C_DeathInfo.GetCorpseMapPosition then
        local mapID = nav.Travel.PlayerMapPosition()
        if mapID then
            local ok, pos = pcall(C_DeathInfo.GetCorpseMapPosition, mapID)
            if ok and type(pos) == "table" then
                local px, py = pos.x, pos.y
                if px == nil and pos.GetXY then px, py = pos:GetXY() end
                if type(px) == "number" and type(py) == "number" and (px > 0 or py > 0) then return mapID, px, py end
            end
        end
    end
end
-- Geist? Beim Freilassen meldet das Spiel den Geist-Zustand manchmal erst kurz nach PLAYER_ALIVE
-- (Spieltest 19.11.2026: Pfeil zeigte als Geist weiter zur Quest) – deshalb mehrfach nachsehen.
function Waypoints.IsGhost()
    return type(UnitIsGhost) == "function" and UnitIsGhost("player") and true or false
end
function Waypoints:CheckGhost()
    if not self.IsGhost() then return end
    local A = nav.Arrow
    if self.ghostStarted or (A.active and A.probe and A.probe.corpse) then return end
    self:OnGhost()
end
function Waypoints:OnGhost()
    if not (ONE:IsEnabled("nav") and (not ONE.FeatureOn or ONE:FeatureOn("nav.corpse"))) then return end
    if not self.AutoAllowed() then return end
    -- Shortest Path Forever fuehrt Geister selbst zur Leiche (rote Route) – nicht dazwischenfunken
    if nav.Arrow.SPF and nav.Arrow.SPF() then return end
    local mapID, x, y = self:CorpsePosition()
    if not mapID then return end
    nav.Arrow:StartPoint(T("Deine Leiche"), mapID, x, y, {corpse = true, quiet = true})
    self.ghostStarted = true
    ONE:Print(T("Navi zu deiner Leiche. Danach geht es weiter zum vorherigen Ziel."))
end
function Waypoints:OnAlive()
    self.corpse, self.ghostStarted = nil, nil
    local A = nav.Arrow
    if A.active and A.probe and A.probe.corpse then
        if A.resume then A:Resume() else A:Stop() end
    end
end

-- ===== Klick auf "?" / "…" in der Zielverfolgung -> Navi zu dieser Quest =====
-- Das Spiel macht die Quest dabei zur "verfolgten" (SUPER_TRACKING_CHANGED). Nur wenn die Maus dabei
-- auf so einem Knopf liegt – automatische Wechsel (z. B. beim Annehmen) starten kein Navi.
function Waypoints:TrackerNavi(questID)
    if type(questID) ~= "number" or questID <= 0 or not nav.Quests then return false end
    if ONE.FeatureOn and not ONE:FeatureOn("nav.trackerNavi") then return false end
    local now = type(GetTime) == "function" and GetTime() or 0
    if self.lastTracked == questID and now - (self.lastTrackedAt or -10) < 1 then return false end
    self.lastTracked, self.lastTrackedAt = questID, now
    for _, q in ipairs(nav.Quests:Log()) do
        if q.id == questID then return nav.Quests:Navi(q) end
    end
    return false
end
function Waypoints.FocusIsQuestButton()
    local f
    if type(GetMouseFoci) == "function" then
        local ok, list = pcall(GetMouseFoci)
        f = ok and type(list) == "table" and list[1] or nil
    elseif type(GetMouseFocus) == "function" then
        local ok, one = pcall(GetMouseFocus)
        f = ok and one or nil
    end
    if type(f) ~= "table" then return false end
    if f.questID then return true end
    local name = f.GetName and f:GetName() or ""
    return type(name) == "string" and name:find("POI") ~= nil
end
function Waypoints:HookTracker()
    if self.trackerHooked then return end
    self.trackerHooked = true
    if type(hooksecurefunc) == "function" and type(rawget(_G, "QuestPOIButton_OnClick")) == "function" then
        hooksecurefunc("QuestPOIButton_OnClick", function(btn) if type(btn) == "table" then Waypoints:TrackerNavi(btn.questID) end end)
    end
end

function Waypoints:Initialize()
    local f = CreateFrame("Frame")
    for _, e in ipairs({"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "ADDON_LOADED", "SUPER_TRACKING_CHANGED",
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA"}) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_DEAD" then
            Waypoints:OnDeath()
        elseif event == "PLAYER_ALIVE" then
            -- PLAYER_ALIVE kommt beim Freilassen des Geistes UND beim Wiederbeleben vor Ort
            if Waypoints.IsGhost() then Waypoints:CheckGhost() else Waypoints:OnAlive() end
            -- falls der Geist-Zustand erst gleich gemeldet wird
            if C_Timer and C_Timer.After then
                C_Timer.After(1, function() Waypoints:CheckGhost() end)
                C_Timer.After(3, function() Waypoints:CheckGhost() end)
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            Waypoints:CheckGhost()
        elseif event == "PLAYER_UNGHOST" then
            Waypoints:OnAlive()
        elseif event == "ADDON_LOADED" then
            Waypoints:HookMap()
        elseif event == "SUPER_TRACKING_CHANGED" then
            if Waypoints.FocusIsQuestButton() and C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
                local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
                if ok then Waypoints:TrackerNavi(id) end
            end
        end
    end)
    self:HookMap()
    self:HookTracker()
    ONE:RegisterSlash("way", function(rest) Waypoints:Way(rest) end, T("Wegpunkt setzen: /trip way 45.2 60.1 [Gebiet]"))
    -- /way wie bei TomTom, aber nur, wenn ihn noch niemand belegt hat
    local taken = false
    local hash = rawget(_G, "hash_SlashCmdList")
    if type(hash) == "table" and hash["/WAY"] then taken = true end
    if self.OtherNavAddon() == "TomTom" then taken = true end
    if not taken and type(SlashCmdList) == "table" then
        _G.SLASH_GUILDTRIPWAY1 = "/way"
        SlashCmdList.GUILDTRIPWAY = function(msg) Waypoints:Way(msg) end
    end
end
