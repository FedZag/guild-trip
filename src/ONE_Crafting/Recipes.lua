-- Project ONE Berufe: eigene und geteilte Rezepte.
-- Belegt im Forever-Spieltest (12.11.2026): Beim Oeffnen eines Berufsfensters
-- liefert C_TradeSkillUI.GetAllRecipeIDs alle Rezepte des Berufs, jeweils mit
-- learned-Flag, Name und Ergebnis-Gegenstand. Eine recipeID ist eine Zauber-ID.
-- Gespeichert wird: eigene gelernte Rezepte (pro Charakter) und – nur wenn
-- Mitglieder es freigeben – ihre Rezeptlisten mit Datenstand (fuer offline).
local _, crafting = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Recipes = {maxGuildAge = 30 * 24 * 3600}
crafting.Recipes = Recipes

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function Now() return Call(GetServerTime) or (type(time) == "function" and time()) or 0 end
local function Me()
    local name, realm = Call(UnitFullName, "player")
    if name then return (realm and realm ~= "") and (name .. "-" .. realm) or name end
    return Call(UnitName, "player") or "?"
end
Recipes.Me = Me
Recipes.Now = Now

function Recipes:Store()
    if not ONE.db then return {chars = {}, guild = {}, names = {}} end
    ONE.db.crafting = type(ONE.db.crafting) == "table" and ONE.db.crafting or {}
    local s = ONE.db.crafting
    s.chars = type(s.chars) == "table" and s.chars or {}
    s.guild = type(s.guild) == "table" and s.guild or {}
    s.names = type(s.names) == "table" and s.names or {}
    s.shareChars = type(s.shareChars) == "table" and s.shareChars or {}
    -- 0.8: Symbol und Zutaten je Rezept (beim Oeffnen des Berufsfensters gemerkt)
    s.icons = type(s.icons) == "table" and s.icons or {}
    s.reagents = type(s.reagents) == "table" and s.reagents or {}
    return s
end

-- Eigener Charakter: {prof = {skill, max, stamp, recipes = {[recipeID] = itemID or 0}}}
function Recipes:Mine()
    local s = self:Store()
    s.chars[Me()] = type(s.chars[Me()]) == "table" and s.chars[Me()] or {}
    return s.chars[Me()]
end

-- Liest das gerade offene Berufsfenster aus (nur gelernte Rezepte).
function Recipes:Capture()
    if not (C_TradeSkillUI and type(C_TradeSkillUI.GetAllRecipeIDs) == "function") then return nil end
    if Call(C_TradeSkillUI.IsTradeSkillLinked) == true then return nil end -- fremder Beruf per Link
    local base = Call(C_TradeSkillUI.GetBaseProfessionInfo)
    local prof = type(base) == "table" and base.professionName
    if type(prof) ~= "string" or prof == "" then return nil end
    local ids = Call(C_TradeSkillUI.GetAllRecipeIDs)
    if type(ids) ~= "table" then return nil end
    local names = self:Store().names
    local recipes, count = {}, 0
    for _, id in ipairs(ids) do
        local info = Call(C_TradeSkillUI.GetRecipeInfo, id)
        if type(info) == "table" and info.learned == true then
            local out = Call(C_TradeSkillUI.GetRecipeOutputItemData, id)
            local itemID = type(out) == "table" and tonumber(out.itemID) or 0
            recipes[id] = itemID
            if type(info.name) == "string" and info.name ~= "" then names[id] = info.name end
            if info.icon then self:Store().icons[id] = info.icon end
            local reagents = self:ReadReagents(id)
            if reagents then self:Store().reagents[id] = reagents end
            count = count + 1
        end
    end
    self:Mine()[prof] = {skill = tonumber(base.skillLevel) or 0, max = tonumber(base.maxSkillLevel) or 0,
        stamp = Now(), recipes = recipes}
    return prof, count
end

