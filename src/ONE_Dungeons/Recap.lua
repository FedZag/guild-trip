-- Guild Trip: Dungeon-Rueckblick (0.7.0).
-- Nach jedem Dungeon (mindestens 5 Minuten drin) eine kleine Karte:
--   "Die Todesminen – 42 Min. (neue Bestzeit!)"
--   Gruppe, besiegte Bosse, Tode je Spieler, Beute (gruen und besser, wer sie bekam).
-- [In den Gildenchat] postet eine Zeile dazu, [Schliessen] macht zu.
-- Die Bestzeit landet im Gildenpass beim Stempel des Dungeons (best = Sekunden).
-- Nichts wird geteilt, solange du nicht selbst auf "In den Gildenchat" klickst.
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local R = {minTime = 300, minQuality = 2, maxLoot = 6}
dungeons.Recap = R

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end
local function G(name) return rawget(_G, name) end
local function Clock() return Call(G("GetTime")) or 0 end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function Me() return Short(Call(G("UnitName"), "player")) end
local function FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("dungeons.recap") end

-- ===== Beute-Zeilen (CHAT_MSG_LOOT) =====
local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local HEX = {["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5}
local function Quality(link)
    local _, _, q = Call(G("GetItemInfo"), link)
    if type(q) == "number" then return q end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    return HEX[(hex or ""):lower()] or 1
end
-- Liefert wer, link oder nil
function R.ParseLoot(text, author)
    if type(text) ~= "string" then return nil end
    local link = text:match("(|c.-|Hitem:.-|h%[.-%]|h|r)")
    if not link then return nil end
    for _, def in ipairs({{"LOOT_ITEM_MULTIPLE"}, {"LOOT_ITEM"}, {"LOOT_ITEM_PUSHED_MULTIPLE"}, {"LOOT_ITEM_PUSHED"},
            {"LOOT_ITEM_SELF_MULTIPLE", true}, {"LOOT_ITEM_SELF", true}, {"LOOT_ITEM_PUSHED_SELF_MULTIPLE", true}, {"LOOT_ITEM_PUSHED_SELF", true}}) do
        local p = Pattern(G(def[1]))
        local who = p and text:match(p)
        if who then return def[2] and Me() or Short(who), link end
    end
    -- Kennt das Spiel die Beute-Texte, war es keine Beute-Zeile (z. B. Wuerfeln)
    if G("LOOT_ITEM") or text:find("[Ww]ürfel") or text:lower():find("roll") then return nil end
    return (author and author ~= "") and Short(author) or Me(), link
end

-- ===== Lauf =====
function R:Start(key, name)
    self.run = {key = key, name = name or key, start = Clock(), deaths = {}, loot = {}, bosses = {}, group = {}, dead = {}}
    self:Roster()
    -- Ausgangslage merken: wer schon tot reinkommt, zaehlt nicht
    for _, u in ipairs(self:Units()) do
        local n = Call(G("UnitExists"), u) and Call(G("UnitName"), u)
        if type(n) == "string" then self.run.dead[Short(n)] = Call(G("UnitIsDeadOrGhost"), u) and true or false end
    end
end

function R:Units()
    local out = {"player"}
    if Call(G("IsInRaid")) then for i = 1, 40 do out[#out + 1] = "raid" .. i end
    else for i = 1, 4 do out[#out + 1] = "party" .. i end end
    return out
end

-- Wer war dabei? (alle, die irgendwann in der Gruppe waren)
function R:Roster()
    local run = self.run
    if not run then return end
    for _, u in ipairs(self:Units()) do
        local n = Call(G("UnitExists"), u) and Call(G("UnitName"), u)
        if type(n) == "string" and n ~= "" then run.group[Short(n)] = true end
    end
end

-- Tode zaehlen: Wechsel lebendig -> tot (alle 2 Sekunden nachsehen)
function R:CheckDeaths()
    local run = self.run
    if not run then return end
    for _, u in ipairs(self:Units()) do
        local n = Call(G("UnitExists"), u) and Call(G("UnitName"), u)
        if type(n) == "string" then
            n = Short(n)
            local dead = Call(G("UnitIsDeadOrGhost"), u) and true or false
            if dead and not run.dead[n] then run.deaths[n] = (run.deaths[n] or 0) + 1 end
            run.dead[n] = dead
        end
    end
end

function R:OnLoot(text, author)
    local run = self.run
    if not run then return end
    local who, link = R.ParseLoot(text, author)
    if who and link and Quality(link) >= self.minQuality then run.loot[#run.loot + 1] = {who = who, link = link} end
end

function R:OnBoss(name, success)
    if self.run and success and type(name) == "string" then self.run.bosses[#self.run.bosses + 1] = name end
end

-- Dungeon verlassen: Rueckblick bauen (nil, wenn zu kurz)
function R:Finish()
    local run = self.run
    self.run = nil
    if not run then return nil end
    local secs = Clock() - run.start
    if secs < self.minTime then return nil end
    run.secs = secs
    -- Bestzeit im Gildenpass
    local P = dungeons.Passport
    local stamp = P and P.Mine and P:Mine().d[run.key]
    if stamp then
        if not stamp.best or secs < stamp.best then
            run.record = stamp.best ~= nil
            stamp.best = math.floor(secs)
        end
    end
    self.last = run
    if FeatureOn() then self:Show(run) end
    return run
end

-- ===== Texte =====
local function Minutes(secs) return math.max(1, math.floor(secs / 60 + .5)) end

function R:Lines(run)
    local lines = {}
    local names = {}
    for n in pairs(run.group) do names[#names + 1] = n end
    table.sort(names)
    lines[#lines + 1] = T("Gruppe: %s", table.concat(names, ", "))
    if #run.bosses > 0 then lines[#lines + 1] = T("Bosse: %d (%s)", #run.bosses, table.concat(run.bosses, ", ")) end
    local total, parts = 0, {}
    local who = {}
    for n in pairs(run.deaths) do who[#who + 1] = n end
    table.sort(who, function(a, b) if run.deaths[a] ~= run.deaths[b] then return run.deaths[a] > run.deaths[b] end return a < b end)
    for _, n in ipairs(who) do total = total + run.deaths[n] parts[#parts + 1] = n .. " " .. run.deaths[n] end
    lines[#lines + 1] = total == 0 and T("Tode: keine – sauber!") or T("Tode: %d (%s)", total, table.concat(parts, ", "))
    if #run.loot > 0 then
        local l = {}
        for i, e in ipairs(run.loot) do
            if i > self.maxLoot then l[#l + 1] = T("… und %d mehr", #run.loot - self.maxLoot) break end
            l[#l + 1] = e.link .. " – " .. e.who
        end
        lines[#lines + 1] = T("Beute:") .. "\n  " .. table.concat(l, "\n  ")
    end
    return lines
end

function R:Title(run)
    local t = T("%s – %d Min.", run.name, Minutes(run.secs))
    if run.record then t = t .. " |cff40ff40" .. T("(neue Bestzeit!)") .. "|r" end
    return t
end

-- Eine Zeile fuer den Gildenchat (ohne Farbcodes ausser Gegenstandslinks)
function R:ChatLine(run)
    local deaths = 0
    for _, d in pairs(run.deaths) do deaths = deaths + d end
    local line = T("Guild Trip: %s in %d Min. – %d Bosse, %d Tode", run.name, Minutes(run.secs), #run.bosses, deaths)
    if run.record then line = line .. " " .. T("(neue Bestzeit!)") end
    local links = {}
    for i, e in ipairs(run.loot) do
        if i > 3 then break end
        links[#links + 1] = e.link
    end
    if #links > 0 then line = line .. " – " .. T("Beute: %s", table.concat(links, " ")) end
    return line
end


-- Fenster im Blizzard-Aussehen, Texte in Theme-Farben
local function Ink(text) return text end
local function Themed(frame, bg, title, texts)
    local th = ONE.Themes
    if not th then return end
    if th.RegisterWindow then pcall(th.RegisterWindow, th, frame, bg, title) end
    for fs, role in pairs(texts or {}) do if th.RegisterText then pcall(th.RegisterText, th, fs, role) end end
end

-- ===== Karte =====
local function Button(parent, label, width)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(width, 22)
    b:SetText(label)
    return b
end

function R:Frame()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "GuildTripDungeonRecap", UIParent)
    f:SetSize(380, 220)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.SetMovable then f:SetMovable(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then bg:SetColorTexture(.1, .07, .03, .94) end
    f.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
    f.head:SetText(T("Dungeon-Rückblick"))
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -24)
    f.title:SetWidth(356)
    if f.title.SetJustifyH then f.title:SetJustifyH("LEFT") end
    f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -50)
    f.body:SetWidth(356)
    if f.body.SetJustifyH then f.body:SetJustifyH("LEFT") end
    if f.body.SetSpacing then f.body:SetSpacing(3) end
    f.post = Button(f, T("In den Gildenchat"), 140)
    f.post:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    f.close = Button(f, T("Schließen"), 90)
    f.close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    f.post:SetScript("OnClick", function() R:Post() end)
    f.close:SetScript("OnClick", function() f:Hide() end)
    Themed(f, bg, f.title, {[f.head] = "soft", [f.body] = "text"})
    f:Hide()
    self.frame = f
    return f
end

function R:Show(run)
    local f = self:Frame()
    self.shown = run
    f.title:SetText(Ink(self:Title(run)))
    local lines = self:Lines(run)
    f.body:SetText(Ink(table.concat(lines, "\n")))
    -- Hoehe nach Inhalt (Beute kann mehrere Zeilen haben)
    local count = #lines + #run.loot
    f:SetHeight(math.max(160, 100 + count * 16))
    f:Show()
end

function R:Post()
    local run = self.shown
    if not (run and Call(G("IsInGuild"))) then return false end
    Call(G("SendChatMessage"), self:ChatLine(run), "GUILD")
    if self.frame then self.frame:Hide() end
    return true
end

-- ===== Ereignisse =====
function R:OnEnteringWorld()
    local inside, kind = Call(G("IsInInstance"))
    if inside and kind == "party" then
        local name = Call(G("GetInstanceInfo"))
        local E = dungeons.Entrances
        local d = E and E.Match and (E.Match(name) or {})[1]
        local key = d and d.key or name
        if not key then return end
        -- Neu laden im selben Dungeon: Lauf geht weiter
        if self.run and self.run.key == key then return end
        -- direkt aus einem anderen Dungeon hierher (z. B. beschworen): alten Lauf erst abschliessen
        if self.run then self:Finish() end
        self:Start(key, name)
    elseif self.run then
        self:Finish()
    end
end

function R:Initialize()
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"PLAYER_ENTERING_WORLD", "CHAT_MSG_LOOT", "ENCOUNTER_END", "GROUP_ROSTER_UPDATE"}) do
        pcall(f.RegisterEvent, f, ev)
    end
    f:SetScript("OnEvent", function(_, event, a, b, c, d, e)
        if event == "PLAYER_ENTERING_WORLD" then R:OnEnteringWorld()
        elseif event == "CHAT_MSG_LOOT" then R:OnLoot(a, b)
        elseif event == "ENCOUNTER_END" then R:OnBoss(b, e == 1 or e == true)
        elseif event == "GROUP_ROSTER_UPDATE" then R:Roster() end
    end)
    self.events = f
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(2, function() if R.run then R:CheckDeaths() end end)
    end
end
