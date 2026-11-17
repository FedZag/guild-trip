local ONE = _G.ProjectONE

-- Entwickler-Addon: eigene Speicherdatei GuildTripDevDB, damit Testdaten
-- (Zauber-Auslese, Navi-/Berufe-/Dungeon-Tests) nicht in der Spieler-Datei
-- ProjectONEDB landen. Fruehere Testdaten aus ProjectONEDB ziehen einmalig um.
function ONE:DevDB()
    _G.GuildTripDevDB = type(_G.GuildTripDevDB) == "table" and _G.GuildTripDevDB or {}
    local db = _G.GuildTripDevDB
    if self.legacyDev then
        for key, value in pairs(self.legacyDev) do
            if db[key] == nil then db[key] = value end
        end
        self.legacyDev = nil
    end
    return db
end

-- Umzug sofort nach dem Laden der Speicherdatei erledigen.
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= "ONE_Dev" then return end
    self:UnregisterEvent("ADDON_LOADED")
    ONE:DevDB()
end)
