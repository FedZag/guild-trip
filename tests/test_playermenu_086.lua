-- Offline-Test: Namens-Menue (ONE.PlayerMenu) – Eintraege, offline, eigene Person, Menue-Arten, Aktionen.
local root = arg[1] or "src"
local did = {}
UnitName = function() return "Hordi" end
ChatFrame_SendTell = function(name) did.whisper = name end
C_PartyInfo = {InviteUnit = function(name) did.invite = name end}
DoEmote = function(token, name) did.emote = {token, name} end
local friends = {}
C_FriendList = {AddFriend = function(name) did.friend = name friends[name] = true end,
    GetFriendInfo = function(name) return friends[name] and {name = name} or nil end}
local ONE = {}
assert(loadfile(root .. "/ONE_Core/PlayerMenu.lua"))("ONE_Core", ONE)
local PM = ONE.PlayerMenu

local function Ids(items) local t = {} for i, it in ipairs(items) do t[i] = it.id end return table.concat(t, ",") end

-- 1) Grundeintraege in fester Reihenfolge, nie fuer sich selbst
assert(Ids(PM:Items("Thrall-Realm")) == "whisper,invite,poke,friend", Ids(PM:Items("Thrall-Realm")))
assert(#PM:Items("Hordi") == 0 and #PM:Items("Hordi-Forever") == 0 and #PM:Items("") == 0)
-- 2) offline nur, was offline geht
assert(Ids(PM:Items("Thrall", {online = false})) == "friend")
-- 3) Modul-Eintrag (z. B. Navi) mit Bedingung und Text-Funktion, sortiert nach order
local sharing = {Thrall = true}
PM:Register({id = "navi", order = 5, label = function(name) return "Navi zu " .. name end,
    available = function(name) return sharing[name] end, run = function(name) did.navi = name end})
local items = PM:Items("Thrall")
assert(items[1].id == "navi" and items[1].text == "Navi zu Thrall")
assert(PM:Items("Jaina")[1].id == "whisper", "ohne geteilte Position kein Navi")
-- fehlerhafte Bedingung bricht das Menue nicht
PM:Register({id = "kaputt", order = 99, label = "x", available = function() error("boom") end, run = function() end})
assert(Ids(PM:Items("Thrall")) == "navi,whisper,invite,poke,friend")

-- 4) Blizzard-Kontextmenue: Titel + Knoepfe, Klick fuehrt aus
local built
MenuUtil = {CreateContextMenu = function(owner, gen)
    local root = {title = nil, buttons = {}}
    function root:CreateTitle(t) self.title = t end
    function root:CreateButton(t, fn) self.buttons[#self.buttons + 1] = {t, fn} return {} end
    gen(owner, root)
    built = root
end}
assert(PM:Open({}, "Thrall-Realm") and built.title == "Thrall" and #built.buttons == 4)
built.buttons[1][2]() assert(did.whisper == "Thrall-Realm")
built.buttons[2][2]() assert(did.invite == "Thrall-Realm")
built.buttons[3][2]() assert(did.emote[1] == "POKE" and did.emote[2] == "Thrall-Realm")
built.buttons[4][2]() assert(did.friend == "Thrall", "Freund ohne Realm")
assert(Ids(PM:Items("Thrall")) == "navi,whisper,invite,poke", "schon Freund -> kein Eintrag mehr")
assert(not PM:Open({}, "Hordi"), "kein Menue fuer sich selbst")

print("OK test_playermenu_086")
