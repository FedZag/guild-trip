local ONE = _G.ProjectONE

-- Empfang der freiwillig geteilten Zauberdaten (Gegenstueck zu ONE_Classes/Share.lua).
-- Meldet sich im Gildenkanal als Entwickler ("HELLO"), setzt die Pakete
-- zusammen, prueft die Pruefsumme und legt die Daten OHNE Absendernamen in
-- GuildTripDevDB.guildSpells ab (je Klasse und Stufe der neueste Stand).
local DevShare = {prefix = "ONECLS1", helloEvery = 300, pending = {}}
ONE.DevShare = DevShare

local function Share() return ONE.ns and ONE.ns.classes and ONE.ns.classes.Share end

function DevShare:Hello()
    local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(fn) ~= "function" or not (IsInGuild and IsInGuild()) then return false end
    return pcall(fn, self.prefix, "HELLO", "GUILD")
end

function DevShare:Receive(prefix, message, channel, sender)
    if prefix ~= self.prefix or channel ~= "WHISPER" or type(message) ~= "string" or type(sender) ~= "string" then return end
    local hash, count = message:match("^H:(%x+):(%d+)$")
    if hash then
        self.pending[sender .. hash] = {hash = hash, count = tonumber(count), parts = {}, got = 0}
        return
    end
    local h, index, payload = message:match("^C:(%x+):(%d+):(.*)$")
    local job = h and self.pending[sender .. h]
    if not job then return end
    index = tonumber(index)
    if not job.parts[index] then job.parts[index], job.got = payload, job.got + 1 end
    if job.got < job.count then return end
    self.pending[sender .. h] = nil
    local text = table.concat(job.parts)
    local S = Share()
    if not S or S.Hash(text) ~= job.hash then ONE:Print("Zauberdaten unvollständig – werden beim nächsten Mal neu geschickt.") return end
    local data = S.Deserialize(text)
    if type(data) ~= "table" or not data.class then return end
    local db = ONE:DevDB()
    db.guildSpells = type(db.guildSpells) == "table" and db.guildSpells or {}
    data.received = date and date("%Y-%m-%d %H:%M") or "?"
    -- Funde fuers Startpaket getrennt sammeln und zusammenfuehren (gleiche Form wie
    -- ProjectONEDB, damit scripts/build_pack.lua sie direkt mitliest)
    local finds = data.finds
    data.finds = nil
    db.guildSpells[data.class .. "-" .. tostring(data.level)] = data
    if type(finds) == "table" then
        db.guildFinds = type(db.guildFinds) == "table" and db.guildFinds or {}
        local gf = db.guildFinds
        for area, lists in pairs(finds) do
            gf[area] = type(gf[area]) == "table" and gf[area] or {}
            for listName, entries in pairs(type(lists) == "table" and lists or {}) do
                gf[area][listName] = type(gf[area][listName]) == "table" and gf[area][listName] or {}
                for key, e in pairs(type(entries) == "table" and entries or {}) do
                    if listName == "classSpells" and type(e) == "table" then
                        -- je Klasse: Zauber|Rang -> Stufe zusammenfuehren
                        gf[area][listName][key] = type(gf[area][listName][key]) == "table" and gf[area][listName][key] or {}
                        for k2, lvl in pairs(e) do gf[area][listName][key][k2] = lvl end
                    else
                        gf[area][listName][key] = e
                    end
                end
            end
        end
    end
    ONE:Print(("Zauberdaten erhalten: %s Stufe %s (%d Zauber, %d Talente)."):format(
        data.class, tostring(data.level), #(data.spells or {}), #(data.talents or {})))
end

function DevShare:Initialize()
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    end
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then self:Receive(...)
        elseif C_Timer and C_Timer.After then C_Timer.After(10, function() self:Hello() end) end
    end)
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(self.helloEvery, function() self:Hello() end)
    end
    self.frame = frame
end

DevShare:Initialize()
