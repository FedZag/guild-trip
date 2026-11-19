-- Project ONE Navigation, Stufe 1: eigener, frei verschiebbarer Richtungspfeil.
-- Standardplatz: ueber der Spielfigur (Bildschirmmitte, etwas hoeher).
-- Zeigt Luftlinie + Reisehinweis, ausdruecklich KEINE Wegfuehrung.
local _, nav = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
-- rotateEvery 0 = jedes Bild; smoothRate: wie schnell der gezeigte Winkel dem Zielwinkel folgt (je Sekunde),
-- damit der Pfeil fliessend dreht statt in Stufen zu springen (Nutzer 17.11.2026: "hakelig").
local Arrow = {active = false, rotateEvery = 0, refreshEvery = 1, staleAfter = 20, keepLost = 300, smoothRate = 14}
nav.Arrow = Arrow

local TEXTURE = "Interface\\AddOns\\ONE_Nav\\Textures\\Arrow.tga"
-- Blizzard-Navigationspfeil aus dem Spielclient (nur referenziert, nicht kopiert).
local BLIZZARD_ATLAS = "Navigation-Tracked-Arrow"
local DEFAULT_POINT = {x = 0, y = 150}
local ARROW_SIZE = 44

local function Clock() return type(GetTime) == "function" and GetTime() or 0 end
local function ShortName(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end

function Arrow:Settings()
    if not ONE.db then return {} end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    local s = type(ONE.db.nav.arrow) == "table" and ONE.db.nav.arrow or {}
    ONE.db.nav.arrow = s
    if type(s.x) ~= "number" or type(s.y) ~= "number" then s.x, s.y = DEFAULT_POINT.x, DEFAULT_POINT.y end
    return s
end

function Arrow:ApplyPosition()
    local s = self:Settings()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
end

function Arrow:SavePosition()
    local f = self.frame
    if not (f.GetCenter and UIParent.GetCenter) then return end
    local fx, fy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (fx and ux) then return end
    local scale = (f.GetEffectiveScale and f:GetEffectiveScale() or 1)
        / (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1)
    local s = self:Settings()
    s.x = math.floor((fx * scale - ux) + .5)
    s.y = math.floor((fy * scale - uy) + .5)
    self:ApplyPosition()
end

function Arrow:SetLocked(locked)
    local s = self:Settings()
    s.locked = locked and true or false
end

function Arrow.BlizzardArrowAvailable()
    if not (C_Texture and type(C_Texture.GetAtlasInfo) == "function") then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, BLIZZARD_ATLAS)
    return ok and type(info) == "table"
end

-- Stil "one" = eigener goldener Pfeil, "blizzard" = Pfeil aus dem Spielclient.
function Arrow:ApplyStyle()
    if not self.arrow then return end
    local style = self:Settings().style
    if style == "blizzard" and self.BlizzardArrowAvailable() and type(self.arrow.SetAtlas) == "function"
        and pcall(self.arrow.SetAtlas, self.arrow, BLIZZARD_ATLAS, false) then
        self.styleInUse = "blizzard"
    else
        self.arrow:SetTexture(TEXTURE)
        self.styleInUse = "one"
    end
    self.arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
end

function Arrow:ToggleStyle()
    local s = self:Settings()
    if s.style == "blizzard" then
        s.style = "one"
    elseif self.BlizzardArrowAvailable() then
        s.style = "blizzard"
    else
        ONE:Print(T("Der Blizzard-Pfeil ist in diesem Client nicht verfügbar."))
        return self.styleInUse or "one"
    end
    self:ApplyStyle()
    return self.styleInUse
end

-- Fuer das Dropdown: Stil direkt setzen ("one" oder "blizzard").
function Arrow:SetStyle(style)
    local s = self:Settings()
    if style == "blizzard" and not self.BlizzardArrowAvailable() then
        ONE:Print(T("Der Blizzard-Pfeil ist in diesem Client nicht verfügbar."))
        return self.styleInUse or "one"
    end
    s.style = style == "blizzard" and "blizzard" or "one"
    self:ApplyStyle()
    return self.styleInUse
end

