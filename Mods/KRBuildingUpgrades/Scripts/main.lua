--[[
    KRBuildingUpgrades v10

    Sammelt beim Spielen automatisch, welche Upgrades ein Gebaeudetyp hat und
    welche davon schon gekauft sind, haelt das ueber Spielneustarts hinweg und
    zeigt es als Overlay im Spiel.

    Warum es so und nicht anders geht (aus UE4SS_ObjectDump.txt belegt):

      * Die Simulation (PunSimCore) ist reines C++ ohne UObject-Reflection und
        aus Lua nicht erreichbar. Einzige Datenquelle sind die UMG-Widgets.
      * Es gibt keine aufrufbare Funktion, um ein Gebaeude zu selektieren -
        ObjectDescriptionUI_C hat genau eine Funktion (OnMouseButtonDown_0),
        die Selektion liegt in nicht-reflektiertem C++. Automatisches
        Durchklicken aller Gebaeude ist damit unmoeglich; der Cache fuellt
        sich, waehrend der Spieler Gebaeude anklickt.
      * Upgrades gelten laut Tooltip ("Shift-click ... all same type buildings")
        pro Gebaeude-TYP. Ein Gebaeude je Typ reicht also fuer die Uebersicht.

    Panelaufbau, im v3-Lauf bestaetigt: DescriptionPunBox.PunVerticalBox ist
    eine flache Zeilenliste; Upgrades sind PunButtonWidget_C (.TopText) und
    PunSplitButtonWidget_C (.Text1/.Text2). Der Zeilentext ist zweizeilig,
    "<Name>\r\n<Status>", mit Status "Done" oder Preis wie
    '<img id="SteelBeam"/><Red>80</>' (<Red> = derzeit nicht bezahlbar).

    Bedienung: nur mit der Maus, keine Tastenbelegung. UE4SS-Keybinds
    verschlucken die Taste nicht, das Spiel reagiert zusaetzlich mit -
    Strg+Shift+B hat so jedes Mal das Baumenue geoeffnet.

      * Kopfzeile anklicken klappt die Liste zu und wieder auf. Zugeklappt
        bleibt nur ein schmaler Streifen stehen, die Gebaeudetabelle darunter
        ist wieder benutzbar. Der Zustand wird im Cache mitgeschrieben und
        gilt beim naechsten Start weiter.
      * Eine Upgradezeile anklicken kauft das Upgrade, sofern das Gebaeude
        gerade ausgewaehlt ist. Sonst springt der erste Klick zum Gebaeude
        (Lupe der Statistikzeile), der zweite kauft.
      * Ein Klick auf den Gebaeudenamen springt hin, jeder weitere zum
        naechsten Gebaeude desselben Typs und nach dem letzten wieder von
        vorn. Die Kopfzeile zeigt dabei "2/5" mit.

    Die Liste fuellt sich beim normalen Spielen, sobald ein Gebaeude angeklickt
    wird, und das Panel haengt als Kind im Root-Canvas der StatisticsUI - es
    erscheint also mit dem Statistik-Fenster und verschwindet damit wieder.
    Sichtbar ist es nur im Gebaeude-Tab, damit es die Graphen der anderen Tabs
    nicht verdeckt (siehe Overlay-Abschnitt). Diagnosedumps schreibt der Mod
    bei Bedarf von selbst.

    Dateien (neben UE4SS.log):
      KRUpgrades.lua  persistenter Cache
      KRRecon.txt     automatische Diagnosedumps

    Was v7 gegenueber v6 geaendert hat: v6 hat die Ursache der Unsichtbarkeit
    belegt - SetAnchors greift ueber UE4SS nicht, der Anker blieb auf (0,0) und
    das Panel lag deshalb 260 Pixel ueber dem oberen Bildschirmrand. v7 setzt
    die Anker ueber die Property LayoutData, legt das Panel als ANTEIL der
    Canvas-Flaeche fest (damit braucht es weder Fenstergroesse noch
    Aufloesung) und prueft Anker mit einer Toleranz, die zu Werten zwischen 0
    und 1 passt. Begruendung im Abschnitt "Geometrie schreiben".

    Was v8 dazu nimmt: v7 lag richtig, verdeckte damit aber die ganze
    Gebaeudetabelle und war nur zum Lesen. v8 macht das Panel bedienbar. Aus
    einem TextBlock wird eine Kopfzeile plus eine Zeile je Eintrag, jede in
    einem eigenen UMG.Button; geklickt wird nicht ueber ein Delegate (UE4SS
    3.0.1 kann keines binden), sondern durch Abfragen von Button:IsPressed in
    einer schnellen Schleife. Damit das nicht ins Geld geht, laeuft die
    Zeilenabfrage nur, solange der Mauszeiger ueber dem Panel steht.

    Der Kaufweg ist aus dem Object-Dump belegt und parameterlos:

        Function /Script/PrototypeCity.PunButton:OnButtonDown
        Function /Script/PrototypeCity.PunSplitButton:OnButtonDown1 / 2
        Function /Script/PrototypeCity.BuildingStatTableRow:OnButtonDown

    PunButtonWidget_C erbt von PunButton, PunSplitButtonWidget_C von
    PunSplitButton (sps-Adressen im Dump geprueft). Aufgerufen wird immer nur
    auf genau dem Widget, das im offenen Beschreibungspanel gefunden wurde -
    dieses traegt Gebaeude-Id und Callback-Enum bereits in nicht-reflektierten
    C++-Feldern, es ist also nichts zu setzen und nichts zu raten. Vor jedem
    Aufruf wird geprueft, dass Widget und _callbackParent gueltig sind: genau
    dieser Zeiger wird in OnButtonDown dereferenziert, und ein CDO haette dort
    nullptr stehen (die FindAllOf-Falle aus v1/v2).

    Was v9 aendert: v8 nahm beim Springen die erste passende Zeile der
    Gebaeudetabelle und war fertig. Die Tabelle listet aber je GEBAEUDE eine
    Zeile, nicht je Typ - bei fuenf Imkereien stehen dort fuenf Zeilen
    "Beekeeper". Jeder Klick landete deshalb beim selben Gebaeude, und die
    uebrigen waren nur ueber die Pfeile im Beschreibungsfenster erreichbar.
    v9 sammelt alle Zeilen eines Typs und geht mit jedem Klick eine weiter.
    Ausserdem stand in der Uebersicht nur "(2/4)", was sich als "Gebaeude 2
    von 4" lesen liess; jetzt steht die Gebaeudezahl in einer eigenen Spalte.

    Was v10 aendert, beides aus der Rueckmeldung zum Lauf von v9:

      * Der Hintergrund war mit Alpha 0.88 durchscheinend, die Gebaeudetabelle
        des Spiels stand hinter der Schrift. Jetzt deckend.
      * Alles stand zentriert und war als Liste kaum zu lesen. Ursache war der
        UButtonSlot, der seinen Inhalt von Haus aus mittig setzt. Aus der
        einen Textzeile je Eintrag ist eine echte Tabelle geworden:
        HorizontalBox mit drei Spalten (Gebaeude/Upgrade, Kosten, Stand),
        linksbuendig, Breite als Anteil - und ein Spaltenkopf, der nicht
        mitscrollt. Erledigte Upgrades treten ueber SetOpacity zurueck; das
        nimmt einen flachen Float, waehrend SetColorAndOpacity mit seinem
        verschachtelten FSlateColor lautlos wirkungslos geblieben waere.
]]

local RECON_FILE = "KRRecon.txt"
local CACHE_FILE = "KRUpgrades.lua"

--==========================================================================--
-- Logging
--==========================================================================--

local FileHandle = nil

local function OpenOut()
    local ok, f = pcall(io.open, RECON_FILE, "a")
    if ok and f then FileHandle = f return true end
    FileHandle = nil
    return false
end

local function CloseOut()
    if FileHandle then
        pcall(function() FileHandle:close() end)
        FileHandle = nil
    end
end

-- Immer in UE4SS.log, zusaetzlich in KRRecon.txt solange ein Dump laeuft.
-- Zeilenweise geflusht: stirbt das Spiel mitten im Dump, ist alles bis dahin da.
local function Log(Message)
    local Line = tostring(Message)
    print(string.format("[KRUpg] %s\n", Line))
    if FileHandle then
        pcall(function()
            FileHandle:write(Line, "\n")
            FileHandle:flush()
        end)
    end
end

--==========================================================================--
-- UObject-Helfer
--==========================================================================--

local function FullName(Obj)
    local ok, n = pcall(function() return Obj:GetFullName() end)
    if ok and n then return n end
    return "<no full name>"
end

local function ClassName(Obj)
    local ok, n = pcall(function() return Obj:GetClass():GetFName():ToString() end)
    if ok and n then return n end
    return "<no class>"
end

local function IsValidObj(Obj)
    if not Obj then return false end
    local ok, v = pcall(function() return Obj:IsValid() end)
    return ok and v == true
end

-- CDOs und WidgetArchetypes sehen fuer FindAllOf wie echte Instanzen aus,
-- haben aber keinen Runtime-State. Genau daran ist v2 gescheitert.
local function IsTemplate(Obj)
    local n = FullName(Obj)
    return n:find("Default__", 1, true) ~= nil
        or n:find("WidgetArchetype", 1, true) ~= nil
end

local function FindLive(WantedClass, Verbose)
    local ok, Objs = pcall(FindAllOf, WantedClass)
    if not ok or not Objs then
        if Verbose then Log(string.format("FindLive(%s): FindAllOf lieferte nichts", WantedClass)) end
        return nil
    end

    local Live, Total = nil, 0
    for _, Obj in pairs(Objs) do
        Total = Total + 1
        local Verdict
        if not IsValidObj(Obj) then
            Verdict = "SKIP (invalid)"
        elseif ClassName(Obj) ~= WantedClass then
            Verdict = "SKIP (Klasse passt nicht: " .. ClassName(Obj) .. ")"
        elseif IsTemplate(Obj) then
            Verdict = "SKIP (CDO/Archetype)"
        else
            Verdict = "OK"
            if not Live then Live = Obj end
        end
        if Verbose then Log(string.format("  Kandidat: %-14s %s", Verdict, FullName(Obj))) end
    end

    if Verbose then
        Log(string.format("FindLive(%s): %d Kandidaten, live=%s",
            WantedClass, Total, Live and FullName(Live) or "KEINE"))
    end
    return Live
end

local function ReadText(W)
    local ok, T = pcall(function() return W.Text end)
    if not ok or not T then return nil end
    local ok2, S = pcall(function() return T:ToString() end)
    if ok2 and S and S ~= "" then return S end
    return nil
end

-- Pun-Widgets tragen den Text selten selbst: PunRichText haelt ihn in
-- .PunRichText, PunButton in .TopText usw.
local NestedTextProps = {
    "PunRichText", "TopText", "ButtonText", "ItemIconText", "LeftText", "PrefixText",
}

local function DeepText(W, Depth)
    Depth = Depth or 0
    if not IsValidObj(W) or Depth > 2 then return nil end
    local T = ReadText(W)
    if T then return T end
    for _, PName in ipairs(NestedTextProps) do
        local Sub = nil
        if pcall(function() Sub = W[PName] end) and IsValidObj(Sub) then
            local S = DeepText(Sub, Depth + 1)
            if S then return S end
        end
    end
    return nil
