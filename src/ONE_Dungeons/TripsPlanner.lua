-- Guild Trip: Termin-Fenster (15.11.2026, nach Vorschau mit dem Nutzer).
-- Vier nummerierte Kaesten: 1 Was · 2 Wann · 3 Wo · 4 Wer, darunter eine
-- Zusammenfassung in einer Zeile und "Abbrechen" / "Ankuendigen".
-- Pflicht sind nur Art, Titel (bzw. Ziel) und Tag; alles andere hat Vorgaben.
-- Normal: 2×2-Raster ueber die ganze Seite. Buch: links 1 und 2, rechts 3 und 4.
-- Alles bleibt im Addon – der WoW-Kalender wird nie geoeffnet.
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Planner = {}
dungeons.TripsPlanner = Planner

local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(T(text or ""))
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end

local function Edit(parent, x, y, width, maxLetters, numeric)
    local ok, box = pcall(CreateFrame, "EditBox", nil, parent, "InputBoxTemplate")
    if not ok or not box then box = CreateFrame("EditBox", nil, parent) end
    if ONE.Kit and ONE.Kit.StyleEdit then ONE.Kit.StyleEdit(box) end
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 6, y)
    box:SetSize(width - 6, 22)
    if box.SetAutoFocus then box:SetAutoFocus(false) end
    if box.SetMaxLetters then box:SetMaxLetters(maxLetters) end
    if numeric and box.SetNumeric then box:SetNumeric(true) end
    if box.SetFontObject then pcall(box.SetFontObject, box, "GameFontHighlight") end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if ONE.Book and ONE.Book.StyleEditBox then pcall(ONE.Book.StyleEditBox, ONE.Book, box) end
    return box
end

-- Standardwerte eines neuen Termins
function Planner:Defaults()
    return {kind = nil, title = "", key = nil, note = "", day = 0, minutes = 20 * 60, dur = 120, rep = "", remind = 15,
        meet = "here", size = 0, roles = {0, 0, 0}, lmin = nil, lmax = nil}
end

-- Art gewaehlt: passende Vorgaben (Plaetze, Rollen, Ziel, Stufe, Treffpunkt)
function Planner:ApplyKind(s, kind)
    local Tr = dungeons.Trips
    local k = Tr.kindByKey[kind]
    if not k then return end
    s.kind, s.size = kind, k.size or 0
    s.roles = k.roles and {k.roles[1], k.roles[2], k.roles[3]} or {0, 0, 0}
    s.key, s.lmin, s.lmax, s.meet = nil, nil, nil, "here"
    if kind == "dungeon" then
        local level = dungeons.Model:PlayerLevel()
        local list = dungeons.Model:Dungeons()
        for _, d in ipairs(list) do
            if level >= d.min - 2 and level <= d.max then s.key = d.key break end
        end
        s.key = s.key or (list[1] and list[1].key)
        self:ApplyTarget(s)
    elseif kind == "raid" then
        s.key = Tr.raids[1].key
        self:ApplyTarget(s)
    end
end

-- Ziel gewaehlt: Stufe und Treffpunkt (Eingang, wenn bekannt)
function Planner:ApplyTarget(s)
    local Tr = dungeons.Trips
    if s.kind == "dungeon" then
        for _, d in ipairs(dungeons.Model:Dungeons()) do
            if d.key == s.key then s.lmin, s.lmax = d.min, d.max end
        end
        s.meet = (dungeons.Entrances and s.key and dungeons.Entrances:Get(s.key)) and "entrance" or "here"
    elseif s.kind == "raid" then
        for _, r in ipairs(Tr.raids) do
            if r.key == s.key then s.lmin, s.lmax, s.size = r.min, 60, r.size end
        end
        s.meet = "capital"
    end
end

function Planner.NeedsTarget(s) return s.kind == "dungeon" or s.kind == "raid" end

