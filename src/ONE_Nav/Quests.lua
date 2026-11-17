-- Guild Trip: Quest-Seite (0.6.4, Etappe 1 von "Quests wie Questie").
-- Daten kommen nur aus dem Spiel selbst (keine fremden Datenbanken):
--  * Questlog: C_QuestLog.GetInfo / GetQuestLogTitle
--  * Ziele + Fortschritt: C_QuestLog.GetQuestObjectives
--  * Ort je Quest: C_QuestLog.GetQuestsOnMap(mapID) – liefert fuer jede Log-Quest
--    einen Punkt (Zielgebiet, Abgabe wenn fertig, sonst Rand Richtung Zielzone).
--    Fuer Quests ausserhalb der aktuellen Zone werden die Zonen des Kontinents
--    abgefragt; ein Punkt am Zonenrand zaehlt weniger als einer mitten in der Zone.
--  * Gilden-Abgleich (QuestShare.lua): wer in der Gilde dieselbe Quest hat;
--    deren Orte fuellen Luecken, wenn das Spiel uns keinen liefert.
-- Spaeter: Elite-Gruppensuche, Symbole auf der Karte, gesammelte Questgeber.
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Q = {cache = {}, cacheAt = 0}
nav.Quests = Q

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

-- Alle Quests im Log (ohne Ueberschriften)
function Q:Log()
    local list, CQ = {}, C_QuestLog
    if CQ and CQ.GetNumQuestLogEntries and CQ.GetInfo then
        for i = 1, Try(CQ.GetNumQuestLogEntries) or 0 do
            local info = Try(CQ.GetInfo, i)
            if type(info) == "table" and not info.isHeader and not info.isHidden and info.questID then
                list[#list + 1] = {id = info.questID, title = info.title or "?", level = info.level or 0,
                    complete = info.isComplete == 1 or info.isComplete == true, group = info.suggestedGroup or 0}
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, Try(GetNumQuestLogEntries) or 0 do
            local title, level, group, isHeader, _, complete, _, questID = Try(GetQuestLogTitle, i)
            if title and not isHeader and questID then
                list[#list + 1] = {id = questID, title = title, level = level or 0, complete = complete == 1, group = group or 0}
            end
        end
    end
    for _, q in ipairs(list) do
        q.objectives = Try(CQ and CQ.GetQuestObjectives, q.id) or {}
        local tag = Try(CQ and CQ.GetQuestTagInfo, q.id)
        q.tag = type(tag) == "table" and tag.tagName or nil
        q.elite = (q.group or 0) > 1 or (type(tag) == "table" and (tag.isElite or tag.tagID == 1 or tag.tagID == 81)) or false
    end
    table.sort(list, function(a, b)
        if a.complete ~= b.complete then return a.complete end
        if a.level ~= b.level then return a.level < b.level end
        return a.title < b.title
    end)
    return list
end

-- Kurzer Fortschritt: erstes unerledigtes Ziel, sonst "fertig"
function Q:Progress(q)
    if q.complete then return T("fertig – abgeben") end
    for _, o in ipairs(q.objectives or {}) do
        if not o.finished then
            local text = o.text or ""
            if text:match("^%s*:") or text == "" then text = ("%d/%d"):format(o.numFulfilled or 0, o.numRequired or 0) end
            return text
        end
    end
    return ""
end

-- Zonen, die nach Quest-Orten abgefragt werden: aktuelle Zone zuerst, dann alle
-- Zonen des Kontinents
local function Zones()
    local here = Try(C_Map and C_Map.GetBestMapForUnit, "player")
    local list, seen = {}, {}
    local function Add(id) if id and not seen[id] then seen[id] = true list[#list + 1] = id end end
    Add(here)
    local info = here and Try(C_Map.GetMapInfo, here)
    local continent = here
    while info and info.parentMapID and info.parentMapID > 0 and info.mapType and Enum and Enum.UIMapType
        and info.mapType > Enum.UIMapType.Continent do
        continent = info.parentMapID
        info = Try(C_Map.GetMapInfo, continent)
    end
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    local children = continent and Try(C_Map.GetMapChildrenInfo, continent, zoneType, true)
    for _, child in ipairs(type(children) == "table" and children or {}) do Add(child.mapID) end
    -- danach die anderen Kontinente (Quest liegt z. B. in den Oestlichen Koenigreichen)
    local world = continent and Try(C_Map.GetMapInfo, continent)
    local worldID = world and world.parentMapID or 947
    local continents = Try(C_Map.GetMapChildrenInfo, worldID, Enum and Enum.UIMapType and Enum.UIMapType.Continent)
    for _, c in ipairs(type(continents) == "table" and continents or {}) do
        if c.mapID ~= continent then
            local zones = Try(C_Map.GetMapChildrenInfo, c.mapID, zoneType, true)
            for _, z in ipairs(type(zones) == "table" and zones or {}) do Add(z.mapID) end
        end
    end
    return list, here
end

-- Orte aller Log-Quests (Ergebnis 5 Sekunden zwischengespeichert)
function Q:Locations()
    local now = type(GetTime) == "function" and GetTime() or 0
    -- Zwischenspeicher: Quest-Ereignisse kommen im Kampf sehr oft (jeder Kill). Neu
    -- gesucht wird hoechstens alle 3 s, ohne Aenderung erst nach 30 s.
    local age = now - self.cacheAt
    if next(self.cache) and age >= 0 and (age < 3 or (age < 30 and not self.dirty)) then return self.cache end
    self.dirty = false
    -- Welche Quests brauchen noch einen Ort? Sobald alle einen Punkt mitten in einer
    -- Zone haben, hoert die Suche auf (sonst ~100 Zonen je Durchlauf).
    local open, missing = {}, 0
    for _, q in ipairs(self:Log()) do if not open[q.id] then open[q.id] = true missing = missing + 1 end end
    local best = {}
    local zones, here = Zones()
    for _, mapID in ipairs(zones) do
        if missing <= 0 then break end
        local list = Try(C_QuestLog and C_QuestLog.GetQuestsOnMap, mapID)
        for _, p in ipairs(type(list) == "table" and list or {}) do
            if p.questID and p.x and p.y then
                -- Punkte am Zonenrand sind meist nur "Richtung andere Zone"
                local edge = math.min(p.x, p.y, 1 - p.x, 1 - p.y) < .06
                local score = (edge and 1 or 3) + (mapID == here and .5 or 0)
                local old = best[p.questID]
                if not old or score > old.score then
                    best[p.questID] = {mapID = mapID, x = p.x, y = p.y, score = score, edge = edge}
                    if not edge and open[p.questID] and (not old or old.edge) then missing = missing - 1 end
                end
            end
        end
    end
    self.cache, self.cacheAt = best, now
    return best
end

function Q:ZoneName(mapID)
    local info = mapID and Try(C_Map and C_Map.GetMapInfo, mapID)
    return type(info) == "table" and info.name or ""
end

-- Eigener Ort, sonst der eines Gildenmitglieds mit derselben Quest
function Q:Where(q)
    local loc = self:Locations()[q.id]
    if loc then return loc end
    local shared = nav.QuestShare and nav.QuestShare:Location(q.id) or nil
    if shared then return shared end
    -- Questdatenbank (QuestieDB Forever): Ziel bzw. Abgabe
    if nav.QuestDB and nav.QuestDB:Available() then
        local here = nav.Travel and nav.Travel.PlayerMapPosition and nav.Travel.PlayerMapPosition()
        return nav.QuestDB:Location(q, here)
    end
end

function Q:Navi(q)
    local loc = self:Where(q)
    local navi = ONE.modules and ONE.modules.nav
    if not loc then ONE:Print(T("Für „%s“ kennt das Spiel gerade keinen Ort.", q.title)) return false end
    if navi and navi.PointTo then return navi:PointTo(q.title, loc.mapID, loc.x, loc.y) end
end

-- Gruppe fuer eine Elite-Quest suchen: Gesuch an die Gilde (nur Mitglieder mit
-- derselben Quest bekommen einen Hinweis im Chat + "!"), dann Gruppen-Ansicht
function Q:FindGroup(q)
    local dungeons = ONE.modules and ONE.modules.dungeons
    if not (dungeons and dungeons.PostQuestAd) then return false end
    if not (dungeons.MyQuestAd and dungeons:MyQuestAd() == q.id) then
        local size = (q.group or 0) > 1 and q.group or 5
        if not dungeons:PostQuestAd(q.id, q.title, size) then return false end
        local _, n = "", 0
        if nav.QuestShare then _, n = nav.QuestShare:HoldersText(q.id) end
        ONE:Print(n > 0 and T("Gesuch für „%s“ aufgegeben – %d aus der Gilde haben die Quest auch.", q.title, n)
            or T("Gesuch für „%s“ aufgegeben.", q.title))
    end
    if ONE.UI.OpenLink then ONE.UI:OpenLink("groups") end
    return true
end

-- ===== Seite =====
local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(T(text)) end
    if ONE.Themes then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end

function Q:Build(panel)
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local L, R
    if ONE.Book and ONE.Book.Spread then L, R = ONE.Book:Spread() end
    local leftW = L and L.width or 380
    local rightX, rightW = R and R.x or (leftW + 14), R and R.width or (W - leftW - 14)
    local state = {}
    ONE.Widgets:PageHeader(panel, T("Quests"), T("Deine Quests mit Fortschritt – „Navi“ zeigt die Richtung zum Ziel."), L and L.width or W)
    local list = ONE.Kit:List(panel, {x = 0, y = -62, width = leftW, height = H - 62, rowHeight = 24,
        columns = {
            {key = "title", title = "QUEST", width = leftW - 24 - 6 - 40 - 44 - 16 - 8, indent = 4},
            {key = "level", title = "STUFE", width = 40, align = "CENTER"},
            {key = "guild", title = "GILDE", width = 44, align = "CENTER"},
        },
        render = function(row, q, cells)
            cells.title:SetText(q.title .. (q.elite and ("  |cffff8040" .. T("(Elite)") .. "|r") or ""))
            if q.complete then cells.title:SetTextColor(.4, 1, .4) else cells.title:SetTextColor(1, .82, 0) end
            cells.level:SetText(q.level > 0 and q.level or "")
            local n = nav.QuestShare and #nav.QuestShare:Holders(q.id) or 0
            cells.guild:SetText(n > 0 and n or "")
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                if ONE.Book and ONE.Book.Paint then ONE.Book.Paint(row.selection, 1, .82, 0, .14) else row.selection:SetColorTexture(1, .82, 0, .14) end
            end
            if state.q and state.q.id == q.id then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, q) state.q = q ONE.UI:Refresh() end,
    })
    local empty = Text(panel, "GameFontHighlight", 8, -100, leftW - 16, "soft", "Dein Questlog ist leer.")

    -- rechts: Details der gewaehlten Quest
    local card = CreateFrame("Frame", nil, panel)
    card:SetPoint("TOPLEFT", panel, "TOPLEFT", rightX, -62)
    card:SetSize(rightW, H - 62)
    if ONE.Themes then ONE.Themes:RegisterPanel(card) end
    local title = Text(card, "GameFontNormalLarge", 14, -12, rightW - 28, "accent")
    local where = Text(card, "GameFontHighlightSmall", 14, -38, rightW - 28, "soft")
    local lines = {}
    for i = 1, 8 do lines[i] = Text(card, "GameFontHighlight", 20, -64 - (i - 1) * 20, rightW - 40, "text") end
    local hint = Text(card, "GameFontHighlightSmall", 14, -228, rightW - 28, "soft")
    if hint.SetWordWrap then hint:SetWordWrap(true) end
    local guildHead = Text(card, "GameFontNormal", 14, -262, rightW - 28, "accent", "In der Gilde")
    local guildText = Text(card, "GameFontHighlightSmall", 14, -282, rightW - 28, "text")
    if guildText.SetWordWrap then guildText:SetWordWrap(true) end
    if guildText.SetMaxLines then guildText:SetMaxLines(3) end
    -- kleiner Navi-Pfeil (wie ueberall), Ziel im Tooltip
    local go = ONE.Widgets:NaviArrow(card, 22, "BOTTOMLEFT", 16, 16, function() if state.q then Q:Navi(state.q) end end,
        function(self)
            if not state.q then return nil end
            if self.IsEnabled and not self:IsEnabled() then return T("Navi zur Quest"), T("Für diese Quest kennt Guild Trip noch keinen Ort.") end
            return T("Navi zur Quest"), state.q.title
        end)
    -- Elite-/Gruppenquest: Gesuch im Gruppenfinder (Reiter Dungeons › Gruppen)
    local group = ONE.Widgets:Button(card, T("Gruppe suchen"), 140, 26, "BOTTOMLEFT", 50, 14, function()
        if state.q then Q:FindGroup(state.q) end
    end)

    return function()
        local log = self:Log()
        local locs = self:Locations()
        list:SetItems(log)
        if #log == 0 then empty:Show() else empty:Hide() end
        -- Auswahl halten (nach Quest-ID), sonst erste Quest
        local pick
        for _, q in ipairs(log) do if state.q and q.id == state.q.id then pick = q end end
        state.q = pick or log[1]
        local q = state.q
        if not q then
            card:Hide() return
        end
        card:Show()
        title:SetText(q.title .. (q.elite and ("  |cffff8040" .. T("(Elite)") .. "|r") or ""))
        local loc = locs[q.id] or (nav.QuestShare and nav.QuestShare:Location(q.id))
        where:SetText(T("Stufe %d", q.level) .. (q.tag and ("  ·  " .. q.tag) or "") ..
            (loc and ("  ·  " .. self:ZoneName(loc.mapID) .. (loc.edge and T(" (Richtung)") or "")) or ""))
        local i = 0
        if q.complete then i = 1 lines[1]:SetText("|cff66ff66" .. T("Erledigt – zurück zum Questgeber.") .. "|r") end
        for _, o in ipairs(q.objectives or {}) do
            i = i + 1
            if lines[i] then
                local text = o.text or ""
                if text:match("^%s*:") or text == "" then text = T("Ziel") .. ": " .. ("%d/%d"):format(o.numFulfilled or 0, o.numRequired or 0) end
                lines[i]:SetText((o.finished and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t  " or "•  ") .. text)
            end
        end
        for k = i + 1, #lines do lines[k]:SetText("") end
        hint:SetText(loc and (loc.from and T("Ort von %s (Gilde).", loc.from) or "")
            or T("Für diese Quest liefert das Spiel gerade keinen Ort – zum Beispiel, wenn sie auf einem anderen Kontinent liegt."))
        local QS = nav.QuestShare
        local who, n = "", 0
        if QS then who, n = QS:HoldersText(q.id) end
        guildHead:SetText(n > 0 and T("In der Gilde (%d)", n) or T("In der Gilde"))
        if n > 0 then guildText:SetText(who)
        elseif QS and not QS:IsSharing() then guildText:SetText(T("Niemand bekannt. Tipp: „Quests teilen“ in Optionen › Teilen einschalten – dann seht ihr gegenseitig, wer dieselbe Quest hat."))
        else guildText:SetText(T("Gerade hat niemand mit Guild Trip diese Quest.")) end
        if loc then go:Enable() else go:Disable() end
        local dungeons = ONE.modules and ONE.modules.dungeons
        if q.elite and dungeons and dungeons.PostQuestAd and ONE:IsEnabled("dungeons") then
            group:Show()
            group:SetText(dungeons.MyQuestAd and dungeons:MyQuestAd() == q.id and T("Gesuch ansehen") or T("Gruppe suchen"))
        else
            group:Hide()
        end
    end
end

function Q:Register()
    if not (ONE.UI and ONE.UI.AddTab and ONE.Kit) then return false end
    -- Seite bei Quest-Aenderungen auffrischen (nur wenn sie offen ist)
    local f = CreateFrame("Frame")
    for _, e in ipairs({"QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "ZONE_CHANGED_NEW_AREA"}) do pcall(f.RegisterEvent, f, e) end
    local last = 0
    f:SetScript("OnEvent", function()
        Q.dirty = true
        Q.Changed()
    end)
    if nav.QuestShare then nav.QuestShare.onChange = function() Q.Changed() end end
    function Q.Changed()
        local now = type(GetTime) == "function" and GetTime() or 0
        if now - last < 1 then return end
        last = now
        if ONE.UI.frame and ONE.UI.frame:IsShown() and ONE.UI.activeTab == "quests" then ONE.UI:Refresh() end
    end
    return ONE.UI:AddTab("quests", T("Quests"), function(panel) return self:Build(panel) end)
end
