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
    -- Navi-Ankunft (22.11.2026, statt Muenz-Klingeln): je Ziel-Art ein eigener Klang
    {key = "arriveGiver", label = "Ankunft: Questgeber", file = DIR .. "AnkunftGeber.ogg", channel = "SFX"},
    {key = "arriveTurnin", label = "Ankunft: Abgabe", file = DIR .. "AnkunftAbgabe.ogg", channel = "SFX"},
    {key = "arriveArea", label = "Ankunft: Zielgebiet", file = DIR .. "AnkunftZiel.ogg", channel = "SFX"},
    {key = "arriveService", label = "Ankunft: Flugmeister, Lehrer, Händler", file = DIR .. "AnkunftDienst.ogg", channel = "SFX"},
    -- Eigene Questklaenge statt der WoW-Klaenge (Schalter "core.questSounds", Standard aus)
    {key = "questAccept", label = "Quest angenommen", file = DIR .. "QuestAngenommen.ogg", channel = "SFX"},
    {key = "questObjectives", label = "Quest: alle Ziele erfüllt", file = DIR .. "QuestZiele.ogg", channel = "SFX"},
    {key = "questTurnin", label = "Quest abgegeben", file = DIR .. "QuestAbgegeben.ogg", channel = "SFX"},
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

-- ===== Eigene Questklaenge statt WoW-Klaenge (22.11.2026) =====
-- Forever erlaubt MuteSoundFile (Spieltest /trip klangtest 22.11.2026). Ist der Schalter an, schaltet
-- Guild Trip die WoW-Dateien stumm und spielt eigene Klaenge – nie doppelt. Aus: WoW-Klaenge wieder an.
-- Dateinummern aus der oeffentlichen WoW-Dateiliste (wowdev/wow-listfile).
Sound.questFiles = {
    567400, -- sound/interface/iquestactivate.ogg (Quest angenommen)
    567439, -- sound/interface/iquestcomplete.ogg (Quest abgegeben)
    642843, -- sound/interface/ui_quest_objectivecomplete_01.ogg (alle Ziele erfuellt)
}
local function QuestSoundsOn()
    return ONE.db and type(ONE.db.features) == "table" and ONE.db.features["core.questSounds"] == true or false
end
function Sound:ApplyQuestMute(on)
    local fn = on and MuteSoundFile or UnmuteSoundFile
    if type(fn) ~= "function" then return false end
    for _, id in ipairs(self.questFiles) do pcall(fn, id) end
    return true
end
if ONE.RegisterFeature then ONE:RegisterFeature("core.questSounds", {order = 3, label = "Eigene Questklänge statt WoW-Klänge",
    tooltip = "Quest angenommen, alle Ziele erfüllt und Quest abgegeben klingen nach Guild Trip. Die WoW-Klänge dafür werden stummgeschaltet, damit nichts doppelt klingt. Aus: wieder die WoW-Klänge.",
    get = QuestSoundsOn,
    set = function(on)
        if not ONE.db then return end
        ONE.db.features = type(ONE.db.features) == "table" and ONE.db.features or {}
        ONE.db.features["core.questSounds"] = on and true or false
        Sound:ApplyQuestMute(on and true or false)
    end}) end

-- Welche Quests im Log sind fertig? (questID -> true/false)
local function LogState()
    local QL = C_QuestLog
    local out = {}
    if not (QL and type(QL.GetNumQuestLogEntries) == "function" and type(QL.GetInfo) == "function") then return out end
    local okN, n = pcall(QL.GetNumQuestLogEntries)
    for i = 1, (okN and type(n) == "number") and n or 0 do
        local ok, info = pcall(QL.GetInfo, i)
        if ok and type(info) == "table" and info.questID and not info.isHeader then
            local okC, done = pcall(QL.IsComplete, info.questID)
            out[info.questID] = okC and done == true
        end
    end
    return out
end
-- Neu fertig = vorher im Log und nicht fertig, jetzt fertig
function Sound.NewlyComplete(before, now)
    for id, done in pairs(now) do
        if done and before[id] == false then return true end
    end
    return false
end

if CreateFrame then
    local f = CreateFrame("Frame")
    local state
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            -- Stummschaltung folgt dem Schalter (auch nach /reload oder Ausschalten in einer anderen Sitzung)
            Sound:ApplyQuestMute(QuestSoundsOn())
            state = LogState()
            for _, e in ipairs({"QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE"}) do pcall(f.RegisterEvent, f, e) end
            return
        end
        local on = QuestSoundsOn()
        if event == "QUEST_ACCEPTED" then
            if on then Sound:PlayAlert("questAccept") end
        elseif event == "QUEST_TURNED_IN" then
            if on then Sound:PlayAlert("questTurnin") end
        elseif event == "QUEST_LOG_UPDATE" then
            local now = LogState()
            if on and state and Sound.NewlyComplete(state, now) then Sound:PlayAlert("questObjectives") end
            state = now
        end
    end)
end