-- Zutaten eines Rezepts aus dem offenen Berufsfenster: {{itemID, menge}, ...} oder nil.
-- Zwei Wege, je nach Client: GetRecipeSchematic (neu) oder GetRecipeNumReagents/-ItemLink (alt).
local function LinkItemID(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
function Recipes:ReadReagents(recipeID)
    local T = C_TradeSkillUI
    if not T then return nil end
    local out = {}
    local schem = Call(T.GetRecipeSchematic, recipeID, false)
    if type(schem) == "table" and type(schem.reagentSlotSchematics) == "table" then
        for _, slot in ipairs(schem.reagentSlotSchematics) do
            local r = type(slot.reagents) == "table" and slot.reagents[1]
            local item = r and tonumber(r.itemID)
            -- reagentType 1 = Pflichtzutat (optionale Zutaten weglassen)
            if item and (slot.reagentType == nil or slot.reagentType == 1) then
                out[#out + 1] = {item, tonumber(slot.quantityRequired) or 1}
            end
        end
        if #out > 0 then return out end
    end
    local n = tonumber((Call(T.GetRecipeNumReagents, recipeID)))
    if not n or n <= 0 then return nil end
    for i = 1, math.min(n, 8) do
        local _, _, count = Call(T.GetRecipeReagentInfo, recipeID, i)
        local item = LinkItemID(Call(T.GetRecipeReagentItemLink, recipeID, i))
        if item then out[#out + 1] = {item, tonumber(count) or 1} end
    end
    return #out > 0 and out or nil
end
function Recipes:Reagents(recipeID) return self:Store().reagents[recipeID] end
-- Symbol: Gegenstand, sonst gemerktes Rezeptsymbol, sonst Zaubersymbol (recipeID = Zauber-ID)
function Recipes:Icon(recipeID, itemID)
    if itemID and itemID > 0 and C_Item then
        local tex = Call(C_Item.GetItemIconByID, itemID)
        if tex then return tex end
    end
    local saved = self:Store().icons[recipeID]
    if saved then return saved end
    return (C_Spell and Call(C_Spell.GetSpellTexture, recipeID)) or Call(GetSpellTexture, recipeID)
end
-- Wie viele hast du (Taschen + Bank)?
function Recipes:Have(itemID)
    local n = C_Item and Call(C_Item.GetItemCount, itemID, true) or Call(GetItemCount, itemID, true)
    return tonumber(n) or 0
end
-- Wie oft kannst du es gerade herstellen? nil, wenn die Zutaten nicht bekannt sind
function Recipes:Craftable(recipeID)
    local list = self:Reagents(recipeID)
    if not list then return nil end
    local times
    for _, r in ipairs(list) do
        local t = math.floor(self:Have(r[1]) / math.max(1, r[2]))
        times = times and math.min(times, t) or t
    end
    return times
end

-- Rezeptname: aus dem eigenen Berufsfenster gemerkt, sonst Zauber-Name (recipeID = Zauber-ID).
function Recipes:Name(recipeID)
    local names = self:Store().names
    if names[recipeID] then return names[recipeID] end
    local name = C_Spell and Call(C_Spell.GetSpellName, recipeID)
    if type(name) == "string" and name ~= "" then names[recipeID] = name return name end
    return T("Rezept %s", tostring(recipeID))
end
function Recipes:ItemName(itemID)
    if not itemID or itemID == 0 then return nil end
    local name = C_Item and Call(C_Item.GetItemNameByID, itemID)
    if type(name) == "string" and name ~= "" then return name end
    -- je Gegenstand nur EINMAL nachladen lassen: jede Antwort loest ein
    -- ITEM_DATA_LOAD_RESULT aus (bis 0.6.4 eine Lawine aus Seiten-Neuaufbauten)
    self.requested = self.requested or {}
    if not self.requested[itemID] and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        self.requested[itemID] = true
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return nil
end
function Recipes:ItemLink(itemID)
    if not itemID or itemID == 0 then return nil end
    local _, link = Call(C_Item and C_Item.GetItemInfo, itemID)
    return link
end

-- Geteilte Daten anderer Mitglieder (inkl. offline, mit Stand). Alte Staende verfallen.
function Recipes:SetGuildProfession(name, prof, skill, max, stamp, recipes)
    local s = self:Store()
    s.guild[name] = type(s.guild[name]) == "table" and s.guild[name] or {}
    s.guild[name][prof] = {skill = skill, max = max, stamp = stamp, recipes = recipes or {}}
end
function Recipes:RemoveMember(name)
    local s = self:Store()
    s.guild[name] = nil
    -- Freigabe zurueckgezogen: auch den Namen bei seinen Lehrer-Funden entfernen.
    for _, t in pairs(type(s.trainers) == "table" and s.trainers or {}) do
        if t.by == name then t.by = nil end
    end
end
function Recipes:Prune(rosterNames)
    local s, now = self:Store(), Now()
    for name, profs in pairs(s.guild) do
        local keep = false
        for prof, data in pairs(profs) do
            if now - (data.stamp or 0) > self.maxGuildAge then profs[prof] = nil else keep = true end
        end
        -- Wer nicht mehr in der Gilde ist, verschwindet (nur wenn die Liste bekannt ist).
        if rosterNames and next(rosterNames) and not rosterNames[name] and not rosterNames[(name:match("^[^-]+") or name)] then keep = false end
        if not keep then s.guild[name] = nil end
    end
    -- Lehrer-Funde: Ort des Lehrers bleibt, der Name des Finders verfaellt wie Rezepte.
    for _, t in pairs(type(s.trainers) == "table" and s.trainers or {}) do
        if t.by and now - (t.seen or 0) > self.maxGuildAge then t.by = nil end
    end
end

-- Alle Herstellbaren: {key = recipeID, name, itemID, prof, crafters = {{name, skill, stamp, me}}}
function Recipes:Catalog()
    local s = self:Store()
    local byRecipe, list = {}, {}
    local function Add(owner, prof, data, me)
        for id, itemID in pairs(data.recipes or {}) do
            local entry = byRecipe[id]
            if not entry then
                entry = {recipeID = id, itemID = itemID, prof = prof, crafters = {}}
                byRecipe[id] = entry
                list[#list + 1] = entry
            end
            entry.crafters[#entry.crafters + 1] = {name = owner, skill = data.skill, stamp = data.stamp, me = me}
        end
    end
    for prof, data in pairs(self:Mine()) do Add(Me(), prof, data, true) end
    for owner, profs in pairs(s.guild) do
        if owner ~= Me() then for prof, data in pairs(profs) do Add(owner, prof, data, false) end end
    end
    return list
end
