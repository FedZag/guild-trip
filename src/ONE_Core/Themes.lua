local _, ONE = ...

-- Project ONE 0.4.4: nativer Blizzard-Look.
-- ONE zeichnet keine eigenen Rahmen mehr, sondern laesst das Spiel seine
-- eigenen Fensterteile zeichnen (NineSlice-Layouts wie "InsetFrameTemplate",
-- Knopfvorlage UIPanelButtonTemplate). Dadurch sieht ONE aus wie die
-- Forever-Fenster und folgt automatisch, wenn Blizzard sein Aussehen aendert.
-- Dieses Modul verwaltet nur noch Textfarben (Rollen) und Kartenflaechen.
local Themes = { windows={}, buttons={}, panels={}, texts={}, rules={} }
ONE.Themes = Themes

Themes.order = {"native"}
Themes.presets = {
    native = {
        name="Blizzard", subtitle="Fensterteile direkt aus dem Spiel", skin="native",
        -- Blizzard-Schriftfarben: Gold fuer Titel, Weiss fuer Text.
        accent={1,.82,0}, text={1,1,1}, soft={.86,.84,.79},
        border={.42,.36,.27}, background={.05,.04,.03}, surface={0,0,0}, button={.10,.08,.06},
        light={1,.88,.6}, softBorder={.25,.21,.15},
    },
    -- Probe "Altes Buch": dunkle Tinte auf Pergament (siehe Book.lua)
    book = {
        name="Altes Buch", subtitle="Pergament und Tinte", skin="book",
        accent={.40,.09,.02}, text={.10,.05,.01}, soft={.24,.15,.07},
        border={.45,.30,.15}, background={.80,.68,.48}, surface={.75,.62,.42}, button={.10,.08,.06},
        light={.42,.13,.02}, softBorder={.55,.42,.25},
    },
}

function Themes:Initialize()
    if type(ONE.db.theme)~="table" then ONE.db.theme={} end
    local t=ONE.db.theme
    -- Alle frueheren Designs (Midnight, Forge, Forever ...) gehen im nativen Look auf;
    -- "book" ist die Probe "Altes Buch".
    if t.selected~="book" then t.selected="native" end
    if type(t.uiSounds)~="boolean" then t.uiSounds=true end
end
local function Selected()
    local t=ONE.db and ONE.db.theme
    return type(t)=="table" and t.selected=="book" and "book" or "native"
end
function Themes:Get() return self.presets[Selected()] end
function Themes:Current() return self.presets[Selected()] end
function Themes:IsNative() return Selected()=="native" end
function Themes:SetActive(id)
    if id~="native" and id~="book" then return false end
    if ONE.Book then ONE.Book:SetEnabled(id=="book") else ONE.db.theme.selected=id self:ApplyAll() end
    return true
end

local function Fill(tex,c,a)
    if tex and tex.SetColorTexture then tex:SetColorTexture(c[1],c[2],c[3],a or 1) end
end

-- Wendet ein Blizzard-NineSlice-Layout an, wenn der Client es kennt.
function Themes:ApplyLayout(frame,layout)
    local util=_G.NineSliceUtil
    if not (util and type(util.ApplyLayoutByName)=="function") then return false end
    return pcall(util.ApplyLayoutByName,frame,layout)==true
end

