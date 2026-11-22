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

    -- Ziel/Tempo steht in der Kopfzeile des Fensters (G.goalText, statt doppelt "Tagebuch Tagebuch");
    -- die Zeile hier bleibt leer (Spieltest 18.11.2026)
    local goal = Text(parent, "GameFontHighlightSmall", 4, 0, leftW, "soft")
    goal:Hide()
    local function Selected(item) return state.sel and item and state.sel.key == item.key end
    local list = ONE.Kit:List(parent, {x = 0, y = -4, width = leftW, height = H - 4, rowHeight = 22,
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
    -- Tagebuch: eigene Liste ueber die ganze Breite (es gibt keine Karte rechts)
    local jlist = ONE.Kit:List(parent, {x = 0, y = -4, width = W, height = H - 4, rowHeight = 22,
        columns = {{key = "text", title = "ERLEBT", width = W - 24 - 8, indent = 4}},
        render = function(_, item, cells)
            cells.text:SetText(item.text)
            if item.header then cells.text:SetTextColor(1, .82, 0) else cells.text:SetTextColor(1, 1, 1) end
        end,
    })
    Page.COL_TITLE = {guide = "SCHRITT", zones = "GEBIET", skipped = "AUSGELASSEN"}
    local empty = Text(parent, "GameFontHighlight", 8, -70, leftW - 16, "soft")
    if empty.SetWordWrap then empty:SetWordWrap(true) end

    -- rechts: Warum?
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", rightX, -4)
    card:SetSize(rightW, H - 4)
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
                -- Steckbrief oben (Nutzer 18.11.2026: Seite wirkte leer)
                local l1, l2, l3 = J:Profile()
                out[1] = {key = "jp1", header = true, text = l1}
                out[2] = {key = "jp2", text = l2}
                out[3] = {key = "jp3", text = l3}
                out[4] = {key = "js", text = "|cff9d9d9d" .. J:Summary() .. "|r"}
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
            local first = s.kind == "dungeon" and s.ids[1] or (s.actions[1] and s.actions[1].id)
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
        G.goalText = T("Stufe %d von 60", plan.level) .. nextText
        local items = Items(plan, mode)
        local journal = mode == "journal"
        -- Kit:List ist eine Tabelle; sichtbar/unsichtbar ist ihr Rahmen .box (Spieltest 19.11.2026: beide Listen
        -- lagen uebereinander)
        if list.box and list.box.SetShown then list.box:SetShown(not journal) end
        if jlist.box and jlist.box.SetShown then jlist.box:SetShown(journal) end
        if list.headers and list.headers.text and list.headers.text.SetText then list.headers.text:SetText(T(Page.COL_TITLE[mode] or "")) end
        if journal then
            jlist:SetItems(items) list:SetItems({}) card:Hide()
            if #items == 0 then empty:SetText(T("Noch nichts erlebt – gib eine Quest ab, dann geht dein Tagebuch los.")) empty:Show() else empty:Hide() end
            return
        end
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
        if state.step then go:Enable() else go:Disable() end
        toggle:SetText(o and o.why and T("Nicht machen") or T("Doch machen"))
        if o and o.group then group:Show() else group:Hide() end
    end
end

-- ===== Reiter "Leveln" =====
Page.VIEWS = {{"guide", "Plan"}, {"zones", "Gebiete"}, {"skipped", "Ausgelassen"}, {"gear", "Ausrüstung"}, {"journal", "Tagebuch"}, {"log", "Questlog"}}
Page.SUBTITLE = {
    guide = "Nur die Quests, die sich lohnen – Dungeon-, Klassen- und Vorquests immer.",
    skipped = "Was die Führung auslässt und warum.",
    zones = "Alle Quests je Gebiet – nur zur Übersicht, der Plan bleibt die schnellste Route.",
    journal = "Deine Reise: Quests, Stufen, neue Gebiete und Dungeons – nur bei dir gespeichert.",
    log = "Deine Quests mit Fortschritt – „Navi“ zeigt die Richtung zum Ziel.",
    gear = "Das Beste je Platz aus Quests, Dungeons und Herstellung – und wie lange es hält.",
}

-- ===== Ausrüstung auf deinem Weg (Way.lua) =====
local QUALITY = {[0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000"}
function Page:BuildGear(parent, W, H)
    local Way = lev.Way
    local head = Text(parent, "GameFontHighlightSmall", 4, 0, W - 8, "soft")
    local plan, stamp, level = nil, 0, nil
    local function Name(id)
        local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and GetItemInfo(id))
        if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        return name or ("#" .. id)
    end
    local function Color(it, text) return "|cff" .. (QUALITY[it.quality] or "ffffff") .. text .. "|r" end
    local list = ONE.Kit:List(parent, {x = 0, y = -22, width = W, height = H - 46, rowHeight = 24,
        columns = {
            {key = "slot", title = "PLATZ", width = 74, indent = 4},
            {key = "item", title = "BESTES FÜR DICH", width = 198, indent = 22},
            {key = "plus", title = "BESSER", width = 50, align = "RIGHT"},
            {key = "src", title = "WOHER", width = 262}, -- Breite auch unten bei SRCW
            {key = "holds", title = "HÄLT BIS", width = 64, align = "RIGHT"},
        },
        render = function(frame, row, cells)
            -- Symbol des Gegenstands vor dem Namen (Glas: rund mit Ring) – 19.11.2026
            if not frame.icon then
                frame.icon = frame:CreateTexture(nil, "ARTWORK")
                frame.icon:SetSize(18, 18)
                frame.icon:SetPoint("LEFT", frame, "LEFT", 88, 0)
                if ONE.Glass and ONE.Glass.RoundIcon then ONE.Glass:RoundIcon(frame, frame.icon) end
            end
            -- leerer Platz: das, was als Naechstes kommt (Nutzer 22.11.2026), grau
            local show = row.now or row.next
            local tex = show and C_Item and type(C_Item.GetItemIconByID) == "function" and select(2, pcall(C_Item.GetItemIconByID, show.item.id))
            if tex then frame.icon:SetTexture(tex) frame.icon:Show() else frame.icon:Hide() end
            if frame.icon.SetDesaturated then frame.icon:SetDesaturated(not row.now and tex and true or false) end
            if frame.icon.__oneRing then frame.icon.__oneRing:SetShown(tex and true or false) end
            cells.slot:SetText(T(row.slot.name))
            cells.slot:SetTextColor(.8, .8, .8)
            -- Knopf "Anfragen": nur wenn ein Hersteller aus der Gilde gerade online ist (22.11.2026)
            local SRCW = 262
            if not frame.ask then
                frame.ask = ONE.Widgets:Button(frame, T("Anfragen"), 70, 18, "RIGHT", -74, 0, function(b)
                    local r = frame.askRow
                    if r and r.now then Way:Ask(r.now.sources[1], r.now.item.id) end
                end)
                frame.ask:HookScript("OnEnter", function(b)
                    local r, g = frame.askRow, frame.askWho
                    if not (GameTooltip and r and g) then return end
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(T("Anfrage an %s", g.name:match("^[^%-]+") or g.name), 1, .82, 0)
                    GameTooltip:AddLine(T("Öffnet ein Flüsterfenster mit fertigem Text – du drückst nur noch Enter."), 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                frame.ask:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            end
            local who = row.now and Way.AskTarget(row.now.sources[1])
            frame.askRow, frame.askWho = row, who
            if who then frame.ask:Show() cells.src:SetWidth(SRCW - 78) else frame.ask:Hide() cells.src:SetWidth(SRCW) end
            if not row.now and row.next then
                local n = row.next
                cells.item:SetText("|cff9d9d9d" .. Name(n.item.id) .. "|r")
                cells.plus:SetText("|cff9d9d9d" .. T("bald") .. "|r")
                cells.src:SetText("|cff9d9d9d" .. Way.SourceText(n.sources[1], true) .. "|r")
                cells.src:SetTextColor(1, 1, 1)
                cells.holds:SetText("|cff9d9d9d" .. T("ab %d", n.at or Way.ReqLevel(n.item)) .. "|r")
                return
            end
            if not row.now then
                cells.item:SetText("|cff808080" .. T("nichts Passendes gefunden") .. "|r")
                cells.plus:SetText("") cells.src:SetText("") cells.holds:SetText("")
                return
            end
            local it = row.now.item
            cells.item:SetText(Color(it, Name(it.id)))
            if row.upgrade then
                cells.plus:SetText(row.plus and row.plus >= 100 and "|cff40ff40" .. T("neu") .. "|r" or ("|cff40ff40+" .. (row.plus or 0) .. " %|r"))
            else
                cells.plus:SetText("|cff9d9d9d" .. T("hast du") .. "|r")
            end
            cells.src:SetText(Way.SourceText(row.now.sources[1], true))
            cells.src:SetTextColor(row.upgrade and 1 or .6, row.upgrade and 1 or .6, row.upgrade and 1 or .6)
            cells.holds:SetText(row.holdsTo and T("Stufe %d", row.holdsTo) or "|cff9d9d9d–|r")
        end,
        onClick = function(_, row)
            local show = row.now or row.next
            if show then Way:Get(show.sources[1], show.item.id) end
        end,
        onEnter = function(self, row)
            if not GameTooltip then return end
            if not row.now and row.next then
                -- leerer Platz: kommt bald
                local n = row.next
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. n.item.id) end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(T("Für diesen Platz gibt es auf deiner Stufe noch nichts – das hier kommt ab Stufe %d.", n.at or Way.ReqLevel(n.item)), .7, .9, 1, true)
                for _, src in ipairs(n.all or n.sources) do
                    GameTooltip:AddLine("• " .. Way.SourceText(src), src.sure and 1 or .6, src.sure and 1 or .6, src.sure and 1 or .6, true)
                end
                GameTooltip:AddLine(T("Klick: Navi zur Quelle mit Anleitung"), .3, 1, .3, true)
                GameTooltip:Show()
                return
            end
            if not row.now then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local it = row.now.item
            if GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. it.id) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T("Guild Trip – so bekommst du es:"), 1, .82, 0)
            for _, src in ipairs(row.now.all) do
                GameTooltip:AddLine("• " .. Way.SourceText(src), src.sure and 1 or .6, src.sure and 1 or .6, src.sure and 1 or .6, true)
                if src.kind == "c" and (src.status == "learn" or src.status == "soon") then
                    for i, l in ipairs(src.learn) do
                        if i > 3 then break end
                        GameTooltip:AddLine("    " .. Way.LearnText(l), .75, .75, .75, true)
                    end
                elseif src.kind == "c" and src.status == "guild" then
                    for i, g in ipairs(src.guild) do
                        if i > 4 then break end
                        GameTooltip:AddLine("    " .. (g.name:match("^[^%-]+") or g.name) .. (g.online and (" |cff40ff40" .. T("(online)") .. "|r") or ""), .8, .8, .8)
                    end
                end
            end
            if row.holdsTo then GameTooltip:AddLine(T("Hält, bis ab Stufe %d etwas deutlich Besseres kommt.", row.holdsTo), .7, .9, 1, true)
            else GameTooltip:AddLine(T("Hält lange – nichts deutlich Besseres in Sicht."), .7, .9, 1, true) end
            if row.next then
                local n = row.next
                GameTooltip:AddLine(T("Bald: %s ab Stufe %d – %s", Color(n.item, Name(n.item.id)), n.at or Way.ReqLevel(n.item), Way.SourceText(n.sources[1], true)), .9, .9, .9, true)
            end
            GameTooltip:AddLine(T("Klick: Navi zur Quelle mit Anleitung – bei Questreihen zum ersten offenen Teil (Herstellung durch die Gilde: Anfrage im Flüsterchat)"), .3, 1, .3, true)
            GameTooltip:Show()
        end,
    })
    -- Gegenstandsnamen kommen vom Server nach: dann die Liste neu zeichnen (gebremst)
    local ev = CreateFrame("Frame", nil, parent)
    local pendingAt
    if ev.RegisterEvent then pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED") end
    ev:SetScript("OnEvent", function()
        if not (parent.IsVisible and parent:IsVisible()) or pendingAt then return end
        pendingAt = true
        if C_Timer and C_Timer.After then
            C_Timer.After(.3, function() pendingAt = nil if parent:IsVisible() then list:Update() end end)
        else pendingAt = nil list:Update() end
    end)
    local foot = Text(parent, "GameFontDisableSmall", 4, -(H - 18), W - 8, "soft",
        "Klick auf eine Zeile: Navi und Anleitung, wie du es bekommst. Bewertet wie im Tooltip „besser für dich“.")
    return function()
        local L = (UnitLevel and UnitLevel("player")) or 1
        local now = (GetTime and GetTime()) or 0
        Way = Way or lev.Way
        if not (Way and Way.Data()) then
            head:SetText(T("Ausrüstungsdaten fehlen – ONE_Leveling vollständig installieren."))
            list:SetItems({})
            return
        end
        if not plan or level ~= L or now - stamp > 10 then
            local ctx = Way:Context()
            plan, stamp, level = Way:Plan(ctx), now, L
            local ranks = ctx.ranks and #ctx.ranks > 0 and table.concat(ctx.ranks, " › ") or nil
            local text = T("Stufe %d", L) .. (ctx.spec ~= "" and (" · " .. T(ctx.spec)) or "")
                .. (ranks and (" · " .. T("wichtig: %s", ranks)) or "")
            -- ab 60: Raid-Vorbereitung (Nutzer 19.11.2026) – wie viele Plaetze lassen sich noch verbessern?
            if L >= 60 then
                local up, all = 0, 0
                for _, row in ipairs(plan or {}) do
                    all = all + 1
                    if row.upgrade then up = up + 1 end
                end
                text = T("Raid-Vorbereitung: das Beste vor dem ersten Raid – %d von %d Plätzen kannst du noch verbessern", up, all)
                    .. (ctx.spec ~= "" and (" · " .. T(ctx.spec)) or "")
            end
            head:SetText(text)
        end
        list:SetItems(plan or {})
        if foot then foot:Show() end
    end
end

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
    -- Glas: Ansichten in der mittleren Spalte statt Knoepfe oben rechts
    local glassViews = ONE.Glass and ONE.Glass:Active() and ONE.UI.SetViews
    if glassViews then
        local items = {}
        for _, d in ipairs(Page.VIEWS) do
            items[#items + 1] = {key = d[1], label = d[2], onClick = function(key) G:DB().view = key ONE.UI:Refresh() end}
        end
        ONE.UI:SetViews("leveling", items, Mode())
        for _, b in pairs(buttons) do b:Hide() b.Show = function() end end
    end
    local function Box(top)
        local box = CreateFrame("Frame", nil, panel)
        box:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, top)
        box:SetSize(W, H + top)
        return box
    end
    local guideBox = Box(-36)
    local guide = self:Build(guideBox, W, H - 36, function() local m = Mode() return (m == "skipped" or m == "zones" or m == "journal") and m or "guide" end)
    local gearBox = Box(-36)
    local gear = self:BuildGear(gearBox, W, H - 36)
    local logBox = Box(0)
    local nav = ONE.ns and ONE.ns.nav
    local log = nav and nav.Quests and nav.Quests:Build(logBox, true)
    return function()
        local mode = Mode()
        if glassViews then ONE.UI:SetActiveView("leveling", mode) end
        for k, b in pairs(buttons) do
            if b.LockHighlight then if k == mode then b:LockHighlight() else b:UnlockHighlight() end end
        end
        if sub and sub.SetText then sub:SetText(T(Page.SUBTITLE[mode] or "")) end
        guideBox:SetShown(mode ~= "log" and mode ~= "gear")
        logBox:SetShown(mode == "log")
        gearBox:SetShown(mode == "gear")
        if mode == "log" then if log then log() end
        elseif mode == "gear" then gear()
        else guide() end
        local name = ({guide = "Plan", zones = "Gebiete", skipped = "Ausgelassen", journal = "Tagebuch", log = "Questlog", gear = "Ausrüstung"})[mode]
        if mode == "gear" and ((UnitLevel and UnitLevel("player")) or 1) >= 60 then name = "Raid-Vorbereitung" end
        -- Kopfzeile: Seitenname steht schon links (Glas), daneben Stufe/Tempo/naechste Stufe
        local glass = ONE.Glass and ONE.Glass:Active()
        if ONE.UI.SetContext then ONE.UI:SetContext("leveling", (glass and "" or (T(name) .. "  ·  ")) .. (G.goalText or "")) end
    end
end

function Page:Register()
    if not (ONE.UI and ONE.UI.AddTab and ONE.Kit) then return false end
    lev.Settings:Register()
    return ONE.UI:AddTab("leveling", T("Leveln"), function(panel) return self:BuildTab(panel) end)
end