-- Fehlt noch etwas? nil = alles gut, sonst kurzer Hinweis
function Planner:Missing(s)
    if not s.kind then return T("Wähle eine Art.") end
    if self.NeedsTarget(s) then
        if not s.key then return T("Wähle ein Ziel.") end
    elseif not (s.title or ""):match("%S") then
        return T("Gib dem Termin einen Titel.")
    end
    local start = dungeons.Trips:StartFrom(s.day, s.minutes)
    if not start or start < dungeons.Trips:Now() then return T("Diese Uhrzeit ist schon vorbei.") end
    return nil
end

-- Zusammenfassung: "HDW Questrun · Di 17.11., 18:30–20:30 · Wegekreuz · 5 Plätze (1 T, 1 H, 3 DD) · Stufe 15–24"
function Planner:Summary(s)
    local Tr = dungeons.Trips
    local what
    if s.kind == "dungeon" and s.key then what = dungeons.Share:DungeonName(s.key)
    elseif s.kind == "raid" and s.key then what = Tr.RaidName(s.key)
    else what = (s.title or ""):match("%S") and s.title or T("Ohne Titel") end
    local parts = {"|cffffd100" .. what .. "|r"}
    local start = Tr:StartFrom(s.day, s.minutes)
    if start then
        local when = Tr:When(start)
        if (s.dur or 0) > 0 and type(date) == "function" then when = when .. "–" .. date("%H:%M", start + s.dur * 60) end
        parts[#parts + 1] = when .. (s.rep == "w" and (" (" .. T("wöchentlich") .. ")") or "")
    end
    local meetNames = {here = T("dein Standort"), entrance = T("Dungeon-Eingang"), capital = T("Hauptstadt"), later = T("Treffpunkt offen")}
    parts[#parts + 1] = meetNames[s.meet] or ""
    local r = s.roles or {}
    local roles = (r[1] or 0) + (r[2] or 0) + (r[3] or 0) > 0
        and string.format(" (%d %s, %d %s, %d %s)", r[1] or 0, T("T"), r[2] or 0, T("H"), r[3] or 0, T("DD")) or ""
    parts[#parts + 1] = ((s.size or 0) > 0 and T("%d Plätze", s.size) or T("offen")) .. roles
    if s.lmin or s.lmax then parts[#parts + 1] = T("Stufe %d–%d", s.lmin or 1, s.lmax or 60) end
    return table.concat(parts, "  ·  ")
end

-- Termin anlegen und an die Gilde schicken
function Planner:Create(s)
    local Tr = dungeons.Trips
    if self:Missing(s) then return nil end
    local start = Tr:StartFrom(s.day, s.minutes)
    local key = self.NeedsTarget(s) and s.key or Tr.FREE
    local meet = Tr:MeetFor(s.meet, key)
    if not meet then
        ONE:Print(T("Der Eingang ist noch unbekannt – Treffpunkt ist dein Standort."))
        meet = Tr:HereMeet()
    end
    local title = (not self.NeedsTarget(s)) and s.title or nil
    return Tr:Create(key, start, meet, title, {kind = s.kind, dur = s.dur, rep = s.rep == "w" and "w" or nil,
        remind = s.remind, size = s.size, roles = {s.roles[1] or 0, s.roles[2] or 0, s.roles[3] or 0},
        lmin = s.lmin, lmax = s.lmax, note = (s.note or ""):match("%S") and s.note or nil})
end

-- ===== Fenster =====
-- onDone(trip oder nil) wird nach "Ankuendigen" bzw. "Abbrechen" gerufen
function Planner:Build(panel, onDone)
    local Tr = dungeons.Trips
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local bookL, bookR
    local f = CreateFrame("Frame", nil, panel)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    f:SetSize(W, H)
    f:Hide()
    local s = self:Defaults()
    self.state = s
    local controls = {}

    -- Kaesten: Lage je nach Aussehen
    local half = math.floor((W - 12) / 2)
    -- Ueberschrift oben rechts (oben links liegen die Umschalter Dungeons | Gruppen | Ausfluege)
    local hx, hw = bookR and bookR.x or (half + 12), bookR and bookR.width or half
    local head = Text(f, "GameFontNormalLarge", hx, -4, hw, "accent", "Termin planen")
    Text(f, "GameFontHighlightSmall", hx, -24, hw, "soft", "Pflicht: nur Art, Titel und Tag")
    if head.SetWordWrap then head:SetWordWrap(false) end
    local C1 = {x = bookL and bookL.x or 0, w = bookL and bookL.width or half}
    local C2 = {x = bookR and bookR.x or (half + 12), w = bookR and bookR.width or half}
    -- Kasten 1: drei Reihen Arten; Kasten 2: vier Zeilen (Tag, Beginn+Dauer, Wiederholen, Erinnerung)
    local place = bookL and {
        {C1, -44, 168}, {C1, -218, 148}, {C2, -44, 84}, {C2, -134, 116},
    } or {
        {C1, -44, 168}, {C2, -44, 168}, {C1, -218, 116}, {C2, -218, 116},
    }
    local LBL = 92
    local function Box(i, title)
        local col, y, h = place[i][1], place[i][2], place[i][3]
        local b = CreateFrame("Frame", nil, f)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", col.x, y)
        b:SetSize(col.w, h)
        if ONE.Themes and ONE.Themes.RegisterPanel then ONE.Themes:RegisterPanel(b) end
        Text(b, "GameFontNormal", 12, -8, col.w - 24, "accent", i .. "   " .. T(title))
        b.fieldX, b.fieldW = 12 + LBL, col.w - 24 - LBL
        return b
    end
    local function Row(b, y, label) return Text(b, "GameFontHighlightSmall", 12, y - 4, LBL - 4, "soft", label) end
    local function DD(b, x, y, width, options, get, set)
        local dd = ONE.Kit:Dropdown(b, {point = "TOPLEFT", x = x, y = y, width = width,
            options = options, get = get, set = set, onChange = function() Planner:Refresh() end})
        controls[#controls + 1] = dd
        return dd
    end

    -- 1 Was: Art (zwei Reihen Knoepfe), Titel oder Ziel, Notiz
    local b1 = Box(1, "Was")
    Row(b1, -30, "Art")
    local chipW = math.floor((b1.fieldW - 2 * 4) / 3)
    local chips = {}
    for i, k in ipairs(Tr.kinds) do
        local col, line = (i - 1) % 3, math.floor((i - 1) / 3)
        local chip = ONE.Widgets:Button(b1, T(k.label), chipW, 20, "TOPLEFT", b1.fieldX + col * (chipW + 4), -28 - line * 23, function()
            Planner:ApplyKind(s, k.key)
            Planner:Refresh()
        end)
        chip.kind, chip.label = k.key, k.label
        chips[#chips + 1] = chip
    end
    local whatLabel = Row(b1, -106, "Titel")
    local titleBox = Edit(b1, b1.fieldX, -104, b1.fieldW, 40)
    titleBox:SetScript("OnTextChanged", function(self) s.title = self:GetText() or "" Planner:RefreshSummary() end)
    local ddTarget = DD(b1, b1.fieldX, -104, b1.fieldW,
        function()
            local out = {}
            if s.kind == "raid" then
                for _, r in ipairs(Tr.raids) do out[#out + 1] = {value = r.key, text = r.name} end
            else
                for _, d in ipairs(dungeons.Model:Dungeons()) do
                    out[#out + 1] = {value = d.key, text = string.format("%s (%d–%d)", dungeons.Share:DungeonName(d.key), d.min, d.max)}
                end
            end
            return out
        end,
        function() return s.key end, function(v) s.key = v Planner:ApplyTarget(s) end)
    Row(b1, -136, "Notiz")
    local noteBox = Edit(b1, b1.fieldX, -134, b1.fieldW, 60)
    noteBox:SetScript("OnTextChanged", function(self) s.note = self:GetText() or "" Planner:RefreshSummary() end)

    -- 2 Wann: Tag · Beginn und Dauer · Wiederholen und Erinnerung
    local b2 = Box(2, "Wann")
    local halfW = math.floor((b2.fieldW - 6) / 2)
    Row(b2, -30, "Tag")
    DD(b2, b2.fieldX, -28, b2.fieldW, function()
        local out = {}
        for i = 0, 13 do
            local t = Tr:Now() + i * 86400
            local label = i == 0 and T("Heute") or i == 1 and T("Morgen")
                or (type(date) == "function" and string.format("%s %s", T(({"So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"})[tonumber(date("%w", t)) + 1]), date("%d.%m.", t)) or tostring(i))
            out[#out + 1] = {value = i, text = label}
        end
        return out
    end, function() return s.day end, function(v) s.day = v end)
    Row(b2, -60, "Beginn")
    DD(b2, b2.fieldX, -58, halfW, function() return Tr:TimeOptions() end, function() return s.minutes end, function(v) s.minutes = v end)
    DD(b2, b2.fieldX + halfW + 6, -58, halfW, function()
        local out = {}
        for _, m in ipairs(Tr.durations) do out[#out + 1] = {value = m, text = m > 0 and T("%d Std.", m / 60) or T("Dauer offen")} end
        return out
    end, function() return s.dur end, function(v) s.dur = v end)
    Row(b2, -90, "Wiederholen")
    DD(b2, b2.fieldX, -88, b2.fieldW, function()
        return {{value = "", text = T("einmalig")}, {value = "w", text = T("jede Woche")}}
    end, function() return s.rep end, function(v) s.rep = v end)
    Row(b2, -120, "Erinnerung")
    DD(b2, b2.fieldX, -118, b2.fieldW, function()
        local out = {}
        for _, m in ipairs(Tr.reminds) do
            out[#out + 1] = {value = m, text = m == 0 and T("ohne Erinnerung") or m >= 60 and T("%d Std. vorher", m / 60) or T("%d Min. vorher", m)}
        end
        return out
    end, function() return s.remind end, function(v) s.remind = v end)

    -- 3 Wo: Treffpunkt
    local b3 = Box(3, "Wo")
    Row(b3, -30, "Treffpunkt")
    DD(b3, b3.fieldX, -28, b3.fieldW, function()
        local here = Tr:HereMeet()
        local out = {{value = "here", text = T("Mein Standort jetzt") .. ((here.name or "") ~= "" and (" (" .. here.name .. ")") or "")}}
        if s.kind == "dungeon" then out[#out + 1] = {value = "entrance", text = T("Dungeon-Eingang")} end
        out[#out + 1] = {value = "capital", text = T("Hauptstadt")}
        out[#out + 1] = {value = "later", text = T("Später festlegen")}
        return out
    end, function() return s.meet end, function(v) s.meet = v end)
    local meetHint = Text(b3, "GameFontHighlightSmall", b3.fieldX, -60, b3.fieldW, "soft",
        "Zum Start führt das Navi alle Angemeldeten dorthin.")
    if meetHint.SetWordWrap then meetHint:SetWordWrap(true) end

    -- 4 Wer: Plaetze · Rollen · Stufe
    local b4 = Box(4, "Wer")
    Row(b4, -30, "Plätze")
    DD(b4, b4.fieldX, -28, math.min(b4.fieldW, 120), function()
        local out = {}
        for _, n in ipairs(Tr.sizes) do out[#out + 1] = {value = n, text = n > 0 and tostring(n) or T("offen")} end
        return out
    end, function() return s.size end, function(v) s.size = v end)
    Row(b4, -60, "Rollen")
    local roleBoxes = {}
    for i, label in ipairs({"T", "H", "DD"}) do
        local x = b4.fieldX + (i - 1) * 74
        Text(b4, "GameFontHighlightSmall", x, -62, 24, "soft", label)
        local box = Edit(b4, x + 26, -58, 36, 2, true)
        box:SetScript("OnTextChanged", function(self) s.roles[i] = tonumber(self:GetText()) or 0 Planner:RefreshSummary() end)
        roleBoxes[i] = box
    end
    Row(b4, -90, "Stufe")
    local lminBox = Edit(b4, b4.fieldX, -88, 44, 2, true)
    Text(b4, "GameFontHighlightSmall", b4.fieldX + 50, -92, 26, "soft", "bis")
    local lmaxBox = Edit(b4, b4.fieldX + 74, -88, 44, 2, true)
    lminBox:SetScript("OnTextChanged", function(self) s.lmin = tonumber(self:GetText()) Planner:RefreshSummary() end)
    lmaxBox:SetScript("OnTextChanged", function(self) s.lmax = tonumber(self:GetText()) Planner:RefreshSummary() end)

    -- Zusammenfassung und Knoepfe
    -- Buch: rechte Seite unter Kasten 4; sonst unter allen Kaesten ueber die volle Breite.
    -- Der Hinweis "was fehlt" steht in einer eigenen Zeile ueber den Knoepfen.
    local sumX, sumY, sumW = bookR and bookR.x or 0, bookR and -262 or -344, bookR and bookR.width or W
    local summary = Text(f, "GameFontHighlight", sumX, sumY, sumW, "text")
    if summary.SetWordWrap then summary:SetWordWrap(true) end
    local missing = Text(f, "GameFontHighlightSmall", sumX, bookR and -326 or -390, bookR and sumW or (W - 2 * 140 - 30), "soft")
    if missing.SetWordWrap then missing:SetWordWrap(false) end
    local BW = bookR and 140 or 120
    local bx = (bookR and (bookR.x + bookR.width) or W) - 2 * BW - 8
    local by = bookR and -350 or -386
    ONE.Widgets:Button(f, T("Abbrechen"), BW, 26, "TOPLEFT", bx, by, function()
        f:Hide()
        if onDone then onDone(nil) end
    end)
    local create = ONE.Widgets:Button(f, T("Ankündigen"), BW, 26, "TOPLEFT", bx + BW + 8, by, function()
        local trip = Planner:Create(s)
        if not trip then return end
        ONE:Print(T("Termin angekündigt: %s, %s.", Tr:Name(trip), Tr:When(trip.start)))
        f:Hide()
        if onDone then onDone(trip) end
    end, "primary")

    -- Anzeige aktualisieren (Werte -> Felder)
    function Planner:RefreshSummary()
        summary:SetText(Planner:Summary(s))
        local miss = Planner:Missing(s)
        missing:SetText(miss and ("|cffff8040" .. miss .. "|r") or "")
        if create.SetEnabled then create:SetEnabled(miss == nil) end
    end
    function Planner:Refresh()
        for _, chip in ipairs(chips) do
            local on = chip.kind == s.kind
            if on then if chip.LockHighlight then chip:LockHighlight() end
            elseif chip.UnlockHighlight then chip:UnlockHighlight() end
            -- normales Aussehen: gewaehlte Art weiss mit Haken, die anderen gold
            local fs = chip.GetFontString and chip:GetFontString()
            local book = false
            if fs and not book then
                if on then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(1, .82, 0) end
            end
            -- Haken als Spielbild (die WoW-Schrift kennt kein Haken-Zeichen)
            if chip.SetText then chip:SetText((on and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " or "") .. T(chip.label)) end
        end
        local target = Planner.NeedsTarget(s)
        whatLabel:SetText(T(target and "Ziel" or "Titel"))
        if target then titleBox:Hide() ddTarget.frame:Show() else titleBox:Show() ddTarget.frame:Hide() end
        for _, dd in ipairs(controls) do if dd.Refresh then dd:Refresh() end end
        for i, box in ipairs(roleBoxes) do box:SetText(tostring(s.roles[i] or 0)) end
        lminBox:SetText(s.lmin and tostring(s.lmin) or "")
        lmaxBox:SetText(s.lmax and tostring(s.lmax) or "")
        Planner:RefreshSummary()
    end
    -- neu oeffnen: Werte zuruecksetzen (kind = vorgewaehlte Art)
    function Planner:Open(kind)
        -- erst alles leeren: Vorgaben mit nil (Art, Ziel, Stufe) wuerden sonst stehen bleiben
        for k in pairs(s) do s[k] = nil end
        for k, v in pairs(Planner:Defaults()) do s[k] = v end
        titleBox:SetText("") noteBox:SetText("")
        if kind then Planner:ApplyKind(s, kind) end
        f:Show()
        Planner:Refresh()
    end
    self.frame = f
    return f
end
