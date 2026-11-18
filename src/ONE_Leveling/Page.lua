-- Guild Trip Quest-Fuehrung: Reiter "Leveln" (0.6.9) mit den Ansichten Plan | Ausgelassen | Questlog.
-- Plan/Ausgelassen: Page:Build; Questlog: ONE_Nav Quests:Build (eingebettet). Einstellungen: Optionen › Leveln (Settings.lua).
-- Links der Plan (Schritte), rechts "Warum diese Quest?" mit Zahlen, Belohnung und Knoepfen.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Page = {}
lev.Page = Page
local G = lev.Guide

local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(T(text)) end
    if ONE.Themes then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end

-- parent: Flaeche unter der Kopfzeile der Quest-Seite; mode: "guide" | "skipped"
function Page:Build(parent, W, H, getMode)
    local L, R
    local leftW = L and L.width or 420
    local rightX, rightW = R and R.x or (leftW + 14), R and R.width or (W - leftW - 14)
    local state = {}

    -- oben: Ziel, Tempo (aendern unter Optionen › Leveln)
    local goal = Text(parent, "GameFontHighlightSmall", 4, 0, leftW, "soft")
    local function Selected(item) return state.sel and item and state.sel.key == item.key end
    local list = ONE.Kit:List(parent, {x = 0, y = -26, width = leftW, height = H - 26, rowHeight = 22,
        columns = {
            {key = "text", title = "SCHRITT", width = leftW - 24 - 8 - 120, indent = 4},
            {key = "tags", title = "", width = 120, align = "RIGHT"},
        },
        render = function(row, item, cells)
            cells.text:SetText(item.text)
            cells.tags:SetText(item.tags or "")
            if item.header then cells.text:SetTextColor(1, .82, 0) elseif item.dim then cells.text:SetTextColor(.6, .6, .6)
            else cells.text:SetTextColor(1, 1, 1) end
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                row.selection:SetColorTexture(1, .82, 0, .14)
            end
            if Selected(item) or (item.current and not state.sel) then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, item)
            -- Gebietsuebersicht: Ueberschrift klappt auf/zu
            if item.header and item.zone then
                state.zoneOpen = state.zoneOpen or {}
                state.zoneOpen[item.zone] = not G.ZoneOpen(state, item.zone)
                ONE.UI:Refresh()
            elseif not item.header then state.sel = item ONE.UI:Refresh() end
        end,
    })
    local empty = Text(parent, "GameFontHighlight", 8, -70, leftW - 16, "soft")
    if empty.SetWordWrap then empty:SetWordWrap(true) end

    -- rechts: Warum?
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", rightX, -26)
    card:SetSize(rightW, H - 26)
    if ONE.Themes then ONE.Themes:RegisterPanel(card) end
    local title = Text(card, "GameFontNormalLarge", 14, -10, rightW - 28, "accent")
    local sub = Text(card, "GameFontHighlightSmall", 14, -34, rightW - 28, "soft")
    local rows = {}
    for i = 1, 6 do
        local a = Text(card, "GameFontHighlightSmall", 14, -56 - (i - 1) * 17, rightW - 100, "text")
        local b = Text(card, "GameFontHighlightSmall", rightW - 90, -56 - (i - 1) * 17, 76, "text")
        b:SetJustifyH("RIGHT")
        rows[i] = {a, b}
    end
    local verdict = Text(card, "GameFontHighlight", 14, -164, rightW - 28, "text")
    if verdict.SetWordWrap then verdict:SetWordWrap(true) end
    local valueHead = Text(card, "GameFontNormal", 14, -214, rightW - 28, "accent", "Belohnung")
    local valueText = Text(card, "GameFontHighlightSmall", 14, -232, rightW - 28, "text")
    if valueText.SetWordWrap then valueText:SetWordWrap(true) end
    -- Belohnungen als echte Spiel-Symbole (feste Belohnung und Auswahl), Tooltip vom Spiel
    local rewardIcons = {}
    local REWARD_SIZE, REWARD_MAX = 26, 6
    if not ONE.Widgets.Icon then REWARD_MAX = 0 end
    for i = 1, REWARD_MAX do
        local ic = ONE.Widgets:Icon(card, REWARD_SIZE)
        ic:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * (REWARD_SIZE + 8), -236)
        local f = ic.frame
        if f.EnableMouse then f:EnableMouse(true) end
        f:SetScript("OnEnter", function(self)
            if not (GameTooltip and ic.itemID) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not pcall(GameTooltip.SetItemByID, GameTooltip, ic.itemID) then GameTooltip:SetText(T("Gegenstand %d", ic.itemID)) end
            if ic.choice then GameTooltip:AddLine(T("Zur Auswahl – du bekommst einen davon."), .7, .8, 1, true) end
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        ic:Hide()
        rewardIcons[i] = ic
    end
    local function ShowRewards(qid)
        local D = _G.GuildTripLeveling
        local r = D and D.r and D.r[qid]
        local n = 0
        for _, part in ipairs({{r and r[4], false}, {r and r[5], true}}) do
            if type(part[1]) == "table" then
                for _, item in ipairs(part[1]) do
                    if n >= REWARD_MAX then break end
                    n = n + 1
                    local ic = rewardIcons[n]
                    ic.itemID, ic.choice = item, part[2]
                    ic:SetItem(item)
                    local info = D.i and D.i[item]
                    if info and info[2] then ic:SetQuality(info[2]) end
                    ic:Show()
                end
            end
        end
        for i = n + 1, REWARD_MAX do rewardIcons[i]:Hide() rewardIcons[i].itemID = nil end
        valueText:ClearAllPoints()
        valueText:SetPoint("TOPLEFT", card, "TOPLEFT", 14, n > 0 and -270 or -232)
    end
    local go = ONE.Widgets:NaviArrow(card, 22, "BOTTOMLEFT", 16, 16, function() if state.step then G:Navi(state.step) end end,
        function() return T("Navi zum Schritt"), state.step and G:StepText(state.step, true) or "" end)
    local toggle = ONE.Widgets:Button(card, T("Nicht machen"), 120, 24, "BOTTOMLEFT", 50, 14, function()
        if not state.qid then return end
        local o = G.plan and G.plan.info[state.qid]
        G:SetOverride(state.qid, (o and o.why) and "no" or "yes")
    end)
    local group = ONE.Widgets:Button(card, T("Gruppe suchen"), 120, 24, "BOTTOMLEFT", 176, 14, function()
        if state.qid then G:FindGroup(state.qid) end
    end)

    local function Items(plan, mode)
        local out = {}
        if mode == "journal" then
            local J = lev.Journal
            local out = {}
            if J then
                out[1] = {key = "js", header = true, text = "|cff9d9d9d" .. J:Summary() .. "|r"}
                for _, it in ipairs(J:Items(300)) do out[#out + 1] = it end
            end
            return out
        end
        if mode == "zones" then return G:ZoneItems(plan, state) end
        if mode == "skipped" then
            for _, o in ipairs(plan.skipped) do
                out[#out + 1] = {key = "s" .. o.id, qid = o.id, dim = true, text = G.Title(o.id) .. "  |cff9d9d9d" .. (lev.Planner.SkipText(o, plan, T) or "") .. "|r"}
            end
            return out
        end
        local lastMap
        for i, s in ipairs(plan.steps) do
            if s.mapID and s.mapID ~= lastMap then
                lastMap = s.mapID
                out[#out + 1] = {key = "h" .. i, header = true, text = G.BlockTitle(plan, s)}
            end
            local first = s.kind == "dungeon" and s.ids[1] or s.actions[1].id
            out[#out + 1] = {key = s.stopKey, step = s, qid = first, current = i == 1, text = G:StepText(s), tags = G:StepTags(s)}
        end
        return out
    end

    return function()
        local plan = G.plan or G:Replan()
        local mode = getMode and getMode() or "guide"
        local db = G:DB()
        if not plan then
            list:SetItems({})
            empty:SetText(G:Available() and T("Die Führung rechnet noch …") or T("Für die Führung fehlen die Questdaten (Guild Trip | Questdaten)."))
            empty:Show() card:Hide() goal:SetText("")
            return
        end
        local n, minutes = G:ToNextLevel()
        local nextText = ""
        if n then
            local m = math.max(1, math.floor(minutes + .5))
            nextText = "  ·  " .. ((n == 0 and T("nächste Stufe: ~%d min", m))
                or (n == 1 and T("nächste Stufe: 1 Abgabe, ~%d min", m))
                or T("nächste Stufe: %d Abgaben, ~%d min", n, m))
        end
        goal:SetText(T("Stufe %d von 60", plan.level) .. "  ·  " .. T("Tempo: %s", T(G.TEMPO_NAMES[db.tempo] or db.tempo)) .. nextText)
        local items = Items(plan, mode)
        list:SetItems(items)
        if #items == 0 then
            empty:SetText(mode == "skipped" and T("Nichts ausgelassen.") or mode == "zones" and T("Keine offenen Quests in deiner Nähe.") or mode == "journal" and T("Noch nichts erlebt – gib eine Quest ab, dann geht dein Tagebuch los.") or T("Gerade nichts zu tun – alle passenden Quests sind erledigt. Monster hauen oder ein Gebiet weiter."))
            empty:Show()
        else empty:Hide() end
        -- Auswahl halten, sonst der aktuelle Schritt
        local pick
        for _, it in ipairs(items) do if not it.header and state.sel and it.key == state.sel.key then pick = it end end
        -- ohne Auswahl: der aktuelle Schritt (nicht der Farm-Hinweis darueber)
        if not pick and not state.sel then for _, it in ipairs(items) do if it.current then pick = it break end end end
        if not pick then for _, it in ipairs(items) do if not it.header then pick = it break end end end
        state.sel, state.step, state.qid = pick, pick and pick.step, pick and pick.qid
        if not (pick and pick.qid) then card:Hide() return end
        card:Show()
        local lines, why, values, o = G:Why(pick.qid)
        title:SetText(G.Title(pick.qid))
        local e = o and o.e
        sub:SetText(e and (T("Stufe %d", e[1]) .. (o.giver and ("  ·  " .. G.ZoneName(o.giver.w[4])) or "")) or "")
        for i, r in ipairs(rows) do
            local l = lines and lines[i]
            r[1]:SetText(l and l[1] or "") r[2]:SetText(l and l[2] or "")
        end
        verdict:SetText(why or "")
        local hasValue = values and #values > 0
        valueText:SetText(hasValue and table.concat(values, "\n") or T("Nichts Besonderes für dich."))
        ShowRewards(pick.qid)
        if state.step then go:Enable() else go:Disable() end
        toggle:SetText(o and o.why and T("Nicht machen") or T("Doch machen"))
        if o and o.group then group:Show() else group:Hide() end
    end
end

-- ===== Reiter "Leveln" =====
Page.VIEWS = {{"guide", "Plan"}, {"zones", "Gebiete"}, {"skipped", "Ausgelassen"}, {"journal", "Tagebuch"}, {"log", "Questlog"}}
Page.SUBTITLE = {
    guide = "Nur die Quests, die sich lohnen – Dungeon-, Klassen- und Vorquests immer.",
    skipped = "Was die Führung auslässt und warum.",
    zones = "Alle Quests je Gebiet – nur zur Übersicht, der Plan bleibt die schnellste Route.",
    journal = "Deine Reise: Quests, Stufen, neue Gebiete und Dungeons – nur bei dir gespeichert.",
    log = "Deine Quests mit Fortschritt – „Navi“ zeigt die Richtung zum Ziel.",
}

function Page:BuildTab(panel)
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local L
    local header = {ONE.Widgets:PageHeader(panel, T("Leveln"), T(Page.SUBTITLE.guide), L and L.width or W)}
    local sub = header[2]
    local function Mode()
        local v = G:DB().view
        for _, d in ipairs(Page.VIEWS) do if d[1] == v then return v end end
        return "guide"
    end
    -- Ansichten oben rechts (wie auf den anderen Seiten)
    local buttons, right = {}, 0
    for k = #Page.VIEWS, 1, -1 do
        local d = Page.VIEWS[k]
        local b = ONE.Widgets:Button(panel, T(d[2]), 96, 20, "TOPRIGHT", right, -4, function()
            G:DB().view = d[1]
            ONE.UI:Refresh()
        end)
        right = right - 100
        buttons[d[1]] = b
    end
    local function Box(top)
        local box = CreateFrame("Frame", nil, panel)
        box:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, top)
        box:SetSize(W, H + top)
        return box
    end
    local guideBox = Box(-36)
    local guide = self:Build(guideBox, W, H - 36, function() local m = Mode() return (m == "skipped" or m == "zones" or m == "journal") and m or "guide" end)
    local logBox = Box(0)
    local nav = ONE.ns and ONE.ns.nav
    local log = nav and nav.Quests and nav.Quests:Build(logBox, true)
    return function()
        local mode = Mode()
        for k, b in pairs(buttons) do
            if b.LockHighlight then if k == mode then b:LockHighlight() else b:UnlockHighlight() end end
        end
        if sub and sub.SetText then sub:SetText(T(Page.SUBTITLE[mode] or "")) end
        guideBox:SetShown(mode ~= "log")
        logBox:SetShown(mode == "log")
        if mode == "log" then if log then log() end
        else guide() end
        local name = ({guide = "Plan", zones = "Gebiete", skipped = "Ausgelassen", journal = "Tagebuch", log = "Questlog"})[mode]
        if ONE.UI.SetContext then ONE.UI:SetContext("leveling", T(name)) end
    end
end

function Page:Register()
    if not (ONE.UI and ONE.UI.AddTab and ONE.Kit) then return false end
    lev.Settings:Register()
    return ONE.UI:AddTab("leveling", T("Leveln"), function(panel) return self:BuildTab(panel) end)
end
