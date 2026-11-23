-- Guild Trip: Restzeit im Flug (Gesamtpruefung 23.11.2026, Idee wie "Forever Flight Times").
-- Beim Klick auf ein Flugziel (hooksecurefunc auf die C-Funktion TakeTaxiNode, nur nachgelagert) merken wir
-- Start und Ziel. Waehrend des Flugs: kleiner Balken "Flug nach X – noch 1:20". Dauer: gemessen (jede Landung
-- merkt sich die echte Flugzeit je Strecke, ONE.db.nav.flightTimes), sonst geschaetzt wie Travel (Luftlinie
-- × FLY_DETOUR / FLY_SPEED + Auf-/Absteigen) – dann mit "~".
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local F = {MIN = 10, MAX = 1800}
nav.FlightTimer = F

if ONE.RegisterFeature then
    ONE:RegisterFeature("nav.flightTimer", {module = "nav", section = "Flug", order = 60,
        label = "Restzeit im Flug anzeigen",
        tooltip = "Während eines Flugs ein kleiner Balken mit Ziel und Restzeit. Jede Landung merkt sich die echte Flugzeit, danach stimmt die Zeit genau (vorher geschätzt, mit ~)."})
end
local function On() return not ONE.FeatureOn or ONE:FeatureOn("nav.flightTimer") end
local function Now() local fn = rawget(_G, "GetTime") return type(fn) == "function" and fn() or 0 end

function F:Times()
    local db = nav.Flights and nav.Flights:Store()
    if not db then return {} end
    db.flightTimes = type(db.flightTimes) == "table" and db.flightTimes or {}
    return db.flightTimes
end
function F.Key(fromID, toID) return tostring(fromID) .. ">" .. tostring(toID) end

-- Sekunden: gemessen (false) oder geschaetzt (true); nil ohne Daten
function F:Duration(fromID, toID)
    local measured = fromID and toID and self:Times()[F.Key(fromID, toID)]
    if type(measured) == "number" then return measured, false end
    local nodes = nav.Flights and nav.Flights:Nodes() or {}
    local a, b = nodes[fromID], nodes[toID]
    local Tr = nav.Travel
    if not (a and b and Tr and a.continent and a.continent == b.continent and a.x and b.x) then return nil end
    local yards = Tr.Distance(a.x, a.y, b.x, b.y)
    return math.floor(yards * Tr.FLY_DETOUR / Tr.FLY_SPEED + Tr.FLY_EXTRA * 60 + .5), true
end

function F.Clock(sec)
    sec = math.max(0, math.floor((sec or 0) + .5))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

-- Aufruf nach TakeTaxiNode(slot): Start (aktueller Flugpunkt) und Ziel aus der offenen Flugkarte
function F:OnTake(slot)
    if not On() then return end
    local TM, getMap = rawget(_G, "C_TaxiMap"), rawget(_G, "GetTaxiMapID")
    local from, to
    if TM and TM.GetAllTaxiNodes and type(getMap) == "function" then
        local okM, mapID = pcall(getMap)
        local ok, list = pcall(TM.GetAllTaxiNodes, okM and mapID or nil)
        for _, n in ipairs(ok and type(list) == "table" and list or {}) do
            if n.state == 0 then from = n end
            if n.slotIndex == slot then to = n end
        end
    end
    local name = to and to.name
    local nameFn = rawget(_G, "TaxiNodeName")
    if not name and type(nameFn) == "function" then
        local ok, n = pcall(nameFn, slot)
        if ok then name = n end
    end
    if type(name) ~= "string" then name = "?" end
    local dur, guess = self:Duration(from and from.nodeID, to and to.nodeID)
    self.flight = {from = from and from.nodeID, to = to and to.nodeID, name = name:match("^([^,]+)") or name,
        dur = dur, guess = guess, clicked = Now()}
end

function F:Started()
    local f = self.flight
    if f and not f.start then f.start = Now() self:Show() end
end

-- Landung: echte Dauer merken (nur direkt geflogene Strecken mit sinnvoller Zeit)
function F:Landed()
    local f = self.flight
    self.flight = nil
    if self.frame then self.frame:Hide() end
    if not (f and f.start and f.from and f.to) then return nil end
    local took = Now() - f.start
    if took < self.MIN or took > self.MAX then return nil end
    took = math.floor(took + .5)
    self:Times()[F.Key(f.from, f.to)] = took
    return took
end

function F:Text()
    local f = self.flight
    if not f then return "" end
    if not f.dur then return T("Flug nach %s", f.name) end
    local left = f.dur - (Now() - (f.start or Now()))
    if left <= 0 then return T("Flug nach %s – gleich da", f.name) end
    return T("Flug nach %s – noch %s", f.name, (f.guess and "~" or "") .. F.Clock(left))
end

function F:Build()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "GuildTripFlightTimer", UIParent)
    frame:SetSize(260, 26)
    local db = nav.Flights and nav.Flights:Store()
    local pos = db and db.flightTimerPos
    if type(pos) == "table" then frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos[1], pos[2])
    else frame:SetPoint("TOP", UIParent, "TOP", 0, -150) end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(s) s:StartMoving() end)
    frame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local x, y = s:GetCenter()
        local store = nav.Flights and nav.Flights:Store()
        if store and x then store.flightTimerPos = {math.floor(x + .5), math.floor(y + .5)} end
    end)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0, 0, 0, .55)
    local bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bar:SetSize(1, 3)
    bar:SetColorTexture(1, .82, 0, .9)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", frame, "CENTER", 0, 1)
    frame.bar, frame.text = bar, text
    frame:SetScript("OnEnter", function(s)
        if not GameTooltip then return end
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(T("Ziehen = verschieben"), .8, .8, .8)
        GameTooltip:AddLine(T("~ = geschätzt; nach der Landung kennt Guild Trip die echte Zeit."), .8, .8, .8, true)
        GameTooltip:AddLine(T("Ausschalten: Optionen › Navi › Flug"), .8, .8, .8)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame:Hide()
    self.frame = frame
    return frame
end

function F:Update()
    local frame, f = self.frame, self.flight
    if not (frame and f) then return end
    frame.text:SetText(self:Text())
    local w = (frame.text.GetStringWidth and frame.text:GetStringWidth() or 200) + 30
    frame:SetWidth(math.max(160, w))
    local share = f.dur and f.dur > 0 and math.min(1, (Now() - (f.start or Now())) / f.dur) or 0
    frame.bar:SetWidth(math.max(1, (frame:GetWidth() or 160) * share))
end

function F:Show()
    if not On() then return end
    self:Build():Show()
    self:Update()
end

function F:Initialize()
    if self.started then return end
    self.started = true
    local hook = rawget(_G, "hooksecurefunc")
    if type(hook) == "function" and type(rawget(_G, "TakeTaxiNode")) == "function" then
        hook("TakeTaxiNode", function(slot) pcall(F.OnTake, F, slot) end)
    end
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_CONTROL_LOST")
    pcall(ev.RegisterEvent, ev, "PLAYER_CONTROL_GAINED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_CONTROL_LOST" then
            -- Kontrolle weg kurz nach dem Klick auf ein Flugziel = Abflug
            if F.flight and Now() - (F.flight.clicked or 0) < 10 then F:Started() end
        elseif F.flight and F.flight.start then
            local onTaxi = rawget(_G, "UnitOnTaxi")
            if not (type(onTaxi) == "function" and onTaxi("player")) then F:Landed() end
        end
    end)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(.5, function() if F.flight and F.flight.start then F:Update() end end)
    end
end
