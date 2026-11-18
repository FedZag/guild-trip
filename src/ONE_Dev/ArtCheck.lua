-- Guild Trip Entwicklung: /trip bilder
-- Zeigt alle Dungeon-Bilder (Ladebildschirme aus dem Client, ONE_Dungeons/Art.lua) in
-- einem Raster. So sieht man im Spiel sofort, ob jede Dateinummer ein Bild liefert und
-- ob der Ausschnitt passt. Prueft ausserdem, ob der Client Masken kann (runde Bildecken).
-- Schreibt nichts in den Chat ausser der Zusammenfassung im eigenen Chatfenster.
local _, ns = ...
local ONE = _G.ProjectONE
local dungeons = (ONE.ns and ONE.ns.dungeons) or nil
local AC = {cols = 6, w = 150, h = 84, gap = 10}

local function Names()
    local out = {}
    if dungeons and dungeons.Model and dungeons.Model.Dungeons then
        local ok, list = pcall(dungeons.Model.Dungeons, dungeons.Model)
        if ok and type(list) == "table" then for _, d in ipairs(list) do out[d.key] = d.name end end
    end
    return out
end

function AC:Masks()
    local f = CreateFrame("Frame")
    return type(f.CreateMaskTexture) == "function"
end

function AC:Frame()
    if self.frame then return self.frame end
    local keys = {}
    for key in pairs(dungeons.Art.data) do keys[#keys + 1] = key end
    table.sort(keys)
    local rows = math.ceil(#keys / self.cols)
    local W = self.cols * (self.w + self.gap) + self.gap
    local H = rows * (self.h + 22 + self.gap) + 54
    local f = CreateFrame("Frame", "GuildTripArtCheck", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true) f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    title:SetText("Dungeon-Bilder prüfen")
    if ONE.Themes and ONE.Themes.RegisterWindow then ONE.Themes:RegisterWindow(f, nil, title) end
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("LEFT", title, "RIGHT", 12, -1)
    if ONE.Widgets and ONE.Widgets.CloseButton then ONE.Widgets:CloseButton(f, "TOPRIGHT", -8, -8) end
    local names = Names()
    local missing = 0
    for i, key in ipairs(keys) do
        local col, row = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
        local x, y = self.gap + col * (self.w + self.gap), -44 - row * (self.h + 22 + self.gap)
        local back = f:CreateTexture(nil, "ARTWORK", nil, 0)
        back:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        back:SetSize(self.w, self.h)
        back:SetColorTexture(.6, .1, .1, 1)
        local pic = f:CreateTexture(nil, "ARTWORK", nil, 1)
        pic:SetAllPoints(back)
        local lift = f:CreateTexture(nil, "ARTWORK", nil, 2)
        lift:SetAllPoints(back)
        local ok = dungeons.Art:Apply(pic, key, self.w / self.h, lift)
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -3)
        label:SetWidth(self.w)
        label:SetJustifyH("LEFT")
        label:SetText((names[key] or key) .. "  |cff8890a8" .. dungeons.Art.data[key][1] .. "|r")
        if not ok then missing = missing + 1 label:SetTextColor(1, .45, .45) end
    end
    info:SetText(("%d Bilder · rote Fläche = Bild fehlt · Masken: %s"):format(#keys, self:Masks() and "ja" or "nein"))
    self.missing = missing
    self.frame = f
    return f
end

function AC:Run()
    if not (dungeons and dungeons.Art) then ONE:Print("Dungeon-Modul ist nicht geladen.") return end
    local f = self:Frame()
    f:Show()
    ONE:Print(("Dungeon-Bilder: %d Einträge, Masken %s. Rote Flächen fehlen im Client – bitte Bildschirmfoto schicken.")
        :format(#(function() local t = {} for k in pairs(dungeons.Art.data) do t[#t + 1] = k end return t end)(),
            self:Masks() and "verfügbar" or "nicht verfügbar"))
end

ONE:RegisterSlash("bilder", function() AC:Run() end, "Dungeon-Bilder im Spiel prüfen")
