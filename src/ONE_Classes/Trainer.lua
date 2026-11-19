local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Lern-Reihenfolge beim Klassenlehrer.
-- Liest die angebotenen Zauber, sortiert sie nach dem Bauplan der aktuellen
-- Ausrichtung (1. Leiste 1 Kampf, 2. Leiste 2 Notfall/Heilung, 3. Leiste 3
-- Hilfe, 4. alles andere = optional), rechnet mit dem eigenen Gold und zeigt
-- eine kleine Liste neben dem Lehrerfenster. "Empfohlene lernen" kauft nach
-- Rueckfrage genau die empfohlenen, so weit das Gold reicht. Nie automatisch.
local Trainer = {maxRows = 12, delay = .4}
classes.Trainer = Trainer

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    return ONE.db.classGuide
end

-- Das Lehrerfenster filtert (verfuegbar / nicht verfuegbar / bekannt); dann
-- zaehlt GetNumTrainerServices nur Sichtbares und die Nummern verschieben sich.
-- Zum Lesen und Kaufen kurz alles zeigen, danach den Filter zurueckstellen.
local FILTERS = {"available", "unavailable", "used"}
function Trainer:WithAllFilters(fn)
    local get, set = _G.GetTrainerServiceTypeFilter, _G.SetTrainerServiceTypeFilter
    if type(get) ~= "function" or type(set) ~= "function" then return fn() end
    local saved = {}
    for _, t in ipairs(FILTERS) do
        local ok, v = pcall(get, t)
        saved[t] = ok and v
        if ok and not v then pcall(set, t, 1) end
    end
    local result = {pcall(fn)}
    for _, t in ipairs(FILTERS) do
        if saved[t] ~= nil and not saved[t] then pcall(set, t, 0) end
    end
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2)
end

-- Alle lernbaren Angebote: {index, name, rank, cost, level, kind}
function Trainer:Services()
    return self:WithAllFilters(function()
        local list = {}
        local n = tonumber((Call(GetNumTrainerServices))) or 0
        for i = 1, math.min(n, 200) do
            local name, rank, kind = Call(GetTrainerServiceInfo, i)
            if type(name) == "string" and kind ~= "header" then
                list[#list + 1] = {index = i, name = name, rank = rank, kind = kind,
                    cost = tonumber((Call(GetTrainerServiceCost, i))) or 0,
                    level = tonumber((Call(GetTrainerServiceLevelReq, i))) or 0}
            end
        end
        return list
    end)
end

-- Rangfolge je Zaubername aus dem Bauplan: Leiste 1 > 2 > 3, darin nach Platz.
function Trainer:PlanOrder(build)
    local order = {}
    for _, bar in ipairs(classes.Data.AllBars(build)) do
        for pos, step in ipairs(bar.slots) do
            for _, id in ipairs(classes.Data.Ids(step[1])) do
                local name = classes.Player.SpellInfo(id)
                if name and not order[name] then order[name] = {tier = bar.bar, pos = pos} end
            end
        end
    end
    return order
end

-- Was kommt spaeter? Beim Klassenlehrer stehen auch noch nicht lernbare Zauber mit
-- ihrer Stufe (Filter "nicht verfuegbar"). Die merken wir uns je Charakter fuer die
-- Klassen-Seite ("Ab Stufe 18: Erneuerung (Rang 3), ..."). Eingeplante zuerst.
function Trainer:Remember(services, p, order)
    local list = {}
    for _, s in ipairs(services) do
        if s.kind == "unavailable" and (s.level or 0) > (p.level or 0) then
            local o = order[s.name]
            list[#list + 1] = {name = s.name, rank = s.rank, level = s.level, planned = o ~= nil,
                tier = o and o.tier or 4, pos = o and o.pos or 99}
        end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.pos ~= b.pos then return a.pos < b.pos end
        return a.name < b.name
    end)
    while #list > 80 do table.remove(list) end
    local me = Call(UnitName, "player") or "?"
    local store = Store()
    store.upcoming = type(store.upcoming) == "table" and store.upcoming or {}
    store.upcoming[me] = {class = p.classFile, list = list}
    -- Zusaetzlich je KLASSE alle Angebote mit Stufe (auch schon gelernte): gilt fuer alle
    -- Charaktere dieser Klasse und wandert ins Startpaket (build_pack.lua)
    if p.classFile then
        store.classSpells = type(store.classSpells) == "table" and store.classSpells or {}
        local cs = store.classSpells[p.classFile] or {}
        store.classSpells[p.classFile] = cs
        for _, s in ipairs(services) do
            if (s.level or 0) > 0 and s.name then cs[s.name .. "|" .. (s.rank or "")] = s.level end
        end
    end
    return list
