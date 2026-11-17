-- Guild Trip: Hilferuf (0.7.0).
-- In Not (Elite-Gegner, Leiche weit weg, verlaufen)? /trip sos [Text] oder eine
-- eigene Taste (Tastenbelegung › AddOns). Gildenmitglieder auf deinem Kontinent
-- bekommen ein kleines Fenster: "Bob (23) braucht Hilfe – 420 m: Elite am Wegkreuz"
-- mit [Ich komme!] (Navi zu dir + Nachricht an dich) und [Flüstern].
-- Deine Position wird NUR mit diesem einen Ruf geschickt (du drueckst selbst),
-- auch ohne dauerhafte Positionsfreigabe. Nichts wird gespeichert.
-- Nachrichten (Praefix ONEHELP1, Gilde):
--   H|karte|x|y|stufe|text   Hilferuf (x/y in Zehntausendsteln)
--   HC                       "Ich komme!" (an den Rufer, Gilde)
--   HX                       Hilfe nicht mehr noetig
local _, guild = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Help = {prefix = "ONEHELP1", cooldown = 60, keep = 600, calls = {}}
guild.Help = Help

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function Clock() return type(GetTime) == "function" and GetTime() or 0 end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function Nav() return ONE.modules and ONE.modules.nav end
local function FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("guild.help") end

function Help:Send(msg)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    if not Call(rawget(_G, "IsInGuild")) then return false end
    Call(C_ChatInfo.SendAddonMessage, self.prefix, msg, "GUILD")
    return true
end

local function Clean(text)
    text = type(text) == "string" and (text:gsub("[|\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")) or ""
    if #text > 60 then
        -- nicht mitten in einem Umlaut abschneiden (UTF-8: Folgebytes 0x80-0xBF)
        local cut = 60
        while cut > 0 and text:byte(cut + 1) and text:byte(cut + 1) >= 128 and text:byte(cut + 1) < 192 do cut = cut - 1 end
        text = text:sub(1, cut)
    end
    return text
end

-- Ruf abschicken. Rueckgabe: true oder nil, Grund
function Help:Call(text)
    if not Call(rawget(_G, "IsInGuild")) then ONE:Print(T("Hilferuf geht nur in einer Gilde.")) return nil, "guild" end
    local now = Clock()
    if self.lastCall and now - self.lastCall < self.cooldown then
        ONE:Print(T("Hilferuf ist schon unterwegs – noch %d Sekunden warten.", math.ceil(self.cooldown - (now - self.lastCall))))
        return nil, "cooldown"
    end
    local map, x, y
    if guild.Presence then map, x, y = guild.Presence:Location() end
    if not map then ONE:Print(T("Hilferuf: Deine Position ist hier nicht bekannt (z. B. in Dungeons).")) return nil, "position" end
    local level = Call(rawget(_G, "UnitLevel"), "player") or 0
    self:Send(("H|%d|%d|%d|%d|%s"):format(map, x, y, level, Clean(text)))
    self.lastCall = now
    self.helpers = {}
    ONE:Print(T("Hilferuf an die Gilde geschickt. /trip sos aus = erledigt."))
    return true
end

function Help:Cancel()
    if not self.lastCall then return false end
    self:Send("HX")
    self.lastCall = nil
    ONE:Print(T("Hilferuf beendet."))
    return true
end

function Help:Slash(rest)
    rest = Clean(rest)
    if rest:lower() == "aus" or rest:lower() == "off" then return self:Cancel() end
    return self:Call(rest)
end

