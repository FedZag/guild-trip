-- Project ONE Berufe: Reiter "Berufe".
-- Links: alles, was du oder deine Gilde herstellen kann (Suche, Beruf-Filter).
-- Rechts: Gegenstand, Rezept und wer es kann (online zuerst, sonst mit Stand)
-- mit "Anfragen": oeffnet das Fluesterfenster mit fertigem Text – absenden
-- tust du selbst mit Enter.
local _, crafting = ...
local ONE = _G.ProjectONE
local function Paint(tex, r, g, b, a) if ONE.Book and ONE.Book.Paint then return ONE.Book.Paint(tex, r, g, b, a) end tex:SetColorTexture(r, g, b, a) end
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Page = {rows = 6}
crafting.Page = Page

local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    fs:SetText(T(text or ""))
    if ONE.Themes then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end

-- Wer ist gerade online? (Gildenliste, ohne ONE_Guild vorauszusetzen)
function Page:OnlineSet()
    local set = {}
    if not (IsInGuild and IsInGuild()) or type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then
        return set
    end
    local total = tonumber((GetNumGuildMembers())) or 0
    for i = 1, math.min(total, 1000) do
        local ok, name, _, _, _, _, _, _, _, online = pcall(GetGuildRosterInfo, i)
        if ok and type(name) == "string" and online then set[name:lower()] = true set[Short(name):lower()] = true end
    end
    return set
end

function Page:Date(stamp)
    if type(stamp) ~= "number" or stamp <= 0 or type(date) ~= "function" then return "?" end
    local ok, text = pcall(date, "%d.%m.", stamp)
    return ok and text or "?"
end

function Page:RequestText(entry, crafter)
    local R = crafting.Recipes
    local what = R:ItemLink(entry.itemID) or R:ItemName(entry.itemID) or R:Name(entry.recipeID)
    return T("Hallo %s, könntest du mir %s herstellen? Die Materialien bringe ich gern mit.", Short(crafter.name), what)
end

-- Fluesterfenster mit fertigem Text oeffnen (Spieler sendet selbst).
function Page:Ask(entry, crafter)
    local text = self:RequestText(entry, crafter)
    if type(ChatFrame_OpenChat) == "function" then
        return pcall(ChatFrame_OpenChat, "/w " .. crafter.name .. " " .. text)
    end
    if type(ChatFrame_SendTell) == "function" then return pcall(ChatFrame_SendTell, crafter.name) end
    return false
end

