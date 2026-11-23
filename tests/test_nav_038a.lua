-- Offline-Test fuer ONE_Nav 0.3.8a (Stufe 0, Diagnose). Run: lua tests/test_nav_038a.lua src
local root = arg[1] or "src"
local printed = {}
local registered = {}
local timers = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) printed[#printed + 1] = m end}
CreateFrame = function()
    local f = {}
    function f:RegisterEvent(ev)
        registered[ev] = registered[ev] or self
        registered["all:" .. ev] = registered["all:" .. ev] or {}
        table.insert(registered["all:" .. ev], self)
    end
    function f:UnregisterEvent(ev) registered[ev] = nil end
    function f:SetScript(ev, fn) self[ev] = fn end
    return f
end
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn, n)
        local t = {fn = fn, n = n, cancelled = false}
        function t:Cancel() self.cancelled = true end
        timers.ticker = t
        return t
    end,
}
local function RunTimers()
    local list = {}
    for i, fn in ipairs(timers) do list[i] = fn end
    for i = #timers, 1, -1 do timers[i] = nil end
    for _, fn in ipairs(list) do fn() end
end

-- Geheime Werte simulieren: jeder Zugriff ausser issecretvalue wirft einen Fehler.
local SECRET = setmetatable({}, {
    __index = function() error("secret value accessed") end,
    __eq = function() error("secret compare") end,
    __lt = function() error("secret compare") end,
    __tostring = function() error("secret tostring") end,
})
issecretvalue = function(v) return v == nil and false or rawequal(v, SECRET) end

-- Minimaler Forever-artiger Client
GetBuildInfo = function() return "1.60.1", "70755", "Nov 3 2026", 16001 end
GetServerTime = function() return 1794000000 end
IsInInstance = function() return false, "none" end
GetZoneText = function() return "Durotar" end
GetSubZoneText = function() return "Razor Hill" end
InCombatLockdown = function() return false end
IsSwimming = function() return false end
IsMounted = function() return true end
IsFlying = function() return false end
UnitOnTaxi = function() return false end
UnitIsDeadOrGhost = function() return false end
GetPlayerFacing = function() return SECRET end          -- Fall: geheim
UnitPosition = function() return -4500.5, 300.25, 0, 1 end
GetUnitSpeed = function() return 7, 7, 4.5, 4.72 end
CreateVector2D = function(x, y) return {x = x, y = y} end
local vec = {x = .52, y = .44}
function vec:GetXY() return self.x, self.y end
local waypoint
C_Map = {
    GetBestMapForUnit = function() return 1411 end,
    GetPlayerMapPosition = function() return vec end,
    GetMapInfo = function(id) return {name = "Karte" .. id, mapType = 3, parentMapID = 1414} end,
    GetWorldPosFromMapPos = function(id, p)
        if id == 1434 then error("unknown map") end
        return (id == 1420 or id == 1458 or id == 1434 or id == 1415) and 0 or 1,
            {x = -4000 + p.x * 100, y = 200 + p.y * 100}
    end,
    GetMapWorldSize = function() return 5000, 3333.3333333 end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p) waypoint = p end,
    GetUserWaypoint = function() return waypoint end,
    ClearUserWaypoint = function() waypoint = nil end,
}
UiMapPoint = {CreateFromCoordinates = function(m, x, y) return {uiMapID = m, position = {x = x, y = y}} end}
C_SuperTrack = {SetSuperTrackedUserWaypoint = function() end, IsSuperTrackingUserWaypoint = function() return true end}
-- C_Navigation fehlt absichtlich.
C_AddOns = {LoadAddOn = function() end}
GetTaxiMapID = function() return 1414 end
C_TaxiMap = {GetAllTaxiNodes = function()
    return {
        {nodeID = 23, name = "Orgrimmar", state = 0, slotIndex = 1, position = {x = .5, y = .3}},
        {nodeID = 25, name = "Crossroads", state = 1, slotIndex = 2, position = {x = .48, y = .5}},
        {nodeID = 22, name = "Thunder Bluff", state = 2, slotIndex = 3, position = SECRET},
    }
end}
TaxiNodeGetType = function(i) return i == 1 and "CURRENT" or "REACHABLE" end
GetNumRoutes = function(i) return i == 3 and 2 or 1 end