-- Rueckfall ohne NineSlice (aeltere Clients, Tests): duenne Kanten.
local function Edges(frame,color,alpha)
    local edges={}
    for _,side in ipairs({"top","bottom","left","right"}) do
        local t=frame:CreateTexture(nil,"BORDER")
        if side=="top" or side=="bottom" then
            t:SetPoint(side=="top" and "TOPLEFT" or "BOTTOMLEFT",frame,side=="top" and "TOPLEFT" or "BOTTOMLEFT",0,0)
            t:SetPoint(side=="top" and "TOPRIGHT" or "BOTTOMRIGHT",frame,side=="top" and "TOPRIGHT" or "BOTTOMRIGHT",0,0)
            t:SetHeight(1)
        else
            t:SetPoint(side=="left" and "TOPLEFT" or "TOPRIGHT",frame,side=="left" and "TOPLEFT" or "TOPRIGHT",0,0)
            t:SetPoint(side=="left" and "BOTTOMLEFT" or "BOTTOMRIGHT",frame,side=="left" and "BOTTOMLEFT" or "BOTTOMRIGHT",0,0)
            t:SetWidth(1)
        end
        Fill(t,color,alpha)
        edges[#edges+1]=t
    end
    return edges
end

function Themes:RegisterRule(tex,role)
    self.rules[#self.rules+1]={tex=tex,role=role or "border"}
    self:ApplyRule(self.rules[#self.rules])
end
function Themes:ApplyRule(entry)
    Fill(entry.tex,self:Current()[entry.role] or self:Current().border)
end
function Themes:RegisterText(font,role)
    if not font then return end
    if ONE.Kit then ONE.Kit:Upgrade(font) end
    -- Buch-Aussehen: Ueberschriften in der Buchschrift
    if Selected()=="book" and role=="accent" and font.GetFont and font.SetFont and ONE.Book then
        local _,size=font:GetFont()
        pcall(font.SetFont,font,ONE.Book.font,(size or 12)+1,"")
    end
    if Selected()=="book" and ONE.Book then ONE.Book.Crisp(font) end
    self.texts[#self.texts+1]={font=font,role=role or "text"}
    self:ApplyText(self.texts[#self.texts])
end
function Themes:ApplyText(entry)
    local p=self:Current()
    local c=ONE.Kit and ONE.Kit:TextColor(p,entry.role) or p[entry.role] or p.text
    if entry.font.SetTextColor then entry.font:SetTextColor(c[1],c[2],c[3]) end
end
function Themes:PlaySound(kind,_,explicitPreview)
    if not explicitPreview and (not ONE.db or not ONE.db.theme or not ONE.db.theme.uiSounds) then return false end
    -- Buch: Seitenwechsel klingt schon als Umblaettern (ONE.Sound "page")
    if not explicitPreview and Selected()=="book" then return false end
    if not PlaySound or not SOUNDKIT then return false end
    local sound=(kind=="click") and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_CHARACTER_INFO_TAB"
    local soundID=SOUNDKIT[sound] or SOUNDKIT.IG_MAINMENU_OPEN
    if not soundID then return false end
    PlaySound(soundID,"SFX")
    return true
end

-- Kleine Fenster (Hinweise, Tagesuebersicht): Blizzard-Dialograhmen.
function Themes:RegisterWindow(frame,background,label)
    if not frame then return end
    local entry={frame=frame,background=background,label=label}
    entry.native=self:ApplyLayout(frame,"SimplePanelTemplate")
    if not entry.native then entry.edges=Edges(frame,self:Current().border,1) end
    self.windows[#self.windows+1]=entry
    self:ApplyWindow(entry)
end
function Themes:ApplyWindow(entry)
    -- Buch: eigene Fenster (Tagesueberblick, Hinweise) als loses Pergamentblatt
    if Selected()=="book" and ONE.Book and ONE.Book.Sheet then
        for _,key in ipairs({"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge","Center"}) do
            local piece=entry.frame[key] if piece and piece.Hide then piece:Hide() end
        end
        for _,t in ipairs(entry.edges or {}) do t:Hide() end
        ONE.Book:Sheet(entry)
        return
    end
    local p=self:Current()
    Fill(entry.background,p.background,entry.native and .92 or 1)
    if entry.frame.SetBackdropColor then entry.frame:SetBackdropColor(0,0,0,0) end
    if entry.frame.SetBackdropBorderColor then entry.frame:SetBackdropBorderColor(0,0,0,0) end
    if entry.label and entry.label.SetTextColor then entry.label:SetTextColor(p.accent[1],p.accent[2],p.accent[3]) end
end

-- Karten: dunkle, eingelassene Flaeche wie die Kaesten im Charakterfenster.
function Themes:RegisterPanel(frame)
    if not frame then return end
    local bg=frame:CreateTexture(nil,"BACKGROUND",nil,-6)
    bg:SetAllPoints(frame)
    local entry={frame=frame,bg=bg}
    entry.native=self:ApplyLayout(frame,"InsetFrameTemplate")
    if not entry.native then entry.edges=Edges(frame,self:Current().border,.8) end
    self.panels[#self.panels+1]=entry
    self:ApplyPanel(entry)
    return bg
end
local NINE={"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge","Center"}
function Themes:ApplyPanel(entry)
    if Selected()=="book" then
        -- Im Buch keine Kaesten: nur die Ueberschrift mit Zierlinie (Themes:PanelTitle)
        Fill(entry.bg,{0,0,0},0)
        for _,key in ipairs(NINE) do local piece=entry.frame[key] if piece and piece.Hide then piece:Hide() end end
        return
    end
    Fill(entry.bg,{0,0,0},entry.native and .35 or .55)
end

-- Ueberschrift einer Karte: im Buch Rubrik-Rot mit doppelter Zierlinie darunter
-- (feine Linie, darunter eine noch feinere), reicht bis zum rechten Kartenrand.
function Themes:PanelTitle(frame,label)
    if Selected()~="book" or not (frame and label) or frame.__oneOrnament then return end
    local red=ONE.Book and ONE.Book.red or {.42,.10,.03}
    if label.SetFont and ONE.Book then pcall(label.SetFont,label,ONE.Book.font,14,"") end
    if ONE.Book then ONE.Book.Crisp(label) end
    label.__oneInk=true
    -- Farbe bleibt Rubrik-Rot (nicht beim naechsten ApplyAll ueberschreiben)
    for i=#self.texts,1,-1 do if self.texts[i].font==label then table.remove(self.texts,i) end end
    if label.SetTextColor then label:SetTextColor(red[1],red[2],red[3]) end
    local lines={}
    for i,spec in ipairs({{-3,1,.75},{-6,1,.35}}) do
        local t=frame:CreateTexture(nil,"ARTWORK")
        t:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,spec[1])
        t:SetPoint("RIGHT",frame,"RIGHT",-12,0)
        t:SetHeight(spec[2])
        if t.SetColorTexture then t:SetColorTexture(red[1],red[2],red[3],spec[3]) end
        lines[i]=t
    end
    frame.__oneOrnament=lines
    return lines
end

-- Knoepfe sind Blizzard-Vorlagen (Widgets:Button); nichts zu faerben.
-- Die Funktionen bleiben fuer Module, die sie noch aufrufen.
function Themes:StyleButton() end
function Themes:ApplyButton() end
function Themes:StyleTree() end

function Themes:ApplyAll()
    for _,e in ipairs(self.windows) do self:ApplyWindow(e) end
    for _,e in ipairs(self.panels) do self:ApplyPanel(e) end
    for _,e in ipairs(self.texts) do self:ApplyText(e) end
    for _,e in ipairs(self.rules) do self:ApplyRule(e) end
end