end

-- Klassenweite Liste (eigene Lehrerbesuche + Startpaket): {name, rank, level}
function Trainer:ClassSpells(classFile)
    local merged = {}
    for _, src in ipairs({(classes.TrainerSpellPack or {})[classFile or ""] or {},
        (Store().classSpells or {})[classFile or ""] or {}}) do
        for key, level in pairs(src) do merged[key] = level end
    end
    local out = {}
    for key, level in pairs(merged) do
        local name, rank = key:match("^(.-)|(.*)$")
        if name then out[#out + 1] = {name = name, rank = rank ~= "" and rank or nil, level = level} end
    end
    return out
end

-- Fuer die Klassen-Seite: jetzt lernbar (Stufe erreicht, seit dem letzten Besuch)
-- und die naechste Stufe mit ihren Zaubern. Rueckgabe: now, nextLevel, nextList, all
function Trainer:Upcoming(p)
    local me = Call(UnitName, "player") or "?"
    local u = Store().upcoming and Store().upcoming[me]
    if not (u and u.class == p.classFile and type(u.list) == "table") then
        -- kein eigener Besuch mit diesem Charakter: klassenweite Liste (andere eigene
        -- Charaktere oder Startpaket) – nur kuenftige Stufen, "jetzt" ist unbekannt
        local list = {}
        local def = classes.Data.classes and classes.Data.classes[p.classFile or ""]
        local build = def and classes.Data.Build and classes.Data:Build(def, p.spec, p.situation)
        local order = build and self:PlanOrder(build) or {}
        for _, s in ipairs(self:ClassSpells(p.classFile)) do
            if s.level > (p.level or 0) then
                local o = order[s.name]
                s.planned, s.tier, s.pos = o ~= nil, o and o.tier or 4, o and o.pos or 99
                list[#list + 1] = s
            end
        end
        if #list == 0 then return nil end
        table.sort(list, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            if a.tier ~= b.tier then return a.tier < b.tier end
            if a.pos ~= b.pos then return a.pos < b.pos end
            return a.name < b.name
        end)
        u = {list = list}
    end
    local now, nextLevel, nextList = {}, nil, {}
    for _, s in ipairs(u.list) do
        if s.level <= (p.level or 0) then now[#now + 1] = s
        elseif not nextLevel or s.level == nextLevel then nextLevel = s.level nextList[#nextList + 1] = s end
    end
    return now, nextLevel, nextList, u.list
end
function Trainer.Names(list, max)
    local parts = {}
    for i, s in ipairs(list) do
        if i > max then parts[#parts + 1] = "+" .. (#list - max) break end
        local rank = (type(s.rank) == "string" and s.rank ~= "") and (" (" .. s.rank .. ")") or ""
        parts[#parts + 1] = s.name .. rank
    end
    return table.concat(parts, ", ")
end

-- Empfehlung: nur "available"; sortiert; mit Gold verrechnet.
-- Rueckgabe: list (mit tier, recommended, affordable), money, isClassTrainer
function Trainer:Plan()
    local store = Store()
    local p = classes.Player:Read(store.spec)
    local def = classes.Data.classes[p.classFile or ""]
    local build = def and classes.Data:Build(def, p.spec, p.situation)
    local order = self:PlanOrder(build)
    local services = self:Services()
    -- Klassenlehrer? Mindestens ein Angebot gehoert zur eigenen Klasse.
    local isClass = false
    for _, s in ipairs(services) do
        if order[s.name] or (p.known[s.name] and (p.known[s.name].tab or 0) >= 2) then isClass = true break end
    end
    if isClass then self:Remember(services, p, order) end
    local list = {}
    for _, s in ipairs(services) do
        if s.kind == "available" then
            local o = order[s.name]
            s.tier = o and o.tier or 4
            s.pos = o and o.pos or 99
            s.recommended = o ~= nil
            list[#list + 1] = s
        end
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.pos ~= b.pos then return a.pos < b.pos end
        return a.index < b.index
    end)
    local money = tonumber((Call(GetMoney))) or 0
    local left = money
    for _, s in ipairs(list) do
        if s.recommended and s.cost <= left then
            s.affordable = true
            left = left - s.cost
        end
    end
    return list, money, isClass
end

function Trainer.Money(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if type(GetCoinTextureString) == "function" then
        local ok, text = pcall(GetCoinTextureString, copper)
        if ok and type(text) == "string" then return text end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 or g > 0 then parts[#parts + 1] = s .. "s" end
    parts[#parts + 1] = c .. "c"
    return table.concat(parts, " ")
end

-- ===== Anzeige neben dem Lehrerfenster =====
function Trainer:Frame()
    if self.frame then return self.frame end
    -- Im Glas-Aussehen ohne Blizzard-Holzrahmen: Glasfenster wie Fehlerbericht/Beute (Nutzer 19.11.2026)
    local glass = ONE.Glass and ONE.Glass.Active and ONE.Glass:Active() and ONE.Themes and ONE.Themes.RegisterWindow
    local ok, f = false, nil
    if not glass then ok, f = pcall(CreateFrame, "Frame", "GuildTripTrainerAdvice", UIParent, "BasicFrameTemplateWithInset") end
    if not ok or not f then f = CreateFrame("Frame", "GuildTripTrainerAdvice", UIParent) end
    f:SetSize(300, 90 + self.maxRows * 16)
    if f.SetFrameStrata then f:SetFrameStrata("HIGH") end
    local title = rawget(f, "TitleText")
    if glass or type(title) ~= "table" then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
    end
    title:SetText(T("Guild Trip: Lern-Reihenfolge"))
    f.rows = {}
    for i = 1, self.maxRows do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -30 - (i - 1) * 16)
        fs:SetWidth(272)
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        f.rows[i] = fs
    end
    f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.summary:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 40)
    f.summary:SetWidth(272)
    f.summary:SetJustifyH("LEFT")
    local buy
    if ONE.Widgets and ONE.Widgets.Button then
        buy = ONE.Widgets:Button(f, "Empfohlene lernen", 160, 24, "BOTTOMLEFT", 12, 10, function() Trainer:AskAndBuy() end)
    else
        buy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        buy:SetSize(160, 24); buy:SetPoint("BOTTOMLEFT", 12, 10); buy:SetText(T("Empfohlene lernen"))
        buy:SetScript("OnClick", function() Trainer:AskAndBuy() end)
    end
    f.buy = buy
    if glass then
        ONE.Themes:RegisterWindow(f, nil, title)
        if ONE.Widgets and ONE.Widgets.CloseButton then ONE.Widgets:CloseButton(f, "TOPRIGHT", -6, -6, function() f:Hide() end) end
        if ONE.Themes.StyleTree then ONE.Themes:StyleTree(f) end
    end
    f:Hide()
    self.frame = f
    return f
end

function Trainer:Anchor(f)
    f:ClearAllPoints()
    local blizz = _G.ClassTrainerFrame
    if type(blizz) == "table" and blizz.IsShown and blizz:IsShown() then
        f:SetPoint("TOPLEFT", blizz, "TOPRIGHT", 4, 0)
    else
        f:SetPoint("LEFT", UIParent, "CENTER", 220, 0)
    end
end

function Trainer:Refresh()
    if Store().trainerAdvice == false then if self.frame then self.frame:Hide() end return end
    local list, money, isClass = self:Plan()
    if not isClass then if self.frame then self.frame:Hide() end return end
    local f = self:Frame()
    self:Anchor(f)
    local count, total = 0, 0
    for _, s in ipairs(list) do if s.affordable then count, total = count + 1, total + s.cost end end
    local missing = 0
    for _, s in ipairs(list) do if s.recommended and not s.affordable then missing = missing + 1 end end
    for i, fs in ipairs(f.rows) do
        local s = list[i]
        if s then
            local color = s.affordable and "|cff80e680" or (s.recommended and "|cffffd100" or "|cff9d9d9d")
            local rank = (type(s.rank) == "string" and s.rank ~= "") and (" (" .. s.rank .. ")") or ""
            local tag = s.recommended and "" or (" · " .. T("optional"))
            fs:SetText(("%s%d  %s%s|r  %s%s"):format(color, i, s.name, rank, Trainer.Money(s.cost), tag))
        else
            fs:SetText(i == 1 and T("Hier gibt es gerade nichts Neues zu lernen.") or "")
        end
    end
    f.summary:SetText(T("Empfohlen: %d Zauber für %s – du hast %s", count, Trainer.Money(total), Trainer.Money(money))
        .. (missing > 0 and ("\n|cffffd100" .. T("%d weitere empfohlen, dafür reicht das Gold noch nicht.", missing) .. "|r") or ""))
    if count > 0 then f.buy:Show() else f.buy:Hide() end
    self.list = list
    f:Show()
    return list
end

-- Kaufen: Rueckfrage, dann nacheinander (Nummern jedes Mal neu suchen).
function Trainer:AskAndBuy()
    local list = self:Plan()
    local queue = {}
    for _, s in ipairs(list) do if s.affordable then queue[#queue + 1] = {name = s.name, rank = s.rank} end end
    if #queue == 0 then ONE:Print(T("Gerade gibt es nichts Empfohlenes zu lernen.")) return false end
    local total = 0
    for _, s in ipairs(list) do if s.affordable then total = total + s.cost end end
    classes.Bars:Confirm(T("%d empfohlene Zauber für %s lernen?", #queue, Trainer.Money(total)), function()
        self:BuyQueue(queue)
    end)
    return true
end

function Trainer:BuyQueue(queue)
    local i, bought = 0, 0
    local function Step()
        i = i + 1
        local want = queue[i]
        if not want then
            ONE:Print(T("%d Zauber gelernt.", bought))
            Trainer:Refresh()
            return
        end
        local done = self:WithAllFilters(function()
            for _, s in ipairs(self:Services()) do
                if s.name == want.name and s.rank == want.rank and s.kind == "available" then
                    Call(BuyTrainerService, s.index)
                    return true
                end
            end
            return false
        end)
        if done then bought = bought + 1 end
        if C_Timer and C_Timer.After then C_Timer.After(self.delay, Step) else Step() end
    end
    Step()
end

function Trainer:Initialize()
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "PLAYER_MONEY"}) do
        pcall(f.RegisterEvent, f, ev)
    end
    local pending = false
    f:SetScript("OnEvent", function(_, event)
        if event == "TRAINER_CLOSED" then
            if Trainer.frame then Trainer.frame:Hide() end
            return
        end
        if event == "PLAYER_MONEY" and not (Trainer.frame and Trainer.frame:IsShown()) then return end
        if pending then return end
        pending = true
        local function Go() pending = false pcall(Trainer.Refresh, Trainer) end
        if C_Timer and C_Timer.After then C_Timer.After(.2, Go) else Go() end
    end)
    self.events = f
end
