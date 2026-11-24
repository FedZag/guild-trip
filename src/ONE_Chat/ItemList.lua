-- Guild Trip Chat: Gegenstands-Vorschlaege beim Tippen von "[" (Nutzer 23.11.2026)
-- "ich brauche noch [schwurgeb" -> Liste passender Gegenstaende ueber dem Eingabefeld (Symbol, Qualitaetsfarbe),
-- jeder Buchstabe kuerzt sie. Pfeile waehlen, Tab/Enter/Klick setzt einen echten Gegenstands-Link ein
-- ("[schwurgeb" wird zu [Schwurgebundene Armschienen]). Gesucht wird in deutschen und englischen Namen
-- (Daten: ItemNames.lua, aus den Spieldaten des Forever-Clients). Gesendet wird nie von hier aus.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local I = {ROWS = 8, ROW_H = 20, MIN = 2, MAX = 40, sel = 1, offset = 0, matches = {}}
chat.ItemList = I
local function M() return chat.Messenger end

-- Qualitaetsfarben (wie im Spiel)
I.QUALITY = {[0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000", "e6cc80", "00ccff"}

-- Kleinschreibung auch fuer Umlaute (string.lower kennt nur A-Z)
function I.Lower(s)
    return (tostring(s or ""):lower():gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"))
end
function I.Locale()
    local loc = type(GetLocale) == "function" and GetLocale() or "deDE"
    return loc == "deDE" and "de" or "en"
end
-- Suchliste einmal beim ersten "[" aufbauen: {id, q, name (Spielsprache), keys (klein, beide Sprachen)}
function I:Index()
    if self.index then return self.index end
    local data = chat.ItemNames
    local list = {}
    if type(data) ~= "table" then self.index = list return list end
    local byId = {}
    local main = I.Locale()
    for _, lang in ipairs({main, main == "de" and "en" or "de"}) do
        for id, q, name in tostring(data[lang] or ""):gmatch("(%d+)\t(%d)\t([^\n]*)\n") do
            id = tonumber(id)
            local e = byId[id]
            if not e then
                e = {id = id, q = tonumber(q) or 1, name = name, keys = {}}
                byId[id] = e
                list[#list + 1] = e
            end
            local k = I.Lower(name)
            if k ~= e.keys[1] then e.keys[#e.keys + 1] = k end
        end
    end
    self.index = list
    return list
end
-- Treffer: Namensanfang vor Wortanfang vor irgendwo; dann bessere Qualitaet, kuerzerer Name
function I:Search(query)
    local q = I.Lower(query):gsub("^%s+", ""):gsub("%s+$", "")
    if #q < self.MIN then return {} end
    local hits = {}
    for _, e in ipairs(self:Index()) do
        local best
        for _, k in ipairs(e.keys) do
            local pos = k:find(q, 1, true)
            if pos then
                local score = pos == 1 and 0 or (k:sub(pos - 1, pos - 1):match("[%s%-']") and 1 or 2)
                if not best or score < best then best = score end
            end
        end
        if best then hits[#hits + 1] = {e = e, score = best} end
    end
    table.sort(hits, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.e.q ~= b.e.q then return a.e.q > b.e.q end
        if #a.e.name ~= #b.e.name then return #a.e.name < #b.e.name end
        return a.e.id < b.e.id
    end)
    local out = {}
    for i = 1, math.min(self.MAX, #hits) do out[i] = hits[i].e end
    return out
end
-- "[" vor dem Cursor: Anfang (Position der Klammer) und Suchtext
function I.Token(text, cursor)
    text = tostring(text or "")
    local before = text:sub(1, cursor or #text)
    local start, q = before:match("()%[([^%[%]|]*)$")
    if not start then return nil end
    return start, q
end

function I:Build()
    if self.frame then return self.frame end
    local m = M()
    if not (m and m.main and m.log) then return nil end
    local f = CreateFrame("Frame", nil, m.main)
    if m.PlaceOverlay then m:PlaceOverlay(f, 26) end
    f:EnableMouse(true)
    local G = ONE.Glass
    if G and G.Surface then
        G.forceLook = "glass"
        local sf = G:Surface(f, "card")
        G.forceLook = nil
        if sf then
            sf.store = function() return chat.Chat:GlassStore() end
            sf.onPaint = function(s2, p) s2.fill:SetColor(p.tint[1], p.tint[2], p.tint[3], .97) end
            if m.surfaces then m.surfaces[#m.surfaces + 1] = sf end
            G:Paint(sf)
        end
    end
    f.rows = {}
    for i = 1, self.ROWS do
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(self.ROW_H)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4 - (i - 1) * self.ROW_H)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4 - (i - 1) * self.ROW_H)
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetAllPoints(b)
        if b.hl.SetColorTexture then b.hl:SetColorTexture(1, 1, 1, 1) end
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(self.ROW_H - 4, self.ROW_H - 4)
        b.icon:SetPoint("LEFT", b, "LEFT", 4, 0)
        b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.name:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.name:SetJustifyH("LEFT")
        if ONE.Fit then ONE.Fit:Line(b.name, false) end
        b:SetScript("OnClick", function(btn) I:Choose(I.offset + btn.index) end)
        b:SetScript("OnEnter", function(btn)
            I.sel = I.offset + btn.index
            I:Paint()
            local e = I.matches[I.sel]
            if e and GameTooltip then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                if not (GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, e.id)) then GameTooltip:SetText(e.name) end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b.index = i
        f.rows[i] = b
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        I.offset = math.max(0, math.min(#I.matches - I.ROWS, I.offset - delta))
        I:Paint()
    end)
    f:Hide()
    self.frame = f
    return f
end
function I:IsShown() return self.frame and self.frame:IsShown() or false end
function I:Hide() if self.frame then self.frame:Hide() end end

-- Nach jeder Aenderung im Eingabefeld
function I:Update()
    local m = M()
    local box = m and m.input
    if not box then return end
    local text = box:GetText() or ""
    local cursor = box.GetCursorPosition and box:GetCursorPosition() or #text
    local start, q = I.Token(text, cursor)
    local matches = start and #(q or "") >= self.MIN and self:Search(q) or nil
    if not (matches and #matches > 0) then self:Hide() return end
    local f = self:Build()
    if not f then return end
    if q ~= self.lastQuery or not f:IsShown() then self.sel, self.offset = 1, 0 end
    self.matches, self.lastQuery, self.start = matches, q, start
    if m.picker and m.picker:IsShown() and m.TogglePicker then m:TogglePicker() end
    if chat.SlashList then chat.SlashList:Hide() end
    f:SetHeight(math.min(#matches, self.ROWS) * self.ROW_H + 8)
    f:Show()
    self:Paint()
end
function I.Icon(id)
    local fn = (C_Item and C_Item.GetItemIconByID) or rawget(_G, "GetItemIcon")
    if type(fn) ~= "function" then return nil end
    local ok, icon = pcall(fn, id)
    return ok and icon or nil
end
function I:Paint()
    local f = self.frame
    if not f then return end
    local m = M()
    local p = m and m.Palette and m:Palette()
    local g = p and p.glow or {1, .82, 0}
    for i, b in ipairs(f.rows) do
        local e = self.matches[self.offset + i]
        b:SetShown(e ~= nil)
        if e then
            b.name:SetText("|cff" .. (I.QUALITY[e.q] or "ffffff") .. e.name .. "|r")
            b.icon:SetTexture(I.Icon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            local on = self.offset + i == self.sel
            b.hl:SetVertexColor(g[1], g[2], g[3], on and .22 or 0)
        end
    end
end
-- dir 1 = nach unten, -1 = nach oben
function I:Move(dir)
    if not self:IsShown() or #self.matches == 0 then return false end
    self.sel = math.max(1, math.min(#self.matches, self.sel + dir))
    if self.sel <= self.offset then self.offset = self.sel - 1 end
    if self.sel > self.offset + self.ROWS then self.offset = self.sel - self.ROWS end
    self:Paint()
    return true
end

-- Link des Gegenstands: vom Spiel (richtige Farbe/Sprache); kennt der Client ihn noch nicht, kurz nachladen
function I.GameLink(id)
    local fn = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
    if type(fn) ~= "function" then return nil end
    local ok, _, link = pcall(fn, id)
    return ok and type(link) == "string" and link ~= "" and link or nil
end
function I.MakeLink(e)
    return "|cff" .. (I.QUALITY[e.q] or "ffffff") .. "|Hitem:" .. e.id .. "::::::::|h[" .. e.name .. "]|h|r"
end
function I:LinkFor(e, done)
    local link = I.GameLink(e.id)
    if link then return done(link) end
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then pcall(C_Item.RequestLoadItemDataByID, e.id) end
    -- warten, bis WoW die Daten hat (hoechstens ~2 s), sonst selbst gebauter Link
    local tries = 0
    local function Again()
        tries = tries + 1
        local l = I.GameLink(e.id)
        if l or tries >= 20 or not (C_Timer and C_Timer.After) then return done(l or I.MakeLink(e)) end
        C_Timer.After(.1, Again)
    end
    if C_Timer and C_Timer.After then C_Timer.After(.05, Again) else done(I.MakeLink(e)) end
end
-- "[suchtext" vor dem Cursor durch den Link ersetzen, nicht senden
function I:Choose(i)
    local e = self.matches[i or self.sel]
    local m = M()
    local box = m and m.input
    if not (e and box) then return false end
    self:Hide()
    self:LinkFor(e, function(link)
        local text = box:GetText() or ""
        local cursor = box.GetCursorPosition and box:GetCursorPosition() or #text
        local start = I.Token(text, cursor)
        local before, after
        if start then before, after = text:sub(1, start - 1), text:sub(cursor + 1)
        else before, after = text:sub(1, cursor), text:sub(cursor + 1) end
        local new = before .. link .. (after:sub(1, 1) == " " and "" or " ") .. after
        box:SetText(new)
        if box.SetCursorPosition then box:SetCursorPosition(#before + #link + 1) end
        if box.SetFocus then box:SetFocus() end
        I:Hide()
    end)
    return true
end
-- Tab/Enter: einsetzen, wenn die Liste offen ist
function I:Complete()
    if not self:IsShown() then return false end
    return self:Choose(self.sel)
end
function I:FocusLost()
    if not (C_Timer and C_Timer.After) then self:Hide() return end
    C_Timer.After(.3, function()
        local m = M()
        local box = m and m.input
        if not (box and box.HasFocus and box:HasFocus()) then I:Hide() end
    end)
end
