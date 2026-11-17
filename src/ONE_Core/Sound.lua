local _, ONE = ...

-- Klaenge von Guild Trip (0.6.2): nur Klaenge, die schon im Spiel stecken (SOUNDKIT),
-- keine eigenen Dateien. Alles haengt am Schalter "Menueklaenge" (db.theme.uiSounds).
-- Je Anlass eine Kandidatenliste; der erste, den der Client kennt, wird gespielt.
-- /trip klang spielt alle Anlaesse nacheinander zum Probehoeren vor.
local Sound = {}
ONE.Sound = Sound

Sound.events = {
    {key = "open",     label = "Buch öffnen",        kit = {"IG_SPELLBOOK_OPEN", "IG_CHARACTER_INFO_OPEN"}},
    {key = "page",     label = "Umblättern",         kit = {"IG_ABILITY_PAGE_TURN", "IG_SPELLBOOK_OPEN"}},
    {key = "checkOn",  label = "Häkchen setzen",     kit = {"IG_MAINMENU_OPTION_CHECKBOX_ON"}},
    {key = "checkOff", label = "Häkchen entfernen",  kit = {"IG_MAINMENU_OPTION_CHECKBOX_OFF", "IG_MAINMENU_OPTION_CHECKBOX_ON"}},
    {key = "seal",     label = "Siegel / Hauptaktion", kit = {"LOOT_WINDOW_COIN_SOUND", "IG_QUEST_LIST_COMPLETE"}},
    {key = "menu",     label = "Auswahl aufklappen", kit = {"U_CHAT_SCROLL_BUTTON", "IG_MAINMENU_OPTION_CHECKBOX_ON"}},
    {key = "close",    label = "Buch schließen",     kit = {"IG_SPELLBOOK_CLOSE", "IG_CHARACTER_INFO_CLOSE"}},
}
local byKey = {}
for _, e in ipairs(Sound.events) do byKey[e.key] = e end

-- Eigene Klaenge (15.11.2026, scripts/build_sounds.py, eigene Rechte) fuer Hinweise.
-- Haengen am Schalter "Ton bei Benachrichtigungen" (db.soundEnabled), nicht an den Menueklaengen.
local DIR = "Interface\\AddOns\\ONE_Core\\Sounds\\"
Sound.alerts = {
    {key = "notify", label = "Erinnerung / Hinweis", file = DIR .. "Glocke.ogg"},
    {key = "trip",   label = "Gildenausflug beginnt", file = DIR .. "Ausflug.ogg"},
    -- Chat: dezent und ueber die Effekt-Lautstaerke (SFX), damit sie dem Effekte-Regler folgen
    {key = "chatWhisper", label = "Chat: Flüstern", file = DIR .. "ChatWhisper.ogg", channel = "SFX"},
    {key = "chatMessage", label = "Chat: Gilde/Gruppe", file = DIR .. "ChatMessage.ogg", channel = "SFX"},
    {key = "chatSent", label = "Chat: gesendet", file = DIR .. "ChatSent.ogg", channel = "SFX"},
}
local alertByKey = {}
for _, a in ipairs(Sound.alerts) do alertByKey[a.key] = a end

-- Spielt einen eigenen Hinweisklang; geht das nicht, Blizzards Raid-Warnung
function Sound:PlayAlert(key)
    local a = alertByKey[key] or alertByKey.notify
    if type(PlaySoundFile) == "function" then
        local ok, willPlay = pcall(PlaySoundFile, a.file, a.channel or "Master")
        if ok and willPlay ~= false then return true end
    end
    if type(PlaySound) == "function" and type(SOUNDKIT) == "table" then
        local id = SOUNDKIT.RAID_WARNING or SOUNDKIT.IG_MAINMENU_OPEN
        if id then pcall(PlaySound, id, "Master") return true end
    end
    return false
end

local function Resolve(e)
    if type(SOUNDKIT) ~= "table" or not e then return end
    for _, name in ipairs(e.kit) do if SOUNDKIT[name] then return SOUNDKIT[name], name end end
end

function Sound:Enabled() return ONE.db and ONE.db.theme and ONE.db.theme.uiSounds and true or false end

-- Spielt den Klang zu einem Anlass (nur mit eingeschalteten Menueklaengen)
function Sound:Play(key, force)
    if not force and not self:Enabled() then return false end
    local id = Resolve(byKey[key])
    if not (id and type(PlaySound) == "function") then return false end
    pcall(PlaySound, id, "SFX")
    return true
end

-- /trip klang: alle Anlaesse im Abstand von 1,5 s vorspielen (auch wenn Menueklaenge aus sind)
function Sound:Demo()
    local T = ONE.T or function(t) return t end
    local list = {}
    for _, e in ipairs(self.events) do list[#list + 1] = e end
    for _, a in ipairs(self.alerts) do list[#list + 1] = a end
    ONE:Print(T("Klangprobe: %d Klänge, je 1,5 Sekunden Abstand.", #list))
    for i, e in ipairs(list) do
        local function Step()
            if e.file then
                ONE:Print(string.format("%d/%d  %s  (%s)", i, #list, T(e.label), T("eigener Klang")))
                self:PlayAlert(e.key)
                return
            end
            local _, name = Resolve(e)
            ONE:Print(string.format("%d/%d  %s  (%s)", i, #list, T(e.label), name or "fehlt"))
            self:Play(e.key, true)
        end
        if i == 1 or not (C_Timer and C_Timer.After) then Step() else C_Timer.After((i - 1) * 1.5, Step) end
    end
end
