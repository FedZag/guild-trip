local _, ONE = ...

-- Namens-Menue (Nutzer-Wunsch 15.11.2026): Klick auf einen Charakternamen, egal wo,
-- oeffnet ein kleines Menue mit allem, was man mit dieser Person tun kann.
-- Grundeintraege hier (Fluestern, Einladen, Anstupsen, Freund); Module melden eigene
-- an (z. B. ONE_Guild "Navi zu …", wenn die Person ihre Position teilt):
--   ONE.PlayerMenu:Register{id, label, order, available = function(name, ctx) end, run = function(name, ctx) end}
-- Buch-Aussehen: Pergament-Menue (Book:OpenMenu), sonst Blizzards Kontextmenue (MenuUtil),
-- ohne beides ebenfalls das Pergament-Menue.
local PlayerMenu = {actions = {}}
ONE.PlayerMenu = PlayerMenu

local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "" end
PlayerMenu.Short = Short

function PlayerMenu.IsMe(name)
    local me = Call(UnitName, "player")
    return me ~= nil and Short(name) == me
end

function PlayerMenu:Register(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or type(def.run) ~= "function" then return false end
    for i, a in ipairs(self.actions) do
        if a.id == def.id then self.actions[i] = def return true end
    end
    self.actions[#self.actions + 1] = def
    table.sort(self.actions, function(a, b) return (a.order or 50) < (b.order or 50) end)
    return true
end

-- Eintraege fuer diese Person (nur, was gerade moeglich ist)
function PlayerMenu:Items(name, ctx)
    local out = {}
    if type(name) ~= "string" or name == "" or self.IsMe(name) then return out end
    for _, a in ipairs(self.actions) do
        local ok, can = true, true
        if a.available then ok, can = pcall(a.available, name, ctx) end
        if ok and can then
            local label = type(a.label) == "function" and a.label(name, ctx) or T(a.label)
            out[#out + 1] = {id = a.id, text = label, tooltip = a.tooltip and T(a.tooltip) or nil, action = a}
        end
    end
    return out
end

function PlayerMenu:Run(item, name, ctx)
    if not item then return false end
    local ok = pcall(item.action.run, name, ctx)
    if ONE.UI and ONE.UI.Refresh then pcall(ONE.UI.Refresh, ONE.UI) end
    return ok
end

-- Menue an owner (Zeile oder Text) oeffnen. ctx: freie Zusatzinfos fuer die Eintraege.
function PlayerMenu:Open(owner, name, ctx)
    local items = self:Items(name, ctx)
    if #items == 0 or not owner then return false end
    local book = ONE.Book and ONE.Book.IsActive and ONE.Book:IsActive() and ONE.Book.OpenMenu
    if not book and type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
            if root.CreateTitle then root:CreateTitle(Short(name)) end
            for _, it in ipairs(items) do
                local button = root:CreateButton(it.text, function() PlayerMenu:Run(it, name, ctx) end)
                if it.tooltip and button and type(button.SetTooltip) == "function" then
                    pcall(button.SetTooltip, button, function(tooltip)
                        if tooltip.SetText then tooltip:SetText(it.text, 1, .82, 0) end
                        if tooltip.AddLine then tooltip:AddLine(it.tooltip, 1, 1, 1, true) end
                    end)
                end
            end
        end)
        if ok then return true end
    end
    if ONE.Book and ONE.Book.OpenMenu then
        local list = {}
        for i, it in ipairs(items) do list[i] = {value = i, text = it.text, tooltip = it.tooltip} end
        ONE.Book:OpenMenu(owner, list, nil, function(i) PlayerMenu:Run(items[i], name, ctx) end)
        return true
    end
    return false
end

-- ===== Grundeintraege =====
-- ctx.online == false (Mitgliederliste, offline): nur, was auch offline geht
local function Online(_, ctx) return not (type(ctx) == "table" and ctx.online == false) end
PlayerMenu:Register({id = "whisper", order = 10, label = "Flüstern", available = Online,
    run = function(name)
        if type(ChatFrame_SendTell) == "function" then return ChatFrame_SendTell(name) end
        if type(ChatFrame_OpenChat) == "function" then return ChatFrame_OpenChat("/w " .. name .. " ") end
    end})
PlayerMenu:Register({id = "invite", order = 20, label = "In Gruppe einladen",
    available = function(name, ctx)
        if not Online(name, ctx) then return false end
        return (C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function") or type(InviteUnit) == "function"
    end,
    run = function(name)
        if C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then return C_PartyInfo.InviteUnit(name) end
        return InviteUnit(name)
    end})
PlayerMenu:Register({id = "poke", order = 30, label = "Anstupsen",
    tooltip = "Das Spiel-Emote /anstupsen – wirkt nur, wenn ihr nah beieinander seid.",
    available = function(name, ctx) return Online(name, ctx) and type(DoEmote) == "function" end,
    run = function(name)
        -- ist die Person dein Ziel, sicher ueber "target"; sonst ueber den Namen (Gruppe/Naehe)
        local target = Call(UnitName, "target")
        return DoEmote("POKE", target and target == Short(name) and "target" or name)
    end})
PlayerMenu:Register({id = "friend", order = 40, label = "Als Freund hinzufügen",
    available = function(name)
        if not (C_FriendList and type(C_FriendList.AddFriend) == "function") then return false end
        -- schon Freund? GetFriendInfo liefert dann einen Eintrag
        local info = type(C_FriendList.GetFriendInfo) == "function" and Call(C_FriendList.GetFriendInfo, Short(name))
        return info == nil
    end,
    run = function(name) return C_FriendList.AddFriend(Short(name)) end})
-- Blizzard erwartet in jedem Chat: Ignorieren und Melden (15.11.2026, Guild-Trip-Chat)
PlayerMenu:Register({id = "ignore", order = 45, label = "Ignorieren",
    tooltip = "Du siehst keine Nachrichten mehr von dieser Person (Blizzards Ignorierliste).",
    available = function(name)
        if not (C_FriendList and type(C_FriendList.AddIgnore) == "function") then return false end
        return not (type(C_FriendList.IsIgnored) == "function" and Call(C_FriendList.IsIgnored, Short(name)))
    end,
    run = function(name) return C_FriendList.AddIgnore(Short(name)) end})
-- Melden: Blizzards Meldefenster fuer genau diese Chatzeile (nur, wo die Zeile bekannt ist)
PlayerMenu:Register({id = "report", order = 50, label = "Melden",
    tooltip = "Öffnet Blizzards Meldefenster für diese Nachricht.",
    available = function(_, ctx)
        return type(ctx) == "table" and type(ctx.lineID) == "number" and ctx.lineID > 0
            and type(ReportFrame) == "table" and type(ReportInfo) == "table" and type(PlayerLocation) == "table"
    end,
    run = function(name, ctx)
        local info = ReportInfo:CreateReportInfoFromType(Enum.ReportType.Chat)
        local location = PlayerLocation:CreateFromChatLineID(ctx.lineID)
        ReportFrame:InitiateReport(info, Short(name), location)
    end})