function Arrow:ShowTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:SetText(T("Guild Trip Navi"))
    GameTooltip:AddLine(T("Zeigt die Richtung (Luftlinie), keine Wegführung."), 1, 1, 1, true)
    if self:Settings().locked then
        GameTooltip:AddLine(T("Rechtsklick: zum Verschieben lösen"), .7, .7, .7)
    else
        GameTooltip:AddLine(T("Linke Maustaste ziehen: verschieben"), .7, .7, .7)
        GameTooltip:AddLine(T("Rechtsklick: festsetzen"), .7, .7, .7)
    end
    GameTooltip:AddLine(T("/trip navi stil: Pfeil-Aussehen wechseln"), .7, .7, .7)
    GameTooltip:Show()
end

function Arrow:ResetPosition()
    local s = self:Settings()
    s.x, s.y = DEFAULT_POINT.x, DEFAULT_POINT.y
    if self.frame then self:ApplyPosition() end
end

-- Zeilen unter dem Pfeil: jede haengt unter der vorigen (lange Namen duerfen
-- umbrechen, ohne die Entfernung zu ueberdecken); schwarzer Rand + Schatten,
-- damit die Schrift auf hellem Boden, Schnee und Sand lesbar bleibt.
local function Text(parent, font, y, width, below, maxLines)
    local t = parent:CreateFontString(nil, "OVERLAY", font)
    if below then t:SetPoint("TOP", below, "BOTTOM", 0, -2)
    else t:SetPoint("TOP", parent, "TOP", 0, y) end
    t:SetWidth(width)
    t:SetJustifyH("CENTER")
    if t.SetWordWrap then t:SetWordWrap(true) end
    if t.SetMaxLines then t:SetMaxLines(maxLines or 2) end
    if t.GetFont and t.SetFont then
        local file, size = t:GetFont()
        if file then pcall(t.SetFont, t, file, size or 12, "OUTLINE") end
    end
    if t.SetShadowOffset then t:SetShadowOffset(1, -1) end
    if t.SetShadowColor then t:SetShadowColor(0, 0, 0, 1) end
    return t
end

function Arrow:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "ProjectONENavArrow", UIParent)
    f:SetSize(240, 108)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        if self:Settings().locked then return end
        if type(InCombatLockdown) == "function" and InCombatLockdown() then return end
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)
    f:SetScript("OnMouseUp", function(frame, button)
        if button == "RightButton" then
            self:SetLocked(not self:Settings().locked)
            if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(frame) then self:ShowTooltip(frame) end
        end
    end)
    f:SetScript("OnEnter", function(frame) self:ShowTooltip(frame) end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local arrow = f:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("TOP", f, "TOP", 0, 0)
    self.arrow = arrow
    self:ApplyStyle()
    self.title = Text(f, "GameFontNormal", -ARROW_SIZE - 4, 236, nil, 2)
    self.distance = Text(f, "GameFontHighlight", nil, 236, self.title, 1)
    self.hint = Text(f, "GameFontHighlightSmall", nil, 236, self.distance, 2)
    self.tip = Text(f, "GameFontHighlightSmall", nil, 236, self.hint, 3)
    if self.tip.SetTextColor then self.tip:SetTextColor(.85, .85, .85) end
    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPLEFT", f, "TOP", ARROW_SIZE / 2 + 6, -2)
    local cross = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cross:SetAllPoints()
    cross:SetText("×")
    close:SetScript("OnClick", function() self:Stop() end)
    self.close = close
    f:Hide()
    self.frame = f
    self.rotateElapsed, self.refreshElapsed = 0, 0
    f:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed or 0) end)
    self:ApplyPosition()
    self:SetLocked(self:Settings().locked)
end

function Arrow:Start(name)
    local guildModule = ONE.modules and ONE.modules.guild
    if not (guildModule and type(guildModule.GetPeer) == "function") then
        ONE:Print(T("Die Navi braucht das Gildenmodul."))
        return false
    end
    local peer = guildModule:GetPeer(name)
    if not peer then
        ONE:Print(T("Von %s kommt gerade keine Guild-Trip-Position (Freigabe aus oder offline).", ShortName(name)))
        return false
    end
    self:Create()
    self.probe = nil
    self.target = peer.name
    self.arrivedAt, self.peerSent = nil, nil
    self:CancelDelegate()
    self.lastPeer = peer
    self.lastPeerAt = Clock()
    self.active = true
    self.title:SetText("Zu " .. ShortName(peer.name))
    self.frame:Show()
    self:Refresh()
    self:Rotate()
    if self.RoutesOn() and not self.SPF() then ONE:Print(T("Navi zu %s gestartet – der Pfeil folgt dem Weg. Beenden: × oder /trip navi aus", ShortName(peer.name)))
    else ONE:Print(T("Navi zu %s gestartet. Richtung, keine Wegführung. Beenden: × oder /trip navi aus", ShortName(peer.name))) end
    return true
