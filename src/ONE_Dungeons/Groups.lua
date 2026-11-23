-- Project ONE Dungeons: Reiter "Gruppen" – der gildeninterne Gruppenfinder.
-- Oben: Einstellungen (Fortschritt teilen, Hinweise, eigene Rolle).
-- Mitte: alle offenen Gesuche der Gilde (passende zuerst).
-- Unten: Details zum gewaehlten Gesuch – "Ich bin dabei" oder, beim eigenen
-- Gesuch, die Meldungen mit "Einladen" und "Anfluestern".
local _, dungeons = ...
local ONE = _G.ProjectONE
local function Paint(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Groups = {}
dungeons.Groups = Groups

local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(T(text or ""))
    if ONE.Themes then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end

local function Age(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds < 60 then return "gerade" end
    return math.floor(seconds / 60) .. " Min."
end

local function RoleNames(roles)
    local out = {}
    for key in tostring(roles or ""):gmatch("[THD]") do out[#out + 1] = dungeons.Share:RoleName(key) end
    return #out > 0 and table.concat(out, ", ") or "alle"
end

function Groups:Build(panel)
    local S, M = dungeons.Share, dungeons.Model
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local state = {}
    local function Now() return type(GetTime) == "function" and GetTime() or 0 end

    if not self.embedded then Text(panel, "GameFontNormalLarge", 0, -4, 180, "accent", T("Gruppen")) end
    local intro = Text(panel, "GameFontHighlightSmall", 0, -30, W, "soft",
        T("Gildeninterner Gruppenfinder – nur für Mitglieder mit Guild Trip."))
    -- Einstellungen rechts oben: zwei Haekchen (an/aus) und die Rolle als Dropdown
    local function Changed() Groups:Refresh() end
    -- "Fortschritt teilen" steht in Optionen › Teilen
    -- Hinweise und Rolle: Optionen › Dungeons (Page:Register, Init.lua)

    local cols = {
            {key = "dungeon", title = "DUNGEON", width = 178},
            {key = "owner", title = "VON", width = 110},
            {key = "roles", title = "SUCHT", width = 150},
            {key = "size", title = "GRUPPE", width = 52, align = "CENTER"},
            {key = "age", title = "SEIT", width = 54, align = "CENTER"},
            {key = "fit", title = "FÜR DICH", width = W - 24 - 6 - 178 - 110 - 150 - 52 - 54 - 40},
        }
    local listH = (22 * 7 + 22)
    local list = ONE.Kit:List(panel, {x = 0, y = -54, width = W, height = listH, rowHeight = 22,
        columns = cols,
        render = function(row, ad, cells)
            local fits, open, over = S:Fit(ad)
            cells.dungeon:SetText(S:AdName(ad))
            cells.dungeon:SetTextColor(1, .82, 0)
            cells.owner:SetText(S.Short(ad.owner) .. (ad == S.myAd and " (du)" or ""))
            cells.owner:SetTextColor(1, 1, 1)
            cells.roles:SetText(RoleNames(ad.roles))
            cells.roles:SetTextColor(.9, .9, .9)
            cells.size:SetText((ad.have or 1) .. "/" .. (ad.size or 5))
            cells.size:SetTextColor(.9, .9, .9)
            cells.age:SetText(Age(Now() - (ad.created or Now())))
            cells.age:SetTextColor(.7, .7, .7)
            if not fits then
                cells.fit:SetText(T("Stufe zu niedrig"))
                cells.fit:SetTextColor(.55, .55, .55)
            elseif open > 0 then
                cells.fit:SetText(T("%d Quests offen", open))
                cells.fit:SetTextColor(.5, .9, .5)
            else
                cells.fit:SetText(over and T("Ausrüstung/Helfen") or T("passt"))
                cells.fit:SetTextColor(.5, .9, .5)
            end
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                Paint(row.selection, 1, .82, 0, .14)
            end
            if state.ad == ad then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, ad) state.ad = ad Groups:Refresh() end,
    })
    local empty = Text(panel, "GameFontHighlight", 16, -98, (W) - 32, "soft")
    if empty.SetWordWrap then empty:SetWordWrap(true) end

    -- Detailkarte unten
    local cardTop = -54 - (22 * 7 + 22) - 10
    local CW = W
    local card = CreateFrame("Frame", nil, panel)
    card:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, cardTop)
    card:SetSize(CW, H + cardTop)
    if ONE.Themes then ONE.Themes:RegisterPanel(card) end
    -- Buch: Texte volle Breite, Knoepfe in eigener Zeile darunter, Meldungen danach
    local TW = (W - 220)
    local headline = Text(card, "GameFontNormal", 16, -12, (W - 390), "accent")
    -- Feste Zeilen statt eines umbrechenden Textblocks: nichts kann sich ueberlappen.
    local info = Text(card, "GameFontHighlight", 16, -34, TW, "text")
    local noteLine = Text(card, "GameFontHighlight", 16, -54, TW, "soft")
    local fitLine = Text(card, "GameFontHighlight", 16, -74, TW, "text")
    for _, fs in ipairs({info, noteLine, fitLine}) do if ONE.Fit then ONE.Fit:Line(fs) end end
    local appliedHead = Text(card, "GameFontNormalSmall", 16, -98, 300, "accent")
    local BW = 170
    local function BP(right) return "TOPRIGHT", right and -12 or -190, -10 end
    local p1, x1, y1 = BP(false)
    local guildChat = ONE.Widgets:Button(card, T("Im Gildenchat posten"), BW, 26, p1, x1, y1, function()
        if S:PostToGuildChat() then ONE:Print(T("Gesuch im Gildenchat gepostet.")) end
    end)
    local p2, x2, y2 = BP(true)
    local primary = ONE.Widgets:Button(card, "", BW, 26, p2, x2, y2, function()
        local ad = state.ad
        if not ad then return end
        if ad == S.myAd then S:CloseAd() state.ad = nil
        else S:Join(ad.gid) ONE:Print(T("Du hast dich bei %s gemeldet.", S.Short(ad.owner))) end
        Groups:Refresh()
    end)
    -- Meldungen beim eigenen Gesuch (bis zu 4 sichtbar)
    local applicants = {}
    for i = 1, 3 do
        local y = (-114) - (i - 1) * 28
        local AW = 120
        local label = Text(card, "GameFontHighlight", 16, y - 4, (W - 300), "text")
        local invite = ONE.Widgets:Button(card, T("Einladen"), AW, 24, "TOPRIGHT", -(12 + AW + 12), y, function()
            local a = applicants[i].who
            if a and not S:Invite(a.name) then ONE:Print(T("Einladen ging nicht – bitte per Rechtsklick einladen.")) end
        end)
        local whisper = ONE.Widgets:Button(card, T("Anflüstern"), AW, 24, "TOPRIGHT", -12, y, function()
            local a = applicants[i].who
            if a then S:Whisper(a.name) end
        end)
        applicants[i] = {label = label, invite = invite, whisper = whisper}
    end

    self.refresh = function()
        local s = S:Settings()
        local ads = S:Ads()
        list:SetItems(ads)
        local stillThere = false
        for _, ad in ipairs(ads) do if ad == state.ad then stillThere = true end end
        if not stillThere then state.ad = S.myAd or ads[1] end
        if #ads == 0 then
            -- Elite-Quests: eigener Reiter "Quests" nur ohne Quest-Fuehrung, sonst Leveln › Questlog
            local questPage = ONE.UI and ONE.UI.tabs and ONE.UI.tabs.quests and T("auf der Seite |cffffd100Quests|r")
                or T("unter |cffffd100Leveln › Questlog|r")
            empty:SetText(T("Gerade sucht niemand aus der Gilde eine Gruppe.\n\nEin Gesuch gibst du im Reiter "
                .. "|cffffd100Dungeons|r auf: Dungeon wählen und „Gruppe suchen“ klicken – für Elite-Quests %s.", questPage))
        else
            empty:SetText("")
        end
        local ad = state.ad
        for _, a in ipairs(applicants) do a.label:SetText("") a.invite:Hide() a.whisper:Hide() a.who = nil end
        noteLine:SetText("") fitLine:SetText("") appliedHead:SetText("")
        guildChat:Hide()
        if not ad then
            headline:SetText(T("Kein Gesuch ausgewählt"))
            info:SetText(S:IsSharing() and "" or "|cff9d9d9d" .. T("Tipp: Mit „Fortschritt teilen“ sieht die Gilde, wo du noch Quests offen hast.") .. "|r")
            primary:Hide()
            return
        end
        local fits, open, over = S:Fit(ad)
        headline:SetText(S:AdName(ad) .. "  –  " .. S.Short(ad.owner))
        info:SetText(T("Sucht: %s   ·   Gruppe %d/%d", RoleNames(ad.roles), ad.have or 1, ad.size or 5))
        noteLine:SetText(ad.note and ad.note ~= "" and ("„" .. ad.note .. "“") or "")
        local quest = S:QuestOf(ad)
        local navi = ONE.modules and ONE.modules.nav
        local holders = quest and navi and navi.QuestHolders and navi:QuestHolders(quest) or ""
        if quest and ad ~= S.myAd and fits then
            fitLine:SetText("|cff80e680" .. T("Du hast diese Quest auch.") .. "|r")
        elseif quest and holders ~= "" then
            fitLine:SetText(T("Mit dieser Quest: %s", holders))
        elseif quest then
        elseif ad ~= S.myAd and fits and open > 0 then
            fitLine:SetText("|cff80e680" .. T("Du hast dort %d offene Quests.", open) .. "|r")
        elseif ad ~= S.myAd and fits and over then
            fitLine:SetText("|cff80e680" .. T("Du kannst mit – für Ausrüstung oder zum Helfen.") .. "|r")
        end
        primary:Show()
        if ad == S.myAd then
            primary:SetText(T("Gesuch schließen"))
            guildChat:Show()
            appliedHead:SetText("MELDUNGEN")
            local i = 0
            for _, a in pairs(S.applicants[ad.gid] or {}) do
                i = i + 1
                if i > #applicants then break end
                local row = applicants[i]
                row.who = a
                row.label:SetText(dungeons.Page:ClassName(a.class, S.Short(a.name)) .. " (" .. a.level .. ")  ·  "
                    .. S:RoleName(a.role))
                row.invite:Show() row.whisper:Show()
            end
            if i == 0 then applicants[1].label:SetText("|cff9d9d9d" .. T("Noch keine. Du bekommst einen Hinweis, sobald sich jemand meldet.") .. "|r") end
        else
            primary:SetText(ad.joined and T("Gemeldet") or T("Ich bin dabei (%s)", S:RoleName(s.role)))
            if primary.SetEnabled then primary:SetEnabled(not ad.joined) end
        end
    end
    return self.refresh
end

function Groups:Refresh() if self.refresh then self.refresh() end end

-- Kein eigener Reiter mehr: die Gruppen sind eine Ansicht im Reiter "Dungeons"
-- (siehe Page:BuildCombined). Bleibt fuer Aufrufer, die es noch erwarten.
function Groups:Register() return true end
