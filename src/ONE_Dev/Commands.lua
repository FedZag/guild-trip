local ONE = _G.ProjectONE

-- Testbefehle, die frueher fest im Kern standen.
ONE:RegisterSlash("test", function()
    ONE:Notify("Test-Erinnerung: Der Gildenabend beginnt in 15 Minuten!")
end, "Test-Benachrichtigung")

ONE:RegisterSlash("diag", function()
    local mod = ONE.modules.guild
    if mod and mod.Diagnostics then mod:Diagnostics() else ONE:Print("Das Gildenmodul fehlt.") end
end, "Gilden-Diagnose")

ONE:RegisterSlash("scan", function()
    local mod = ONE.modules.guild
    if mod and mod.RequestRefresh and ONE:IsEnabled("guild") then
        mod:RequestRefresh()
    else
        ONE:Print("Das Gildenmodul ist nicht installiert oder pausiert.")
    end
end, "Gildendaten neu einlesen")

ONE:RegisterSlash("nativ", function()
    if ONE.Native then ONE.Native:OpenPreview() end
end, "Vorschau Blizzard-Vorlagen")

ONE:Print("Entwickler-Werkzeuge geladen (ONE_Dev).")