-- Core laden
local ONE = {
    UI = {Initialize = function() end, Refresh = function() end, Toggle = function() ONE_toggled = true end},
    Themes = {Initialize = function() end},
    Welcome = {Initialize = function() end},
    Notifications = {Initialize = function() end, Push = function() return true end},
}
assert(loadfile(root .. "/ONE_Core/Core.lua"))("ONE_Core", ONE)
ProjectONEDB = {}
registered.ADDON_LOADED.OnEvent(registered.ADDON_LOADED, "ADDON_LOADED", "ONE_Core")
assert(ONE.started)

-- ONE_Nav gemaess TOC laden
local nav = {}
local toc = assert(io.open(root .. "/ONE_Nav/ONE_Nav.toc"))
local files = 0
local tocText = toc:read("*a")
toc:close()
assert(tocText:find("## Interface: 16001", 1, true), "ONE_Nav nicht fuer Forever 16001")
assert(tocText:find("## Dependencies: ONE_Core", 1, true))
for name in tocText:gmatch("\n([%w_]+%.lua)") do
    assert(loadfile(root .. "/ONE_Nav/" .. name))("ONE_Nav", nav)
    files = files + 1
end
assert(files >= 2, "zu wenige Lua-Dateien in ONE_Nav")
assert(ONE.modules.nav and ONE.modules.nav.initialized, "Modul nav nicht gestartet")
assert(not ONE.slashCommands.navdiag, "ohne ONE_Dev keine Testbefehle")
-- Testwerkzeug aus dem Entwickler-Addon dazuladen (haengt sich an ONE.ns.nav)
assert(loadfile(root .. "/ONE_Dev/NavDiag.lua"))("ONE_Dev", {})
assert(ONE.slashCommands.navdiag and ONE.slashCommands.navpfeil)
assert(not ONE:RegisterSlash("navdiag", function() end), "Doppelregistrierung muss scheitern")
assert(not ONE:RegisterSlash("Map Test", function() end), "ungueltiger Name muss scheitern")

-- 1) /one navdiag ueber den echten Slash-Handler
SlashCmdList.PROJECTONE("navdiag Hoehle")
local d = ONE.db.navDiag
assert(d and #d.runs == 1, "Messung nicht gespeichert")
local run = d.runs[1]
assert(run.note == "hoehle")
assert(run.build.interface == 16001)
assert(run.position.map == 1411 and run.position.x == .52 and run.position.continent == 1)
assert(run.position.worldX == -3948 and run.position.worldY == 244, "Weltkoordinaten falsch: "
    .. tostring(run.position.worldX) .. "/" .. tostring(run.position.worldY))
assert(run.facing.value == "GEHEIM", "geheime Blickrichtung muss als GEHEIM markiert werden")
assert(run.unitPosition.z == 0 and run.unitPosition.instance == 1)
assert(run.speed.run == 7)
assert(run.waypoint.canSet == true and run.waypoint.superTrack == true)
assert(run.waypoint.navDistance == nil, "fehlendes C_Navigation darf keinen Wert erfinden")
assert(run.situation.zone == "Durotar" and run.situation.mounted == true)
local byLabel = {}
for _, m in ipairs(run.maps) do byLabel[m.label] = m end
assert(byLabel.Durotar.continent == 1 and byLabel.Tirisfal.continent == 0)
assert(byLabel.Schlingendorn.status == "FEHLER", "Fehler einer Karte muss erfasst, nicht geworfen werden")
assert(byLabel.Durotar.height == 3333.3333, "Zahlen werden auf 4 Stellen gerundet")
-- Ausgabe im Chat ohne Lua-Fehler
local joined = table.concat(printed, "\n")
assert(joined:find("Navi-Test gespeichert", 1, true))
assert(joined:find("GEHEIM", 1, true))

-- 2) Nichts davon darf in den Gilden-Kanal gehen
assert(C_ChatInfo == nil)

