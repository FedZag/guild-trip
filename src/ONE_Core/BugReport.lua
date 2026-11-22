local _, ONE = ...

-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
-- /trip bug: Fehlerbericht zum Kopieren.
-- Sammelt Lua-Fehler aus Guild-Trip-Dateien (ONE_*) und Startfehler der Module,
-- merkt sich die letzten paar ueber /reload hinweg und zeigt alles in einem
-- Fenster mit markiertem Text (Strg+C). Keine Spieler-, Gilden- oder Realmnamen.
local BugReport = {}
ONE.BugReport = BugReport

BugReport.maxEntries = 8
BugReport.maxLength = 600

local function Log()
    local db = ONE.db
    if not db then
        BugReport.pending = BugReport.pending or {}
        return BugReport.pending
    end
    db.bugLog = type(db.bugLog) == "table" and db.bugLog or {}
    return db.bugLog
end

local function Now()
    if type(date) == "function" then return date("%d.%m. %H:%M") end
    return "?"
end

-- Nur Fehler, die in unseren eigenen Dateien entstehen.
function BugReport:IsOurs(message)
    return type(message) == "string" and (message:find("ONE_%u%l") ~= nil)
end

function BugReport:Record(source, message)
    message = tostring(message or "?"):gsub("\r", "")
    if #message > self.maxLength then message = message:sub(1, self.maxLength) .. " …" end
    local log = Log()
    for _, entry in ipairs(log) do
        if entry.msg == message then
            entry.count, entry.time = (entry.count or 1) + 1, Now()
            return entry
        end
    end
    local entry = {source = source or "lua", msg = message, count = 1, time = Now()}
    table.insert(log, 1, entry)
    while #log > self.maxEntries do table.remove(log) end
    return entry
end

-- Fehler vor dem Laden der Einstellungen in die gespeicherte Liste uebernehmen.
function BugReport:Attach()
    local pending = self.pending
    self.pending = nil
    if pending then
        for i = #pending, 1, -1 do self:Record(pending[i].source, pending[i].msg) end
    end
end

function BugReport:Clear()
    if ONE.db then ONE.db.bugLog = {} end
    self.pending = nil
end

-- Blizzards Fehlerbehandlung bleibt erhalten; wir lesen nur mit.
function BugReport:HookErrors()
    if self.hooked or type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then return end
    self.hooked = true
    local previous = geterrorhandler()
    seterrorhandler(function(message, ...)
        if BugReport:IsOurs(message) then pcall(BugReport.Record, BugReport, "lua", message) end
        if previous then return previous(message, ...) end
    end)
end

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

-- Speicher je Guild-Trip-Teil (KB) – fuer Fehlerbericht und /trip speicher. {{name, kb}}, Summe
BugReport.ADDONS = {"ONE_Core", "ONE_Guild", "ONE_Nav", "ONE_Dungeons", "ONE_Crafting", "ONE_Classes", "ONE_Chat",
    "ONE_QuestDB", "ONE_Routes", "ONE_Leveling", "ONE_Dev"}
