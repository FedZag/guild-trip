-- Project ONE Dungeons: Seite "Dungeons" im ONE-Fenster (Blizzard-Look).
-- Links: alle Dungeons, nach Stufe eingefaerbt, mit Suche und "passend".
-- Rechts: Quests des gewaehlten Dungeons mit Status, darunter die Details
-- (Questgeber, Ort, Vorquests, Hinweise) und "Hinfuehren" mit dem ONE-Pfeil.
local _, dungeons = ...
local ONE = _G.ProjectONE
local function Paint(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Page = {}
dungeons.Page = Page

local ICONS = {
    done = "Interface\\RaidFrame\\ReadyCheck-Ready",
    log = "Interface\\GossipFrame\\ActiveQuestIcon",
    open = "Interface\\GossipFrame\\AvailableQuestIcon",
    locked = "Interface\\GossipFrame\\AvailableQuestIcon",
}
local STATUS_TEXT = {done = "Erledigt", log = "Im Questlog", open = "Annehmbar", locked = "Vorquests fehlen"}
local CLASS_NAMES = {PALADIN = "Paladin", MAGE = "Magier", WARLOCK = "Hexenmeister", SHAMAN = "Schamane",
    PRIEST = "Priester", WARRIOR = "Krieger", ROGUE = "Schurke", HUNTER = "Jäger", DRUID = "Druide"}

local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(T(text or ""))
    if ONE.Themes then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end

local function Byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + .5) end
local function Hex(c) return string.format("|cff%02x%02x%02x", Byte(c[1]), Byte(c[2]), Byte(c[3])) end

function Page:QuestIcon(row, status)
    if not row.icon then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    end
    row.icon:SetTexture(ICONS[status] or ICONS.open)
    if row.icon.SetDesaturated then row.icon:SetDesaturated(status == "locked") end
    if row.icon.SetAlpha then row.icon:SetAlpha(status == "locked" and .45 or 1) end
end

-- Kurzinfo rechts in der Questzeile
function Page:QuestTag(q)
    local M = dungeons.Model
    if q.classOnly then return T(CLASS_NAMES[q.classOnly] or q.classOnly) end
    local done, total = M:PrereqState(q)
    if total > 0 then return T("Vorquests %d/%d", done, total) end
    if q.dungeonDrop then return T("im Dungeon") end
    return ""
end