-- 3) Flugkarte automatisch erfassen
for _, fr in ipairs(registered["all:TAXIMAP_OPENED"]) do fr.OnEvent(fr, "TAXIMAP_OPENED") end
RunTimers()
assert(#d.taxi == 1)
local taxi = d.taxi[1]
assert(taxi.status == "OK" and taxi.total == 3 and taxi.taxiMap == 1414)
assert(taxi.counts["0"] == 1 and taxi.counts["1"] == 1 and taxi.counts["2"] == 1)
assert(taxi.nodes[3].x == "GEHEIM", "geheime Knotenposition darf nicht crashen")
assert(taxi.nodes[3].routes == 2 and taxi.nodes[1].type == "CURRENT")

-- 4) Pfeil-Test setzt und entfernt nur den eigenen Wegpunkt
SlashCmdList.PROJECTONE("navpfeil")
assert(waypoint and waypoint.uiMapID == 1411 and d.arrow.set == "OK")
RunTimers()
assert(d.arrow.trackingLater == true)
SlashCmdList.PROJECTONE("navpfeil aus")
assert(waypoint == nil, "eigener Test-Wegpunkt muss entfernt werden")
SlashCmdList.PROJECTONE("navpfeil")
waypoint = {uiMapID = 1411, position = {x = .1, y = .9}} -- Spieler setzt eigenen Wegpunkt
SlashCmdList.PROJECTONE("navpfeil aus")
assert(waypoint and waypoint.position.x == .1, "fremder Wegpunkt darf nicht geloescht werden")

-- 5) Kampf: kein Pfeil-Test
InCombatLockdown = function() return true end
waypoint = nil
SlashCmdList.PROJECTONE("navpfeil")
assert(waypoint == nil)
InCombatLockdown = function() return false end

-- 6) Fahrt-Test sammelt begrenzt und stoppt selbst
SlashCmdList.PROJECTONE("navdiag fahrt")
local ticker = timers.ticker
assert(ticker and #d.rides == 1)
for _ = 1, 60 do ticker.fn() end
assert(#d.rides[1].samples == 60 and ticker.cancelled)

-- 7) Fehlende APIs (aelterer/anderer Client) duerfen nichts zerbrechen
local saved = C_Map
C_Map = nil
GetPlayerFacing = nil
SlashCmdList.PROJECTONE("navdiag")
assert(#d.runs == 2 and d.runs[2].position.bestStatus == "FEHLT")
assert(d.runs[2].facing.status == "FEHLT")
C_Map = saved

-- 8) Begrenzung der gespeicherten Messungen
for _ = 1, 50 do SlashCmdList.PROJECTONE("navdiag") end
assert(#d.runs == 40)

-- 9) Pausiertes Modul tut nichts
ONE.db.modules.nav = false
local before = #d.runs
SlashCmdList.PROJECTONE("navdiag")
assert(#d.runs == before)
for _, fr in ipairs(registered["all:TAXIMAP_OPENED"]) do fr.OnEvent(fr, "TAXIMAP_OPENED") end
RunTimers()
assert(#d.taxi == 1)
ONE.db.modules.nav = nil

-- 10) Loeschen
SlashCmdList.PROJECTONE("navdiag loeschen")
assert(ONE.db.navDiag == nil)

-- 11) Unbekannte Befehle: seit 23.11.2026 Hinweis statt Fenster (Nutzer, Gesamtpruefung); Hilfe listet Modulbefehle
ONE_toggled = false
printed = {}
SlashCmdList.PROJECTONE("irgendwas")
assert(not ONE_toggled and table.concat(printed, "\n"):find("/trip hilfe", 1, true))
SlashCmdList.PROJECTONE("")
assert(ONE_toggled)
printed = {}
SlashCmdList.PROJECTONE("hilfe")
assert(table.concat(printed, "\n"):find("/trip navdiag", 1, true))

print("OK: 0.3.8a - ONE_Nav Diagnose, geheime Werte, Flugkarte, Pfeil-Test, Fahrt-Test, Datenschutz")
