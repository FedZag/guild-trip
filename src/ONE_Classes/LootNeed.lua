-- Guild Trip: Wer braucht die Beute? (0.7.0)
-- Faellt in der Gruppe Ausruestung (Wuerfeln oder Beutefenster), rechnet JEDER
-- Guild-Trip-Spieler fuer sich aus, ob es ein Upgrade ist (Ausruestung bewerten,
-- Gear:UpgradePercent), und meldet das der Gruppe. Ergebnis:
--  * kleines Fenster "Wer braucht die Beute?": Gegenstand + "Bob +12 %, Gildi: Platz frei"
--  * Zeile im Gegenstands-Tooltip: "Guild Trip: Upgrade für Bob (+12 %), Gildi (+4 %)"
-- Nachrichten (Praefix ONELOOT1, Gruppe/Schlachtzug):
--   A|itemID           "Wer braucht das?" (vom Pluenderer, Beutefenster)
--   U|itemID|prozent   "Fuer mich ein Upgrade" (100 = Platz frei)
-- Fremde ohne Guild Trip tauchen nicht auf – deren Ausruestung kennt niemand.
local _, classes = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local L = {prefix = "ONELOOT1", keep = 300, showFor = 45, minQuality = 2, needs = {}, asked = {}, answered = {}}
classes.LootNeed = L

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end
local function Clock() return type(GetTime) == "function" and GetTime() or 0 end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function Me() return Short(Call(rawget(_G, "UnitName"), "player")) end
local function After(sec, fn) if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end end
local function FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("classes.lootNeed") end
local function ItemID(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or tonumber(link) end

local function Channel()
    if Call(rawget(_G, "IsInRaid")) then return "RAID" end
    if Call(rawget(_G, "IsInGroup")) then return "PARTY" end
end

function L:Send(msg)
    local ch = Channel()
    if not (ch and C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    Call(C_ChatInfo.SendAddonMessage, self.prefix, msg, ch)
    return true
end

-- Eintrag merken: needs[itemID] = {at, link, who = {Name -> Prozent}}
function L:Note(itemID, name, pct, link)
    if not itemID or not name or type(pct) ~= "number" or pct <= 0 then return end
    local e = self.needs[itemID] or {who = {}}
    self.needs[itemID] = e
    e.at = Clock()
    e.link = link or e.link
    e.who[name] = pct
    self:Changed(itemID)
end

-- Eigene Bewertung; noch nicht geladene Gegenstaende ein paar Mal neu versuchen.
function L:Answer(itemID, link, tries)
    if not FeatureOn() or not itemID then return end
    local now = Clock()
    if (self.answered[itemID] or -1000) > now - 30 then return end
    local pct = classes.Gear and classes.Gear.UpgradePercent and classes.Gear:UpgradePercent(itemID)
    if pct == nil and (tries or 0) < 3 then
        After(1, function() L:Answer(itemID, link, (tries or 0) + 1) end)
        return
    end
    self.answered[itemID] = now
    if pct and pct > 0 then
        self:Note(itemID, Me(), pct, link)
        self:Send("U|" .. itemID .. "|" .. pct)
    end
end

-- Gegenstand ist aufgetaucht (Wuerfeln: jeder sieht ihn; Beutefenster: nur der Pluenderer fragt)
function L:Seen(link, ask)
    local itemID = ItemID(link)
    if not itemID or not Channel() then return end
    self.needs[itemID] = self.needs[itemID] or {who = {}, at = Clock()}
    self.needs[itemID].link = link
    if ask and (self.asked[itemID] or -1000) < Clock() - 30 then
        self.asked[itemID] = Clock()
        self:Send("A|" .. itemID)
    end
    self:Answer(itemID, link)
end

function L:Receive(prefix, msg, _, sender)
    if prefix ~= self.prefix or type(msg) ~= "string" or #msg > 60 then return end
    local name = Short(sender)
    if name == Me() then return end
    local kind, id, pct = msg:match("^(%a)|(%d+)|?(%d*)$")
    id = tonumber(id)
    if not id then return end
    if kind == "A" then
        After(.5 + (math.random and math.random() or .5), function() L:Answer(id) end)
    elseif kind == "U" then
        pct = tonumber(pct)
        if pct and pct > 0 and pct <= 1000 then self:Note(id, name, pct) end
    end
end

-- Wer braucht es? Liste {name, pct}, beste zuerst
function L:Who(itemID)
    local e = self.needs[itemID]
    if not e or Clock() - (e.at or 0) > self.keep then return {} end
    local out = {}
    for name, pct in pairs(e.who) do out[#out + 1] = {name = name, pct = pct} end
    table.sort(out, function(a, b) if a.pct ~= b.pct then return a.pct > b.pct end return a.name < b.name end)
    return out
end

function L:WhoText(itemID)
    local parts = {}
    for _, w in ipairs(self:Who(itemID)) do
        parts[#parts + 1] = w.pct >= 100 and T("%s (Platz frei)", w.name) or T("%s (+%d %%)", w.name, w.pct)
    end
    return table.concat(parts, ", "), #parts
end


-- Fenster im aktiven Aussehen (Blizzard-Rahmen bzw. Pergamentblatt im Buch) und Texte in Theme-Farben
-- Im Buch-Aussehen: helle Farbcodes als lesbare Tinte auf Pergament
local function Ink(text)
    local book = ONE.Book
    if book and book.IsActive and book:IsActive() and book.InkCodes then return book.InkCodes(text) end
    return text
end
local function Themed(frame, bg, title, texts)
    local th = ONE.Themes
    if not th then return end
    if th.RegisterWindow then pcall(th.RegisterWindow, th, frame, bg, title) end
    for fs, role in pairs(texts or {}) do if th.RegisterText then pcall(th.RegisterText, th, fs, role) end end
end

-- ===== Fenster =====
function L:Frame()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "GuildTripLootNeed", UIParent)
    f:SetSize(300, 30)
    f:SetPoint("TOP", UIParent, "TOP", 0, -220)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.SetMovable then f:SetMovable(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then bg:SetColorTexture(0, 0, 0, .8) end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    f.title:SetText(T("Wer braucht die Beute?"))
    local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
    if not ok or not close then close = CreateFrame("Button", nil, f) end
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)
    f.lines = {}
    Themed(f, bg, f.title)
    f:Hide()
    self.frame = f
    return f
end

-- Fenster neu fuellen: alle frischen Gegenstaende mit mindestens einem Interessenten
function L:Refresh()
    local items = {}
    local now = Clock()
    for id, e in pairs(self.needs) do
        if now - (e.at or 0) <= self.showFor and next(e.who) then items[#items + 1] = id end
    end
    table.sort(items, function(a, b) return (self.needs[a].at or 0) > (self.needs[b].at or 0) end)
    local f = self:Frame()
    local n = math.min(#items, 4)
    for i = 1, n do
        local id = items[i]
        local line = f.lines[i]
        if not line then
            line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetWidth(284)
            if line.SetJustifyH then line:SetJustifyH("LEFT") end
            if ONE.Themes and ONE.Themes.RegisterText then pcall(ONE.Themes.RegisterText, ONE.Themes, line, "text") end
            f.lines[i] = line
        end
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26 - (i - 1) * 30)
        local name = self.needs[id].link
        if not (type(name) == "string" and name:find("|H")) then name = Call(rawget(_G, "GetItemInfo"), id) or ("#" .. id) end
        line:SetText(Ink(name .. "\n|cff40ff40" .. self:WhoText(id) .. "|r"))
        line:Show()
    end
    for i = n + 1, #f.lines do f.lines[i]:Hide() end
    f:SetHeight(30 + n * 30)
    if n > 0 then f:Show() else f:Hide() end
    return items
end

function L:Changed()
    if self.pending then return end
    self.pending = true
    After(.5, function() L.pending = nil L:Refresh() end)
end

-- Tooltip-Zeile (aus Gear:OnTooltip)
function L:TooltipLine(itemID)
    if not FeatureOn() then return nil end
    local text, n = self:WhoText(itemID)
    if n == 0 then return nil end
    return "|cff40ff40" .. T("Guild Trip: Upgrade für %s", text) .. "|r"
end

function L:Initialize()
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        Call(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    end
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"CHAT_MSG_ADDON", "START_LOOT_ROLL", "LOOT_OPENED"}) do pcall(f.RegisterEvent, f, ev) end
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then L:Receive(...) return end
        if not FeatureOn() then return end
        if event == "START_LOOT_ROLL" then
            local rollID = ...
            L:Seen(Call(rawget(_G, "GetLootRollItemLink"), rollID), false)
        elseif event == "LOOT_OPENED" then
            for i = 1, Call(rawget(_G, "GetNumLootItems")) or 0 do
                local link = Call(rawget(_G, "GetLootSlotLink"), i)
                local _, _, _, _, quality = Call(rawget(_G, "GetLootSlotInfo"), i)
                if link and (quality or 0) >= L.minQuality then L:Seen(link, true) end
            end
        end
    end)
    self.events = f
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(5, function() if L.frame and L.frame:IsShown() then L:Refresh() end end)
    end
end
