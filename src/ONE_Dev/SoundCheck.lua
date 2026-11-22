-- Pruefung: /trip klangtest (22.11.2026) – darf ein Addon in Forever Klaenge stummschalten (MuteSoundFile)?
-- Vorbereitung fuer eigene Quest-Klaenge, die WoW-Klaenge ersetzen statt doppelt zu klingen.
-- Ablauf (je 2 s): Glocke normal, Glocke stummgeschaltet (nichts hoeren), Glocke wieder an.
-- Ergebnis zusaetzlich in GuildTripDevDB.soundCheck (nach /reload in den SavedVariables lesbar).
local ONE = _G.ProjectONE
local SC = {}
local FILE = "Interface\\AddOns\\ONE_Core\\Sounds\\Glocke.ogg"
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

local function Play() return pcall(PlaySoundFile, FILE, "Master") end

function SC:Run()
    local res = {mute = type(MuteSoundFile), unmute = type(UnmuteSoundFile), at = time and time() or 0}
    local db = DevDB()
    if db then db.soundCheck = res end
    ONE:Print(("Klangtest: Stummschalten %s, Wiederanschalten %s."):format(
        res.mute == "function" and "vorhanden" or "FEHLT", res.unmute == "function" and "vorhanden" or "FEHLT"))
    if res.mute ~= "function" or res.unmute ~= "function" or not (C_Timer and C_Timer.After) then
        ONE:Print("Klangtest: Stummschalten geht in diesem Spiel nicht – eigene Klaenge kaemen dann zusaetzlich.")
        return
    end
    ONE:Print("1/3: Glocke normal – du solltest sie HOEREN.")
    Play()
    C_Timer.After(2, function()
        local ok, err = pcall(MuteSoundFile, FILE)
        res.muteCall = ok and "OK" or tostring(err)
        ONE:Print("2/3: Glocke stummgeschaltet – du solltest jetzt NICHTS hoeren.")
        Play()
        C_Timer.After(2, function()
            local ok2, err2 = pcall(UnmuteSoundFile, FILE)
            res.unmuteCall = ok2 and "OK" or tostring(err2)
            ONE:Print("3/3: Glocke wieder an – du solltest sie wieder HOEREN.")
            Play()
            ONE:Print(("Klangtest fertig (Aufrufe: %s / %s). Sag Claude: 1, 2 und 3 gehoert oder nicht – und ob ein Fenster 'wurde geblockt' kam.")
                :format(res.muteCall, res.unmuteCall))
        end)
    end)
end

ONE:RegisterSlash("klangtest", function() SC:Run() end)
