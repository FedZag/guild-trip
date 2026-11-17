-- Project ONE Navigation: eigene Flugpunkte merken.
-- Belegt im Forever-Spieltest: GetAllTaxiNodes(GetTaxiMapID()) listet beim
-- Flugmeister alle Flugpunkte des Kontinents; state 0 = hier, 1 = erreichbar
-- (= bekannt), 2 = noch nicht entdeckt. Die Taxikarte hat eine eigene ID
-- (Kalimdor: 1464), daher wird jede Umrechnung gegen die eigene Position geprueft.
local _, nav = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Flights = {maxCheckDistance = 200}
nav.Flights = Flights

local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) == true
end
local function Number(v) return type(v) == "number" and not IsSecret(v) and v == v end

local function CharacterKey()
    if type(UnitFullName) == "function" then
        local ok, name, realm = pcall(UnitFullName, "player")
        if ok and type(name) == "string" and name ~= "" then
            return name .. "-" .. (type(realm) == "string" and realm or "")
        end
    end
end

function Flights:Store()
    if not ONE.db then return end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    local db = ONE.db.nav
    db.nodes = type(db.nodes) == "table" and db.nodes or {}
    db.chars = type(db.chars) == "table" and db.chars or {}
    return db
end

function Flights:Known()
    local db, key = self:Store(), CharacterKey()
    if not db or not key then return {} end
    db.chars[key] = type(db.chars[key]) == "table" and db.chars[key] or {}
    local char = db.chars[key]
    char.known = type(char.known) == "table" and char.known or {}
    return char.known
end

function Flights:Nodes()
    local db = self:Store()
    return db and db.nodes or {}
end

local function Field(t, k)
    if type(t) ~= "table" or IsSecret(t) then return end
    local ok, v = pcall(function() return t[k] end)
    if ok and not IsSecret(v) then return v end
end

function Flights:Capture()
    local db = self:Store()
    if not db or type(GetTaxiMapID) ~= "function" then return end
    local okMap, taxiMap = pcall(GetTaxiMapID)
    if not okMap or not Number(taxiMap) then return end
    if not (C_TaxiMap and type(C_TaxiMap.GetAllTaxiNodes) == "function") then return end
    local okNodes, list = pcall(C_TaxiMap.GetAllTaxiNodes, taxiMap)
    if not okNodes or type(list) ~= "table" then return end
    local playerContinent, playerX, playerY = nav.Travel.PlayerWorld()
    local converted, current = {}, nil
    for _, node in ipairs(list) do
        local id, name, state = Field(node, "nodeID"), Field(node, "name"), Field(node, "state")
        local pos = Field(node, "position")
        local px, py = Field(pos, "x"), Field(pos, "y")
        if Number(id) and type(name) == "string" and not name:find("^zz") then
            local entry = {id = id, name = name, state = state}
            local continent, wx, wy = nav.Travel.World(taxiMap, px, py)
            entry.continent, entry.x, entry.y = continent, wx, wy
            converted[#converted + 1] = entry
            if state == 0 then current = entry end
        end
    end
    -- Umrechnung nur glauben, wenn der Flugpunkt "hier" nahe an der eigenen
    -- Position liegt. Sonst nur den aktuellen Flugpunkt mit eigener Position.
    local trusted = current and playerContinent and current.continent == playerContinent
        and Number(current.x) and nav.Travel.Distance(playerX, playerY, current.x, current.y)
            <= self.maxCheckDistance
    local known = self:Known()
    local learned = 0
    for _, entry in ipairs(converted) do
        if trusted and Number(entry.x) then
            db.nodes[entry.id] = {name = entry.name, continent = entry.continent, x = entry.x, y = entry.y}
        elseif entry == current and playerContinent then
            db.nodes[entry.id] = {name = entry.name, continent = playerContinent, x = playerX, y = playerY}
        end
        if entry.state == 0 or entry.state == 1 then
            if not known[entry.id] then learned = learned + 1 end
            known[entry.id] = true
        end
    end
    self.lastTrusted = trusted and true or false
    if learned > 0 then
        ONE:Print(T("Navi: %d Flugpunkt(e) gemerkt.", learned))
    end
    return learned
end

function Flights:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TAXIMAP_OPENED")
    frame:SetScript("OnEvent", function()
        if not ONE:IsEnabled("nav") then return end
        if C_Timer and C_Timer.After then
            C_Timer.After(.3, function() self:Capture() end)
        else
            self:Capture()
        end
    end)
    self.frame = frame
end
