-- Project ONE Berufe: Reiter "Berufe".
-- Links: alles, was du oder deine Gilde herstellen kann (Suche, Beruf-Filter).
-- Rechts: Gegenstand, Rezept und wer es kann (online zuerst, sonst mit Stand)
-- mit "Anfragen": oeffnet das Fluesterfenster mit fertigem Text – absenden
-- tust du selbst mit Enter.
local _, crafting = ...
local ONE = _G.ProjectONE
local function Paint(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Page = {rows = 6}
crafting.Page = Page

local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    if ONE.Fit then ONE.Fit:Line(fs) end
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
    if entry.trade then
        return T("Hallo %s, ich habe deinen Link (%s) im Chat gesehen. Könntest du mir etwas herstellen?", Short(crafter.name), entry.prof)
    end
    local what = R:ItemLink(entry.itemID) or R:ItemName(entry.itemID) or R:Name(entry.recipeID)
    return T("Hallo %s, könntest du mir %s herstellen? Die Materialien bringe ich gern mit.", Short(crafter.name), what)
end

-- Fluesterfenster mit fertigem Text oeffnen (Spieler sendet selbst).
function Page:Ask(entry, crafter)
    local text = self:RequestText(entry, crafter)
    return ONE:Whisper(crafter.name, text)
end

function Page:Build(panel)
    local R, S = crafting.Recipes, crafting.Share
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local leftW, gap = 430, 12
    local rightX, rightW = leftW + gap, W - leftW - gap
    local store = R:Store()
    local state = {}

    local pageTitle = Text(panel, "GameFontNormalLarge", 0, -4, 80, "accent", T("Berufe"))
    -- Rezepte (wer kann was herstellen). Die Lehrer stehen seit 23.11.2026 nur noch in Navi › Lehrer
    -- (Nutzer: "nur navi, aber mit suchfunktion"); hier fuehrt ein Knopf dorthin.
    local rv = CreateFrame("Frame", nil, panel)
    rv:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    rv:SetSize(W, H)
    -- nur noch eine Ansicht: keine Unterseiten-Liste (Nutzer 23.11.2026: einzelnes "Rezepte" wirkte leer)
    if ONE.UI.SetViews and ONE.UI:SetViews("crafting", {}) then
        ONE.UI:RetireButtons(pageTitle)
        self.headerViews = true
    end
    local toTrainers = ONE.Widgets:Button(rv, T("Lehrer in der Navi"), 150, 22, "TOPRIGHT", -178, -2, function()
        Page:OpenTrainers(store.filter)
    end)
    if toTrainers.HookScript then
        toTrainers:HookScript("OnEnter", function(b)
            if not GameTooltip then return end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:AddLine(T("Zeigt in Navi › Lehrer die Lehrer für den gewählten Beruf – mit Suche und Navi-Pfeil."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        toTrainers:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
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
            if ONE.Glass and ONE.Glass.RoundIcon then ONE.Glass:RoundIcon(row, row.icon) end
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
        -- 0.7.2: Berufsfenster eines Spielers aus dem Chat ansehen (wie Klick auf seinen Link)
        local view = ONE.Widgets:Button(card, T("Ansehen"), 76, 22, "TOPRIGHT", -94, y + 2, function()
            local c = rows[i].crafter
            if c and c.link then crafting.ChatLinks:Open(c.link) end
        end)
        rows[i] = {name = name, info = info, ask = ask, view = view}
    end
    local more = Text(card, "GameFontDisableSmall", 14, -74 - self.rows * 40, inner, "soft")

    local function Changed() Page:Refresh() end
    if search.HookScript then search:HookScript("OnTextChanged", Changed) end

    self.refresh = function()
        rv:Show()
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
                e.label = e.trade and T("%s (ganzer Beruf)", e.prof) or R:ItemName(e.itemID) or R:Name(e.recipeID)
                local hay = string.lower(e.label .. " " .. (e.trade and e.prof or R:Name(e.recipeID)))
                if query == "" or hay:find(query, 1, true) then
                    e.online = 0
                    for _, c in ipairs(e.crafters) do
                        c.online = c.me or online[c.name:lower()] or online[Short(c.name):lower()] or false
                        if c.online and not c.me then e.online = e.online + 1 end
                    end
                    table.sort(e.crafters, function(a, b)
                        if a.online ~= b.online then return a.online end
                        if (a.chat or false) ~= (b.chat or false) then return not a.chat end
                        if a.chat then return (a.stamp or 0) > (b.stamp or 0) end
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
        for _, r in ipairs(rows) do r.name:SetText("") r.info:SetText("") r.ask:Hide() r.view:Hide() r.crafter = nil end
        more:SetText("")
        if not e then title:SetText("") recipe:SetText("") head:SetText("") return end
        title:SetText(e.label)
        recipe:SetText(e.trade and T("Im Chat verlinkt – „Ansehen“ öffnet das Berufsfenster")
            or (R:Name(e.recipeID) .. "  ·  " .. e.prof))
        head:SetText(e.trade and T("WER HAT DEN BERUF VERLINKT?") or T("WER KANN ES HERSTELLEN?"))
        for i, c in ipairs(e.crafters) do
            if i > #rows then more:SetText(T("+%d weitere", #e.crafters - #rows)) break end
            local row = rows[i]
            row.crafter = c
            row.name:SetText(c.me and T("%s (du)", Short(c.name)) or Short(c.name))
            row.name:SetTextColor(c.online and 1 or .6, c.online and 1 or .6, c.online and 1 or .6)
            if c.chat then
                -- aus dem Chat: "hat verlinkt", nicht sicher; online nur bei Gildenmitgliedern bekannt
                local where = T(crafting.ChatLinks.SOURCE_NAMES[c.src] or "Chat")
                row.info:SetText((c.online and ("|cff80e680" .. T("online") .. "|r  ·  ") or "")
                    .. T("hat am %s im Chat verlinkt (%s)", Page:Date(c.stamp), where))
                row.name:SetTextColor(c.online and 1 or .8, c.online and 1 or .8, c.online and 1 or .8)
            else
                row.info:SetText((c.online and ("|cff80e680" .. T("online") .. "|r") or T("offline · Stand %s", Page:Date(c.stamp)))
                    .. "  ·  " .. T("Fertigkeit %s", tostring(c.skill or "?")))
            end
            if not c.me then row.ask:Show() end
            if c.link then row.view:Show() end
            row.name:SetWidth(c.link and inner - 170 or inner - 86)
        end
    end
    return self.refresh
end

-- Navi › Lehrer oeffnen, passend zum gewaehlten Beruf (sonst alle Berufslehrer)
function Page:OpenTrainers(prof)
    local navi = ONE.modules and ONE.modules.nav
    if not (navi and navi.ShowTrainers and (not ONE.IsEnabled or ONE:IsEnabled("nav"))) then
        ONE:Print(T("Die Lehrer stehen in der Navi – das Modul Navigation ist aus.")) return false
    end
    local filter = "profession"
    if prof then
        for _, e in ipairs(crafting.Trainers:All()) do
            if e.kind == "profession" and e.what == prof then filter = "p:" .. prof break end
        end
    end
    return navi:ShowTrainers(filter)
end

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
                    local item = {icon = "Interface\\Icons\\Trade_BlackSmithing", link = "nav-trainers", sort = 30, text = d.text}
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
    -- "!" an der Minimap und "Was steht an" (faellige Ausbildung) fuehren zu Navi › Lehrer (Berufe)
    if ONE.UI.AddAlias then
        ONE.UI:AddAlias("nav-trainers", "nav", function()
            local navi = ONE.modules and ONE.modules.nav
            if navi and navi.ShowTrainers then navi:ShowTrainers("profession", true) end
            if ONE.MinimapButton and ONE.MinimapButton.ClearAlert then ONE.MinimapButton:ClearAlert("crafting") end
        end)
    end
    return ONE.UI:AddTab("crafting", T("Berufe"), function(panel) return self:Build(panel) end)
end
