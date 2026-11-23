-- Pruefung: /trip zeit (23.11.2026) – liefert Forever die Restzeit von Quests mit Zeitlimit an Addons?
-- Zeigt beide Wege (C_QuestLog.GetTimeAllowed und GetQuestTimers) und was Guild Trip daraus macht.
-- Nur Lese-Abfragen, sendet nichts. Ergebnis auch in GuildTripDevDB.zeitCheck.
local ONE = _G.ProjectONE
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

local function Run()
    local out = {at = time and time() or 0, allowed = {}, timers = {}}
    local QL = C_QuestLog
    ONE:Print("Zeit-Pruefung: GetTimeAllowed " .. (QL and type(QL.GetTimeAllowed) == "function" and "vorhanden" or "fehlt")
        .. ", GetQuestTimers " .. (type(GetQuestTimers) == "function" and "vorhanden" or "fehlt"))
    local n = QL and QL.GetNumQuestLogEntries and select(2, pcall(QL.GetNumQuestLogEntries)) or 0
    for i = 1, tonumber(n) or 0 do
        local ok, info = pcall(QL.GetInfo, i)
        if ok and type(info) == "table" and info.questID and not info.isHeader and type(QL.GetTimeAllowed) == "function" then
            local ok2, total, elapsed = pcall(QL.GetTimeAllowed, info.questID)
            if ok2 and type(total) == "number" and total > 0 then
                out.allowed[#out.allowed + 1] = {id = info.questID, total = total, elapsed = elapsed}
                ONE:Print(("  GetTimeAllowed: %s (%d) gesamt %s s, vergangen %s s"):format(tostring(info.title), info.questID, tostring(total), tostring(elapsed)))
            end
        end
    end
    if type(GetQuestTimers) == "function" then
        local qt = {pcall(GetQuestTimers)}
        ONE:Print("  GetQuestTimers: " .. (qt[1] and (#qt - 1) .. " Zeitquest(s)" or ("Fehler " .. tostring(qt[2]))))
        for i = 2, table.maxn(qt) do out.timers[#out.timers + 1] = tostring(qt[i]) ONE:Print("    Restzeit " .. tostring(qt[i])) end
    end
    local G = ONE.ns and ONE.ns.leveling and ONE.ns.leveling.Guide
    local t = G and G.QuestTimers and G.QuestTimers() or {}
    local any = false
    for id, left in pairs(t) do any = true ONE:Print(("  Guild Trip erkennt: Quest %d, noch %d s"):format(id, left)) end
    if not any then ONE:Print("  Guild Trip erkennt: keine Quest mit Zeitlimit im Log") end
    local db = DevDB()
    if db then db.zeitCheck = out end
end

ONE:RegisterSlash("zeit", function() Run() end)
