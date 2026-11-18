-- Guild Trip: echte Dungeon-Bilder aus dem Spielclient (Ladebildschirme).
-- Guild Trip liefert keine Blizzard-Bilder mit; hier stehen nur Dateinummern
-- (FileDataIDs) der Ladebildschirme, die schon im Client liegen.
--
-- Herkunft der Nummern: Polestar (fitzforge/polestar, GPL-3.0, Dungeons/Art.lua),
-- aus den Tabellen des Forever-Clients 1.60.1 (Map.LoadingScreenID ->
-- LoadingScreens.NarrowScreenFileDataID bzw. MainImageFileDataID). Siehe THIRD_PARTY.md.
-- Die Ausschnitte rechnet Guild Trip selbst fuer jede Flaeche aus; aus Polestar stammt
-- nur der Bildschwerpunkt (fx, fy) und die Aufhellung (lift) dunkler Bilder.
--
-- Bildformate:
--   classic: 4:3-Bild in einer quadratischen Textur; Gemaelde zwischen t 0.17 und b 0.80
--   forever: 2992x1684, Gemaelde in den Zeilen 266-1418
local _, dungeons = ...
local Art = {}
dungeons.Art = Art

local C, F = "classic", "forever"
-- key = {Datei, Schwerpunkt x, Schwerpunkt y, Format, Aufhellung}
Art.data = {
    rfc        = {131862, .50, .53, C, .7},
    thanes     = {7963781, .50, .50, F},
    wc         = {131882, .55, .50, C, .35},
    ruins      = {7963782, .50, .50, F},
    dm         = {131833, .50, .49, C},
    sfk        = {131869, .33, .55, C, .45},
    stocks     = {131870, .50, .49, C, 1},
    bfd        = {131823, .18, .45, C, .2},
    excavation = {7963777, .50, .50, F},
    dalaran    = {7963775, .50, .50, F},
    gnomer     = {131841, .50, .49, C},
    rfk        = {131865, .50, .49, C},
    sm         = {131852, .50, .49, C},
    drowned    = {7963741, .40, .50, F},
    rfd        = {131864, .56, .48, C, .25},
    krol       = {7963780, .55, .50, F},
    ulda       = {131876, .45, .47, C, .95},
    zf         = {131885, .53, .57, C, .25},
    mara       = {131850, .50, .49, C},
    alcaz      = {7963734, .55, .50, F},
    st         = {131872, .50, .49, C},
    brd        = {131824, .50, .49, C},
    dme        = {131835, .33, .50, C},
    dmw        = {131835, .33, .50, C},
    dmn        = {131835, .33, .50, C},
    lbrs       = {131825, .33, .46, C, 1},
    ubrs       = {131825, .33, .46, C, 1},
    blackmaw   = {7963784, .65, .50, F},
    scholo     = {131868, .74, .51, C},
    stratlive  = {131871, .50, .49, C, 1},
    stratud    = {131871, .50, .49, C, 1},
    shaper     = {7963783, .55, .50, F, .3},
}

-- Bildbereich je Format (Texturkoordinaten) und Seitenverhaeltnis eines Texturanteils
local FORMAT = {
    -- Breite 1 Texturanteil : Hoehe 1 Texturanteil auf dem Bildschirm = 4 : 3
    classic = {top = .17, bottom = .80, ratio = 4 / 3},
    -- 2992 x 1684 Pixel
    forever = {top = 266 / 1684, bottom = 1418 / 1684, ratio = 2992 / 1684},
}

local function Clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

-- Ausschnitt fuer eine Flaeche mit Seitenverhaeltnis aspect (Breite/Hoehe):
-- so gross wie moeglich, um den Schwerpunkt, nie ueber den Bildbereich hinaus.
-- -> l, r, t, b
function Art.Crop(entry, aspect)
    local fmt = FORMAT[entry[4]] or FORMAT.classic
    local bandH = fmt.bottom - fmt.top
    -- Hoehe (Texturanteil), wenn die ganze Breite genutzt wird
    local w, h = 1, fmt.ratio / aspect
    if h > bandH then h = bandH w = h * aspect / fmt.ratio end
    local l = Clamp(entry[2] - w / 2, 0, 1 - w)
    local t = Clamp(entry[3] - h / 2, fmt.top, fmt.bottom - h)
    return l, l + w, t, t + h
end

function Art:Has(key) return self.data[key] ~= nil end

-- Bild auf eine Textur legen. lifter (optional): zweite Textur gleicher Groesse, die
-- dunkle Bilder aufhellt (Bild + Bild * Aufhellung). -> true, wenn ein Bild gesetzt wurde
function Art:Apply(tex, key, aspect, lifter)
    local e = self.data[key]
    if not (tex and e) then
        if lifter then lifter:Hide() end
        return false
    end
    local l, r, t, b = Art.Crop(e, aspect or 1)
    if tex:SetTexture(e[1]) == false then
        if lifter then lifter:Hide() end
        return false
    end
    if tex.SetTexCoord then tex:SetTexCoord(l, r, t, b) end
    if tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 1) end
    if lifter then
        if e[5] then
            lifter:SetTexture(e[1])
            if lifter.SetTexCoord then lifter:SetTexCoord(l, r, t, b) end
            if lifter.SetBlendMode then lifter:SetBlendMode("ADD") end
            if lifter.SetVertexColor then lifter:SetVertexColor(1, 1, 1, math.min(1, e[5])) end
            lifter:Show()
        else
            lifter:Hide()
        end
    end
    return true
end