function BugReport.Memory()
    local update = rawget(_G, "UpdateAddOnMemoryUsage")
    local get = rawget(_G, "GetAddOnMemoryUsage")
    if type(update) ~= "function" or type(get) ~= "function" then return nil end
    pcall(update)
    local out, sum = {}, 0
    for _, name in ipairs(BugReport.ADDONS) do
        local ok, kb = pcall(get, name)
        if ok and type(kb) == "number" and kb > 0 then
            out[#out + 1] = {name, kb}
            sum = sum + kb
        end
    end
    return out, sum
end
function BugReport.MemoryLine()
    local list, sum = BugReport.Memory()
    if not list then return nil end
    local parts = {}
    for _, e in ipairs(list) do parts[#parts + 1] = ("%s %.1f"):format(e[1]:gsub("^ONE_", ""), e[2] / 1024) end
    return ("Memory: %.1f MB (%s)"):format(sum / 1024, table.concat(parts, ", "))
end

function BugReport:Build()
    local lines = {}
    local function Add(text) lines[#lines + 1] = text end
    Add("Guild Trip " .. tostring(ONE.version) .. " – Bug report / Fehlerbericht")
    local gameVersion, build = Try(GetBuildInfo)
    Add((T("Game: %s (%s) · Locale: %s · %s")):format(tostring(gameVersion or "?"), tostring(build or "?"),
        tostring(Try(GetLocale) or "?"), Try(date, "%Y-%m-%d") or "?"))
    local modules = {}
    for _, id in ipairs(ONE.moduleOrder or {}) do
        local def = ONE.modules[id]
        local state = def.error and "ERROR" or (ONE:IsEnabled(id) and "on" or "paused")
        modules[#modules + 1] = id .. "=" .. state
    end
    Add("Modules: " .. (#modules > 0 and table.concat(modules, ", ") or "-"))
    local mem = BugReport.MemoryLine()
    if mem then Add(mem) end
    for _, id in ipairs(ONE.moduleOrder or {}) do
        local def = ONE.modules[id]
        if def.error then Add("Start error " .. id .. ": " .. def.error) end
    end
    local log = Log()
    Add("")
    if #log == 0 then
        Add(T("Errors: none recorded / keine Fehler aufgezeichnet"))
    else
        Add(T("Errors (newest first):"))
        for _, entry in ipairs(log) do
            Add((T("[%s] %s%s: %s")):format(entry.time or "?", entry.source or "lua",
                (entry.count or 1) > 1 and (" x" .. entry.count) or "", entry.msg))
        end
    end
    Add("")
    Add(T("What happened? / Was ist passiert?"))
    Add("- ")
    return table.concat(lines, "\n")
end

function BugReport:CreateFrame()
    -- Glas-Aussehen: eigener Glasrahmen statt Blizzard-Vorlage (19.11.2026)
    local glass = ONE.Glass and ONE.Glass.Active and ONE.Glass:Active() and ONE.Themes and ONE.Themes.RegisterWindow
    local ok, frame
    if not glass then ok, frame = pcall(CreateFrame, "Frame", "GuildTripBugReport", UIParent, "BasicFrameTemplateWithInset") end
    if not ok or not frame then frame = CreateFrame("Frame", "GuildTripBugReport", UIParent) end
    frame:SetSize(560, 360)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "GuildTripBugReport") end

    local title = rawget(frame, "TitleText")
    if type(title) ~= "table" then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
    end
    title:SetText(T("Guild Trip – Fehler melden"))

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 14, -32)
    hint:SetPoint("TOPRIGHT", -14, -32)
    hint:SetJustifyH("LEFT")
    hint:SetText(T("Text ist markiert: Strg+C drücken und auf CurseForge in die Kommentare einfügen. Kurz dazuschreiben, was du gemacht hast."))

    local okScroll, scroll = pcall(CreateFrame, "ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    if not okScroll or not scroll then scroll = CreateFrame("ScrollFrame", nil, frame) end
    scroll:SetPoint("TOPLEFT", 14, -62)
    scroll:SetPoint("BOTTOMRIGHT", -34, 44)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    edit:SetWidth(500)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    -- Der Bericht bleibt unveraendert; Tippen setzt ihn zurueck, damit nichts verloren geht.
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and BugReport.text then self:SetText(BugReport.text); self:HighlightText() end
    end)
    scroll:SetScrollChild(edit)
    frame.edit = edit

    local Widgets = ONE.Widgets
    local function Button(text, x, callback)
        local b
        if Widgets and Widgets.Button then
            b = Widgets:Button(frame, text, 150, 24, "BOTTOMLEFT", x, 12, callback)
        else
            b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            b:SetSize(150, 24); b:SetPoint("BOTTOMLEFT", x, 12); b:SetText(text)
            b:SetScript("OnClick", callback)
        end
        return b
    end
    Button(T("Alles markieren"), 14, function() edit:SetFocus(); edit:HighlightText() end)
    Button(T("Liste leeren"), 172, function()
        BugReport:Clear()
        BugReport:Open()
        ONE:Print(T("Fehlerliste geleert."))
    end)
    Button(T("Schließen"), 396, function() frame:Hide() end)
    if glass then
        ONE.Themes:RegisterWindow(frame, nil, title)
        -- Textfeld auf einer eingelassenen Karte; das mehrzeilige Feld selbst bleibt ohne eigenen Rahmen
        edit.__oneGlassCtl = "skip"
        local card = CreateFrame("Frame", nil, frame)
        card:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 6)
        card:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 26, -6)
        if card.SetFrameLevel and frame.GetFrameLevel then card:SetFrameLevel(math.max(0, frame:GetFrameLevel())) end
        ONE.Themes:RegisterPanel(card)
        if ONE.Widgets and ONE.Widgets.CloseButton then ONE.Widgets:CloseButton(frame, "TOPRIGHT", -6, -6, function() frame:Hide() end) end
        if ONE.Themes.StyleTree then ONE.Themes:StyleTree(frame) end
    end
    self.frame = frame
    return frame
end

function BugReport:Open()
    local frame = self.frame or self:CreateFrame()
    self.text = self:Build()
    frame.edit:SetText(self.text)
    frame:Show()
    frame.edit:SetFocus()
    frame.edit:HighlightText()
    return self.text
end

function BugReport:Slash(rest)
    rest = rest or ""
    if rest == "leeren" or rest == "clear" then
        self:Clear()
        ONE:Print(T("Fehlerliste geleert."))
    else
        self:Open()
    end
end

-- Schon beim Laden mithoeren, damit Fehler anderer Guild-Trip-Teile beim Start nicht fehlen.
BugReport:HookErrors()
