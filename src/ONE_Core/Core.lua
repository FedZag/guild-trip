local addonName, ONE = ...
-- Uebersetzung (ONE.T aus Locale.lua); ohne sie bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Andere AddOns haben eigene Namespace-Tabellen. Die Bruecke ist nur das Core-API.
_G.ProjectONE = ONE
ONE.version = "0.7.3-alpha"
ONE.modules = {}
ONE.moduleOrder = {}
ONE.slashCommands = {}
ONE.slashOrder = {}
ONE.started = false
ONE.devKeys = {"spellCatalog", "spellScan", "combatProbe", "navDiag", "craftDiag", "dungeonDiag", "nativeDiag"}
ONE.defaults = {
    remindersEnabled = true,
    soundEnabled = true,
    toastEnabled = true,
    loginSummaryEnabled = true,
    theme = {selected = "forever", uiSounds = true},
    guild = { noticeHistory = {}, locationConsent = {} },
    minimap = { angle = 225, hidden = false },
    modules = {},
    window = {scale=1, x=0, y=0},
}

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = type(value) == "table" and {} or value
        end
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            MergeDefaults(target[key], value)
        end
    end
end

function ONE:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66d9ff[Guild Trip]|r " .. tostring(self.T and self.T(message) or message))
    end
end

-- Öffentliche Benachrichtigungs-Schnittstelle für alle Module.
-- Bestehende Aufrufe ONE:Notify("...") bleiben kompatibel.
function ONE:Notify(message, options)
    if self.Notifications then
        return self.Notifications:Push(message, options)
    end
    self:Print(tostring(message))
    return false
end

function ONE:IsEnabled(id)
    return self.db and self.db.modules[id] ~= false
end

