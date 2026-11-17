-- Guild Trip: Gilden-Auftragsbrett (0.7.0).
-- Kleine Gesuche an die Gilde: "Brauche 10 Leinenstoff", "Wer hilft bei der
-- Elite-Quest?", "Suche Verzauberer fuer Umhang".
--  * Einstellen: /trip auftrag <Text> oder im Fenster (/trip auftrag ohne Text).
--  * Die Gilde sieht es unter "Was steht an" und im Fenster; "Ich helfe" meldet
--    sich beim Auftraggeber (und oeffnet das Fluestern), "Erledigt" nimmt es raus.
--  * Hoechstens 3 offene eigene Auftraege, je 80 Zeichen, nach 3 Tagen weg.
--  * Nur ueber den Gilden-Addon-Kanal. Jeder schickt nur seine EIGENEN Auftraege
--    (beim Einloggen und auf Nachfrage); fremde werden bis zum Ablauf gemerkt.
-- Nachrichten (Praefix ONEBRD1, Gilde):
--   B|id|zeit|text   Auftrag (zeit = Serverzeit beim Einstellen)
--   BX|id            Auftrag erledigt/zurueckgezogen
--   BH|id            "Ich helfe" (an den Auftraggeber)
--   BREQ             "Bitte schickt eure Auftraege"
local _, guild = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Board = {prefix = "ONEBRD1", maxOwn = 3, maxLen = 80, life = 3 * 86400, rows = 8}
guild.Board = Board

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function Now()
    return Call(rawget(_G, "GetServerTime")) or (os and os.time and os.time()) or 0
end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function After(sec, fn) if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end end
local function FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("guild.board") end
local function Me() return Short(Call(rawget(_G, "UnitName"), "player")) end

local function Clean(text)
    text = type(text) == "string" and (text:gsub("[|\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")) or ""
    if #text > Board.maxLen then text = text:sub(1, Board.maxLen) end
    return text
end

function Board:Store()
    ONE.db.guild = type(ONE.db.guild) == "table" and ONE.db.guild or {}
    local s = type(ONE.db.guild.board) == "table" and ONE.db.guild.board or {}
    ONE.db.guild.board = s
    s.mine = type(s.mine) == "table" and s.mine or {}
    s.others = type(s.others) == "table" and s.others or {}
    s.nextId = tonumber(s.nextId) or 1
    return s
end

function Board:Send(msg)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    if not Call(rawget(_G, "IsInGuild")) then return false end
    Call(C_ChatInfo.SendAddonMessage, self.prefix, msg, "GUILD")
    return true
end

-- Abgelaufenes wegraeumen
function Board:Prune()
    local s, now = self:Store(), Now()
    for id, e in pairs(s.mine) do if now - (e.at or 0) > self.life then s.mine[id] = nil end end
    for owner, list in pairs(s.others) do
        for id, e in pairs(list) do if now - (e.at or 0) > self.life then list[id] = nil end end
        if not next(list) then s.others[owner] = nil end
    end
end