end

-- FindAllOf scannt das gesamte GUObjectArray (der Object-Dump dieses Spiels ist
-- 94 MB gross). Einmal pro Sekunde waere das im Poll-Loop spuerbar, also den
-- HUD-Zeiger merken und nur neu aufloesen, wenn er ungueltig wird - etwa nach
-- einem Spielwechsel.
local CachedHUD = nil

local function GetHUD(Verbose)
    if not Verbose and IsValidObj(CachedHUD) and ClassName(CachedHUD) == "PunHUD" then
        return CachedHUD
    end
    local HUD = FindLive("PunHUD", Verbose)
    if HUD then CachedHUD = HUD end
    return HUD
end

local function GetDescriptionUI(Verbose)
    local HUD = GetHUD(Verbose)
    if not HUD then return nil end
    local Sys = nil
    pcall(function() Sys = HUD["_descriptionUISystem"] end)
    if not IsValidObj(Sys) then return nil end
    local UI = nil
    pcall(function() UI = Sys["_objectDescriptionUI"] end)
    if not IsValidObj(UI) then return nil end
    return UI
end

--==========================================================================--
-- Textaufbereitung
--==========================================================================--

local function Trim(S)
    return (S:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Rich-Text-Markup fuer die Anzeige entschaerfen: <img id="Wood"/> -> "Wood",
-- alle uebrigen Tags raus.
local function StripTags(S)
    if not S then return "" end
    S = S:gsub('<img%s+id="([^"]*)"%s*/>', "%1 ")
    S = S:gsub("<[^>]*>", "")
    return Trim(S)
end

-- Im Titel-Widget ist je nach Gebaeude mal .Title, mal .Title2Lines belegt;
-- das jeweils ungenutzte Feld behaelt seinen Platzhaltertext aus dem
-- Blueprint. Ohne diese Liste landete eine Brennerei als Gebaeudetyp "Title"
-- im Cache.
local Placeholders = {
    Title = true, Title2Lines = true, Subtitle = true, TownName12345678 = true,
}

-- "House Lv 6" und "House Lv 1" sind derselbe Typ.
local function TypeKey(Title)
    local T = Trim(StripTags(Title or ""))
    T = T:gsub("%s+Lv%s*%d+$", "")
    return T
end

--==========================================================================--
-- Sammeln
--==========================================================================--

-- Je Zeilentyp: welche Text-Property den Upgradetext traegt, und welche
-- parameterlose UFunction denselben Klick ausloest wie die Maus. Die Zuordnung
-- steht so im Object-Dump; PunButtonWidget_C erbt von PunButton,
-- PunSplitButtonWidget_C von PunSplitButton.
local UpgradeRowProps = {
    PunButtonWidget_C      = { { "TopText", "OnButtonDown"  } },
    PunSplitButtonWidget_C = { { "Text1",   "OnButtonDown1" },
                               { "Text2",   "OnButtonDown2" } },
}

-- Zerlegt "<Name>\r\n<Status>" in die Bestandteile.
local function ParseUpgradeText(Raw)
    local First, Rest = Raw:match("^([^\r\n]*)[\r\n]+(.*)$")
    if not First then First, Rest = Raw, "" end

    local Label = Trim(StripTags(First))
    if Label == "" then return nil end

    local StatusRaw = Trim(Rest)
    local StatusPlain = StripTags(StatusRaw)

    local Entry = { label = Label, raw = Raw }
    if StatusPlain == "" then
        -- Kein zweiter Text: Zustand unbekannt, aber das Upgrade existiert.
        Entry.state = "unknown"
    elseif StatusPlain:lower() == "done" then
        Entry.state = "done"
    else
        Entry.state = "open"
        Entry.cost = StatusPlain
        -- <Red> markiert im Spiel genau das, was man sich gerade nicht leisten kann.
        Entry.affordable = (StatusRaw:find("<Red>", 1, true) == nil)
    end
    return Entry
end

-- Liest das gerade offene Beschreibungspanel aus. Gibt nil zurueck, wenn kein
-- Gebaeude ausgewaehlt ist oder das Panel keine Upgradezeilen hat.
local function ScrapeDescriptionPanel(DescUI)
    local Box = nil
    pcall(function() Box = DescUI["DescriptionPunBox"] end)
    if not IsValidObj(Box) then return nil end

    local VBox = nil
    pcall(function() VBox = Box["PunVerticalBox"] end)
    if not IsValidObj(VBox) then return nil end

    local okc, Count = pcall(function() return VBox:GetChildrenCount() end)
    if not okc or type(Count) ~= "number" or Count <= 0 then return nil end

    local Title, Upgrades, Seen, Live = nil, {}, {}, {}
    for i = 0, Count - 1 do
        local Child = nil
        local okch = pcall(function() Child = VBox:GetChildAt(i) end)
        if okch and IsValidObj(Child) then
            local CN = ClassName(Child)

            if CN == "WGT_ObjectFocus_Title_C" and not Title then
                for _, PName in ipairs({ "Title", "Title2Lines" }) do
                    local W = nil
                    pcall(function() W = Child[PName] end)
                    if IsValidObj(W) then
                        local T = ReadText(W)
                        if T then
                            T = Trim((T:gsub("[\r\n]+", " ")))
                            if T ~= "" and not Placeholders[T] then
                                Title = T
                                break
                            end
                        end
                    end
                end
            end

            local Props = UpgradeRowProps[CN]
            if Props then
                for _, PSpec in ipairs(Props) do
                    local PName, FName_ = PSpec[1], PSpec[2]
                    local W = nil
                    pcall(function() W = Child[PName] end)
                    local Raw = IsValidObj(W) and ReadText(W) or nil
                    if Raw then
                        local Entry = ParseUpgradeText(Raw)
                        -- Split-Buttons zeigen dasselbe Upgrade zweimal
                        -- (einzeln / alle), also nach Label entdoppeln.
                        if Entry and not Seen[Entry.label] then
                            Seen[Entry.label] = true
                            Upgrades[#Upgrades + 1] = Entry
                            -- Das lebende Widget getrennt merken: der Cache
                            -- wird als Text weggeschrieben, Objektzeiger haben
                            -- darin nichts zu suchen und ueberleben ohnehin
                            -- keinen Wechsel der Auswahl.
                            Live[Entry.label] = { W = Child, Fn = FName_ }
                        end
                    end
                end
            end
        end
    end

    if not Title then return nil end
    return { title = Trim(StripTags(Title)), upgrades = Upgrades, live = Live }
end

--==========================================================================--
-- Cache + Persistenz
--==========================================================================--

local Cache = {}          -- TypeKey -> { title, upgrades, seen }
local CacheDirty = false

-- Bedienzustand, der einen Spielneustart ueberleben soll. Liegt mit im
-- Cachefile unter einem Schluessel, den es als Gebaeudetyp nicht geben kann.
-- Zugeklappt ist die Voreinstellung: v7 hat das Statistik-Fenster unbenutzbar
-- gemacht, weil das Panel die Gebaeudetabelle vollstaendig verdeckt hat. Ohne
-- gespeicherten Zustand soll die Statistik deshalb erst einmal so
-- funktionieren wie ohne den Mod - die Uebersicht ist einen Klick entfernt,
-- und der Zustand gilt danach weiter.
local SETTINGS_KEY = "__settings"
local Settings = { collapsed = true }

local function CountEntries(T)
    local n = 0
    for _ in pairs(T) do n = n + 1 end
    return n
end

local function SortedKeys(T)
    local Keys = {}
    for k in pairs(T) do Keys[#Keys + 1] = k end
    table.sort(Keys)
    return Keys
end

-- Hat sich gegenueber dem Cache wirklich etwas geaendert? Sonst wuerde jeder
-- Poll die Datei neu schreiben.
--
-- Frisch gescrapte und aus der Datei geladene Eintraege sind nicht bitgleich:
-- ein fehlendes cost ist einmal nil und einmal "", affordable einmal nil und
-- einmal false. Ohne Normalisierung gilt nach jedem Spielstart alles als
-- geaendert und wird sofort neu geschrieben.
local function SameCost(A, B)
    return (A or "") == (B or "")
end

local function EntryDiffers(Old, New)
    if not Old then return true end
    if Old.title ~= New.title then return true end
    if #Old.upgrades ~= #New.upgrades then return true end
    for i, U in ipairs(New.upgrades) do
        local O = Old.upgrades[i]
        if not O or O.label ~= U.label or O.state ~= U.state
           or not SameCost(O.cost, U.cost)
           or (O.affordable == true) ~= (U.affordable == true) then
            return true
        end
    end
    return false
end

local function Remember(Scraped)
    local Key = TypeKey(Scraped.title)
    if Key == "" or Placeholders[Key] then return false end

    local New = {
        title = Scraped.title,
        upgrades = Scraped.upgrades,
    }
    if not EntryDiffers(Cache[Key], New) then return false end

    local Stamp = ""
    pcall(function() Stamp = os.date("%Y-%m-%d %H:%M:%S") end)
    New.seen = Stamp
    Cache[Key] = New
    CacheDirty = true
    Log(string.format("erfasst: %s (%d Upgrades)", Key, #New.upgrades))
    return true
end

local function QuoteStr(S)
    return string.format("%q", tostring(S or ""))
end

local function SaveCache()
    local ok, f = pcall(io.open, CACHE_FILE, "w")
    if not ok or not f then
        Log("WARNUNG: " .. CACHE_FILE .. " nicht schreibbar")
        return false
    end
    local okw = pcall(function()
        f:write("-- KRBuildingUpgrades cache, automatisch erzeugt\n")
        f:write("return {\n")
        f:write(string.format("  [%s] = { collapsed = %s },\n",
            QuoteStr(SETTINGS_KEY), tostring(Settings.collapsed == true)))
        for _, Key in ipairs(SortedKeys(Cache)) do
            local E = Cache[Key]
            f:write(string.format("  [%s] = {\n", QuoteStr(Key)))
            f:write(string.format("    title = %s,\n", QuoteStr(E.title)))
            f:write(string.format("    seen = %s,\n", QuoteStr(E.seen)))
            f:write("    upgrades = {\n")
            for _, U in ipairs(E.upgrades) do
                f:write(string.format(
                    "      { label = %s, state = %s, cost = %s, affordable = %s },\n",
                    QuoteStr(U.label), QuoteStr(U.state), QuoteStr(U.cost),
                    tostring(U.affordable == true)))
            end
            f:write("    },\n  },\n")
        end
        f:write("}\n")
    end)
    pcall(function() f:close() end)
    if okw then CacheDirty = false end
    return okw
end

local function LoadCache()
    local okf, chunk = pcall(loadfile, CACHE_FILE)
    if not okf or not chunk then return end
    local okr, Data = pcall(chunk)
    if not okr or type(Data) ~= "table" then
        Log("WARNUNG: " .. CACHE_FILE .. " unlesbar, starte mit leerem Cache")
        return
    end
    -- Defensiv einlesen: eine kaputte Datei darf den Mod nicht kippen.
    -- Platzhalter-Keys aus aelteren Laeufen fliegen dabei raus; sie werden beim
    -- naechsten Anklicken des Gebaeudes unter dem richtigen Namen neu erfasst.
    local Dropped = 0
    for Key, E in pairs(Data) do
        if Key == SETTINGS_KEY then
            if type(E) == "table" then Settings.collapsed = (E.collapsed == true) end
        elseif type(Key) == "string" and Placeholders[Key] then
            Dropped = Dropped + 1
        elseif type(Key) == "string" and type(E) == "table" and type(E.upgrades) == "table" then
            local Ups = {}
            for _, U in ipairs(E.upgrades) do
                if type(U) == "table" and type(U.label) == "string" then
                    Ups[#Ups + 1] = {
                        label = U.label,
                        state = U.state or "unknown",
                        -- Beim Serialisieren wird nil zu "". Wieder zu nil
                        -- machen, sonst haelt EntryDiffers jeden geladenen
                        -- Eintrag fuer veraendert und schreibt bei jedem
                        -- Spielstart alles neu.
                        cost = (U.cost ~= "" and U.cost) or nil,
                        affordable = U.affordable == true,
                    }
                end
            end
            Cache[Key] = { title = E.title or Key, seen = E.seen or "", upgrades = Ups }
        end
    end
    Log(string.format("Cache geladen: %d Gebaeudetypen aus %s%s",
        CountEntries(Cache), CACHE_FILE,
        Dropped > 0 and string.format(" (%d Platzhalter verworfen)", Dropped) or ""))
    if Dropped > 0 then CacheDirty = true end
end

--==========================================================================--
-- Overlay-Text
--==========================================================================--

--[[
    Aus dem Cache wird nicht mehr ein Textblock, sondern ein Zeilenmodell: je
    Eintrag Text plus die Angabe, was ein Klick darauf bedeutet.

      kind = "type"     Gebaeudename       -> zu einem Gebaeude dieses Typs springen
      kind = "upgrade"  offenes Upgrade    -> kaufen (bzw. erst hinspringen)
      kind = "info"     nichts anklickbar  (erledigte Upgrades, Hinweistexte)

    Die Zeilen kommen je in einen eigenen Button. Erledigtes bleibt bewusst
    unklickbar - ein zweiter Kauf waere sinnlos, und jeder nicht ausgeloeste
    C++-Aufruf ist einer weniger, der schiefgehen kann.
]]
local Notice = { Text = nil, Ticks = 0 }

-- Gebaeudezahl je Typ, aus der Gebaeudetabelle gezaehlt. Steht hier oben, weil
-- der Zeilentext sie braucht; gefuellt wird sie weiter unten, wo die Tabelle
-- ohnehin durchlaufen wird.
local BuildingCounts = {}
local CountBuildingsHook = nil

local function BuildHeaderText(TypeCount, OpenCount)
    local Mark = Settings.collapsed and "[+]" or "[-]"
    local Body
    if Notice.Text and Notice.Ticks > 0 then
        Body = Notice.Text
    elseif TypeCount == 0 then
        Body = "KR Upgrade-Uebersicht - noch nichts erfasst"
    else
        Body = string.format("KR Upgrade-Uebersicht - %d Gebaeudetypen, %d offen",
            TypeCount, OpenCount)
    end
    return string.format("%s  %s", Mark, Body)
end

local function BuildRowModel()
    local Keys = SortedKeys(Cache)
    local Rows, TotalOpen = {}, 0

    if #Keys == 0 then
        Rows[1] = { kind = "info",
            cells = { "Klicke Gebaeude an - die Liste fuellt sich von selbst.", "", "" } }
        return Rows, 0, 0
    end

    for _, Key in ipairs(Keys) do
        local E = Cache[Key]
        local Done = 0
        for _, U in ipairs(E.upgrades) do
            if U.state == "done" then Done = Done + 1 end
            if U.state == "open" then TotalOpen = TotalOpen + 1 end
        end

        -- "(2/4)" sind die Upgrades, nicht die Gebaeude - das war
        -- missverstaendlich. Also in getrennte Spalten, beides beschriftet.
        local N = BuildingCounts[Key]
        Rows[#Rows + 1] = {
            kind = "type", key = Key,
            cells = { Key,
                      string.format("%d/%d Upgrades", Done, #E.upgrades),
                      N and string.format("%d Gebaeude", N) or "" },
        }

        -- Upgrades ruecken ein, damit die Gebaeudenamen die Gliederung tragen.
        for _, U in ipairs(E.upgrades) do
            local Name = "    " .. U.label
            if U.state == "done" then
                Rows[#Rows + 1] = { kind = "info", dim = true,
                    cells = { Name, "", "erledigt" } }
            elseif U.state == "open" then
                Rows[#Rows + 1] = { kind = "upgrade", key = Key, label = U.label,
                    cells = { Name, U.cost or "?",
                              U.affordable and "offen" or "zu teuer" } }
            else
                Rows[#Rows + 1] = { kind = "info", dim = true,
                    cells = { Name, "", "?" } }
            end
        end
    end

    return Rows, #Keys, TotalOpen
end

--==========================================================================--
-- Overlay-Widget
--==========================================================================--

local Overlay = {
    Root = nil, Box = nil, Scroll = nil, Canvas = nil, Slot = nil, Window = nil,
    HeaderBtn = nil, HeaderText = nil, ColumnHead = nil,
    Switcher = nil, PaneIndex = nil, Shown = nil,
    Attempts = 0, Mounted = false,
    Rows = {},          -- Pool: { Btn, Text, Model, Pressed }
    RowCount = 0,       -- davon gerade in Benutzung
}
local MAX_BUILD_ATTEMPTS = 30
local PANEL_ZORDER = 1000

-- Der Pool waechst nur bis hierher. 24 Gebaeudetypen mit je vier Upgrades
-- ergeben rund 120 Zeilen; die Grenze faengt den Fall ab, dass der Cache durch
-- einen Fehler ins Kraut schiesst und der Mod tausende Widgets baut.
local MAX_ROWS = 400

-- Beim Aufbau einmal aufgeloest, danach fuer jede nachgebaute Zeile
-- wiederverwendet. StaticFindObject je Zeile waere nur Arbeit ohne Ertrag.
local WidgetClasses = nil
local ROW_FONT_SIZE = 12

--[[
    Spalten.

    Angegeben als Anteil der Panelbreite, nicht in Pixeln: die Breite des
    Panels ergibt sich selbst erst aus einem Anteil der Canvas-Flaeche, und
    Pixel waeren hier so wenig zu bekommen wie bei der Fenstergroesse.

    ESlateSizeRule: 0 Automatic, 1 Fill.
    EHorizontalAlignment: 0 Fill, 1 Left, 2 Center, 3 Right.
    EVerticalAlignment:   0 Fill, 1 Top,  2 Center, 3 Bottom.
]]
local COLUMNS = {
    { key = "name",  width = 0.58, align = 1 },  -- Gebaeude bzw. Upgrade
    { key = "cost",  width = 0.22, align = 1 },  -- Preis
    { key = "state", width = 0.20, align = 1 },  -- Stand bzw. Anzahl
}

local COLUMN_TITLES = {
    name  = "Gebaeude / Upgrade",
    cost  = "Kosten",
    state = "Stand",
}

local DIM_DONE = 0.45   -- erledigte Zeilen abdunkeln statt sie wegzulassen

-- Gemeinsame Grundlage von Kopf- und Datenzeilen. Beide sind ein Button, auch
-- der Spaltenkopf: dessen Innenabstaende sind sonst andere als die der Zeilen,
-- und die Spalten stuenden um ein paar Pixel versetzt.
local function NewRowShell(Outer)
    local Btn = StaticConstructObject(WidgetClasses.Button, Outer)
    -- Der frisch konstruierte UMG.Button bringt den grauen Standardhintergrund
    -- mit - hundert graue Kaesten uebereinander waeren unlesbar. Also auf
    -- durchsichtig setzen. Anklickbar bleibt er trotzdem: die Trefferflaeche
    -- von SButton haengt an der Sichtbarkeit, nicht am Pinsel.
    pcall(function() Btn:SetBackgroundColor({ R = 1.0, G = 1.0, B = 1.0, A = 0.0 }) end)
    return Btn
end

local function StyleCellText(Text)
    pcall(function()
        local Font = Text.Font
        Font.Size = ROW_FONT_SIZE
        Text:SetFont(Font)
    end)
    -- Umbrechen wuerde die Zeilenhoehe springen lassen und die Tabelle
    -- zerreissen; lieber laesst man einen langen Namen rechts auslaufen.
    pcall(function() Text:SetAutoWrapText(false) end)
end

--[[
    Eine Datenzeile: Button > HorizontalBox > je Spalte ein TextBlock.

    Das Zentrieren kam vom UButtonSlot, der seinen Inhalt von Haus aus mittig
    setzt - deshalb stand vorher alles in der Mitte und war als Liste kaum zu
    lesen. HAlign_Fill gibt der HorizontalBox die volle Breite, erst dann
    greifen die Spaltenanteile.
]]
local function MakeRowButton(Outer)
    local Btn  = NewRowShell(Outer)
    local HBox = StaticConstructObject(WidgetClasses.HBox, Outer)

    local Slot = nil
    pcall(function() Slot = Btn:AddChild(HBox) end)
    if IsValidObj(Slot) then
        pcall(function() Slot:SetHorizontalAlignment(0) end)
        pcall(function() Slot:SetVerticalAlignment(2) end)
        pcall(function() Slot:SetPadding({ Left = 2.0, Top = 1.0, Right = 2.0, Bottom = 1.0 }) end)
    end

    local Cells = {}
    for i, Col in ipairs(COLUMNS) do
        local Text = StaticConstructObject(WidgetClasses.Text, Outer)
        StyleCellText(Text)
        local CSlot = nil
        pcall(function() CSlot = HBox:AddChildToHorizontalBox(Text) end)
        if IsValidObj(CSlot) then
            pcall(function() CSlot:SetSize({ Value = Col.width, SizeRule = 1 }) end)
            pcall(function() CSlot:SetHorizontalAlignment(Col.align) end)
            pcall(function() CSlot:SetPadding({ Left = 4.0, Top = 0.0, Right = 4.0, Bottom = 0.0 }) end)
        end
        Cells[i] = Text
    end

    return Btn, Cells
end

-- Die Kopfzeile ganz oben spannt sich ueber die volle Breite und hat keine
-- Spalten; sie traegt den Umschalter und die Rueckmeldung auf einen Klick.
local function MakeBarButton(Outer)
    local Btn  = NewRowShell(Outer)
    local Text = StaticConstructObject(WidgetClasses.Text, Outer)
    StyleCellText(Text)

    local Slot = nil
    pcall(function() Slot = Btn:AddChild(Text) end)
    if IsValidObj(Slot) then
        pcall(function() Slot:SetHorizontalAlignment(1) end)
        pcall(function() Slot:SetVerticalAlignment(2) end)
        pcall(function() Slot:SetPadding({ Left = 6.0, Top = 2.0, Right = 6.0, Bottom = 2.0 }) end)
    end
    return Btn, Text
end

-- Vorwaerts deklariert: der Aufbau des Panels braucht beide, definiert sind
-- sie weiter unten, weil sie das fertige Panel voraussetzen.
local RefreshOverlay, ApplyCollapsed

-- Zahlen defensiv formatieren: fehlt ein Wert, soll die Diagnosezeile das
-- zeigen und nicht den Aufbau mit einem format-Fehler abbrechen.
local function N(V) return type(V) == "number" and string.format("%.4g", V) or "?" end

local function Num(V) if type(V) == "number" then return V end return nil end

-- Wird weiter unten gesetzt, sobald RunDump existiert. Erlaubt der
-- Overlay-Logik, im Problemfall einen Diagnosedump anzustossen, ohne dass
-- jemand eine Taste druecken muss.
local AutoDumpHook = nil

--[[
    Anker ist der Root-CanvasPanel der StatisticsUI.

    v4 hat das Panel in StatisticsUI.BuildingsStatBox gehaengt. Das hat das
    Spiel beim Oeffnen des Statistik-Fensters zerlegt:

        EXCEPTION_ACCESS_VIOLATION reading address 0x00000000
        UStatisticsUI::TickUI()          [StatisticsUI.cpp:428]
          -> lambda                      [StatisticsUI.cpp:344]

    TickUI laeuft durch die Kinder von BuildingsStatBox und behandelt jedes als
    BuildingStatTableRow. Unser UMG.Border ist keine; der Cast liefert nullptr
    und der naechste Zugriff liest von 0x0. Jedes Fremdkind in einer von C++
    befuellten Box ist damit toedlich, und EnsureAttached hat es nach jedem
    Neuaufbau der Liste brav wieder hineingehaengt.

    Der Root-Canvas ist dagegen reines Blueprint-Layout. C++ greift dort nur
    ueber benannte Zeiger zu (StatSwitcher 0x348, BuildingsStatBox 0x378, ... -
    siehe UE4SS_ObjectDump.txt), nie ueber GetChildAt. Genau dort hing das
    Panel in v3, und v3 lief stabil.

    Was v3 fehlte, war die Geometrie: der Slot blieb auf Standardwerten, das
    Panel lag oben links am Bildschirm - links vom Spiel-HUD beschnitten,
    rechts vom Fenster ueberdeckt. Diesmal bekommt der CanvasPanelSlot Anker
    und Ausrichtung des Fensters selbst und wird in dessen rechte Haelfte
    gesetzt, mit ZOrder ueber dem Fenster. Auf der Fensterflaeche ist Sichtbar-
    keit garantiert: das HUD liegt zwar ueber der StatisticsUI, aber das
    Fenster ist ja selbst zu sehen.
]]

local function ChildCount(W)
    local ok, n = pcall(function() return W:GetChildrenCount() end)
    if ok and type(n) == "number" then return n end
    return 0
end

local function ChildAt(W, Index)
    local ok, C = pcall(function() return W:GetChildAt(Index) end)
    if ok and IsValidObj(C) then return C end
    return nil
end

-- Vergleich ueber den Pfadnamen: zwei Lua-Wrapper desselben UObjects sind
-- nicht zwingend dasselbe Lua-Objekt.
local function ContainsWidget(Node, NeedleName, Depth)
    Depth = Depth or 0
    if not IsValidObj(Node) or Depth > 8 then return false end
    if FullName(Node) == NeedleName then return true end
    for i = 0, ChildCount(Node) - 1 do
        if ContainsWidget(ChildAt(Node, i), NeedleName, Depth + 1) then return true end
    end
    return false
end

local function FindCanvas(Node, Depth)
    Depth = Depth or 0
    if not IsValidObj(Node) or Depth > 4 then return nil end
    if ClassName(Node) == "CanvasPanel" then return Node end
    for i = 0, ChildCount(Node) - 1 do
        local Found = FindCanvas(ChildAt(Node, i), Depth + 1)
        if Found then return Found end
    end
    return nil
end

local function GetStatUI()
    local HUD = GetHUD(false)
    if not HUD then return nil end
    local UI = nil
    pcall(function() UI = HUD["_statisticsUI"] end)
    if not IsValidObj(UI) then return nil end
    return UI
end

local function GetStatCanvas(StatUI)
    local Tree = nil
    pcall(function() Tree = StatUI["WidgetTree"] end)
    if not IsValidObj(Tree) then return nil end
    local Root = nil
    pcall(function() Root = Tree["RootWidget"] end)
    if not IsValidObj(Root) then return nil end
    return FindCanvas(Root, 0)
end

local function SetWidgetVisible(W, Visible)
    -- ESlateVisibility: 0 Visible, 1 Collapsed, 2 Hidden,
    -- 3 HitTestInvisible, 4 SelfHitTestInvisible
    pcall(function() W:SetVisibility(Visible and 0 or 1) end)
end
--==========================================================================--
-- Geometrie schreiben
--
-- Der v6-Lauf am 2026-07-26 hat die offenen Fragen beantwortet:
--
--   Panel: ist  pos=(20,-260) groesse=(430,560) ausrichtung=(0,0)
--               anker=(0,0)-(0,0) autosize=false zorder=1000
--
--   * SetPosition/SetSize/SetAlignment mit Lua-Tabellen greifen sehr wohl -
--     alle drei Werte standen hinterher im Slot.
--   * SetAnchors greift NICHT. Der Anker blieb auf (0,0), also oben links.
--     Der Unterschied zu den anderen: FAnchors ist verschachtelt
--     ({Minimum={X,Y}, Maximum={X,Y}}), FVector2D ist flach.
--   * Damit lag das Panel bei y = -260 zu 260 Pixeln ueber dem Bildschirmrand,
--     der Rest hinter der Rohstoffleiste des HUD. Genau wie v3.
--   * GetCachedGeometry liefert ueber UE4SS nur 0x0, taugt hier also nicht
--     zum Messen - und die SizeBox des Fensters hat keine Overrides. Die
--     Fenstergroesse ist auf diesem Weg schlicht nicht zu bekommen.
--
-- Daraus folgt der Aufbau von v7: die Lage wird gar nicht mehr in Pixeln
-- gerechnet, sondern ueber gestreckte Anker als ANTEIL der Canvas-Flaeche.
-- Anker Minimum/Maximum spannen das Rechteck auf, alle vier Offsets sind
-- null - dann braucht es weder Fenstergroesse noch Bildschirmaufloesung.
--
-- Die Anker muessen dafuer sitzen. Weil der Setter das nicht kann, werden sie
-- ueber die reflektierte Property LayoutData geschrieben und mit
-- SetLayout(GetLayout()) an den lebenden Slate-Slot durchgereicht - dieser
-- Aufruf ist im Spiel belegt. Danach wird zurueckgelesen; klappt auch das
-- nicht, bleibt der Rueckfall in Pixeln ueber die Viewport-Groesse.
--
-- Feldnamen aus UE4SS_ObjectDump.txt:
--   UMG.AnchorData    offsets (FMargin), Anchors (FAnchors), Alignment (FVector2D)
--   Slate.Anchors     Minimum, Maximum (FVector2D)
--   SlateCore.Margin  Left, Top, Right, Bottom
--==========================================================================--

--[[
    Wo das Panel liegt, als Anteil der Canvas-Flaeche.

    Aus dem Screenshot vom 2026-07-26 ausgemessen (Fenster waagerecht 22,8 %
    bis 77,4 %, senkrecht 15,1 % bis 84,4 % - das Fenster ist also mittig, die
    frueher notierte Verschiebung nach rechts war ein Schaetzfehler). Links im
    Fenster liegt die Tab-Spalte bis etwa 37 %, die bleibt frei; das Panel
    deckt die Gebaeudetabelle ab.
]]
local PANEL_FRACTION = { L = 0.395, T = 0.205, R = 0.760, B = 0.800 }

-- Zugeklappt bleibt nur die Kopfzeile stehen. Der Streifen ist absichtlich
-- schmal: darunter soll die Gebaeudetabelle wieder sichtbar und anklickbar
-- sein, sonst braeuchte es den Umschalter gar nicht.
local PANEL_FRACTION_COLLAPSED = { L = 0.395, T = 0.205, R = 0.760, B = 0.245 }

local function CurrentFraction()
    if Settings.collapsed then return PANEL_FRACTION_COLLAPSED end
    return PANEL_FRACTION
end

local function SlotState(Slot)
    local S = {}
    if not IsValidObj(Slot) then return S end
    pcall(function() local P = Slot:GetPosition() S.L, S.T = P.X, P.Y end)
    pcall(function() local Z = Slot:GetSize()     S.R, S.B = Z.X, Z.Y end)
    pcall(function() local A = Slot:GetAlignment() S.AX, S.AY = A.X, A.Y end)
    pcall(function()
        local A = Slot:GetAnchors()
        S.AnMinX, S.AnMinY = A.Minimum.X, A.Minimum.Y
        S.AnMaxX, S.AnMaxY = A.Maximum.X, A.Maximum.Y
    end)
    pcall(function() S.Auto = Slot:GetAutoSize() end)
    pcall(function() S.Z = Slot:GetZOrder() end)
    return S
end

local function SlotText(S)
    return string.format("offsets=(%s,%s,%s,%s) ausrichtung=(%s,%s) anker=(%s,%s)-(%s,%s) autosize=%s zorder=%s",
        N(S.L), N(S.T), N(S.R), N(S.B), N(S.AX), N(S.AY),
        N(S.AnMinX), N(S.AnMinY), N(S.AnMaxX), N(S.AnMaxY),
        tostring(S.Auto), N(S.Z))
end

-- Anker laufen von 0 bis 1: ein Vergleich mit derselben Toleranz wie fuer
-- Pixel wuerde 0 und 0.5 fuer gleich halten. Genau das ist in v6 passiert -
-- die Pruefung hat den falschen Anker durchgewinkt und die Nachbesserung nie
-- ausgeloest.
local function Near(A, B, Eps)
    return type(A) == "number" and math.abs(A - B) < (Eps or 0.6)
end

local function SlotMatches(S, Want)
    return Near(S.L, Want.L) and Near(S.T, Want.T)
       and Near(S.R, Want.R) and Near(S.B, Want.B)
       and Near(S.AX, 0.0, 0.01) and Near(S.AY, 0.0, 0.01)
       and Near(S.AnMinX, Want.AnMinX, 0.01) and Near(S.AnMinY, Want.AnMinY, 0.01)
       and Near(S.AnMaxX, Want.AnMaxX, 0.01) and Near(S.AnMaxY, Want.AnMaxY, 0.01)
end

-- Diese drei greifen im Spiel (v6 belegt). SetAnchors fehlt hier bewusst: der
-- Aufruf laeuft zwar durch, setzt aber nichts.
local function WriteViaSetters(Slot, Want)
    pcall(function() Slot:SetAlignment({ X = 0.0, Y = 0.0 }) end)
    pcall(function() Slot:SetPosition({ X = Want.L, Y = Want.T }) end)
    pcall(function() Slot:SetSize({ X = Want.R, Y = Want.B }) end)
    pcall(function()
        Slot:SetAnchors({ Minimum = { X = Want.AnMinX, Y = Want.AnMinY },
                          Maximum = { X = Want.AnMaxX, Y = Want.AnMaxY } })
    end)
end

local function WriteViaLayoutData(Slot, Want)
    local Written = pcall(function()
        local LD = Slot.LayoutData

        -- Im Dump heisst das Feld klein geschrieben ("offsets"). FName-Suche
        -- ist zwar unabhaengig von Gross- und Kleinschreibung, aber der Umweg
        -- kostet nichts.
        local Off = nil
        pcall(function() Off = LD.Offsets end)
        if not Off then pcall(function() Off = LD.offsets end) end
        Off.Left, Off.Top    = Want.L, Want.T
        Off.Right, Off.Bottom = Want.R, Want.B

        LD.Anchors.Minimum.X, LD.Anchors.Minimum.Y = Want.AnMinX, Want.AnMinY
        LD.Anchors.Maximum.X, LD.Anchors.Maximum.Y = Want.AnMaxX, Want.AnMaxY
        LD.Alignment.X, LD.Alignment.Y = 0.0, 0.0
    end)
    -- Durchreichen an den lebenden Slate-Slot, auch wenn oben nur ein Teil
    -- ankam: ein halb gesetztes LayoutData ist immer noch besser als keins.
    pcall(function() Slot:SetLayout(Slot:GetLayout()) end)
    return Written
end

local function ApplySlot(Slot, Want)
    pcall(function() Slot:SetAutoSize(false) end)
    pcall(function() Slot:SetZOrder(PANEL_ZORDER) end)

    -- LayoutData zuerst: nur dieser Weg bekommt die Anker gesetzt.
    WriteViaLayoutData(Slot, Want)
    local S = SlotState(Slot)
    local Method = "LayoutData"
    if not SlotMatches(S, Want) then
        WriteViaSetters(Slot, Want)
        S = SlotState(Slot)
        Method = "LayoutData+Setter"
    end
    return S, Method, SlotMatches(S, Want)
end

--==========================================================================--
-- Canvas-Groesse (nur fuer den Rueckfall)
--
-- Greifen die Anker auch ueber LayoutData nicht, bleiben sie auf (0,0) - oben
-- links. Dann hilft nur noch Rechnen in Pixeln, und dafuer braucht es die
-- Groesse der Zeichenflaeche. GetCachedGeometry liefert ueber UE4SS 0x0,
-- WidgetLayoutLibrary.GetViewportSize dagegen echte Zahlen; geteilt durch
-- GetViewportScale ergibt das die Canvas-Groesse in Slate-Einheiten.
--==========================================================================--

local LayoutLib = nil

local function GetLayoutLib()
    if IsValidObj(LayoutLib) then return LayoutLib end
    local ok, L = pcall(StaticFindObject, "/Script/UMG.Default__WidgetLayoutLibrary")
    if ok and IsValidObj(L) then LayoutLib = L return L end
    return nil
end

local function CanvasSize()
    local Lib, HUD = GetLayoutLib(), GetHUD(false)
    if not Lib or not HUD then return nil end
    local X, Y, Scale
    pcall(function() local S = Lib:GetViewportSize(HUD) X, Y = S.X, S.Y end)
    pcall(function() Scale = Lib:GetViewportScale(HUD) end)
    if not (Num(X) and Num(Y)) or X < 1 or Y < 1 then return nil end
    if Num(Scale) and Scale > 0.01 then X, Y = X / Scale, Y / Scale end
    return X, Y
end

--==========================================================================--
-- Platzieren
--==========================================================================--

-- Nur fuer die Logzeile: der echte Root-Canvas hat genau ein Kind, naemlich
-- das Fenster (SizeBox). Die Geometrie kommt nicht mehr von dort.
local function FindWindow(Canvas)
    local OwnName = IsValidObj(Overlay.Root) and FullName(Overlay.Root) or nil
    for i = 0, math.min(ChildCount(Canvas), 16) - 1 do
        local Child = ChildAt(Canvas, i)
        if Child and (not OwnName or FullName(Child) ~= OwnName) then
            local Slot = nil
            pcall(function() Slot = Child.Slot end)
            return { Widget = Child, Slot = Slot, State = SlotState(Slot) }
        end
    end
    return {}
end

local function PlacePanel(Slot, Canvas)
    local Win = FindWindow(Canvas)
    Overlay.Window = Win.Widget

    local F = CurrentFraction()
    local Want = {
        AnMinX = F.L, AnMinY = F.T, AnMaxX = F.R, AnMaxY = F.B,
        L = 0.0, T = 0.0, R = 0.0, B = 0.0,
    }
    local S, Method, Ok = ApplySlot(Slot, Want)
    local Mode = "Anteil der Canvas-Flaeche"

    if not Ok then
        -- Anker sitzen nicht. In Pixeln von oben links rechnen, dafuer muss
        -- die Canvas-Groesse bekannt sein.
        local CW, CH = CanvasSize()
        if Num(CW) then
            Want = {
                AnMinX = 0.0, AnMinY = 0.0, AnMaxX = 0.0, AnMaxY = 0.0,
                L = F.L * CW, T = F.T * CH,
                R = (F.R - F.L) * CW, B = (F.B - F.T) * CH,
            }
            S, Method, Ok = ApplySlot(Slot, Want)
            Mode = string.format("Rueckfall in Pixeln, Canvas %sx%s", N(CW), N(CH))
        else
            Mode = "Anker sitzen nicht und Canvas-Groesse unbekannt"
        end
    end

    return { Want = Want, State = S, Method = Method, Ok = Ok, Mode = Mode,
             WinState = Win.State }
end

-- Der WidgetSwitcher blendet je Tab genau eine Seite ein. Welche davon die
-- Gebaeudeseite ist, wird gesucht statt geraten: es ist die, in deren
-- Unterbaum BuildingsStatBox haengt. Nur dort soll das Panel zu sehen sein.
local function FindBuildingsPane(StatUI)
    local Switcher = nil
    pcall(function() Switcher = StatUI["StatSwitcher"] end)
    if not IsValidObj(Switcher) then return nil, nil end

    local Box = nil
    pcall(function() Box = StatUI["BuildingsStatBox"] end)
    if not IsValidObj(Box) then return Switcher, nil end

    local BoxName = FullName(Box)
    for i = 0, ChildCount(Switcher) - 1 do
        if ContainsWidget(ChildAt(Switcher, i), BoxName, 0) then
            return Switcher, i
        end
    end
    return Switcher, nil
end

--[[
    Panelfarbe.

    Ein frisch konstruierter UMG.Border traegt einen Pinsel ohne Textur und
    zeichnet damit ein weisses Rechteck - auf weisser Schrift waere der Inhalt
    unlesbar. Deshalb dieselbe Vorsicht wie beim Slot: setzen, zuruecklesen
    (Border.BrushColor ist als FLinearColor reflektiert), und notfalls die
    Property direkt beschreiben und ueber den Setter durchreichen.
]]
-- Deckend, nicht durchscheinend. Mit A = 0.88 stand die Gebaeudetabelle des
-- Spiels hinter der Schrift und machte sie schwer lesbar - der Hintergrund
-- muss die Flaeche wirklich abdecken.
local PANEL_COLOR = { R = 0.04, G = 0.04, B = 0.045, A = 1.0 }

local function SetPanelColor(Border)
    pcall(function() Border:SetBrushColor(PANEL_COLOR) end)

    local R = nil
    pcall(function() R = Border.BrushColor.R end)
    if Near(R, PANEL_COLOR.R) then return "Setter" end

    local Written = pcall(function()
        local C = Border.BrushColor
        C.R, C.G, C.B, C.A = PANEL_COLOR.R, PANEL_COLOR.G, PANEL_COLOR.B, PANEL_COLOR.A
    end)
    pcall(function() Border:SetBrushColor(Border.BrushColor) end)
    pcall(function() R = Border.BrushColor.R end)
    if Near(R, PANEL_COLOR.R) then return "Property" end
    return Written and "unbestaetigt" or "fehlgeschlagen"
end

local function LogPlacement(P)
    if not P then
        Log("  Panel:   ohne Slot angehaengt, Position vom Spiel bestimmt")
        return
    end
    Log(string.format("  Fenster: slot %s", SlotText(P.WinState or {})))
    Log(string.format("  Panel:   soll offsets=(%s,%s,%s,%s) anker=(%s,%s)-(%s,%s) [%s]",
        N(P.Want.L), N(P.Want.T), N(P.Want.R), N(P.Want.B),
        N(P.Want.AnMinX), N(P.Want.AnMinY), N(P.Want.AnMaxX), N(P.Want.AnMaxY),
        P.Mode))
    -- Das ist die Zeile, die v5 gefehlt hat: nicht der Wunsch, sondern das,
    -- was der Slot hinterher wirklich sagt.
    Log(string.format("  Panel:   ist  %s", SlotText(P.State)))
    Log(string.format("  Panel:   geschrieben ueber %s, uebernommen=%s",
        P.Method, tostring(P.Ok)))
end

local function BuildOverlay()
    if Overlay.Attempts >= MAX_BUILD_ATTEMPTS then return false end

    -- Noch keine StatisticsUI: das ist im Hauptmenue der Normalfall und zaehlt
    -- nicht als Fehlversuch, sonst waere das Budget nach 30 Sekunden Menue
    -- aufgebraucht.
    local StatUI = GetStatUI()
    if not StatUI then return false end
    local Canvas = GetStatCanvas(StatUI)
    if not Canvas then return false end

    Overlay.Attempts = Overlay.Attempts + 1

    local Placed, ColorMethod = nil, "?"

    local ok, err = pcall(function()
        local BorderClass = StaticFindObject("/Script/UMG.Border")
        local ScrollClass = StaticFindObject("/Script/UMG.ScrollBox")
        local TextClass   = StaticFindObject("/Script/UMG.TextBlock")
        local BoxClass    = StaticFindObject("/Script/UMG.VerticalBox")
        local ButtonClass = StaticFindObject("/Script/UMG.Button")
        if not BorderClass or not ScrollClass or not TextClass
            or not BoxClass or not ButtonClass then
            error("UMG-Klassen nicht auffindbar")
        end
        local HBoxClass = StaticFindObject("/Script/UMG.HorizontalBox")
        if not HBoxClass then error("UMG.HorizontalBox nicht auffindbar") end
        WidgetClasses = { Text = TextClass, Button = ButtonClass, HBox = HBoxClass }

        --  Border                          Hintergrund und Aussenrand
        --    VerticalBox                   Kopfzeile / Spaltenkopf / Liste
        --      Button > TextBlock          Kopfzeile, klappt auf und zu
        --      Button > HorizontalBox      Spaltenkopf, scrollt nicht mit
        --      ScrollBox                   die Liste, waechst mit dem Cache
        --        Button > HorizontalBox    je Zeile, aus dem Pool
        --
        -- Alles davon gehoert uns; kein C++-Code laeuft durch diese Kinder.
        -- Genau daran ist v4 gestorben (Fremdkind in BuildingsStatBox).
        local Border = StaticConstructObject(BorderClass, Canvas)
        local Box    = StaticConstructObject(BoxClass, Canvas)
        local Scroll = StaticConstructObject(ScrollClass, Canvas)

        local HeaderBtn, HeaderText = MakeBarButton(Canvas)
        HeaderText:SetText(FText(BuildHeaderText(0, 0)))

        -- Der Spaltenkopf wird bewusst wie eine Zeile gebaut, samt Button:
        -- sonst haette er andere Innenabstaende als die Zeilen darunter und
        -- die Spalten stuenden versetzt.
        local ColBtn, ColCells = MakeRowButton(Canvas)
        for i, Col in ipairs(COLUMNS) do
            pcall(function() ColCells[i]:SetText(FText(COLUMN_TITLES[Col.key])) end)
        end

        Box:AddChild(HeaderBtn)
        Box:AddChild(ColBtn)
        Overlay.ColumnHead = ColBtn
        local ScrollSlot = Box:AddChild(Scroll)
        -- Ohne Fuellregel bleibt die ScrollBox auf ihrer Wunschhoehe stehen und
        -- die Liste nutzt das Panel nicht aus. ESlateSizeRule: 0 Automatic,
        -- 1 Fill. FSlateChildSize ist flach, geht also als Tabelle durch.
        pcall(function()
            if IsValidObj(ScrollSlot) then
                ScrollSlot:SetSize({ Value = 1.0, SizeRule = 1 })
            end
        end)

        Border:SetContent(Box)
        ColorMethod = SetPanelColor(Border)
        pcall(function() Border:SetPadding({ Left = 10.0, Top = 8.0, Right = 10.0, Bottom = 8.0 }) end)

        local Slot = nil
        pcall(function() Slot = Canvas:AddChildToCanvas(Border) end)
        if not IsValidObj(Slot) then
            -- Ohne Slot keine Geometrie, aber immer noch ein sichtbares Panel.
            pcall(function() Canvas:AddChild(Border) end)
        end

        Overlay.Root, Overlay.Box, Overlay.Scroll, Overlay.Slot = Border, Box, Scroll, Slot
        Overlay.HeaderBtn, Overlay.HeaderText = HeaderBtn, HeaderText
        Overlay.Canvas = Canvas
        -- Der Zeilenpool gehoerte zur alten ScrollBox. Nach einem Neuaufbau -
        -- etwa beim Partiewechsel - zeigen seine Eintraege auf Widgets, die in
        -- keinem Baum mehr haengen; sie wuerden nie wieder sichtbar.
        Overlay.Rows, Overlay.RowCount = {}, 0
        if IsValidObj(Slot) then
            Placed = PlacePanel(Slot, Canvas)
            Overlay.Placed = Placed
        end
    end)

    if not ok then
        Log(string.format("Overlay-Aufbau fehlgeschlagen (Versuch %d/%d): %s",
            Overlay.Attempts, MAX_BUILD_ATTEMPTS, tostring(err)))
        Overlay.Root, Overlay.Box, Overlay.Scroll = nil, nil, nil
        Overlay.HeaderBtn, Overlay.HeaderText, Overlay.ColumnHead = nil, nil, nil
        Overlay.Slot, Overlay.Canvas = nil, nil
        Overlay.Rows, Overlay.RowCount = {}, 0
        if Overlay.Attempts >= MAX_BUILD_ATTEMPTS and AutoDumpHook then
            -- Aufgegeben: einmal die StatisticsUI mitschreiben, damit sich der
            -- Fehler ohne Zutun des Spielers nachvollziehen laesst.
            AutoDumpHook("statistics")
        end
        return false
    end

    Overlay.Switcher, Overlay.PaneIndex = FindBuildingsPane(StatUI)
    Overlay.Shown = nil
    SetWidgetVisible(Overlay.Root, true)
    Overlay.Mounted = true

    Log("Overlay im Root-Canvas der StatisticsUI (nicht mehr in BuildingsStatBox).")
    LogPlacement(Placed)
    Log(string.format("  Farbe:   ueber %s gesetzt", ColorMethod))
    Log(string.format("  Gebaeude-Tab: StatSwitcher=%s, Seitenindex=%s",
        IsValidObj(Overlay.Switcher) and "ja" or "nein", tostring(Overlay.PaneIndex)))

    -- Fuellt die Liste und stellt den gemerkten Auf-/Zuklappzustand her.
    pcall(ApplyCollapsed)
    Log(string.format("  Zeilen:  %d gebaut, Panel %s", Overlay.RowCount,
        Settings.collapsed and "zugeklappt" or "aufgeklappt"))
    return true
end

-- Der Canvas ist statisches Blueprint-Layout, trotzdem billig zu pruefen: bei
-- einem Wechsel der Partie kann die UI neu aufgebaut werden. Ist unser Panel
-- weg, reicht erneutes Anhaengen samt Geometrie - neu bauen muss man es nicht.
local function EnsureAttached()
    if not IsValidObj(Overlay.Root) or not IsValidObj(Overlay.Canvas) then return end
    local ok, has = pcall(function() return Overlay.Canvas:HasChild(Overlay.Root) end)
    if ok and has == false then
        local Slot = nil
        pcall(function() Slot = Overlay.Canvas:AddChildToCanvas(Overlay.Root) end)
        if IsValidObj(Slot) then
            Overlay.Slot = Slot
            Overlay.Placed = PlacePanel(Slot, Overlay.Canvas)
        end
    end
end

-- Sichtbar nur im Gebaeude-Tab. Laesst sich der aktive Tab nicht lesen, bleibt
-- das Panel sichtbar: lieber im Weg als unauffindbar.
local function UpdateVisibility()
    if not IsValidObj(Overlay.Root) then return end
    local Show = true
    if Overlay.PaneIndex and IsValidObj(Overlay.Switcher) then
        local Active = nil
        pcall(function() Active = Overlay.Switcher:GetActiveWidgetIndex() end)
        if type(Active) == "number" then Show = (Active == Overlay.PaneIndex) end
    end
    if Show ~= Overlay.Shown then
        Overlay.Shown = Show
        SetWidgetVisible(Overlay.Root, Show)
    end
end

--[[
    Zeilen erzeugen kostet Widgets, also werden sie einmal gebaut und danach
    nur noch umbeschriftet. Ueberzaehlige verschwinden ueber Collapsed statt
    zerstoert zu werden - ein Widget aus der Hierarchie zu loesen, waehrend
    Slate es womoeglich gerade zeichnet, ist genau die Sorte Wette, die den
    Abstuerzen in v1/v2 zugrunde lag.
]]
function RefreshOverlay()
    if not IsValidObj(Overlay.Root) then return end

    -- Ein Durchlauf durch die Gebaeudetabelle je Auffrischung, nicht je Tick:
    -- gezaehlt wird nur, wenn sich am Inhalt etwas geaendert hat.
    if CountBuildingsHook then pcall(CountBuildingsHook) end

    local Model, TypeCount, OpenCount = BuildRowModel()
    pcall(function()
        Overlay.HeaderText:SetText(FText(BuildHeaderText(TypeCount, OpenCount)))
    end)

    if not IsValidObj(Overlay.Scroll) or not WidgetClasses then return end

    local Wanted = math.min(#Model, MAX_ROWS)
    for i = 1, Wanted do
        local R = Overlay.Rows[i]
        if not R then
            local ok, Btn, Cells = pcall(MakeRowButton, Overlay.Scroll)
            if not ok or not IsValidObj(Btn) or type(Cells) ~= "table" then break end
            pcall(function() Overlay.Scroll:AddChild(Btn) end)
            R = { Btn = Btn, Cells = Cells, Pressed = false }
            Overlay.Rows[i] = R
        end

        local M = Model[i]
        R.Model = M
        -- Erledigtes bleibt stehen, tritt aber zurueck: gestrichen waere die
        -- Information weg, gleich hell zoege es den Blick genauso an wie das,
        -- was noch zu tun ist.
        local Alpha = M.dim and DIM_DONE or 1.0
        for c = 1, #COLUMNS do
            local Cell = R.Cells[c]
            if IsValidObj(Cell) then
                pcall(function() Cell:SetText(FText((M.cells and M.cells[c]) or "")) end)
                if R.Alpha ~= Alpha then pcall(function() Cell:SetOpacity(Alpha) end) end
            end
        end
        R.Alpha = Alpha
        SetWidgetVisible(R.Btn, true)
    end

    for i = Wanted + 1, #Overlay.Rows do
        local R = Overlay.Rows[i]
        R.Model, R.Pressed = nil, false
        SetWidgetVisible(R.Btn, false)
    end

    Overlay.RowCount = Wanted
end

-- Auf- und zuklappen. Die Liste verschwindet, und der Slot wird auf den
-- schmalen Streifen umgerechnet - sonst laege ueber der Gebaeudetabelle
-- weiterhin eine unsichtbare, aber klickfangende Flaeche.
function ApplyCollapsed()
    if IsValidObj(Overlay.Scroll) then
        SetWidgetVisible(Overlay.Scroll, not Settings.collapsed)
    end
    -- Der Spaltenkopf gehoert zur Liste und geht mit ihr weg; zugeklappt
    -- bliebe sonst eine Beschriftung ohne Tabelle darunter stehen.
    if IsValidObj(Overlay.ColumnHead) then
        SetWidgetVisible(Overlay.ColumnHead, not Settings.collapsed)
    end
    if IsValidObj(Overlay.Slot) and IsValidObj(Overlay.Canvas) then
        Overlay.Placed = PlacePanel(Overlay.Slot, Overlay.Canvas)
    end
    RefreshOverlay()
end

local function ToggleCollapsed()
    Settings.collapsed = not Settings.collapsed
    ApplyCollapsed()
    CacheDirty = true
    Log(string.format("Panel %s", Settings.collapsed and "zugeklappt" or "aufgeklappt"))
end

--==========================================================================--
-- Handeln
--
-- Zwei Wege, beide ueber parameterlose UFunctions aus dem Object-Dump:
--
--   kaufen   PunButton:OnButtonDown / PunSplitButton:OnButtonDown1|2 auf dem
--            Upgradebutton im offenen Beschreibungspanel. Der traegt Gebaeude
--            und Callback-Enum schon in sich - es ist nichts zu setzen.
--   springen BuildingStatTableRow.GotoButton:OnButtonDown, also die Lupe in
--            der Gebaeudetabelle nebenan. Das ist die einzige aus Lua
--            erreichbare Moeglichkeit, ein bestimmtes Gebaeude auszuwaehlen;
--            DescriptionUISystem hat weder Funktionen noch Properties.
--==========================================================================--

local function SetNotice(Fmt, ...)
    Notice.Text = string.format(Fmt, ...)
    Notice.Ticks = 4
    pcall(RefreshOverlay)
    Log("Klick: " .. Notice.Text)
end

--[[
    Freigabe fuer einen C++-Klick.

    OnButtonDown dereferenziert _callbackParent. Steht der nicht, liest das
    Spiel von 0x0 - das war der EXCEPTION_ACCESS_VIOLATION aus v1/v2, und ein
    CDO aus FindAllOf traegt dort genau nichts. Die Property ist reflektiert,
    also laesst sich das vorher pruefen statt hinterher zu bereuen.
]]
local function ClickSafe(W)
    if not IsValidObj(W) or IsTemplate(W) then return false end
    local Parent = nil
    pcall(function() Parent = W["_callbackParent"] end)
    return IsValidObj(Parent)
end

local function CallHandler(W, FnName)
    if not ClickSafe(W) then return "Button nicht klickbar (_callbackParent fehlt)" end
    local ok, err = pcall(function() W[FnName](W) end)
    if not ok then return tostring(err) end
    return nil
end

-- Was gerade im Beschreibungspanel steht. Die Zeiger darin gelten nur bis zur
-- naechsten Auswahl, deshalb wird bei jedem Klick frisch gelesen statt
-- gemerkt.
local function LiveDescription()
    local DescUI = GetDescriptionUI(false)
    if not DescUI then return nil, nil end
    local S = ScrapeDescriptionPanel(DescUI)
    if not S then return nil, nil end
    return TypeKey(S.title), S
end

local function FireUpgrade(Key, Label)
    local LiveKey, S = LiveDescription()
    if not LiveKey then return "kein Gebaeude ausgewaehlt" end
    if LiveKey ~= Key then return string.format("ausgewaehlt ist %s", LiveKey) end

    local Hit = S.live and S.live[Label]
    if not Hit then return "Zeile im offenen Panel nicht gefunden" end
    return CallHandler(Hit.W, Hit.Fn)
end

--[[
    Die Gebaeudetabelle listet je Gebaeude eine Zeile, nicht je Typ - bei fuenf
    Imkereien stehen dort fuenf Zeilen "Beekeeper". Deshalb wird der ganze
    Unterbaum abgelaufen statt bei der ersten Zeile aufzuhoeren: sonst springt
    jeder Klick zum selben Gebaeude, und die uebrigen sind nur ueber die Pfeile
    im Beschreibungsfenster erreichbar.
]]
local function WalkStatRows(Node, Visit, Depth, Seen)
    Seen = Seen or { n = 0 }
    if not IsValidObj(Node) or (Depth or 0) > 4 or Seen.n >= MAX_ROWS then return Seen end

    if ClassName(Node):find("BuildingStatTableRow", 1, true) then
        Seen.n = Seen.n + 1
        -- BuildingName ist im Spiel ein Pun-Widget, das den Text erst eine
        -- Ebene tiefer haelt - wie ueberall hier, deshalb DeepText.
        local NameW = nil
        pcall(function() NameW = Node["BuildingName"] end)
        local T = IsValidObj(NameW) and DeepText(NameW, 0) or nil
        if T then Visit(TypeKey(T), Node) end
        return Seen
    end

    for i = 0, math.min(ChildCount(Node), MAX_ROWS) - 1 do
        WalkStatRows(ChildAt(Node, i), Visit, (Depth or 0) + 1, Seen)
    end
    return Seen
end

local function StatBox()
    local StatUI = GetStatUI()
    if not StatUI then return nil, "StatisticsUI nicht gefunden" end
    local Box = nil
    pcall(function() Box = StatUI["BuildingsStatBox"] end)
    if not IsValidObj(Box) then return nil, "BuildingsStatBox nicht gefunden" end
    return Box, nil
end

local function StatRowsFor(Key)
    local Box, Err = StatBox()
    if not Box then return nil, Err end

    local Rows = {}
    WalkStatRows(Box, function(K, Row)
        if K == Key then Rows[#Rows + 1] = Row end
    end, 0)

    if #Rows == 0 then return nil, string.format("keine Statistikzeile fuer %s", Key) end
    return Rows, nil
end

-- Wie viele Gebaeude es je Typ gibt. Ein Durchlauf zaehlt alle Typen auf
-- einmal; die Liste steht dann in der Uebersicht, damit sichtbar ist, wie oft
-- sich das Weiterspringen ueberhaupt lohnt.
CountBuildingsHook = function()
    local Box = StatBox()
    if not Box then return end
    local Counts = {}
    WalkStatRows(Box, function(K)
        Counts[K] = (Counts[K] or 0) + 1
    end, 0)
    BuildingCounts = Counts
end

local function ClickStatRow(Row)
    -- Erst die Lupe: sie ist ein PunButton und laesst sich vollstaendig
    -- pruefen. Nur wenn die fehlt, der Handler der Zeile selbst - der hat kein
    -- _callbackParent, ist dafuer aber das Ziel des Klicks und kein Zeiger,
    -- dem etwas fehlen koennte.
    local Goto = nil
    pcall(function() Goto = Row["GotoButton"] end)
    if ClickSafe(Goto) then return CallHandler(Goto, "OnButtonDown") end

    if IsTemplate(Row) then return "Statistikzeile ist eine Vorlage" end
    local ok, err = pcall(function() Row:OnButtonDown() end)
    if not ok then return tostring(err) end
    return nil
end

--[[
    Wo der letzte Sprung je Gebaeudetyp stehengeblieben ist.

    Bewusst nur ein Zaehler und keine gemerkte Zeile: die Tabelle wird von C++
    laufend neu befuellt, gemerkte Widgets waeren also schnell veraltet. Aendert
    sich die Anzahl der Zeilen, faengt der Zaehler wieder vorne an.
]]
local JumpCursor = {}

local function JumpToType(Key)
    local Rows, Err = StatRowsFor(Key)
    if not Rows then return Err end

    local C = JumpCursor[Key]
    if not C or C.total ~= #Rows or C.index >= #Rows then
        C = { index = 0, total = #Rows }
    end
    C.index = C.index + 1
    JumpCursor[Key] = C

    local CErr = ClickStatRow(Rows[C.index])
    if CErr then return CErr end
    return nil, C.index, #Rows
end

-- "Beekeeper 2/5" statt nur "Beekeeper": ohne die Zaehlung sieht ein Sprung
-- zum naechsten Gebaeude desselben Typs aus wie gar kein Sprung.
local function Where(Index, Total)
    if not Index or not Total or Total <= 1 then return "" end
    return string.format(" %d/%d", Index, Total)
end

local function ActivateRow(M)
    if M.kind == "type" then
        local err, Index, Total = JumpToType(M.key)
        if err then SetNotice("%s: %s", M.key, err)
        else SetNotice("springe zu %s%s", M.key, Where(Index, Total)) end
        return
    end
    if M.kind ~= "upgrade" then return end

    local err = FireUpgrade(M.key, M.label)
    if not err then
        -- Der Cache zeigt das Upgrade weiter als offen; das raeumt sich beim
        -- naechsten Einlesen des Panels von selbst auf.
        SetNotice("gekauft: %s", M.label)
        return
    end

    local JErr, Index, Total = JumpToType(M.key)
    if JErr then
        SetNotice("%s (%s)", err, JErr)
    else
        SetNotice("%s - springe zu %s%s, dann nochmal klicken",
            err, M.key, Where(Index, Total))
    end
end

--[[
    Klicks abfragen.

    UE4SS 3.0.1 kann kein Delegate aus Lua binden (RegisterCustomEvent geht nur
    auf BP-eigene UFunctions), also bleibt nur Abfragen. Button:IsPressed ist
    true, solange die Maus gedrueckt ist; ausgeloest wird auf der steigenden
    Flanke, damit ein Halten nicht zu vielen Klicks wird.

    Die Zeilen werden nur abgefragt, solange der Zeiger ueberhaupt ueber dem
    Panel steht. Sonst waeren es bei 120 Zeilen an die 2000 Aufrufe je Sekunde,
    die samt und sonders false zurueckgeben.
]]
local POLL_MS = 60

local function PollClicks()
    if not IsValidObj(Overlay.Root) or Overlay.Shown == false then return end

    local Down = nil
    pcall(function() Down = Overlay.HeaderBtn:IsPressed() end)
    if Down == true then
        if not Overlay.HeaderPressed then
            Overlay.HeaderPressed = true
            pcall(ToggleCollapsed)
        end
    else
        Overlay.HeaderPressed = false
    end

    if Settings.collapsed then return end

    -- Nur bei einem ausdruecklichen "nein" wird gespart. Liefert IsHovered
    -- ueber UE4SS gar nichts - so wie GetCachedGeometry, das nur 0x0 zurueckgab
    -- -, dann lieber alle Zeilen abfragen als die Bedienung verlieren.
    local Hover = nil
    local Asked = pcall(function() Hover = Overlay.Root:IsHovered() end)
    if Asked and Hover == false then
        for i = 1, Overlay.RowCount do
            local R = Overlay.Rows[i]
            if R then R.Pressed = false end
        end
        return
    end

    for i = 1, Overlay.RowCount do
        local R = Overlay.Rows[i]
        local M = R and R.Model
        if M and (M.kind == "type" or M.kind == "upgrade") then
            local RDown = nil
            pcall(function() RDown = R.Btn:IsPressed() end)
            if RDown == true then
                if not R.Pressed then
                    R.Pressed = true
                    pcall(ActivateRow, M)
                end
            else
                R.Pressed = false
            end
        end
    end
end

--[[
    Zustandszeile.

    Beantwortet die Fragen, die sich sonst nur durch einen weiteren
    Spielneustart klaeren lassen: ist das Widget sichtbar geschaltet, haelt der
    Slate-Baum es fuer sichtbar, wo liegt sein Slot am Ende wirklich, und
    stimmt der aktive Tab mit der gesuchten Seite ueberein.

    Die gezeichnete Flaeche steht bewusst nicht mehr drin: GetCachedGeometry
    liefert ueber UE4SS nur 0x0 (im v6-Lauf gemessen) und taugt hier nicht.

    Geschrieben wird nur bei Aenderung und hoechstens ein paar Mal, sonst
    laeuft UE4SS.log im Sekundentakt voll.
]]
local Diag = { Count = 0, Last = nil }
local DIAG_MAX = 14

local function DiagTick()
    if Diag.Count >= DIAG_MAX or not IsValidObj(Overlay.Root) then return end

    local Vis, Drawn, Active = "?", "?", "?"
    pcall(function() Vis = tostring(Overlay.Root:GetVisibility()) end)
    pcall(function() Drawn = tostring(Overlay.Root:IsVisible()) end)
    if IsValidObj(Overlay.Switcher) then
        pcall(function() Active = tostring(Overlay.Switcher:GetActiveWidgetIndex()) end)
    end

    local Line = string.format(
        "  Zustand: sichtbarkeit=%s gezeichnet=%s Tab=%s (Gebaeude=%s) | Slot %s",
        Vis, Drawn, Active, tostring(Overlay.PaneIndex),
        SlotText(SlotState(Overlay.Slot)))
    if Line == Diag.Last then return end
    Diag.Last = Line
    Diag.Count = Diag.Count + 1
    Log(Line)
end

--==========================================================================--
-- Recon-Dump (aus v3 uebernommen, unveraendert nuetzlich)
--==========================================================================--

local MAX_DEPTH = 10
local MAX_NODES = 1500

-- TooltipWidget ist der wichtige Eintrag: jede Zeile und jeder Button schleppt
-- einen kompletten TooltipWidget_C-Teilbaum mit ~30 Knoten mit. Im ersten
-- v3-Lauf hat das auf dem Forester-Panel das ganze Budget im Titel-Widget
-- aufgefressen, die Upgradezeilen wurden nie erreicht.
local SkipProps = {
    _punHUD = true, _callbackParent = true, Parent = true, Slot = true,
    WidgetTree = true, Animations = true, Outer = true,
    TooltipWidget = true, TooltipPunBoxWidget = true, TipSizeBox = true,
}

local Visited, NodeCount

local function ResetWalk()
    Visited = {}
    NodeCount = 0
end

local DumpWidget

local function DumpNamedSubWidgets(W, Depth)
    local Class = nil
    if not pcall(function() Class = W:GetClass() end) then return end

    local Guard = 0
    while Class and IsValidObj(Class) and Guard < 32 do
        Guard = Guard + 1
        pcall(function()
            Class:ForEachProperty(function(Prop)
                if NodeCount >= MAX_NODES then return end

                local PName = nil
                if not pcall(function() PName = Prop:GetFName():ToString() end) then return end
                if not PName or SkipProps[PName] then return end

                local okType, isObj = pcall(function()
                    return Prop:IsA(PropertyTypes.ObjectProperty)
                end)
                if not okType or not isObj then return end

                local Sub = nil
                if not pcall(function() Sub = W[PName] end) then return end
                if not IsValidObj(Sub) then return end

                -- Nur in Widgets absteigen, sonst landen wir im GameManager.
                local C, Found, G = nil, false, 0
                if not pcall(function() C = Sub:GetClass() end) then return end
                while C and IsValidObj(C) and G < 32 do
                    G = G + 1
                    local okN, N = pcall(function() return C:GetFName():ToString() end)
                    if not okN then return end
                    if N == "Widget" then Found = true break end
                    local okS, S = pcall(function() return C:GetSuperStruct() end)
                    if not okS then return end
                    C = S
                end
                if not Found then return end

                DumpWidget(Sub, Depth + 1, "." .. PName)
            end)
        end)

        local okS, Super = pcall(function() return Class:GetSuperStruct() end)
        if not okS then return end
        Class = Super
    end
end

DumpWidget = function(W, Depth, Label)
    if not IsValidObj(W) then return end
    if NodeCount >= MAX_NODES then return end

    local FN = FullName(W)
    local Indent = string.rep("  ", Depth)
    if Visited[FN] then
        Log(string.format("%s%s [%s] (schon gedumpt)", Indent, Label, ClassName(W)))
        return
    end
    Visited[FN] = true
    NodeCount = NodeCount + 1

    local Txt = ReadText(W)
    Log(string.format("%s%s [%s]%s", Indent, Label, ClassName(W),
        Txt and string.format(' Text=%q', Txt) or ""))

    if Depth >= MAX_DEPTH then
        Log(Indent .. "  ...MAX_DEPTH")
        return
    end

    local okc, Count = pcall(function() return W:GetChildrenCount() end)
    if okc and type(Count) == "number" and Count > 0 then
        for i = 0, Count - 1 do
            if NodeCount >= MAX_NODES then break end
            local okch, Child = pcall(function() return W:GetChildAt(i) end)
            if okch and IsValidObj(Child) then
                DumpWidget(Child, Depth + 1, string.format("Child[%d]", i))
            end
        end
    end

    DumpNamedSubWidgets(W, Depth)
end

local function DumpDescriptionUI()
    local DescUI = GetDescriptionUI(true)
    if not DescUI then
        Log("FEHLER: ObjectDescriptionUI nicht erreichbar")
        return
    end
    Log("_objectDescriptionUI = " .. FullName(DescUI))

    Log("")
    Log("### Upgrade-Zusammenfassung ###")
    local Scraped = ScrapeDescriptionPanel(DescUI)
    if Scraped then
        Log(string.format("Gebaeude: %s (Typ %s), %d Upgrades",
            Scraped.title, TypeKey(Scraped.title), #Scraped.upgrades))
        for _, U in ipairs(Scraped.upgrades) do
            Log(string.format("  %-6s %-28s %s", U.state, U.label,
                U.cost and (U.cost .. (U.affordable and "" or " (zu teuer)")) or ""))
        end
    else
        Log("kein Gebaeude ausgewaehlt / keine Upgradezeilen gefunden")
    end

    for _, PName in ipairs({ "DescriptionPunBox", "DescriptionPunBoxScroll",
                             "CardSlots", "TownBonusSlots", "GlobalBonusSlots" }) do
        Log("")
        Log("### " .. PName .. " ###")
        ResetWalk()
        local W = nil
        pcall(function() W = DescUI[PName] end)
        if IsValidObj(W) then
            DumpWidget(W, 0, PName)
            Log(string.format("(%d Knoten)", NodeCount))
        else
            Log(PName .. " ungueltig")
        end
    end
end

local function DumpStatisticsUI()
    local HUD = GetHUD(true)
    if not HUD then return end

    local StatUI = nil
    pcall(function() StatUI = HUD["_statisticsUI"] end)
    if not IsValidObj(StatUI) then
        Log("FEHLER: _statisticsUI ungueltig/null")
        return
    end
    Log("_statisticsUI = " .. FullName(StatUI) .. " class=" .. ClassName(StatUI))

    Log("")
    Log("### StatisticsUI WidgetTree ###")
    ResetWalk()
    local Tree = nil
    pcall(function() Tree = StatUI["WidgetTree"] end)
    local Root = nil
    if IsValidObj(Tree) then pcall(function() Root = Tree["RootWidget"] end) end
    if IsValidObj(Root) then
        Log("RootWidget = " .. FullName(Root) .. " class=" .. ClassName(Root))
        DumpWidget(Root, 0, "RootWidget")
    else
        Log("WidgetTree/RootWidget ungueltig")
    end
    Log(string.format("(%d Knoten)", NodeCount))

    Log("")
    Log("### Lebende BuildingStatTableRow_C-Instanzen ###")
    local Rows = nil
    pcall(function() Rows = FindAllOf("BuildingStatTableRow_C") end)
    if not Rows then
        Log("keine gefunden (Statistik -> Gebaeude offen?)")
        return
    end
    local n = 0
    for _, Row in pairs(Rows) do
        if IsValidObj(Row) and not IsTemplate(Row) then
            n = n + 1
            local NameTxt = "?"
            pcall(function()
                local BN = Row["BuildingName"]
                if IsValidObj(BN) then NameTxt = DeepText(BN) or "?" end
            end)
            Log(string.format("  Row[%d] %s BuildingName=%q", n, FullName(Row), NameTxt))
        end
    end
    Log(string.format("%d echte Zeilen (CDO/Archetype herausgefiltert)", n))
end

local function RunDump(Title, Fn)
    local Opened = OpenOut()
    local Stamp = ""
    pcall(function() Stamp = " @ " .. os.date("%Y-%m-%d %H:%M:%S") end)
    Log("")
    Log("================================================================")
    Log("=== " .. Title .. Stamp .. " ===")
    Log("================================================================")
    if not Opened then
        Log("(" .. RECON_FILE .. " nicht beschreibbar - Ausgabe nur in UE4SS.log)")
    end
    local ok, err = pcall(Fn)
    if not ok then Log("DUMP-FEHLER: " .. tostring(err)) end
    Log("=== fertig ===")
    CloseOut()
end

--==========================================================================--
-- Hauptschleife
--==========================================================================--

--[[
    Diagnose ohne Tastendruck.

    Frueher lagen die Dumps auf Strg+Shift+B und Strg+Shift+N. UE4SS-Keybinds
    verschlucken die Taste aber nicht: das Spiel bekommt das B zusaetzlich und
    oeffnet jedes Mal das Baumenue. Deshalb gibt es gar keine Tastenbelegung
    mehr - der Mod schreibt von sich aus einen Dump, wenn er ihn braucht, und
    hoechstens einmal pro Sitzung je Art.
]]
local AutoDumped = {}

local function AutoDump(Kind)
    if AutoDumped[Kind] then return end
    AutoDumped[Kind] = true
    if Kind == "statistics" then
        RunDump("StatisticsUI (automatisch)", DumpStatisticsUI)
    elseif Kind == "description" then
        RunDump("ObjectDescriptionUI (automatisch)", DumpDescriptionUI)
    end
end

AutoDumpHook = AutoDump

local function Tick()
    local DescUI = GetDescriptionUI(false)
    if not DescUI then return end

    local Scraped = ScrapeDescriptionPanel(DescUI)
    if not Scraped then return end

    if #Scraped.upgrades == 0 then
        -- Panel mit Titel, aber keine Upgradezeile erkannt: entweder hat das
        -- Gebaeude wirklich keine, oder die Zeilentypen stimmen nicht mehr.
        -- Einmal mitschreiben, damit es sich pruefen laesst.
        AutoDump("description")
        return
    end

    if Remember(Scraped) then RefreshOverlay() end
end

-- Nebenher: Meldungen in der Kopfzeile wieder verfallen lassen und einen
-- geaenderten Cache wegschreiben. Der Umschalter aendert ihn ebenfalls, nicht
-- nur ein neu erfasstes Gebaeude.
local function HouseKeeping()
    if Notice.Ticks > 0 then
        Notice.Ticks = Notice.Ticks - 1
        if Notice.Ticks == 0 then
            Notice.Text = nil
            RefreshOverlay()
        end
    end
    if CacheDirty then
        -- Nicht schreibbar: der Cache bleibt trotzdem im Speicher gueltig, aber
        -- es darf nicht jede Sekunde erneut versucht und geloggt werden.
        if not SaveCache() then CacheDirty = false end
    end
end

LoadCache()

LoopAsync(1000, function()
    ExecuteInGameThread(function()
        pcall(Tick)
        -- Zu Spielbeginn gibt es weder HUD noch StatisticsUI, und beim Wechsel
        -- der Partie kann das Panel neu gebaut werden. Also so lange versuchen,
        -- bis es haengt, und danach ueberwachen.
        if not IsValidObj(Overlay.Root) then
            if Overlay.Mounted then
                -- War schon mal da und ist weg: neu aufbauen duerfen.
                Overlay.Mounted = false
                Overlay.Attempts = 0
            end
            pcall(BuildOverlay)
        else
            pcall(EnsureAttached)
            pcall(UpdateVisibility)
            pcall(DiagTick)
        end
        pcall(HouseKeeping)
    end)
    return false -- false = weiterlaufen
end)

-- Zweite, schnelle Schleife nur fuer Klicks. Sie muss deutlich enger takten
-- als die Sekundenschleife, sonst faellt ein kurzer Mausklick zwischen zwei
-- Abfragen und geht verloren.
LoopAsync(POLL_MS, function()
    ExecuteInGameThread(function() pcall(PollClicks) end)
    return false
end)

Log("KRBuildingUpgrades v10 geladen. Keine Tastenbelegung noetig: die Liste "
    .. "fuellt sich beim Anklicken von Gebaeuden und steht im Statistik-Fenster, "
    .. "Tab 'Buildings'. Kopfzeile klicken klappt sie zu, eine Upgradezeile "
    .. "klicken kauft das Upgrade, der Gebaeudename geht reihum durch alle "
    .. "Gebaeude des Typs.")