end

-- Probe ohne zweiten Spieler: fester Testpunkt in der Mitte der aktuellen Zone.
function Arrow:StartProbe()
    local mapID = nav.Travel.PlayerMapPosition()
    if not mapID then
        ONE:Print(T("Probe nicht möglich: eigene Position hier nicht verfügbar."))
        return false
    end
    self:Create()
    self.probe = {name = T("Testpunkt (Zonenmitte)"), mapID = mapID, x = .5, y = .5}
    self.target = self.probe.name
    self.active = true
    self.frame:Show()
    self:Refresh()
    self:Rotate()
    ONE:Print(T("Navi-Probe: Der Pfeil zeigt zur Mitte dieser Zone. Beenden: × oder /trip navi aus"))
    return true
end

-- Fester Zielpunkt (z. B. Questgeber aus ONE Dungeons). Kein Zeitlimit.
-- opts: service = kurzer Abstecher (Haendler, Lehrer, Flugmeister …) – danach geht es zum vorherigen Ziel weiter;
-- corpse = Leichenlauf; quiet = keine Chatmeldung
function Arrow:StartPoint(label, mapID, x, y, opts)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return false end
    self:Create()
    self:RememberForReturn(opts)
    self.probe = {name = label or T("Ziel"), mapID = mapID, x = x, y = y, service = opts and opts.service, corpse = opts and opts.corpse}
    self.arrivedAt, self.leftAfterArrival = nil, nil
    self:SetDelegated(self:Delegate(mapID, x, y, self.probe.name))
    self.target = self.probe.name
    self.active = true
    self.frame:Show()
    self:Refresh()
    self:Rotate()
    local routed = not self.delegated and self.RoutesOn()
    if not (opts and opts.quiet) then
        if self.delegated then ONE:Print(T("Navi zu %s – Wegführung über Shortest Path Forever.", self.probe.name))
        elseif routed then ONE:Print(T("Navi zu %s – der Pfeil folgt dem Weg. Beenden: × oder /trip navi aus", self.probe.name))
        else ONE:Print(T("Navi zu %s. Richtung, keine Wegführung. Beenden: × oder /trip navi aus", self.probe.name)) end
    end
    return true
end

-- Ziel in Weltkoordinaten (z. B. gemerkter Flugmeister)
function Arrow:StartWorld(label, continent, x, y, opts)
    if type(continent) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return false end
    self:Create()
    self:RememberForReturn(opts)
    self.probe = {name = label or T("Ziel"), world = {continent, x, y}, service = opts and opts.service}
    self.arrivedAt, self.leftAfterArrival = nil, nil
    self:CancelDelegate() -- Weltkoordinaten (ohne Karte) kann Shortest Path Forever nicht annehmen
    self.target = self.probe.name
    self.active = true
    self.frame:Show()
    self:Refresh()
    self:Rotate()
    if opts and opts.quiet then return true end -- Quest-Fuehrung: Pfeil springt still weiter
    if self.RoutesOn() then ONE:Print(T("Navi zu %s – der Pfeil folgt dem Weg. Beenden: × oder /trip navi aus", self.probe.name))
    else ONE:Print(T("Navi zu %s. Richtung, keine Wegführung. Beenden: × oder /trip navi aus", self.probe.name)) end
    return true
end

-- ===== Wegfuehrung ueber Shortest Path Forever (eigenes Addon, GPL, github.com/cjber/shortest-path-forever) =====
-- Ist es installiert, geben wir feste Ziele per offizieller Schnittstelle weiter: Es plant echte Wege (Strassen,
-- Flugrouten, Schiffe) und zeigt seinen eigenen Pfeil + Route auf den Karten. Unser Pfeil wird dann unsichtbar,
-- rechnet aber weiter (Ankunft, hin und zurueck, Gildenmitglied bewegt sich).
Arrow.spfOwner = "GuildTrip"
-- Wegenetz 2 (19.11.2026): Guild Trip fuehrt selbst (eigenes Wegenetz + Flugzeiten); die Weitergabe an
-- Shortest Path Forever und sein Schalter sind entfallen. SPF() bleibt als "nie", damit alte Pfade ruhen.
function Arrow.SPF() return nil end
function Arrow:Delegate(mapID, x, y, label)
    local api = self.SPF()
    if not (api and type(mapID) == "number" and type(x) == "number" and type(y) == "number") then return false end
    local ok, started = pcall(api.Navigate, self.spfOwner, mapID, x, y, label)
    return ok and started == true
