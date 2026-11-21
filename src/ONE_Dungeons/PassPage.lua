-- Guild Trip Reisepass – Ansicht im Dungeons-Bereich (Blizzard-Aussehen, 0.6.8).
-- Links: du und die Gilde mit Anzahl Stempel. Rechts: aufgeschlagener Pass – links Dungeons
-- (runde Stempel), rechts Gildenausflüge (eckige Stempel); freie Felder gestrichelt mit Vorschlag.
-- Grafiken: Stempel scripts/build_stamps.py, Seiten = Pergament aus dem Buch (Sheet.tga).
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local PassPage = {}
dungeons.PassPage = PassPage

local TEX = "Interface\\AddOns\\ONE_Dungeons\\Textures\\"
local SHEET = "Interface\\AddOns\\ONE_Core\\Textures\\Common\\Sheet"
local FELL = "Interface\\AddOns\\ONE_Core\\Fonts\\IMFellEnglish.ttf"
local INKS = {{.55, .11, .07}, {.16, .21, .45}, {.36, .24, .1}, {.12, .36, .2}}
local PER_PAGE = 6
local ROT = {.12, -.09, .05, -.14, .1, -.04}

local function Text(parent, font, role)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH("LEFT")
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end
local function Ink(fs, size, c)
    if fs.SetFont then pcall(fs.SetFont, fs, FELL, size, "") end
    fs:SetTextColor(c[1], c[2], c[3])
    if fs.SetShadowOffset then fs:SetShadowOffset(0, 0) end
end
local function Day(t) return (type(date) == "function" and t and t > 0) and date("%d.%m.%y", t) or "" end

