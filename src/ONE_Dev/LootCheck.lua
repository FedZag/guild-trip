-- Guild Trip (nur lokal, ONE_Dev): Liefert Forever Beute-Daten fuer ein Ausruestungs-Modul?
-- /trip lootcheck geht das Dungeon-Kompendium (Encounter Journal) durch:
--  * Stufen (Tiers), Instanzen (Dungeons und Raids), Bosse je Instanz
--  * Beute je Instanz (EJ_GetNumLoot + C_EncounterJournal.GetLootInfoByIndex bzw. EJ_GetLootInfoByIndex)
--  * ob die Gegenstaende Werte haben (GetItemStats) und welcher Boss sie fallen laesst
-- Laeuft in Haeppchen (je Instanz ~1,5 s, Beute wird nachgeladen). Ergebnis in
-- GuildTripDevDB.lootCheck (erst nach /reload gespeichert). Nur Spieldaten.
local ONE = _G.ProjectONE
if not ONE then return end
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

local LC = {}
ONE.LootCheck = LC

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function After(sec, fn) if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end end

-- Beute-Eintrag lesen (neue oder alte Abfrage)
local function LootAt(i)
    local info = Try(C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex, i)
    if type(info) == "table" then return info end
    local itemID, encounterID, name, icon, slot, armorType, link = Try(EJ_GetLootInfoByIndex, i)
    if itemID then return {itemID = itemID, encounterID = encounterID, name = name, slot = slot, armorType = armorType, link = link} end
end

function LC:Run()
    if self.running then ONE:Print("Lootcheck läuft schon …") return end
    self.running = true
    local r = {when = date and date("%Y-%m-%d %H:%M") or "?", has = {}, instances = {}}
    for _, name in ipairs({"EJ_GetNumTiers", "EJ_SelectTier", "EJ_GetInstanceByIndex", "EJ_SelectInstance",
        "EJ_GetEncounterInfoByIndex", "EJ_SelectEncounter", "EJ_GetNumLoot", "EJ_GetLootInfoByIndex",
        "EJ_ResetLootFilter", "EJ_SetLootFilter", "EJ_GetInstanceInfo", "GetItemStats"}) do
        r.has[name] = type(_G[name]) == "function"
    end
    r.has["C_EncounterJournal.GetLootInfoByIndex"] = C_EncounterJournal and type(C_EncounterJournal.GetLootInfoByIndex) == "function" or false
    r.has["C_Item.GetItemStats"] = C_Item and type(C_Item.GetItemStats) == "function" or false
    r.has["C_TooltipInfo.GetHyperlink"] = C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" or false
    -- Das Kompendium fuellt seine Daten manchmal erst, wenn sein Fenster geladen ist
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    r.loadedJournal = Try(load, "Blizzard_EncounterJournal") and true or false
    -- Probe: Werte eines bekannten Gegenstands (Spieler-Ausruestung, Handgelenk/Brust)
    for _, slot in ipairs({9, 5, 16}) do
        local link = Try(GetInventoryItemLink, "player", slot)
        if link then
            r.probe = {slot = slot, link = link, cItemStats = Try(C_Item and C_Item.GetItemStats, link)}
            local tip = Try(C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
            if type(tip) == "table" and tip.lines then
                r.probe.lines = {}
                for i, l in ipairs(tip.lines) do if i <= 12 then r.probe.lines[i] = l.leftText end end
            end
            break
        end
    end
    -- Beute fuer alle Klassen zeigen (sonst filtert das Kompendium nach der eigenen Klasse)
    Try(EJ_ResetLootFilter)
    Try(EJ_SetLootFilter, 0, 0)
    r.tiers = Try(EJ_GetNumTiers) or 0
    -- alle Instanzen aller Stufen sammeln
    local list = {}
    for tier = 1, math.max(1, r.tiers) do
        Try(EJ_SelectTier, tier)
        for _, raid in ipairs({false, true}) do
            for i = 1, 80 do
                local id, name = Try(EJ_GetInstanceByIndex, i, raid)
                if not id then break end
                list[#list + 1] = {id = id, name = name, raid = raid, tier = tier}
            end
        end
    end
    r.instanceCount = #list
    ONE:Print(("Lootcheck: %d Instanzen gefunden, lese Beute … (ca. %d Sekunden)"):format(#list, math.ceil(#list * 1.5)))
    local totalLoot, withStats, withBoss = 0, 0, 0
    local idx = 0
    local function Finish()
        r.totalLoot, r.withStats, r.withBoss = totalLoot, withStats, withBoss
        DevDB().lootCheck = r
        self.running = false
        ONE:Print(("Lootcheck fertig: %d Instanzen, %d Beute-Einträge, davon %d mit Werten und %d mit Boss. Jetzt /reload.")
            :format(#list, totalLoot, withStats, withBoss))
    end
    local function Next()
        idx = idx + 1
        local inst = list[idx]
        if not inst then return Finish() end
        Try(EJ_SelectTier, inst.tier)
        Try(EJ_SelectInstance, inst.id)
        Try(EJ_ResetLootFilter)
        local e = {name = inst.name, raid = inst.raid, bosses = {}, loot = {}}
        for j = 1, 30 do
            local bname, _, encounterID = Try(EJ_GetEncounterInfoByIndex, j, inst.id)
            if not bname then break end
            e.bosses[#e.bosses + 1] = {name = bname, id = encounterID}
        end
        Try(EJ_GetNumLoot) -- Nachladen anstossen
        After(1.2, function()
            local n = Try(EJ_GetNumLoot) or 0
            e.lootCount = n
            for i = 1, math.min(n, 60) do
                local info = LootAt(i)
                if type(info) == "table" then
                    totalLoot = totalLoot + 1
                    local link = info.link or (info.itemID and ("item:" .. info.itemID))
                    local stats = link and (Try(C_Item and C_Item.GetItemStats, link) or Try(GetItemStats, link))
                    local statCount = 0
                    for _ in pairs(type(stats) == "table" and stats or {}) do statCount = statCount + 1 end
                    if statCount > 0 then withStats = withStats + 1 end
                    if info.encounterID then withBoss = withBoss + 1 end
                    -- nur die ersten 8 je Instanz ausfuehrlich speichern (Dateigroesse)
                    if #e.loot < 8 then
                        e.loot[#e.loot + 1] = {itemID = info.itemID, name = info.name, slot = info.slot,
                            armorType = info.armorType, encounterID = info.encounterID, stats = stats}
                    end
                end
            end
            r.instances[#r.instances + 1] = e
            if idx % 10 == 0 then ONE:Print(("Lootcheck: %d/%d Instanzen …"):format(idx, #list)) end
            After(.3, Next)
        end)
    end
    Next()
end

ONE:RegisterSlash("lootcheck", function() LC:Run() end)
