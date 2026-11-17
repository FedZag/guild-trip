local _, ONE = ...

-- Sprachen: Deutsch ist die Quellsprache im Code. Jeder sichtbare Text geht
-- durch ONE.T("deutscher Text"); fuer Englisch liefert die Tabelle ONE.EN die
-- Uebersetzung. Fehlt ein Eintrag, bleibt der deutsche Text stehen (so kann
-- Seite fuer Seite uebersetzt werden). Module fuellen ONE.EN in ihrer eigenen
-- Datei Locale_enUS.lua.
-- Auswahl in den Optionen: Automatisch (Spielsprache) / Deutsch / English.
-- Gespeichert in ProjectONEDB.language ("de", "en" oder nil = automatisch).
ONE.EN = ONE.EN or {}

function ONE:Language()
    local choice = self.db and self.db.language
    if choice == "de" or choice == "en" then return choice end
    local ok, locale = pcall(GetLocale)
    return (ok and locale == "deDE") and "de" or "en"
end

-- T("Text") oder T("Noch %d Punkte", 3)
function ONE.T(text, ...)
    local out = text
    if type(text) == "string" and ONE:Language() == "en" then out = ONE.EN[text] or text end
    if select("#", ...) > 0 and type(out) == "string" then
        local ok, formatted = pcall(string.format, out, ...)
        if ok then return formatted end
    end
    return out
end

-- Fuer Tests und die Optionen: Anteil der vorhandenen Uebersetzungen.
function ONE:TranslationCount()
    local n = 0
    for _ in pairs(self.EN) do n = n + 1 end
    return n
end