-- Ein Stempelfeld: Grafik (gedreht, eingefaerbt) + Schrift darin
local function NewStamp(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints(f)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("CENTER", f, "CENTER", 0, 6)
    f.name:SetWidth(size * .62)
    f.name:SetJustifyH("CENTER")
    if f.name.SetMaxLines then f.name:SetMaxLines(3) end
    f.info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.info:SetPoint("TOP", f.name, "BOTTOM", 0, -3)
    f.info:SetWidth(size * .8)
    f.info:SetJustifyH("CENTER")
    if f.EnableMouse then f:EnableMouse(true) end
    f:SetScript("OnEnter", function(self)
        if not (GameTooltip and self.tip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip[1])
        for i = 2, #self.tip do GameTooltip:AddLine(self.tip[i], .85, .85, .85) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return f
end
local function SetStamp(f, kind, i, name, info, tip)
    local c = kind == "slot" and {.36, .24, .12} or INKS[(i - 1) % #INKS + 1]
    f.tex:SetTexture(TEX .. (kind == "trip" and "StampRect" or kind == "slot" and "StampSlot" or "StampRound"))
    f.tex:SetVertexColor(c[1], c[2], c[3], kind == "slot" and .55 or .92)
    if f.tex.SetRotation then f.tex:SetRotation(kind == "slot" and 0 or ROT[(i - 1) % #ROT + 1]) end
    Ink(f.name, kind == "trip" and 13 or 12, kind == "slot" and {.4, .3, .18} or c)
    Ink(f.info, 10, kind == "slot" and {.45, .35, .22} or c)
    f.name:SetText(name or "")
    f.info:SetText(info or "")
    f.tip = tip
    f:Show()
end

function PassPage:Build(panel)
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local leftW = 196
    local state = {}
    local P = dungeons.Passport
    -- Links: Personen
    local list = ONE.Kit:List(panel, {x = 0, y = -4, width = leftW, height = H - 4, rowHeight = 24,
        columns = {{key = "name", title = "GILDE", width = leftW - 24 - 6 - 54 - 8, indent = 6},
            {key = "count", title = "STEMPEL", width = 54, align = "CENTER"}},
        render = function(row, e, cells)
            cells.name:SetText(e.me and (e.name .. "  |cff9d9d9d(" .. T("du") .. ")|r") or e.name)
            cells.name:SetTextColor(1, .82, 0)
            cells.count:SetText(tostring(e.count))
            cells.count:SetTextColor(.9, .9, .9)
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                row.selection:SetColorTexture(1, .82, 0, .14)
            end
            if state.who == e.name then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, e) state.who = e.name PassPage:Refresh() end})
    local hint = Text(panel, "GameFontDisableSmall", "soft")
    hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    hint:SetWidth(leftW - 16)
    if hint.SetWordWrap then hint:SetWordWrap(true) end

    -- Rechts: Kopf + aufgeschlagener Pass
    local RX, RW = leftW + 12, W - leftW - 12
    local title = Text(panel, "GameFontNormalLarge", "accent")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", RX + 4, -6)
    local sub = Text(panel, "GameFontHighlightSmall", "soft")
    sub:SetPoint("TOPLEFT", panel, "TOPLEFT", RX + 4, -28)
    local cover = CreateFrame("Frame", nil, panel)
    cover:SetPoint("TOPLEFT", panel, "TOPLEFT", RX, -48)
    cover:SetSize(RW, H - 50)
    local leather = cover:CreateTexture(nil, "BACKGROUND")
    leather:SetAllPoints(cover)
    leather:SetColorTexture(.2, .11, .05, 1)
    local rim = cover:CreateTexture(nil, "BORDER")
    rim:SetPoint("TOPLEFT", cover, "TOPLEFT", 3, -3)
    rim:SetPoint("BOTTOMRIGHT", cover, "BOTTOMRIGHT", -3, 3)
    rim:SetColorTexture(.33, .19, .08, 1)
    local pageW, pageH = math.floor((RW - 22) / 2), H - 50 - 16
    local pages = {}
    for side = 1, 2 do
        local pg = CreateFrame("Frame", nil, cover)
        pg:SetPoint("TOPLEFT", cover, "TOPLEFT", 8 + (side - 1) * (pageW + 6), -8)
        pg:SetSize(pageW, pageH)
        local paper = pg:CreateTexture(nil, "BACKGROUND")
        paper:SetAllPoints(pg)
        paper:SetTexture(SHEET)
        -- Pergament aus dem Tagesueberblick-Blatt, je Seite eine Haelfte
        paper:SetTexCoord(side == 1 and .04 or .5, side == 1 and .5 or .96, .06, .80)
        local fold = pg:CreateTexture(nil, "ARTWORK")
        fold:SetPoint(side == 1 and "TOPRIGHT" or "TOPLEFT", pg, side == 1 and "TOPRIGHT" or "TOPLEFT", 0, 0)
        fold:SetPoint(side == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT", pg, side == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, 0)
        fold:SetWidth(14)
        fold:SetColorTexture(.25, .15, .05, .18)
        local head = pg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        head:SetPoint("TOP", pg, "TOP", 0, -10)
        Ink(head, 13, {.42, .1, .03})
        head:SetText(side == 1 and T("DUNGEONS") or T("GILDENAUSFLÜGE"))
        local more = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        more:SetPoint("BOTTOM", pg, "BOTTOM", 0, 8)
        Ink(more, 10, {.36, .24, .1})
        local stamps = {}
        local cell = math.min(math.floor(pageW / 2), math.floor((pageH - 44) / 3))
        for i = 1, PER_PAGE do
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            local s = NewStamp(pg, cell - 10)
            s:SetPoint("TOPLEFT", pg, "TOPLEFT", math.floor((pageW - 2 * cell) / 2) + col * cell + 5, -32 - row * cell)
            stamps[i] = s
        end
        pages[side] = {frame = pg, stamps = stamps, more = more}
    end

    self.refresh = function()
        local people = P:People()
        if not state.who then state.who = people[1] and people[1].name end
        local who
        for _, e in ipairs(people) do if e.name == state.who then who = e end end
        who = who or people[1]
        list:SetItems(people)
        local S = dungeons.Share
        hint:SetText(S and S.IsSharing and S:IsSharing() and T("Die Gilde sieht deinen Pass.")
            or T("Mit „Fortschritt teilen“ (Optionen) sieht die Gilde deinen Pass – und du ihre."))
        if not who then return end
        local d, t = dungeons.Passport.Stamps(who.pass)
        title:SetText(who.me and T("Reisepass · %s", who.name) or T("Reisepass · %s", who.name))
        sub:SetText(T("%d Dungeons · %d Gildenausflüge", #d, who.me and #t or (who.pass.trips or 0)))
        -- Dungeons (links): neueste zuerst, freie Felder mit Vorschlag fuer deine Stufe
        local L = pages[1]
        local suggest = {}
        if who.me and dungeons.Model then
            for _, dd in ipairs(dungeons.Model:Dungeons()) do
                if dd.suitable and not who.pass.d[dd.key] then suggest[#suggest + 1] = dd.name end
            end
        end
        for i, s in ipairs(L.stamps) do
            local e = d[i]
            if e then
                local name = S and S.DungeonName and S:DungeonName(e.key) or e.key
                local info = who.me and (Day(e.first) .. ((e.runs or 1) > 1 and ("  ·  " .. e.runs .. "x") or "")) or T("bezwungen")
                SetStamp(s, "dungeon", i, name, info, {name, who.me and T("Zuerst: %s", Day(e.first)) or nil,
                    who.me and T("Läufe: %d", e.runs or 1) or nil})
            else
                local idea = suggest[i - #d]
                SetStamp(s, "slot", i, idea or "", idea and T("passt zu dir") or "", idea and {idea, T("Passt zu deiner Stufe – noch kein Stempel.")} or nil)
            end
        end
        L.more:SetText(#d > PER_PAGE and T("und %d weitere", #d - PER_PAGE) or "")
        -- Ausfluege (rechts)
        local R = pages[2]
        local upcoming
        if who.me and dungeons.Trips then
            local now = dungeons.Trips:Now()
            for _, trip in ipairs(dungeons.Trips:List()) do
                if (trip.start or 0) > now and (not upcoming or trip.start < upcoming.start) then upcoming = trip end
            end
        end
        for i, s in ipairs(R.stamps) do
            local e = who.me and t[i]
            if e then
                SetStamp(s, "trip", i + 1, e.title or "?", Day(e.time) .. "  ·  " .. T("%d dabei", e.count or 1),
                    {e.title or "?", Day(e.time), T("%d dabei", e.count or 1)})
            elseif i == (who.me and #t or 0) + 1 and upcoming then
                local when = type(date) == "function" and date("%a %H:%M", upcoming.start) or ""
                SetStamp(s, "slot", i, T("nächster:"), when, {dungeons.Trips:Name(upcoming), when})
            elseif not who.me and i <= (who.pass.trips or 0) then
                SetStamp(s, "trip", i + 1, T("Ausflug"), "", nil)
            else
                SetStamp(s, "slot", i, "", "", nil)
            end
        end
        R.more:SetText(who.me and #t > PER_PAGE and T("und %d weitere", #t - PER_PAGE) or "")
    end
    return self.refresh
end

function PassPage:Refresh() if self.refresh then self.refresh() end end