function Page:Build(panel)
    local M = dungeons.Model
    local store = M:Store()
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local leftW, gap = 290, 12
    local rightX, rightW = leftW + gap, W - leftW - gap
    local state = {selected = nil, quest = nil, list = {}}

    -- ===== Linke Spalte: Dungeonliste =====
    if not self.embedded then Text(panel, "GameFontNormalLarge", 0, -4, leftW, "accent", T("Dungeons")) end
    local okSearch, search = pcall(CreateFrame, "EditBox", nil, panel, "SearchBoxTemplate")
    if not okSearch or not search then search = CreateFrame("EditBox", nil, panel) end
    if ONE.Kit and ONE.Kit.StyleEdit then ONE.Kit.StyleEdit(search) end
    search:SetSize(leftW - 8, 22)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -30)
    if search.SetAutoFocus then search:SetAutoFocus(false) end
    local okCheck, check = pcall(CreateFrame, "CheckButton", nil, panel, "UICheckButtonTemplate")
    if not okCheck or not check then check = CreateFrame("CheckButton", nil, panel) end
    if ONE.Kit and ONE.Kit.StyleCheck then ONE.Kit:StyleCheck(check) end
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -56)
    if check.SetChecked then check:SetChecked(store.suitableOnly) end
    local checkLabel = Text(panel, "GameFontHighlight", 26, -61, leftW - 26, "text")
    -- Auswahl mit Zaehlern statt Haekchen (Fuer deine Stufe, Alle, Stufenbereiche, mit offenen Quests)
    local category
    if ONE.Kit and ONE.Kit.Dropdown then
        check:Hide() checkLabel:Hide()
        if not store.category then store.category = store.suitableOnly and "level" or "all" end
        category = ONE.Kit:Dropdown(panel, {point = "TOPLEFT", x = 0, y = -56, width = leftW,
            options = function() return Page:CategoryOptions() end,
            get = function() return store.category end,
            set = function(v) store.category = v end,
            onChange = function() Page:Refresh() end})
    end
    local dungeonList
    dungeonList = ONE.Kit:List(panel, {x = 0, y = -86, width = leftW, height = H - 86, rowHeight = 24,
        columns = {
            {key = "name", title = "DUNGEON", width = false and 142 or 116},
            {key = "level", title = "STUFE", width = false and 46 or 40, align = "CENTER"},
            {key = "open", title = "OFFEN", width = false and 46 or 38, align = "CENTER"},
            {key = "guild", title = "GILDE", width = false and 46 or 38, align = "CENTER"},
        },
        render = function(row, d, cells)
            local selected = state.selected and state.selected.key == d.key
            cells.name:SetText(d.name)
            cells.name:SetTextColor(d.color[1], d.color[2], d.color[3])
            cells.level:SetText(d.min == d.max and tostring(d.min) or (d.min .. "–" .. d.max))
            cells.level:SetTextColor(.9, .9, .9)
            if not d.hasData then cells.open:SetText("–") cells.open:SetTextColor(.5, .5, .5)
            elseif d.open == 0 then cells.open:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t") cells.open:SetTextColor(1, 1, 1)
            else cells.open:SetText(tostring(d.open)) cells.open:SetTextColor(1, .82, 0) end
            local needers = dungeons.Share and #dungeons.Share:Needers(d.key) or 0
            cells.guild:SetText(needers > 0 and tostring(needers) or "")
            cells.guild:SetTextColor(.5, .9, .5)
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                Paint(row.selection, 1, .82, 0, .14)
            end
            if selected then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, d) state.selected, state.quest = d, nil Page:Refresh() end,
        onEnter = function(row, d)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(d.name)
            if d.en and d.en ~= d.name then GameTooltip:AddLine(d.en, .62, .62, .62) end
            GameTooltip:AddLine(T("Stufe %d–%d", d.min, d.max), 1, 1, 1)
            if d.hasData then
                GameTooltip:AddLine(T("%d von %d Quests erledigt", d.done, #d.quests), .8, .8, .8)
            else
                GameTooltip:AddLine(T("Noch keine Questdaten (neuer Forever-Dungeon)"), .7, .7, .7)
            end
            for _, n in ipairs(dungeons.Share and dungeons.Share:Needers(d.key) or {}) do
                GameTooltip:AddLine(T("Gilde: %s (%d) – %d offen", dungeons.Share.Short(n.name), n.level, n.open), .5, .9, .5)
            end
            GameTooltip:Show()
        end,
    })

    -- ===== Rechte Spalte: Dungeon-Karte =====
    local card = CreateFrame("Frame", nil, panel)
    card:SetPoint("TOPLEFT", panel, "TOPLEFT", rightX, 0)
    card:SetSize(rightW, H)
    if ONE.Themes then ONE.Themes:RegisterPanel(card) end
    -- 0.6.8 Blizzard-Aussehen: gezeichnete Karte als Kopfbild (scripts/build_maps.py), links
    -- abgedunkelt, damit Titel und Angaben lesbar bleiben; je Dungeon fest eine von vier Landschaften
    local banner, bannerLift
    banner = card:CreateTexture(nil, "BACKGROUND", nil, 2)
    banner:SetPoint("TOPLEFT", card, "TOPLEFT", 3, -3)
    banner:SetPoint("TOPRIGHT", card, "TOPRIGHT", -3, -3)
    banner:SetHeight(88)
    -- 0.8: echter Ladebildschirm des Dungeons (Art.lua); dunkle Bilder werden mit einer
    -- zweiten, addierten Lage aufgehellt. Ohne Bild: gezeichnete Karte (Map1-4).
    bannerLift = card:CreateTexture(nil, "BACKGROUND", nil, 3)
    bannerLift:SetAllPoints(banner)
    bannerLift:Hide()
    local shade = card:CreateTexture(nil, "BACKGROUND", nil, 4)
    shade:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
    shade:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
    shade:SetColorTexture(1, 1, 1, 1)
    local dark, clear = {0, 0, 0, .86}, {0, 0, 0, .05}
    local done = type(CreateColor) == "function" and shade.SetGradient
        and pcall(shade.SetGradient, shade, "HORIZONTAL", CreateColor(unpack(dark)), CreateColor(unpack(clear)))
    if not done and shade.SetGradientAlpha then
        done = pcall(shade.SetGradientAlpha, shade, "HORIZONTAL", 0, 0, 0, .86, 0, 0, 0, .05)
    end
    if not done then shade:SetColorTexture(0, 0, 0, .55) end
    local edge = card:CreateTexture(nil, "BORDER", nil, 2)
    edge:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, 0)
    edge:SetPoint("TOPRIGHT", banner, "BOTTOMRIGHT", 0, 0)
    edge:SetHeight(1)
    edge:SetColorTexture(.79, .64, .29, .6)
    local inner = rightW - 32
    local title = Text(card, "GameFontNormalHuge", 16, -14, inner - 32, "accent")
    if title.SetWordWrap then title:SetWordWrap(false) end
    -- Navi zum Dungeon-Eingang (Entrances.lua); Herkunft des Orts im Tooltip
    -- kleiner Navi-Pfeil (wie ueberall) oben rechts; Herkunft des Orts im Tooltip
    local entrance = ONE.Widgets:NaviArrow(card, 22, "TOPRIGHT", -16, -16, function()
        if state.selected and dungeons.Entrances then dungeons.Entrances:Navi(state.selected) end
    end, function()
        local d = state.selected
        local e = d and dungeons.Entrances and dungeons.Entrances:Get(d.key)
        return T("Navi zum Eingang"), e and T("Ort: %s", dungeons.Entrances:SourceText(e.source))
            or T("Noch unbekannt – betritt den Dungeon einmal, dann merkt Guild Trip sich den Eingang.")
    end)
    local sub = Text(card, "GameFontHighlight", 16, -42, inner, "text")
    if sub.SetWordWrap then sub:SetWordWrap(false) end
    local guildLine = Text(card, "GameFontHighlight", 16, -61, inner - 136, "text")
    if guildLine.SetWordWrap then guildLine:SetWordWrap(false) end
    -- volle Namensliste beim Drueberfahren (die Zeile zeigt nur, was hineinpasst)
    local guildHover = CreateFrame("Frame", nil, card)
    guildHover:SetPoint("TOPLEFT", guildLine, "TOPLEFT", 0, 2)
    guildHover:SetSize(inner - 136, 18)
    if guildHover.EnableMouse then guildHover:EnableMouse(true) end
    guildHover:SetScript("OnEnter", function(self)
        if not (GameTooltip and self.names and #self.names > 0) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(T("Auch offen bei:"), 1, .82, 0)
        for _, n in ipairs(self.names) do GameTooltip:AddLine(n, 1, 1, 1) end
        GameTooltip:Show()
    end)
    guildHover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local keyNote = Text(card, "GameFontHighlightSmall", 16, -78, inner, "soft")
    if keyNote.SetWordWrap then keyNote:SetWordWrap(false) end
    local seek = ONE.Widgets:Button(card, T("Gruppe suchen"), 124, 22, "TOPRIGHT", -12, -56, function()
        if dungeons.Share and dungeons.Share.myAd then ONE.UI:OpenLink("groups")
        elseif state.selected then Page:OpenSeekDialog(state.selected) end
    end)
    local questList = ONE.Kit:List(card, {x = 8, y = -94, width = rightW - 16, height = 22 * 7 + 22, rowHeight = 22,
        columns = false and {
            {key = "name", title = "QUEST", width = rightW - 16 - 24 - 6 - 46 - 46 - 16, indent = 20},
            {key = "level", title = "STUFE", width = 46, align = "CENTER"},
            {key = "guild", title = "GILDE", width = 46, align = "CENTER"},
        } or {
            {key = "name", title = "QUEST", width = rightW - 16 - 24 - 6 - 40 - 92 - 34 - 24, indent = 20},
            {key = "level", title = "STUFE", width = 40, align = "CENTER"},
            {key = "tag", title = "HINWEIS", width = 92},
            {key = "guild", title = "GILDE", width = 34, align = "CENTER"},
        },
        render = function(row, q, cells)
            local status = M:Status(q)
            Page:QuestIcon(row, status)
            cells.name:SetText(M:Title(q))
            local done = status == "done"
            cells.name:SetTextColor(done and .55 or 1, done and .55 or .82, done and .55 or 0)
            cells.level:SetText(q.level and tostring(q.level) or "")
            cells.level:SetTextColor(.9, .9, .9)
            if cells.tag then
                cells.tag:SetText(Page:QuestTag(q))
                cells.tag:SetTextColor(q.classOnly and .4 or .75, q.classOnly and .8 or .75, q.classOnly and 1 or .75)
            else
                local tag = Page:QuestTag(q)
                if tag and tag ~= "" then cells.name:SetText(M:Title(q) .. "  |cff8c7a66(" .. tag .. ")|r") end
            end
            local needers = (dungeons.Share and state.selected) and #dungeons.Share:QuestNeeders(state.selected.key, q) or 0
            cells.guild:SetText(needers > 0 and ("+" .. needers) or "")
            cells.guild:SetTextColor(.5, .9, .5)
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                Paint(row.selection, 1, .82, 0, .14)
            end
            if state.quest == q then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, q) state.quest = q Page:Refresh() end,
        onEnter = function(row, q)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(M:Title(q))
            GameTooltip:AddLine(T(STATUS_TEXT[M:Status(q)] or ""), 1, 1, 1)
            if dungeons.Share and state.selected then
                for _, n in ipairs(dungeons.Share:QuestNeeders(state.selected.key, q)) do
                    GameTooltip:AddLine(T("Braucht auch: %s (%d)", dungeons.Share.Short(n.name), n.level), .5, .9, .5)
                end
            end
            GameTooltip:AddLine(T("Klicken für Details"), .7, .7, .7)
            GameTooltip:Show()
        end,
    })
    local noData = Text(card, "GameFontHighlight", 16, -120, inner, "soft")
    if noData.SetWordWrap then noData:SetWordWrap(true) end

    -- Detailbereich unter der Questliste (scrollbar fuer lange Vorquest-Ketten)
    local detailTop = -94 - (22 * 7 + 22) - 8
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", card, "TOPLEFT", 16, detailTop)
    rule:SetSize(inner, 1)
    Paint(rule, 1, .82, 0, .3)
    local detailH = H + detailTop - 44
    local okScroll, scroll = pcall(CreateFrame, "ScrollFrame", nil, card, "UIPanelScrollFrameTemplate")
    if not okScroll or not scroll then scroll = CreateFrame("ScrollFrame", nil, card) end
    if ONE.Kit and ONE.Kit.StyleScroll then ONE.Kit.StyleScroll(scroll) end
    scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 16, detailTop - 8)
    scroll:SetSize(inner - 24, detailH)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(inner - 30, detailH)
    if scroll.SetScrollChild then scroll:SetScrollChild(child) end
    local detail = Text(child, "GameFontHighlight", 0, 0, inner - 34, "text")
    if detail.SetWordWrap then detail:SetWordWrap(true) end
    if detail.SetJustifyV then detail:SetJustifyV("TOP") end
    -- kleiner Navi-Pfeil zum Questgeber (wie ueberall im Addon)
    local guide = ONE.Widgets:NaviArrow(card, 22, "BOTTOMRIGHT", -16, 12, function()
        local q = state.quest
        local navi = ONE.modules and ONE.modules.nav
        local mapID = q and M:MapFor(q)
        if q and mapID and q.x and navi and type(navi.PointTo) == "function" then
            navi:PointTo((q.giver or M:Title(q)), mapID, q.x, q.y)
        end
    end, function()
        local q = state.quest
        return q and T("Navi zu %s", q.giver or M:Title(q)) or nil, q and q.location or nil
    end)
    -- Quellenangabe (MIT) vollstaendig: notfalls zweizeilig neben "Hinfuehren"
    local credit = Text(card, "GameFontDisableSmall", 16, -(H - 36), rightW - 60, "soft",
        T("Quest-Daten: Forever Dungeon Quests (Sundee, MIT)"))
    if credit.SetWordWrap then credit:SetWordWrap(true) end
    if credit.SetMaxLines then credit:SetMaxLines(2) end

    local function Changed() Page:Refresh() end
    if search.HookScript then search:HookScript("OnTextChanged", Changed) end
    check:SetScript("OnClick", function(self)
        store.suitableOnly = self.GetChecked and self:GetChecked() and true or false
        Changed()
    end)

    local function DetailText(q)
        local lines = {}
        local status = M:Status(q)
        lines[#lines + 1] = "|cffffd100" .. M:Title(q) .. "|r   " .. T(STATUS_TEXT[status] or "")
        if q.name and q.name ~= M:Title(q) then lines[#lines + 1] = "|cff9d9d9d(" .. q.name .. ")|r" end
        local where = q.location or "?"
        if q.x then where = where .. string.format("  (%.0f, %.0f)", q.x * 100, q.y * 100) end
        lines[#lines + 1] = T("Questgeber: %s", q.giver or "?")
        lines[#lines + 1] = T("Ort: %s", where)
        if q.classOnly then lines[#lines + 1] = T("Nur für: %s", T(CLASS_NAMES[q.classOnly] or q.classOnly)) end
        if q.prereqs then
            lines[#lines + 1] = " "
            lines[#lines + 1] = "|cffffd100" .. T("Vorquests") .. "|r"
            for _, p in ipairs(q.prereqs) do
                local mark = (p.ids and M:IsDone(p.ids)) and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " or "|cffaaaaaa-|r "
                local info = dungeons.QuestData and dungeons.QuestData.prereqInfo and dungeons.QuestData.prereqInfo[p.name]
                local title = p.ids and M:Title({ids = p.ids, name = p.name}) or p.name
                lines[#lines + 1] = mark .. title .. (info and info.giver and ("  –  " .. info.giver
                    .. (info.location and (", " .. info.location) or "")) or "")
            end
        end
        if dungeons.Share and state.selected then
            local names = {}
            for _, n in ipairs(dungeons.Share:QuestNeeders(state.selected.key, q)) do
                names[#names + 1] = dungeons.Share.Short(n.name)
            end
            if #names > 0 then lines[#lines + 1] = "|cff80e680" .. T("Braucht auch: %s", table.concat(names, ", ")) .. "|r" end
        end
        if q.notes and q.notes ~= "" then
            lines[#lines + 1] = " "
            lines[#lines + 1] = "|cffbbbbbb" .. q.notes .. "|r"
        end
        return table.concat(lines, "\n")
    end

    self.refresh = function()
        local level = M:PlayerLevel()
        checkLabel:SetText(T("Nur passend zu Stufe %d", level))
        local query = string.lower(search.GetText and search:GetText() or "")
        local all = M:Dungeons()
        local items = {}
        self.lastAll = all
        if category and category.Refresh then category:Refresh() end
        for _, d in ipairs(all) do
            local okLevel
            if category then okLevel = Page.InCategory(d, store.category) else okLevel = not store.suitableOnly or d.suitable end
            local hay = string.lower(d.name .. " " .. (d.en or ""))
            if okLevel and (query == "" or hay:find(query, 1, true)) then items[#items + 1] = d end
        end
        -- Auswahl halten (nach Schluessel), sonst den ersten passenden Dungeon zeigen
        local selected
        for _, d in ipairs(items) do if state.selected and d.key == state.selected.key then selected = d end end
        state.selected = selected or items[1]
        dungeonList:SetItems(items)
        local d = state.selected
        if not d then
            guildLine:SetText("")
            seek:Hide() entrance:Hide()
            title:SetText(T("Kein Dungeon gefunden"))
            sub:SetText(T("Suche ändern oder „Nur passend“ ausschalten."))
            keyNote:SetText("")
            questList:SetItems({})
            noData:SetText("")
            detail:SetText("")
            guide:Hide()
            return
        end
        title:SetText(d.name)
        if banner then Page.PaintBanner(banner, bannerLift, d.key, rightW - 6, 88) end
        sub:SetText(((d.en and d.en ~= d.name) and ("|cff9d9d9d" .. d.en .. "|r   ·   ") or "")
            .. Hex(d.color) .. "Stufe " .. d.min .. "–" .. d.max .. "|r"
            .. (d.hasData and ("   ·   " .. d.done .. "/" .. #d.quests .. " erledigt") or ""))
        keyNote:SetText(d.keyNote or "")
        seek:Show()
        entrance:Show()
        if dungeons.Entrances and dungeons.Entrances:Get(d.key) then entrance:Enable() else entrance:Disable() end
        seek:SetText(dungeons.Share and dungeons.Share.myAd and T("Mein Gesuch") or T("Gruppe suchen"))
        local S = dungeons.Share
        local needers = S and S:Needers(d.key) or {}
        guildHover.names = nil
        if #needers > 0 then
            local all = {}
            for _, n in ipairs(needers) do all[#all + 1] = Page:ClassName(n.class, S.Short(n.name)) .. " (" .. n.level .. ")" end
            guildHover.names = all
            -- so viele Namen, wie in die Zeile passen, Rest als "+n"
            local head = "|cffffd100" .. T("Auch offen bei:") .. "|r "
            local maxW = inner - 136
            local shown = {}
            for i, name in ipairs(all) do
                shown[#shown + 1] = name
                local rest = #all - i
                guildLine:SetText(head .. table.concat(shown, " · ") .. (rest > 0 and ("  +" .. rest) or ""))
                local w = guildLine.GetStringWidth and guildLine:GetStringWidth() or 0
                if w > maxW and #shown > 1 then
                    shown[#shown] = nil
                    guildLine:SetText(head .. table.concat(shown, " · ") .. "  +" .. (#all - #shown))
                    break
                end
            end
        elseif S and not S:IsSharing() then
            guildLine:SetText("|cff9d9d9d" .. T("Gilde: „Fortschritt teilen“ ist aus") .. "|r")
        else
            guildLine:SetText("|cff9d9d9d" .. T("Gilde: niemand mit offenen Quests") .. "|r")
        end
        M:RequestTitles(d.quests)
        questList:SetItems(d.quests)
        if not d.hasData then
            noData:SetText(T("Für diesen Dungeon gibt es noch keine Questdaten. Er ist neu in WoW Forever – "
                .. "sobald die Quelle ihn ergänzt, erscheint er hier mit allen Quests."))
        elseif #d.quests == 0 then
            noData:SetText(T("Für deine Fraktion und Klasse gibt es hier keine Quests."))
        else
            noData:SetText("")
        end
        local q = state.quest
        local stillThere = false
        for _, item in ipairs(d.quests) do if item == q then stillThere = true end end
        if not stillThere then q = nil state.quest = nil end
        if q then
            detail:SetText(DetailText(q))
            local h = (detail.GetStringHeight and detail:GetStringHeight() or 0) + 8
            child:SetHeight(math.max(detailH, h))
            ONE.Kit.ShowScrollBar(scroll, h > detailH)
            local canGuide = M:MapFor(q) ~= nil and q.x ~= nil and ONE.modules and ONE.modules.nav ~= nil
            if canGuide then guide:Show() else guide:Hide() end
        else
            detail:SetText(#d.quests > 0 and "|cffaaaaaa" .. T("Quest anklicken für Questgeber, Ort und Vorquests.") .. "|r" or "")
            ONE.Kit.ShowScrollBar(scroll, false)
            guide:Hide()
        end
    end
    return self.refresh
end

function Page:Refresh() if self.refresh then self.refresh() end end

-- Kopfbild: Ladebildschirm aus dem Client, sonst die gezeichnete Karte
function Page.PaintBanner(tex, lift, key, w, h)
    local aspect = w / math.max(1, h)
    if dungeons.Art and dungeons.Art:Apply(tex, key, aspect, lift) then return "picture" end
    if lift then lift:Hide() end
    tex:SetTexture("Interface\\AddOns\\ONE_Dungeons\\Textures\\Map" .. Page.MapVariant(key))
    -- Kartenbild 4:1 -> oben/unten etwas abschneiden statt verzerren
    local frac = math.min(1, (4 * h) / math.max(1, w))
    tex:SetTexCoord(0, 1, (1 - frac) / 2, 1 - (1 - frac) / 2)
    return "map"
end
-- Kartenbild je Dungeon: fest (aus dem Schluessel), eine von vier Landschaften
function Page.MapVariant(key)
    local h = 0
    for i = 1, #(key or "") do h = (h * 31 + key:byte(i)) % 9973 end
    return h % 4 + 1
end
-- Auswahl links: Kategorien mit Zaehlern
local BANDS = {{10, 19}, {20, 29}, {30, 39}, {40, 49}, {50, 60}}
function Page.InCategory(d, cat)
    if cat == "all" or cat == nil then return true end
    if cat == "level" then return d.suitable end
    if cat == "open" then return d.hasData and (d.open or 0) > 0 end
    local lo = tonumber(cat)
    if lo then
        for _, b in ipairs(BANDS) do if b[1] == lo then return d.min >= b[1] and d.min <= b[2] end end
    end
    return false
end
function Page:CategoryOptions()
    local all = self.lastAll or (dungeons.Model and dungeons.Model:Dungeons()) or {}
    local function Count(cat)
        local n = 0
        for _, d in ipairs(all) do if Page.InCategory(d, cat) then n = n + 1 end end
        return n
    end
    local level = dungeons.Model and dungeons.Model:PlayerLevel() or 0
    local out = {{value = "level", text = T("Für deine Stufe (%d) · %d", level, Count("level"))},
        {value = "all", text = T("Alle Dungeons · %d", Count("all"))},
        {value = "open", text = T("Mit offenen Quests · %d", Count("open"))}}
    for _, b in ipairs(BANDS) do
        local n = Count(tostring(b[1]))
        if n > 0 then out[#out + 1] = {value = tostring(b[1]), text = T("Stufe %d–%d · %d", b[1], b[2], n)} end
    end
    return out
end

function Page:ClassName(class, text)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c and c.colorStr then return "|c" .. c.colorStr .. text .. "|r" end
    if c and c.r then return string.format("|cff%02x%02x%02x%s|r", Byte(c.r), Byte(c.g), Byte(c.b), text) end
    return text
end

-- Kleines Blizzard-Fenster: Gruppengesuch fuer den gewaehlten Dungeon.
function Page:OpenSeekDialog(d)
    local S = dungeons.Share
    if not S then return end
    local f = self.dialog
    if not f then
        -- Eigenes Blizzard-Fenster UEBER dem ONE-Fenster (hoehere Ebene), mit
        -- deckendem Hintergrund und Mausfang, damit nichts durchscheint oder durchklickt.
        local ok, frame = pcall(CreateFrame, "Frame", "ProjectONEGroupDialog", UIParent, "BasicFrameTemplateWithInset")
        f = ok and frame or CreateFrame("Frame", "ProjectONEGroupDialog", UIParent)
        f:SetSize(340, 236)
        f:SetPoint("CENTER", ONE.UI.frame or UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        if f.SetFrameLevel then f:SetFrameLevel(100) end
        if f.SetToplevel then f:SetToplevel(true) end
        if f.EnableMouse then f:EnableMouse(true) end
        local shade = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        shade:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
        shade:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
        shade:SetColorTexture(.05, .04, .03, .97)
        if UISpecialFrames then table.insert(UISpecialFrames, "ProjectONEGroupDialog") end
        if ONE.UI.frame and ONE.UI.frame.HookScript then
            ONE.UI.frame:HookScript("OnHide", function() f:Hide() end)
        end
        f.title = Text(f, "GameFontNormal", 14, -6, 300, "accent")
        Text(f, "GameFontHighlight", 16, -36, 300, "text", T("Wen suchst du noch?"))
        f.roles = {}
        for i, key in ipairs({"T", "H", "D"}) do
            local okC, c = pcall(CreateFrame, "CheckButton", nil, f, "UICheckButtonTemplate")
            if not okC or not c then c = CreateFrame("CheckButton", nil, f) end
            if ONE.Kit and ONE.Kit.StyleCheck then ONE.Kit:StyleCheck(c) end
            c:SetSize(32, 24)
            c:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * 104, -56)
            local label = Text(f, "GameFontHighlight", 0, 0, 70, "text", S:RoleName(key))
            label:ClearAllPoints()
            label:SetPoint("LEFT", c, "RIGHT", 4, 0)
            f.roles[key] = c
        end
        Text(f, "GameFontHighlight", 16, -94, 300, "text", T("Notiz (optional):"))
        local okE, edit = pcall(CreateFrame, "EditBox", nil, f, "InputBoxTemplate")
        if not okE or not edit then edit = CreateFrame("EditBox", nil, f) end
        if ONE.Kit and ONE.Kit.StyleEdit then ONE.Kit.StyleEdit(edit) end
        edit:SetSize(296, 22)
        edit:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -114)
        if edit.SetAutoFocus then edit:SetAutoFocus(false) end
        if edit.SetMaxLetters then edit:SetMaxLetters(80) end
        f.note = edit
        Text(f, "GameFontDisableSmall", 16, -146, 308, "soft",
            T("Alle Gildenmitglieder mit Guild Trip sehen dein Gesuch. Es endet nach 30 Minuten oder wenn du es schließt."))
        ONE.Widgets:Button(f, T("Gesuch aufgeben"), 150, 26, "BOTTOMLEFT", 14, 14, function()
            local roles = {}
            for _, key in ipairs({"T", "H", "D"}) do
                if f.roles[key].GetChecked and f.roles[key]:GetChecked() then roles[#roles + 1] = key end
            end
            if #roles == 0 then roles = {"T", "H", "D"} end
            S:PostAd(f.dungeon.key, table.concat(roles, ","), 1, f.note.GetText and f.note:GetText() or "")
            f:Hide()
            ONE.UI:OpenLink("groups")
        end)
        ONE.Widgets:Button(f, T("Abbrechen"), 120, 26, "BOTTOMRIGHT", -14, 14, function() f:Hide() end)
        self.dialog = f
    end
    f.dungeon = d
    f.title:SetText(T("Gruppe suchen: %s", d.name))
    for _, c in pairs(f.roles) do if c.SetChecked then c:SetChecked(false) end end
    if f.note.SetText then f.note:SetText("") end
    f:Show()
    return f
end

-- Startseiten-Kachel: bester Dungeon fuer die eigene Stufe mit offenen Quests.
function Page:Tile(card, body)
    local first = body:Text("", "body", "text")
    local second = body:Text("", "small", "soft")
    body:Action(T("Dungeons öffnen"), function() ONE.UI:OpenLink("dungeons") end)
    return function()
        local best
        for _, d in ipairs(dungeons.Model:Dungeons()) do
            if d.suitable and d.open > 0 and (not best or d.min < best.min) then best = d end
        end
        if best then
            first:SetText(best.name)
            second:SetText(best.open == 1 and T("1 Quest offen") or T("%d Quests offen", best.open))
        else
            first:SetText(T("Alles erledigt"))
            second:SetText(T("Keine offenen Dungeon-Quests"))
        end
    end
end

-- Ein Reiter fuer Dungeons und Gruppen: Umschalter oben links.
function Page:BuildCombined(panel)
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local dv = CreateFrame("Frame", nil, panel)
    dv:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    dv:SetSize(W, H)
    local gv = CreateFrame("Frame", nil, panel)
    gv:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    gv:SetSize(W, H)
    local tv = CreateFrame("Frame", nil, panel)
    tv:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    tv:SetSize(W, H)
    self.embedded, dungeons.Groups.embedded = true, true
    local refreshD = self:Build(dv)
    local refreshG = dungeons.Groups:Build(gv)
    local refreshT = dungeons.TripsPage and dungeons.TripsPage:Build(tv)
    -- Die drei Umschalter muessen in die linke Spalte passen (290, im Buch die linke Seite);
    -- bis 0.6.4 ragte "Ausfluege" unter die rechte Karte.
    local L = false
    local span = L and L.width or 290
    local bw = math.floor((span - 8) / 3)
    local bD = ONE.Widgets:Button(panel, "Dungeons", bw, 24, "TOPLEFT", 0, -2, function() Page:ShowView("dungeons") end)
    local bG = ONE.Widgets:Button(panel, "Gruppen", bw, 24, "TOPLEFT", bw + 4, -2, function() Page:ShowView("groups") end)
    local bT = ONE.Widgets:Button(panel, "Ausflüge", span - 2 * (bw + 4), 24, "TOPLEFT", 2 * (bw + 4), -2, function() Page:ShowView("trips") end)
    self.combined = {dv = dv, gv = gv, tv = tv, refreshD = refreshD, refreshG = refreshG, refreshT = refreshT, bD = bD, bG = bG, bT = bT}
    -- 0.6.8: Reisepass als vierte Ansicht (nur Blizzard-Aussehen; im Buch bleibt alles wie es war)
    if dungeons.PassPage and not (false) and ONE.UI.sidebar then
        local pv = CreateFrame("Frame", nil, panel)
        pv:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        pv:SetSize(W, H)
        self.combined.pv = pv
        self.combined.refreshP = dungeons.PassPage:Build(pv)
    end
    -- 0.6.8: mit Symbolleiste stehen die drei Ansichten oben in der Kopfzeile
    if ONE.UI.SetViews and ONE.UI:SetViews("dungeons", self:HeaderViews(), "dungeons") then
        ONE.UI:RetireButtons(bD, bG, bT)
        self.headerViews = true
    end
    return function() Page:RefreshCombined() end
end

function Page:HeaderViews(nG, nT)
    local function Go(key) Page:ShowView(key) end
    return {{key = "dungeons", label = T("Dungeons"), onClick = Go},
        {key = "groups", label = (nG or 0) > 0 and T("Gruppen (%d)", nG) or T("Gruppen"), onClick = Go},
        {key = "trips", label = (nT or 0) > 0 and T("Ausflüge (%d)", nT) or T("Ausflüge"), onClick = Go},
        self.combined and self.combined.pv and {key = "pass", label = T("Reisepass"), onClick = Go} or nil}
end

function Page:ShowView(view)
    self.view = view
    self:RefreshCombined()
end

function Page:RefreshCombined()
    local c = self.combined
    if not c then return end
    local S = dungeons.Share
    local n = S and type(S.Ads) == "function" and #S:Ads() or 0
    c.bG:SetText(n > 0 and T("Gruppen (%d)", n) or T("Gruppen"))
    local nt = dungeons.Trips and #dungeons.Trips:List() or 0
    c.bT:SetText(nt > 0 and T("Ausflüge (%d)", nt) or T("Ausflüge"))
    local view = (self.view == "groups" or self.view == "trips" or (self.view == "pass" and c.pv)) and self.view or "dungeons"
    if self.headerViews then ONE.UI:SetViews("dungeons", self:HeaderViews(n, nt), view) end
    local frames = {dungeons = c.dv, groups = c.gv, trips = c.tv, pass = c.pv}
    local buttons = {dungeons = c.bD, groups = c.bG, trips = c.bT}
    for key, f in pairs(frames) do if key == view then f:Show() else f:Hide() end end
    for key, b in pairs(buttons) do
        if key == view then if b.LockHighlight then b:LockHighlight() end
        elseif b.UnlockHighlight then b:UnlockHighlight() end
    end
    if view == "groups" then if c.refreshG then c.refreshG() end
    elseif view == "trips" then if c.refreshT then c.refreshT() end
    elseif view == "pass" then if c.refreshP then c.refreshP() end
    elseif c.refreshD then c.refreshD() end
end

function Page:Register()
    if not (ONE.UI and ONE.UI.AddTab and ONE.Kit) then return false end
    ONE.Kit:RegisterTile("dungeons", {title = "DUNGEONS", order = 25,
        build = function(card, body) return Page:Tile(card, body) end})
    local ok = ONE.UI:AddTab("dungeons", T("Dungeons"), function(panel) return self:BuildCombined(panel) end)
    -- Gilde-Seite "Was steht an": offene Gruppengesuche
    if ONE.UI.AddFeed then
        ONE.UI:AddFeed("groups", function()
            local S, out = dungeons.Share, {}
            for _, ad in ipairs(S:Ads()) do
                local fits = S:Fit(ad)
                out[#out + 1] = {icon = "Interface\\Icons\\INV_Sword_04", link = "groups", sort = fits and 5 or 20,
                    text = T("%s sucht Gruppe: %s", S.Short(ad.owner), S:DungeonName(ad.key))}
            end
            return out
        end)
    end
    -- Gruppenfinder: Rolle in Optionen › Dungeons (Hinweise = Funktion "dungeons.notify")
    if ONE.UI.AddSetting and dungeons.Share then
        local S = dungeons.Share
        local function Changed() if dungeons.Groups and dungeons.Groups.Refresh then dungeons.Groups:Refresh() end end
        ONE.UI:AddSetting({id = "groupRole", category = "dungeons", section = "Gruppen", order = 20, kind = "dropdown", width = 200,
            label = "Deine Rolle",
            options = function()
                return {{value = "T", text = S:RoleName("T")}, {value = "H", text = S:RoleName("H")}, {value = "D", text = S:RoleName("D")}}
            end,
            get = function() return S:Settings().role or "D" end, set = function(v) S:Settings().role = v Changed() end})
    end
    if ONE.UI.AddShareOption then
        ONE.UI:AddShareOption({id = "dungeons", module = "dungeons", order = 20, label = "Dungeon-Fortschritt teilen",
            tooltip = "Gildenmitglieder mit Guild Trip sehen, welche Dungeon-Quests du noch offen hast. Dazu gehen von dir gefundene Dungeon-Eingänge an die Gilde.",
            get = function() return dungeons.Share:IsSharing() end, set = function(on) dungeons.Share:SetSharing(on) end})
    end
    -- frueherer Reiter "Gruppen": oeffnet jetzt die Gruppen-Ansicht hier
    if ONE.UI.AddAlias then ONE.UI:AddAlias("groups", "dungeons", function() Page.view = "groups" end) end
    -- Kalender/"Was steht an": direkt in die Ausfluege (TripsPage.selectId waehlt einen aus)
    if ONE.UI.AddAlias then ONE.UI:AddAlias("trips", "dungeons", function() Page.view = "trips" end) end
    return ok
end
