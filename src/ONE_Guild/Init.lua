local _, guild = ...
local ONE = _G.ProjectONE

function guild:OnCalendarScanned()
    if self.Reminders then self.Reminders:Check() end
    if ONE.Welcome then ONE.Welcome:MarkReady("guild") end
    if ONE.UI then ONE.UI:Refresh() end
end

if ONE.RegisterFeature then
    ONE:RegisterFeature("guild.reminders", {module = "guild", label = "Erinnerungen an Gildentermine",
        get = function() return ONE.db.remindersEnabled and true or false end, set = function(on) ONE.db.remindersEnabled = on end})
    ONE:RegisterFeature("guild.mapSearch", {module = "guild", label = "Gildensuche auf der Weltkarte",
        tooltip = "Kleines Feld auf der Weltkarte, um Gildenmitglieder zu finden und das Navi zu starten."})
    ONE:RegisterFeature("guild.mapPins", {module = "guild", label = "Gildenmitglieder auf der Weltkarte",
        tooltip = "Punkte für Mitglieder, die ihre Position teilen."})
end

ONE:RegisterModule("guild", {
    title = "Gilde & Kalender",
    Initialize = function(self)
        ONE.Welcome:RegisterProvider("guild", function()
            local now = guild.Calendar:GetCurrentTime()
            if not now then return {} end
            local today = {}
            for _, event in ipairs(guild.Calendar.events or {}) do
                local t = event.startTime
                if t and t.year == now.year and t.month == now.month and t.monthDay == now.monthDay then
                    today[#today + 1] = {title = event.title, hour = t.hour or 0, minute = t.minute or 0}
                end
            end
            return today
        end, function()
            return guild.Calendar.ready, guild.Calendar.status
        end)
        guild.UI:RegisterTabs()
        guild.Calendar:Initialize()
        guild.Guild:Initialize()
        guild.Roster:Request()
        guild.Presence:Initialize()
        guild.Pins:Initialize()
        guild.Reminders:Initialize()
        -- Namens-Menue: "Navi zu …", wenn die Person ihre Position teilt
        if ONE.PlayerMenu then
            ONE.PlayerMenu:Register({id = "navi", order = 5,
                label = function(name) return ONE.T and ONE.T("Navi zu %s", ONE.PlayerMenu.Short(name)) or ("Navi zu " .. name) end,
                available = function(name)
                    local navi = ONE.modules and ONE.modules.nav
                    return navi and navi.StartTo and ONE:IsEnabled("nav") and guild.Pins and guild.Pins:GetPeer(name) ~= nil
                end,
                run = function(name)
                    local peer = guild.Pins:GetPeer(name)
                    ONE.modules.nav:StartTo(peer and peer.name or name)
                end})
        end
    end,
    -- Oeffentliche, nur lesende Schnittstelle fuer andere ONE-Module (z. B.
    -- ONE_Nav). Liefert eine Kopie, damit niemand Presence-Daten veraendert.
    GetPeer = function(self, name)
        local peer = guild.Pins and guild.Pins:GetPeer(name)
        if not peer then return nil end
        return {name = peer.name, mapID = peer.mapID, x = peer.x, y = peer.y,
            seen = peer.seen, subZone = peer.subZone}
    end,
    -- Alle aktuell live teilenden Mitglieder (Kopien, nach Name sortiert).
    LivePeers = function(self)
        local result = {}
        for _, peer in ipairs(guild.Presence and guild.Presence:ActivePeers() or {}) do
            result[#result + 1] = {name = peer.name, mapID = peer.mapID, x = peer.x, y = peer.y,
                seen = peer.seen, subZone = peer.subZone}
        end
        table.sort(result, function(a, b) return (a.name or "") < (b.name or "") end)
        return result
    end,
    DescribePeer = function(self, peer)
        return guild.Pins and guild.Pins:LocationDetails(peer) or {}
    end,
    OpenMap = function(self)
        if guild.Roster then guild.Roster:Request() end
        if guild.Pins then guild.Pins:OpenMap() end
    end,
    Diagnostics = function(self)
        local p=guild.Presence
        local stats=p and p.stats or {}
        local online=guild.Roster and guild.Roster:OnlineCount() or 0
        local live=p and #p:ActivePeers() or 0
        ONE:Print("Gilden-Diagnose | Gilde: "..tostring(IsInGuild and IsInGuild()))
        ONE:Print("Mitglieder online: "..online.." | Live-Positionen empfangen: "..live)
        ONE:Print("Eigene Freigabe: "..((p and p:IsSharing()) and "AN" or "AUS")
            .." | Sendeversuche angenommen: "..(stats.sent or 0)
            .." | Sendefehler: "..(stats.failed or 0)
            .." | Empfangene Nachrichten: "..(stats.received or 0))
        ONE:Print("WICHTIG: 'Senden angenommen' beweist NICHT, dass ein anderes Mitglied die Nachricht erhält.")
    end,
    RequestRefresh = function(self)
        guild.Calendar:RequestRefresh()
    end,
})
