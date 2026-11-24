-- Guild Trip Berufe: Wer kann diesen Gegenstand herstellen? (Chat-Ideen 24.11.2026)
-- Zeile im Tooltip von Gegenstands-Links (Chat in allen Ansichten, auch WoW-Chat): du selbst, Gildenmitglieder
-- (online zuerst), Leute, die das Rezept im Chat verlinkt haben. Klick auf den Link: Knopf "Bei … anfragen"
-- oeffnet das Fluestern mit fertigem Text (abschicken tust du selbst). Ueber ONE.LinkTips (ONE_Core).
local _, crafting = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Tip = {cacheTime = 0}
crafting.ItemTip = Tip
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end

-- itemID -> {entry, crafters} (30 Sekunden zwischengespeichert: Tooltips kommen oft hintereinander)
function Tip:Index()
    if self.cache and Now() - self.cacheTime < 30 then return self.cache end
    local idx = {}
    for _, e in ipairs(crafting.Recipes:Catalog()) do
        if type(e.itemID) == "number" and e.itemID > 0 then
            local slot = idx[e.itemID]
            if not slot then slot = {entry = e, crafters = {}} idx[e.itemID] = slot end
            for _, c in ipairs(e.crafters) do slot.crafters[#slot.crafters + 1] = c end
        end
    end
    self.cache, self.cacheTime = idx, Now()
    return idx
end
function Tip:Reset() self.cache = nil end

-- Fuer einen Link: {me = true/nil, others = {{name, online, chat, crafter}}, entry}
function Tip:For(itemID)
    local slot = self:Index()[itemID]
    if not slot then return nil end
    local online = crafting.Page and crafting.Page.OnlineSet and crafting.Page:OnlineSet() or {}
    local out, seen = {entry = slot.entry, others = {}}, {}
    for _, c in ipairs(slot.crafters) do
        local key = Short(c.name):lower()
        if c.me then out.me = true
        elseif not seen[key] then
            seen[key] = true
            out.others[#out.others + 1] = {name = c.name, online = online[key] or online[(c.name or ""):lower()] or false,
                chat = c.chat, crafter = c}
        end
    end
    table.sort(out.others, function(a, b)
        if a.online ~= b.online then return a.online end
        if (a.chat or false) ~= (b.chat or false) then return not a.chat end
        return Short(a.name) < Short(b.name)
    end)
    if not out.me and #out.others == 0 then return nil end
    return out
end

function Tip.Provider(link, kind)
    if kind ~= "item" then return nil end
    if ONE.FeatureOn and not ONE:FeatureOn("crafting.itemTip") then return nil end
    local itemID = tonumber(link:match("^item:(%d+)"))
    local info = itemID and Tip:For(itemID)
    if not info then return nil end
    local lines = {}
    if info.me then lines[#lines + 1] = {"|cff40ff40" .. T("Guild Trip: Das kannst du selbst herstellen") .. "|r"} end
    if #info.others > 0 then
        local names = {}
        for i = 1, math.min(3, #info.others) do
            local o = info.others[i]
            names[#names + 1] = Short(o.name) .. (o.online and (" |cff40ff40(" .. T("online") .. ")|r") or "")
                .. (o.chat and (" |cff9d9d9d(" .. T("Chat") .. ")|r") or "")
        end
        local text = T("Guild Trip: Herstellen kann %s", table.concat(names, ", "))
        if #info.others > 3 then text = text .. " " .. T("und %d weitere", #info.others - 3) end
        lines[#lines + 1] = {text, .9, .8, .5}
    end
    local first = info.others[1]
    local button = first and {label = T("Bei %s anfragen", Short(first.name)), run = function()
        if crafting.Page and crafting.Page.Ask then crafting.Page:Ask(info.entry, first.crafter) end
    end} or nil
    return {lines = lines, button = button}
end

if ONE.RegisterFeature then
    ONE:RegisterFeature("crafting.itemTip", {module = "crafting", label = "Hersteller im Gegenstands-Tooltip",
        tooltip = "Zeigt bei Gegenstands-Links (z. B. im Chat), wer in deiner Gilde ihn herstellen kann – online zuerst. Klick auf den Link: Knopf zum Anfragen."})
end
if ONE.LinkTips then ONE.LinkTips:Register("crafting.itemTip", Tip.Provider) end
