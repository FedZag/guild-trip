-- Project ONE Berufe, Stufe 0: Was liefert WoW Forever zu Berufen und Rezepten?
-- 1) /one berufediag: eigene Berufe und vorhandene Schnittstellen
-- 3) Automatisch beim Lehrer (z. B. Waffenmeister): angebotene Fertigkeiten
-- 2) Automatisch beim Oeffnen eines Berufsfensters: Rezeptliste (Anzahl,
--    Beispiele mit Name, gelernt, Ergebnis-Gegenstand, Reagenzien)
-- Nur eigene Daten, nichts wird gesendet.
local _, ns = ...
local ONE = _G.ProjectONE
-- Liegt in ONE_Dev (nur fuer die Entwicklung) und haengt sich an den
-- Namensraum des Moduls (ONE.ns.crafting). Ohne das Modul passiert nichts.
local crafting = (ONE.ns and ONE.ns.crafting) or ns
if not crafting then return end
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end
local Diag = {maxSamples = 8}
crafting.Diag = Diag

local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, s = pcall(issecretvalue, v)
    return ok and s == true
end
local function Plain(v)
    if IsSecret(v) then return "GEHEIM" end
    local t = type(v)
    if v == nil then return "nil" end
    if t == "number" or t == "boolean" then return v end
    if t == "string" then return #v > 90 and v:sub(1, 90) or v end
    return "<" .. t .. ">"
end
local function Pack(...) return {n = select("#", ...), ...} end
local function Try(fn, ...)
    if type(fn) ~= "function" then return {status = "FEHLT", n = 0} end
    local r = Pack(pcall(fn, ...))
    if not r[1] then return {status = "FEHLER", err = Plain(tostring(r[2])), n = 0} end
    local out = {status = "OK", n = r.n - 1}
    for i = 2, math.min(r.n, 21) do out[i - 1] = Plain(r[i]) end
    return out
