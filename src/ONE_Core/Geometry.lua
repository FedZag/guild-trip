local _, ONE = ...

-- Project ONE: gemeinsame Geometrie aller Themes und Module.
-- Alle Werte sind WoW-UI-Einheiten, keine Bildschirm-Pixel.
-- Die API ist unabhängig vom Grafiktheme und benötigt keine WoW-Frames.
local Geometry = {}
ONE.Geometry = Geometry

Geometry.tokens = {
    contentWidth = 726,
    contentHeight = 437,
    columnGap = 16,
    actionGap = 12,
    -- Semantische Rollen fuer einzelne Aktionen. Bei zu kleinen Bereichen
    -- wird die Breite begrenzt, ohne den Elternbereich zu verlassen.
    actionWidths = {primary=248, card=176, toolbar=184},
    buttonHeight = 34,
    navButtonHeight = 38,
    cardPadding = 24,
    cardHeaderTop = 25,
    cardHeaderRuleTop = 57,
    cardHeaderRuleHeight = 1,
    -- Gleiche 8er Innenkante fuer beide Hauptbereiche und alle Unterseiten.
    shell = {
        -- Header und Footer teilen dieselben sichtbaren Aussenkanten
        -- wie die zusammengefasste Breite von Navigation und Inhalt.
        header={x=18,y=18,width=967,height=80},
        sidebar={x=18,y=110,width=208,height=508},
        content={x=243,y=110,width=742,height=508},
        footer={x=18,y=626,width=967,height=32},
    },
    cardBottomPadding = 16,
    -- Gleiche Seiteneinfuehrung fuer Core, Guild, Module und Farbpalette.
    pageTitleY = -4,
    pageSubtitleY = -35,
    -- Leere Datenansichten zeigen einen zentrierten, lesbaren Hinweis.
    emptyStateMinHeight = 96,
    -- Panels benutzen eine Textur, deren sichtbarer Strich ca. 8 Einheiten
    -- innerhalb des zugeordneten Frames beginnt. Buttons werden daher an
    -- den SICHTBAREN Panelkanten statt an den transparenten TGA-Rändern ausgerichtet.
    panelStrokeInset = 8,
}

local function Positive(v, message)
    assert(type(v) == "number" and v > 0 and v < math.huge, message)
    return v
end
local function Nonnegative(v, message)
    assert(type(v) == "number" and v >= 0 and v < math.huge, message)
    return v
end

