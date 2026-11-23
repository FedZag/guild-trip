-- Guild Trip Chat: Befehlsliste beim Tippen von "/" (Nutzer 23.11.2026)
-- Zeigt ueber dem Eingabefeld alle Befehle, die das Spiel gerade kennt (WoW, Guild Trip, andere
-- Addons, Emotes zuletzt). Jeder weitere Buchstabe kuerzt die Liste, nach dem ersten Leerzeichen
-- verschwindet sie. Klick oder Tab setzt den Befehl ein, Pfeil hoch/runter waehlt aus.
-- Gesendet wird nie von hier aus – erst mit Enter.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local S = {ROWS = 8, ROW_H = 18, REBUILD = 300, sel = 1, offset = 0, matches = {}}
chat.SlashList = S

-- Kurze Erklaerungen fuer die gaengigen Befehle (alles andere ohne Erklaerung)
S.DESC = {
    ["/s"] = "Sagen", ["/say"] = "Sagen", ["/sagen"] = "Sagen",
    ["/y"] = "Schreien", ["/yell"] = "Schreien", ["/schreien"] = "Schreien",
    ["/e"] = "Emote schreiben", ["/em"] = "Emote schreiben", ["/me"] = "Emote schreiben",
    ["/g"] = "Gildenchat", ["/guild"] = "Gildenchat", ["/gilde"] = "Gildenchat",
    ["/o"] = "Offizierschat", ["/officer"] = "Offizierschat",
    ["/p"] = "Gruppenchat", ["/party"] = "Gruppenchat", ["/gruppe"] = "Gruppenchat",
    ["/ra"] = "Schlachtzugschat", ["/raid"] = "Schlachtzugschat",
    ["/rw"] = "Schlachtzugswarnung",
    ["/i"] = "Instanzchat", ["/instance"] = "Instanzchat",
    ["/w"] = "Flüstern", ["/whisper"] = "Flüstern", ["/t"] = "Flüstern", ["/tell"] = "Flüstern",
    ["/fl"] = "Flüstern", ["/flüstern"] = "Flüstern",
    ["/r"] = "Letztem Flüsterer antworten", ["/reply"] = "Letztem Flüsterer antworten",
    ["/inv"] = "In die Gruppe einladen", ["/invite"] = "In die Gruppe einladen", ["/einladen"] = "In die Gruppe einladen",
    ["/ginvite"] = "In die Gilde einladen", ["/gremove"] = "Aus der Gilde werfen", ["/gquit"] = "Gilde verlassen",
    ["/leave"] = "Gruppe verlassen", ["/leaveparty"] = "Gruppe verlassen",
    ["/kick"] = "Aus der Gruppe werfen", ["/uninvite"] = "Aus der Gruppe werfen",
    ["/who"] = "Spieler suchen", ["/wer"] = "Spieler suchen",
    ["/roll"] = "Würfeln", ["/random"] = "Würfeln", ["/rnd"] = "Würfeln", ["/würfeln"] = "Würfeln",
    ["/afk"] = "Abwesend", ["/dnd"] = "Nicht stören",
    ["/friend"] = "Freund hinzufügen", ["/ignore"] = "Spieler ignorieren",
    ["/join"] = "Kanal betreten", ["/leavechannel"] = "Kanal verlassen",
    ["/follow"] = "Folgen", ["/f"] = "Folgen", ["/folgen"] = "Folgen",
    ["/assist"] = "Ziel des Ziels übernehmen", ["/target"] = "Ziel wählen", ["/tar"] = "Ziel wählen", ["/focus"] = "Fokus setzen",
    ["/cast"] = "Zauber wirken", ["/use"] = "Gegenstand benutzen", ["/stopcasting"] = "Zaubern abbrechen",
    ["/played"] = "Spielzeit anzeigen", ["/time"] = "Uhrzeit anzeigen",
    ["/reload"] = "Oberfläche neu laden", ["/rl"] = "Oberfläche neu laden",
    ["/logout"] = "Ausloggen", ["/camp"] = "Ausloggen", ["/quit"] = "Spiel beenden", ["/exit"] = "Spiel beenden",
    ["/macro"] = "Makros", ["/m"] = "Makros", ["/help"] = "Hilfe",
    ["/trip"] = "Guild Trip", ["/gt"] = "Guild Trip",
    ["/sit"] = "Hinsetzen", ["/dance"] = "Tanzen", ["/wave"] = "Winken",
}