function Page:Build(panel)
    local R, S = crafting.Recipes, crafting.Share
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local leftW, gap = 430, 12
    local rightX, rightW = leftW + gap, W - leftW - gap
    if ONE.Book and ONE.Book.Spread and ONE.Book:Spread() then
        local L, R = ONE.Book:Spread()
        leftW, rightX, rightW = L.width, R.x, R.width
    end
    local store = R:Store()
    local state = {}

    Text(panel, "GameFontNormalLarge", 0, -4, 80, "accent", T("Berufe"))
    -- Zwei Ansichten: Rezepte (wer kann was herstellen) und Lehrer (wo lerne ich was)
    local rv = CreateFrame("Frame", nil, panel)
    rv:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    rv:SetSize(W, H)
    local tv = CreateFrame("Frame", nil, panel)
    tv:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    tv:SetSize(W, H)
    local viewRecipes = ONE.Widgets:Button(panel, T("Rezepte"), 96, 24, "TOPLEFT", 84, -2, function()
        store.view = "recipes" Page:Refresh()
    end)
    local viewTrainers = ONE.Widgets:Button(panel, T("Lehrer"), 96, 24, "TOPLEFT", 186, -2, function()
        store.view = "trainers" Page:Refresh()
    end)
    self:BuildTrainers(tv, W, H)
    -- An/Aus als Haekchen, Auswahl als Dropdown (Blizzard-Bausteine aus dem Kit)
    -- "Rezepte teilen" steht in Optionen › Teilen
    local filter = ONE.Kit:Dropdown(rv, {point = "TOPRIGHT", x = 0, y = -2, width = 170,
        options = function()
            local out = {{value = nil, text = T("Alle Berufe")}}
            for _, prof in ipairs(Page:Professions()) do out[#out + 1] = {value = prof, text = prof} end
            return out
        end,
        get = function() return store.filter end, set = function(v) store.filter = v end,
        onChange = function() Page:Refresh() end})
    local mine = Text(rv, "GameFontHighlightSmall", 0, -30, W, "soft")
    -- Buch: eigene Berufe rechts unter dem Auswahlfeld (zweizeilig), nicht ueber die Falz
    if ONE.Book and ONE.Book.Spread and ONE.Book:Spread() then
        local _, R = ONE.Book:Spread()
        mine:ClearAllPoints()
        mine:SetPoint("TOPLEFT", rv, "TOPLEFT", R.x, -34)
        mine:SetWidth(R.width)
        if mine.SetWordWrap then mine:SetWordWrap(true) end
        if mine.SetMaxLines then mine:SetMaxLines(2) end
    end
    local okSearch, search = pcall(CreateFrame, "EditBox", nil, rv, "SearchBoxTemplate")
    if not okSearch or not search then search = CreateFrame("EditBox", nil, rv) end
    search:SetSize(leftW - 8, 22)
    search:SetPoint("TOPLEFT", rv, "TOPLEFT", 6, -50)
    if search.SetAutoFocus then search:SetAutoFocus(false) end

    local list = ONE.Kit:List(rv, {x = 0, y = -80, width = leftW, height = H - 80, rowHeight = 22,
        columns = {
            {key = "item", title = "GEGENSTAND", width = leftW < 400 and 168 or 236, indent = 20},
            {key = "prof", title = "BERUF", width = leftW < 400 and 84 or 96},
            {key = "who", title = "WER", width = leftW - 24 - 6 - (leftW < 400 and 168 or 236) - (leftW < 400 and 84 or 96) - 16, align = "CENTER"},
        },
        render = function(row, e, cells)
            if not row.icon then
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(16, 16)
                row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
            end
            local icon = e.itemID and e.itemID > 0 and C_Item and type(C_Item.GetItemIconByID) == "function"
                and select(2, pcall(C_Item.GetItemIconByID, e.itemID))
            row.icon:SetTexture(type(icon) == "number" and icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            cells.item:SetText(e.label)
            cells.item:SetTextColor(1, .82, 0)
            cells.prof:SetText(e.prof)
            cells.prof:SetTextColor(.85, .85, .85)
            cells.who:SetText(e.online > 0 and ("|cff80e680" .. e.online .. "|r/" .. #e.crafters) or tostring(#e.crafters))
            cells.who:SetTextColor(.85, .85, .85)
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                Paint(row.selection, 1, .82, 0, .14)
            end
            if state.entry and state.entry.recipeID == e.recipeID then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, e) state.entry = e Page:Refresh() end,
        onEnter = function(row, e)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            local link = R:ItemLink(e.itemID)
            if link and pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
                GameTooltip:Show()
                return
            end
            GameTooltip:SetText(e.label)
            GameTooltip:AddLine(e.prof, 1, 1, 1)
            GameTooltip:Show()
        end,
    })
    local empty = Text(rv, "GameFontHighlight", 16, -120, leftW - 32, "soft")
    if empty.SetWordWrap then empty:SetWordWrap(true) end

    -- Detailkarte rechts
    local card = CreateFrame("Frame", nil, rv)
    card:SetPoint("TOPLEFT", rv, "TOPLEFT", rightX, -80)
    card:SetSize(rightW, H - 80)
    if ONE.Themes then ONE.Themes:RegisterPanel(card) end
    local inner = rightW - 28
    local title = Text(card, "GameFontNormal", 14, -12, inner, "accent")
    local recipe = Text(card, "GameFontHighlightSmall", 14, -32, inner, "soft")
    local head = Text(card, "GameFontNormalSmall", 14, -56, inner, "accent")
    local rows = {}
    for i = 1, self.rows do
        local y = -74 - (i - 1) * 40
        local name = Text(card, "GameFontHighlight", 14, y, inner - 86, "text")
        local info = Text(card, "GameFontHighlightSmall", 14, y - 17, inner - 86, "soft")
        local ask = ONE.Widgets:Button(card, T("Anfragen"), 80, 22, "TOPRIGHT", -10, y + 2, function()
            local c = rows[i].crafter
            if c and state.entry then Page:Ask(state.entry, c) end
        end)
        rows[i] = {name = name, info = info, ask = ask}
    end
    local more = Text(card, "GameFontDisableSmall", 14, -74 - self.rows * 40, inner, "soft")

    local function Changed() Page:Refresh() end
    if search.HookScript then search:HookScript("OnTextChanged", Changed) end

    self.refresh = function()
        local trainersView = store.view == "trainers"
        if trainersView then rv:Hide() tv:Show() else tv:Hide() rv:Show() end
        if viewRecipes.SetEnabled then viewRecipes:SetEnabled(trainersView) viewTrainers:SetEnabled(not trainersView) end
        if trainersView then Page:RefreshTrainers() return end
        filter:Refresh()
        local own = {}
        for prof, data in pairs(R:Mine()) do own[#own + 1] = prof .. " " .. (data.skill or 0) .. "/" .. (data.max or 0) end
        table.sort(own)
        mine:SetText(#own > 0 and T("Deine Berufe: %s", table.concat(own, "  ·  "))
            or T("Öffne jedes deiner Berufsfenster einmal, dann kennt Guild Trip deine Rezepte."))
        local online = Page:OnlineSet()
        local query = string.lower(search.GetText and search:GetText() or "")
        local items = {}
        for _, e in ipairs(R:Catalog()) do
            if not store.filter or e.prof == store.filter then
                e.label = R:ItemName(e.itemID) or R:Name(e.recipeID)
                local hay = string.lower(e.label .. " " .. R:Name(e.recipeID))
                if query == "" or hay:find(query, 1, true) then
                    e.online = 0
                    for _, c in ipairs(e.crafters) do
                        c.online = c.me or online[c.name:lower()] or online[Short(c.name):lower()] or false
                        if c.online and not c.me then e.online = e.online + 1 end
                    end
                    table.sort(e.crafters, function(a, b)
                        if a.online ~= b.online then return a.online end
                        return (a.skill or 0) > (b.skill or 0)
                    end)
                    items[#items + 1] = e
                end
            end
        end
        table.sort(items, function(a, b)
            if a.prof ~= b.prof then return a.prof < b.prof end
            return a.label < b.label
        end)
        list:SetItems(items)
        if #items == 0 then
            empty:SetText(query ~= "" and T("Nichts gefunden. Anderen Suchbegriff probieren.")
                or T("Noch keine Rezepte bekannt. Öffne deine Berufsfenster und bitte die Gilde, "
                .. "„Rezepte teilen“ einzuschalten."))
        else
            empty:SetText("")
        end
        local still
        for _, e in ipairs(items) do if state.entry and e.recipeID == state.entry.recipeID then still = e end end
        state.entry = still or items[1]
        local e = state.entry
        for _, r in ipairs(rows) do r.name:SetText("") r.info:SetText("") r.ask:Hide() r.crafter = nil end
        more:SetText("")
        if not e then title:SetText("") recipe:SetText("") head:SetText("") return end
        title:SetText(e.label)
        recipe:SetText(R:Name(e.recipeID) .. "  ·  " .. e.prof)
        head:SetText(T("WER KANN ES HERSTELLEN?"))
        for i, c in ipairs(e.crafters) do
            if i > #rows then more:SetText(T("+%d weitere", #e.crafters - #rows)) break end
            local row = rows[i]
            row.crafter = c
            row.name:SetText(c.me and T("%s (du)", Short(c.name)) or Short(c.name))
            row.name:SetTextColor(c.online and 1 or .6, c.online and 1 or .6, c.online and 1 or .6)
            row.info:SetText((c.online and ("|cff80e680" .. T("online") .. "|r") or T("offline · Stand %s", Page:Date(c.stamp)))
                .. "  ·  " .. T("Fertigkeit %s", tostring(c.skill or "?")))
            if not c.me then row.ask:Show() end
        end
    end
    return self.refresh
end

-- ===== Ansicht "Lehrer" =====
local KIND_NAMES = {profession = "Berufe", class = "Klassen", weapon = "Waffen", other = "Sonstige"}
function Page:BuildTrainers(tv, W, H)
    local Tr, store = crafting.Trainers, crafting.Recipes:Store()
    local state = {}
    local due = Text(tv, "GameFontHighlight", 0, -32, W - 180, "text")
    local kindButton = ONE.Kit:Dropdown(tv, {point = "TOPRIGHT", x = 0, y = -2, width = 170,
        options = function()
            return {{value = nil, text = T("Alle Lehrer")}, {value = "profession", text = T("Berufe")},
                {value = "class", text = T("Klassen")}, {value = "weapon", text = T("Waffen")}, {value = "other", text = T("Sonstige")}}
        end,
        get = function() return store.trainerKind end, set = function(v) store.trainerKind = v end,
        onChange = function() Page:RefreshTrainers() end})
    local leftW, cardX, NPCW, WHATW = 430, 442, 140, 116
    if ONE.Book and ONE.Book.Spread and ONE.Book:Spread() then
        local L, R = ONE.Book:Spread()
        leftW, cardX, NPCW, WHATW = L.width, R.x, 120, 86
    end
    local list = ONE.Kit:List(tv, {x = 0, y = -80, width = leftW, height = H - 80, rowHeight = 22,
        columns = {
            {key = "npc", title = "LEHRER", width = NPCW},
            {key = "what", title = "FÜR", width = WHATW},
            {key = "area", title = "WO", width = leftW - 24 - 6 - NPCW - WHATW - 16},
        },
        render = function(row, e, cells)
            cells.npc:SetText(e.npc)
            cells.npc:SetTextColor(e.confirmed and 1 or .85, e.confirmed and .82 or .75, e.confirmed and 0 or .5)
            cells.what:SetText(T(e.what or "?"))
            cells.what:SetTextColor(.9, .9, .9)
            cells.area:SetText(T(e.area or "?"))
            cells.area:SetTextColor(.75, .75, .75)
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                Paint(row.selection, 1, .82, 0, .14)
            end
            if state.entry and state.entry.npc == e.npc then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, e) state.entry = e Page:RefreshTrainers() end,
    })
    local card = CreateFrame("Frame", nil, tv)
    card:SetPoint("TOPLEFT", tv, "TOPLEFT", cardX, -80)
    card:SetSize(W - cardX, H - 80)
    if ONE.Themes then ONE.Themes:RegisterPanel(card) end
    local inner = W - cardX - 28
    local name = Text(card, "GameFontNormal", 14, -12, inner, "accent")
    local what = Text(card, "GameFontHighlight", 14, -34, inner, "text")
    local where = Text(card, "GameFontHighlight", 14, -54, inner, "text")
    local status = Text(card, "GameFontHighlightSmall", 14, -78, inner, "soft")
    local hint = Text(card, "GameFontDisableSmall", 14, -100, inner, "soft")
    if hint.SetWordWrap then hint:SetWordWrap(true) end
    hint:SetHeight(60)
    local guide = ONE.Widgets:Button(card, T("Hinführen"), 130, 24, "BOTTOMRIGHT", -12, 12, function()
        local e = state.entry
        local navi = ONE.modules and ONE.modules.nav
        if e and e.map and e.x and navi and type(navi.PointTo) == "function" then navi:PointTo(e.npc, e.map, e.x, e.y, {service = true}) end
    end)
    self.refreshTrainers = function()
        kindButton:Refresh()
        local level = tonumber((UnitLevel and UnitLevel("player"))) or 0
        local lines = {}
        for i, d in ipairs(Tr:Due(Tr:MyProfessions(), level)) do
            if i > 2 then break end
            lines[#lines + 1] = (d.ready and "|cff80e680" or "|cffaaaaaa") .. d.text .. "|r"
        end
        due:SetText(#lines > 0 and T("Für dich: %s", table.concat(lines, "   ·   ")) or T("Für dich: gerade keine Berufsausbildung fällig."))
        local items = {}
        for _, e in ipairs(Tr:All()) do
            if not store.trainerKind or e.kind == store.trainerKind then items[#items + 1] = e end
        end
        list:SetItems(items)
        local still
        for _, e in ipairs(items) do if state.entry and e.npc == state.entry.npc then still = e end end
        state.entry = still or items[1]
        local e = state.entry
        if not e then name:SetText("") what:SetText("") where:SetText("") status:SetText("") hint:SetText("") guide:Hide() return end
        name:SetText(e.npc)
        what:SetText(T(KIND_NAMES[e.kind] or "") .. ": " .. T(e.what or "?"))
        where:SetText(T(e.area or "?"))
        if e.confirmed then
            status:SetText("|cff80e680" .. T("Bestätigt") .. "|r" .. (e.by and (" " .. T("von %s", (e.by:match("^[^-]+")) or e.by)) or "")
                .. (e.seen and (" " .. T("am %s", Page:Date(e.seen))) or ""))
            hint:SetText(T("Diese Position stammt aus dem Spiel: Ein Gildenmitglied hat den Lehrer angesprochen."))
        else
            status:SetText("|cffffaa33" .. T("Noch nicht bestätigt") .. "|r – " .. T("Position ungefähr (Classic-Stand)"))
            hint:SetText(T("Sobald jemand aus der Gilde mit Guild Trip diesen Lehrer anspricht, wird der Eintrag "
                .. "automatisch mit der echten Position bestätigt."))
        end
        local navi = ONE.modules and ONE.modules.nav
        if e.map and e.x and navi then guide:Show() else guide:Hide() end
    end
end
function Page:RefreshTrainers() if self.refreshTrainers then self.refreshTrainers() end end

function Page:Professions()
    local seen, out = {}, {}
    for _, e in ipairs(crafting.Recipes:Catalog()) do
        if not seen[e.prof] then seen[e.prof] = true out[#out + 1] = e.prof end
    end
    table.sort(out)
    return out
end

function Page:Refresh() if self.refresh then self.refresh() end end

function Page:Register()
    if not (ONE.UI and ONE.UI.AddTab and ONE.Kit) then return false end
    -- Gilde-Seite "Was steht an": faellige Ausbildung beim Berufslehrer
    if ONE.UI.AddFeed then
        ONE.UI:AddFeed("crafting", function()
            local out = {}
            local level = type(UnitLevel) == "function" and UnitLevel("player") or 0
            for _, d in ipairs(crafting.Trainers:Due(crafting.Trainers:MyProfessions(), level)) do
                if d.ready then
                    local item = {icon = "Interface\\Icons\\Trade_BlackSmithing", link = "crafting", sort = 30, text = d.text}
                    -- Navi zum naechsten Lehrer, der diese Stufe lehrt
                    local e = crafting.Trainers:BestFor(d.prof, d.rank)
                    local navi = ONE.modules and ONE.modules.nav
                    if e and navi and navi.PointTo then
                        item.naviTip = T("Zu %s (%s)", e.npc, T(e.area or ""))
                        item.navi = function() navi:PointTo(e.npc, e.map, e.x, e.y, {service = true}) end
                    end
                    out[#out + 1] = item
                end
            end
            return out
        end)
    end
    if ONE.UI.AddShareOption then
        ONE.UI:AddShareOption({id = "recipes", module = "crafting", order = 30, label = "Rezepte teilen",
            tooltip = "Deine Rezepte für die Gilde sichtbar machen (nur mit Guild Trip, jederzeit abschaltbar).",
            get = function() return crafting.Share:IsSharing() end, set = function(on) crafting.Share:SetSharing(on) end})
    end
    return ONE.UI:AddTab("crafting", T("Berufe"), function(panel) return self:Build(panel) end)
end