end
function Arrow:SetDelegated(on)
    self.delegated = on and true or false
    if self.frame then
        if self.frame.SetAlpha then self.frame:SetAlpha(on and 0 or 1) end
        if self.frame.EnableMouse then self.frame:EnableMouse(not on) end
    end
end
function Arrow:CancelDelegate()
    if not self.delegated then return end
    local api = self.SPF()
    if api and type(api.Cancel) == "function" then pcall(api.Cancel, self.spfOwner) end
    self:SetDelegated(false)
end
-- Hat der Spieler die Reise in Shortest Path Forever beendet oder eine andere gestartet?
function Arrow:DelegateEnded()
    local api = self.delegated and self.SPF()
    if not (api and type(api.Ended) == "function") then return nil end
    local ok, why = pcall(api.Ended, self.spfOwner)
    if ok and (why == "cleared" or why == "replaced") then return why end
end

-- ===== Wegenetz (ONE_Routes, vorab berechnete Laufwege, kein Zusatz-Addon) =====
-- Liefert den naechsten Punkt auf dem Weg zum Ziel (bzw. zum empfohlenen Flugmeister) oder nil (Luftlinie).
function Arrow.RoutesOn()
    local Routes = nav.Routes
    if not (Routes and Routes:Available()) then return false end
    return not (ONE.FeatureOn and not ONE:FeatureOn("nav.routes"))
end
function Arrow:SteerRoute(player, target, advice)
    if self.delegated or not (player and target) or player.continent ~= target.continent or not self.RoutesOn() then
        self.route = nil
        return
    end
    local goal = target
    if advice and advice.kind == "flight" and advice.from and nav.Flights then
        local node = nav.Flights:Nodes()[advice.from]
        if node and node.continent == player.continent and node.x and node.y then goal = node end
    end
    local p, rest, last = nav.Routes:Steer(self, player.continent, player.x, player.y, goal.x, goal.y, Clock())
    if not p then return end
    return {x = p.x, y = p.y, rest = rest, last = last}
end

-- Hin und zurueck: laeuft gerade ein "richtiges" Ziel und kommt ein Abstecher dazu, merken wir das alte Ziel
function Arrow:RememberForReturn(opts)
    if not (opts and (opts.service or opts.corpse) and self.active) then
        if not (opts and (opts.service or opts.corpse)) then self.resume = nil end
        return
    end
    if self.probe and (self.probe.service or self.probe.corpse) then return end -- Abstecher vom Abstecher: altes Ziel bleibt
    if self.probe then
        local p = self.probe
        self.resume = {name = p.name, mapID = p.mapID, x = p.x, y = p.y, world = p.world}
    elseif self.target then
        self.resume = {peer = self.target}
    end
end
function Arrow:Resume()
    local r = self.resume
    self.resume = nil
    if not r then self:Stop() return false end
    ONE:Print(T("Weiter zu %s.", r.peer and ShortName(r.peer) or r.name))
    if r.peer then return self:Start(r.peer) end
    if r.world then return self:StartWorld(r.name, r.world[1], r.world[2], r.world[3], {quiet = true}) end
    return self:StartPoint(r.name, r.mapID, r.x, r.y, {quiet = true})
end

-- Ankunft: einmal melden (Ton + Chat), Abstecher -> nach dem Weggehen zurueck zum alten Ziel,
-- feste Ziele ohne Rueckweg -> nach einer Weile ausblenden. Gildenmitglieder bewegen sich: kein Ende.
Arrow.arrivedHold, Arrow.leaveDistance = 15, 30
function Arrow:CheckArrival(advice, distance)
    local now = Clock()
    if advice and advice.kind == "arrived" then
        if not self.arrivedAt then
            self.arrivedAt = now
            if self.probe and not self.probe.corpse then
                ONE:Print(T("Angekommen: %s", self.probe.name))
                if ONE.Sound and ONE.Sound.Play then pcall(ONE.Sound.Play, ONE.Sound, "seal") end
            end
        end
    end
    if not (self.arrivedAt and self.probe) or self.probe.corpse then return end
    if self.probe.service and self.resume then
        -- erst zurueck, wenn man den Abstecher wieder verlaesst (fertig eingekauft, gelernt …)
        if distance and distance > self.leaveDistance then self:Resume() end
        return
    end
    if now - self.arrivedAt >= self.arrivedHold then self:Stop() end
