-- Guild Trip Berufe: Berufs- und Rezept-Links aus dem Chat merken (0.7.2).
-- Liest STILL mit (Gilde, Handel, Fluestern) – sendet nie etwas, nutzt kein Kampflog.
-- Erkannt werden nur zwei Link-Arten:
--   |Htrade:...Player-1234-ABCDEF...|h[Schneiderei]|h       Beruf (Besitzer steht im Link)
--   |Henchant:3914|h[Schneiderei: Wollstoffballen]|h        Rezept (Zauber-ID = recipeID)
-- (auch |Hspell:…|h[Beruf: Rezept]|h, wenn vor dem Doppelpunkt ein Berufsname steht)
-- Gespeichert NUR lokal: ONE.db.crafting.chat[Spieler] = {profs = {[Beruf] = {stamp, src, link}},
--   recipes = {[recipeID] = {prof, stamp, src}}}. Verfaellt nach 30 Tagen. Standard: aus.
local _, crafting = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Links = {maxAge = 30 * 24 * 3600, maxPlayers = 400, maxRaw = 5, maxRecent = 8}
crafting.ChatLinks = Links

-- Nur diese Chat-Ereignisse (alle frei fuer Addons, wie im Guild-Trip-Chat)
Links.EVENTS = {CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild", CHAT_MSG_WHISPER = "whisper", CHAT_MSG_CHANNEL = "channel"}
Links.SOURCE_NAMES = {guild = "Gilde", trade = "Handel", whisper = "Flüstern"}

-- Berufe mit Rezepten (deutsch/englisch), fuer spell-Links und als Pruefung
Links.PROFESSIONS = {
    ["Alchemie"] = true, ["Schmiedekunst"] = true, ["Verzauberkunst"] = true, ["Ingenieurskunst"] = true,
    ["Lederverarbeitung"] = true, ["Schneiderei"] = true, ["Kochkunst"] = true, ["Erste Hilfe"] = true,
    ["Bergbau"] = true, ["Juwelierskunst"] = true, ["Inschriftenkunde"] = true, ["Verhüttung"] = true,
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Enchanting"] = true, ["Engineering"] = true,
    ["Leatherworking"] = true, ["Tailoring"] = true, ["Cooking"] = true, ["First Aid"] = true,
    ["Mining"] = true, ["Jewelcrafting"] = true, ["Inscription"] = true, ["Smelting"] = true,
}

local function Secret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, s = pcall(issecretvalue, v)
    return ok and s == true
end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function Same(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    return Short(a):lower() == Short(b):lower()
end

function Links:Enabled()
    local s = crafting.Recipes:Store()
    return s.chatLinks == true
end
function Links:SetEnabled(on) crafting.Recipes:Store().chatLinks = on and true or nil end

function Links:Data()
    local s = crafting.Recipes:Store()
    s.chat = type(s.chat) == "table" and s.chat or {}
    return s.chat
end

-- Handelskanal am Kanalnamen erkennen ("2. Handel - Stadt", "Trade - City")
function Links.ChannelKind(name)
    if type(name) ~= "string" then return nil end
    local base = name:lower():gsub("^%d+%.%s*", "")
    if base:find("^handel") or base:find("^trade") then return "trade" end
    return nil
end

-- Alle Links einer Nachricht: {kind = "trade"|"recipe", prof, recipe, recipeID, guid, link}
function Links.Parse(msg)
    local out = {}
    if type(msg) ~= "string" or not msg:find("|H", 1, true) then return out end
    for payload, text in msg:gmatch("|H([^|]+)|h%[([^%]]+)%]|h") do
        local kind = payload:match("^([%a]+):")
        local link = "|H" .. payload .. "|h[" .. text .. "]|h"
        if kind == "trade" then
            local guid = payload:match("(Player%-%d+%-%x+)")
            local prof = text:match("^([^:]+)$")
            if prof then out[#out + 1] = {kind = "trade", prof = prof, guid = guid, link = link} end
        elseif kind == "enchant" or kind == "spell" then
            local id = tonumber(payload:match("^%a+:(%d+)"))
            local prof, recipe = text:match("^(.-):%s*(.+)$")
            if id and prof and recipe and (kind == "enchant" or Links.PROFESSIONS[prof]) then
                out[#out + 1] = {kind = "recipe", prof = prof, recipe = recipe, recipeID = id, link = link}
            end
        end
    end
    return out
end

-- Fuer /trip berufslinks: rohe Links, die nach Beruf aussehen, aber nicht erkannt wurden
function Links:RememberRaw(msg)
    if type(msg) ~= "string" then return end
    for payload, text in msg:gmatch("|H([^|]+)|h%[([^%]]+)%]|h") do
        local kind = payload:match("^([%a]+):") or "?"
        if kind ~= "item" and kind ~= "player" and kind ~= "quest" and kind ~= "achievement"
            and not (kind == "trade" or kind == "enchant" or (kind == "spell" and text:find(":", 1, true))) then
            self.raw = self.raw or {}
            table.insert(self.raw, 1, "|H" .. payload .. "|h[" .. text .. "]|h")
            while #self.raw > self.maxRaw do table.remove(self.raw) end
        end
    end
end

-- Eine Chat-Zeile auswerten. Gibt die Zahl der gemerkten Links zurueck.
function Links:Handle(event, msg, author, channelName, authorGUID)
    if not self:Enabled() then return 0 end
    local src = self.EVENTS[event]
    if not src then return 0 end
    if Secret(msg) or Secret(author) or Secret(authorGUID) then return 0 end -- im Kampf geschuetzt
    if type(msg) ~= "string" or type(author) ~= "string" or author == "" then return 0 end
    if src == "channel" then
        src = self.ChannelKind(channelName)
        if not src then return 0 end
    end
    local R = crafting.Recipes
    if Same(author, R.Me()) then return 0 end -- eigene Rezepte kennt Guild Trip schon
    local found = self.Parse(msg)
    if #found == 0 then self:RememberRaw(msg) return 0 end
    local now, names, data = R.Now(), R:Store().names, self:Data()
    local count = 0
    for _, f in ipairs(found) do
        local owner = author
        -- Beruf-Link: der Besitzer steht im Link. Fremder Link (weitergereicht)? Dann dessen Name.
        if f.kind == "trade" and f.guid and type(authorGUID) == "string" and authorGUID ~= "" and f.guid ~= authorGUID then
            -- direkt per pcall: Call() liefert nur 4 Werte, der Name ist der 6.
            local name, realm
            if type(GetPlayerInfoByGUID) == "function" then
                local ok, _, _, _, _, _, n, r = pcall(GetPlayerInfoByGUID, f.guid)
                if ok then name, realm = n, r end
            end
            owner = type(name) == "string" and name ~= "" and ((realm and realm ~= "") and (name .. "-" .. realm) or name) or nil
        end
        if owner and not Same(owner, R.Me()) then
            local p = type(data[owner]) == "table" and data[owner] or {}
            data[owner] = p
            p.profs = type(p.profs) == "table" and p.profs or {}
            p.recipes = type(p.recipes) == "table" and p.recipes or {}
            p.stamp = now
            if f.kind == "trade" then
                p.profs[f.prof] = {stamp = now, src = src, link = f.link}
            else
                p.recipes[f.recipeID] = {prof = f.prof, stamp = now, src = src}
                if not names[f.recipeID] then names[f.recipeID] = f.recipe end
            end
            self.recent = self.recent or {}
            table.insert(self.recent, 1, {owner = owner, prof = f.prof, recipe = f.recipe, src = src, stamp = now})
            while #self.recent > self.maxRecent do table.remove(self.recent) end
            count = count + 1
        end
    end
    if count > 0 and self.onChange then pcall(self.onChange) end
    return count
end

-- Alte Eintraege (30 Tage) und zu viele Spieler entfernen
function Links:Prune(now)
    local data = self:Data()
    now = now or crafting.Recipes.Now()
    local players = {}
    for name, p in pairs(data) do
        if type(p) ~= "table" then data[name] = nil else
            for prof, e in pairs(type(p.profs) == "table" and p.profs or {}) do
                if now - (tonumber(e.stamp) or 0) > self.maxAge then p.profs[prof] = nil end
            end
            for id, e in pairs(type(p.recipes) == "table" and p.recipes or {}) do
                if now - (tonumber(e.stamp) or 0) > self.maxAge then p.recipes[id] = nil end
            end
            if not next(p.profs or {}) and not next(p.recipes or {}) then data[name] = nil
            else players[#players + 1] = {name = name, stamp = tonumber(p.stamp) or 0} end
        end
    end
    if #players > self.maxPlayers then
        table.sort(players, function(a, b) return a.stamp > b.stamp end)
        for i = self.maxPlayers + 1, #players do data[players[i].name] = nil end
    end
end

function Links:Clear()
    crafting.Recipes:Store().chat = {}
    self.recent, self.raw = nil, nil
end

-- Beruf-Link eines Spielers (zum Ansehen seines Berufsfensters)
function Links:TradeLink(owner, prof)
    local p = self:Data()[owner]
    local e = type(p) == "table" and type(p.profs) == "table" and p.profs[prof]
    return e and e.link or nil
end

-- Berufsfenster des Spielers oeffnen (wie ein Klick auf den Link im Chat)
function Links:Open(link)
    if type(link) ~= "string" then return false end
    local payload = link:match("^|H([^|]+)|h%[.-%]|h$")
    if not payload then return false end
    if type(SetItemRef) == "function" then
        return pcall(SetItemRef, payload, "|cffffd000" .. link .. "|r", "LeftButton")
    end
    return false
end

function Links:Count()
    local players, recipes, profs = 0, 0, 0
    for _, p in pairs(self:Data()) do
        if type(p) == "table" then
            players = players + 1
            for _ in pairs(p.recipes or {}) do recipes = recipes + 1 end
            for _ in pairs(p.profs or {}) do profs = profs + 1 end
        end
    end
    return players, recipes, profs
end

-- /trip berufslinks [leeren]
function Links:Slash(rest)
    rest = type(rest) == "string" and rest:lower() or ""
    if rest:find("leer") or rest:find("clear") then
        self:Clear()
        ONE:Print(T("Berufs-Links aus dem Chat gelöscht."))
        return
    end
    local players, recipes, profs = self:Count()
    ONE:Print(T("Berufs-Links aus dem Chat: %s. %d Spieler, %d Rezepte, %d Berufe gemerkt.",
        self:Enabled() and T("an") or T("aus (Optionen › Berufe)"), players, recipes, profs))
    for i, r in ipairs(self.recent or {}) do
        if i > 5 then break end
        ONE:Print(T("  %s: %s (%s)", Short(r.owner), r.recipe and (r.prof .. ": " .. r.recipe) or r.prof,
            T(self.SOURCE_NAMES[r.src] or r.src)))
    end
    if self.raw and #self.raw > 0 then
        ONE:Print(T("Nicht erkannte Links (bitte an Guild Trip melden):"))
        for _, l in ipairs(self.raw) do ONE:Print("  " .. l:gsub("|", "||")) end
    end
end

function Links:Initialize()
    local f = CreateFrame("Frame")
    for ev in pairs(self.EVENTS) do pcall(f.RegisterEvent, f, ev) end
    f:SetScript("OnEvent", function(_, event, msg, author, _, channel4, _, _, _, _, channelName, _, _, guid)
        if not self:Enabled() then return end
        if ONE.IsEnabled and not ONE:IsEnabled("crafting") then return end
        if type(channelName) ~= "string" or channelName == "" then channelName = channel4 end
        pcall(self.Handle, self, event, msg, author, channelName, guid)
    end)
    self.frame = f
    self:Prune()
    if ONE.RegisterSlash then
        ONE:RegisterSlash("berufslinks", function(rest) Links:Slash(rest) end,
            T("Berufs-Links aus dem Chat: Stand zeigen (\"leeren\" löscht alles)"))
    end
end