-- Alle offenen Auftraege: {owner, id, text, at, mine}; neueste zuerst
function Board:List()
    self:Prune()
    local s, out, me = self:Store(), {}, Me()
    for id, e in pairs(s.mine) do out[#out + 1] = {owner = me, id = id, text = e.text, at = e.at, mine = true, helpers = e.helpers} end
    for owner, list in pairs(s.others) do
        for id, e in pairs(list) do out[#out + 1] = {owner = owner, full = e.full, id = id, text = e.text, at = e.at} end
    end
    table.sort(out, function(a, b) if a.at ~= b.at then return a.at > b.at end return a.owner < b.owner end)
    return out
end

-- ===== Eigene Auftraege =====
function Board:Post(text)
    text = Clean(text)
    if text == "" then return nil, "empty" end
    if not Call(rawget(_G, "IsInGuild")) then ONE:Print(T("Das Auftragsbrett gibt es nur in einer Gilde.")) return nil, "guild" end
    local s = self:Store()
    self:Prune()
    local n = 0
    for _ in pairs(s.mine) do n = n + 1 end
    if n >= self.maxOwn then ONE:Print(T("Du hast schon %d offene Aufträge – erledige erst einen.", self.maxOwn)) return nil, "full" end
    local id = s.nextId
    s.nextId = id + 1
    s.mine[id] = {text = text, at = Now()}
    self:SendOne(id)
    ONE:Print(T("Auftrag eingestellt: %s", text))
    self:Changed()
    return id
end

function Board:SendOne(id)
    local e = self:Store().mine[id]
    if e then self:Send(("B|%d|%d|%s"):format(id, e.at, e.text)) end
end

function Board:Done(id)
    local s = self:Store()
    if not s.mine[id] then return false end
    s.mine[id] = nil
    self:Send("BX|" .. id)
    self:Changed()
    return true
end

-- "Ich helfe": dem Auftraggeber Bescheid geben und Fluestern oeffnen
function Board:Help(entry)
    if not entry or entry.mine then return false end
    self:Send("BH|" .. entry.id .. "|" .. entry.owner)
    if type(ChatFrame_OpenChat) == "function" then
        Call(ChatFrame_OpenChat, "/w " .. (entry.full or entry.owner) .. " " .. T("Ich helfe dir: %s", entry.text))
    end
    return true
end

-- ===== Empfangen =====
function Board:Receive(prefix, msg, channel, sender)
    if prefix ~= self.prefix or channel ~= "GUILD" or type(msg) ~= "string" or #msg > 200 then return end
    local owner = Short(sender)
    if owner == Me() then return end
    local s = self:Store()
    if msg == "BREQ" then
        After(1 + (math.random and math.random() * 4 or 2), function() Board:SendMine() end)
        return
    end
    local kind, id, rest = msg:match("^(B%a?)|(%d+)|?(.*)$")
    id = tonumber(id)
    if not id then return end
    if kind == "B" then
        local at, text = rest:match("^(%d+)|(.*)$")
        at, text = tonumber(at), Clean(text)
        if not at or text == "" or Now() - at > self.life then return end
        s.others[owner] = s.others[owner] or {}
        local fresh = not s.others[owner][id]
        s.others[owner][id] = {text = text, at = at, full = sender}
        if fresh and FeatureOn() and Now() - at < 600 then
            ONE:Notify(T("Auftrag von %s: %s", owner, text), {source = T("Auftragsbrett"), toast = false, silent = true})
        end
    elseif kind == "BX" then
        if s.others[owner] then s.others[owner][id] = nil end
    elseif kind == "BH" then
        -- jemand hilft – nur wenn es MEIN Auftrag ist
        local e = rest == Me() and s.mine[id]
        if not e then return end
        e.helpers = e.helpers or {}
        if e.helpers[owner] then return end
        e.helpers[owner] = true
        ONE:Notify(T("%s will dir helfen: %s", owner, e.text), {source = T("Auftragsbrett"), sound = "notify"})
    else
        return
    end
    self:Changed()
end

function Board:SendMine()
    self:Prune()
    for id in pairs(self:Store().mine) do self:SendOne(id) end
end

-- ===== "Was steht an" =====
function Board:Feed()
    if not FeatureOn() then return {} end
    local out = {}
    local guildMod = ONE.modules and ONE.modules.guild
    for _, e in ipairs(self:List()) do
        local item = {icon = "Interface\\Icons\\INV_Misc_Note_01", sort = e.mine and 30 or 12,
            text = e.mine and T("Dein Auftrag: %s", e.text) or T("%s sucht: %s", e.owner, e.text),
            open = function() Board:Open() end}
        local peer = not e.mine and guildMod and guildMod.GetPeer and guildMod:GetPeer(e.full or e.owner)
        if peer then
            item.navi = function() local nav = ONE.modules.nav if nav and nav.StartTo then nav:StartTo(peer.name) end end
            item.naviTip = T("Navi zu %s", e.owner)
        end
        out[#out + 1] = item
    end
    return out
end

-- ===== Fenster =====
local function Button(parent, label, width)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(width, 20)
    b:SetText(label)
    return b
end

local function Age(at)
    local d = math.max(0, Now() - (at or 0))
    if d < 3600 then return T("vor %d Min.", math.max(1, math.floor(d / 60))) end
    if d < 86400 then return T("vor %d Std.", math.floor(d / 3600)) end
    return T("vor %d Tagen", math.floor(d / 86400))
end
Board.Age = Age

function Board:Frame()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "GuildTripBoard", UIParent)
    f:SetSize(380, 90 + self.rows * 24)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.SetMovable then f:SetMovable(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then bg:SetColorTexture(.08, .06, .03, .92) end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.title:SetText(T("Auftragsbrett der Gilde"))
    local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
    if not ok or not close then close = CreateFrame("Button", nil, f) end
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)
    -- Eingabe
    local okE, edit = pcall(CreateFrame, "EditBox", nil, f, "InputBoxTemplate")
    if not okE or not edit then edit = CreateFrame("EditBox", nil, f) end
    edit:SetSize(270, 20)
    edit:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
    if edit.SetAutoFocus then edit:SetAutoFocus(false) end
    if edit.SetMaxLetters then edit:SetMaxLetters(self.maxLen) end
    f.edit = edit
    f.post = Button(f, T("Einstellen"), 80)
    f.post:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    local function PostNow()
        if Board:Post(edit:GetText()) then edit:SetText("") if edit.ClearFocus then edit:ClearFocus() end end
    end
    f.post:SetScript("OnClick", PostNow)
    edit:SetScript("OnEnterPressed", PostNow)
    edit:SetScript("OnEscapePressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -58)
    f.hint:SetText(T("z. B. „Brauche 10 Leinenstoff“ oder „Wer hilft bei der Elite-Quest?“"))
    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -84)
    f.empty:SetText(T("Noch keine Aufträge – stell den ersten ein!"))
    f.rows = {}
    for i = 1, self.rows do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(356, 22)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -78 - (i - 1) * 24)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.text:SetWidth(266)
        if row.text.SetJustifyH then row.text:SetJustifyH("LEFT") end
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end
        row.action = Button(row, "", 86)
        row.action:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.action:SetScript("OnClick", function(self)
            local e = self:GetParent().entry
            if not e then return end
            if e.mine then Board:Done(e.id) else Board:Help(e) end
        end)
        f.rows[i] = row
    end
    f:Hide()
    self.frame = f
    return f
end

function Board:Refresh()
    local f = self.frame
    if not f then return end
    local list = self:List()
    for i, row in ipairs(f.rows) do
        local e = list[i]
        row.entry = e
        if e then
            local who = e.mine and ("|cff66ccff" .. T("Du") .. "|r") or ("|cffffd100" .. e.owner .. "|r")
            local helpers = 0
            for _ in pairs(e.helpers or {}) do helpers = helpers + 1 end
            local extra = helpers > 0 and (" |cff40ff40" .. T("(%d helfen)", helpers) .. "|r") or ""
            row.text:SetText(who .. ": " .. e.text .. " |cff888888" .. Age(e.at) .. "|r" .. extra)
            row.action:SetText(e.mine and T("Erledigt") or T("Ich helfe"))
            row:Show()
        else
            row:Hide()
        end
    end
    if #list == 0 then f.empty:Show() else f.empty:Hide() end
end

function Board:Open()
    local f = self:Frame()
    f:Show()
    self:Refresh()
end

function Board:Changed()
    if self.frame and self.frame:IsShown() then self:Refresh() end
    if ONE.UI and ONE.UI.Refresh and ONE.UI.frame and ONE.UI.frame:IsShown() then pcall(ONE.UI.Refresh, ONE.UI) end
end

function Board:Slash(rest)
    rest = Clean(rest)
    if rest == "" then return self:Open() end
    return self:Post(rest)
end

function Board:Initialize()
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        Call(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, ...) Board:Receive(...) end)
    self.events = f
    if ONE.UI and ONE.UI.AddFeed then ONE.UI:AddFeed("board", function() return Board:Feed() end) end
    if ONE.RegisterSlash then
        ONE:RegisterSlash("auftrag", function(rest) Board:Slash(rest) end, T("Auftragsbrett: /trip auftrag [Text]"))
    end
    -- Nach dem Einloggen: eigene schicken, die der anderen erfragen
    After(20, function() Board:SendMine() Board:Send("BREQ") end)
end
