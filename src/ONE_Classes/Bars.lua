local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Legt die vorgeschlagenen Zauber auf die Blizzard-Aktionsleisten.
-- Nur ausserhalb des Kampfes und nach Rueckfrage. Vorher wird die bisherige
-- Belegung jedes betroffenen Platzes gemerkt; "Rueckgaengig" stellt sie her.
-- Plaetze fuer noch nicht gelernte Zauber bleiben unangetastet.
local Bars = {}
classes.Bars = Bars

local Path = classes.Player.Path

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    return ONE.db.classGuide
end

local function InCombat() return type(InCombatLockdown) == "function" and InCombatLockdown() end

-- Welchen Zauber wirkt das Makro auf diesem Platz? (Name oder nil)
-- Neuere Clients (auch Forever) liefern bei Makros direkt die Zauber-Nummer
-- (GetActionInfo -> "macro", Zauber-Nummer, "spell"); aeltere die Makro-Nummer.
-- Zur Sicherheit auch ueber den Makronamen (GetActionText) nachfragen.
function Bars:SlotMacroSpell(slot)
    local kind, id, sub = Call(GetActionInfo, slot)
    if kind ~= "macro" then return nil end
    if sub == "spell" and type(id) == "number" then
        local name = classes.Player.SpellInfo(id)
        if name then return name end
    end
    local name = self:MacroSpellName(id)
    if name then return name end
    local macroName = Call(GetActionText, slot)
    if type(macroName) == "string" and macroName ~= "" then return self:MacroSpellName(macroName) end
end

-- Makros auf allen Leisten: Zaubername -> erster Platz mit einem Makro dafuer.
function Bars:MacroSlots()
    local found = {}
    for slot = 1, (classes.Ranks and classes.Ranks.maxSlot or 120) do
        local name = self:SlotMacroSpell(slot)
        if name and not found[name] then found[name] = slot end
    end
    return found
end