-- Alle Befehle aus dem Spiel: SLASH_NAME1 = "/befehl" (WoW + Addons), EMOTE1_CMD1 = "/emote"
function S.Collect(env)
    env = env or _G
    local list, seen = {}, {}
    local function Add(cmd, emote)
        if type(cmd) ~= "string" then return end
        cmd = cmd:lower()
        if not cmd:match("^/[^%s]+$") or seen[cmd] then return end
        seen[cmd] = true
        list[#list + 1] = {cmd = cmd, emote = emote}
    end
    local emotes = {}
    for k, v in pairs(env) do
        if type(k) == "string" and type(v) == "string" then
            if k:match("^SLASH_.-%d+$") then Add(v, false)
            elseif k:match("^EMOTE%d+_CMD%d+$") then emotes[#emotes + 1] = v end
        end
    end
    for _, v in ipairs(emotes) do Add(v, true) end
    table.sort(list, function(a, b)
        if a.emote ~= b.emote then return not a.emote end
        return a.cmd < b.cmd
    end)
    return list
end
function S:All()
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if not self.list or now - (self.builtAt or 0) > self.REBUILD then
        self.list, self.builtAt = S.Collect(), now
    end
    return self.list
end
-- Passende Befehle zu einem Anfang ("/in"); nil = Liste nicht zeigen
function S.Filter(list, text)
    text = tostring(text or "")
    if not text:match("^/[^%s]*$") then return nil end
    local prefix, out = text:lower(), {}
    for _, e in ipairs(list) do
        if e.cmd:sub(1, #prefix) == prefix then out[#out + 1] = e end
    end
    return #out > 0 and out or nil
end

local function M() return chat.Messenger end
function S:Build()
    if self.frame then return self.frame end
    local m = M()
    if not (m and m.main and m.log) then return nil end
    local f = CreateFrame("Frame", nil, m.main)
    f:SetPoint("BOTTOMLEFT", m.log, "BOTTOMLEFT", 4, 4)
    f:SetPoint("BOTTOMRIGHT", m.log, "BOTTOMRIGHT", -4, 4)
    if f.SetFrameLevel and m.main.GetFrameLevel then f:SetFrameLevel((m.main:GetFrameLevel() or 1) + 25) end
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
        b.cmd = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.cmd:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.cmd:SetWidth(120)
        b.cmd:SetJustifyH("LEFT")
        b.desc = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        b.desc:SetPoint("LEFT", b, "LEFT", 130, 0)
        b.desc:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.desc:SetJustifyH("LEFT")
        if ONE.Fit then ONE.Fit:Line(b.cmd, false) ONE.Fit:Line(b.desc, false) end
        b:SetScript("OnClick", function(btn) S:Choose(S.offset + btn.index) end)
        b:SetScript("OnEnter", function(btn) S.sel = S.offset + btn.index S:Paint() end)
        b.index = i
        f.rows[i] = b
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        S.offset = math.max(0, math.min(#S.matches - S.ROWS, S.offset - delta))
        S:Paint()
    end)
    f:Hide()
    self.frame = f
    return f
end
function S:IsShown() return self.frame and self.frame:IsShown() or false end
function S:Hide() if self.frame then self.frame:Hide() end end

-- Nach jeder Aenderung im Eingabefeld
function S:Update()
    local m = M()
    local box = m and m.input
    if not box then return end
    local text = box:GetText() or ""
    local matches = text:sub(1, 1) == "/" and S.Filter(self:All(), text) or nil
    if not matches then self:Hide() return end
    local f = self:Build()
    if not f then return end
    local changed = self.lastText ~= text
    self.matches, self.lastText = matches, text
    if changed or not f:IsShown() then self.sel, self.offset = 1, 0 end
    if m.picker and m.picker:IsShown() and m.TogglePicker then m:TogglePicker() end
    f:SetHeight(math.min(#matches, self.ROWS) * self.ROW_H + 8)
    f:Show()
    self:Paint()
end
function S:Paint()
    local f = self.frame
    if not f then return end
    local m = M()
    local p = m and m.Palette and m:Palette()
    local g = p and p.glow or {1, .82, 0}
    for i, b in ipairs(f.rows) do
        local e = self.matches[self.offset + i]
        b:SetShown(e ~= nil)
        if e then
            b.cmd:SetText(e.cmd)
            b.desc:SetText(S.DESC[e.cmd] and T(S.DESC[e.cmd]) or (e.emote and T("Emote") or ""))
            local on = self.offset + i == self.sel
            b.hl:SetVertexColor(g[1], g[2], g[3], on and .22 or 0)
            if b.cmd.SetTextColor then
                if on then b.cmd:SetTextColor(1, 1, 1) else b.cmd:SetTextColor(g[1], g[2], g[3]) end
            end
        end
    end
end
-- dir 1 = nach unten, -1 = nach oben; bleibt sichtbar
function S:Move(dir)
    if not self:IsShown() or #self.matches == 0 then return false end
    self.sel = math.max(1, math.min(#self.matches, self.sel + dir))
    if self.sel <= self.offset then self.offset = self.sel - 1 end
    if self.sel > self.offset + self.ROWS then self.offset = self.sel - self.ROWS end
    self:Paint()
    return true
end
-- Befehl ins Feld setzen (mit Leerzeichen), nicht senden
function S:Choose(i)
    local e = self.matches[i or self.sel]
    local m = M()
    local box = m and m.input
    if not (e and box) then return false end
    box:SetText(e.cmd .. " ")
    if box.SetCursorPosition then box:SetCursorPosition(#e.cmd + 1) end
    box:SetFocus()
    self:Hide()
    return true
end
-- Tab: einsetzen, wenn die Liste offen ist
function S:Complete()
    if not self:IsShown() then return false end
    return self:Choose(self.sel)
end
-- Fokus weg (z. B. Klick ins Spiel): kurz warten, ein Klick in die Liste setzt ihn wieder
function S:FocusLost()
    if not (C_Timer and C_Timer.After) then self:Hide() return end
    C_Timer.After(.3, function()
        local m = M()
        local box = m and m.input
        if not (box and box.HasFocus and box:HasFocus()) then S:Hide() end
    end)
end