end
Diag.Try, Diag.Plain = Try, Plain
local function Has(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return false end
        cur = cur[part]
    end
    return type(cur) == "function"
end
local function CopyTable(t, depth)
    depth = depth or 0
    if type(t) ~= "table" or IsSecret(t) then return Plain(t) end
    if depth > 2 then return "<tabelle>" end
    local out, n = {}, 0
    for k, v in pairs(t) do
        n = n + 1
        if n > 25 then break end
        if type(k) == "string" or type(k) == "number" then out[k] = CopyTable(v, depth + 1) end
    end
    return out
end

function Diag:Store()
    if not DevDB() then return nil end
    DevDB().craftDiag = type(DevDB().craftDiag) == "table" and DevDB().craftDiag or {}
    local d = DevDB().craftDiag
    d.windows = type(d.windows) == "table" and d.windows or {}
    return d
end

function Diag:Apis()
    local names = {
        "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
        "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetRecipeSchematic",
        "C_TradeSkillUI.GetRecipeItemLink", "C_TradeSkillUI.GetRecipeOutputItemData",
        "C_TradeSkillUI.GetBaseProfessionInfo", "C_TradeSkillUI.GetChildProfessionInfo",
        "C_TradeSkillUI.GetTradeSkillLine", "C_TradeSkillUI.IsTradeSkillLinked", "C_TradeSkillUI.OpenTradeSkill",
        "C_TradeSkillUI.GetProfessionInfoBySkillLineID", "C_TradeSkillUI.GetTradeSkillListLink",
        "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillItemLink", "GetTradeSkillRecipeLink",
        "GetNumCrafts", "GetCraftInfo", "C_Item.GetItemInfo", "C_Item.GetItemNameByID", "ChatFrame_OpenChat",
    }
    local out = {}
    for _, name in ipairs(names) do out[name] = Has(name) end
    return out
end

function Diag:Professions()
    local out = {}
    local p = Try(GetProfessions)
    out.status = p.status
    out.raw = p
    for i = 1, 6 do
        local index = p[i]
        if type(index) == "number" then
            out[#out + 1] = {index = index, info = Try(GetProfessionInfo, index)}
        end
    end
    -- Classic-Weg ueber die Fertigkeitenliste
    local n = Try(GetNumSkillLines)[1]
    out.skillLines = {}
    if type(n) == "number" then
        for i = 1, math.min(n, 80) do
            local s = Try(GetSkillLineInfo, i)
            out.skillLines[#out.skillLines + 1] = {s[1], s[2], s[4], s[7]}
        end
    end
    return out
end

function Diag:Run()
    local d = self:Store()
    if not d then return end
    self.active = true -- erst nach /trip berufediag werden Fenster und Lehrer mitgeschrieben
    d.run = {time = Try(GetServerTime)[1], level = Try(UnitLevel, "player")[1],
        apis = self:Apis(), professions = self:Professions()}
    local profCount = 0
    for _, p in ipairs(d.run.professions) do profCount = profCount + 1 end
    ONE:Print("Berufe-Test gespeichert: " .. profCount .. " Berufe über GetProfessions, "
        .. #d.run.professions.skillLines .. " Einträge in der Fertigkeitenliste.")
    ONE:Print("Jetzt bitte jedes Berufsfenster einmal öffnen (z. B. Bergbau, Kräuterkunde, Schneiderei).")
    ONE:Print("Wenn du magst: einen Waffenmeister ansprechen (Orgrimmar: Sayoc, Hanashi; Donnerfels; Unterstadt).")
    ONE:Print("Danach /reload, damit WoW speichert.")
    return d.run
end

-- Beim Oeffnen eines Berufsfensters: was steht drin?
function Diag:CaptureWindow(event)
    if not self.active then return end
    local d = self:Store()
    if not d then return end
    local w = {time = Try(GetServerTime)[1], event = event, samples = {}}
    w.line = Try(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine)
    local okBase, base = pcall(function() return C_TradeSkillUI.GetBaseProfessionInfo() end)
    w.base = okBase and CopyTable(base) or "FEHLT"
    w.linked = Try(C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillLinked)[1]
    w.listLink = Try(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillListLink)[1]
    local okIds, ids = false, nil
    if C_TradeSkillUI and type(C_TradeSkillUI.GetAllRecipeIDs) == "function" then
        okIds, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    end
    w.recipeCount = okIds and type(ids) == "table" and #ids or "nil"
    if okIds and type(ids) == "table" then
        for i, id in ipairs(ids) do
            if i > self.maxSamples then break end
            local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
            local sample = {id = Plain(id), info = okInfo and CopyTable(info) or "FEHLER"}
            sample.link = Try(C_TradeSkillUI.GetRecipeItemLink, id)[1]
            local okOut, out = pcall(function() return C_TradeSkillUI.GetRecipeOutputItemData(id) end)
            sample.output = okOut and CopyTable(out) or "FEHLT"
            local okSch, sch = pcall(function() return C_TradeSkillUI.GetRecipeSchematic(id, false) end)
            sample.schematic = okSch and CopyTable(sch) or "FEHLT"
            w.samples[#w.samples + 1] = sample
        end
    end
    -- Classic-Weg
    w.classicCount = Try(GetNumTradeSkills)[1]
    if type(w.classicCount) == "number" and w.classicCount > 0 then
        w.classicSamples = {}
        for i = 1, math.min(w.classicCount, self.maxSamples) do
            w.classicSamples[#w.classicSamples + 1] = {info = Try(GetTradeSkillInfo, i), link = Try(GetTradeSkillItemLink, i)[1]}
        end
    end
    d.windows[#d.windows + 1] = w
    while #d.windows > 8 do table.remove(d.windows, 1) end
    ONE:Print("Berufe-Test: Berufsfenster erfasst (" .. tostring(w.recipeCount) .. " Rezepte gefunden).")
end

-- Beim Lehrer (z. B. Waffenmeister): welche Fertigkeiten bietet er an, fuer wen, zu welchem Preis?
function Diag:CaptureTrainer()
    if not self.active then return end
    local T = crafting.Trainers
    if T and T.WithAllFilters then return T:WithAllFilters(function() return self:CaptureTrainerNow() end) end
    return self:CaptureTrainerNow()
end
function Diag:CaptureTrainerNow()
    local d = self:Store()
    if not d then return end
    d.trainers = type(d.trainers) == "table" and d.trainers or {}
    local t = {time = Try(GetServerTime)[1], npc = Try(UnitName, "npc")[1], zone = Try(GetZoneText)[1],
        sub = Try(GetSubZoneText)[1], services = {}}
    local n = Try(GetNumTrainerServices)[1]
    t.count = n
    if type(n) == "number" then
        for i = 1, math.min(n, 60) do
            local info = Try(GetTrainerServiceInfo, i)
            t.services[#t.services + 1] = {name = info[1], rank = info[2], kind = info[3],
                cost = Try(GetTrainerServiceCost, i)[1], level = Try(GetTrainerServiceLevelReq, i)[1],
                skill = Try(GetTrainerServiceSkillReq, i)}
        end
    end
    d.trainers[#d.trainers + 1] = t
    while #d.trainers > 10 do table.remove(d.trainers, 1) end
    ONE:Print("Berufe-Test: Lehrer " .. tostring(t.npc) .. " erfasst (" .. tostring(n) .. " Einträge).")
end

function Diag:Initialize()
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "CRAFT_SHOW"}) do
        pcall(f.RegisterEvent, f, ev)
    end
    local pending = false
    f:SetScript("OnEvent", function(_, event)
        if pending then return end
        pending = true
        local function Go() pending = false self:CaptureWindow(event) end
        if C_Timer and C_Timer.After then C_Timer.After(1, Go) else Go() end
    end)
    self.frame = f
    local trainer = CreateFrame("Frame")
    pcall(trainer.RegisterEvent, trainer, "TRAINER_SHOW")
    trainer:SetScript("OnEvent", function()
        if C_Timer and C_Timer.After then C_Timer.After(.5, function() self:CaptureTrainer() end)
        else self:CaptureTrainer() end
    end)
    self.trainerFrame = trainer
end

-- ===== Anmeldung (nur mit ONE_Dev) =====
ONE:RegisterSlash("berufediag", function()
    if not ONE:IsEnabled("crafting") then ONE:Print("Das Berufe-Modul ist pausiert (/trip modules).") return end
    Diag:Run()
end, "Berufe-Test: was liefert das Spiel?")
Diag:Initialize()