-- Einzelfunktionen der Module, je mit Haekchen in Optionen (Bereich des Moduls, Kern unter Allgemein).
-- def = {module, label, tooltip, reload (wirkt erst nach Neuladen), get, set}
-- Ohne get/set merkt sich der Kern den Schalter in ProjectONEDB.features (Standard: an).
ONE.features, ONE.featureOrder = {}, {}
function ONE:RegisterFeature(id, def)
    if type(id) ~= "string" or type(def) ~= "table" or self.features[id] then return false end
    def.id = id
    self.features[id] = def
    self.featureOrder[#self.featureOrder + 1] = id
    return true
end
-- Kern-Funktionen (gehoeren zu keinem Modul, stehen oben in der Liste)
ONE:RegisterFeature("core.loginSummary", {label = "Tagesüberblick beim Einloggen",
    get = function() return ONE.db and ONE.db.loginSummaryEnabled and true or false end,
    set = function(on) if ONE.db then ONE.db.loginSummaryEnabled = on end end})
ONE:RegisterFeature("core.sounds", {label = "Menüklänge",
    get = function() return ONE.db and ONE.db.theme and ONE.db.theme.uiSounds ~= false end,
    set = function(on) if ONE.db then ONE.db.theme = ONE.db.theme or {} ONE.db.theme.uiSounds = on and true or false end end})
function ONE:FeatureOn(id)
    local def = self.features[id]
    if def and def.module and not self:IsEnabled(def.module) then return false end
    if def and def.get then local ok, on = pcall(def.get) return ok and on and true or false end
    local f = self.db and type(self.db.features) == "table" and self.db.features
    return not (f and f[id] == false)
end
function ONE:SetFeature(id, on)
    local def = self.features[id]
    if def and def.set then pcall(def.set, on) return end
    if not self.db then return end
    self.db.features = type(self.db.features) == "table" and self.db.features or {}
    self.db.features[id] = on and true or false
end

function ONE:RegisterModule(id, def)
    if type(id) ~= "string" or type(def) ~= "table" or self.modules[id] then return false end
    self.modules[id] = def
    self.moduleOrder[#self.moduleOrder + 1] = id
    def.id = id
    if self.started then self:StartModule(id) end
    return true
end

-- Optional modules add their own /one subcommands without editing Core.
-- Built-in commands always win; a name can be registered only once.
function ONE:RegisterSlash(name, handler, help)
    if type(name) ~= "string" or not name:match("^%l+$")
        or type(handler) ~= "function" or self.slashCommands[name] then return false end
    self.slashCommands[name] = {handler = handler, help = help}
    self.slashOrder[#self.slashOrder + 1] = name
    return true
end

-- rest = Rest der Eingabe kleingeschrieben (fuer Schluesselwoerter), raw = wie getippt (z. B. Text fuer /trip sos)
function ONE:RunSlash(name, rest, raw)
    local entry = self.slashCommands[name]
    if not entry then return false end
    local ok, err = pcall(entry.handler, rest or "", raw or rest or "")
    if not ok then
        self:Print(T("/trip %s fehlgeschlagen: %s", name, tostring(err)))
        if self.BugReport then self.BugReport:Record("/trip " .. name, err) end
    end
    return true
end

function ONE:StartModule(id)
    local def = self.modules[id]
    if not def or def.initialized then return end
    -- Ausgeschaltetes Modul startet gar nicht (keine Reiter, keine Ereignisse); gilt ab dem Neuladen
    if self.db and self.db.modules and self.db.modules[id] == false then def.skipped = true return end
    def.initialized = true
    if type(def.Initialize) == "function" then
        local ok, err = pcall(def.Initialize, def, self)
        if not ok then
            def.error = tostring(err)
            self:Print(T("Modul '%s' konnte nicht gestartet werden: %s", id, def.error))
            if self.BugReport then self.BugReport:Record("start " .. id, def.error) end
        end
    end
    if self.UI then self.UI:Refresh() end
end

function ONE:Initialize()
    ProjectONEDB = ProjectONEDB or {}
    MergeDefaults(ProjectONEDB, self.defaults)
    self.db = ProjectONEDB
    -- Testdaten frueherer Versionen gehoeren nicht in die Spieler-Datei (bis zu
    -- ~2 MB, bei jedem Login geladen). Sie ziehen ins Entwickler-Addon ONE_Dev
    -- um, falls es installiert ist; sonst verschwinden sie einfach.
    self.legacyDev = {}
    for _, key in ipairs(self.devKeys) do
        if ProjectONEDB[key] ~= nil then
            self.legacyDev[key] = ProjectONEDB[key]
            ProjectONEDB[key] = nil
        end
    end
    if self.BugReport then self.BugReport:Attach() end
    self.Themes:Initialize()
    self.Notifications:Initialize()
    self.UI:Initialize()
    if self.MinimapButton then self.MinimapButton:Initialize() end
    self.Welcome:Initialize()
    if self.WhatsNew then self.WhatsNew:Initialize() end
    if self.Vendor then self.Vendor:Initialize() end
    -- alle eigenen Fenster durch Ziehen an Kanten/Ecken vergroesserbar (sobald es sie gibt)

    SLASH_PROJECTONE1 = "/trip"
    SLASH_PROJECTONE2 = "/one" -- alter Befehl bleibt fuer bisherige Tester
    SlashCmdList.PROJECTONE = function(input)
        local raw = tostring(input or ""):match("^%s*(.-)%s*$")
        input = raw:lower()
        local command, rest = input:match("^(%S+)%s*(.-)$")
        local rawRest = raw:match("^%S+%s*(.-)$") or ""
        if input == "heute" or input == "today" then
            self.UI:Navigate("today")
        elseif input == "modules" or input == "module" or input == "optionen" or input == "options" then
            -- eigene Modul-Ansicht gibt es seit 17.11.2026 nicht mehr: Module stehen in den Optionen
            if self.UI.OpenOptions then self.UI:OpenOptions() else self.UI:Show() end
        elseif input == "guild" or input == "gilde" then
            if self.UI.tabs.guild then
                self.UI:SelectTab("guild")
                self.UI:Show()
            else
                self:Print("Das Gildenmodul ist nicht installiert.")
            end
        elseif input == "map" or input == "karte" then
            local mod=self.modules.guild
            if mod and mod.OpenMap then mod:OpenMap() else self:Print("Das Gildenmodul fehlt.") end
        elseif input == "minimap" then
            if self.MinimapButton then
                self.MinimapButton:SetVisible(self.db.minimap.hidden)
                self:Print(self.db.minimap.hidden and "Minimap-Button: AUS" or "Minimap-Button: AN")
            end
        elseif command == "klang" or command == "sound" then
            if self.Sound then self.Sound:Demo() end
        elseif command == "bug" or command == "fehler" then
            if self.BugReport then self.BugReport:Slash(rest) end
        elseif input == "help" or input == "hilfe" then
            self:Print("/trip - Fenster | /trip gilde | /trip karte | /trip minimap | /trip bug (Fehler melden)")
            for _, name in ipairs(self.slashOrder) do
                local help = self.slashCommands[name].help
                self:Print("/trip " .. name .. (help and (" - " .. T(help)) or ""))
            end
        elseif command and self:RunSlash(command, rest, rawRest) then
            -- handled by an optional module
        else
            self.UI:Toggle()
        end
    end

    self.started = true
    for _, id in ipairs(self.moduleOrder) do self:StartModule(id) end
    self:Print(T("v%s bereit. Fenster: /trip", self.version))
end

function ProjectONE_Toggle()
    if ONE.UI and ONE.UI.frame then ONE.UI:Toggle() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    ONE:Initialize()
end)