-- ===== Empfangen =====
function Help:Receive(prefix, msg, channel, sender)
    if prefix ~= self.prefix or channel ~= "GUILD" or type(msg) ~= "string" or #msg > 120 then return end
    if guild.Presence and guild.Presence:IsMe(sender) then return end
    local name = Short(sender)
    if msg == "HX" then
        self.calls[name] = nil
        if self.current and self.current.name == name then self:Hide() end
        return
    end
    if msg == "HC" then
        -- Antwort auf MEINEN Ruf
        if not self.lastCall or not FeatureOn() then return end
        self.helpers = self.helpers or {}
        if self.helpers[name] then return end
        self.helpers[name] = true
        ONE:Notify(T("%s kommt dir zu Hilfe!", name), {source = T("Hilferuf"), sound = "notify"})
        return
    end
    local map, x, y, level, text = msg:match("^H|(%d+)|(%d+)|(%d+)|(%d+)|(.*)$")
    map, x, y, level = tonumber(map), tonumber(x), tonumber(y), tonumber(level)
    if not (map and x and y and x <= 10000 and y <= 10000) then return end
    local call = {name = name, full = sender, mapID = map, x = x / 10000, y = y / 10000, level = level, text = Clean(text), at = Clock()}
    local navi = Nav()
    -- nur, wer auf demselben Kontinent ist (sonst kann man nicht helfen)
    call.dist = navi and navi.DistanceTo and Call(navi.DistanceTo, navi, call.mapID, call.x, call.y)
    if not call.dist then return end
    self.calls[name] = call
    if FeatureOn() then self:Show(call) end
end

function Help:Text(c)
    local head = T("%s (%d) braucht Hilfe – %d m entfernt.", c.name, c.level or 0, math.floor((c.dist or 0) + .5))
    if c.text ~= "" then head = head .. "\n|cffffffff„" .. c.text .. "“|r" end
    return head
end

-- ===== Fenster =====
local function Button(parent, label, width)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(width, 22)
    b:SetText(label)
    return b
end

function Help:Frame()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "GuildTripHelpCall", UIParent)
    f:SetSize(320, 92)
    f:SetPoint("TOP", UIParent, "TOP", 0, -100)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.SetMovable then f:SetMovable(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then bg:SetColorTexture(.25, 0, 0, .85) end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.title:SetText(T("Hilferuf aus der Gilde"))
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
    f.text:SetWidth(300)
    if f.text.SetJustifyH then f.text:SetJustifyH("LEFT") end
    f.go = Button(f, T("Ich komme!"), 110)
    f.go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.whisper = Button(f, T("Flüstern"), 90)
    f.whisper:SetPoint("LEFT", f.go, "RIGHT", 6, 0)
    f.close = Button(f, "×", 24)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    f.go:SetScript("OnClick", function() Help:Come() end)
    f.whisper:SetScript("OnClick", function() Help:Whisper() end)
    f.close:SetScript("OnClick", function() Help:Hide() end)
    f:Hide()
    self.frame = f
    return f
end

function Help:Show(c)
    self.current = c
    local f = self:Frame()
    f.text:SetText(self:Text(c))
    f:Show()
    ONE:Notify((self:Text(c):gsub("\n", " ")), {source = T("Hilferuf"), toast = false, sound = "notify"})
    if C_Timer and C_Timer.After then
        C_Timer.After(120, function() if Help.current == c then Help:Hide() end end)
    end
end

function Help:Hide()
    if self.frame then self.frame:Hide() end
    self.current = nil
end

-- "Ich komme!": Navi zum Rufer und Bescheid geben
function Help:Come()
    local c, navi = self.current, Nav()
    if not c then return end
    if navi and navi.PointTo then Call(navi.PointTo, navi, T("Hilferuf: %s", c.name), c.mapID, c.x, c.y) end
    self:Send("HC")
    self:Hide()
end

function Help:Whisper()
    local c = self.current
    if c and type(ChatFrame_OpenChat) == "function" then Call(ChatFrame_OpenChat, "/w " .. (c.full or c.name) .. " ") end
    self:Hide()
end

function Help:Initialize()
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        Call(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, ...) Help:Receive(...) end)
    self.events = f
    if ONE.RegisterSlash then
        ONE:RegisterSlash("sos", function(rest) Help:Slash(rest) end, T("Hilferuf an die Gilde: /trip sos [Text], /trip sos aus"))
    end
end

-- Tastenbelegung (Bindings.xml)
_G.BINDING_HEADER_GUILDTRIPHELP = "Guild Trip"
_G.BINDING_NAME_GUILDTRIPHELP_CALL = T("Hilferuf an die Gilde")
function _G.GuildTripHelp_Call() Help:Call("") end
