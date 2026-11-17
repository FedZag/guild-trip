-- Project ONE Guild: opt-in, guild-only, short-lived position sharing.
-- No position history is saved. Never use custom channels or a web service.
local _, guild = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Presence = { peers={}, prefix="ONEGEO1", timeout=70, stats={sent=0, failed=0, received=0} }
guild.Presence = Presence

local function Clock()
    return type(GetTime) == "function" and GetTime() or 0
end
local function ValidNumber(v)
    return type(v)=="number" and v==v and v>=0 and v<=1
end
local function CurrentName()
    if type(UnitFullName)=="function" then
        local name, realm=UnitFullName("player")
        if name then return realm and realm~="" and (name.."-"..realm) or name end
    end
    return type(UnitName)=="function" and UnitName("player") or nil
end
-- Location consent must NOT leak across alts or to a newly joined guild.
local function ConsentKey()
    local player=CurrentName()
    local guildName=type(GetGuildInfo)=="function" and GetGuildInfo("player") or nil
    if not (player and guildName and guildName~="") then return nil end
    return guildName.."|"..player
end
function Presence:IsSharing()
    local key=ConsentKey()
    local db=ONE.db and ONE.db.guild
    return key~=nil and db and type(db.locationConsent)=="table"
        and db.locationConsent[key]==true or false
end
function Presence:SetSharing(enabled)
    if not ONE.db or not ONE.db.guild then return end
    local key=ConsentKey()
    if not key then
        ONE:Print(T("Standortfreigabe nur mit aktivem Gildencharakter möglich."))
        return
    end
    local old=self:IsSharing()
    ONE.db.guild.locationConsent=ONE.db.guild.locationConsent or {}
    ONE.db.guild.locationConsent[key]=enabled and true or false
    if old and not enabled then
        self:Send("OFF")
        self.lastSubZone=nil
    elseif enabled and not old then
        self:Broadcast(true)
    end
    if guild.Pins then guild.Pins:Refresh() end
end
function Presence:Send(message)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage)=="function") then return false end
    if not (IsInGuild and IsInGuild()) then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, message, "GUILD")
    local accepted=ok and (result == nil or result == 0 or result == true)
    self.stats[accepted and "sent" or "failed"] = self.stats[accepted and "sent" or "failed"] + 1
    self.stats.lastSendCode = result
    -- Result 0 means queued, NOT received by another client.
    return accepted
end
function Presence:Location()
    if not (C_Map and type(C_Map.GetBestMapForUnit)=="function"
        and type(C_Map.GetPlayerMapPosition)=="function") then return end
    if type(IsInInstance)=="function" and IsInInstance() then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or type(mapID)~="number" or mapID<1 then return end
    local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okPos or not pos or type(pos.GetXY)~="function" then return end
    local okXY,x,y = pcall(pos.GetXY, pos)
    if not okXY or not ValidNumber(x) or not ValidNumber(y) then return end
    return mapID, math.floor(x*10000+0.5), math.floor(y*10000+0.5)
end
-- A separate optional location label keeps the original ONEGEO1 P:... message
-- backwards compatible with previous testers. It is not a full zone database.
local function CurrentSubZone()
    if type(GetSubZoneText)~="function" then return "" end
    local ok,name=pcall(GetSubZoneText)
    if not ok or type(name)~="string" then return "" end
    name=name:gsub("[:|\r\n]"," ")
    if #name>65 then return "" end -- keep one addon message compact
    return name
end

function Presence:Broadcast(force)
    if not self:IsSharing() or not (IsInGuild and IsInGuild()) then return end
    local map,x,y = self:Location()
    if not map then return end
    local stamp=Clock()
    local key=map..":"..x..":"..y
    if not force and key==self.lastKey and stamp-(self.lastSend or 0)<15 then return end
    local sent=self:Send("P:"..map..":"..x..":"..y)
    if sent then
        self.lastKey,self.lastSend=key,stamp
        local subZone=CurrentSubZone()
        if force or subZone~=self.lastSubZone
            or stamp-(self.lastSubZoneSend or 0)>=45 then
            if self:Send("L:"..subZone) then
                self.lastSubZone,self.lastSubZoneSend=subZone,stamp
            end
        end
    end