-- Alle Plaetze der drei Guild-Trip-Leisten (1-12, 61-72, 49-60)
function Bars:ManagedSlots(build)
    local list = {}
    local D = classes.Data
    for bar, first in pairs(D.barSlots) do
        -- Gestalt-Leisten nur, wenn der Bauplan sie nutzt (Krieger-Haltungen!)
        local use = not D.formBars[bar]
        if not use then
            for _, f in ipairs(build and build.forms or {}) do if f.bar == bar then use = true end end
        end
        if use then for i = 0, 11 do list[#list + 1] = first + i end end
    end
    table.sort(list)
    return list
end

-- Vorschlag: jeder Eintrag mit festem Aktions-Slot.

function Bars:Plan(p, build)
    local plan = {}
    local macros = self:MacroSlots()
    for _, bar in ipairs(classes.Data.AllBars(build)) do
        local first = classes.Data.barSlots[bar.bar]
        for pos, step in ipairs(bar.slots) do
            -- exact = true: immer genau dieser Rang; Zahl: erst ab dieser Stufe (vorher der höchste Rang)
            local exact = step.exact == true or (type(step.exact) == "number" and (p.level or 1) >= step.exact)
            local s = p:Spell(step[1], exact)
            -- Talent-Plaetze (ab 9) erst zeigen, wenn das Talent gelernt ist
            if not step.talent or s.known then plan[#plan + 1] = {bar = bar.bar, pos = pos, slot = first + pos - 1, spellID = s.id, name = s.name,
                icon = s.icon, known = s.known, label = step[2], ids = classes.Data.Ids(step[1]), macroSlot = s.name and macros[s.name] or nil} end
        end
        -- Volksfaehigkeit: fester Platz 12, nur wenn bekannt
        local race = classes.Data.raceSlots and classes.Data.raceSlots[bar.bar]
        local pos = classes.Data.racePos or 12
        if race and #bar.slots < pos then
            local s = p:Spell(race[1])
            if s.known then
                plan[#plan + 1] = {bar = bar.bar, pos = pos, slot = first + pos - 1, spellID = s.id, name = s.name,
                    icon = s.icon, known = true, label = race[2], ids = classes.Data.Ids(race[1]), race = true,
                    macroSlot = s.name and macros[s.name] or nil}
            end
        end
    end
    return plan
end

-- Klassenzauber, die im Vorschlag nicht vorkommen (bleiben im Zauberbuch).
-- Nur Reiter der Klasse (2 .. Anzahl Ausrichtungen + 1); "Allgemein" mit
-- Volksfaehigkeiten und Berufe zaehlen nicht dazu.
function Bars:Unused(p, build)
    local def = classes.Data.classes[p.classFile or ""]
    local lastTab = 1 + (def and #def.specs or 0)
    local planned = {}
    for _, bar in ipairs(classes.Data.AllBars(build)) do
        for _, step in ipairs(bar.slots) do
            for _, id in ipairs(classes.Data.Ids(step[1])) do
                local name = classes.Player.SpellInfo(id)
                if name then planned[name] = true end
            end
        end
    end
    local list = {}
    for name, e in pairs(p.known or {}) do
        if not planned[name] and (e.tab or 0) >= 2 and (e.tab or 0) <= lastTab then
            list[#list + 1] = {id = e.id, name = name, icon = e.icon, known = true}
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Ist eine Zusatzleiste eingeblendet? (Leiste 1 ist immer da)
function Bars:IsBarShown(bar)
    local name = classes.Data.barFrames[bar]
    if not name then return true end
    local frame = _G[name]
    if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then return nil end
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown or false
end

local function PickupSpellID(id)
    local new = Path("C_Spell.PickupSpell")
    if type(new) == "function" then return pcall(new, id) end
    return pcall(PickupSpell, id)
end

local function Pickup(kind, id)
    if kind == "spell" then
        return PickupSpellID(id)
    elseif kind == "item" then
        if type(Path("C_Item.PickupItem")) == "function" then Call(Path("C_Item.PickupItem"), id) else Call(PickupItem, id) end
        return true
    elseif kind == "macro" then
        Call(PickupMacro, id)
        return true
    end
    return false
end

function Bars:Current(slot)
    local kind, id, sub = Call(GetActionInfo, slot)
    if kind == nil then return {empty = true} end
    local entry = {kind = kind, id = id, sub = sub}
    -- Makros ueber ihren Namen merken: die Nummer ist je nach Client die Zauber-Nummer
    if kind == "macro" then entry.macroName = Call(GetActionText, slot) end
    return entry
end

-- Legt die gelernten Zauber auf ihre Plaetze. Gibt die Anzahl zurueck.
function Bars:Apply(p, build)
    if InCombat() then ONE:Print(T("Leisten bitte nach dem Kampf einrichten.")) return 0 end
    local store = Store()
    store.backup = type(store.backup) == "table" and store.backup or {}
    local placed, macros, used, removed = 0, 0, 0, 0
    self.keptMacros = {}
    -- Erst aufraeumen: nicht eingeplante Klassenzauber von allen Leisten nehmen
    -- (gesichert; Makros, Gegenstaende, Volks- und Berufsfaehigkeiten bleiben).
    local unused = {}
    for _, u in ipairs(self:Unused(p, build)) do unused[u.name] = true end
    for slot = 1, (classes.Ranks and classes.Ranks.maxSlot or 120) do
        local kind, id = Call(GetActionInfo, slot)
        local name = kind == "spell" and classes.Player.SpellInfo(id)
        if name and unused[name] then
            if store.backup[slot] == nil then store.backup[slot] = self:Current(slot) end
            Call(ClearCursor)
            Call(PickupAction, slot)
            Call(ClearCursor)
            removed = removed + 1
        end
    end
    -- Doppelte eingeplante Zauber auf den drei Guild-Trip-Leisten abraeumen: ein
    -- Zauber gehoert nur auf seinen Platz (oder ist durch ein Makro abgedeckt).
    -- Liegt auf seinem Platz ein fremdes Makro, bleibt eine vorhandene Kopie stehen.
    local plan = {}
    -- Volksfaehigkeit, die schon irgendwo liegt, bleibt dort (nicht verschieben)
    local onBars = {}
    for slot = 1, (classes.Ranks and classes.Ranks.maxSlot or 120) do
        local kind, id = Call(GetActionInfo, slot)
        local name = kind == "spell" and classes.Player.SpellInfo(id)
        if name then onBars[name] = true end
    end
    for _, e in ipairs(self:Plan(p, build)) do
        if not (e.race and e.name and onBars[e.name]) then plan[#plan + 1] = e end
    end
    local home = {} -- Zaubername -> Platz, "macro" (durch Makro abgedeckt) oder false (nicht ablegbar)
    for _, e in ipairs(plan) do
        if e.known then
            local target
            if e.macroSlot then target = "macro"
            elseif self:Current(e.slot).kind == "macro" then target = false
            else target = e.slot end
            for _, id in ipairs(e.ids or {}) do
                local name = classes.Player.SpellInfo(id)
                if name and home[name] == nil then home[name] = target end
            end
        end
    end
    local duplicates = 0
    for _, slot in ipairs(self:ManagedSlots(build)) do
        local kind, id = Call(GetActionInfo, slot)
        local name = kind == "spell" and classes.Player.SpellInfo(id)
        local target = name and home[name]
        if target ~= nil and target ~= false and target ~= slot then
            if store.backup[slot] == nil then store.backup[slot] = self:Current(slot) end
            Call(ClearCursor)
            Call(PickupAction, slot)
            Call(ClearCursor)
            duplicates = duplicates + 1
        end
    end
    self.lastDuplicates = duplicates
    -- Makros fuer eingeplante Zauber wandern auf den Platz ihres Zaubers (Tausch:
    -- was dort lag, kommt auf den alten Makro-Platz – es geht nichts verloren).
    -- Ein Makro, das schon auf einem passenden Platz liegt, bleibt dort.
    local moved, claimed = 0, {}
    -- Zaubernamen des Plans: liegt auf dem Zielplatz ein Makro fuer einen ANDEREN
    -- eingeplanten Zauber, wird getauscht (es wandert danach selbst an seinen Platz)
    local plannedName = {}
    for _, e in ipairs(plan) do if e.known and e.name then plannedName[e.name] = true end end
    for _, e in ipairs(plan) do
        if e.known and e.macroSlot then
            local from = self:MacroSlots()[e.name]
            local target = self:Current(e.slot)
            local targetMacro = target.kind == "macro" and self:SlotMacroSpell(e.slot)
            local swappable = target.kind ~= "macro" or (targetMacro and targetMacro ~= e.name and plannedName[targetMacro])
            if from == e.slot then
                claimed[e.slot] = true
            elseif from and not claimed[from] and not claimed[e.slot] and swappable then
                if store.backup[from] == nil then store.backup[from] = self:Current(from) end
                if store.backup[e.slot] == nil then store.backup[e.slot] = self:Current(e.slot) end
                Call(ClearCursor)
                Call(PickupAction, from)
                Call(PlaceAction, e.slot)
                -- Verdraengtes (falls vorhanden) auf den alten Makro-Platz
                if type(GetCursorInfo) ~= "function" or Call(GetCursorInfo) then Call(PlaceAction, from) end
                Call(ClearCursor)
                claimed[e.slot] = true
                moved = moved + 1
            end
        end
    end
    self.lastMoved = moved
    for _, e in ipairs(plan) do
        -- Liegt schon ein Makro fuer diesen Zauber auf einer Leiste, bleibt es dort
        -- und uebernimmt den Platz in der Rotation.
        if e.known and e.macroSlot then
            used = used + 1
        elseif e.known then
            local current = self:Current(e.slot)
            local already = current.kind == "spell" and current.id == e.spellID
            -- Makros fuer Zauber ausserhalb des Plans bleiben liegen (wer ein Makro hat,
            -- hat einen Grund) – ihr Name wird gemeldet
            if current.kind == "macro" then
                already = true
                if self:SlotMacroSpell(e.slot) ~= e.name then
                    macros = macros + 1
                    self.keptMacros = self.keptMacros or {}
                    self.keptMacros[#self.keptMacros + 1] = {slot = e.slot, name = current.macroName or "?", spell = e.name}
                end
            end
            if not already then
                if store.backup[e.slot] == nil then store.backup[e.slot] = current end
                Call(ClearCursor)
                if PickupSpellID(e.spellID) then
                    Call(PlaceAction, e.slot)
                    placed = placed + 1
                end
                Call(ClearCursor) -- was vorher dort lag, faellt vom Mauszeiger (ist gesichert)
            end
        end
    end
    self.lastMacros = macros
    store.managed = true -- ab jetzt pflegt Guild Trip die Leisten (neue Zauber, siehe AutoAdd)
    return placed, macros, used, removed, duplicates, moved
end

-- Neu gelernte, eingeplante Zauber auf ihren Platz legen. Nur wenn der
-- Spieler einmal "Leisten einrichten" benutzt hat und das Haekchen an ist;
-- nur auf einen freien Platz; nicht, wenn der Zauber schon auf einer Leiste
-- liegt oder ein Makro ihn abdeckt. learned: {Zaubername = true}, wird geleert.
function Bars:AutoAdd(learned)
    local function Clear() for k in pairs(learned) do learned[k] = nil end end
    local store = Store()
    if not store.managed or not (classes.Ranks and classes.Ranks:Enabled()) then Clear() return 0 end
    if InCombat() then return 0 end -- nach dem Kampf (Ranks:OnCombatEnded)
    local p = classes.Player:Read(store.spec)
    local def = classes.Data.classes[p.classFile or ""]
    if not def then Clear() return 0 end
    local build = classes.Data:Build(def, p.spec, p.situation)
    local onBars = {}
    for slot = 1, (classes.Ranks and classes.Ranks.maxSlot or 120) do
        local kind, id = Call(GetActionInfo, slot)
        local name = kind == "spell" and classes.Player.SpellInfo(id)
        if name then onBars[name] = true end
    end
    local added = 0
    for _, e in ipairs(self:Plan(p, build)) do
        if e.known and e.name and learned[e.name] and not e.macroSlot and not onBars[e.name]
            and self:Current(e.slot).empty then
            Call(ClearCursor)
            if PickupSpellID(e.spellID) then
                Call(PlaceAction, e.slot)
                added = added + 1
                onBars[e.name] = true
                ONE:Print(e.bar == 1 and T("%s neu auf Leiste 1 gelegt (Taste %d).", e.name, e.pos)
                    or T("%s neu auf Leiste %d gelegt.", e.name, e.bar))
            end
            Call(ClearCursor)
        end
    end
    Clear()
    return added
end

-- Welcher Zauber wirkt ein Makro? (nil, wenn unbekannt)
function Bars:MacroSpellName(index)
    local spellID = Call(GetMacroSpell, index)
    if type(spellID) ~= "number" then return nil end
    return (classes.Player.SpellInfo(spellID))
end

function Bars:HasBackup()
    local b = Store().backup
    return type(b) == "table" and next(b) ~= nil
end

-- Stellt die gemerkte Belegung wieder her.
function Bars:Undo()
    if InCombat() then ONE:Print(T("Bitte nach dem Kampf.")) return 0 end
    local store = Store()
    local restored = 0
    for slot, old in pairs(store.backup or {}) do
        Call(ClearCursor)
        if old.empty then
            Call(PickupAction, slot)
            Call(ClearCursor)
            restored = restored + 1
        elseif Pickup(old.kind, old.kind == "macro" and old.macroName or old.id) then
            Call(PlaceAction, slot)
            Call(ClearCursor)
            restored = restored + 1
        end
    end
    store.backup = {}
    return restored
end

-- Rueckfrage mit Blizzard-Dialog; ohne Dialog direkt ausfuehren.
function Bars:Confirm(text, onAccept)
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return onAccept() end
    StaticPopupDialogs.GUILDTRIP_BARS = {
        text = text, button1 = T("Ja"), button2 = T("Abbrechen"),
        OnAccept = function() onAccept() end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }
    StaticPopup_Show("GUILDTRIP_BARS")
end
