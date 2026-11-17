-- Project ONE Berufe: Rezepte in der Gilde teilen (nur mit eigener Zustimmung).
-- Praefix ONECRF1, nur Gilden-Addon-Kanal. Nachrichten:
--   C0|beruf|skill|max|stand     Beginn eines Berufs (ersetzt den alten Stand)
--   C1|beruf|rezept:gegenstand,...   gelernte Rezepte (in Stuecken <= 230 Zeichen)
--   COFF                          Teilen ausgeschaltet -> Daten beim Empfaenger loeschen
--   CREQ                          "Bitte schickt eure Rezepte"
--   T|npc|art|wofuer|karte|x|y|ort    gefundener Lehrer (Weltwissen, kein Personenbezug)
local _, crafting = ...
local ONE = _G.ProjectONE
local Share = {prefix = "ONECRF1", queue = {}, chunk = 230, replyGap = 60}
crafting.Share = Share

local function Same(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    return a:lower() == b:lower() or (a:match("^[^-]+") or a):lower() == (b:match("^[^-]+") or b):lower()
end
local function Split(msg)
    local out = {}
    for part in (msg .. "|"):gmatch("([^|]*)|") do out[#out + 1] = part end
    return out
end
local function Clean(text) return (tostring(text or ""):gsub("[|:,\r\n]", " ")) end

function Share:IsSharing() return crafting.Recipes:Store().shareChars[crafting.Recipes.Me()] == true end
function Share:SetSharing(on)
    crafting.Recipes:Store().shareChars[crafting.Recipes.Me()] = on and true or nil
    if on then self:SendAll() else self:Send("COFF") end
end

function Share:Send(msg)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    if not (IsInGuild and IsInGuild()) then return false end
    self.queue[#self.queue + 1] = msg
    if not self.ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
        self.ticker = C_Timer.NewTicker(.4, function() self:Flush(1) end)
    elseif not self.ticker then
        self:Flush(#self.queue)
    end
    return true
end
function Share:Flush(n)
    for _ = 1, n or 1 do
        local msg = table.remove(self.queue, 1)
        if not msg then break end
        pcall(C_ChatInfo.SendAddonMessage, self.prefix, msg, "GUILD")
    end
end

-- Einen Beruf in Stuecken senden.
function Share:SendProfession(prof, data)
    local name = Clean(prof)
    self:Send(table.concat({"C0", name, data.skill or 0, data.max or 0, data.stamp or 0}, "|"))
    local parts, length = {}, 0
    local ids = {}
    for id in pairs(data.recipes or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local piece = id .. ":" .. (data.recipes[id] or 0)
        if length + #piece + 1 > self.chunk and #parts > 0 then
            self:Send("C1|" .. name .. "|" .. table.concat(parts, ","))
            parts, length = {}, 0
        end
        parts[#parts + 1] = piece
        length = length + #piece + 1
    end
    if #parts > 0 then self:Send("C1|" .. name .. "|" .. table.concat(parts, ",")) end
end
function Share:SendAll()
    if not self:IsSharing() then return false end
    for prof, data in pairs(crafting.Recipes:Mine()) do self:SendProfession(prof, data) end
    -- eigene Lehrer-Funde der letzten 30 Tage mitschicken (neue Mitglieder bekommen sie so auch)
    local me, now, n = crafting.Recipes.Me(), crafting.Recipes.Now(), 0
    for _, e in pairs(crafting.Trainers:Store()) do
        if n < 30 and Same(e.by, me) and (now - (e.seen or 0)) < 30 * 24 * 3600 and e.map then
            n = n + 1
            self:SendTrainer(e)
        end
    end
    return true
end

function Share:Receive(prefix, msg, channel, sender)
    if prefix ~= self.prefix or channel ~= "GUILD" or type(msg) ~= "string" or type(sender) ~= "string" then return end
    if Same(sender, crafting.Recipes.Me()) or #msg > 255 then return end
    local p = Split(msg)
    local R = crafting.Recipes
    if p[1] == "C0" and p[2] and p[2] ~= "" then
        R:SetGuildProfession(sender, p[2], tonumber(p[3]) or 0, tonumber(p[4]) or 0, tonumber(p[5]) or R.Now(), {})
    elseif p[1] == "C1" and p[2] then
        local guild = R:Store().guild[sender]
        local data = guild and guild[p[2]]
        if not data then return end
        for id, item in (p[3] or ""):gmatch("(%d+):(%d+)") do data.recipes[tonumber(id)] = tonumber(item) end
    elseif p[1] == "COFF" then
        R:RemoveMember(sender)
    elseif p[1] == "T" and p[2] and p[2] ~= "" then
        local store = crafting.Trainers and crafting.Trainers:Store()
        if store then
            local old = store[p[2]]
            local teaches
            for rank in (p[9] or ""):gmatch("[^,]+") do teaches = teaches or {} teaches[rank] = true end
            -- 10. Feld: Waffenarten eines Waffenmeisters ("axe2,bow,staff")
            local weapons
            if p[3] == "weapon" then
                for key in (p[10] or ""):gmatch("[^,]+") do
                    if key:match("^%l[%l%d]*$") and #key <= 12 then weapons = weapons or {} weapons[key] = true end
                end
            end
            store[p[2]] = {npc = p[2], kind = p[3], what = p[4], map = tonumber(p[5]), x = tonumber(p[6]),
                y = tonumber(p[7]), area = p[8], seen = R.Now(), by = sender,
                teaches = teaches or (old and old.teaches), weapons = weapons or (old and old.weapons)}
        end
    elseif p[1] == "CREQ" then
        local now = type(GetTime) == "function" and GetTime() or 0
        if self:IsSharing() and now - (self.lastReply or -999) > self.replyGap then
            self.lastReply = now
            local delay = 2 + (math.random and math.random() * 8 or 4)
            if C_Timer and C_Timer.After then C_Timer.After(delay, function() self:SendAll() end) else self:SendAll() end
        end
    end
    if self.onChange then self.onChange() end
end

-- Lehrer-Funde verraten, wo man gerade war: nur mit Berufe-Freigabe (eigenes Haekchen).
function Share:SendTrainer(e)
    if not e or not self:IsSharing() then return false end
    -- 9. Feld: gelehrte Ausbildungsstufen ("Geselle,Experte"), damit die Gilde die
    -- Experten-/Fachmann-Lehrer findet (aeltere Versionen ignorieren es)
    local teaches = {}
    for _, r in ipairs(crafting.Trainers.ranks) do if type(e.teaches) == "table" and e.teaches[r.name] then teaches[#teaches + 1] = r.name end end
    -- 10. Feld: Waffenarten eines Waffenmeisters (sortiert, damit gleiche Funde gleich aussehen)
    local weapons = {}
    if e.kind == "weapon" and type(e.weapons) == "table" then
        for key, on in pairs(e.weapons) do if on then weapons[#weapons + 1] = key end end
        table.sort(weapons)
    end
    return self:Send(table.concat({"T", Clean(e.npc), Clean(e.kind), Clean(e.what), e.map or "",
        e.x or "", e.y or "", Clean(e.area), table.concat(teaches, ","), table.concat(weapons, ",")}, "|"))
end

function Share:Initialize()
    if not (C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function") then return false end
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, ...) self:Receive(...) end)
    self.frame = f
    if C_Timer and C_Timer.After then
        C_Timer.After(15, function() self:SendAll() self:Send("CREQ") end)
    end
    return true
end
