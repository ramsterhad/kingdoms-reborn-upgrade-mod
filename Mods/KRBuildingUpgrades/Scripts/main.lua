--[[
    KRBuildingUpgrades v16

    Collects, while playing, which upgrades a building type has and which of
    them are already bought, keeps that across game restarts, and shows it as
    an overlay in the game.

    Why it has to work this way (backed by UE4SS_ObjectDump.txt):

      * The simulation (PunSimCore) is plain C++ without UObject reflection
        and unreachable from Lua. The only data source is the UMG widgets.
      * There is no callable function to select a building - ObjectDescriptionUI_C
        has exactly one function (OnMouseButtonDown_0), and selection lives in
        non-reflected C++. Automatically clicking through every building is
        therefore impossible; the cache fills up as the player clicks buildings.
      * Upgrades belong to the individual BUILDING. The tooltip ("Shift-click
        ... all same type buildings") describes a bulk purchase button, not a
        property of the type - see "What v12 changes" below.

    Panel layout, confirmed in the v3 run: DescriptionPunBox.PunVerticalBox is
    a flat row list; upgrades are PunButtonWidget_C (.TopText) and
    PunSplitButtonWidget_C (.Text1/.Text2). The row text is two lines,
    "<Name>\r\n<Status>", with status "Done" or a price like
    '<img id="SteelBeam"/><Red>80</>' (<Red> = currently unaffordable).

    Controls: mouse only, no keybinds. UE4SS keybinds do not swallow the key,
    the game reacts to it as well - Ctrl+Shift+B used to open the build menu
    every single time.

      * Clicking the header row collapses and expands the list. Collapsed,
        only a thin strip remains and the building table underneath is
        usable again. The state is written to the cache and persists across
        restarts.
      * Clicking an upgrade row buys the upgrade, provided the building is
        currently selected. Otherwise the first click jumps to the building
        (the magnifier in the stat row), the second buys it.
      * Clicking the building name jumps there; every further click goes to
        the next building of the same type and wraps around after the last
        one. The header shows "2/5" alongside it.

    The list fills up during normal play as soon as a building is clicked,
    and the panel hangs as a child of the StatisticsUI root canvas, so it
    appears with the statistics window and disappears with it too. It is
    only visible on the Buildings tab so it doesn't cover the graphs on the
    other tabs (see the overlay section). The mod writes diagnostic dumps on
    its own when needed.

    Files (besides UE4SS.log):
      KRUpgrades.lua  persistent cache
      KRRecon.txt     automatic diagnostic dumps

    What v7 changed vs v6: v6 established the cause of the invisibility -
    SetAnchors doesn't take effect through UE4SS, the anchor stayed at (0,0)
    and the panel sat 260 pixels above the top edge of the screen because of
    it. v7 sets the anchors via the LayoutData property, places the panel as
    a FRACTION of the canvas area (so it needs neither window size nor
    resolution) and checks anchors with a tolerance that fits values between
    0 and 1. Reasoning in the "Writing geometry" section.

    What v8 added: v7 sat in the right place but covered the whole building
    table and was read-only. v8 makes the panel interactive. The single
    TextBlock became a header row plus one row per entry, each in its own
    UMG.Button; clicks aren't handled via a delegate (UE4SS 3.0.1 can't bind
    one), but by polling Button:IsPressed in a fast loop. To keep that cheap,
    the row poll only runs while the mouse cursor is over the panel.

    The purchase path is confirmed from the object dump and takes no
    parameters:

        Function /Script/PrototypeCity.PunButton:OnButtonDown
        Function /Script/PrototypeCity.PunSplitButton:OnButtonDown1 / 2
        Function /Script/PrototypeCity.BuildingStatTableRow:OnButtonDown

    PunButtonWidget_C inherits from PunButton, PunSplitButtonWidget_C from
    PunSplitButton (sps addresses checked in the dump). It is always called
    on exactly the widget found in the open description panel - that widget
    already carries the building id and callback enum in non-reflected C++
    fields, so there's nothing to set and nothing to guess. Before every call
    it is checked that the widget and _callbackParent are valid: that exact
    pointer is dereferenced inside OnButtonDown, and a CDO would have
    nullptr there (the FindAllOf trap from v1/v2).

    What v9 changes: v8 took the first matching row of the building table
    when jumping and stopped there. But the table lists one row per BUILDING,
    not per type - five beehives produce five rows named "Beekeeper". Every
    click therefore landed on the same building, and the rest were only
    reachable via the arrows in the description window. v9 collects all rows
    of a type and advances one further with each click. The overview also
    used to show only "(2/4)", which read as "building 2 of 4"; the building
    count now has its own column.

    What v10 changes, both from feedback on the v9 run:

      * The background was translucent at alpha 0.88, and the game's building
        table showed through the text. Now opaque.
      * Everything was centered and hard to read as a list. The cause was
        UButtonSlot, which centers its content by default. The single text
        line per entry became a real table: a HorizontalBox with three
        columns (Building/Upgrade, Cost, Status), left-aligned, width as a
        fraction, and a column header that doesn't scroll along. Completed
        upgrades recede via SetOpacity; that takes a flat float, whereas
        SetColorAndOpacity with its nested FSlateColor would have been
        silently ineffective.

    What v11 changes: v10 was readable but still didn't say what was
    clickable - an upgrade you can't afford looked exactly like one you
    can. Now the right-hand cell is the affordance, and it isn't only
    cosmetic:

      * Three columns became two. The status column is gone; a chip on the
        right states the action instead ("jump >>" or the price), and its
        fill says whether the row does anything at all.
      * Unaffordable upgrades are no longer clickable. They get kind
        "info", which PollClicks already skips, so the panel stops offering
        a purchase the game would refuse. Fill and behaviour can't disagree
        because both come from the same U.affordable flag.
      * The chip is a Border, so the colour rides on Border:SetBrushColor,
        already proven in-game on the panel background - not on
        TextBlock:SetColorAndOpacity, whose nested FSlateColor would have
        been the FAnchors trap all over again.
      * Building name and upgrade counts share the left cell; the marker
        glyph on upgrade rows is gone. It agreed with the chip often enough
        to look meaningful and then didn't, which read as a bug.

    What v12 changes, and it corrects an assumption this mod was built on:

    Upgrades are NOT per building type. Of two Brickworks in the v11 run,
    one offered "Upgrade Level (Enlightenment Age)" and the other "Upgrade
    Electric Machinery" - which upgrades are listed at all depends on that
    building's own level. Of three Beekeepers, one had "Intensive Care"
    bought and another didn't. The log showed "recorded: Beekeeper" five
    times as the player cycled through them: the type cache was being
    overwritten by whichever building was looked at last.

    So "2/4 upgrades" never meant "for Beekeepers" - it meant "for the one
    Beekeeper I last had open", which is useless as a to-do list for a town.

      * Rows are now per building where that is known: "#2  Upgrade
        Knowledge Sharing". Buying checks it is on the right one by
        comparing the open panel's upgrade list against what was recorded -
        there is no building id to compare, and two buildings with
        identical state are interchangeable for a purchase anyway.
      * A "collect all information" button selects every building in the
        table in turn and reads it. That moves the camera, so it is an
        explicit action with a progress count that can be stopped, never
        something running in the background.
      * Types that have not been scanned still show the old single sample,
        now labelled "(last seen)" instead of being passed off as a fact
        about the type.
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

-- Always to UE4SS.log, additionally to KRRecon.txt while a dump is running.
-- Flushed line by line: if the game dies mid-dump, everything up to that
-- point is still there.
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
-- UObject helpers
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

-- CDOs and WidgetArchetypes look like real instances to FindAllOf, but carry
-- no runtime state. That's exactly what tripped up v2.
local function IsTemplate(Obj)
    local n = FullName(Obj)
    return n:find("Default__", 1, true) ~= nil
        or n:find("WidgetArchetype", 1, true) ~= nil
end

local function FindLive(WantedClass, Verbose)
    local ok, Objs = pcall(FindAllOf, WantedClass)
    if not ok or not Objs then
        if Verbose then Log(string.format("FindLive(%s): FindAllOf returned nothing", WantedClass)) end
        return nil
    end

    local Live, Total = nil, 0
    for _, Obj in pairs(Objs) do
        Total = Total + 1
        local Verdict
        if not IsValidObj(Obj) then
            Verdict = "SKIP (invalid)"
        elseif ClassName(Obj) ~= WantedClass then
            Verdict = "SKIP (class mismatch: " .. ClassName(Obj) .. ")"
        elseif IsTemplate(Obj) then
            Verdict = "SKIP (CDO/Archetype)"
        else
            Verdict = "OK"
            if not Live then Live = Obj end
        end
        if Verbose then Log(string.format("  Candidate: %-14s %s", Verdict, FullName(Obj))) end
    end

    if Verbose then
        Log(string.format("FindLive(%s): %d candidates, live=%s",
            WantedClass, Total, Live and FullName(Live) or "NONE"))
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

-- Pun widgets rarely carry the text themselves: PunRichText holds it in
-- .PunRichText, PunButton in .TopText, and so on.
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

-- FindAllOf scans the entire GUObjectArray (this game's object dump is
-- 94 MB). Once per second would be noticeable in the poll loop, so the HUD
-- pointer is cached and only re-resolved once it becomes invalid, e.g.
-- after switching games.
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
-- Text processing
--==========================================================================--

local function Trim(S)
    return (S:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Defuse rich-text markup for display: <img id="Wood"/> -> "Wood", every
-- other tag stripped out.
local function StripTags(S)
    if not S then return "" end
    S = S:gsub('<img%s+id="([^"]*)"%s*/>', "%1 ")
    S = S:gsub("<[^>]*>", "")
    return Trim(S)
end

-- Depending on the building, either .Title or .Title2Lines is populated in
-- the title widget; the unused field keeps its placeholder text from the
-- blueprint. Without this list a distillery would land in the cache as
-- building type "Title".
local Placeholders = {
    Title = true, Title2Lines = true, Subtitle = true, TownName12345678 = true,
}

-- "House Lv 6" and "House Lv 1" are the same type.
local function TypeKey(Title)
    local T = Trim(StripTags(Title or ""))
    T = T:gsub("%s+Lv%s*%d+$", "")
    return T
end

--==========================================================================--
-- Collecting
--==========================================================================--

-- Per row type: which text property carries the upgrade text, and which
-- parameterless UFunction triggers the same click as the mouse. This mapping
-- comes straight from the object dump; PunButtonWidget_C inherits from
-- PunButton, PunSplitButtonWidget_C from PunSplitButton.
local UpgradeRowProps = {
    PunButtonWidget_C      = { { "TopText", "OnButtonDown"  } },
    PunSplitButtonWidget_C = { { "Text1",   "OnButtonDown1" },
                               { "Text2",   "OnButtonDown2" } },
}

-- Splits "<Name>\r\n<Status>" into its parts.
local function ParseUpgradeText(Raw)
    local First, Rest = Raw:match("^([^\r\n]*)[\r\n]+(.*)$")
    if not First then First, Rest = Raw, "" end

    local Label = Trim(StripTags(First))
    if Label == "" then return nil end

    local StatusRaw = Trim(Rest)
    local StatusPlain = StripTags(StatusRaw)

    local Entry = { label = Label, raw = Raw }
    if StatusPlain == "" then
        -- No second line: state unknown, but the upgrade exists.
        Entry.state = "unknown"
    elseif StatusPlain:lower() == "done" then
        Entry.state = "done"
    else
        Entry.state = "open"
        Entry.cost = StatusPlain
        -- <Red> marks exactly what you currently can't afford, in the game.
        Entry.affordable = (StatusRaw:find("<Red>", 1, true) == nil)
    end
    return Entry
end

-- Reads the currently open description panel. Returns nil if no building is
-- selected or the panel has no upgrade rows.
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
                        -- Split buttons show the same upgrade twice
                        -- (single / all), so de-dupe by label.
                        if Entry and not Seen[Entry.label] then
                            Seen[Entry.label] = true
                            Upgrades[#Upgrades + 1] = Entry
                            -- Keep the live widget separately: the cache
                            -- is written out as text, object pointers have
                            -- no business in it and wouldn't survive a
                            -- selection change anyway.
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
-- Cache + persistence
--==========================================================================--

local Cache = {}          -- TypeKey -> { title, upgrades, seen }
local CacheDirty = false

-- UI state that should survive a game restart. Stored inside the cache file
-- under a key that can never occur as a building type.
-- Collapsed is the default: v7 made the statistics window unusable because
-- the panel covered the entire building table. Without a saved state the
-- statistics should therefore work like without the mod at first - the
-- overview is one click away, and the state persists after that.
local SETTINGS_KEY = "__settings"
local SCAN_KEY     = "__scan"
local Settings = { collapsed = true }

--[[
    Per-building results.

    Upgrades belong to the individual building, not to the type. Confirmed
    in-game on 2026-07-26: of two Brickworks one offered "Upgrade Level
    (Enlightenment Age)" and the other "Upgrade Electric Machinery", because
    which upgrades are listed at all depends on that building's level. And
    of three Beekeepers, one had "Intensive Care" bought and another didn't.
    The tooltip "Shift-click ... all same type buildings" describes a bulk
    purchase button, not a property of the type.

    So the type cache only answers "what kind of upgrades does this building
    have". This answers "and which are still open, on which one". It can
    only be filled by selecting every building in turn, which moves the
    camera - hence an explicit action the player triggers, never something
    that happens while they play.

      Buildings[i] = { key = "Beekeeper", ord = 2, upgrades = { ... } }

    ord is the position within its type, in building-table order.
]]
local ScanData = { At = "", Buildings = {} }

-- Runner state for that scan. Declared alongside, because the row model,
-- the header and SaveCache all read it; the stepping code needs the
-- description panel and lives much further down.
local Scan = { Active = false, Rows = nil, Index = 0, Wait = 0,
               Seen = nil, Result = nil }

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

-- Did anything actually change compared to the cache? Otherwise every poll
-- would rewrite the file.
--
-- Freshly scraped and file-loaded entries aren't bit-identical: a missing
-- cost is nil in one case and "" in the other, affordable is nil once and
-- false once. Without normalizing this, everything counts as changed after
-- every game start and gets rewritten immediately.
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
    Log(string.format("recorded: %s (%d upgrades)", Key, #New.upgrades))
    return true
end

local function QuoteStr(S)
    return string.format("%q", tostring(S or ""))
end

local function SaveCache()
    local ok, f = pcall(io.open, CACHE_FILE, "w")
    if not ok or not f then
        Log("WARNING: " .. CACHE_FILE .. " not writable")
        return false
    end
    local okw = pcall(function()
        f:write("-- KRBuildingUpgrades cache, auto-generated\n")
        f:write("return {\n")
        f:write(string.format("  [%s] = { collapsed = %s },\n",
            QuoteStr(SETTINGS_KEY), tostring(Settings.collapsed == true)))

        -- The scan snapshot. Written with its timestamp so the panel can
        -- say how old it is - buildings get built and upgraded, and a
        -- stale list presented as current would be worse than none.
        if #ScanData.Buildings > 0 then
            f:write(string.format("  [%s] = {\n    at = %s,\n    buildings = {\n",
                QuoteStr(SCAN_KEY), QuoteStr(ScanData.At)))
            for _, B in ipairs(ScanData.Buildings) do
                f:write(string.format("      { key = %s, ord = %d, upgrades = {\n",
                    QuoteStr(B.key), B.ord))
                for _, U in ipairs(B.upgrades) do
                    f:write(string.format(
                        "        { label = %s, state = %s, cost = %s, affordable = %s },\n",
                        QuoteStr(U.label), QuoteStr(U.state), QuoteStr(U.cost),
                        tostring(U.affordable == true)))
                end
                f:write("      } },\n")
            end
            f:write("    },\n  },\n")
        end
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
        Log("WARNING: " .. CACHE_FILE .. " unreadable, starting with empty cache")
        return
    end
    -- Read defensively: a corrupt file must not take the mod down.
    -- Placeholder keys from older runs get dropped here; they'll be
    -- recorded again under the right name the next time the building is
    -- clicked.
    local Dropped = 0
    for Key, E in pairs(Data) do
        if Key == SETTINGS_KEY then
            if type(E) == "table" then Settings.collapsed = (E.collapsed == true) end
        elseif Key == SCAN_KEY then
            if type(E) == "table" and type(E.buildings) == "table" then
                local Bs = {}
                for _, B in ipairs(E.buildings) do
                    if type(B) == "table" and type(B.key) == "string"
                       and type(B.ord) == "number" and type(B.upgrades) == "table" then
                        local Ups = {}
                        for _, U in ipairs(B.upgrades) do
                            if type(U) == "table" and type(U.label) == "string" then
                                Ups[#Ups + 1] = {
                                    label = U.label,
                                    state = U.state or "unknown",
                                    cost = (U.cost ~= "" and U.cost) or nil,
                                    affordable = U.affordable == true,
                                }
                            end
                        end
                        Bs[#Bs + 1] = { key = B.key, ord = B.ord, upgrades = Ups }
                    end
                end
                ScanData = { At = E.at or "", Buildings = Bs }
            end
        elseif type(Key) == "string" and Placeholders[Key] then
            Dropped = Dropped + 1
        elseif type(Key) == "string" and type(E) == "table" and type(E.upgrades) == "table" then
            local Ups = {}
            for _, U in ipairs(E.upgrades) do
                if type(U) == "table" and type(U.label) == "string" then
                    Ups[#Ups + 1] = {
                        label = U.label,
                        state = U.state or "unknown",
                        -- Serializing turns nil into "". Turn it back into
                        -- nil, otherwise EntryDiffers thinks every loaded
                        -- entry has changed and rewrites everything on
                        -- every game start.
                        cost = (U.cost ~= "" and U.cost) or nil,
                        affordable = U.affordable == true,
                    }
                end
            end
            Cache[Key] = { title = E.title or Key, seen = E.seen or "", upgrades = Ups }
        end
    end
    Log(string.format("Cache loaded: %d building types from %s%s",
        CountEntries(Cache), CACHE_FILE,
        Dropped > 0 and string.format(" (%d placeholders discarded)", Dropped) or ""))
    if Dropped > 0 then CacheDirty = true end
end

--==========================================================================--
-- Overlay text
--==========================================================================--

--[[
    The cache no longer turns into a text block, but into a row model: per
    entry, text plus what a click on it means.

      kind = "type"     building name       -> jump to a building of this type
      kind = "upgrade"  open upgrade        -> buy (or jump there first)
      kind = "info"     nothing clickable   (completed upgrades, hint text)

    The rows each go into their own button. Completed entries are
    deliberately unclickable - a second purchase would be pointless, and
    every C++ call not triggered is one less thing that can go wrong.
]]
local Notice = { Text = nil, Ticks = 0 }

-- Building count per type, counted from the building table. Declared up
-- here because the row text needs it; it's filled in further down, where
-- the table is walked anyway.
local BuildingCounts = {}
local CountBuildingsHook = nil

-- ScanData and Scan are declared up with the cache, since SaveCache writes
-- the snapshot and a local declared after its use silently reads as nil.

-- How strongly a row is drawn. Declared here rather than down with the
-- widget code because BuildRowModel is what assigns them, and a local
-- declared after its use silently reads as nil - which cost a run before
-- the harness caught it.
local DIM_DONE   = 0.45   -- bought: still listed, but out of the way
local DIM_LOCKED = 0.70   -- unaffordable: readable, clearly not on offer

--[[
    Upgrade rows are one line, so colour carries the state on its own.

    That makes colour the single point of failure, and FSlateColor is
    exactly the nested-struct shape that has failed silently here before.
    So brightness varies too: even if the colour never lands, buyable rows
    stay bright, unaffordable ones sit back, done ones recede. Cheap
    insurance against a panel that would otherwise read as one flat wall of
    white text.
]]
local TEXT_COLOR = {
    buy     = { R = 0.49, G = 0.75, B = 0.40 },
    locked  = { R = 0.76, G = 0.36, B = 0.29 },
    done    = { R = 0.55, G = 0.53, B = 0.50 },
    default = { R = 0.91, G = 0.90, B = 0.87 },
}

--[[
    The game writes prices as icon-then-number, which StripTags leaves as
    "Glass 756". Spoken the other way round, so it reads that way here.
]]
local function FormatCost(Cost)
    if not Cost or Cost == "" then return "" end
    local Res, Amount = Cost:match("^(%S+)%s+(%d+)$")
    if Res and Amount then return Amount .. " " .. Res end
    return Cost
end

local function BuildHeaderText(TypeCount, OpenCount)
    local Mark = Settings.collapsed and "[+]" or "[-]"
    local Body
    if Notice.Text and Notice.Ticks > 0 then
        Body = Notice.Text
    elseif TypeCount == 0 then
        Body = "KR Upgrade Overview - nothing recorded yet"
    else
        Body = string.format("KR Upgrade Overview - %d building types, %d open",
            TypeCount, OpenCount)
    end
    return string.format("%s  %s", Mark, Body)
end

--[[
    One upgrade, on one line: "Upgrade Improved Filtration: 273 Stone".

    Not two columns any more - a price in a separate right-hand column made
    the eye travel across the row for every single entry, and with the state
    already in the colour there was nothing for that column to add. The chip
    stays empty here; only building rows still carry one.

    Three states, and only the buyable one is clickable:
      green  affordable       -> buys it
      red    too expensive    -> inert, price still shown so you know what for
      grey   already bought   -> inert, name only, no price to show
]]
local function UpgradeRow(Rows, Key, U, Prefix, Ord)
    local Line = Prefix .. U.label

    if U.state == "done" then
        Rows[#Rows + 1] = { kind = "info", chip = "none", alpha = DIM_DONE,
            color = "done", name = Line, action = "" }
    elseif U.state ~= "open" then
        Rows[#Rows + 1] = { kind = "info", chip = "none", alpha = DIM_DONE,
            color = "done", name = Line .. ": ?", action = "" }
    elseif U.affordable then
        Rows[#Rows + 1] = { kind = "upgrade", key = Key, label = U.label, ord = Ord,
            chip = "none", alpha = 1.0, color = "buy",
            name = Line .. ": " .. FormatCost(U.cost), action = "" }
    else
        -- kind "info" is what PollClicks already skips, so this needs no
        -- new mechanism - and it stops the panel dangling a purchase the
        -- game would refuse anyway.
        Rows[#Rows + 1] = { kind = "info", chip = "none", alpha = DIM_LOCKED,
            color = "locked", name = Line .. ": " .. FormatCost(U.cost), action = "" }
    end
end

-- "1 buildings" reads like a bug even though it isn't one.
local function Count(N, Word)
    if N == 1 then return string.format("%d %s", N, Word) end
    return string.format("%d %ss", N, Word)
end

--[[
    The scan row, built like every other row: label left, chip right.

    It used to be flat text in brackets, which broke the one rule the panel
    has - a filled chip means the row does something. It is clickable, so it
    gets a chip. Gold, because gold already means "this moves the camera",
    and reading every building is exactly that.

    While running it doubles as its own progress bar and the chip offers the
    way out: a full pass across a town takes a while and shouldn't be a
    one-way door.
]]
local function BuildScanRow()
    if Scan.Active and Scan.Rows then
        return string.format("> reading %d / %d",
            math.min(Scan.Index, #Scan.Rows), #Scan.Rows), "stop"
    end
    if ScanData.At ~= "" then
        return string.format("> Collect all information    last run %s", ScanData.At), "scan"
    end
    return "> Collect all information", "scan"
end

local function BuildRowModel()
    -- Types can come from either source: the cache fills up passively while
    -- playing, the scan covers everything at once.
    local KeySet = {}
    for K in pairs(Cache) do KeySet[K] = true end

    local ByType = {}
    for _, B in ipairs(ScanData.Buildings) do
        KeySet[B.key] = true
        ByType[B.key] = ByType[B.key] or {}
        table.insert(ByType[B.key], B)
    end

    local Keys = SortedKeys(KeySet)
    local Rows, TotalOpen = {}, 0

    if #Keys == 0 then
        Rows[1] = { kind = "info", alpha = 1.0, chip = "none",
            name = "Click buildings, or use 'collect all information' above.",
            action = "" }
        return Rows, 0, 0
    end

    for _, Key in ipairs(Keys) do
        local Group = ByType[Key]

        if Group then
            --[[
                Scanned: every building is its own entry, named in full.

                No type heading above them. Once each building is listed by
                name and number, a separate "Beekeeper - 4 buildings" line
                only restates what the four lines below it already say, and
                the counts on it invited being misread ("2/4" looked like
                "the 2nd of 4").

                Buildings with nothing left are listed too, just dimmed.
                Leaving them out made the numbering skip, so #3 could mean
                "done" or "gone" and there was no way to tell.
            ]]
            for _, B in ipairs(Group) do
                local Open = 0
                for _, U in ipairs(B.upgrades) do
                    if U.state == "open" then Open = Open + 1 end
                end
                TotalOpen = TotalOpen + Open

                Rows[#Rows + 1] = {
                    kind = "building", key = Key, ord = B.ord, chip = "jump",
                    -- Dimmed when there is nothing to do, but still
                    -- clickable: the chip means "this goes somewhere", and
                    -- it does. The name says whether it is worth going.
                    alpha = (Open > 0) and 1.0 or DIM_DONE, chipAlpha = 1.0,
                    name = string.format("%s #%d", Key, B.ord),
                    action = "jump",
                }
                for _, U in ipairs(B.upgrades) do
                    UpgradeRow(Rows, Key, U, "      ", B.ord)
                end
            end
        else
            --[[
                Not scanned yet, so only the type cache is available - and
                that holds whichever building happened to be looked at last.
                Shown as before, but the count is deliberately labelled
                "last seen" rather than presented as a fact about the type.
            ]]
            local E = Cache[Key]
            local Done = 0
            for _, U in ipairs(E.upgrades) do
                if U.state == "done" then Done = Done + 1 end
                if U.state == "open" then TotalOpen = TotalOpen + 1 end
            end

            local N = BuildingCounts[Key]
            Rows[#Rows + 1] = {
                kind = "type", key = Key, chip = "jump", alpha = 1.0,
                name = string.format("> %s   %d/%d upgrades (last seen)%s", Key,
                    Done, #E.upgrades,
                    N and ("  |  " .. Count(N, "building")) or ""),
                action = "jump >>",
            }

            for _, U in ipairs(E.upgrades) do
                UpgradeRow(Rows, Key, U, "      ", nil)
            end
        end
    end

    return Rows, #Keys, TotalOpen
end

--==========================================================================--
-- Overlay widget
--==========================================================================--

local Overlay = {
    Root = nil, Box = nil, Scroll = nil, Canvas = nil, Slot = nil, Window = nil,
    HeaderBtn = nil, HeaderText = nil, ColumnHead = nil,
    ScanBtn = nil, ScanCells = nil, ScanPressed = false,
    Switcher = nil, PaneIndex = nil, Shown = nil,
    Attempts = 0, Mounted = false,
    Rows = {},          -- pool: { Btn, Text, Model, Pressed }
    RowCount = 0,       -- of which are currently in use
}
local MAX_BUILD_ATTEMPTS = 30
local PANEL_ZORDER = 1000

-- The pool only grows up to this limit. Since every building lists every
-- one of its upgrades, a large town reaches four figures: 200 buildings
-- with four upgrades each is 1000 rows. The bound is there to stop a
-- corrupt cache building widgets without end, not to trim normal play -
-- RefreshOverlay logs when it actually bites.
local MAX_ROWS = 1400

-- Resolved once at build time, then reused for every row rebuilt after
-- that. StaticFindObject per row would just be work without any benefit.
local WidgetClasses = nil
local ROW_FONT_SIZE = 12

-- Whether writing FSlateColor actually took. Logged once, because with
-- single-line upgrade rows the colour is the state, and a silent failure
-- would leave a wall of identical white text.
local ColorWorks = nil
local ColorReported = false

--[[
    Two columns: what the row is, and what clicking it does.

    v10 had three (name / cost / status) and still didn't make clickability
    obvious - a status word looks identical whether or not you can act on
    it. Now the right cell IS the affordance: a filled chip means the row
    does something, flat text means it doesn't. The status column is gone
    because clickability already carries that information.

    Widths are a fraction of the panel width, not pixels - the panel's own
    width already only comes from a fraction of the canvas area, and pixels
    are as hard to get here as they were for the window size.

    ESlateSizeRule: 0 Automatic, 1 Fill.
    EHorizontalAlignment: 0 Fill, 1 Left, 2 Center, 3 Right.
    EVerticalAlignment:   0 Fill, 1 Top,  2 Center, 3 Bottom.
]]
local COL_NAME   = 0.62
local COL_ACTION = 0.38

local COLUMN_TITLE = "Building / Upgrade"

--[[
    Chip fills.

    FLinearColor is flat, and Border:SetBrushColor is already confirmed
    working in the game on the panel background itself. So the colour coding
    rides on a proven call instead of TextBlock:SetColorAndOpacity, whose
    FSlateColor is nested the way FAnchors was and would risk failing
    silently.

    Deliberately only two filled states: gold means "this moves the camera",
    green means "this spends resources". Everything else gets no fill at all
    and is not clickable either, so fill and behaviour can never disagree.
]]
local CHIP = {
    jump = { R = 0.26, G = 0.20, B = 0.07, A = 1.0 },
    buy  = { R = 0.11, G = 0.19, B = 0.09, A = 1.0 },
    none = { R = 0.0,  G = 0.0,  B = 0.0,  A = 0.0 },
}

-- Emphasis levels live with the row model further up, since that is what
-- assigns them.

-- Shared basis for the header and data rows. Both are a button, even the
-- column header: otherwise its padding would differ from the rows below it
-- and the columns would sit a few pixels off.
local function NewRowShell(Outer)
    local Btn = StaticConstructObject(WidgetClasses.Button, Outer)
    -- A freshly constructed UMG.Button brings the gray default background
    -- with it - a hundred gray boxes stacked on top of each other would be
    -- unreadable. So set it transparent. It stays clickable regardless: the
    -- hit area of SButton depends on visibility, not on the brush.
    pcall(function() Btn:SetBackgroundColor({ R = 1.0, G = 1.0, B = 1.0, A = 0.0 }) end)
    return Btn
end

local function StyleCellText(Text)
    pcall(function()
        local Font = Text.Font
        Font.Size = ROW_FONT_SIZE
        Text:SetFont(Font)
    end)
    -- Wrapping would make the row height jump around and tear the table
    -- apart; better to let a long name run off to the right.
    pcall(function() Text:SetAutoWrapText(false) end)
end

--[[
    A data row: Button > HorizontalBox > [ TextBlock, Border > TextBlock ].

    The centering came from UButtonSlot, which centers its content by
    default - that's why everything used to sit in the middle and was hard
    to read as a list. HAlign_Fill gives the HorizontalBox the full width,
    only then do the column fractions take effect.

    The right cell is a Border wrapping its text, not bare text: the Border
    is what can carry a background, and a background is what makes a row
    read as actionable. It sizes to its own content and sits at the right
    edge (HAlign_Right), so every row's chip lines up in one column even
    though the labels differ in length.
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

    -- Left: what the row is.
    local NameText = StaticConstructObject(WidgetClasses.Text, Outer)
    StyleCellText(NameText)
    local NameSlot = nil
    pcall(function() NameSlot = HBox:AddChildToHorizontalBox(NameText) end)
    if IsValidObj(NameSlot) then
        pcall(function() NameSlot:SetSize({ Value = COL_NAME, SizeRule = 1 }) end)
        pcall(function() NameSlot:SetHorizontalAlignment(1) end)
        pcall(function() NameSlot:SetVerticalAlignment(2) end)
        pcall(function() NameSlot:SetPadding({ Left = 4.0, Top = 0.0, Right = 4.0, Bottom = 0.0 }) end)
    end

    -- Right: what clicking it does.
    local Chip     = StaticConstructObject(WidgetClasses.Border, Outer)
    local ChipText = StaticConstructObject(WidgetClasses.Text, Outer)
    StyleCellText(ChipText)
    pcall(function() Chip:SetContent(ChipText) end)
    pcall(function() Chip:SetPadding({ Left = 8.0, Top = 1.0, Right = 8.0, Bottom = 1.0 }) end)

    local ChipSlot = nil
    pcall(function() ChipSlot = HBox:AddChildToHorizontalBox(Chip) end)
    if IsValidObj(ChipSlot) then
        pcall(function() ChipSlot:SetSize({ Value = COL_ACTION, SizeRule = 1 }) end)
        pcall(function() ChipSlot:SetHorizontalAlignment(3) end)
        pcall(function() ChipSlot:SetVerticalAlignment(2) end)
        pcall(function() ChipSlot:SetPadding({ Left = 4.0, Top = 0.0, Right = 4.0, Bottom = 0.0 }) end)
    end

    return Btn, { Name = NameText, Chip = Chip, ChipText = ChipText }
end

-- The header row at the very top spans the full width and has no columns;
-- it carries the toggle and the click feedback.
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

-- Forward-declared: building the panel needs both, they're defined further
-- down because they presuppose the finished panel.
local RefreshOverlay, ApplyCollapsed

-- Format numbers defensively: if a value is missing, the diagnostic line
-- should show that instead of aborting the build with a format error.
local function N(V) return type(V) == "number" and string.format("%.4g", V) or "?" end

local function Num(V) if type(V) == "number" then return V end return nil end

-- Set further down once RunDump exists. Lets the overlay logic trigger a
-- diagnostic dump on failure without anyone having to press a key.
local AutoDumpHook = nil

--[[
    The anchor is the StatisticsUI's root CanvasPanel.

    v4 hung the panel in StatisticsUI.BuildingsStatBox. That took the game
    down when the statistics window opened:

        EXCEPTION_ACCESS_VIOLATION reading address 0x00000000
        UStatisticsUI::TickUI()          [StatisticsUI.cpp:428]
          -> lambda                      [StatisticsUI.cpp:344]

    TickUI walks the children of BuildingsStatBox and treats each one as a
    BuildingStatTableRow. Our UMG.Border isn't one; the cast returns nullptr
    and the next access reads from 0x0. Any foreign child in a box that C++
    populates is lethal because of this, and EnsureAttached dutifully hung
    it back in there after every rebuild of the list.

    The root canvas, by contrast, is plain blueprint layout. C++ only
    touches it through named pointers there (StatSwitcher 0x348,
    BuildingsStatBox 0x378, ... see UE4SS_ObjectDump.txt), never via
    GetChildAt. That's exactly where the panel hung in v3, and v3 ran
    stably.

    What v3 lacked was the geometry: the slot stayed at default values, the
    panel sat at the top left of the screen, clipped by the game HUD on the
    left and covered by the window on the right. This time the
    CanvasPanelSlot gets the window's own anchors and alignment and is
    placed in its right half, with ZOrder above the window. Visibility is
    guaranteed on the window area: the HUD does sit above the StatisticsUI,
    but the window itself is of course visible.
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

-- Compared by path name: two Lua wrappers of the same UObject aren't
-- necessarily the same Lua object.
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
-- Writing geometry
--
-- The v6 run on 2026-07-26 answered the open questions:
--
--   Panel: is  pos=(20,-260) size=(430,560) alignment=(0,0)
--              anchor=(0,0)-(0,0) autosize=false zorder=1000
--
--   * SetPosition/SetSize/SetAlignment with Lua tables do take effect -
--     all three values were reflected in the slot afterwards.
--   * SetAnchors does NOT take effect. The anchor stayed at (0,0), i.e. top
--     left. The difference to the others: FAnchors is nested
--     ({Minimum={X,Y}, Maximum={X,Y}}), FVector2D is flat.
--   * As a result the panel sat at y = -260 to 260 pixels above the screen
--     edge, the rest behind the HUD's resource bar. Just like v3.
--   * GetCachedGeometry only returns 0x0 through UE4SS, so it's useless
--     for measuring here - and the window's SizeBox has no overrides. The
--     window size simply cannot be obtained this way.
--
-- From this follows the v7 approach: the position is no longer computed in
-- pixels at all, but via stretched anchors as a FRACTION of the canvas
-- area. The Minimum/Maximum anchors span the rectangle, all four offsets
-- are zero - then neither window size nor screen resolution is needed.
--
-- For that the anchors need to actually take. Since the setter can't do it,
-- they're written via the reflected LayoutData property and passed through
-- to the live Slate slot with SetLayout(GetLayout()) - that call is
-- confirmed in the game. It's then read back; if that fails too, the
-- fallback is pixels via the viewport size.
--
-- Field names from UE4SS_ObjectDump.txt:
--   UMG.AnchorData    offsets (FMargin), Anchors (FAnchors), Alignment (FVector2D)
--   Slate.Anchors     Minimum, Maximum (FVector2D)
--   SlateCore.Margin  Left, Top, Right, Bottom
--==========================================================================--

--[[
    Where the panel sits, as a fraction of the canvas area.

    Measured from the screenshot on 2026-07-26 (window horizontally 22.8% to
    77.4%, vertically 15.1% to 84.4% - so the window is centered; the
    earlier note about a rightward shift was an estimation error). The tab
    column on the left side of the window reaches to about 37% and stays
    free; the panel covers the building table.
]]
local PANEL_FRACTION = { L = 0.395, T = 0.205, R = 0.760, B = 0.800 }

--[[
    Collapsed, only the header row remains.

    Pulled up to the top edge of the window: at 0.205 the strip landed right
    on the table's column headings, so it read as something floating over
    the list rather than as its title bar. Up here it overlaps the window's
    own "Buildings" caption instead - decoration rather than information.
]]
local PANEL_FRACTION_COLLAPSED = { L = 0.395, T = 0.155, R = 0.760, B = 0.195 }

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
    return string.format("offsets=(%s,%s,%s,%s) alignment=(%s,%s) anchor=(%s,%s)-(%s,%s) autosize=%s zorder=%s",
        N(S.L), N(S.T), N(S.R), N(S.B), N(S.AX), N(S.AY),
        N(S.AnMinX), N(S.AnMinY), N(S.AnMaxX), N(S.AnMaxY),
        tostring(S.Auto), N(S.Z))
end

-- Anchors range from 0 to 1: comparing with the same tolerance as pixels
-- would consider 0 and 0.5 equal. That's exactly what happened in v6 - the
-- check waved the wrong anchor through and the correction never triggered.
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

-- These three take effect in the game (confirmed in v6). SetAnchors is
-- deliberately missing here: the call runs through fine but sets nothing.
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

        -- The dump spells the field lowercase ("offsets"). FName lookup is
        -- case-insensitive, but the extra check costs nothing.
        local Off = nil
        pcall(function() Off = LD.Offsets end)
        if not Off then pcall(function() Off = LD.offsets end) end
        Off.Left, Off.Top    = Want.L, Want.T
        Off.Right, Off.Bottom = Want.R, Want.B

        LD.Anchors.Minimum.X, LD.Anchors.Minimum.Y = Want.AnMinX, Want.AnMinY
        LD.Anchors.Maximum.X, LD.Anchors.Maximum.Y = Want.AnMaxX, Want.AnMaxY
        LD.Alignment.X, LD.Alignment.Y = 0.0, 0.0
    end)
    -- Pass through to the live Slate slot even if only part of it landed
    -- above: a half-written LayoutData is still better than none.
    pcall(function() Slot:SetLayout(Slot:GetLayout()) end)
    return Written
end

local function ApplySlot(Slot, Want)
    pcall(function() Slot:SetAutoSize(false) end)
    pcall(function() Slot:SetZOrder(PANEL_ZORDER) end)

    -- LayoutData first: only this path gets the anchors set.
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
-- Canvas size (fallback only)
--
-- If the anchors don't take effect even via LayoutData, they stay at
-- (0,0), i.e. top left. Then only computing in pixels helps, and that
-- needs the canvas size. GetCachedGeometry returns 0x0 through UE4SS,
-- WidgetLayoutLibrary.GetViewportSize gives real numbers instead; divided
-- by GetViewportScale that yields the canvas size in Slate units.
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
-- Placement
--==========================================================================--

-- Just for the log line: the real root canvas has exactly one child,
-- namely the window (SizeBox). The geometry no longer comes from there.
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
    local Mode = "fraction of the canvas area"

    if not Ok then
        -- Anchors aren't taking. Compute in pixels from the top left
        -- instead, which needs the canvas size to be known.
        local CW, CH = CanvasSize()
        if Num(CW) then
            Want = {
                AnMinX = 0.0, AnMinY = 0.0, AnMaxX = 0.0, AnMaxY = 0.0,
                L = F.L * CW, T = F.T * CH,
                R = (F.R - F.L) * CW, B = (F.B - F.T) * CH,
            }
            S, Method, Ok = ApplySlot(Slot, Want)
            Mode = string.format("pixel fallback, canvas %sx%s", N(CW), N(CH))
        else
            Mode = "anchors not taking and canvas size unknown"
        end
    end

    return { Want = Want, State = S, Method = Method, Ok = Ok, Mode = Mode,
             WinState = Win.State }
end

-- The WidgetSwitcher shows exactly one page per tab. Which one is the
-- buildings page is searched for rather than guessed: it's the one whose
-- subtree contains BuildingsStatBox. The panel should only be visible
-- there.
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
    Panel color.

    A freshly constructed UMG.Border carries a brush without a texture and
    therefore paints a white rectangle - white text on it would be
    unreadable. Hence the same caution as with the slot: set it, read it
    back (Border.BrushColor is reflected as FLinearColor), and if needed
    write the property directly and pass it through the setter.
]]
-- Opaque, not translucent. At A = 0.88 the game's building table showed
-- through the text and made it hard to read - the background needs to
-- actually cover the area.
local PANEL_COLOR = { R = 0.04, G = 0.04, B = 0.045, A = 1.0 }

--[[
    Set a Border's fill, with the same belt-and-braces as the panel: write
    it, read it back, and if the setter didn't take, write the property
    directly and pass it through the setter.

    Used for the row chips too. Alpha needs checking alongside R because the
    transparent fill and a dark fill can share the same R.
]]
local function ApplyBrushColor(Border, C)
    pcall(function() Border:SetBrushColor(C) end)

    local R, A = nil, nil
    pcall(function() R, A = Border.BrushColor.R, Border.BrushColor.A end)
    if Near(R, C.R, 0.01) and Near(A, C.A, 0.01) then return "Setter" end

    local Written = pcall(function()
        local B = Border.BrushColor
        B.R, B.G, B.B, B.A = C.R, C.G, C.B, C.A
    end)
    pcall(function() Border:SetBrushColor(Border.BrushColor) end)
    pcall(function() R, A = Border.BrushColor.R, Border.BrushColor.A end)
    if Near(R, C.R, 0.01) and Near(A, C.A, 0.01) then return "Property" end
    return Written and "unconfirmed" or "failed"
end

local function SetPanelColor(Border)
    return ApplyBrushColor(Border, PANEL_COLOR)
end

--[[
    Text colour.

    FSlateColor wraps an FLinearColor, so it is the same nested shape that
    made SetAnchors fail without complaining. It gets written the way the
    anchors eventually were: mutate the reflected property in place, hand
    the returned struct back through the setter (a returned struct does pass
    as a parameter - that much is confirmed in-game), then read it back.

    ColorUseRule has to be 0 (UseColor_Specified), otherwise SpecifiedColor
    is ignored in favour of the inherited style.
]]
local function ApplyTextColor(Text, C, Alpha)
    Alpha = Alpha or 1.0
    pcall(function()
        local SC = Text.ColorAndOpacity
        SC.SpecifiedColor.R, SC.SpecifiedColor.G = C.R, C.G
        SC.SpecifiedColor.B, SC.SpecifiedColor.A = C.B, Alpha
        SC.ColorUseRule = 0
    end)
    pcall(function() Text:SetColorAndOpacity(Text.ColorAndOpacity) end)

    --[[
        This last call is not about the alpha - it is what makes the colour
        count at all.

        FSlateColor only uses SpecifiedColor when ColorUseRule says so;
        otherwise it falls back to the inherited style, which is white.
        Writing that byte through the property does not take, so the value
        landed correctly and was then ignored - the log said the colour
        "works" while every row rendered white.

        UTextBlock::SetOpacity reads GetSpecifiedColor (whatever we just
        wrote), replaces the alpha, and re-wraps it as FSlateColor(colour) -
        and that constructor sets the rule to Specified. So it carries the
        hue through and flips the switch that the direct write could not.
    ]]
    pcall(function() Text:SetOpacity(Alpha) end)

    local R, A, Rule = nil, nil, nil
    pcall(function()
        R = Text.ColorAndOpacity.SpecifiedColor.R
        A = Text.ColorAndOpacity.SpecifiedColor.A
        Rule = Text.ColorAndOpacity.ColorUseRule
    end)
    -- A stored colour that the rule ignores is not applied, so the rule is
    -- part of the check.
    return Near(R, C.R, 0.02) and Near(A, Alpha, 0.02) and (Rule == 0)
end

local function LogPlacement(P)
    if not P then
        Log("  Panel:   attached without slot, position determined by the game")
        return
    end
    Log(string.format("  Window:  slot %s", SlotText(P.WinState or {})))
    Log(string.format("  Panel:   want offsets=(%s,%s,%s,%s) anchor=(%s,%s)-(%s,%s) [%s]",
        N(P.Want.L), N(P.Want.T), N(P.Want.R), N(P.Want.B),
        N(P.Want.AnMinX), N(P.Want.AnMinY), N(P.Want.AnMaxX), N(P.Want.AnMaxY),
        P.Mode))
    -- This is the line that v5 was missing: not the wish, but what the
    -- slot actually says afterwards.
    Log(string.format("  Panel:   is   %s", SlotText(P.State)))
    Log(string.format("  Panel:   written via %s, applied=%s",
        P.Method, tostring(P.Ok)))
end

local function BuildOverlay()
    if Overlay.Attempts >= MAX_BUILD_ATTEMPTS then return false end

    -- No StatisticsUI yet: that's the normal case in the main menu and
    -- doesn't count as a failed attempt, otherwise the budget would be
    -- used up after 30 seconds in the menu.
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
            error("UMG classes not found")
        end
        local HBoxClass = StaticFindObject("/Script/UMG.HorizontalBox")
        if not HBoxClass then error("UMG.HorizontalBox not found") end
        WidgetClasses = { Text = TextClass, Button = ButtonClass,
                          HBox = HBoxClass, Border = BorderClass }

        --  Border                          background and outer border
        --    VerticalBox                   header row / column header / list
        --      Button > TextBlock          header row, collapses and expands
        --      Button > HorizontalBox      column header, doesn't scroll along
        --      ScrollBox                   the list, grows with the cache
        --        Button > HorizontalBox    one per row, from the pool
        --
        -- All of this belongs to us; no C++ code walks through these
        -- children. That's exactly what killed v4 (foreign child in
        -- BuildingsStatBox).
        local Border = StaticConstructObject(BorderClass, Canvas)
        local Box    = StaticConstructObject(BoxClass, Canvas)
        local Scroll = StaticConstructObject(ScrollClass, Canvas)

        local HeaderBtn, HeaderText = MakeBarButton(Canvas)
        HeaderText:SetText(FText(BuildHeaderText(0, 0)))

        -- The column header is deliberately built like a row, button
        -- included: otherwise it would have different padding than the
        -- rows below it and the columns would sit off. Its chip is blanked
        -- and made transparent - a fresh UMG.Border paints white, which
        -- would otherwise put a bright block above the list.
        local ColBtn, ColCells = MakeRowButton(Canvas)
        pcall(function() ColCells.Name:SetText(FText(COLUMN_TITLE)) end)
        pcall(function() ColCells.ChipText:SetText(FText("")) end)
        pcall(function() ApplyBrushColor(ColCells.Chip, CHIP.none) end)

        -- The scan button sits between the title and the table: it acts on
        -- the whole list below it, so it belongs above that list and inside
        -- the part that collapses away with it.
        -- Built like a data row, not as bare text: it is clickable, and the
        -- one rule this panel has is that a filled chip means the row does
        -- something. Gold, because gold already means "this moves the
        -- camera" - and reading every building is exactly that.
        local ScanBtn, ScanCells = MakeRowButton(Canvas)
        local SName, SAction = BuildScanRow()
        pcall(function() ScanCells.Name:SetText(FText(SName)) end)
        pcall(function() ScanCells.ChipText:SetText(FText(SAction)) end)
        pcall(function() ApplyBrushColor(ScanCells.Chip, CHIP.jump) end)

        Box:AddChild(HeaderBtn)
        Box:AddChild(ScanBtn)
        Box:AddChild(ColBtn)
        Overlay.ScanBtn, Overlay.ScanCells = ScanBtn, ScanCells
        Overlay.ColumnHead = ColBtn
        local ScrollSlot = Box:AddChild(Scroll)
        -- Without a fill rule the ScrollBox stays at its desired height and
        -- the list doesn't use the panel's full space. ESlateSizeRule:
        -- 0 Automatic, 1 Fill. FSlateChildSize is flat, so it goes through
        -- as a table.
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
            -- No slot means no geometry, but the panel is still visible.
            pcall(function() Canvas:AddChild(Border) end)
        end

        Overlay.Root, Overlay.Box, Overlay.Scroll, Overlay.Slot = Border, Box, Scroll, Slot
        Overlay.HeaderBtn, Overlay.HeaderText = HeaderBtn, HeaderText
        Overlay.Canvas = Canvas
        -- The row pool belonged to the old ScrollBox. After a rebuild -
        -- e.g. on a game switch - its entries point at widgets that no
        -- longer hang in any tree; they would never become visible again.
        Overlay.Rows, Overlay.RowCount = {}, 0
        if IsValidObj(Slot) then
            Placed = PlacePanel(Slot, Canvas)
            Overlay.Placed = Placed
        end
    end)

    if not ok then
        Log(string.format("Overlay build failed (attempt %d/%d): %s",
            Overlay.Attempts, MAX_BUILD_ATTEMPTS, tostring(err)))
        Overlay.Root, Overlay.Box, Overlay.Scroll = nil, nil, nil
        Overlay.HeaderBtn, Overlay.HeaderText, Overlay.ColumnHead = nil, nil, nil
        Overlay.ScanBtn, Overlay.ScanCells = nil, nil
        Overlay.Slot, Overlay.Canvas = nil, nil
        Overlay.Rows, Overlay.RowCount = {}, 0
        if Overlay.Attempts >= MAX_BUILD_ATTEMPTS and AutoDumpHook then
            -- Given up: write the StatisticsUI down once, so the failure
            -- can be traced without the player having to do anything.
            AutoDumpHook("statistics")
        end
        return false
    end

    Overlay.Switcher, Overlay.PaneIndex = FindBuildingsPane(StatUI)
    Overlay.Shown = nil
    SetWidgetVisible(Overlay.Root, true)
    Overlay.Mounted = true

    Log("Overlay attached to the StatisticsUI root canvas (no longer inside BuildingsStatBox).")
    LogPlacement(Placed)
    Log(string.format("  Color:   set via %s", ColorMethod))
    Log(string.format("  Building tab: StatSwitcher=%s, page index=%s",
        IsValidObj(Overlay.Switcher) and "yes" or "no", tostring(Overlay.PaneIndex)))

    -- Fills the list and restores the remembered collapsed/expanded state.
    pcall(ApplyCollapsed)
    Log(string.format("  Rows:    %d built, panel %s", Overlay.RowCount,
        Settings.collapsed and "collapsed" or "expanded"))
    return true
end

-- The canvas is static blueprint layout, but still cheap to check: the UI
-- can be rebuilt on a game switch. If our panel is gone, re-attaching it
-- with its geometry is enough - no need to rebuild it.
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

-- Only visible on the buildings tab. If the active tab can't be read, the
-- panel stays visible: better in the way than nowhere to be found.
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
    Creating rows costs widgets, so they're built once and only relabeled
    after that. Excess ones disappear via Collapsed instead of being
    destroyed - detaching a widget from the hierarchy while Slate might be
    drawing it right then is exactly the kind of bet that caused the
    crashes in v1/v2.
]]
-- Just the scan row, so progress can count every single building without
-- rebuilding the whole list for each one. Two SetText calls against the
-- hundreds a full refresh would cost.
local function RefreshScanRow()
    if not Overlay.ScanCells then return end
    local Name, Act = BuildScanRow()
    pcall(function() Overlay.ScanCells.Name:SetText(FText(Name)) end)
    pcall(function() Overlay.ScanCells.ChipText:SetText(FText(Act)) end)
end

function RefreshOverlay()
    if not IsValidObj(Overlay.Root) then return end

    -- One pass through the building table per refresh, not per tick: only
    -- counted when the content actually changed.
    if CountBuildingsHook then pcall(CountBuildingsHook) end

    local Model, TypeCount, OpenCount = BuildRowModel()
    pcall(function()
        Overlay.HeaderText:SetText(FText(BuildHeaderText(TypeCount, OpenCount)))
    end)
    RefreshScanRow()

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

        pcall(function() R.Cells.Name:SetText(FText(M.name or "")) end)
        pcall(function() R.Cells.ChipText:SetText(FText(M.action or "")) end)

        -- Completed rows stay but recede: removing them would delete the
        -- information, and keeping them equally bright would draw the eye
        -- just as much as what's still left to do. Unaffordable ones sit
        -- between the two - readable, but visibly not on offer.
        local Alpha = M.alpha or 1.0

        --[[
            One writer for the name's colour AND its brightness.

            SetOpacity and SetColorAndOpacity both write ColorAndOpacity -
            SetOpacity replaces the whole struct, keeping the hue but
            resetting alpha. Cached independently they took turns
            overwriting each other, so the same state showed up at two
            different brightnesses depending on which happened to run last.
            Now they are one call with one cache key.

            And it is only remembered once the write verifiably took:
            marking it done on a silent failure is what left some rows
            stuck on a colour meant for whatever the pool showed before.
        ]]
        local Col  = M.color or "default"
        local Want = Col .. "@" .. tostring(Alpha)
        if R.NameStyle ~= Want then
            local ok, applied = pcall(ApplyTextColor, R.Cells.Name,
                TEXT_COLOR[Col] or TEXT_COLOR.default, Alpha)
            ColorWorks = (ok and applied) or false
            if ok and applied then R.NameStyle = Want end
        end

        -- The chip has no colour of its own, so brightness there is still
        -- SetOpacity - nothing else writes it. A dimmed row can still have
        -- a fully readable chip: the name says whether there is work, the
        -- chip says whether it goes somewhere.
        local ChipAlpha = M.chipAlpha or Alpha
        if R.ChipAlpha ~= ChipAlpha then
            pcall(function() R.Cells.ChipText:SetOpacity(ChipAlpha) end)
            R.ChipAlpha = ChipAlpha
        end

        -- Only rewritten when the state actually changes: a readback per
        -- chip per refresh would be a few hundred reflected calls for
        -- nothing.
        local Kind = M.chip or "none"
        if R.ChipKind ~= Kind then
            pcall(function() ApplyBrushColor(R.Cells.Chip, CHIP[Kind] or CHIP.none) end)
            R.ChipKind = Kind
        end

        SetWidgetVisible(R.Btn, true)
    end

    for i = Wanted + 1, #Overlay.Rows do
        local R = Overlay.Rows[i]
        R.Model, R.Pressed = nil, false
        SetWidgetVisible(R.Btn, false)
    end

    Overlay.RowCount = Wanted

    -- Both worth knowing on the next run and neither visible from inside
    -- the game: whether the list got cut short, and whether colouring text
    -- works at all through UE4SS.
    if #Model > MAX_ROWS then
        Log(string.format("List truncated: %d rows wanted, showing %d", #Model, MAX_ROWS))
    end
    if ColorWorks ~= nil and not ColorReported then
        ColorReported = true
        Log(string.format("Text colour via FSlateColor: %s",
            ColorWorks and "works" or "IGNORED - rows differ only in brightness"))
    end
end

-- Collapse and expand. The list disappears, and the slot is recomputed to
-- the narrow strip - otherwise an invisible but click-catching area would
-- still sit over the building table.
function ApplyCollapsed()
    if IsValidObj(Overlay.Scroll) then
        SetWidgetVisible(Overlay.Scroll, not Settings.collapsed)
    end
    -- The column header and the scan button belong to the list and go away
    -- with it; collapsed, a label without a table underneath would
    -- otherwise remain.
    if IsValidObj(Overlay.ColumnHead) then
        SetWidgetVisible(Overlay.ColumnHead, not Settings.collapsed)
    end
    if IsValidObj(Overlay.ScanBtn) then
        SetWidgetVisible(Overlay.ScanBtn, not Settings.collapsed)
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
    Log(string.format("Panel %s", Settings.collapsed and "collapsed" or "expanded"))
end

--==========================================================================--
-- Acting
--
-- Two paths, both via parameterless UFunctions from the object dump:
--
--   buy   PunButton:OnButtonDown / PunSplitButton:OnButtonDown1|2 on the
--         upgrade button in the open description panel. It already carries
--         the building and callback enum in itself - nothing to set.
--   jump  BuildingStatTableRow.GotoButton:OnButtonDown, i.e. the magnifier
--         next to the building table. That's the only way reachable from
--         Lua to select a specific building; DescriptionUISystem has
--         neither functions nor properties.
--==========================================================================--

local function SetNotice(Fmt, ...)
    Notice.Text = string.format(Fmt, ...)
    Notice.Ticks = 4
    pcall(RefreshOverlay)
    Log("Click: " .. Notice.Text)
end

--[[
    Clearance for a C++ click.

    OnButtonDown dereferences _callbackParent. If it isn't set, the game
    reads from 0x0 - that was the EXCEPTION_ACCESS_VIOLATION from v1/v2, and
    a CDO from FindAllOf carries nothing there. The property is reflected,
    so this can be checked beforehand instead of regretted afterward.
]]
local function ClickSafe(W)
    if not IsValidObj(W) or IsTemplate(W) then return false end
    local Parent = nil
    pcall(function() Parent = W["_callbackParent"] end)
    return IsValidObj(Parent)
end

local function CallHandler(W, FnName)
    if not ClickSafe(W) then return "button not clickable (_callbackParent missing)" end
    local ok, err = pcall(function() W[FnName](W) end)
    if not ok then return tostring(err) end
    return nil
end

-- What's currently in the description panel. The pointers in it are only
-- valid until the next selection, so it's read fresh on every click
-- instead of being remembered.
local function LiveDescription()
    local DescUI = GetDescriptionUI(false)
    if not DescUI then return nil, nil end
    local S = ScrapeDescriptionPanel(DescUI)
    if not S then return nil, nil end
    return TypeKey(S.title), S
end

--[[
    Is the open description panel the building this row belongs to?

    The type alone isn't enough once rows are per building: clicking
    "#2 Knowledge Sharing" while #1 is selected would buy it on #1. There is
    no building id to compare - the simulation is C++ without reflection -
    so the comparison is over the upgrade list itself.

    That happens to fail exactly when it matters. Two buildings with
    identical upgrade state are interchangeable for a purchase, and their
    lists match; two that differ are the case worth catching, and their
    lists differ.
]]
local function SameUpgradeState(S, Entry)
    if not Entry or #S.upgrades ~= #Entry.upgrades then return false end
    for i, U in ipairs(Entry.upgrades) do
        local L = S.upgrades[i]
        if not L or L.label ~= U.label or L.state ~= U.state then return false end
    end
    return true
end

local function ScanEntry(Key, Ord)
    if not Ord then return nil end
    for _, B in ipairs(ScanData.Buildings) do
        if B.key == Key and B.ord == Ord then return B end
    end
    return nil
end

local function FireUpgrade(Key, Label, Ord)
    local LiveKey, S = LiveDescription()
    if not LiveKey then return "no building selected" end
    if LiveKey ~= Key then return string.format("%s is selected", LiveKey) end

    -- Only rows that came from a scan carry an ordinal, and only those can
    -- be checked this way.
    local Entry = ScanEntry(Key, Ord)
    if Entry and not SameUpgradeState(S, Entry) then
        return string.format("a different %s is selected", Key)
    end

    local Hit = S.live and S.live[Label]
    if not Hit then return "row not found in the open panel" end
    return CallHandler(Hit.W, Hit.Fn)
end

--[[
    The building table lists one row per BUILDING, not per type - five
    beehives produce five rows named "Beekeeper". That's why the whole
    subtree is walked instead of stopping at the first row: otherwise every
    click would jump to the same building, and the rest would only be
    reachable via the arrows in the description window.
]]
local function WalkStatRows(Node, Visit, Depth, Seen)
    Seen = Seen or { n = 0 }
    if not IsValidObj(Node) or (Depth or 0) > 4 or Seen.n >= MAX_ROWS then return Seen end

    if ClassName(Node):find("BuildingStatTableRow", 1, true) then
        Seen.n = Seen.n + 1
        -- BuildingName is a Pun widget in the game, which holds the text
        -- one level deeper - like everywhere here, hence DeepText.
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
    if not StatUI then return nil, "StatisticsUI not found" end
    local Box = nil
    pcall(function() Box = StatUI["BuildingsStatBox"] end)
    if not IsValidObj(Box) then return nil, "BuildingsStatBox not found" end
    return Box, nil
end

local function StatRowsFor(Key)
    local Box, Err = StatBox()
    if not Box then return nil, Err end

    local Rows = {}
    WalkStatRows(Box, function(K, Row)
        if K == Key then Rows[#Rows + 1] = Row end
    end, 0)

    if #Rows == 0 then return nil, string.format("no stat row for %s", Key) end
    return Rows, nil
end

-- How many buildings there are per type. One pass counts every type at
-- once; the count then shows up in the overview so it's visible how much
-- there is to jump through.
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
    -- The magnifier first: it's a PunButton and can be fully checked.
    -- Only if that's missing, the row's own handler - it has no
    -- _callbackParent, but it is the click target and not a pointer that
    -- could be missing anything.
    local Goto = nil
    pcall(function() Goto = Row["GotoButton"] end)
    if ClickSafe(Goto) then return CallHandler(Goto, "OnButtonDown") end

    if IsTemplate(Row) then return "stat row is a template" end
    local ok, err = pcall(function() Row:OnButtonDown() end)
    if not ok then return tostring(err) end
    return nil
end

--[[
    Where the last jump per building type left off.

    Deliberately just a counter, no remembered row: the table is
    continuously repopulated by C++, so remembered widgets would go stale
    quickly. If the row count changes, the counter starts over from the
    front.
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

-- Jump to one specific building rather than the next one. Scanned rows know
-- which of the three Beekeepers they mean, so "click again to buy" has to
-- land on that one and not merely on the next.
local function JumpToOrdinal(Key, Ord)
    local Rows, Err = StatRowsFor(Key)
    if not Rows then return Err end
    if Ord < 1 or Ord > #Rows then
        return string.format("%s #%d no longer exists - scan again", Key, Ord)
    end

    -- Keep the cycling cursor in step, so a later click on the type row
    -- carries on from here instead of jumping back to the front.
    JumpCursor[Key] = { index = Ord, total = #Rows }

    local CErr = ClickStatRow(Rows[Ord])
    if CErr then return CErr end
    return nil, Ord, #Rows
end

-- "Beekeeper 2/5" instead of just "Beekeeper": without the count, a jump to
-- the next building of the same type would look like no jump at all.
local function Where(Index, Total)
    if not Index or not Total or Total <= 1 then return "" end
    return string.format(" %d/%d", Index, Total)
end

local function ActivateRow(M)
    if M.kind == "type" then
        local err, Index, Total = JumpToType(M.key)
        if err then SetNotice("%s: %s", M.key, err)
        else SetNotice("jump to %s%s", M.key, Where(Index, Total)) end
        return
    end

    -- A building heading goes to that exact one, where the type row only
    -- steps to the next.
    if M.kind == "building" then
        local err, Index, Total = JumpToOrdinal(M.key, M.ord)
        if err then SetNotice("%s #%d: %s", M.key, M.ord, err)
        else SetNotice("jump to %s%s", M.key, Where(Index, Total)) end
        return
    end

    if M.kind ~= "upgrade" then return end

    local err = FireUpgrade(M.key, M.label, M.ord)
    if not err then
        -- The cache still shows the upgrade as open; that clears itself up
        -- the next time the panel is read.
        SetNotice("bought: %s", M.label)
        return
    end

    -- Wrong building selected. A scanned row knows exactly which one it
    -- wants, so it goes straight there instead of cycling and hoping.
    local JErr, Index, Total
    if M.ord then
        JErr, Index, Total = JumpToOrdinal(M.key, M.ord)
    else
        JErr, Index, Total = JumpToType(M.key)
    end

    if JErr then
        SetNotice("%s (%s)", err, JErr)
    else
        SetNotice("%s - jumping to %s%s, click again",
            err, M.key, Where(Index, Total))
    end
end

--==========================================================================--
-- Collecting everything at once
--
-- Reading a building means selecting it, and selecting it moves the camera.
-- So this cannot run in the background - it is a button the player presses
-- when they want the overview brought up to date, and it can be stopped
-- mid-way by pressing it again.
--
-- Stepping is driven by the click loop rather than a wait: Lua can't block
-- here, and the description panel needs a few frames to rebuild after a
-- selection. SCAN_SETTLE polls at POLL_MS each is the gap between selecting
-- a building and reading it.
--==========================================================================--

local SCAN_SETTLE = 3

local function ScanProgress()
    if not Scan.Active or not Scan.Rows then return nil end
    return math.min(Scan.Index, #Scan.Rows), #Scan.Rows
end

local function StopScan(Reason)
    if not Scan.Active then return end
    Scan.Active = false
    local Done = Scan.Result and #Scan.Result or 0

    if Done > 0 then
        local Stamp = ""
        pcall(function() Stamp = os.date("%Y-%m-%d %H:%M:%S") end)
        ScanData = { At = Stamp, Buildings = Scan.Result }
        CacheDirty = true
    end

    Scan.Rows, Scan.Result, Scan.Seen = nil, nil, nil
    Log(string.format("Scan %s: %d buildings read", Reason, Done))
    pcall(RefreshOverlay)
end

local function StartScan()
    local Box, Err = StatBox()
    if not Box then
        SetNotice("cannot scan: %s", Err or "no building table")
        return
    end

    local Rows = {}
    WalkStatRows(Box, function(_, Row) Rows[#Rows + 1] = Row end, 0)
    if #Rows == 0 then
        SetNotice("cannot scan: no buildings in the table")
        return
    end

    Scan.Active, Scan.Rows, Scan.Index, Scan.Wait = true, Rows, 0, 0
    Scan.Seen, Scan.Result = {}, {}
    Log(string.format("Scan started: %d buildings", #Rows))
    pcall(RefreshOverlay)
end

local function ScanStep()
    if not Scan.Active then return end
    if Scan.Wait > 0 then Scan.Wait = Scan.Wait - 1 return end

    -- Read whatever the previous step selected. Numbering is by arrival, so
    -- the ordinal matches the order the building table lists them in - the
    -- same order JumpToOrdinal walks later.
    if Scan.Index >= 1 then
        local LiveKey, S = LiveDescription()
        if LiveKey and S then
            local Ord = (Scan.Seen[LiveKey] or 0) + 1
            Scan.Seen[LiveKey] = Ord
            Scan.Result[#Scan.Result + 1] =
                { key = LiveKey, ord = Ord, upgrades = S.upgrades }
        end
    end

    Scan.Index = Scan.Index + 1
    if Scan.Index > #Scan.Rows then
        StopScan("finished")
        return
    end

    local Err = ClickStatRow(Scan.Rows[Scan.Index])
    if Err then
        -- A row that can't be selected is skipped rather than aborting the
        -- run: one stale widget shouldn't cost the whole scan.
        Scan.Wait = 0
    else
        Scan.Wait = SCAN_SETTLE
    end

    -- Counts every single building: only the scan row is rewritten, which
    -- is two SetText calls rather than the hundreds a full refresh costs.
    pcall(RefreshScanRow)
end

--[[
    Polling clicks.

    UE4SS 3.0.1 can't bind a delegate from Lua (RegisterCustomEvent only
    works on BP-owned UFunctions), so polling is the only option.
    Button:IsPressed is true while the mouse is held down; triggered on the
    rising edge so a hold doesn't turn into many clicks.

    The rows are only polled while the cursor is actually over the panel.
    Otherwise, with 120 rows, that would be around 2000 calls per second,
    every single one returning false.
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

    -- Same rising edge for the scan button. Pressing it while a run is
    -- going stops that run, so the player is never stuck watching the
    -- camera tour the town.
    local ScanDown = nil
    pcall(function() ScanDown = Overlay.ScanBtn:IsPressed() end)
    if ScanDown == true then
        if not Overlay.ScanPressed then
            Overlay.ScanPressed = true
            if Scan.Active then pcall(StopScan, "stopped")
            else pcall(StartScan) end
        end
    else
        Overlay.ScanPressed = false
    end

    -- Row clicks while a scan is running would fight it for the selection.
    if Scan.Active then return end

    -- Only save work on an explicit "no". If IsHovered returns nothing at
    -- all through UE4SS - like GetCachedGeometry, which only ever gave
    -- 0x0 - it's better to poll every row than to lose the controls.
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
        if M and (M.kind == "type" or M.kind == "building" or M.kind == "upgrade") then
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
    Status line.

    Answers the questions that would otherwise only get resolved by another
    game restart: is the widget switched to visible, does the Slate tree
    consider it visible, where does its slot actually end up, and does the
    active tab match the page being looked for.

    The drawn area is deliberately no longer in here: GetCachedGeometry only
    returns 0x0 through UE4SS (measured in the v6 run) and isn't useful for
    this.

    Only written on change and at most a handful of times, otherwise
    UE4SS.log fills up once a second.
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
        "  State:   visibility=%s drawn=%s tab=%s (building=%s) | slot %s",
        Vis, Drawn, Active, tostring(Overlay.PaneIndex),
        SlotText(SlotState(Overlay.Slot)))
    if Line == Diag.Last then return end
    Diag.Last = Line
    Diag.Count = Diag.Count + 1
    Log(Line)
end

--==========================================================================--
-- Recon dump (carried over from v3, still useful unchanged)
--==========================================================================--

local MAX_DEPTH = 10
local MAX_NODES = 1500

-- TooltipWidget is the important entry: every row and every button drags
-- along a complete TooltipWidget_C subtree of about 30 nodes. In the first
-- v3 run that ate the whole budget in the title widget on the Forester
-- panel, and the upgrade rows were never reached.
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

                -- Only descend into widgets, otherwise we end up in the
                -- game manager.
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
        Log(string.format("%s%s [%s] (already dumped)", Indent, Label, ClassName(W)))
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
        Log("ERROR: ObjectDescriptionUI unreachable")
        return
    end
    Log("_objectDescriptionUI = " .. FullName(DescUI))

    Log("")
    Log("### Upgrade summary ###")
    local Scraped = ScrapeDescriptionPanel(DescUI)
    if Scraped then
        Log(string.format("Building: %s (type %s), %d upgrades",
            Scraped.title, TypeKey(Scraped.title), #Scraped.upgrades))
        for _, U in ipairs(Scraped.upgrades) do
            Log(string.format("  %-6s %-28s %s", U.state, U.label,
                U.cost and (U.cost .. (U.affordable and "" or " (too expensive)")) or ""))
        end
    else
        Log("no building selected / no upgrade rows found")
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
            Log(string.format("(%d nodes)", NodeCount))
        else
            Log(PName .. " invalid")
        end
    end
end

local function DumpStatisticsUI()
    local HUD = GetHUD(true)
    if not HUD then return end

    local StatUI = nil
    pcall(function() StatUI = HUD["_statisticsUI"] end)
    if not IsValidObj(StatUI) then
        Log("ERROR: _statisticsUI invalid/null")
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
        Log("WidgetTree/RootWidget invalid")
    end
    Log(string.format("(%d nodes)", NodeCount))

    Log("")
    Log("### Live BuildingStatTableRow_C instances ###")
    local Rows = nil
    pcall(function() Rows = FindAllOf("BuildingStatTableRow_C") end)
    if not Rows then
        Log("none found (Statistics -> Buildings open?)")
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
    Log(string.format("%d real rows (CDO/archetype filtered out)", n))
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
        Log("(" .. RECON_FILE .. " not writable, output only in UE4SS.log)")
    end
    local ok, err = pcall(Fn)
    if not ok then Log("DUMP ERROR: " .. tostring(err)) end
    Log("=== done ===")
    CloseOut()
end

--==========================================================================--
-- Main loop
--==========================================================================--

--[[
    Diagnostics without a keypress.

    Dumps used to sit on Ctrl+Shift+B and Ctrl+Shift+N. But UE4SS keybinds
    don't swallow the key: the game gets the B as well and opens the build
    menu every time. So there's no keybind at all anymore - the mod writes
    a dump on its own when it needs one, and at most once per session per
    kind.
]]
local AutoDumped = {}

local function AutoDump(Kind)
    if AutoDumped[Kind] then return end
    AutoDumped[Kind] = true
    if Kind == "statistics" then
        RunDump("StatisticsUI (automatic)", DumpStatisticsUI)
    elseif Kind == "description" then
        RunDump("ObjectDescriptionUI (automatic)", DumpDescriptionUI)
    end
end

AutoDumpHook = AutoDump

local function Tick()
    local DescUI = GetDescriptionUI(false)
    if not DescUI then return end

    local Scraped = ScrapeDescriptionPanel(DescUI)
    if not Scraped then return end

    if #Scraped.upgrades == 0 then
        -- Panel with a title but no upgrade row recognized: either the
        -- building really has none, or the row types no longer match.
        -- Write it down once so it can be checked.
        AutoDump("description")
        return
    end

    if Remember(Scraped) then RefreshOverlay() end
end

-- On the side: let notices in the header row expire again and write out a
-- changed cache. The toggle changes it too, not just a newly recorded
-- building.
local function HouseKeeping()
    if Notice.Ticks > 0 then
        Notice.Ticks = Notice.Ticks - 1
        if Notice.Ticks == 0 then
            Notice.Text = nil
            RefreshOverlay()
        end
    end
    if CacheDirty then
        -- Not writable: the cache stays valid in memory regardless, but it
        -- mustn't retry and log every single second.
        if not SaveCache() then CacheDirty = false end
    end
end

LoadCache()

LoopAsync(1000, function()
    ExecuteInGameThread(function()
        pcall(Tick)
        -- At game start there's neither a HUD nor a StatisticsUI, and the
        -- panel may get rebuilt on a game switch. So keep trying until it
        -- sticks, and watch it after that.
        if not IsValidObj(Overlay.Root) then
            if Overlay.Mounted then
                -- Was there before and is gone: allowed to rebuild.
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
    return false -- false = keep running
end)

-- Second, fast loop just for clicks. It needs to tick noticeably tighter
-- than the once-a-second loop, otherwise a short mouse click falls between
-- two polls and gets lost.
LoopAsync(POLL_MS, function()
    ExecuteInGameThread(function()
        pcall(PollClicks)
        -- Driven from the same loop rather than a timer: a scan step has to
        -- happen between frames anyway, and this way stopping it is always
        -- one poll away.
        pcall(ScanStep)
    end)
    return false
end)

Log("KRBuildingUpgrades v16 loaded. No keybind needed: the panel sits in "
    .. "the statistics window, Buildings tab. Clicking the header row "
    .. "collapses it. 'collect all information' reads every building once "
    .. "(this moves the camera; click again to stop). Rows with a filled "
    .. "chip on the right do something - gold jumps to a building, green "
    .. "buys that upgrade on the building the row names. Upgrades you "
    .. "can't afford have no chip and are not clickable.")