end

-- Farbe: je naeher, desto gruener (die letzten 100 Yards)
function Arrow.NearColor(distance)
    if type(distance) ~= "number" or distance >= 100 then return 1, 1, 1 end
    local t = 1 - math.max(0, distance) / 100
    return 1 - .65 * t, 1, 1 - .65 * t
end

function Arrow:Stop(reason)
    self:CancelDelegate()
    self.active = false
    self.target, self.lastPeer, self.state, self.probe = nil, nil, nil, nil
    self.route, self.routeTried = nil, nil
    self.arrivedAt, self.resume = nil, nil
    if self.frame then self.frame:Hide() end
    if reason then ONE:Print(reason) end
end

function Arrow:CurrentPeer()
    local now = Clock()
    if self.probe then
        self.probe.seen = now
        return self.probe, 0
    end
    local guildModule = ONE.modules and ONE.modules.guild
    local peer = guildModule and guildModule.GetPeer and guildModule:GetPeer(self.target)
    if peer then
        self.lastPeer, self.lastPeerAt = peer, now
        return peer, now - (peer.seen or now)
    end
    -- Letzte Position nur im Arbeitsspeicher, hoechstens 5 Minuten.
    if self.lastPeer and now - (self.lastPeer.seen or self.lastPeerAt) <= self.keepLost then
        return self.lastPeer, now - (self.lastPeer.seen or self.lastPeerAt), true
    end
end

function Arrow:Refresh()
    if not self.active then return end
    local Travel = nav.Travel
    local ended = self:DelegateEnded()
    if ended then
        -- In Shortest Path Forever beendet/ersetzt: unser (unsichtbarer) Pfeil hoert auch auf
        self:SetDelegated(false) -- dort schon beendet: nicht nochmal abbrechen, Pfeil fuer spaeter wieder sichtbar
        self.resume = nil
        self:Stop()
        return
    end
    local peer, age, lost = self:CurrentPeer()
    -- Gildenmitglied: Weg alle paar Sekunden neu planen lassen, wenn es sich deutlich bewegt hat
    if not self.probe and peer and peer.mapID and self.SPF() then
        local now, sent = Clock(), self.peerSent
        local moved = not sent or sent.mapID ~= peer.mapID or math.abs((sent.x or 0) - (peer.x or 0)) + math.abs((sent.y or 0) - (peer.y or 0)) > .01
        if moved and (not sent or now - sent.at >= 5) then
            self.peerSent = {mapID = peer.mapID, x = peer.x, y = peer.y, at = now}
            self:SetDelegated(self:Delegate(peer.mapID, peer.x, peer.y, T("Zu %s", ShortName(peer.name))))
        end
    end
    if not peer then
        self:Stop("Navi beendet: keine Position von " .. ShortName(self.target) .. " seit über 5 Minuten.")
        return
    end
    local pc, px, py = Travel.PlayerWorld()
    local tc, tx, ty
    if peer.world then tc, tx, ty = peer.world[1], peer.world[2], peer.world[3]
    else tc, tx, ty = Travel.World(peer.mapID, peer.x, peer.y) end
    local player = pc and {continent = pc, x = px, y = py} or nil
    local target = tc and {continent = tc, x = tx, y = ty} or nil
    -- echter Laufweg (Wegenetz), wenn der gemerkte Weg zu diesem Ziel fuehrt
    local walk
    local r = self.route
    if r and target and r.length and r.tx and math.abs(r.tx - target.x) < 60 and math.abs(r.ty - target.y) < 60 then walk = r.length end
    local advice = Travel.Advice(player, target, nav.Flights:Nodes(), nav.Flights:Known(), walk)
    -- Anderer Kontinent: erst zum Zeppelin/Schiff (Etappe 1), drueben automatisch weiter
    local leg = Travel.Departure and Travel.Departure(player, target)
    if leg then
        target = {continent = leg.continent, x = leg.x, y = leg.y}
        advice = {kind = "leg", distance = leg.distance,
            text = leg.distance < 40 and T("Am Abflugort – warte auf Zeppelin oder Schiff.") or T("Etappe 1: %s", T(leg.name)),
            tip = T("Drüben zeigt der Pfeil weiter zum Ziel.")}
    end
    -- Wegenetz (ONE_Routes): dem vorab berechneten Laufweg folgen – zum Ziel bzw. zum Flugmeister/Abflugort.
    -- Der Pfeil zeigt dann auf die nächste Abbiegung, die Entfernung ist der Restweg.
    local steer = self:SteerRoute(player, target, advice)
    if steer then
        target = {continent = player.continent, x = steer.x, y = steer.y}
        advice = {kind = advice.kind, text = advice.text, tip = advice.tip, from = advice.from, to = advice.to,
            distance = steer.rest, routed = true, final = advice}
    end
    self.state = {player = player, target = target, advice = advice}
    local where = ""
    local guildModule = ONE.modules.guild
    if not self.probe and guildModule and guildModule.DescribePeer then
        local d = guildModule:DescribePeer(peer)
        where = d.place or d.region or d.map or ""
    end
    self.title:SetText("Zu " .. ShortName(peer.name) .. (where ~= "" and (" · " .. where) or ""))
    if advice.distance then
        self.distance:SetText(Travel.FormatDistance(advice.distance))
    elseif player and target and player.continent == target.continent then
        self.distance:SetText(Travel.FormatDistance(Travel.Distance(px, py, tx, ty)))
    else
        self.distance:SetText("")
    end
    local dist = advice.distance
    if not dist and player and target and player.continent == target.continent then dist = Travel.Distance(px, py, tx, ty) end
    if self.arrow and self.arrow.SetVertexColor then self.arrow:SetVertexColor(Arrow.NearColor(dist)) end
    self.hint:SetText(T(advice.text or ""))
    local tip = advice.tip
    if lost or (age and age > self.staleAfter) then
        tip = (lost and T("Position vor %d s (zuletzt gesehen)", math.floor(age or 0)) or T("Position vor %d s", math.floor(age or 0)))
            .. (tip and (" · " .. tip) or "")
    end
    if self.resume and self.probe and self.probe.service then
        tip = T("Danach weiter zu %s", self.resume.peer and ShortName(self.resume.peer) or self.resume.name) .. (tip and (" · " .. tip) or "")
    end
    self.tip:SetText((tip and (tip .. " · ") or "") .. (advice.routed and T("Folge dem Weg") or T("Richtung, keine Wegführung")))
    self:CheckArrival(advice, dist)