function Geometry:Columns(width, weights, gap, left)
    Positive(width, "Spaltenbreite muss positiv sein")
    assert(type(weights) == "table" and #weights > 0, "Spaltengewichte fehlen")
    gap = Nonnegative(gap or self.tokens.columnGap, "Spaltenabstand ungueltig")
    left = left or 0
    local sum = 0
    for _,w in ipairs(weights) do sum = sum + Positive(w, "Spaltengewicht ungueltig") end
    local available = width - gap*(#weights-1)
    Positive(available, "Spaltenabstaende uebersteigen die Breite")
    local columns, x, allocated = {}, left, 0
    for i,w in ipairs(weights) do
        local cw = (i == #weights) and (available-allocated) or math.floor(available*w/sum)
        columns[i] = {x=x, width=cw}
        allocated = allocated+cw
        x = x+cw+gap
    end
    assert(allocated == available, "Spaltenrundung fehlerhaft")
    return columns
end

-- Erstellt Aktionsflächen, deren sichtbare Aussenkanten an einer Panelkarte
-- ausgerichtet sind. Keine von Hand eingesetzten x-Werte pro Button.
function Geometry:Actions(card, weights, gap, inset)
    assert(type(card) == "table", "Aktionsreihe benoetigt Kartenmaße")
    Positive(card.width, "Kartenbreite ungueltig")
    gap = gap or self.tokens.actionGap
    inset = inset or self.tokens.panelStrokeInset
    Nonnegative(inset, "Aussenabstand ungueltig")
    local width = card.width-2*inset
    Positive(width, "Karte zu schmal fuer Buttons")
    return self:Columns(width, weights, gap, card.x+inset)
end

-- Gemeinsame Platzierung EINER Aktion in einer konkreten Flaeche.
-- profile: primary / card / toolbar / fill. align: left / right / center.
-- Modul-Autoren duerfen keine ungeprueften Buttonbreiten an Seiten vorbeifuehren.
function Geometry:ActionRect(region, profile, align)
    assert(type(region)=="table", "Aktionsbereich fehlt")
    assert(type(region.x)=="number" and type(region.y)=="number", "Aktionsanker fehlen")
    Positive(region.width, "Aktionsbereich ungueltig")
    profile=profile or "card"
    align=align or "left"
    local width
    if profile=="fill" then
        width=region.width
    else
        local preferred=self.tokens.actionWidths[profile]
        assert(preferred, "Unbekannte Aktionsgroesse: "..tostring(profile))
        width=math.min(preferred,region.width)
    end
    local offset=0
    if align=="right" then offset=region.width-width
    elseif align=="center" then offset=(region.width-width)/2
    else assert(align=="left", "Ungueltige Aktionsausrichtung") end
    local rect={x=region.x+offset,y=region.y,width=width,height=self.tokens.buttonHeight}
    self:AssertActionInside(region,rect)
    return rect
end
function Geometry:AssertActionInside(region,rect)
    assert(region and rect and region.x and rect.x, "Aktionsgeometrie fehlt")
    Positive(region.width, "Aktionsbereich ungueltig")
    Positive(rect.width, "Buttonbreite ungueltig")
    assert(rect.x>=region.x-0.01, "Aktion ragt links aus ihrem Bereich")
    assert(rect.x+rect.width<=region.x+region.width+0.01, "Aktion ragt rechts aus ihrem Bereich")
    assert(rect.height==self.tokens.buttonHeight, "Aktionshoehe weicht vom Standard ab")
    return true
end

function Geometry:VisualBounds(card, inset)
    assert(card and card.x and card.width, "Karte ungueltig")
    inset = inset or self.tokens.panelStrokeInset
    return card.x+inset,card.x+card.width-inset
end

-- Testfunktion: Sichtkanten und Zwischenabstaende der ganzen Buttonreihe.
function Geometry:AssertAligned(card, actions, tolerance)
    assert(type(actions) == "table" and #actions > 0, "Keine Aktionen")
    local left,right = self:VisualBounds(card)
    tolerance = tolerance or 0
    assert(math.abs(actions[1].x-left)<=tolerance, "Linke Buttonkante stimmt nicht mit Panel ueberein")
    for i,button in ipairs(actions) do
        Positive(button.width, "Buttonbreite ungueltig")
        if i > 1 then
            local prev=actions[i-1]
            assert(button.x>=prev.x+prev.width, "Buttons ueberlappen")
        end
    end
    local last=actions[#actions]
    assert(math.abs(last.x+last.width-right)<=tolerance, "Rechte Buttonkante stimmt nicht mit Panel ueberein")
    return true
end

-- Untere Kartenaktionen liegen INNERHALB der Karten und haben Platz zum Rand.
function Geometry:BottomActionY(cardHeight, buttonHeight, bottomPadding)
    Positive(cardHeight, "Kartenhoehe ungueltig")
    buttonHeight=Positive(buttonHeight or self.tokens.buttonHeight, "Buttonhoehe ungueltig")
    bottomPadding=Positive(bottomPadding or self.tokens.cardBottomPadding, "Unterer Abstand ungueltig")
    local y=cardHeight-buttonHeight-bottomPadding
    assert(y>=0, "Karte zu klein fuer Aktion")
    return -y
end

-- Kartenüberschriften: die sichtbare Rahmenkante besitzt einen eigenen
-- Sicherheitsbereich. Dieser Vertrag gilt fuer alle neuen Karten beider Themes.
function Geometry:PageHeader(width)
    Positive(width, "Seitenbreite ungueltig")
    return {x=0,titleY=self.tokens.pageTitleY,subtitleY=self.tokens.pageSubtitleY,width=width}
end

-- Leerzustand liegt innerhalb des zugewiesenen Containers. Alle Koordinaten
-- verwenden das TOPLEFT-System mit negativen Y-Werten von WoW.
function Geometry:AssertEmptyRegion(parentWidth, parentHeight, region)
    Positive(parentWidth,"Leerseite: Elternbreite ungueltig")
    Positive(parentHeight,"Leerseite: Elternhoehe ungueltig")
    assert(type(region)=="table" and type(region.x)=="number" and type(region.y)=="number", "Leerseite: Anker fehlen")
    Positive(region.width,"Leerseite: Breite ungueltig")
    assert(type(region.height)=="number" and region.height>=self.tokens.emptyStateMinHeight, "Leerseite: Hoehe ungueltig")
    assert(region.x>=0 and region.x+region.width<=parentWidth, "Leerseite: horizontal ausserhalb")
    assert(region.y<=0 and -region.y+region.height<=parentHeight, "Leerseite: vertikal ausserhalb")
    return true
end

function Geometry:CardHeader(width)
    Positive(width, "Kartenbreite ungueltig")
    local padding=self.tokens.cardPadding
    assert(width>2*padding, "Karte zu schmal fuer Ueberschrift")
    return {
        x=padding, y=-self.tokens.cardHeaderTop, width=width-2*padding,
        ruleX=padding, ruleY=-self.tokens.cardHeaderRuleTop,
        ruleWidth=width-2*padding, ruleHeight=self.tokens.cardHeaderRuleHeight,
    }
end

-- Navigation und Inhaltsflaeche besitzen je einen eigenen, nicht
-- ueberlappenden Rahmen. Die aktiven Inhalts-/Nav-Elemente liegen mittig
-- mit 8 Einheiten Randabstand in ihren jeweiligen Rahmen.
-- Gemeinsame Anker im Launcher: Header, Navigation und Content erhalten
-- ihre Koordinaten nur ueber die Geometrie-Tokens, nicht je Seite.
function Geometry:HeaderPlacement()
    local h=self.tokens.shell.header
    local closeSize=34
    return {
        logoX=h.x+16, logoY=h.y+13, logoSize=54,
        titleX=h.x+92, titleY=h.y+18, titleWidth=350,
        subtitleY=h.y+44, subtitleWidth=535,
        versionX=h.x+h.width-280, versionY=h.y+26, versionWidth=225,
        closeX=h.x+h.width-closeSize-10,
        closeY=h.y+(h.height-closeSize)/2,
        closeSize=closeSize,
    }
end
function Geometry:ShellPlacement()
    local s=self.tokens.shell
    return {
        navLabelX=s.sidebar.x+16, navLabelY=s.sidebar.y+19,
        navButtonX=s.sidebar.x+8, navButtonY=s.sidebar.y+54,
        contentX=s.content.x+8, contentY=s.content.y+49,
        backX=s.content.x+14, forwardX=s.content.x+58,
        navToolsY=s.content.y+11,
        pathX=s.content.x+122, pathY=s.content.y+19,
        -- Untere Labels bleiben ueber dem gemeinsamen Footer.
        sidebarInfoX=s.sidebar.x+12, sidebarInfoY=s.sidebar.y+s.sidebar.height-53,
        sidebarHintY=s.sidebar.y+s.sidebar.height-32,
        footerLabelX=s.content.x+14, footerLabelY=s.footer.y+14,
    }
end
function Geometry:AssertShell()
    local r=self.tokens.shell
    local head,left,right,foot=r.header,r.sidebar,r.content,r.footer
    assert(head.x==left.x, "Header links nicht am Seitenraster")
    assert(head.x+head.width==right.x+right.width, "Header rechts nicht am Seitenraster")
    assert(foot.x==head.x and foot.width==head.width, "Footer nicht am Seitenraster")
    assert(left.x+left.width<right.x, "Hauptbereiche ueberlappen")
    assert(left.y==right.y and left.height==right.height, "Hauptbereich-Hoehen unterschiedlich")
    assert(head.y+head.height+12==left.y, "Header-Abstand zur Navigation nicht einheitlich")
    assert(left.y+left.height+8==foot.y, "Inhaltsabstand zum Footer nicht einheitlich")
    local nav=self:ShellPlacement()
    local navWidth,contentWidth=192,self.tokens.contentWidth
    assert(nav.navButtonX-left.x==left.x+left.width-(nav.navButtonX+navWidth), "Navigation nicht mittig im Rahmen")
    assert(nav.contentX-right.x==right.x+right.width-(nav.contentX+contentWidth), "Inhalt nicht mittig im Rahmen")
    local h=self:HeaderPlacement()
    assert(h.logoX>=head.x and h.logoY>=head.y and h.logoY+h.logoSize<=head.y+head.height, "Logo ausserhalb Header")
    assert(h.closeX>=head.x and h.closeX+h.closeSize<=head.x+head.width and
        h.closeY>=head.y and h.closeY+h.closeSize<=head.y+head.height, "Schliessen-Button ausserhalb Header")
    assert(right.x+right.width<=1010 and foot.y+foot.height<=670, "Hauptbereiche ragen hinaus")
    return true
end
