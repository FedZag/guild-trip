-- Project ONE Navigation: optionaler ONE-Spielerpfeil (Wunsch eines Testers).
-- Ersetzt das Spieler-Symbol auf Minimap und Weltkarte durch den goldenen
-- ONE-Pfeil. Standard ist AUS; ausschalten stellt Blizzards Pfeil wieder her.
-- Die Weltkarten-Schnittstelle ist in Forever ungeprueft und wird nur mit
-- pcall versucht – fehlt sie, bleibt die Weltkarte einfach bei Blizzard.
local _, nav = ...
local ONE = _G.ProjectONE
local PA = {
    texture = "Interface\\AddOns\\ONE_Nav\\Textures\\Arrow.tga",
    minimapDefault = "Interface\\Minimap\\MinimapArrow",
    worldDefault = "Interface\\WorldMap\\WorldMapArrow",
}
nav.PlayerArrow = PA

function PA:Enabled()
    return ONE.db and type(ONE.db.nav) == "table" and ONE.db.nav.playerArrow == true or false
end
function PA:SetEnabled(on)
    if not ONE.db then return end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    ONE.db.nav.playerArrow = on and true or false
    self:Apply()
end

function PA:ApplyMinimap(on)
    local mm = _G.Minimap
    if not (mm and type(mm.SetPlayerTexture) == "function") then return false end
    return pcall(mm.SetPlayerTexture, mm, on and self.texture or self.minimapDefault) == true
end

function PA:ApplyWorldMap(on)
    local wm = _G.WorldMapFrame
    if not (wm and type(wm.EnumeratePinsByTemplate) == "function") then return false end
    local done = false
    local ok, iter = pcall(wm.EnumeratePinsByTemplate, wm, "GroupMembersPinTemplate")
    if not ok or type(iter) ~= "function" then return false end
    for pin in iter do
        local frame = pin.UnitPositionFrame or pin
        if type(frame.SetPlayerPinTexture) == "function" then
            done = pcall(frame.SetPlayerPinTexture, frame, on and self.texture or self.worldDefault) or done
        end
    end
    return done
end

-- Seit 0.6.2 nur noch die Minimap: auf der Weltkarte lag der goldene Pfeil ueber dem
-- Pfeil von Karten-Addons (z. B. OpenMap) – das sah unschoen aus. Die Weltkarte
-- bekommt einmalig Blizzards Pfeil zurueck, falls er frueher ersetzt wurde.
function PA:Apply()
    local on = self:Enabled()
    self.minimapOk = self:ApplyMinimap(on)
    if self.worldReplaced then self:ApplyWorldMap(false) self.worldReplaced = nil end
end

function PA:Initialize()
    -- Weltkarten-Symbole entstehen erst beim Oeffnen der Karte.
    local wm = _G.WorldMapFrame
    if self:Enabled() then self:Apply() end
end