end

function Arrow:Rotate(elapsed)
    local s = self.state
    if not (s and s.player and s.target and s.player.continent == s.target.continent)
        or (s.advice and s.advice.kind == "arrived") then
        self.arrow:Hide() self.shownAngle = nil
        return
    end
    local facing = nav.Travel.Facing()
    local pc, px, py = nav.Travel.PlayerWorld()
    if not facing or not pc then
        self.arrow:Hide() self.shownAngle = nil
        return
    end
    s.player.x, s.player.y = px, py
    -- Wegenetz: zwischen zwei Refresh-Läufen schon zur nächsten Abbiegung weiterschalten
    if s.advice and s.advice.routed and self.route and nav.Routes then
        local p = nav.Routes:Next(self.route, px, py, true)
        if p then s.target.x, s.target.y = p.x, p.y end
    end
    local angle = nav.Travel.ArrowAngle(px, py, s.target.x, s.target.y, facing)
    self.shownAngle = Arrow.Smooth(self.shownAngle, angle, elapsed, self.smoothRate)
    if self.arrow.SetRotation then self.arrow:SetRotation(self.shownAngle) end
    self.arrow:Show()
end

-- Gezeigten Winkel weich zum Ziel fuehren (kuerzester Weg ueber +-pi); ohne elapsed (Start) sofort springen
function Arrow.Smooth(shown, target, elapsed, rate)
    if not shown or not elapsed or elapsed <= 0 or elapsed > .5 then return target end
    local tau = math.pi * 2
    local d = (target - shown) % tau
    if d > math.pi then d = d - tau end
    local k = 1 - math.exp(-(rate or 14) * elapsed)
    local a = shown + d * k
    a = a % tau
    if a > math.pi then a = a - tau end
    return a
end

function Arrow:OnUpdate(elapsed)
    if not self.active then return end
    self.refreshElapsed = self.refreshElapsed + elapsed
    self.rotateElapsed = self.rotateElapsed + elapsed
    if self.refreshElapsed >= self.refreshEvery then
        self.refreshElapsed = 0
        self:Refresh()
        if not self.active then return end
    end
    if self.rotateElapsed >= self.rotateEvery then
        local dt = self.rotateElapsed
        self.rotateElapsed = 0
        self:Rotate(dt)
    end
end