end
-- Eigene Nachrichten erkennen: Der Absender kommt als "Name-Realm", der eigene
-- Name ohne Realm. Vorher fiel der Vergleich durch -> eigener Punkt lag ueber
-- dem eigenen WoW-Pfeil (Testerhinweis 12.11.2026).
function Presence:IsMe(sender)
    if type(sender)~="string" then return false end
    local me=CurrentName()
    if not me then return false end
    local short=function(s) return ((s:match("^[^-]+")) or s):lower() end
    if sender:lower()==me:lower() then return true end
    local myRealm=me:match("%-(.+)$") or (type(GetNormalizedRealmName)=="function" and GetNormalizedRealmName()) or nil
    local senderRealm=sender:match("%-(.+)$")
    if short(sender)~=short(me) then return false end
    return not myRealm or not senderRealm or myRealm:gsub("%s",""):lower()==senderRealm:gsub("%s",""):lower()
end
function Presence:Receive(prefix, message, channel, sender)
    if prefix~=self.prefix or channel~="GUILD" or type(sender)~="string" then return end
    if self:IsMe(sender) or type(message)~="string" or #message>100 then return end
    self.stats.received=self.stats.received+1
    self.stats.lastSender=sender
    if message=="OFF" then
        self.peers[sender]=nil
    elseif message:sub(1,2)=="L:" then
        -- Never create or extend a live position from a location-label packet.
        local peer=self.peers[sender]
        if not peer then return end
        local location=message:sub(3)
        if #location>65 or location:find("[|:\r\n]") then return end
        peer.subZone=location~="" and location or nil
        peer.subZoneSeen=Clock()
    else
        local map,x,y=message:match("^P:(%d+):(%d+):(%d+)$")
        map,x,y=tonumber(map),tonumber(x),tonumber(y)
        if not map or map<1 or map>100000 or not x or not y or x>10000 or y>10000 then return end
        local old=self.peers[sender]
        local sameMap=old and old.mapID==map
        self.peers[sender]={mapID=map,x=x/10000,y=y/10000,seen=Clock(),name=sender,
            subZone=sameMap and old.subZone or nil,
            subZoneSeen=sameMap and old.subZoneSeen or nil}
    end
    if guild.Pins then guild.Pins:Refresh() end
end
function Presence:ActivePeers()
    local result={}
    local stamp=Clock()
    for name, peer in pairs(self.peers) do
        if stamp-peer.seen>self.timeout or peer.seen>stamp then
            self.peers[name]=nil
        else
            result[#result+1]=peer
        end
    end
    return result
end
function Presence:Initialize()
    if not (C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix)=="function") then
        ONE:Print(T("Gilden-Positionsaustausch: Addonkanal nicht verfügbar."))
        return
    end
    local ok,registered=pcall(C_ChatInfo.RegisterAddonMessagePrefix,self.prefix)
    if not ok or registered==false then
        ONE:Print(T("Gilden-Positionsaustausch: Kanalregistrierung fehlgeschlagen."))
        return
    end
    local events=CreateFrame("Frame")
    events:RegisterEvent("CHAT_MSG_ADDON")
    events:RegisterEvent("PLAYER_GUILD_UPDATE")
    events:SetScript("OnEvent", function(_, event, ...)
        if event=="CHAT_MSG_ADDON" then
            self:Receive(...)
        else
            -- Avoid showing coordinates belonging to a previous guild.
            self.peers={}
            self.lastKey=nil
            self.lastSubZone=nil
            if guild.Pins then guild.Pins:Refresh() end
        end
    end)
    if C_Timer and type(C_Timer.NewTicker)=="function" then
        C_Timer.NewTicker(5, function() self:Broadcast(false); self:ActivePeers() end)
    end
end
