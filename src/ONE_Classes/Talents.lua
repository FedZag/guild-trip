local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Talentpunkte nach Plan setzen – halbautomatisch.
--  * Freier Punkt: Hinweis im Chat und "!" am Minimap-Knopf (einmal je Stand).
--  * Knopf "Nächsten Punkt setzen": genau EIN Punkt, nach Rueckfrage.
--  * Haekchen "Talente automatisch nach Plan setzen" (Standard aus): setzt
--    freie Punkte selbst, einen nach dem anderen.
--  * Nur ausserhalb des Kampfes. Sperrt Forever das Setzen, sagt Guild Trip
--    das einmal und zeigt den Punkt nur noch an.
-- Zuruecksetzen von Talenten kostet beim Lehrer Gold – daher vorsichtig.
local Talents = {}
classes.Talents = Talents

local Path = classes.Player.Path

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    return ONE.db.classGuide
end

local function InCombat() return type(InCombatLockdown) == "function" and InCombatLockdown() end

function Talents:AutoEnabled() return Store().autoTalents == true end
function Talents:SetAutoEnabled(on)
    Store().autoTalents = on and true or false
    if on then self:Check() end
end

-- Naechster Schritt laut Plan fuer den aktuellen Spieler.
-- Rueckgabe: p, step, talent (oder nil)
function Talents:Next()
    local store = Store()
    local p = classes.Player:Read(store.spec)
    local def = classes.Data.classes[p.classFile or ""]
    if not def then return p end
    local build = classes.Data:Build(def, p.spec, p.situation)
    local step, t = classes.Player.NextTalent(p, build and build.talents)
    return p, step, t
end

-- Kann jetzt ein Punkt gesetzt werden? (frei, kaufbar, nicht gesperrt)
function Talents:CanSpend(p, step, t)
    -- canPurchaseRank liefert Forever zuverlaessig (true/false)
    return p and step and t and (p.free or 0) > 0 and t.canBuy == true and not self.blocked
end

-- Genau einen Punkt setzen. Rueckgabe true/false.
function Talents:Spend(t)
    if InCombat() then ONE:Print(T("Talente bitte nach dem Kampf setzen.")) return false end
    local traits = Path("C_Traits")
    if not (t and t.config and t.node and type(traits) == "table") then return self:Blocked() end
    local ok
    if t.choice and type(traits.SetSelection) == "function" then
        ok = Call(traits.SetSelection, t.config, t.node, t.entry)
    elseif type(traits.PurchaseRank) == "function" then
        ok = Call(traits.PurchaseRank, t.config, t.node)
    end
    if not ok then return self:Blocked() end
    -- Forever uebernimmt einen gekauften Punkt sofort (wie im klassischen WoW);
    -- eine zusaetzliche Bestaetigung loest dort "Talent kann nicht erlernt werden"
    -- aus. Nur bestaetigen, wenn das Spiel wirklich eine vorgemerkte Aenderung hat.
    -- Robust, unabhaengig davon, welche Abfragen Forever kennt: ist der Rang des
    -- Knotens schon gestiegen, ist der Punkt gesetzt -> nichts nachschicken.
    local needsCommit = true
    local node = Call(traits.GetNodeInfo, t.config, t.node)
    local now = type(node) == "table" and tonumber(node.ranksPurchased or node.currentRank)
    if now and now > (t.ranks or 0) then
        needsCommit = false
    else
        local staged = Path("C_Traits.ConfigHasStagedChanges")
        if type(staged) == "function" then needsCommit = Call(staged, t.config) == true end
    end
    if needsCommit then
        local commit = Path("C_ClassTalents.CommitConfig") or traits.CommitConfig
        if type(commit) == "function" and not Call(commit, t.config) then return self:Blocked() end
    end
    classes.Player:Invalidate()
    ONE:Print(T("Talentpunkt gesetzt: %s (Rang %d).", t.name or "?", (t.ranks or 0) + 1))
    self.notified = nil
    return true
end

-- Forever laesst das Setzen nicht zu: einmal sagen, dann nur noch anzeigen.
function Talents:Blocked()
    if not self.blocked then
        ONE:Print(T("Forever lässt Guild Trip keine Talentpunkte setzen. Bitte im Talentfenster (Taste N) selbst setzen."))
    end
    self.blocked = true
    return false
end

-- Knopf auf der Klasse-Seite: Rueckfrage, dann einen Punkt setzen.
function Talents:AskAndSpend(onDone)
    local p, step, t = self:Next()
    if not self:CanSpend(p, step, t) then
        ONE:Print(T("Gerade gibt es keinen freien Talentpunkt nach Plan."))
        return false
    end
    classes.Bars:Confirm(T("Talentpunkt setzen: %s (Rang %d › %d)?\nZurücksetzen kostet beim Lehrer Gold.",
        t.name or "?", t.ranks or 0, (t.ranks or 0) + 1), function()
        self:Spend(t)
        if onDone then onDone() end
    end)
    return true
end

-- Bei neuem Stand pruefen: automatisch setzen oder Hinweis geben.
function Talents:Check()
    if InCombat() then self.waiting = true return end
    self.waiting = false
    local p, step, t = self:Next()
    local mini = ONE.MinimapButton
    if not self:CanSpend(p, step, t) then
        if mini and mini.ClearAlert then mini:ClearAlert("talent") end
        self.notified = nil
        return
    end
    if self:AutoEnabled() then
        -- einen Punkt setzen; der naechste folgt nach der Rueckmeldung des Spiels
        self:Spend(t)
        return
    end
    if ONE.FeatureOn and not ONE:FeatureOn("classes.talentHint") then return end
    local key = (t.name or "?") .. ":" .. tostring(t.ranks) .. ":" .. tostring(p.free)
    if self.notified == key then return end
    self.notified = key
    local text = T("Talentpunkt frei: %s (Rang %d/%d) – Klasse › „Nächsten Punkt setzen“.", t.name or "?", (t.ranks or 0) + 1, step[2])
    ONE:Print(text)
    if mini and mini.SetAlert then mini:SetAlert("talent", text, "classes") end
end

function Talents:Initialize()
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE",
        "CHARACTER_POINTS_CHANGED", "PLAYER_REGEN_ENABLED", "TRAIT_TREE_CURRENCY_INFO_UPDATED"}) do
        pcall(f.RegisterEvent, f, ev)
    end
    local pending = false
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not self.waiting then return end
        if pending then return end
        pending = true
        local function Go() pending = false Talents:Check() end
        if C_Timer and C_Timer.After then C_Timer.After(1, Go) else Go() end
    end)
    self.frame = f
end
