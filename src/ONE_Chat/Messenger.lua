-- Guild Trip Chat im Messenger-Stil (Nutzer 21.11.2026, OK zu Vorschau 2 `docs/vorschau_chat_messenger.html`:
-- "ja perfekt. für unser theme gebaut").
-- Links die Liste aller Gespraeche (Kreis mit Anfangsbuchstabe, letzte Nachricht, Uhrzeit, Zaehler),
-- angeheftete oben, Suche ueber alle Gespraeche. Rechts das Gespraech als Sprechblasen: eigene rechts in der
-- Leuchtfarbe des Glases, andere links mit Namen in Klassenfarbe, Systemzeilen klein in der Mitte,
-- Trennzeilen "Heute", gelbe Linie "neue Nachrichten", Haken beim Fluestern (zugestellt), Emojis.
-- Schmales Fenster (unter 430): wie am Handy – erst Liste, dann Gespraech mit Zurueck-Pfeil.
-- Der alte Stil (ChatUI.lua) bleibt waehlbar (Einstellungen › Stil). Messenger ersetzt dafuer die
-- Fenster-Funktionen von chat.UI (Install), alles andere (Senden, Reiter, Verlauf) bleibt in Chat.lua.
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat, UI = chat.Chat, chat.UI
local M = {bubbles = {}, convRows = {}, newFrom = {}, scroll = 0, listScroll = 0, page = "list"}
chat.Messenger = M

local TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\"
local TITLE_H, LIST_W, HEAD_H, FOOT_H, ROW_H, LABEL_H = 30, 196, 38, 36, 40, 16
local NARROW_W = 430
M.NARROW_W = NARROW_W
local GAP, GROUP_GAP = 2, 6
-- Sprechblasen: Rundung und Zipfel (Nutzer 21.11.2026: "mehr wie Sprechblasen"; Bild aus scripts/build_bubble_tail.py)
local BUBBLE_R = 10
local TAIL_TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\BubbleTail"
local TAIL_RING_TEX = "Interface\\AddOns\\ONE_Chat\\Textures\\BubbleTailRing"

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    return fs
end
local function Me() return type(UnitName) == "function" and Call(UnitName, "player") or nil end
local function Short(n) return Chat.Short(n) end
local function Hex(c) return string.format("|cff%02x%02x%02x", math.floor((c[1] or 1) * 255 + .5), math.floor((c[2] or 1) * 255 + .5), math.floor((c[3] or 1) * 255 + .5)) end
local function ClassRGB(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return .7, .7, .75
end
local function Tip(owner, fn)
    owner:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        for i, l in ipairs(fn() or {}) do
            if i == 1 then GameTooltip:SetText(l[1], l[2] or 1, l[3] or 1, l[4] or 1)
            else GameTooltip:AddLine(l[1], l[2] or .8, l[3] or .8, l[4] or .8, true) end
        end
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- ===== Glas-Kreise mit Bild (Liste, Kopfzeile, Klasse in der Blase; Nutzer 21.11.2026) =====
local ICON = "Interface\\Icons\\"
local CLASS_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
-- je Art mehrere Kandidaten: der erste, den der Client kennt, wird genommen
M.KIND_ICONS = {
    all = {"INV_Misc_Book_09"},
    guild = {"INV_Shirt_GuildTabard_01"},
    officer = {"INV_Shirt_GuildTabard_01"},
    group = {"Spell_Holy_PrayerOfFortitude", "Spell_Holy_WordFortitude"},
    say = {"Ability_Warrior_RallyingCry", "Ability_Warrior_BattleShout"},
    yell = {"Ability_Warrior_BattleShout"},
    emote = {"Spell_Holy_MindVision", "INV_Misc_Note_01"},
    trade = {"INV_Misc_Coin_01", "INV_Misc_Coin_02"},
    general = {"INV_Misc_Map_01"},
    lfg = {"INV_Misc_Spyglass_02"},
    channel = {"INV_Misc_Note_01"},
    system = {"INV_Misc_Gear_01", "Trade_Engineering"},
    npc = {"INV_Misc_Head_Human_01", "Spell_Holy_PrayerOfSpirit", "INV_Misc_Note_01"},
    progress = {"INV_Misc_Bag_10", "INV_Misc_Coin_01"},
    -- Battle.net-Freund (Fluestern aus dem Launcher)
    bnet = {"INV_Misc_Note_02", "INV_Letter_15", "INV_Misc_Note_01"},
}
-- helle Symbole etwas abdunkeln (Spieltest 21.11.2026: Gilde/Gruppe "zu grell")
M.ICON_DIM = {guild = .66, officer = .66, group = .70}
M.iconDim = {}
-- schwarzer Grund hinter dem Symbol, Symbol etwas kleiner (Spieltest 21.11.2026: Gruppe)
M.ICON_BLACK = {group = true}
M.iconBlack = {}
local iconCache = {}
function M.KindIcon(key)
    if not key then return nil end
    if iconCache[key] ~= nil then return iconCache[key] or nil end
    local found = false
    for _, name in ipairs(M.KIND_ICONS[key] or {}) do
        local path = ICON .. name
        local known = type(GetFileIDFromPath) ~= "function" or Call(GetFileIDFromPath, path)
        if known then found = path break end
    end
    iconCache[key] = found
    if found then M.iconDim[found] = M.ICON_DIM[key] M.iconBlack[found] = M.ICON_BLACK[key] end
    return found or nil
end
function M.ClassCoords(classFile)
    local c = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if c then return c[1], c[2], c[3], c[4] end
end
function M.ClassOfGuid(guid, name)
    if guid and guid ~= "" and type(GetPlayerInfoByGUID) == "function" then
        local _, classFile = Call(GetPlayerInfoByGUID, guid)
        if classFile then return classFile end
    end
    -- ohne GUID (aelterer Verlauf) oder WoW kennt sie gerade nicht: Gildenliste nach Namen
    if name and name ~= "" and M.RosterInfo then
        -- kurz merken: die Gildenliste nicht fuer jede Blase neu durchsuchen
        local now = (type(GetTime) == "function" and GetTime()) or 0
        M.classCache = M.classCache or {}
        local c = M.classCache[name]
        if c and now - c.t < 30 then return c.cls or nil end
        local info = M.RosterInfo(name)
        local cls = info and info.classFile or false
        M.classCache[name] = {t = now, cls = cls}
        return cls or nil
    end
    return nil
end
-- legt um eine runde Textur (av) Bild, Ring und Glanz an
function M.GlassAvatar(parent, av, inset)
    local G = ONE.Glass
    local a = {av = av, parent = parent}
    a.icon = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    a.inset = inset or 2
    a.icon:SetPoint("TOPLEFT", av, "TOPLEFT", a.inset, -a.inset)
    a.icon:SetPoint("BOTTOMRIGHT", av, "BOTTOMRIGHT", -a.inset, a.inset)
    a.icon:Hide()
    if parent.CreateMaskTexture and a.icon.AddMaskTexture and G then
        local ok, m = pcall(parent.CreateMaskTexture, parent)
        if ok and m then
            m:SetTexture(G.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(a.icon)
            pcall(a.icon.AddMaskTexture, a.icon, m)
        end
    end
    a.shine = parent:CreateTexture(nil, "OVERLAY", nil, 1)
    a.shine:SetAllPoints(av)
    if G then a.shine:SetTexture(G.tex.orb) end
    a.ring = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    a.ring:SetAllPoints(av)
    if G then a.ring:SetTexture(G.tex.ring) end
    return a
end
-- icon = Pfad (+ Ausschnitt) oder nil (dann Buchstabe im farbigen Glas)
function M.PaintAvatar(a, p, cr, cg, cb, icon, coords, letter, letterText)
    if not a then return end
    local t = p.tint
    if icon then
        a.icon:SetTexture(icon)
        if coords then a.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else a.icon:SetTexCoord(.08, .92, .08, .92) end
        local d = M.iconDim[icon] or 1
        a.icon:SetVertexColor(d, d, d, .92)
        a.icon:Show()
        local black = M.iconBlack[icon]
        local ins = black and a.inset + 2 or a.inset
        a.icon:ClearAllPoints()
        a.icon:SetPoint("TOPLEFT", a.av, "TOPLEFT", ins, -ins)
        a.icon:SetPoint("BOTTOMRIGHT", a.av, "BOTTOMRIGHT", -ins, ins)
        if black then a.av:SetVertexColor(0, 0, 0, .95)
        else a.av:SetVertexColor(t[1] + (cr - t[1]) * .25, t[2] + (cg - t[2]) * .25, t[3] + (cb - t[3]) * .25, .55) end
        if letter then letter:Hide() end
    else
        a.icon:Hide()
        a.av:SetVertexColor(cr * .55, cg * .55, cb * .55, .55)
        if letter then
            letter:SetText("|cffffffff" .. (letterText or "") .. "|r")
            letter:Show()
        end
    end
    a.av:Show()
    a.ring:SetVertexColor(cr, cg, cb, .65)
    a.ring:Show()
    a.shine:SetVertexColor(1, 1, 1, .30)
    a.shine:Show()
end
function M.HideAvatar(a)
    if not a then return end
    a.av:Hide() a.icon:Hide() a.ring:Hide() a.shine:Hide()
end

-- ===== Farben (Glas des Chats) =====
function M:Palette()
    local G = ONE.Glass
    if G and G.Palette then return G:Palette(Chat:GlassStore()) end
    return {tint = {.04, .05, .07}, glow = {1, .82, 0}, title = {1, .82, 0}, alpha = .8, onGlow = {.07, .06, .03}}
end
-- Farbe {r, g, b} aus den Einstellungen pruefen (sonst nil)
function M.ValidColor(c)
    if type(c) ~= "table" then return nil end
    for i = 1, 3 do if type(c[i]) ~= "number" or c[i] < 0 or c[i] > 1 then return nil end end
    return c
end
-- Staerke der Blasenfarbe: 1 = normal (Spieltest 21.11.), kleiner dezenter, groesser kraeftiger
M.STRENGTHS = {.5, 1, 1.8, 2.6}
function M.BubbleStrength()
    local v = Chat:Settings().bubbleStrength
    for _, x in ipairs(M.STRENGTHS) do if v == x then return v end end
    return 1
end
-- Blasen: eigene in der Leuchtfarbe (gedaempft), andere hell auf dem Glas
-- Sprechblase aus Glas (Nutzer 21.11.2026): durchscheinende Flaeche, heller Rand, Glanz oben.
-- Andere leicht in der Farbe ihrer Art (Gilde gruen, Gruppe blau …), eigene in der Leuchtfarbe.
-- Liefert Flaeche (r, g, b, a) und Rand (r, g, b, a).
function M.BubbleColor(p, out, failed, kind)
    -- Spieltest 21.11.2026: "viel zu hell, durchscheinender, nur ein leichter Akzent", dann "noch etwas weniger"
    if failed then return .55, .14, .14, .45, 1, .45, .45, .32 end
    -- Einstellungen (22.11.2026): eigene Blasenfarbe statt Leuchtfarbe, Staerke der Farbe
    local s = Chat:Settings()
    local f = M.BubbleStrength()
    local t, g = p.tint, M.ValidColor(s.ownBubble) or p.glow
    if out then
        local k = math.min(.8, .20 * f)
        return t[1] + (g[1] - t[1]) * k, t[2] + (g[2] - t[2]) * k, t[3] + (g[3] - t[3]) * k, math.min(.85, .40 + (f - 1) * .1),
            g[1], g[2], g[3], math.min(.8, .22 * f)
    end
    local r, gg, b = t[1] + (1 - t[1]) * .09, t[2] + (1 - t[2]) * .09, t[3] + (1 - t[3]) * .09
    local c = kind and s.bubbleColors ~= false and Chat.kindByKey[kind] and Chat.kindByKey[kind].color
    if type(c) == "table" and c[1] then
        local k = math.min(.6, .035 * f * f)
        r, gg, b = r + (c[1] - r) * k, gg + (c[2] - gg) * k, b + (c[3] - b) * k
        return r, gg, b, .34, c[1], c[2], c[3], math.min(.7, .12 * f)
    end
    return r, gg, b, .34, 1, 1, 1, .09
end

-- ===== Gespraeche =====
-- Alle Ansichten: Reiter + Fluestergespraeche, je {view, title, whisper, tab, last, unread, muted, pinned}
function M.ViewTitle(view)
    if type(view) == "string" and view:sub(1, 2) == "w:" then return view:sub(3) end
    local tab = Chat:Tab(view)
    return tab and T(tab.label) or "?"
end
function M.LastEntry(view)
    local buf = Chat.buffers[view]
    return buf and buf[#buf] or nil
end
function M.IsPinned(view)
    for i, v in ipairs(Chat:Settings().pinned) do if v == view then return i end end
end
function M.SetPinned(view, on)
    local list = Chat:Settings().pinned
    for i = #list, 1, -1 do if list[i] == view then table.remove(list, i) end end
    if on then list[#list + 1] = view end
end
function M.IsMuted(view) return Chat:Settings().muted[view] == true end
function M.SetMuted(view, on) Chat:Settings().muted[view] = on and true or nil end

-- unten im Bereich "System": ruhige Gespraeche ohne eigene Unterhaltung
M.SYSTEM_VIEWS = {system = true, progress = true}
function M.Conversations()
    local out = {}
    for _, t in ipairs(Chat:Tabs()) do
        local last = M.LastEntry(t.id)
        out[#out + 1] = {view = t.id, title = T(t.label), tab = t, last = last and last.time or 0}
    end
    for _, w in ipairs(Chat.whispers) do
        local view = Chat.WhisperView(w.name)
        local last = M.LastEntry(view)
        out[#out + 1] = {view = view, title = w.name, whisper = w.name, last = math.max(last and last.time or 0, w.last or 0)}
    end
    for i, c in ipairs(out) do
        c.order = i
        c.unread = Chat.unread[c.view] or 0
        c.muted = M.IsMuted(c.view)
        c.pinned = M.IsPinned(c.view)
    end
    -- angeheftete in ihrer Reihenfolge, dann nach letzter Nachricht (neueste oben).
    -- Nutzer 22.11.2026 ("permanenter Wechsel zwischen Beute und Alle"): "Alle" steht fest oben,
    -- stumme Gespraeche rutschen nicht hoch (feste Reihenfolge unter den anderen).
    table.sort(out, function(a, b)
        if a.pinned or b.pinned then
            if a.pinned and b.pinned then return a.pinned < b.pinned end
            return a.pinned ~= nil
        end
        local aAll, bAll = a.view == "all", b.view == "all"
        if aAll ~= bAll then return aAll end
        if (a.muted and true or false) ~= (b.muted and true or false) then return not a.muted end
        if a.muted then return a.order < b.order end
        if a.last ~= b.last then return a.last > b.last end
        return a.order < b.order
    end)
    return out
end

-- Farbe des Kreises: Fluestern = Klassenfarbe, sonst Farbe der Art
function M.AvatarColor(c)
    if c.whisper then
        local info = M.PersonInfo(c.whisper)
        if info and info.classFile then return ClassRGB(info.classFile) end
        local last = M.LastEntry(c.view)
        if last and last.guid and type(GetPlayerInfoByGUID) == "function" then
            local _, classFile = Call(GetPlayerInfoByGUID, last.guid)
            if classFile then return ClassRGB(classFile) end
        end
        if Chat.IsBN(c.whisper) then return .30, .70, 1 end -- Battle.net-Blau
        return .75, .55, .85
    end
    local tab = c.tab
    local key = tab and (Chat.kindByKey[tab.id] and tab.id or tab.send)
    if tab and tab.id == "system" then return 1, 1, .45 end
    if tab and tab.id == "all" then return .7, .7, .75 end
    if key == "say" then key = "emote" end
    local kind = key and Chat.kindByKey[key]
    local col = kind and kind.color or {.65, .65, .7}
    return col[1], col[2], col[3]
end

-- Bild im Kreis: Fluestern = Klassen-Symbol, sonst Symbol der Art (nil = Buchstabe)
function M.AvatarIcon(c)
    if c.whisper then
        local info = M.PersonInfo(c.whisper)
        local classFile = info and info.classFile
        if not classFile then
            local last = M.LastEntry(c.view)
            classFile = last and M.ClassOfGuid(last.guid, last.author)
        end
        local l, r, t, b = M.ClassCoords(classFile)
        if l then return CLASS_ATLAS, {l, r, t, b} end
        if Chat.IsBN(c.whisper) then return M.KindIcon("bnet") end
        return nil
    end
    local tab = c.tab
    if tab and (tab.id == "all" or tab.id == "system") then return M.KindIcon(tab.id) end
    local key = tab and (Chat.kindByKey[tab.id] and tab.id or tab.send)
    return M.KindIcon(key)
end

-- Battle.net-Freund: "Battle.net · Charakter · Ort" bzw. "Battle.net · offline"
function M.BNLine(info)
    if not info.online then return "Battle.net · " .. T("offline") end
    local parts = {"Battle.net"}
    if info.character and info.character ~= "" then parts[#parts + 1] = info.character end
    if info.zone and info.zone ~= "" then parts[#parts + 1] = info.zone end
    return table.concat(parts, " · ")
end
-- Hat diese Person gerade (in den letzten 3 Minuten) geschrieben? Dann ist sie online, auch wenn die
-- Gildenliste von WoW noch alt ist (Spieltest 22.11.2026: "gerade offline" direkt nach ihrer Nachricht)
M.HEARD_SECONDS = 180
function M.RecentlyHeard(name)
    local buf = Chat.buffers and Chat.buffers[Chat.WhisperView(name)]
    if type(buf) ~= "table" then return false end
    local now = (type(time) == "function" and time()) or 0
    for i = #buf, math.max(1, #buf - 10), -1 do
        local e = buf[i]
        if e and not e.inform and not e.failed and e.kind == "whisper" and Short(e.author or "") == Short(name) then
            return (now - (e.time or 0)) <= M.HEARD_SECONDS
        end
    end
    return false
end
-- Gildenliste bei WoW neu anfordern (WoW liefert sonst einen alten Stand; hoechstens alle 15 s)
function M.RequestRoster()
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if M.rosterAsked and now - M.rosterAsked < 15 then return false end
    M.rosterAsked = now
    if type(IsInGuild) == "function" and not Call(IsInGuild) then return false end
    if type(C_GuildInfo) == "table" and type(C_GuildInfo.GuildRoster) == "function" then pcall(C_GuildInfo.GuildRoster)
    elseif type(GuildRoster) == "function" then pcall(GuildRoster) end
    return true
end
-- Gilde/Freunde: Klasse, Stufe, Ort, online, zuletzt online
function M.PersonInfo(name)
    local info = M.RosterInfo(name)
    if info and not info.bn and not info.online and M.RecentlyHeard(name) then
        info.online, info.lastOnline = true, nil
    end
    return info
end
function M.RosterInfo(name)
    local short = Short(name)
    if Chat.IsBN(short) then
        local b = Chat.BNInfo(Chat.BNFind(short))
        if not b then return nil end
        return {bn = true, online = b.online, zone = b.zone, character = b.character, level = b.level}
    end
    if type(GetNumGuildMembers) == "function" and type(GetGuildRosterInfo) == "function" then
        for i = 1, (Call(GetNumGuildMembers) or 0) do
            -- direkt pcall: Call liefert nur 4 Werte, online ist der 9. (Punkt fehlte, Spieltest 22.11.2026)
            local ok, full, _, _, level, class, zone, _, _, online, _, classFile = pcall(GetGuildRosterInfo, i)
            if ok and full and Short(full) == short then
                local info = {level = level, class = class, zone = zone, online = online and true or false, classFile = classFile, inGuild = true}
                if not info.online and type(GetGuildRosterLastOnline) == "function" then
                    local y, mo, d, h = Call(GetGuildRosterLastOnline, i)
                    info.lastOnline = {y or 0, mo or 0, d or 0, h or 0}
                end
                return info
            end
        end
    end
    if C_FriendList and type(C_FriendList.GetFriendInfo) == "function" then
        local f = Call(C_FriendList.GetFriendInfo, short)
        if type(f) == "table" then
            return {level = f.level, class = f.className, zone = f.area, online = f.connected and true or false}
        end
    end
end
function M.OfflineText(info)
    local lo = info and info.lastOnline
    if not lo then return T("offline") end
    if lo[1] > 0 then return T("offline seit %d Jahren", lo[1]) end
    if lo[2] > 0 then return lo[2] == 1 and T("offline seit 1 Monat") or T("offline seit %d Monaten", lo[2]) end
    if lo[3] > 0 then return lo[3] == 1 and T("offline seit 1 Tag") or T("offline seit %d Tagen", lo[3]) end
    if lo[4] > 0 then return lo[4] == 1 and T("offline seit 1 Std.") or T("offline seit %d Std.", lo[4]) end
    return T("gerade offline")
end

-- Zeit in der Liste: heute Uhrzeit, sonst "Gestern" bzw. Datum
function M.ListTime(t)
    if not t or t == 0 or type(date) ~= "function" then return "" end
    local now = (type(time) == "function" and time()) or t
    if date("%Y%m%d", t) == date("%Y%m%d", now) then return date("%H:%M", t) end
    if date("%Y%m%d", t) == date("%Y%m%d", now - 86400) then return T("Gestern") end
    return date("%d.%m.", t)
end
function M.DayLabel(t)
    if type(date) ~= "function" then return "" end
    local now = (type(time) == "function" and time()) or t
    if date("%Y%m%d", t) == date("%Y%m%d", now) then return T("Heute") end
    if date("%Y%m%d", t) == date("%Y%m%d", now - 86400) then return T("Gestern") end
    return date("%d.%m.%Y", t)
end

-- Text fuer die Anzeige: Emojis/WoW-Zeichen als Bilder, eigener Name gold
function M.Show(text, size)
    local s = Chat:Settings()
    text = tostring(text or "")
    local me = Me()
    if me and me ~= "" and text:find(me, 1, true) then
        text = text:gsub(me:gsub("%p", "%%%0"), "|cffffd100" .. me .. "|r")
    end
    if s.emojiImages ~= false and chat.Emoji then text = chat.Emoji.Render(text, size, {noAscii = s.asciiSmileys == false}) end
    return text
end
-- Vorschau in der Liste: eine Zeile ohne Links
function M.Preview(entry)
    if not entry then return "" end
    local text = tostring(entry.text or ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local who = ""
    if entry.kind ~= "system" then
        if entry.inform or Short(entry.author) == Me() then who = T("Du") .. ": "
        elseif entry.author and entry.author ~= "" then who = Short(entry.author) .. ": " end
    end
    return M.Show(who .. text, 12)
end

-- ===== Verlauf eines Gespraechs als Eintraege fuer die Blasen =====
-- {type = "day"/"new"/"sys"/"bubble", entry, out, cont, name}
function M.Items(view, newFrom)
    local items = {}
    local buf = Chat:Buffer(view)
    local whisper = type(view) == "string" and view:sub(1, 2) == "w:"
    local me = Me()
    local lastDay, prev
    for i, e in ipairs(buf) do
        local day = type(date) == "function" and date("%Y%m%d", e.time or 0) or ""
        if day ~= lastDay then
            items[#items + 1] = {type = "day", text = M.DayLabel(e.time or 0)}
            lastDay, prev = day, nil
        end
        if newFrom and i == newFrom then
            items[#items + 1] = {type = "new", count = #buf - i + 1}
            prev = nil
        end
        if Chat.IsPlain(e) then
            items[#items + 1] = {type = "sys", entry = e}
            prev = nil
        elseif e.kind == "emote" then
            items[#items + 1] = {type = "sys", entry = e, emote = true}
            prev = nil
        else
            local out = e.inform or (me and Short(e.author) == me) or false
            local cont = prev and prev.out == out and Short(prev.entry.author) == Short(e.author)
                and (e.time or 0) - (prev.entry.time or 0) < 300 or false
            local it = {type = "bubble", entry = e, out = out, cont = cont,
                name = not out and not whisper and not cont}
            -- im Reiter "Alle": Art vor den Namen
            if view == "all" and not out and not cont then it.kind = e.kind end
            items[#items + 1] = it
            prev = it
        end
    end
    return items
end

-- ===== Aufbau =====
function M:Install()
    UI.style = "messenger"
    UI.flat, UI.glass, UI.modern = false, true, false
    UI.Build = function() return M:Build() end
    UI.Show = function(_, view) return M:ShowView(view) end
    UI.Hide = function() return M:Hide() end
    UI.Toggle = function() if M.frame and M.frame:IsShown() then M:Hide() else M:ShowView() end end
    UI.Refresh = function() return M:Refresh() end
    UI.Render = function() return M:Render() end
    UI.OnMessage = function(_, entry, views, update) return M:OnMessage(entry, views, update) end
    UI.ApplyLook = function() return M:ApplyLook() end
    UI.SetFontSize = function(_, size) Chat:Settings().fontSize = size M:Render() end
    UI.LayoutRows = function() return M:Refresh() end
    UI.RefreshHead = function() return M:RefreshHead() end
    UI.AskWhisper = function() return M:AskWhisper() end
    UI.WakeUp = function() if M.frame then M.frame.__fadeWait = 0 end end
end

function M:Build()
    if self.frame then return self.frame end
    local G = ONE.Glass
    local before = G and G.surfaces and #G.surfaces or 0
    if G then G.forceLook = "glass" end
    local ok, err = pcall(self.BuildFrame, self)
    if G then G.forceLook = nil end
    -- Glas-Teile des Chats: eigene Farben, Deckkraft ueber "Hintergrund" (wie ChatUI)
    self.surfaces = {}
    if G and G.surfaces then
        for i = before + 1, #G.surfaces do
            local sf = G.surfaces[i]
            sf.store = function() return Chat:GlassStore() end
            if sf.kind == "window" then sf.scale = function() return tonumber(Chat:Settings().opacity) or 1 end end
            self.surfaces[#self.surfaces + 1] = sf
            if G.Paint then G:Paint(sf) end
        end
        if not self.glassHooked and G.OnChange then
            self.glassHooked = true
            G:OnChange(function() M:Paint() M:Refresh() M:Render() end)
        end
    end
    if not ok then error(err, 0) end
    UI.frame = self.frame
    if UI.HookInsertLink then UI:HookInsertLink() end
    self:Paint()
    return self.frame
end

function M:BuildFrame()
    local s = Chat:Settings()
    local f = CreateFrame("Frame", "GuildTripChatWindow", UIParent)
    self.frame = f
    f:SetSize(s.width or 640, s.height or 420)
    if s.point then f:SetPoint(s.point[1], UIParent, s.point[2], s.point[3], s.point[4]) else f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 160) end
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(UI.MIN_W or 280, 240, 1200, 900) end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(fr) if not Chat:Settings().locked then fr:StartMoving() end end)
    f:SetScript("OnDragStop", function(fr) fr:StopMovingOrSizing() UI:SaveGeometry() end)
    if ONE.Glass and ONE.Glass.Surface then
        ONE.Glass:Surface(f, "window")
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f)
        bg:SetColorTexture(.04, .05, .07, .9)
    end
    if ONE.Widgets and ONE.Widgets.ResizeHandles then
        self.resize = ONE.Widgets:ResizeHandles(f, {size = 6, onStop = function() UI:SaveGeometry() M:Refresh() M:Render() end})
    end

    -- Titelleiste: Name, Beute, Zahnrad (Einstellungen im Chat), Schliessen
    local title = Text(f, "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -9)
    title:SetText(T("Guild Trip Chat"))
    self.title = title
    ONE.Widgets:CloseButton(f, "TOPRIGHT", -4, -2, function() M:Hide() end)
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(18, 18)
    gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, -6)
    local gt = gear:CreateTexture(nil, "ARTWORK")
    gt:SetAllPoints(gear)
    gt:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function() UI:OpenSettings() end)
    Tip(gear, function() return {{T("Chat-Einstellungen")}} end)
    self.gear = gear
    local loot = CreateFrame("Button", nil, f)
    loot:SetSize(18, 18)
    loot:SetPoint("RIGHT", gear, "LEFT", -6, 0)
    local lt = loot:CreateTexture(nil, "ARTWORK")
    lt:SetAllPoints(loot)
    lt:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    loot:SetScript("OnClick", function() if chat.Loot then chat.Loot:Toggle() end end)
    Tip(loot, function() return {{T("Beute-Fenster")}, {T("Wer hat welchen Gegenstand bekommen")}} end)
    self.lootButton = loot
    -- Sprung zum WoW-Chat (Nutzer 22.11.2026), abschaltbar im Zahnrad
    if chat.Hider then
        local jump = chat.Hider:JumpButton(f)
        jump:SetPoint("RIGHT", loot, "LEFT", -6, 0)
        jump:SetShown(chat.Hider.JumpShown())
        self.jumpButton = jump
    end

    self:BuildList(f)
    self:BuildMain(f)
    -- Erst jetzt: WoW meldet Groessen-Aenderungen schon waehrend des Aufbaus (Spieltest 21.11.2026,
    -- Fehler "main nil" in Layout beim Anlegen eines Knopfs)
    f:SetScript("OnSizeChanged", function() M:Layout() end)
    self:ApplyLook()
    f:Hide()
    UI.current = UI.current or "guild"
    return f
end

-- ===== Liste links =====
function M:BuildList(f)
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -TITLE_H)
    list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
    list:SetWidth(LIST_W)
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(list, "column") end
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        M.listScroll = math.max(0, (M.listScroll or 0) - delta * 2)
        M:LayoutList()
    end)
    self.list = list
    -- Suche + "+" (neues Gespraech)
    local ok, search = pcall(CreateFrame, "EditBox", nil, list, "InputBoxTemplate")
    if not ok or not search then search = CreateFrame("EditBox", nil, list) end
    for _, key in ipairs({"Left", "Right", "Middle"}) do
        local t = rawget(search, key)
        if type(t) == "table" and t.Hide then t:Hide() end
    end
    search:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -6)
    search:SetPoint("TOPRIGHT", list, "TOPRIGHT", -56, -6)
    search:SetHeight(20)
    search:SetAutoFocus(false)
    if search.SetTextInsets then search:SetTextInsets(8, 8, 0, 0) end
    if search.SetFontObject and GameFontHighlightSmall then search:SetFontObject(GameFontHighlightSmall) end
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(search, "card") end
    local ph = Text(list, "GameFontDisableSmall")
    ph:SetPoint("LEFT", search, "LEFT", 9, 0)
    ph:SetText(T("Suchen …"))
    local function Changed()
        local txt = search:GetText() or ""
        ph:SetShown(txt == "" and not (search.HasFocus and search:HasFocus()))
        M.search = txt:match("^%s*(.-)%s*$")
        M.listScroll = 0
        M:LayoutList()
    end
    search:SetScript("OnTextChanged", Changed)
    search:SetScript("OnEditFocusGained", Changed)
    search:SetScript("OnEditFocusLost", Changed)
    search:SetScript("OnEscapePressed", function(b) b:SetText("") b:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(b) b:ClearFocus() end)
    self.searchBox, self.searchPh = search, ph
    local add = CreateFrame("Button", nil, list)
    add:SetSize(22, 22)
    add:SetPoint("LEFT", search, "RIGHT", 4, 0)
    local at = Text(add, "GameFontNormalLarge")
    at:SetPoint("CENTER", add, "CENTER", 0, 1)
    at:SetText("+")
    self.addText = at
    local hl = add:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(add)
    hl:SetColorTexture(1, 1, 1, .08)
    add:SetScript("OnClick", function(btn) M:NewMenu(btn) end)
    Tip(add, function() return {{T("Neues Gespräch")}, {T("Flüstern an jemanden oder eigenen Reiter anlegen")}} end)
    self.addButton = add
    -- Freunde neben dem + (Nutzer 23.11.2026: "Knopf wie im WoW-Chat, der die Battle.net-Freunde zeigt"):
    -- eigenes Menue, Klick oeffnet das Gespraech hier; Zahl = Freunde online
    local friends = CreateFrame("Button", nil, list)
    friends:SetSize(18, 18)
    friends:SetPoint("LEFT", add, "RIGHT", 3, 0)
    local ft = friends:CreateTexture(nil, "ARTWORK")
    ft:SetAllPoints(friends)
    ft:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    friends.count = Text(friends, "GameFontHighlightSmall")
    friends.count:SetPoint("BOTTOMRIGHT", friends, "BOTTOMRIGHT", 4, -3)
    if ONE.Fit then ONE.Fit:Line(friends.count, false) end
    -- offene Freundschaftsanfragen: rote Zahl oben rechts
    friends.req = Text(friends, "GameFontHighlightSmall")
    friends.req:SetPoint("TOPRIGHT", friends, "TOPRIGHT", 5, 4)
    if ONE.Fit then ONE.Fit:Line(friends.req, false) end
    friends.icon = ft
    friends:SetScript("OnClick", function() M:ToggleFriends() end)
    Tip(friends, function()
        local on = M.FriendsOnline()
        return {{T("Freunde")}, {T("%d online – Klick: Freunde statt Gespräche zeigen, Klick auf einen Namen öffnet das Gespräch hier.", on)}}
    end)
    self.friendsButton = friends
end

function M:NewMenu(owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateButton(T("Flüstern an …"), function() M:AskWhisper() end)
            root:CreateButton(T("Neuer Reiter …"), function() if UI.EditTab then UI:EditTab() end end)
        end)
    else
        M:AskWhisper()
    end
end

local function NewConvRow(list)
    local b = CreateFrame("Button", nil, list)
    b:SetHeight(ROW_H)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:Hide()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(1, 1, 1, .06)
    local G = ONE.Glass
    b.av = b:CreateTexture(nil, "ARTWORK")
    b.av:SetSize(24, 24)
    b.av:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.av:SetTexture(G and G.tex.circle or (TEX .. "Dot"))
    b.letter = Text(b, "GameFontNormalSmall")
    b.letter:SetPoint("CENTER", b.av, "CENTER", 0, 0)
    b.letter:SetJustifyH("CENTER")
    b.glass = M.GlassAvatar(b, b.av, 2)
    -- online: gruener Punkt mit dunklem Rand unten rechts am Kreis (wie im Messenger), ueber Ring und Glanz
    b.onlineRim = b:CreateTexture(nil, "OVERLAY", nil, 5)
    b.onlineRim:SetSize(11, 11)
    b.onlineRim:SetPoint("BOTTOMRIGHT", b.av, "BOTTOMRIGHT", 2, -2)
    b.onlineRim:SetTexture(G and G.tex.circle or (TEX .. "Dot"))
    b.onlineRim:SetVertexColor(.05, .06, .07, 1)
    b.online = b:CreateTexture(nil, "OVERLAY", nil, 6)
    b.online:SetSize(7, 7)
    b.online:SetPoint("CENTER", b.onlineRim, "CENTER", 0, 0)
    b.online:SetTexture(G and G.tex.circle or (TEX .. "Dot"))
    b.online:SetVertexColor(.30, .90, .35)
    b.name = Text(b, "GameFontHighlight")
    b.name:SetPoint("TOPLEFT", b.av, "TOPRIGHT", 8, 1)
    b.name:SetPoint("RIGHT", b, "RIGHT", -44, 0)
    if ONE.Fit then ONE.Fit:Line(b.name, b) end
    b.time = Text(b, "GameFontDisableSmall")
    b.time:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -6)
    b.time:SetJustifyH("RIGHT")
    b.preview = Text(b, "GameFontDisableSmall")
    b.preview:SetPoint("BOTTOMLEFT", b.av, "BOTTOMRIGHT", 8, 0)
    b.preview:SetPoint("RIGHT", b, "RIGHT", -30, 0)
    if ONE.Fit then ONE.Fit:Line(b.preview, b) end
    b.badge = b:CreateTexture(nil, "OVERLAY")
    b.badge:SetSize(18, 16)
    b.badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -7, 5)
    b.badge:SetTexture(TEX .. "Pill")
    b.count = Text(b, "GameFontHighlightSmall")
    b.count:SetPoint("CENTER", b.badge, "CENTER", 0, 0)
    b.count:SetJustifyH("CENTER")
    b.label = Text(b, "GameFontDisableSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 10, 0)
    return b
end

M.NewConvRow = NewConvRow

-- Liste fuellen: normal (angeheftet / Gespraeche) oder Suchergebnisse
function M:ListRows()
    local rows = {}
    local q = (self.search or ""):lower()
    if self.friendsMode then return self:FriendRows(q) end
    if q ~= "" then
        local hits, seen = {}, {}
        -- "Alle" zuletzt: ein Treffer gehoert zum eigentlichen Gespraech (Fluestern, Gilde …)
        local convs = M.Conversations()
        table.sort(convs, function(a, b)
            if (a.view == "all") ~= (b.view == "all") then return b.view == "all" end
            return a.order < b.order
        end)
        for _, c in ipairs(convs) do
            if c.title:lower():find(q, 1, true) then rows[#rows + 1] = {conv = c} end
            for i = #Chat:Buffer(c.view), 1, -1 do
                local e = Chat:Buffer(c.view)[i]
                if not seen[e] then
                    local plain = tostring(e.text or ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
                    if plain:find(q, 1, true) or Short(e.author or ""):lower():find(q, 1, true) then
                        seen[e] = true
                        hits[#hits + 1] = {conv = c, hit = e}
                    end
                end
            end
        end
        table.sort(hits, function(a, b) return (a.hit.time or 0) > (b.hit.time or 0) end)
        if #hits > 0 then rows[#rows + 1] = {label = T("NACHRICHTEN")} end
        for i = 1, math.min(40, #hits) do rows[#rows + 1] = hits[i] end
        if #rows == 0 then rows[#rows + 1] = {label = T("Nichts gefunden")} end
        return rows
    end
    -- Bereiche (Spieltest 21.11.2026): Angeheftet, Gespraeche, Fluestern eigens, System & Addons ganz unten
    local groups = {{label = T("ANGEHEFTET")}, {label = T("GESPRÄCHE")}, {label = T("FLÜSTERN")}, {label = T("SYSTEM")}}
    for _, c in ipairs(M.Conversations()) do
        local g = c.pinned and 1 or (c.whisper and 3) or (M.SYSTEM_VIEWS[c.view] and 4) or 2
        groups[g][#groups[g] + 1] = c
    end
    for _, g in ipairs(groups) do
        if #g > 0 then
            rows[#rows + 1] = {label = g.label, gap = #rows > 0}
            for _, c in ipairs(g) do rows[#rows + 1] = {conv = c} end
        end
    end
    return rows
end

function M:LayoutList()
    local list = self.list
    if not (list and self.frame and self.frame:IsShown()) then return end
    local p = self:Palette()
    local g = p.glow
    if self.addText then self.addText:SetTextColor(g[1], g[2], g[3]) end
    local rows = self:ListRows()
    local h = list:GetHeight() or 300
    local maxScroll = math.max(0, #rows - 3)
    self.listScroll = math.min(self.listScroll or 0, maxScroll)
    local y = 32
    local n = 0
    for i = 1 + self.listScroll, #rows do
        if y > h then break end
        local r = rows[i]
        n = n + 1
        local b = self.convRows[n] or NewConvRow(list)
        self.convRows[n] = b
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        b:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
        if r.label then
            if r.gap then y = y + GROUP_GAP end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
            b:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
            b:SetHeight(LABEL_H)
            for _, part in ipairs({b.av, b.letter, b.online, b.onlineRim, b.name, b.time, b.preview, b.badge, b.count, b.sel}) do part:Hide() end
            M.HideAvatar(b.glass)
            b.label:SetText(r.click and (Hex(g) .. r.label .. "|r") or r.label)
            b.label:Show()
            b:SetAlpha(1)
            -- anklickbare Zeile (Freunde: "Zurueck zu den Gespraechen", WoW-Freundesliste)
            b:SetScript("OnClick", r.click and function() r.click() end or nil)
            b:SetScript("OnEnter", nil)
            b:EnableMouse(r.click and true or false)
            if r.click then b:SetHeight(LABEL_H + 6) y = y + 6 end
            y = y + LABEL_H
        else
            b:EnableMouse(true)
            b:SetHeight(ROW_H)
            b.label:Hide()
            if r.friend then self:FillFriendRow(b, r.friend, p)
            elseif r.request then self:FillRequestRow(b, r.request, p)
            else b:SetAlpha(1) self:FillConvRow(b, r, p) end
            y = y + ROW_H
        end
        b:Show()
    end
    for i = n + 1, #self.convRows do self.convRows[i]:Hide() end
end

function M:FillConvRow(b, r, p)
    local c = r.conv
    local g = p.glow
    local cr, cg, cb = M.AvatarColor(c)
    local icon, coords = M.AvatarIcon(c)
    M.PaintAvatar(b.glass, p, cr, cg, cb, icon, coords, b.letter, UI.First and UI.First(c.title) or c.title:sub(1, 1))
    local info = c.whisper and M.PersonInfo(c.whisper)
    b.online:SetShown(info and info.online or false)
    b.onlineRim:SetShown(info and info.online or false)
    b.name:SetText(c.title)
    b.name:Show()
    local selected = c.view == UI.current and not r.hit
    b.sel:SetColorTexture(g[1], g[2], g[3], .14)
    b.sel:SetShown(selected)
    local entry = r.hit or M.LastEntry(c.view)
    b.time:SetText(M.ListTime(r.hit and r.hit.time or c.last))
    b.time:Show()
    local draft = not r.hit and Chat.drafts and Chat.drafts[c.view]
    if draft and draft ~= "" and c.view ~= UI.current then
        b.preview:SetText("|cffe06060" .. T("Entwurf:") .. "|r " .. M.Show(draft, 12))
    elseif c.muted and not entry then
        b.preview:SetText(T("stumm"))
    else
        b.preview:SetText(M.Preview(entry))
    end
    b.preview:Show()
    local unread = r.hit and 0 or c.unread
    if unread > 0 then
        b.badge:Show()
        b.count:Show()
        if c.muted then b.badge:SetVertexColor(.38, .38, .4) else b.badge:SetVertexColor(g[1] * .8, g[2] * .8, g[3] * .8) end
        local dark = not c.muted and p.onGlow and p.onGlow[1] < .5
        b.count:SetText((dark and "|cff111111" or "|cffffffff") .. tostring(math.min(unread, 99)) .. "|r")
        b.badge:SetWidth(unread > 9 and 24 or 18)
    else
        b.badge:Hide()
        b.count:Hide()
    end
    b:SetScript("OnClick", function(btn, button)
        if button == "RightButton" then M:ConvMenu(btn, c) return end
        if r.hit then M.jump = r.hit end
        M.page = "chat"
        M:ShowView(c.view)
    end)
    Tip(b, function()
        local out = {{c.title, cr, cg, cb}}
        if info then
            out[#out + 1] = {info.bn and M.BNLine(info) or info.online and string.format("%s %s · %s", info.class or "", tostring(info.level or ""), info.zone or "") or M.OfflineText(info)}
        end
        if c.muted then out[#out + 1] = {T("stummgeschaltet: kein Ton, grauer Zähler")} end
        out[#out + 1] = {T("Rechtsklick: Anheften, Stumm, …"), .6, .6, .6}
        return out
    end)
end

-- Rechtsklick auf ein Gespraech
function M:ConvMenu(owner, c)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton(c.pinned and T("Lösen") or T("Anheften"), function() M.SetPinned(c.view, not c.pinned) M:Refresh() end)
        root:CreateButton(c.muted and T("Ton an") or T("Stummschalten"), function() M.SetMuted(c.view, not c.muted) M:Refresh() end)
        if (Chat.unread[c.view] or 0) > 0 then
            root:CreateButton(T("Als gelesen markieren"), function() Chat:MarkRead(c.view) M:Refresh() end)
        end
        if c.whisper then
            if ONE.PlayerMenu then root:CreateButton(T("Namens-Menü …"), function() ONE.PlayerMenu:Open(owner, c.whisper) end) end
            root:CreateButton(T("Gespräch schließen"), function() UI:CloseWhisper(c.view) end)
        elseif c.tab and not c.tab.builtin and UI.EditTab then
            root:CreateButton(T("Reiter bearbeiten …"), function() UI:EditTab(c.tab) end)
        end
    end)
end

-- ===== Gespraech rechts =====
function M:BuildMain(f)
    local main = CreateFrame("Frame", nil, f)
    self.main = main
    -- Kopfzeile
    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
    head:SetHeight(HEAD_H)
    self.head = head
    local back = CreateFrame("Button", nil, head)
    back:SetSize(22, 22)
    back:SetPoint("LEFT", head, "LEFT", 2, 0)
    local bt = back:CreateTexture(nil, "ARTWORK")
    bt:SetAllPoints(back)
    bt:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    back:SetScript("OnClick", function() M.page = "list" M:Layout() end)
    Tip(back, function() return {{T("Zurück zur Liste")}} end)
    self.back = back
    local av = head:CreateTexture(nil, "ARTWORK")
    av:SetSize(26, 26)
    av:SetTexture(ONE.Glass and ONE.Glass.tex.circle or (TEX .. "Dot"))
    self.headAv = av
    local letter = Text(head, "GameFontNormal")
    letter:SetPoint("CENTER", av, "CENTER", 0, 0)
    letter:SetJustifyH("CENTER")
    self.headLetter = letter
    self.headGlass = M.GlassAvatar(head, av, 2)
    local name = Text(head, "GameFontNormal")
    name:SetPoint("TOPLEFT", av, "TOPRIGHT", 8, 1)
    name:SetPoint("RIGHT", head, "RIGHT", -60, 0)
    if ONE.Fit then ONE.Fit:Line(name) end
    self.headName = name
    -- Fluestern: Name oben anklickbar (Spieltest 22.11.2026: Umschalt+Klick fuer Gildeneinladung ging nicht,
    -- weil im Fluestergespraech kein Name in den Blasen steht). Umschalt+Klick = wie ein Name im WoW-Chat
    -- (Einladungsdialog, Eingabefeld), Klick = Namens-Menue
    local hit = CreateFrame("Button", nil, head)
    hit:SetPoint("TOPLEFT", name, "TOPLEFT", -2, 2)
    hit:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 2, -2)
    if hit.RegisterForClicks then pcall(hit.RegisterForClicks, hit, "LeftButtonUp", "RightButtonUp") end
    hit:SetScript("OnClick", function(btn, button) M:HeadNameClick(btn, button) end)
    Tip(hit, function() return {{T("Umschalt+Klick: Name einfügen (z. B. Gildeneinladung)")}, {T("Klick: Namens-Menü"), .6, .6, .6}} end)
    self.headHit = hit
    local sub = Text(head, "GameFontDisableSmall")
    sub:SetPoint("BOTTOMLEFT", av, "BOTTOMRIGHT", 8, -1)
    sub:SetPoint("RIGHT", head, "RIGHT", -60, 0)
    if ONE.Fit then ONE.Fit:Line(sub) end
    self.headSub = sub
    -- Fluestern: Namens-Menue und Schliessen
    self.headMenu = ONE.Widgets:Button(head, "", 28, 20, "RIGHT", -30, 0, function(btn)
        local view = UI.current or ""
        if view:sub(1, 2) == "w:" and ONE.PlayerMenu then ONE.PlayerMenu:Open(btn, view:sub(3)) end
    end)
    -- drei Punkte als Bild: Text "···" zeigte im Spiel nur einen Punkt (Spielbild 22.11.2026)
    local G = ONE.Glass
    self.headMenu.dots = {}
    for i = -1, 1 do
        local d = self.headMenu:CreateTexture(nil, "OVERLAY")
        d:SetSize(4, 4)
        d:SetTexture(G and G.tex and G.tex.circle or "Interface\\Buttons\\WHITE8X8")
        d:SetVertexColor(.9, .9, .9, .9)
        d:SetPoint("CENTER", self.headMenu, "CENTER", i * 6, 0)
        self.headMenu.dots[#self.headMenu.dots + 1] = d
    end
    Tip(self.headMenu, function() return {{T("Namens-Menü")}, {T("Einladen, Navi, Ignorieren …")}} end)
    if ONE.Widgets.IconButton then
        self.headClose = ONE.Widgets:IconButton(head, "Interface\\AddOns\\ONE_Core\\Textures\\Common\\CloseGlyph.tga", 20, "RIGHT", -4, 0,
            function() UI:CloseWhisper(UI.current) end, "secondary", 9)
        Tip(self.headClose, function() return {{T("Gespräch schließen")}} end)
    end
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(1, 1, 1, .08)

    -- Verlauf (Sprechblasen)
    local log = CreateFrame("Frame", nil, main)
    log:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
    log:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, FOOT_H + 2)
    if log.SetClipsChildren then log:SetClipsChildren(true) end
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(_, delta)
        M.scroll = math.max(0, math.min(M.maxScroll or 0, (M.scroll or 0) + delta * 2))
        if M.scroll == 0 then M.newBelow = 0 end
        M:LayoutLog()
    end)
    self.log = log
    UI.log = nil
    local empty = Text(log, "GameFontDisable")
    empty:SetPoint("CENTER", log, "CENTER", 0, 0)
    empty:SetJustifyH("CENTER")
    self.empty = empty

    -- Knopf "nach unten" mit Zahl neuer Nachrichten
    local down = CreateFrame("Button", nil, main)
    down:SetSize(26, 26)
    down:SetPoint("BOTTOMRIGHT", log, "BOTTOMRIGHT", -8, 6)
    if down.SetFrameLevel and main.GetFrameLevel then down:SetFrameLevel((main:GetFrameLevel() or 1) + 10) end
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(down, "button") end
    local dt = down:CreateTexture(nil, "ARTWORK")
    dt:SetSize(20, 20)
    dt:SetPoint("CENTER", down, "CENTER", 0, -1)
    dt:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    down.count = Text(down, "GameFontHighlightSmall")
    down.count:SetPoint("BOTTOM", down, "TOP", 0, -2)
    down:SetScript("OnClick", function() M.scroll = 0 M.newBelow = 0 M:LayoutLog() end)
    Tip(down, function() return {{T("Nach unten")}} end)
    down:Hide()
    self.down = down

    -- Eingabe: Emoji-Knopf, Feld, Senden
    local foot = CreateFrame("Frame", nil, main)
    foot:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOT_H)
    self.foot = foot
    local emo = CreateFrame("Button", nil, foot)
    emo:SetSize(26, 26)
    emo:SetPoint("LEFT", foot, "LEFT", 2, 0)
    if ONE.Glass and ONE.Glass.Surface then emo.glass = ONE.Glass:Surface(emo, "select") end
    local et = emo:CreateTexture(nil, "ARTWORK")
    et:SetSize(18, 18)
    et:SetPoint("CENTER", emo, "CENTER", 0, 0)
    et:SetTexture(chat.Emoji and (chat.Emoji.DIR .. "1f60a") or (TEX .. "Dot"))
    emo:SetScript("OnClick", function() M:TogglePicker() end)
    Tip(emo, function() return {{T("Emojis und WoW-Zeichen")}, {T("Emojis sehen nur Spieler mit Guild Trip als Bild, andere lesen den Code (z. B. :daumen:). WoW-Zeichen wie {Stern} sieht jeder.")}} end)
    self.emojiButton = emo
    local send = ONE.Widgets:Button(foot, T("Senden"), 62, 24, "RIGHT", -2, 0, function() M:SendInput() end, "primary")
    self.sendButton = send
    local ok, box = pcall(CreateFrame, "EditBox", "GuildTripChatInput", foot, "InputBoxTemplate")
    if not ok or not box then box = CreateFrame("EditBox", "GuildTripChatInput", foot) end
    for _, key in ipairs({"Left", "Right", "Middle", "LeftDisabled", "RightDisabled", "MiddleDisabled"}) do
        local t = rawget(box, key)
        if type(t) == "table" and t.Hide then t:Hide() end
    end
    box:SetPoint("LEFT", emo, "RIGHT", 6, 0)
    box:SetPoint("RIGHT", send, "LEFT", -6, 0)
    box:SetHeight(24)
    box:SetAutoFocus(false)
    box:SetMaxLetters(1020)
    if box.SetTextInsets then box:SetTextInsets(10, 10, 0, 0) end
    if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(box, "card") end
    -- Enter: offene Gegenstands-Liste setzt erst den Link ein (Nutzer 23.11.2026), sonst senden
    box:SetScript("OnEnterPressed", function()
        if chat.ItemList and chat.ItemList:Complete() then return end
        M:SendInput()
    end)
    box:SetScript("OnEscapePressed", function(b)
        if chat.ItemList and chat.ItemList:IsShown() then chat.ItemList:Hide() return end
        if chat.SlashList and chat.SlashList:IsShown() then chat.SlashList:Hide() return end
        if M.picker and M.picker:IsShown() then M.picker:Hide() return end
        b:ClearFocus()
    end)
    box:SetScript("OnTabPressed", function()
        -- offene Befehls-/Gegenstandsliste: Tab setzt ein
        if chat.ItemList and chat.ItemList:Complete() then return end
        if chat.SlashList and chat.SlashList:Complete() then return end
        UI:CycleWhisper(IsShiftKeyDown and IsShiftKeyDown())
    end)
    -- Pfeil hoch/runter: Befehlsliste offen = dort auswaehlen, sonst letzte Eingaben (mit oder ohne Alt).
    -- Spieltest 23.11.2026: Alt+Pfeil kam im Feld nicht an (OnArrowPressed nur ohne Alt) -> zusaetzlich
    -- OnKeyDown; einfacher Pfeil blaettert ebenfalls (einzeiliges Feld, sonst ohne Wirkung).
    local function Arrow(key)
        if key ~= "UP" and key ~= "DOWN" then return end
        local now = (type(GetTime) == "function" and GetTime()) or 0
        if M.arrowAt == now and M.arrowKey == key then return end -- dieselbe Taste ueber beide Wege
        M.arrowAt, M.arrowKey = now, key
        local alt = IsAltKeyDown and IsAltKeyDown()
        if not alt and chat.ItemList and chat.ItemList:Move(key == "UP" and -1 or 1) then return end
        if not alt and chat.SlashList and chat.SlashList:Move(key == "UP" and -1 or 1) then return end
        M:HistoryStep(key == "UP" and 1 or -1)
    end
    box:SetScript("OnArrowPressed", function(_, key) Arrow(key) end)
    box:SetScript("OnKeyDown", function(_, key)
        if IsAltKeyDown and IsAltKeyDown() then Arrow(key) end
    end)
    box:SetScript("OnMouseUp", function(b, button) if button == "RightButton" then M:HistoryMenu(b) end end)
    local ph = Text(foot, "GameFontDisableSmall")
    ph:SetPoint("LEFT", box, "LEFT", 11, 0)
    ph:SetPoint("RIGHT", box, "RIGHT", -8, 0)
    if ONE.Fit then ONE.Fit:Line(ph, false) end
    self.placeholder = ph
    local function Placeholder()
        ph:SetShown((box:GetText() or "") == "" and not (box.HasFocus and box:HasFocus()))
    end
    self.UpdatePlaceholder = Placeholder
    box:SetScript("OnTextChanged", function()
        Placeholder()
        if chat.SlashList then chat.SlashList:Update() end
        if chat.ItemList then chat.ItemList:Update() end
    end)
    -- schmal auf der Liste (z. B. Enter bei ersetztem WoW-Chat): zum Gespraech wechseln
    box:SetScript("OnEditFocusGained", function()
        Placeholder()
        if M:IsNarrow() and M.page ~= "chat" then M.page = "chat" M:Layout() end
    end)
    box:SetScript("OnEditFocusLost", function()
        Placeholder()
        if chat.SlashList then chat.SlashList:FocusLost() end
        if chat.ItemList then chat.ItemList:FocusLost() end
    end)
    self.input = box
    UI.input = box
    UI.UpdatePlaceholder = Placeholder
end

-- ===== Antworten mit Zitat (wie WhatsApp, Nutzer 22.11.2026) =====
-- Der WoW-Chat uebertraegt nur Text: das Zitat steht gekuerzt vorne in der Nachricht
--   @Name „Anfang der Nachricht…“ Antwort
-- Spieler mit Guild Trip sehen daraus einen Zitat-Kasten in der Blase, alle anderen den Text.
M.QUOTE_CHARS = 30
-- reiner Text ohne Links/Farben/Bilder, gekuerzt (UTF-8-sicher)
function M.QuoteText(text, max)
    max = max or M.QUOTE_CHARS
    local plain = tostring(text or ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- ein schon vorhandenes Zitat nicht mitzitieren
    plain = plain:gsub("^@.- „.-“%s*", ""):gsub("[„“]", "\""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local out, n = {}, 0
    for ch in plain:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > max then return table.concat(out) .. "…" end
        out[#out + 1] = ch
    end
    return table.concat(out)
end
-- Antwort-Text bauen und wieder zerlegen
function M.WithQuote(name, quote, text) return "@" .. name .. " „" .. quote .. "“ " .. text end
function M.SplitQuote(text)
    -- Namen in Forever haben Leerzeichen ("Mechthild Verfallstag", Spieltest 22.11.2026)
    local name, quote, rest = tostring(text or ""):match("^@(.-) „(.-)“%s*(.*)$")
    if name and quote ~= "" then return name, quote, rest end
    return nil
end
-- Farbe fuer Strich und Name im Zitat: Klassenfarbe (Gildenliste, eigene Klasse), sonst Blau
function M.QuoteColor(name)
    local classFile
    if name and name == Me() and type(UnitClass) == "function" then classFile = select(2, Call(UnitClass, "player")) end
    classFile = classFile or (name and M.ClassOfGuid(nil, name))
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return {c.r, c.g, c.b} end
    return {.45, .78, 1}
end
-- Original einer zitierten Nachricht im Gespraech suchen (neueste zuerst, vor der Antwort)
function M.FindQuoted(view, entry)
    local name, quote = M.SplitQuote(entry and entry.text)
    if not name then return nil end
    local start = quote:gsub("…$", "")
    local buf = Chat:Buffer(view)
    local before = false
    for i = #buf, 1, -1 do
        local b = buf[i]
        if b == entry then before = true
        elseif before and Short(b.author or "") == name and M.QuoteText(b.text, 200):sub(1, #start) == start then return b end
    end
    return nil
end
function M:StartReply(entry)
    if not (entry and self.input) then return end
    local name = Short(entry.author or "")
    if name == "" then return end
    self.replyTo = {name = name, quote = M.QuoteText(entry.text), entry = entry}
    self:ShowReplyBar()
    self.input:SetFocus()
end
function M:CancelReply()
    local was = self.replyBar and self.replyBar:IsShown()
    self.replyTo = nil
    if self.replyBar then self.replyBar:Hide() end
    if was then self:LayoutLog() end
end
function M:ShowReplyBar()
    local rt = self.replyTo
    if not rt then return end
    local bar = self.replyBar
    if not bar then
        bar = CreateFrame("Frame", nil, self.main)
        bar:SetHeight(26)
        bar:SetPoint("BOTTOMLEFT", self.foot, "TOPLEFT", 0, 2)
        bar:SetPoint("BOTTOMRIGHT", self.foot, "TOPRIGHT", 0, 2)
        if bar.SetFrameLevel and self.main.GetFrameLevel then bar:SetFrameLevel((self.main:GetFrameLevel() or 1) + 15) end
        bar:EnableMouse(true)
        if ONE.Glass and ONE.Glass.Surface then ONE.Glass:Surface(bar, "card") else
            local bg = bar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(bar)
            bg:SetColorTexture(.08, .09, .12, .95)
        end
        bar.line = bar:CreateTexture(nil, "ARTWORK")
        bar.line:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, -4)
        bar.line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 4, 4)
        bar.line:SetWidth(3)
        bar.text = Text(bar, "GameFontHighlightSmall")
        bar.text:SetPoint("LEFT", bar, "LEFT", 12, 0)
        bar.text:SetPoint("RIGHT", bar, "RIGHT", -28, 0)
        if ONE.Fit then ONE.Fit:Line(bar.text, false) end
        if ONE.Widgets.IconButton then
            bar.close = ONE.Widgets:IconButton(bar, "Interface\\AddOns\\ONE_Core\\Textures\\Common\\CloseGlyph.tga", 18, "RIGHT", -4, 0,
                function() M:CancelReply() end, "secondary", 8)
            Tip(bar.close, function() return {{T("Antwort abbrechen")}} end)
        end
        self.replyBar = bar
    end
    local g = self:Palette().glow
    if bar.line.SetColorTexture then bar.line:SetColorTexture(g[1], g[2], g[3], .9) end
    -- Nutzer 22.11.2026: nur das Zitat; im Fluestern ohne Namen (ist klar, wem man antwortet)
    local whisper = (UI.current or ""):sub(1, 2) == "w:"
    bar.text:SetText((whisper and "" or (Hex(g) .. rt.name .. ":|r  ")) .. "|cffc8c8c8" .. rt.quote .. "|r")
    bar:Show()
    -- Leiste verdeckt sonst die unterste Blase
    self:LayoutLog()
end

function M:SendInput()
    local box = self.input
    if not box then return end
    local text = box:GetText() or ""
    local raw = text
    local rt = self.replyTo
    if rt and text:match("%S") and text:sub(1, 1) ~= "/" then
        -- WoW-Grenze 255 Zeichen: Zitat notfalls weiter kuerzen
        local quote = rt.quote
        local full = M.WithQuote(rt.name, quote, text)
        if #full > 255 and #text < 230 then
            quote = M.QuoteText(rt.entry and rt.entry.text or quote, 12)
            full = M.WithQuote(rt.name, quote, text)
        end
        if #full <= 255 then text = full end
    end
    local sent, err = Chat:Send(UI.current, text)
    if sent then
        self:CancelReply()
        M.AddHistory(raw)
        box:SetText("")
        if chat.SlashList then chat.SlashList:Hide() end
        if chat.ItemList then chat.ItemList:Hide() end
        -- wie im WoW-Chat: nach dem Senden zurueck ins Spiel, ohne erst ESC (Nutzer 23.11.2026)
        if box.ClearFocus then box:ClearFocus() end
        if Chat.drafts then Chat.drafts[UI.current] = nil end
        M.scroll, M.newBelow = 0, 0
        if self.picker then self.picker:Hide() end
    elseif err then
        ONE:Print(err)
    end
end

-- ===== Letzte Eingaben (Nutzer 23.11.2026: wie Alt+Pfeil im WoW-Chat, dazu Liste per Rechtsklick) =====
-- Gespeichert wird die eigene Eingabe ohne Zitat, neueste zuerst, ohne Doppelte, hoechstens 10.
-- Eine gewaehlte Eingabe kommt nur ins Feld, gesendet wird erst mit Enter/Senden.
M.HISTORY_MAX = 10
function M.History()
    local s = Chat:Settings()
    if type(s.inputHistory) ~= "table" then s.inputHistory = {} end
    return s.inputHistory
end
function M.AddHistory(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    M.histPos, M.histDraft = nil, nil
    if text == "" then return end
    local h = M.History()
    for i = #h, 1, -1 do if h[i] == text then table.remove(h, i) end end
    table.insert(h, 1, text)
    while #h > M.HISTORY_MAX do table.remove(h) end
end
function M.UseHistory(text)
    local box = M.input
    if not box then return end
    box:SetText(text or "")
    if box.SetCursorPosition then box:SetCursorPosition(#(text or "")) end
    box:SetFocus()
end
-- dir 1 = aeltere Eingabe (Alt+Hoch), -1 = neuere (Alt+Runter); ganz unten steht wieder der Entwurf
function M:HistoryStep(dir)
    local h, box = M.History(), self.input
    if not box or #h == 0 then return end
    local pos = M.histPos or 0
    if pos == 0 then M.histDraft = box:GetText() or "" end
    pos = math.max(0, math.min(#h, pos + dir))
    M.histPos = pos
    M.UseHistory(pos == 0 and M.histDraft or h[pos])
end
function M:HistoryMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local h = M.History()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if root.CreateTitle then root:CreateTitle(T("Letzte Eingaben")) end
        if #h == 0 then
            root:CreateButton(T("Noch nichts geschrieben"), function() end)
            return
        end
        for i, text in ipairs(h) do
            local shown = M.QuoteText(text, 40)
            if shown == "" then shown = text:sub(1, 40) end
            root:CreateButton(shown, function() M.histPos = i M.UseHistory(text) end)
        end
    end)
end

-- ===== Emoji-Auswahl =====
M.PICK_GROUPS = {{"recent", "Zuletzt"}, {"faces", "Gesichter"}, {"hands", "Gesten"}, {"hearts", "Herzen"}, {"things", "WoW"}, {"marks", "Zeichen"}}
function M:BuildPicker()
    if self.picker then return self.picker end
    local pk = CreateFrame("Frame", nil, self.main)
    self:PlaceOverlay(pk, 20)
    pk:SetHeight(150)
    pk:EnableMouse(true)
    if ONE.Glass and ONE.Glass.Surface then
        local G = ONE.Glass
        G.forceLook = "glass"
        local sf = G:Surface(pk, "card")
        G.forceLook = nil
        if sf then
            sf.store = function() return Chat:GlassStore() end
            self.surfaces[#self.surfaces + 1] = sf
            -- Auswahl liegt ueber den Blasen: nicht durchsichtig
            sf.onPaint = function(s2, p) s2.fill:SetColor(p.tint[1], p.tint[2], p.tint[3], .97) end
            G:Paint(sf)
        end
    end
    pk.tabs = {}
    for i, grp in ipairs(M.PICK_GROUPS) do
        local b = CreateFrame("Button", nil, pk)
        b:SetHeight(16)
        b.text = Text(b, "GameFontHighlightSmall")
        b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.text:SetText(T(grp[2]))
        b:SetWidth(math.max(30, (b.text.GetStringWidth and b.text:GetStringWidth() or 40) + 8))
        b.under = b:CreateTexture(nil, "ARTWORK")
        b.under:SetHeight(2)
        b.under:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, -1)
        b.under:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -1)
        b.key = grp[1]
        b:SetScript("OnClick", function() M.pickGroup = grp[1] M:FillPicker() end)
        pk.tabs[i] = b
    end
    pk.hint = Text(pk, "GameFontDisableSmall")
    pk.hint:SetPoint("BOTTOMLEFT", pk, "BOTTOMLEFT", 8, 6)
    pk.hint:SetPoint("BOTTOMRIGHT", pk, "BOTTOMRIGHT", -8, 6)
    if ONE.Fit then ONE.Fit:Line(pk.hint) end
    pk.cells = {}
    pk:Hide()
    self.picker = pk
    self.pickGroup = self.pickGroup or "recent"
    return pk
end
-- Emoji-Auswahl und Befehlsliste: ueber dem Verlauf – oder ueber der Eingabezeile der Randleiste
function M:PlaceOverlay(f, level)
    local R = chat.Rail
    local host = R and R.docked and R.quick or self.main
    if f.SetParent then f:SetParent(host) end
    f:ClearAllPoints()
    if host == self.main then
        f:SetPoint("BOTTOMLEFT", self.log, "BOTTOMLEFT", 4, 4)
        f:SetPoint("BOTTOMRIGHT", self.log, "BOTTOMRIGHT", -4, 4)
    else
        f:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 4)
        f:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 4)
    end
    if f.SetFrameLevel and host.GetFrameLevel then f:SetFrameLevel((host:GetFrameLevel() or 1) + (level or 20)) end
end
function M:TogglePicker()
    local pk = self:BuildPicker()
    if pk:IsShown() then pk:Hide() else pk:Show() self:FillPicker() end
    if self.emojiButton and self.emojiButton.glass then
        self.emojiButton.glass.on = pk:IsShown()
        if ONE.Glass then ONE.Glass:Paint(self.emojiButton.glass) end
    end
end
function M:FillPicker()
    local pk = self.picker
    if not (pk and pk:IsShown()) then return end
    local p = self:Palette()
    local g = p.glow
    -- Reiter (umbrechen, wenn schmal)
    local w = (pk:GetWidth() or 300) - 16
    local x, y = 8, -6
    for _, b in ipairs(pk.tabs) do
        local bw = b:GetWidth() or 40
        if x + bw > w + 8 then x, y = 8, y - 18 end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pk, "TOPLEFT", x, y)
        x = x + bw + 6
        local on = b.key == self.pickGroup
        b.under:SetColorTexture(g[1], g[2], g[3], 1)
        b.under:SetShown(on)
        b.text:SetTextColor(on and g[1] or .7, on and g[2] or .7, on and g[3] or .7)
    end
    local top = -y + 22
    local items = chat.Emoji and chat.Emoji.PickerItems(self.pickGroup, Chat:Settings()) or {}
    local size, step = 22, 26
    local cols = math.max(4, math.floor(w / step))
    local rowsFit = math.max(1, math.floor(((pk:GetHeight() or 150) - top - 22) / step))
    for i, it in ipairs(items) do
        local c = pk.cells[i]
        if not c then
            c = CreateFrame("Button", nil, pk)
            c:SetSize(size, size)
            c.icon = c:CreateTexture(nil, "ARTWORK")
            c.icon:SetAllPoints(c)
            c.hl = c:CreateTexture(nil, "HIGHLIGHT")
            c.hl:SetPoint("TOPLEFT", c, "TOPLEFT", -2, 2)
            c.hl:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 2, -2)
            c.hl:SetColorTexture(1, 1, 1, .12)
            pk.cells[i] = c
        end
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        if row < rowsFit then
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", pk, "TOPLEFT", 8 + col * step, -top - row * step)
            if it.kind == "mark" then c.icon:SetTexture(chat.Emoji.MARK_TEX .. it.n) else c.icon:SetTexture(chat.Emoji.Texture(it.item)) end
            c:SetScript("OnClick", function() M:InsertCode(it.code) end)
            c:SetScript("OnEnter", function()
                pk.hint:SetText(it.name .. "  |cff9a9a9a" .. it.code .. "|r" .. (it.kind == "mark" and ("  |cff9a9a9a" .. T("(sieht jeder)") .. "|r") or ""))
            end)
            c:SetScript("OnLeave", function() M:PickerHint() end)
            c:Show()
        else
            c:Hide()
        end
    end
    for i = #items + 1, #pk.cells do pk.cells[i]:Hide() end
    self:PickerHint()
end
function M:PickerHint()
    local pk = self.picker
    if not pk then return end
    pk.hint:SetText(self.pickGroup == "marks" and T("WoW-Zeichen sieht jeder – auch ohne Guild Trip.")
        or T("Emojis: Bild nur mit Guild Trip, sonst steht der Code da."))
end
function M:InsertCode(code)
    local box = self.input
    if not box then return end
    local cur = box:GetText() or ""
    local pre = (cur ~= "" and not cur:find("%s$")) and " " or ""
    if box.Insert then box:Insert(pre .. code .. " ") else box:SetText(cur .. pre .. code .. " ") end
    if box.SetFocus then box:SetFocus() end
    if chat.Emoji then chat.Emoji.Remember(Chat:Settings(), code) end
    if self.UpdatePlaceholder then self.UpdatePlaceholder() end
end

-- ===== Blasen =====
local function NewBubble(log)
    local r = CreateFrame("Frame", nil, log)
    r:EnableMouse(true)
    local G = ONE.Glass
    if G and G.Nine then
        r.bg = G:Nine(r, G.tex.round, .25, "BACKGROUND", 1)
    end
    -- Zipfel an der ersten Blase einer Folge (wie WhatsApp), ersetzt die obere aeussere Ecke
    r.tail = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.tail:SetTexture(TAIL_TEX)
    r.tail:Hide()
    -- Glas: Rand (auch um den Zipfel) und Glanz oben
    if G and G.Nine then r.edge = G:Nine(r, G.tex.roundRing, .25, "BACKGROUND", 2) end
    r.tailEdge = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.tailEdge:SetTexture(TAIL_RING_TEX)
    r.tailEdge:Hide()
    r.sheen = r:CreateTexture(nil, "BACKGROUND", nil, 3)
    if G and G.tex then r.sheen:SetTexture(G.tex.sheen) end
    r.sheen:Hide()
    r.flat = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.flat:Hide()
    r.who = Text(r, "GameFontNormalSmall")
    -- kleines Klassen-Symbol (Glas) vor dem Namen
    r.clsAv = r:CreateTexture(nil, "ARTWORK")
    r.clsAv:SetSize(14, 14)
    if G and G.tex then r.clsAv:SetTexture(G.tex.circle) end
    r.cls = M.GlassAvatar(r, r.clsAv, 1)
    M.HideAvatar(r.cls)
    if ONE.Fit then ONE.Fit:Line(r.who, false) end
    -- Zitat-Kasten wie WhatsApp: dunklere Flaeche, farbiger Strich links, Name + Zitat
    r.qbox = r:CreateTexture(nil, "BORDER")
    r.qbar = r:CreateTexture(nil, "ARTWORK")
    r.qbar:SetWidth(3)
    r.qname = Text(r, "GameFontNormalSmall")
    r.qtext = Text(r, "GameFontHighlightSmall")
    if ONE.Fit then ONE.Fit:Line(r.qname, false) ONE.Fit:Line(r.qtext, false) end
    r.text = Text(r, "ChatFontNormal")
    if r.text.SetWordWrap then r.text:SetWordWrap(true) end
    if r.text.SetNonSpaceWrap then r.text:SetNonSpaceWrap(true) end
    r.time = Text(r, "GameFontDisableSmall")
    r.time:SetJustifyH("RIGHT")
    r.tick = r:CreateTexture(nil, "OVERLAY")
    r.tick:SetSize(11, 11)
    r.note = Text(r, "GameFontDisableSmall")
    r.note:SetJustifyH("RIGHT")
    r.line1 = r:CreateTexture(nil, "ARTWORK")
    r.line1:SetHeight(1)
    r.line2 = r:CreateTexture(nil, "ARTWORK")
    r.line2:SetHeight(1)
    -- Links: Gegenstand zeigen (Vorschau), anklicken wie im WoW-Chat, Namen -> Namens-Menue
    if r.SetHyperlinksEnabled then pcall(r.SetHyperlinksEnabled, r, true) end
    pcall(r.SetScript, r, "OnHyperlinkClick", function(self, link, text, button)
        self.linkHandled = (type(GetTime) == "function" and GetTime()) or 0
        if UI.ShiftLink and UI.ShiftLink(link, text, button, self) then return end
        local kind, rest = tostring(link):match("^(%a+):(.*)$")
        if kind == "player" and ONE.PlayerMenu then
            local name, lineID = rest:match("^([^:]+):?(%d*)")
            ONE.PlayerMenu:Open(self, name, {lineID = tonumber(lineID)})
            return
        end
        UI.OpenLink(link, text, button, self, self.item and self.item.entry and self.item.entry.author)
    end)
    pcall(r.SetScript, r, "OnHyperlinkEnter", function(self, link)
        local kind = tostring(link):match("^(%a+):")
        if not (GameTooltip and kind) or kind == "player" then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if kind == "trade" then
            -- Berufs-Link: WoW hat dafuer keinen Tooltip -> Hinweis, dass man klicken kann
            GameTooltip:SetText(T("Berufs-Link"))
            GameTooltip:AddLine(T("Klick: bekannte Rezepte zeigen und anflüstern"), .8, .8, .8)
            GameTooltip:Show()
            return
        end
        if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    pcall(r.SetScript, r, "OnHyperlinkLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    r:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.item then M:BubbleMenu(self, self.item) return end
        -- Spieltest 22.11.2026: in Forever kommen Link-Klicks in den Blasen nicht an (kein OnHyperlinkClick).
        -- Darum selbst: Klick auf den Namen = Namens-Menue, sonst Link der Nachricht oeffnen (mehrere: Auswahl).
        -- Kommt der Link-Klick doch an, hat er Vorrang (linkHandled).
        -- SOFORT, nicht verzoegert: das Berufsfenster oeffnet WoW nur waehrend eines echten Mausklicks
        -- (Spieltest 22.11.2026: mit C_Timer kam der Klick an, aber nichts ging auf)
        if button ~= "LeftButton" or not self.item then return end
        local now = (type(GetTime) == "function" and GetTime()) or 0
        -- Doppelklick = Antworten mit Zitat (Nutzer 22.11.2026); das Menue des ersten Klicks wieder schliessen
        local e = self.item.entry
        if e and self.item.type == "bubble" and M.lastClick and M.lastClick.entry == e and now - M.lastClick.t < .4 then
            M.lastClick = nil
            M.CloseMenus()
            M:StartReply(e)
            return
        end
        M.lastClick = {entry = e, t = now}
        if self.linkHandled and now - self.linkHandled < .5 then return end
        M:BubbleClick(self, self.item)
    end)
    return r
end

-- Innenabstand der Blasen oben/unten
M.PAD_TOP, M.PAD_BOTTOM = 7, 6
-- Groesse der Emojis, wenn eine Nachricht nur aus Emojis besteht
function M.BigEmojiSize(fsize) return math.floor((fsize or 14) * 2.2) end

-- ===== In die Gilde einladen (sicherer Knopf) =====
-- Forever sperrt das Einladen fuer Addons ("ONE_Chat wurde geblockt", Spieltest 22.11.2026) – auch, wenn ein Addon
-- den Namen nur ins Einladungsfenster schreibt. Erlaubt ist ein Makro-Knopf, den DU anklickst
-- (SecureActionButtonTemplate, /ginvite Name). Er haengt an UIParent, damit das Chatfenster nicht "geschuetzt"
-- wird; er wird nur ausserhalb des Kampfs gezeigt/geaendert und beim Kampfbeginn versteckt.
function M.CanInvite()
    if type(IsInGuild) == "function" and not Call(IsInGuild) then return false end
    if type(CanGuildInvite) == "function" then return Call(CanGuildInvite) and true or false end
    if C_GuildInfo and type(C_GuildInfo.CanGuildInvite) == "function" then return Call(C_GuildInfo.CanGuildInvite) and true or false end
    return false
end
-- Wen einladen? Fluestergespraech mit jemandem, der nicht in deiner Gilde ist (Battle.net: sein Charakter)
function M.InviteTarget(view)
    local name = M.HeadPlayer(view)
    if not name or name == "" or Short(name) == Me() then return nil end
    local info = M.RosterInfo(name)
    if info and info.inGuild then return nil end
    return name
end
function M:BuildInviteButton()
    if self.inviteButton or not self.head then return self.inviteButton end
    local ok, b = pcall(CreateFrame, "Button", "GuildTripChatInvite", UIParent, "SecureActionButtonTemplate")
    if not ok or not b then return nil end
    b:SetSize(20, 20)
    b:SetFrameStrata("HIGH")
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexture("Interface\\GossipFrame\\TabardGossipIcon")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    hl:SetBlendMode("ADD")
    b:SetAttribute("type", "macro")
    b:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText(T("In die Gilde einladen"))
        GameTooltip:AddLine(T("Lädt %s in deine Gilde ein.", btn.target or "?"), .8, .8, .8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:Hide()
    -- Kampfbeginn: PLAYER_REGEN_DISABLED kommt kurz BEVOR WoW sperrt -> jetzt noch verstecken
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then b:Hide() else M:UpdateInviteButton() end
    end)
    self.inviteButton = b
    return b
end
function M:UpdateInviteButton()
    if InCombatLockdown and InCombatLockdown() then return end
    local b = self:BuildInviteButton()
    if not b then return end
    local shown = self.frame and self.frame:IsShown() and self.head and self.head:IsVisible() and self.headMenu and self.headMenu:IsVisible()
    local target = shown and M.CanInvite() and M.InviteTarget(UI.current)
    if not target then b:Hide() b.target = nil return end
    b.target = target
    b:SetAttribute("macrotext", "/ginvite " .. target)
    b:ClearAllPoints()
    b:SetPoint("RIGHT", self.headMenu, "LEFT", -4, 0)
    b:Show()
end

-- Name oben im Fluestergespraech: Spielername dazu (Battle.net-Freund: sein Charakter, wenn er WoW spielt)
function M.HeadPlayer(view)
    if type(view) ~= "string" or view:sub(1, 2) ~= "w:" then return nil end
    local name = view:sub(3)
    if Chat.IsBN and Chat.IsBN(name) then
        local b = Chat.BNInfo and Chat.BNInfo(Chat.BNFind(name))
        return b and b.online and b.character and b.character ~= "" and b.character or nil
    end
    return name
end
function M:HeadNameClick(owner, button)
    local name = M.HeadPlayer(UI.current)
    if not name then return end
    local link = "player:" .. name
    if UI.ShiftLink and UI.ShiftLink(link, "[" .. name .. "]", button or "LeftButton", owner) then return end
    if ONE.PlayerMenu then ONE.PlayerMenu:Open(owner, name) end
end

-- Rechtsklick auf eine Blase: Antworten, Text kopieren, Namens-Menue
-- offene Klickmenues schliessen (WoW-Menue, Namens-Menue)
function M.CloseMenus()
    if Menu and type(Menu.GetManager) == "function" then
        pcall(function() local m = Menu.GetManager() if m and m.CloseMenus then m:CloseMenus() end end)
    end
    if type(CloseDropDownMenus) == "function" then pcall(CloseDropDownMenus) end
    if ONE.PlayerMenu and type(ONE.PlayerMenu.Close) == "function" then pcall(ONE.PlayerMenu.Close, ONE.PlayerMenu) end
end
-- Links in einem Text: {{link = "item:…", text = "[Name]", full = "|H…|h[Name]|h"}}
function M.LinksIn(text)
    local out = {}
    for payload, shown in tostring(text or ""):gmatch("|H(.-)|h(.-)|h") do
        out[#out + 1] = {link = payload, text = shown, full = "|H" .. payload .. "|h" .. shown .. "|h"}
    end
    return out
end
-- Liegt der Mauszeiger auf der Namenszeile der Blase?
function M.CursorOnName(r)
    if not (r.who and r.who:IsShown() and type(GetCursorPosition) == "function" and r.GetTop) then return false end
    local _, y = GetCursorPosition()
    local scale = (r.GetEffectiveScale and r:GetEffectiveScale()) or 1
    local top = r:GetTop()
    if not (y and top) then return false end
    return y / scale >= top - 18
end
function M:BubbleClick(owner, item)
    local e = item.entry
    if not e then return end
    -- Umschalt: Link/Name wie gewohnt ins Feld
    local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
    if M.CursorOnName(owner) and not e.npc and (e.author or "") ~= "" then
        local name = e.author
        if UI.AltInvite and UI:AltInvite(name) then return end
        if shift and UI.ShiftLink and UI.ShiftLink("player:" .. name, "[" .. Short(name) .. "]", "LeftButton", owner) then return end
        if ONE.PlayerMenu then ONE.PlayerMenu:Open(owner, Short(name), {lineID = e.lineID}) end
        return
    end
    local links = M.LinksIn(e.text)
    if #links == 0 then
        -- Antwort mit Zitat: zur Original-Nachricht springen
        local found = M.FindQuoted(UI.current, e)
        if found then M.jump = found UI:Show(UI.current) end
        return
    end
    local function Open(l)
        if shift and UI.ShiftLink and UI.ShiftLink(l.link, l.full, "LeftButton", owner) then return end
        UI.OpenLink(l.link, l.full, "LeftButton", owner, e.author)
    end
    if #links == 1 or not (MenuUtil and MenuUtil.CreateContextMenu) then Open(links[1]) return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, l in ipairs(links) do root:CreateButton(l.text, function() Open(l) end) end
    end)
end
function M:BubbleMenu(owner, item)
    local e = item.entry
    if not (e and MenuUtil and MenuUtil.CreateContextMenu) then return end
    local name = Short(e.author or "")
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if name ~= "" and item.type == "bubble" then
            root:CreateButton(T("Antworten"), function() M:StartReply(e) end)
        end
        if not item.out and name ~= "" and item.type == "bubble" then
            if ONE.PlayerMenu then root:CreateButton(T("Namens-Menü …"), function() ONE.PlayerMenu:Open(owner, name) end) end
        end
        for _, l in ipairs(M.LinksIn(e.text)) do
            root:CreateButton(T("Öffnen: %s", l.text), function() UI.OpenLink(l.link, l.full, "LeftButton", owner, e.author) end)
        end
        root:CreateButton(T("Text kopieren"), function()
            if not M.input then return end
            M.input:SetText(tostring(e.text or ""))
            M.input:SetFocus()
            if M.input.HighlightText then M.input:HighlightText() end
            ONE:Print(T("Text steht im Eingabefeld und ist markiert – Strg+C kopiert ihn."))
        end)
    end)
end

local function SetBg(r, on, cr, cg, cb, ca)
    if r.bg then
        r.bg:SetShown(on)
        if on then r.bg:SetColor(cr, cg, cb, ca) end
    end
    if r.tail and on then r.tail:SetVertexColor(cr, cg, cb, ca) end
    if not on then
        if r.edge then r.edge:SetShown(false) end
        if r.tailEdge then r.tailEdge:Hide() end
        if r.sheen then r.sheen:Hide() end
    end
end

-- Hoehe eines Eintrags; legt die Teile innerhalb der Zeile an
function M:FillBubble(r, it, W, p)
    local s = Chat:Settings()
    r.item = it
    for _, part in ipairs({r.who, r.text, r.time, r.tick, r.note, r.line1, r.line2, r.flat, r.tail, r.tailEdge, r.sheen, r.qbox, r.qbar, r.qname, r.qtext}) do part:Hide() end
    M.HideAvatar(r.cls)
    SetBg(r, false)
    local file = ChatFontNormal and ChatFontNormal.GetFont and ChatFontNormal:GetFont()
    if file and r.text.SetFont then pcall(r.text.SetFont, r.text, file, s.fontSize or 14, "") end
    local fsize = s.fontSize or 14
    local g = p.glow
    if it.type == "day" or it.type == "sys" then
        local txt
        if it.type == "day" then txt = it.text
        elseif it.emote then txt = (Chat.ClassColorCode(it.entry.guid, false) or "|cffff8040") .. Short(it.entry.author) .. "|r |cffff9a5a" .. M.Show(it.entry.text, 0) .. "|r"
        else txt = M.Show(it.entry.text, 0) end
        local small = it.type == "day"
        r.text:SetFontObject(small and GameFontDisableSmall or GameFontHighlightSmall)
        r.text:SetJustifyH("CENTER")
        r.text:SetWidth(math.floor(W * .9) - 20)
        r.text:SetText(txt)
        if not small and not it.emote then r.text:SetTextColor(.85, .80, .55) else r.text:SetTextColor(1, 1, 1) end
        local tw = math.min(math.floor(W * .9) - 20, (r.text:GetStringWidth() or 60) + 2)
        r.text:SetWidth(tw)
        local th = r.text:GetStringHeight() or 12
        local bw, bh = tw + 20, th + (small and 4 or 6)
        r:SetSize(bw, bh)
        r.text:ClearAllPoints()
        r.text:SetPoint("CENTER", r, "CENTER", 0, 0)
        r.text:Show()
        SetBg(r, true, 1, 1, 1, small and .07 or .05)
        if it.type == "sys" and not it.emote then SetBg(r, true, g[1], g[2], g[3], .08) end
        if r.bg then r.bg:Place(math.min(8, math.floor(bh / 2)), 0, r) end
        return bh, "CENTER"
    end
    if it.type == "new" then
        -- schmaler: rechts unten sitzt der Knopf "Nach unten" (Spielbild 22.11.2026: Linie lief darunter)
        local NW = W - 70
        r:SetSize(NW, 16)
        r.text:SetFontObject(GameFontNormalSmall)
        r.text:SetJustifyH("CENTER")
        r.text:SetWidth(NW)
        r.text:SetText(it.count == 1 and T("1 neue Nachricht") or T("%d neue Nachrichten", it.count))
        r.text:SetTextColor(g[1], g[2], g[3])
        r.text:ClearAllPoints()
        r.text:SetPoint("CENTER", r, "CENTER", 0, 0)
        r.text:Show()
        local tw = math.min(NW - 24, (r.text:GetStringWidth() or 100) + 16)
        r.line1:SetColorTexture(g[1], g[2], g[3], .5)
        r.line2:SetColorTexture(g[1], g[2], g[3], .5)
        r.line1:ClearAllPoints() r.line1:SetPoint("LEFT", r, "LEFT", 0, 0) r.line1:SetWidth(math.max(1, (NW - tw) / 2))
        r.line2:ClearAllPoints() r.line2:SetPoint("RIGHT", r, "RIGHT", 0, 0) r.line2:SetWidth(math.max(1, (NW - tw) / 2))
        r.line1:Show() r.line2:Show()
        return 16, "CENTER"
    end
    -- Sprechblase
    local e = it.entry
    r.text:SetFontObject(ChatFontNormal or GameFontHighlight)
    if file and r.text.SetFont then pcall(r.text.SetFont, r.text, file, fsize, "") end
    r.text:SetJustifyH("LEFT")
    local tc = M.ValidColor(s.bubbleText)
    if tc then r.text:SetTextColor(tc[1], tc[2], tc[3]) else r.text:SetTextColor(1, 1, 1) end
    local big = s.bigEmoji ~= false and s.emojiImages ~= false and chat.Emoji and chat.Emoji.OnlyEmoji(e.text)
    local maxW = math.floor(W * .78)
    local pad = 10
    local inner = maxW - 2 * pad
    local qName, qText, qRest = M.SplitQuote(e.text)
    local txt
    local quoteW, quoteH = 0, 0
    if qName and not big then
        -- Zitat-Kasten (Name in Leuchtfarbe, Zitat grau), darunter nur die Antwort
        txt = M.Show(qRest, 0)
        r.quoted = {name = qName, quote = qText}
        r.qname:SetText(qName == Me() and T("Du") or qName)
        r.qtext:SetText(M.Show(qText, 0))
        r.qname:SetWidth(0) r.qtext:SetWidth(0)
        quoteW = math.min(inner, math.max(r.qname:GetStringWidth() or 40, r.qtext:GetStringWidth() or 40) + 16)
        quoteH = 34
    else
        txt = M.Show(e.text, big and M.BigEmojiSize(fsize) or 0)
        r.quoted = nil
    end
    r.text:SetWidth(inner)
    r.text:SetText(txt)
    local tw = r.text:GetStringWidth() or 60
    -- Name (Gruppen, Gilde …), im Reiter "Alle" mit Art
    local whoW, whoH, clsW = 0, 0, 0
    if it.name then
        local classFile0 = not e.npc and M.ClassOfGuid(e.guid, e.author) or nil
        local code = Chat.ClassColorCode(e.guid, false)
        if not code and classFile0 and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile0] then code = Hex({ClassRGB(classFile0)}) end
        local kind = it.kind and Chat.kindByKey[it.kind]
        local shown = (code or "|cffd0d0d0") .. Short(e.author) .. "|r"
        local link = e.npc and shown or ("|Hplayer:" .. (e.author or "") .. ":" .. tostring(e.lineID or 0) .. "|h" .. shown .. "|h")
        if kind then link = link .. "  " .. Hex(kind.color) .. T(kind.label) .. "|r" end
        r.who:SetText(link)
        local classFile = s.classIcons ~= false and classFile0
        local l, rr, tt, bb = M.ClassCoords(classFile)
        if l and r.cls then
            clsW = 17
            local cr2, cg2, cb2 = ClassRGB(classFile)
            M.PaintAvatar(r.cls, p, cr2, cg2, cb2, CLASS_ATLAS, {l, rr, tt, bb})
        end
        whoW, whoH = (r.who:GetStringWidth() or 40) + 2 + clsW, 13
        r.who:Show()
    end
    local nameH = whoH
    -- +6: Abstand zwischen Zitat-Kasten und Antwort (Nutzer 22.11.2026)
    if quoteH > 0 then whoW, whoH = math.max(whoW, quoteW), whoH + (whoH > 0 and 3 or 2) + quoteH + 6 end
    -- Uhrzeit (+ Haken) unten rechts in der Blase
    local stamp = (type(date) == "function" and date("%H:%M", e.time or 0)) or ""
    r.time:SetText(stamp)
    local timeW = (r.time:GetStringWidth() or 26) + 2
    local tickW = 0
    local whisperOut = it.out and e.kind == "whisper"
    if whisperOut and (e.delivered or e.pending) then
        tickW = 13
        r.tick:SetTexture(e.pending and "Interface\\RaidFrame\\ReadyCheck-Waiting" or "Interface\\RaidFrame\\ReadyCheck-Ready")
    end
    local lineH = fsize + 2
    local th = r.text:GetStringHeight() or lineH
    local oneLine = th <= lineH * 1.5
    local stampW = timeW + tickW
    local bw, bh, timeBelow
    if oneLine and tw + 8 + stampW <= inner then
        bw = math.max(tw + 8 + stampW, whoW) + 2 * pad
        timeBelow = false
    else
        bw = math.max(math.min(tw, inner), whoW, stampW) + 2 * pad
        timeBelow = true
    end
    r.text:SetWidth(bw - 2 * pad - (timeBelow and 0 or (8 + stampW)))
    -- Mehrzeilig: WoW misst die Breite der ungebrochenen Zeile -> rechts blieb Luft (Spielbild 22.11.2026
    -- "Texte nicht mittig"). Schmalste Breite mit gleich vielen Zeilen suchen, Blase daran anpassen.
    if timeBelow and not big and r.text.GetNumLines then
        local w = bw - 2 * pad
        local lines = r.text:GetNumLines()
        local lo, hi = math.max(40, whoW, stampW), w
        if lines and lines > 1 and lo < hi then
            for _ = 1, 7 do
                local mid = math.floor((lo + hi) / 2)
                r.text:SetWidth(mid)
                if r.text:GetNumLines() > lines then lo = mid + 1 else hi = mid end
            end
            r.text:SetWidth(hi)
            bw = hi + 2 * pad
        else
            r.text:SetWidth(w)
        end
    end
    th = r.text:GetStringHeight() or th
    -- oben und unten gleich viel Luft (Spielbild 22.11.2026)
    bh = M.PAD_TOP + whoH + th + (timeBelow and 12 or 0) + M.PAD_BOTTOM
    -- grosses Emoji: WoW zaehlt die Bildhoehe nicht zur Texthoehe -> selbst rechnen, Namenszeile mitzaehlen
    if big then bh = 4 + whoH + (it.name and 1 or 0) + math.max(th, M.BigEmojiSize(fsize)) + 4 end
    -- Blase
    local cr, cg, cb, ca, er, eg, eb, ea = M.BubbleColor(p, it.out, e.failed, e.kind)
    r.flat:ClearAllPoints()
    local noteH = e.failed and 13 or 0
    r:SetSize(bw, bh + noteH)
    if not big then
        SetBg(r, true, cr, cg, cb, ca)
        if r.bg then
            -- Blase ohne die Zeile "nicht zugestellt"
            local holder = r.bgHolder or CreateFrame("Frame", nil, r)
            r.bgHolder = holder
            holder:ClearAllPoints()
            holder:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
            holder:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 0)
            holder:SetHeight(bh)
            r.bg:Place(BUBBLE_R, 0, holder)
            -- erste Blase einer Folge: Zipfel oben aussen statt runder Ecke
            local corner = r.bg.pieces and r.bg.pieces[it.out and 3 or 1]
            if not it.cont and corner and r.tail then
                corner:Hide()
                r.tail:ClearAllPoints()
                r.tail:SetSize(2 * BUBBLE_R, BUBBLE_R)
                if it.out then
                    r.tail:SetPoint("TOPLEFT", holder, "TOPRIGHT", -BUBBLE_R, 0)
                    r.tail:SetTexCoord(1, 0, 0, 1)
                else
                    r.tail:SetPoint("TOPRIGHT", holder, "TOPLEFT", BUBBLE_R, 0)
                    r.tail:SetTexCoord(0, 1, 0, 1)
                end
                r.tail:Show()
            end
            -- Glas: Rand und Glanz
            if r.edge then
                r.edge:SetShown(true)
                r.edge:SetColor(er, eg, eb, ea)
                r.edge:Place(BUBBLE_R, 0, holder)
                local ec = r.edge.pieces[it.out and 3 or 1]
                if not it.cont and ec and r.tailEdge then
                    ec:Hide()
                    r.tailEdge:ClearAllPoints()
                    r.tailEdge:SetAllPoints(r.tail)
                    r.tailEdge:SetTexCoord(it.out and 1 or 0, it.out and 0 or 1, 0, 1)
                    r.tailEdge:SetVertexColor(er, eg, eb, ea)
                    r.tailEdge:Show()
                end
            end
            if r.sheen then
                r.sheen:ClearAllPoints()
                r.sheen:SetPoint("TOPLEFT", holder, "TOPLEFT", BUBBLE_R - 2, -1)
                r.sheen:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -(BUBBLE_R - 2), -1)
                r.sheen:SetHeight(math.max(6, math.floor(bh * .45)))
                r.sheen:SetVertexColor(1, 1, 1, it.out and .06 or .04)
                r.sheen:Show()
            end
        end
    end
    if it.name then
        r.who:ClearAllPoints()
        r.who:SetPoint("TOPLEFT", r, "TOPLEFT", pad + clsW, -M.PAD_TOP)
        if clsW > 0 then
            r.clsAv:ClearAllPoints()
            r.clsAv:SetPoint("RIGHT", r.who, "LEFT", -3, 0)
        end
    end
    if quoteH > 0 then
        -- Farbe wie bei WhatsApp je Person: Klassenfarbe der zitierten Person (Spielbild 22.11.2026:
        -- Gold auf goldener Blase zu wenig Kontrast), sonst ein ruhiges Blau
        local g0 = M.QuoteColor(qName)
        local top = -(M.PAD_TOP + nameH + (nameH > 0 and 3 or 2))
        r.qbox:ClearAllPoints()
        r.qbox:SetPoint("TOPLEFT", r, "TOPLEFT", pad - 4, top)
        r.qbox:SetPoint("TOPRIGHT", r, "TOPRIGHT", -(pad - 4), top)
        r.qbox:SetHeight(quoteH)
        -- eigene (goldene) Blase: Kasten dunkler, fremde Blase: Kasten leicht heller
        if r.qbox.SetColorTexture then
            if it.out then r.qbox:SetColorTexture(0, 0, 0, .30) else r.qbox:SetColorTexture(1, 1, 1, .07) end
        end
        r.qbar:ClearAllPoints()
        r.qbar:SetPoint("TOPLEFT", r.qbox, "TOPLEFT", 0, 0)
        r.qbar:SetPoint("BOTTOMLEFT", r.qbox, "BOTTOMLEFT", 0, 0)
        if r.qbar.SetColorTexture then r.qbar:SetColorTexture(g0[1], g0[2], g0[3], .95) end
        r.qname:ClearAllPoints()
        r.qname:SetPoint("TOPLEFT", r.qbox, "TOPLEFT", 9, -4)
        r.qname:SetPoint("RIGHT", r.qbox, "RIGHT", -6, 0)
        r.qname:SetTextColor(g0[1], g0[2], g0[3])
        r.qtext:ClearAllPoints()
        r.qtext:SetPoint("TOPLEFT", r.qname, "BOTTOMLEFT", 0, -3)
        r.qtext:SetPoint("RIGHT", r.qbox, "RIGHT", -6, 0)
        r.qtext:SetTextColor(.86, .86, .86)
        for _, q in ipairs({r.qbox, r.qbar, r.qname, r.qtext}) do q:Show() end
    end
    r.text:ClearAllPoints()
    r.text:SetPoint("TOPLEFT", r, "TOPLEFT", pad, -(M.PAD_TOP + whoH + (it.name and 1 or 0)))
    r.text:Show()
    if not big then
        r.time:ClearAllPoints()
        r.time:SetPoint("BOTTOMRIGHT", r, "TOPRIGHT", -(pad + tickW), -(bh - M.PAD_BOTTOM + 2))
        r.time:SetTextColor(it.out and .82 or .6, it.out and .85 or .6, it.out and .82 or .62)
        r.time:Show()
        if tickW > 0 then
            r.tick:ClearAllPoints()
            r.tick:SetPoint("LEFT", r.time, "RIGHT", 2, 0)
            r.tick:Show()
        end
    end
    if e.failed then
        r.note:SetText("|cffe07070" .. T("nicht zugestellt – %s ist offline", Short(e.author)) .. "|r")
        r.note:ClearAllPoints()
        r.note:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2, -(bh + 1))
        r.note:Show()
    end
    -- gesprungen (Suche): kurz hervorheben
    if M.highlight == e and r.bg then
        r.bg:SetColor(math.min(1, cr + .25), math.min(1, cg + .2), cb, 1)
        if r.tail then r.tail:SetVertexColor(math.min(1, cr + .25), math.min(1, cg + .2), cb, 1) end
    end
    return bh + noteH, it.out and "RIGHT" or "LEFT"
end

-- Blasen von unten nach oben setzen (scroll = wie viele Eintraege unten ausgeblendet sind)
function M:LayoutLog()
    local log = self.log
    if not (log and self.frame and self.frame:IsShown()) then return end
    local items = self.items or {}
    local W = log:GetWidth() or 300
    local H = log:GetHeight() or 200
    local p = self:Palette()
    self.maxScroll = math.max(0, #items - 1)
    self.scroll = math.min(self.scroll or 0, self.maxScroll)
    -- Platz fuer die Antwort-Leiste lassen
    local y, n = 6 + ((self.replyBar and self.replyBar:IsShown()) and 30 or 0), 0
    for i = #items - self.scroll, 1, -1 do
        if y > H then break end
        n = n + 1
        local r = self.bubbles[n] or NewBubble(log)
        self.bubbles[n] = r
        local h, side = self:FillBubble(r, items[i], W, p)
        r:ClearAllPoints()
        -- Platz fuer den Zipfel lassen
        if side == "RIGHT" then r:SetPoint("BOTTOMRIGHT", log, "BOTTOMRIGHT", -(6 + BUBBLE_R), y)
        elseif side == "LEFT" then r:SetPoint("BOTTOMLEFT", log, "BOTTOMLEFT", 6 + BUBBLE_R, y)
        else r:SetPoint("BOTTOM", log, "BOTTOM", 0, y) end
        r:Show()
        local nextIt = items[i - 1]
        local tight = items[i].cont and nextIt and nextIt.type == "bubble"
        y = y + h + (tight and GAP or GAP + 4)
    end
    for i = n + 1, #self.bubbles do self.bubbles[i]:Hide() end
    if self.empty then
        if #items == 0 then
            local view = UI.current or ""
            self.empty:SetText(view:sub(1, 2) == "w:" and T("Noch keine Nachrichten – schreib unten los.") or T("Noch keine Nachrichten."))
            self.empty:Show()
        else
            self.empty:Hide()
        end
    end
    if self.down then
        if self.scroll > 0 then
            self.down:Show()
            local nb = self.newBelow or 0
            self.down.count:SetText(nb > 0 and ("|cffffd100" .. nb .. "|r") or "")
        else
            self.down:Hide()
        end
    end
end

-- Verlauf neu aufbauen (scroll bleibt; Sprung aus der Suche setzt ihn)
function M:Render()
    if not self.frame then return end
    local view = UI.current or "guild"
    self.items = M.Items(view, self.newFrom[view])
    if self.jump then
        for i = #self.items, 1, -1 do
            if self.items[i].entry == self.jump then self.scroll = math.max(0, #self.items - i - 2) break end
        end
        self.highlight = self.jump
        self.jump = nil
    end
    self:LayoutLog()
end

-- ===== Kopfzeile =====
function M:RefreshHead()
    if not self.head then return end
    local view = UI.current or "guild"
    local whisper = view:sub(1, 2) == "w:"
    local c = {view = view, title = M.ViewTitle(view), whisper = whisper and view:sub(3) or nil, tab = not whisper and Chat:Tab(view) or nil}
    local r, g, b = M.AvatarColor(c)
    local p = self:Palette()
    local icon, coords = M.AvatarIcon(c)
    M.PaintAvatar(self.headGlass, p, r, g, b, icon, coords, self.headLetter, UI.First and UI.First(c.title) or "?")
    if whisper then self.headName:SetTextColor(r, g, b) else self.headName:SetTextColor(p.title[1], p.title[2], p.title[3]) end
    self.headName:SetText(c.title)
    local sub = ""
    local chatType = Chat:Target(view)
    if whisper then
        M.RequestRoster()
        local info = M.PersonInfo(c.whisper)
        if info then
            sub = info.bn and M.BNLine(info)
                or info.online and string.format("%s · %s %s · %s", info.class or "", T("Stufe"), tostring(info.level or "?"), info.zone or "")
                or M.OfflineText(info)
        else
            sub = T("Flüstern")
        end
    elseif view == "guild" and type(GetNumGuildMembers) == "function" then
        local total, online = Call(GetNumGuildMembers)
        if total and total > 0 then sub = T("%d von %d online", online or 0, total) end
    elseif view == "system" then
        sub = T("Meldungen von WoW und Addons")
    elseif not chatType then
        sub = T("nur lesen")
    else
        local tab = Chat:Tab(view)
        local kind = tab and tab.send and Chat.kindByKey[tab.send]
        if kind then sub = T("schreibt in: %s", T(kind.label)) end
    end
    if M.IsMuted(view) then sub = (sub ~= "" and (sub .. "  ·  ") or "") .. T("stumm") end
    self.headSub:SetText(sub)
    self.headMenu:SetShown(whisper and ONE.PlayerMenu ~= nil)
    if self.headHit then self.headHit:SetShown(whisper and true or false) end
    if self.headClose then self.headClose:SetShown(whisper) end
    self:UpdateInviteButton()
    local to = whisper and c.whisper or (chatType and M.SendLabel(view)) or nil
    if self.placeholder then
        self.placeholder:SetText(to and T("Nachricht an %s …", to) or T("Hier kann man nur lesen."))
    end
    if self.UpdatePlaceholder then self.UpdatePlaceholder() end
end
function M.SendLabel(view)
    local tab = Chat:Tab(view)
    local kind = tab and tab.send and Chat.kindByKey[tab.send]
    return kind and T(kind.label) or M.ViewTitle(view)
end

-- ===== Anordnen (breit / schmal) =====
function M:IsNarrow()
    local w = self.frame and self.frame:GetWidth()
    return type(w) == "number" and w < NARROW_W
end
function M:Layout()
    local f = self.frame
    if not f then return end
    local list, main = self.list, self.main
    -- Noch im Aufbau (Teile fehlen): nichts anordnen
    if not (list and main and self.back and self.head and self.headAv) then return end
    local narrow = self:IsNarrow()
    main:ClearAllPoints()
    list:ClearAllPoints()
    if narrow then
        list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -TITLE_H)
        list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        main:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TITLE_H)
        main:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
        if self.page == "chat" then list:Hide() main:Show() else list:Show() main:Hide() end
    else
        list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -TITLE_H)
        list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
        list:SetWidth(LIST_W)
        main:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0)
        main:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
        list:Show() main:Show()
    end
    self.back:SetShown(narrow)
    self.headAv:ClearAllPoints()
    self.headAv:SetPoint("LEFT", self.head, "LEFT", narrow and 26 or 4, 0)
    if self.sendButton then self.sendButton:SetWidth(narrow and 54 or 62) end
    if self.settingsPanel and self.settingsPanel:IsShown() and UI.LayoutSettingsPanel then UI:LayoutSettingsPanel() end
    self:LayoutList()
    self:LayoutLog()
    if self.picker and self.picker:IsShown() then self:FillPicker() end
    self:UpdateInviteButton()
end

-- ===== Fenster =====
function M:Paint()
    local p = self:Palette()
    if self.title then self.title:SetTextColor(p.title[1], p.title[2], p.title[3]) end
end
function M:ApplyLook()
    local f, s = self.frame, Chat:Settings()
    if not f then return end
    local G = ONE.Glass
    for _, sf in ipairs(self.surfaces or {}) do if G and G.Paint then G:Paint(sf) end end
    f:SetMovable(not s.locked)
    local idle = tonumber(s.idleAlpha) or 1
    if idle >= 1 then
        f:SetScript("OnUpdate", nil)
        f:SetAlpha(1)
    else
        f.__fadeWait = 0
        f:SetScript("OnUpdate", function(frame, elapsed) UI:FadeStep(frame, elapsed or 0) end)
    end
end
function M:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    self:LayoutList()
    self:RefreshHead()
    self:UpdateFriendsButton()
end

-- ===== Freunde (Battle.net + WoW), Nutzer 23.11.2026 =====
-- Der Freunde-Knopf zeigt die Freunde in der Liste links (Messenger-Stil), Klick oeffnet das Gespraech.
-- {name = Gespraechsname, label, bn = Konto-Nummer, online, afk, char, zone, game, classFile, level, wow}
function M.ClassFileFromName(name)
    if type(name) ~= "string" or name == "" then return nil end
    for _, t in ipairs({rawget(_G, "LOCALIZED_CLASS_NAMES_MALE"), rawget(_G, "LOCALIZED_CLASS_NAMES_FEMALE")}) do
        if type(t) == "table" then for file, n in pairs(t) do if n == name then return file end end end
    end
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[name:upper()] then return name:upper() end
end
function M.Friends()
    local out = {}
    local n = type(BNGetNumFriends) == "function" and tonumber((Call(BNGetNumFriends))) or 0
    for i = 1, n or 0 do
        local a = C_BattleNet and type(C_BattleNet.GetFriendAccountInfo) == "function" and Call(C_BattleNet.GetFriendAccountInfo, i)
        if type(a) == "table" and type(a.battleTag) == "string" then
            local g = type(a.gameAccountInfo) == "table" and a.gameAccountInfo or {}
            local char = type(g.characterName) == "string" and g.characterName ~= "" and g.characterName or nil
            out[#out + 1] = {name = a.battleTag, label = a.battleTag:match("^[^#]+") or a.battleTag, bn = a.bnetAccountID,
                online = (g.isOnline or a.isOnline) and true or false, afk = (a.isAFK or a.isDND or g.isGameAFK) and true or false,
                char = char, zone = g.areaName, game = not char and (g.richPresence or g.clientProgram) or nil,
                classFile = M.ClassFileFromName(g.className), level = g.characterLevel,
                note = type(a.note) == "string" and a.note ~= "" and a.note or nil,
                gameAccount = g.gameAccountID, realm = g.realmName, wowGame = char and (g.clientProgram == nil or g.clientProgram == "WoW")}
        end
    end
    local FL = C_FriendList
    local m = FL and type(FL.GetNumFriends) == "function" and tonumber((Call(FL.GetNumFriends))) or 0
    for i = 1, m or 0 do
        local w = type(FL.GetFriendInfoByIndex) == "function" and Call(FL.GetFriendInfoByIndex, i)
        if type(w) == "table" and type(w.name) == "string" and w.name ~= "" then
            out[#out + 1] = {name = w.name, label = Short(w.name), online = w.connected and true or false,
                afk = (w.afk or w.dnd) and true or false, zone = w.area, level = w.level,
                classFile = M.ClassFileFromName(w.className), wow = true,
                note = type(w.notes) == "string" and w.notes ~= "" and w.notes or nil}
        end
    end
    table.sort(out, function(x, y)
        if x.online ~= y.online then return x.online end
        if (x.wow or false) ~= (y.wow or false) then return not x.wow end
        return x.label:lower() < y.label:lower()
    end)
    return out
end
function M.FriendsOnline()
    local n = 0
    for _, fr in ipairs(M.Friends()) do if fr.online then n = n + 1 end end
    return n
end
-- Zweite Zeile: "Testheld (17) · Brachland", "Im Menü", "abwesend · …", "offline"
function M.FriendLine(fr)
    if not fr.online then return T("offline") end
    local parts = {}
    if fr.char then parts[#parts + 1] = fr.char .. ((tonumber(fr.level) or 0) > 0 and (" (" .. fr.level .. ")") or "")
    elseif fr.wow and (tonumber(fr.level) or 0) > 0 then parts[#parts + 1] = T("Stufe %d", fr.level) end
    if type(fr.zone) == "string" and fr.zone ~= "" then parts[#parts + 1] = fr.zone end
    if #parts == 0 and type(fr.game) == "string" and fr.game ~= "" then parts[#parts + 1] = fr.game end
    local line = (table.concat(parts, " · "):gsub("|", ""))
    if fr.afk then line = "|cffffd100" .. T("abwesend") .. "|r" .. (line ~= "" and (" · " .. line) or "") end
    return line
end
function M:UpdateFriendsButton()
    local b = self.friendsButton
    if not b then return end
    local n = M.FriendsOnline()
    b.count:SetText(n > 0 and tostring(n) or "")
    local req = #M.FriendRequests()
    if b.req then b.req:SetText(req > 0 and ("|cffff4040" .. req .. "|r") or "") end
    if b.icon then
        local g = self:Palette().glow
        if self.friendsMode then b.icon:SetVertexColor(g[1], g[2], g[3]) else b.icon:SetVertexColor(1, 1, 1) end
    end
end
function M:ToggleFriends(on)
    if on == nil then on = not self.friendsMode end
    self.friendsMode = on and true or false
    self.listScroll = 0
    if self.friendsMode then M.page = "list" if self.Layout then self:Layout() end end
    self:LayoutList()
    self:UpdateFriendsButton()
end
function M:FriendRows(q)
    local rows = {{label = T("Zurück zu den Gesprächen"), click = function() M:ToggleFriends(false) end}}
    local req = M.FriendRequests()
    if #req > 0 then
        rows[#rows + 1] = {label = T("ANFRAGEN (%d)", #req), gap = true}
        for _, r in ipairs(req) do rows[#rows + 1] = {request = r} end
    end
    local on, off = {}, {}
    for _, fr in ipairs(M.Friends()) do
        local hay = (fr.label .. " " .. (fr.char or "") .. " " .. (type(fr.zone) == "string" and fr.zone or "")):lower()
        if q == "" or hay:find(q, 1, true) then
            if fr.online then on[#on + 1] = fr else off[#off + 1] = fr end
        end
    end
    rows[#rows + 1] = {label = T("ONLINE (%d)", #on), gap = true}
    for _, fr in ipairs(on) do rows[#rows + 1] = {friend = fr} end
    if #on == 0 then rows[#rows + 1] = {label = T("Gerade ist niemand online")} end
    if #off > 0 then
        rows[#rows + 1] = {label = T("OFFLINE (%d)", #off), gap = true}
        for _, fr in ipairs(off) do rows[#rows + 1] = {friend = fr} end
    end
    rows[#rows + 1] = {label = T("Freund hinzufügen …"), gap = true, click = function() M:AskAddFriend() end}
    rows[#rows + 1] = {label = T("Freundesliste von WoW öffnen …"), click = function()
        if InCombatLockdown and InCombatLockdown() then ONE:Print(T("Im Kampf nicht möglich.")) return end
        if type(ToggleFriendsFrame) == "function" then pcall(ToggleFriendsFrame) end
    end}
    return rows
end
function M:FillFriendRow(b, fr, p)
    local cr, cg, cb
    if fr.classFile then cr, cg, cb = ClassRGB(fr.classFile)
    elseif not fr.wow then cr, cg, cb = .30, .70, 1
    else cr, cg, cb = .75, .55, .85 end
    local l, r, t, bt = M.ClassCoords(fr.classFile)
    local icon, coords
    if l then icon, coords = CLASS_ATLAS, {l, r, t, bt} elseif not fr.wow then icon = M.KindIcon("bnet") end
    M.PaintAvatar(b.glass, p, cr, cg, cb, icon, coords, b.letter, UI.First and UI.First(fr.label) or fr.label:sub(1, 1))
    b.online:SetShown(fr.online)
    b.onlineRim:SetShown(fr.online)
    if fr.afk then b.online:SetVertexColor(1, .82, .2) else b.online:SetVertexColor(.30, .90, .35) end
    local nameColor = fr.wow and Hex({cr, cg, cb}) or "|cff4cb3ff"
    b.name:SetText(nameColor .. fr.label .. "|r")
    b.name:Show()
    local line = M.FriendLine(fr)
    if fr.note then line = line .. "  |cff9d8fc0" .. (fr.note:gsub("|", "")) .. "|r" end
    b.preview:SetText(line)
    b.preview:Show()
    b.time:SetText(fr.wow and "WoW" or "Battle.net")
    b.time:Show()
    b.sel:Hide()
    b.badge:Hide()
    b.count:Hide()
    b:SetAlpha(fr.online and 1 or .55)
    b:SetScript("OnClick", function(btn, button)
        if button == "RightButton" then M:FriendMenu(btn, fr) return end
        M.OpenFriend(fr)
    end)
    Tip(b, function()
        local out = {{fr.name, cr, cg, cb}, {M.FriendLine(fr)}}
        if fr.note then out[#out + 1] = {T("Notiz: %s", (fr.note:gsub("|", ""))), .75, .7, .95} end
        out[#out + 1] = {T("Klick: Gespräch hier öffnen"), .6, .6, .6}
        out[#out + 1] = {T("Rechtsklick: Einladen, Notiz, Entfernen …"), .6, .6, .6}
        return out
    end)
end
-- Freundschaftsanfragen (Battle.net): {id, name}
function M.FriendRequests()
    local out = {}
    local n = type(BNGetNumFriendInvites) == "function" and tonumber((Call(BNGetNumFriendInvites))) or 0
    for i = 1, n or 0 do
        local id, name = Call(BNGetFriendInviteInfo, i)
        if id then out[#out + 1] = {id = id, name = type(name) == "string" and name ~= "" and name or "?"} end
    end
    return out
end
function M.AnswerRequest(r, accept)
    local fn = accept and rawget(_G, "BNAcceptFriendInvite") or rawget(_G, "BNDeclineFriendInvite")
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, r.id)
    if ok then ONE:Print(accept and T("Freundschaftsanfrage angenommen.") or T("Freundschaftsanfrage abgelehnt.")) end
    if M.LayoutList then M:LayoutList() M:UpdateFriendsButton() end
    return ok
end
function M:FillRequestRow(b, r, p)
    M.PaintAvatar(b.glass, p, 1, .82, .2, M.KindIcon("bnet"), nil, b.letter, "?")
    b.online:Hide()
    b.onlineRim:Hide()
    b.name:SetText("|cffffd100" .. r.name .. "|r")
    b.name:Show()
    b.preview:SetText(T("möchte dein Freund sein – klicken"))
    b.preview:Show()
    b.time:SetText("")
    b.sel:Hide()
    b.badge:Hide()
    b.count:Hide()
    b:SetAlpha(1)
    b:SetScript("OnClick", function(btn)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(btn, function(_, root)
            if root.CreateTitle then root:CreateTitle(r.name) end
            root:CreateButton(T("Annehmen"), function() M.AnswerRequest(r, true) end)
            root:CreateButton(T("Ablehnen"), function() M.AnswerRequest(r, false) end)
        end)
    end)
    Tip(b, function() return {{r.name, 1, .82, .2}, {T("Freundschaftsanfrage über Battle.net")}, {T("Klick: Annehmen oder Ablehnen"), .6, .6, .6}} end)
end

-- Kleines Eingabefeld ueber der Suche (wie "Fluestern an …"): Hinweis, Starttext, Enter -> fn(text)
function M:AskText(hint, initial, fn)
    self:Build()
    if not self.promptBox then
        local ok, b = pcall(CreateFrame, "EditBox", nil, self.list, "InputBoxTemplate")
        if not ok or not b then b = CreateFrame("EditBox", nil, self.list) end
        b:SetPoint("TOPLEFT", self.searchBox, "TOPLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", self.searchBox, "BOTTOMRIGHT", 0, 0)
        if b.SetFrameLevel and self.list.GetFrameLevel then b:SetFrameLevel((self.list:GetFrameLevel() or 1) + 30) end
        b:SetAutoFocus(true)
        b:SetMaxLetters(120)
        b.hint = Text(b, "GameFontDisableSmall")
        b.hint:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -2)
        b:SetScript("OnEnterPressed", function(box)
            local text = (box:GetText() or ""):match("^%s*(.-)%s*$")
            local done = box.fn
            box.fn = nil
            box:SetText("") box:Hide()
            if done then done(text) end
        end)
        b:SetScript("OnEscapePressed", function(box) box.fn = nil box:SetText("") box:Hide() end)
        b:SetScript("OnEditFocusLost", function(box) box.fn = nil box:Hide() end)
        self.promptBox = b
    end
    local b = self.promptBox
    b.hint:SetText(hint)
    b.fn = fn
    b:Show()
    b:SetText(initial or "")
    b:SetFocus()
end
-- Freund hinzufuegen: BattleTag (Name#1234) -> Battle.net-Anfrage, sonst WoW-Freund (Charaktername)
function M.AddFriend(text)
    text = tostring(text or ""):match("^%s*(.-)%s*$")
    if text == "" then return false end
    if text:find("#", 1, true) then
        local fn = rawget(_G, "BNSendFriendInvite")
        if type(fn) ~= "function" then ONE:Print(T("Battle.net-Anfragen gehen in diesem Client nicht.")) return false end
        local ok = pcall(fn, text)
        if ok then ONE:Print(T("Freundschaftsanfrage an %s geschickt.", text)) end
        return ok
    end
    if not (C_FriendList and type(C_FriendList.AddFriend) == "function") then return false end
    local ok = pcall(C_FriendList.AddFriend, text)
    if ok then ONE:Print(T("%s wird als Freund hinzugefügt.", text)) end
    return ok
end
function M:AskAddFriend()
    self:AskText(T("Name oder BattleTag (Name#1234), Enter"), "", function(text) M.AddFriend(text) end)
end
-- Notiz setzen (leer = loeschen)
function M.SetFriendNote(fr, note)
    note = tostring(note or "")
    if fr.wow then
        local FL = C_FriendList
        if not (FL and type(FL.SetFriendNotes) == "function") then return false end
        return pcall(FL.SetFriendNotes, fr.name, note) == true
    end
    local fn = rawget(_G, "BNSetFriendNote")
    if type(fn) ~= "function" or not fr.bn then return false end
    return pcall(fn, fr.bn, note) == true
end
function M.RemoveFriend(fr)
    local ok
    if fr.wow then
        ok = C_FriendList and type(C_FriendList.RemoveFriend) == "function" and pcall(C_FriendList.RemoveFriend, fr.name)
    else
        local fn = rawget(_G, "BNRemoveFriend")
        ok = type(fn) == "function" and fr.bn and pcall(fn, fr.bn)
    end
    if ok then ONE:Print(T("%s ist nicht mehr in deiner Freundesliste.", fr.label)) end
    return ok and true or false
end
-- In die Gruppe: WoW-Freund per Name, Battle.net-Freund ueber sein Spielkonto (nur wenn er WoW spielt)
function M.CanInviteFriend(fr)
    if not fr.online then return false end
    if fr.wow then return true end
    return fr.wowGame and (fr.gameAccount ~= nil or fr.char ~= nil) or false
end
function M.InviteFriend(fr)
    if not fr.wow and fr.gameAccount and type(rawget(_G, "BNInviteFriend")) == "function" then
        return pcall(BNInviteFriend, fr.gameAccount) == true
    end
    local name = fr.wow and fr.name or (fr.char and (fr.realm and fr.realm ~= "" and (fr.char .. "-" .. fr.realm:gsub("%s", "")) or fr.char))
    if not name then return false end
    if ONE.PlayerMenu and ONE.PlayerMenu.actions then
        for _, a in ipairs(ONE.PlayerMenu.actions) do
            if a.id == "invite" and a.run then return pcall(a.run, name) == true end
        end
    end
    return false
end
-- Rechtsklick auf einen Freund
function M:FriendMenu(owner, fr)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if root.CreateTitle then root:CreateTitle(fr.label) end
        root:CreateButton(T("Anschreiben"), function() M.OpenFriend(fr) end)
        if M.CanInviteFriend(fr) then root:CreateButton(T("In Gruppe einladen"), function() M.InviteFriend(fr) end) end
        root:CreateButton(fr.note and T("Notiz ändern …") or T("Notiz schreiben …"), function()
            M:AskText(T("Notiz zu %s, Enter (leer = löschen)", fr.label), fr.note or "", function(text)
                M.SetFriendNote(fr, text)
                M:LayoutList()
            end)
        end)
        if fr.wow and ONE.PlayerMenu then
            root:CreateButton(T("Namens-Menü …"), function() ONE.PlayerMenu:Open(owner, fr.name) end)
        end
        if root.CreateDivider then root:CreateDivider() end
        -- Sicherheitsfrage als zweites Menue
        root:CreateButton(T("Freund entfernen …"), function()
            MenuUtil.CreateContextMenu(owner, function(_, ask)
                if ask.CreateTitle then ask:CreateTitle(T("%s wirklich entfernen?", fr.label)) end
                ask:CreateButton(T("Ja, entfernen"), function() M.RemoveFriend(fr) M:LayoutList() end)
                ask:CreateButton(T("Abbrechen"), function() end)
            end)
        end)
    end)
end
-- Gespraech mit einem Freund hier oeffnen (Freunde-Ansicht schliesst sich)
function M.OpenFriend(fr)
    if not fr then return end
    if fr.bn then Chat.bnIds[fr.name] = fr.bn end
    M.friendsMode = false
    M.page = "chat"
    UI:Show(Chat:OpenWhisper(fr.name))
    M:UpdateFriendsButton()
    if M.input then M.input:SetFocus() end
end

-- Gespraech zeigen (und Fenster oeffnen). Entwurf des alten Gespraechs merken, "neue Nachrichten" setzen.
-- Gespraech wechseln (Entwurf merken), ohne das Fenster zu zeigen – auch fuer die Randleiste
function M:SwitchView(view)
    self:Build()
    local old = UI.current
    if view and view ~= old then
        self:CancelReply()
        M.histPos, M.histDraft = nil, nil
        if chat.SlashList then chat.SlashList:Hide() end
        Chat.drafts = Chat.drafts or {}
        if self.input and old then
            local t = self.input:GetText() or ""
            Chat.drafts[old] = t ~= "" and t or nil
        end
        if self.input then self.input:SetText(Chat.drafts[view] or "") end
        UI.current = view
        self.scroll, self.newBelow, self.highlight = 0, 0, nil
        self.newFrom[old or ""] = nil
        if self.picker then self.picker:Hide() end
    end
    if not (Chat:Tab(UI.current) or (UI.current or ""):sub(1, 2) == "w:") then UI.current = "guild" end
    if chat.Rail and chat.Rail.RememberView then chat.Rail:RememberView() end
end
function M:ShowView(view)
    if chat.Hider and chat.Hider.OnChatShown then chat.Hider:OnChatShown() end
    self:Build()
    if chat.Rail and chat.Rail.OnWindowShown then chat.Rail:OnWindowShown() end
    self:SwitchView(view)
    if view then self.page = "chat" end
    local cur = UI.current
    local n = Chat.unread[cur] or 0
    if n > 0 then self.newFrom[cur] = #Chat:Buffer(cur) - n + 1 end
    Chat.current, Chat.visible = cur, true
    Chat:MarkRead(cur)
    self.frame:Show()
    self:ApplyLook()
    self:Layout()
    self:Render()
    self:Refresh()
    if self.UpdatePlaceholder then self.UpdatePlaceholder() end
    if chat.Launcher and chat.Launcher.Update then chat.Launcher:Update() end
    if ONE.MinimapButton and ONE.MinimapButton.ClearAlert then pcall(ONE.MinimapButton.ClearAlert, ONE.MinimapButton, "chat") end
    if chat.Rail and chat.Rail.AfterWindowShown then chat.Rail:AfterWindowShown() end
end
-- now = sofort (Randleiste: erst zuklappen, dann kommt dieser Aufruf mit now)
function M:Hide(now)
    if not now and chat.Rail and chat.Rail.CloseWindow and chat.Rail:CloseWindow() then return end
    if self.frame then self.frame:Hide() end
    if chat.SlashList then chat.SlashList:Hide() end
    if chat.ItemList then chat.ItemList:Hide() end
    Chat.visible = false
    self:UpdateInviteButton()
    if chat.Launcher and chat.Launcher.Update then chat.Launcher:Update() end
    if chat.Rail and chat.Rail.OnWindowHidden then chat.Rail:OnWindowHidden() end
    if chat.Rail and chat.Rail.Update then chat.Rail:Update() end
end

-- Neue Nachricht (update = Haken/nicht zugestellt an einer schon gezeigten Nachricht)
function M:OnMessage(entry, views, update)
    local shown = self.frame and self.frame:IsShown()
    if shown then
        if Chat:Settings().wakeOnMessage ~= false then UI:WakeUp() end
        local here = false
        for _, v in ipairs(views or {}) do if v == UI.current then here = true end end
        -- im schmalen Fenster auf der Liste: Gespraech gilt nicht als gelesen
        if here and self:IsNarrow() and self.page ~= "chat" then
            here = false
            if not update and not entry.inform then Chat.unread[UI.current] = (Chat.unread[UI.current] or 0) + 1 end
        end
        if here then
            Chat:MarkRead(UI.current)
            if not update and (self.scroll or 0) > 0 then
                self.newBelow = (self.newBelow or 0) + 1
                -- Blick bleibt, wo er ist
                self.scroll = self.scroll + 1
            end
            self:Render()
        end
        self:Refresh()
    end
    if update then return end
    -- Randleiste: Blase, solange das Fenster zu ist
    if not shown and chat.Rail and chat.Rail.OnMessage then chat.Rail:OnMessage(entry, views) end
    local sound = Chat:SoundFor(entry, views)
    if sound then Chat:PlaySound(sound) end
    if entry.kind == "whisper" and not entry.inform then
        local s = Chat:Settings()
        if s.blink and type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
        if not shown and ONE.MinimapButton and ONE.MinimapButton.SetAlert then
            pcall(ONE.MinimapButton.SetAlert, ONE.MinimapButton, "chat", T("Neue Flüsternachricht von %s", Short(entry.author)), "chat")
        end
    end
end

-- Neues Fluestergespraech: Name eingeben
function M:AskWhisper()
    self:Build()
    if not self.askBox then
        local ok, b = pcall(CreateFrame, "EditBox", nil, self.list, "InputBoxTemplate")
        if not ok or not b then b = CreateFrame("EditBox", nil, self.list) end
        b:SetPoint("TOPLEFT", self.searchBox, "TOPLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", self.searchBox, "BOTTOMRIGHT", 0, 0)
        if b.SetFrameLevel and self.list.GetFrameLevel then b:SetFrameLevel((self.list:GetFrameLevel() or 1) + 30) end
        b:SetAutoFocus(true)
        b.hint = Text(b, "GameFontDisableSmall")
        b.hint:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -2)
        b.hint:SetText(T("Name eingeben, Enter"))
        b:SetScript("OnEnterPressed", function(box)
            local name = (box:GetText() or ""):match("^%s*(.-)%s*$")
            box:SetText("") box:Hide()
            if name ~= "" then M.page = "chat" M:ShowView(Chat:OpenWhisper(name)) if M.input then M.input:SetFocus() end end
        end)
        b:SetScript("OnEscapePressed", function(box) box:SetText("") box:Hide() end)
        b:SetScript("OnEditFocusLost", function(box) box:Hide() end)
        self.askBox = b
    end
    self.askBox:Show()
    self.askBox:SetFocus()
end
