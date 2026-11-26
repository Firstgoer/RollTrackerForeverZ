local TOCNAME, RTC = ...
local L = setmetatable({}, {__index = function(_, k) return RTC.L[k] end})

RollTrackerClassic_Addon = RTC
local GetAddOnMetadata
if C_AddOns and C_AddOns.GetAddOnMetadata then
    GetAddOnMetadata = C_AddOns.GetAddOnMetadata
elseif _G.GetAddOnMetadata then
    GetAddOnMetadata = _G.GetAddOnMetadata
end
RTC.Version = GetAddOnMetadata(TOCNAME, "Version")
RTC.Title = GetAddOnMetadata(TOCNAME, "Title")

RTC.MAXRARITY = 6
RTC.IconDice = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
RTC.IconGreed = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
RTC.IconPass = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
RTC.IconLoot = "Interface\\GroupFrame\\UI-Group-MasterLooter"
RTC.TxtEscapePicture = "|T%s:0|t"
RTC.TxtEscapeIcon = "|T%s:0:0:0:0:64:64:4:60:4:60|t"

RTC.MSGPREFIX = "RTC: "
RTC.MSGPREFIX_START = "RTC.StartRoll: "
RTC.LOOTTRACKER_MAXLINES = 1000
RTC.CLASSIC_ERA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
RTC.BCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
-- WoW: Forever ("Camelot", interface 16001) runs on the modern 12.x API
RTC.FOREVER = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

-- API compatibility (Forever / modern clients moved many globals into C_ namespaces)
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemClassInfo = (C_Item and C_Item.GetItemClassInfo) or _G.GetItemClassInfo
local SendChatMessage = (C_ChatInfo and C_ChatInfo.SendChatMessage) or _G.SendChatMessage
local issecretvalue = _G.issecretvalue or function() return false end

-- Chat payloads are "secret" (unreadable by addons) while chat messaging lockdown
-- is active (boss encounters, M+, rated PvP); addons may not send chat then either.
local function InChatLockdown()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and
               C_ChatInfo.InChatMessagingLockdown() or false
end
RTC.InChatLockdown = InChatLockdown

local function IsReadable(...)
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end
RTC.IsReadable = IsReadable

-- Group loot roll window: modern clients use GroupLootHistoryFrame
local function ModernLootHistory() return GroupLootHistoryFrame ~= nil end
local function GetLootHistoryFrame()
    return GroupLootHistoryFrame or LootHistoryFrame
end

function RTC.GetPlayerList(unsort)
    local count, start
    local prefix
    local ret = {}
    local retName = {}

    if IsInRaid() then
        prefix = "raid"
        count = MAX_RAID_MEMBERS
        start = 1
    else
        prefix = "party"
        count = MAX_PARTY_MEMBERS
        start = 0
    end

    for index = start, count do
        local guildName, guildRankName
        local id
        if index > 0 then
            id = prefix .. index
        else
            id = "player"
        end
        local name = GetUnitName(id)
        local _, englishClass = UnitClass(id)
        if not IsReadable(name) then name = nil end
        if not IsReadable(englishClass) then englishClass = nil end

        local rank = ""
        if name ~= nil then
            local guid = UnitGUID(id)
            if IsInGuild() and guid and IsReadable(guid) and UnitIsInMyGuild(id) then
                local order = C_GuildInfo.GetGuildRankOrder(guid)
                local rankName = order and GuildControlGetRankName(order)
                if rankName then rank = "<" .. rankName .. ">" end
            else
                guildName, guildRankName = GetGuildInfo(id)
                if IsReadable(guildName, guildRankName) and guildName and
                    guildRankName then
                    rank = "<" .. guildName .. " / " .. guildRankName .. ">"
                end
            end
        end

        if name ~= nil then

            local entry = {
                ["name"] = name,
                ["rank"] = rank,
                ["class"] = englishClass
            }
            tinsert(ret, entry)
            retName[name] = entry
        end
    end

    if unsort then
        sort(ret, function(a, b)
            return
                ((a.class or "") < (b.class or "") or
                    ((a.class or "") == (b.class or "") and a.name < b.name))
        end)
    end

    return ret, retName
end

function RTC.PopupMinimap(frame)
    if not RTC.PopupDynamic:Wipe(frame:GetName()) then return end
    RTC.PopupDynamic:AddItem(L["BtnRoll"], false, RTC.BtnRoll)
    if RTC.DB.MainAndOffSpecMode then
        RTC.PopupDynamic:AddItem(L["BtnOffSpec"], false, RTC.BtnOffSpec)
    end
    RTC.PopupDynamic:AddItem(L["BtnPass"], false, RTC.BtnPass)
    RTC.PopupDynamic:AddItem("", true)
    RTC.PopupDynamic:AddItem(L["BtnRaidRoll"], false, RTC.RaidRoll)
    RTC.PopupDynamic:AddItem("", true)

    RTC.PopupDynamic:AddItem(L["BtnOpen"], false, RTC.ShowWindow, 1)
    if RTC.DB.LootTracker.Enable then
        RTC.PopupDynamic:AddItem(L["BtnOpenLoot"], false, RTC.ShowWindow, 2)
        RTC.PopupDynamic:AddItem(L["BtnCSVExport"], false, RTC.ShowWindow, 3)
    end
    RTC.PopupDynamic:AddItem(L["BtnLootRolls"], false, RTC.LootHistoryShow)
    RTC.PopupDynamic:AddItem("", true)
    RTC.PopupDynamic:AddItem(L["BtnConfig"], false, RTC.Options.Open)
    RTC.PopupDynamic:AddItem(L["PanelAbout"], false, RTC.Options.Open, 4)

    RTC.PopupDynamic:AddItem("", true)

    RTC.PopupDynamic:AddItem(L["CboxLTEnable"], false, RTC.DB.LootTracker,
                             "Enable")

    RTC.PopupDynamic:AddItem("", true)
    RTC.PopupDynamic:AddItem(L["BtnCancel"], false)

    RTC.PopupDynamic:Show(frame, 0, 0)
end

function RTC.GetAutoChannel()
    -- Return an appropriate channel in order of preference: /raid, /p, /s
    local channel
    if IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    else
        channel = "SAY"
    end
    return channel
end

function RTC.AddChat(msg)
    if msg ~= nil and msg ~= "" then
        if (IsInGroup() or IsInRaid()) and not InChatLockdown() then
            SendChatMessage(msg, RTC.GetAutoChannel())
        else
            DEFAULT_CHAT_FRAME:AddMessage(msg, RTC.DB.ColorChat.r,
                                          RTC.DB.ColorChat.g,
                                          RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
        end
    end
end

function RTC.AllowInInstance()
    local _, instanceType = IsInInstance()
    if instanceType == "arena" then
        instanceType = "pvp"
    elseif instanceType == "scenario" then
        instanceType = "party"
    end
    return RTC.DB["NotfiyIn" .. instanceType]
end

-- LootHistory (Blizzard group loot roll window)
local function MyLootHistoryFrame_FullUpdate(self)
    local numItems = C_LootHistory.GetNumItems()
    for i = 1, numItems do
        if self.itemFrames[i] and self.itemFrames[i].rollID and
            RTC.LootHistoryCleardRollID[self.itemFrames[i].rollID] then
            self.itemFrames[i]:Hide()
        end
    end
end

function RTC.LootHistoryClear()
    if ModernLootHistory() then
        -- the modern loot history is per encounter and is managed by the client
        DEFAULT_CHAT_FRAME:AddMessage(RTC.MSGPREFIX .. L["MsgLootRollsNoClear"],
                                      RTC.DB.ColorChat.r, RTC.DB.ColorChat.g,
                                      RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
        return
    end

    if RTC.LootHistroyFrameHooked == nil then
        RTC.LootHistroyFrameHooked = true
        hooksecurefunc("LootHistoryFrame_FullUpdate", MyLootHistoryFrame_FullUpdate)
    end

    local numItems = C_LootHistory.GetNumItems()

    for i = 1, numItems do
        if LootHistoryFrame.itemFrames[i] then
            RTC.LootHistoryCleardRollID[LootHistoryFrame.itemFrames[i].rollID] =
                true
        end
    end

    LootHistoryFrame_FullUpdate(LootHistoryFrame)
end

function RTC.LootHistoryShow(rollID)
    if ModernLootHistory() then
        if rollID == nil then
            ToggleLootHistoryFrame()
        elseif not GroupLootHistoryFrame:IsShown() then
            GroupLootHistoryFrame:Show()
        end
        return
    end

    if not LootHistoryFrame:IsShown() or rollID == nil then
        ToggleLootHistoryFrame()
    end
    if rollID then
        LootHistoryFrame.expandedRolls[rollID] = true
        LootHistoryFrame_FullUpdate(LootHistoryFrame)
    end
end

function RTC.LootHistoryHide()
    RTC.LootHistoryCountHandle = 0
    wipe(RTC.LootHistoryHandle)
    if not ModernLootHistory() then
        LootHistoryFrame_CollapseAll(LootHistoryFrame)
    end
end

function RTC.LootHistoryClose()
    local frame = GetLootHistoryFrame()
    if not frame then return end
    if not ModernLootHistory() then LootHistoryFrame_CollapseAll(frame) end
    frame:Hide()
end

-- GUI

function RTC.ResetWindow()
    RollTrackerClassicMainWindow:ClearAllPoints()
    RollTrackerClassicMainWindow:SetPoint("Center", UIParent, "Center", 0, 0)
    RollTrackerClassicMainWindow:SetWidth(200)
    RollTrackerClassicMainWindow:SetHeight(200)
    RTC.SaveAnchors()
    RTC.ShowWindow(1)
end

function RTC.ToggleWindow(id)
    if RollTrackerClassicMainWindow:IsVisible() then
        RTC.HideWindow()
    else
        RTC.ShowWindow(id)
    end
end

function RTC.MenuButtonClick(self, button)
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            RTC.LootHistoryShow()
        else
            RTC.ToggleWindow()
        end

    else
        if self.isMinimapButton then
            RTC.PopupMinimap(self.button)
        else
            RTC.PopupMinimap(self)
        end
    end
end

function RTC.MenuToolTip(self)
    self:AddLine(RTC.Title)
    self:AddLine(L["MsgTooltip"])
end

function RTC.ResizeButtons()
    local w = RollTrackerClassicFrameHelperButton:GetWidth()
    if RTC.DB.MainAndOffSpecMode then
        RollTrackerClassicFrameRollButton:SetWidth(w / 3)
        RollTrackerClassicFramePassButton:SetWidth(w / 3)
        RollTrackerClassicFrameOffSpecButton:Show()
    else
        RollTrackerClassicFrameRollButton:SetWidth(w / 2)
        RollTrackerClassicFramePassButton:SetWidth(w / 2)
        RollTrackerClassicFrameOffSpecButton:Hide()
    end

    if RTC.DB.ShowNotRolled then
        RollTrackerClassicFrameAnnounceButton:SetWidth(w / 3)
        RollTrackerClassicFrameClearButton:SetWidth(w / 3)
        RollTrackerClassicFrameNotRolledButton:Show()
    else
        RollTrackerClassicFrameAnnounceButton:SetWidth(w / 2)
        RollTrackerClassicFrameClearButton:SetWidth(w / 2)
        RollTrackerClassicFrameNotRolledButton:Hide()
    end
end

function RTC.BtnClose()
    RTC.HideWindow()
    if RTC.DB.ClearOnClose then RTC.ClearRolls() end
end

function RTC.BtnRoll() RandomRoll(1, 100) end

function RTC.BtnOffSpec()
    RandomRoll(1, 99)
end

function RTC.BtnPass()
    if (IsInGroup() or IsInRaid()) and not InChatLockdown() then
        -- the party/raid message comes back as a chat event and is recorded there
        RTC.AddChat(L.pass)
    else
        -- solo, or chat sending locked: nobody would see "pass", record it directly
        RTC.AddRoll(GetUnitName("player"), "0", "1", "100")
    end
end

function RTC.BtnClearRolls()
    if #RTC.rollArray > 0 then
        RTC.ClearRolls()
        if RTC.DB.CloseOnClear then RTC.HideWindow() end
    elseif #RTC.rollUndoArray > 0 then
        RTC.UndoRolls()
    end
end

function RTC.BtnAnnounce()
    RTC.RollAnnounce()
    if RTC.DB.ClearOnAnnounce then RTC.ClearRolls() end
    if RTC.DB.CloseOnAnnounce then RTC.HideWindow() end
end

function RTC.BtnAnnounceDown(button)
    if button == "RightButton" then RTC.StartCountdown() end
end

function RTC.BtnNotRolled() RTC.NotRolled() end

function RTC.BtnSettings()
    RTC.Options.Open()
    --[[DEFAULT_CHAT_FRAME:AddMessage("Temporarily disabled. Please use main options menu.", RTC.DB.ColorChat.r, RTC.DB.ColorChat.g, RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)]]
end

function RTC.BtnLootClear()
    if #RollTrackerForeverZLoot > 0 then
        RTC.ClearLoot()
    elseif #RTC.lootUndo > 0 then
        RTC.UndoLoot()
    end
end

function RTC.SaveAnchors()
    RTC.DB.X = RollTrackerClassicMainWindow:GetLeft()
    RTC.DB.Y = RollTrackerClassicMainWindow:GetTop()
    RTC.DB.Width = RollTrackerClassicMainWindow:GetWidth()
    RTC.DB.Height = RollTrackerClassicMainWindow:GetHeight()
end

function RTC.ShowWindow(id)
    -- workaround for a strange bug
    if RollTrackerClassicMainWindow.Tabs then
        for i = 1, RollTrackerClassicMainWindow.numTabs do
            local child = RollTrackerClassicMainWindow.Tabs[i].content
            child:SetParent(RollTrackerClassicMainWindow)
            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", 8, -30)
            child:SetPoint("BOTTOMRIGHT", -8, 8)
        end
    end

    RollTrackerClassicMainWindow:Show()
    RTC.UpdateRollList()
    RTC.UpdateLootList()
    RTC.Tool.SelectTab(RollTrackerClassicMainWindow, id)
end

function RTC.HideWindow() RollTrackerClassicMainWindow:Hide() end

-- Options Panel
function RTC.OptionsUpdate()
    RTC.LootListInit()
    RTC.CSVListInit()
    RTC.UpdateRollList()
    RTC.UpdateLootList()
    RTC.ResizeButtons()
    RTC.MinimapButton.UpdatePosition()

    local list = RTC.Tool.Split(RTC.DB.LootTracker.WhiteList)
    RTC.whitelist = {}
    for _, value in ipairs(list) do RTC.whitelist[value] = true end

    if RTC.DB.LootTracker.Enable then
        RTC.Tool.TabShow(RollTrackerClassicMainWindow)
    else
        RTC.Tool.SelectTab(RollTrackerClassicMainWindow, 1)
        RTC.Tool.TabHide(RollTrackerClassicMainWindow)
    end
    if RTC.PlaceForeverResizeHandle then RTC.PlaceForeverResizeHandle() end
end

local function RTCO_CheckBox(Var, Init)
    RTC.Options.AddCheckBox(RTC.DB, Var, Init, L["Cbox" .. Var])
end

local function RTCO_CheckBoxLT(Var, Init)
    RTC.Options.AddCheckBox(RTC.DB.LootTracker, Var, Init, L["CboxLT" .. Var])
end

function RTC.OptionsInit()
    RTC.Options.Init(function() -- doOk
        RTC.Options.DoOk()
        RTC.OptionsUpdate()
    end, function() -- doCancel
        RTC.Options.DoCancel()
        RTC.OptionsUpdate()
    end, function() -- doDefault
        RTC.Options.DoDefault()
        RTC.DB.Minimap.position = 50
        RTC.ResetWindow()

        RTC.MinimapButton.UpdatePosition()

        RTC.OptionsUpdate()
    end)

    RTC.Options.SetScale(0.85)
    RTC.Options.AddPanel(RTC.Title, nil, true)
    RTC.Options.AddVersion('|cff00c0ff' .. RTC.Version .. "|r")

    -- RTC.Options.AddCategory( L["HeaderSettings"] )
    -- RTC.Options.Indent()

    RTC.Options.AddCheckBox(RTC.DB.Minimap, "visible", true,
                            L["Cboxshowminimapbutton"])
    RTC.Options.AddCheckBox(RTC.DB.Minimap, "lock", false,
                            L["CboxLockMinimapButton"])
    RTC.Options.AddCheckBox(RTC.DB.Minimap, "lockDistance", false,
                            L["CboxLockMinimapButtonDistance"])
    RTC.Options.AddSpace()
    RTCO_CheckBox("NotfiyInnone", true)
    RTCO_CheckBox("NotfiyInpvp", false)
    RTCO_CheckBox("NotfiyInparty", true)
    RTCO_CheckBox("NotfiyInraid", true)

    RTC.Options.AddSpace()
    RTCO_CheckBox("ClearOnClose", true)
    RTCO_CheckBox("ClearOnAnnounce", true)
    RTCO_CheckBox("CloseOnAnnounce", true)
    RTCO_CheckBox("CloseOnClear", true)
    RTC.Options.AddSpace()
    RTCO_CheckBox("IgnoreDouble", false)
    RTCO_CheckBox("RejectOutBounds", false)
    RTCO_CheckBox("AnnounceIgnoreDouble", true)
    RTCO_CheckBox("AnnounceRejectOutBounds", false)
    RTCO_CheckBox("PromoteRolls", false)
    RTCO_CheckBox("AutoCountdownWithItem", false)
    RTC.Options.AddSpace()
    RTCO_CheckBox("MainAndOffSpecMode", false)
    RTCO_CheckBox("ShowNotRolled", true)
    RTCO_CheckBox("AnnounceLeaderOnly", false)
    RTC.Options.AddSpace()
    RTCO_CheckBox("ClearOnStart", false)
    RTCO_CheckBox("OpenOnStart", false)
    RTC.Options.AddSpace()
    RTCO_CheckBox("ColorName", true)
    RTCO_CheckBox("ShowClassIcon", true)
    RTCO_CheckBox("ShowGuildRank", true)
    RTC.Options.AddSpace()
    RTCO_CheckBox("AutmaticAnnounce", false)
    RTC.Options.AddEditBox(RTC.DB, "AnnounceList", 1, L["EdtAnnounceList"], 50,
                           300, true)
    RTC.Options.AddSpace()
    RTC.Options.AddText(L["MsgStartCD"])
    RTC.Options.AddSpace(0.2)
    RTC.Options.AddEditBox(RTC.DB, "DefaultCD", 5, L["EdtDefaultCD"], 50, 300,
                           true)
    RTC.Options.AddEditBox(RTC.DB, "CDRefresh", 3, L["EdtCDRefresh"], 50, 300,
                           true)

    RTC.Options.AddSpace()
    RTC.Options.AddText(L["BtnLootRolls"], 150)
    RTC.Options.AddSpace(0.2)
    RTCO_CheckBox("AutoLootRolls", true)
    RTCO_CheckBox("AutoCloseLootRolls", true)
    RTC.Options.AddEditBox(RTC.DB, "AutoCloseDelay", 5, L["EdtAutoCloseDelay"],
                           50, 300, true)
    RTC.Options.AddSpace()
    RTC.Options.AddColorButton(RTC.DB, "ColorNormal",
                               {a = 1, r = 1, g = 1, b = 1}, L["BtnColorNormal"], 150)
    RTC.Options.AddColorButton(RTC.DB, "ColorCheat",
                               {a = 1, r = 1, g = .8, b = .8},
                               L["BtnColorCheat"], 150)
    RTC.Options.AddColorButton(RTC.DB, "ColorGuild",
                               {a = 1, r = .2, g = 1, b = .2},
                               L["BtnColorGuild"], 150)
    RTC.Options.AddColorButton(RTC.DB, "ColorInfo",
                               {a = 1, r = .6, g = .6, b = .6},
                               L["BtnColorInfo"], 150)
    RTC.Options.AddColorButton(RTC.DB, "ColorChat",
                               {a = 1, r = 1, g = 1, b = 1}, L["BtnColorChat"], 150)
    RTC.Options.AddColorButton(RTC.DB, "ColorScroll",
                               {a = 1, r = .8, g = .8, b = .8},
                               L["BtnColorScroll"], 150)

    RTC.Options.AddSpace()
    RTCO_CheckBox("OnDebug", false)

    -- loot tracker
    RTC.Options.AddPanel(L["PanelLootTracker"], false, true)

    RTC.Options.AddCategory(L["HeaderSettings"])
    RTC.Options.Indent()
    RTCO_CheckBoxLT("Enable", false)
    RTC.Options.AddSpace()
    RTCO_CheckBoxLT("SmallFont", true)
    RTCO_CheckBoxLT("ShortMessage", false)
    RTCO_CheckBoxLT("ShowIcon", true)
    RTC.Options.AddSpace()
    RTCO_CheckBoxLT("TrackSolo", true)
    RTCO_CheckBoxLT("TrackGroup", true)
    RTCO_CheckBoxLT("TrackSRaid", true)
    RTCO_CheckBoxLT("TrackBRaid", true)
    RTC.Options.AddSpace()
    -- lib:AddEditBox(DB,Var,Init,TXTLeft,width,widthLeft,onlynumbers,tooltip,suggestion)
    RTC.Options.AddEditBox(RTC.DB.LootTracker, "NbLoots", 1000, L["EdtNbLoots"],
                           50, 200, true)

    RTC.Options.AddEditBox(RTC.DB.LootTracker, "WhiteList", "",
                           L["EdtWhiteList"], 400, 200)

    RTC.Options.Indent(-10)

    RTC.Options.AddCategory(L["HeaderRarity"])
    RTC.Options.Indent(10)
    for i = 0, tonumber(RTC.MAXRARITY) do
        RTC.Options.AddCheckBox(RTC.DB.LootTracker.Rarity, i, i >= 2,
                                ITEM_QUALITY_COLORS[i].hex ..
                                    _G["ITEM_QUALITY" .. i .. "_DESC"] .. "|r")
    end
    RTC.Options.Indent(-10)

    RTC.Options.AddCategory(L["HeaderItemType"])
    RTC.Options.Indent()
    RTC.Options.AddText(L["TxtItemType"], 350)
    local NumberOfItemClasses = _G.NUM_LE_ITEM_CLASSS or 19
    for i = 0, NumberOfItemClasses - 1 do
        local txt = GetItemClassInfo(i)
        if txt ~= nil and string.find(txt, "OBSOLETE") == nil then
            RTC.Options.AddCheckBox(RTC.DB.LootTracker.ItemType, i, false, txt)
        end
    end
    RTC.Options.Indent(-10)

    RTC.Options.AddCategory(L["HeaderCSV"])
    RTC.Options.Indent(10)
    RTC.Options.AddText(L["TxtCSVJokersTitle"])
    RTC.Options.AddText(L["TxtCSVJokers"])
    RTC.Options.AddText(L["TxtCSVJokers2"])
    RTC.Options.AddSpace()
    -- lib:AddEditBox(DB,Var,Init,TXTLeft,width,widthLeft,onlynumbers,tooltip,suggestion)
    RTC.Options.AddEditBox(RTC.DB.LootTracker, "CSVexport",
                           '%yy%-%mm%-%dd%;%HH%:%MM%;%name%;%iid%;%icount%', "",
                           600)

    RTC.Options.Indent(-10)

    -- localization
    RTC.Options.SetScale(0.85)
    RTC.Options.AddPanel(L["HeaderCustomLocales"], false, true)
    RTC.Options.AddText(L["MsgLocalRestart"])
    RTC.Options.AddSpace()

    local locales = getmetatable(L).__index
    local t = {}
    for key in pairs(locales) do table.insert(t, key) end
    table.sort(t)
    for _, key in ipairs(t) do
        local col = L[key] ~= locales[key] and "|cffffffff" or "|cffff4040"
        local txt = L[key .. "_org"] ~= "[" .. key .. "_org]" and
                        L[key .. "_org"] or L[key]

        RTC.Options.AddEditBox(RTC.DB.CustomLocales, key, "",
                               col .. "[" .. key .. "]", 450, 200, false,
                               locales[key], txt)
    end

    -- About
    local function SlashText(txt) RTC.Options.AddText(txt) end

    RTC.Options.AddPanel(L["PanelAbout"],false,true)

    RTC.Options.AddCategory(
        "|cFFFF1C1C" .. GetAddOnMetadata(TOCNAME, "Title") .. "|r v" ..
            GetAddOnMetadata(TOCNAME, "Version") .. " by " ..
            GetAddOnMetadata(TOCNAME, "Author"))
    RTC.Options.Indent(10)
    RTC.Options.AddText(GetAddOnMetadata(TOCNAME, "Notes"))
    RTC.Options.Indent(-10)

    RTC.Options.AddCategory(L["HeaderInfo"])
    RTC.Options.Indent(10)
    RTC.Options.AddText(L["AboutInfo"], -20)
    RTC.Options.Indent(-10)

    RTC.Options.AddCategory(L["HeaderUsage"])
    RTC.Options.Indent(10)
    RTC.Options.AddText(L["AboutUsage"], -20)
    RTC.Options.Indent(-10)

    RTC.Options.AddCategory(L["HeaderSlashCommand"])
    RTC.Options.Indent(10)
    RTC.Options.AddText(L["AboutSlashCommand"], -20)
    RTC.Tool.PrintSlashCommand(nil, nil, SlashText)
    RTC.Options.Indent(-10)

    RTC.Options.AddCategory(L["HeaderCredits"])
    RTC.Options.Indent(10)
    RTC.Options.AddText(L["AboutCredits"], -20)
    RTC.Options.Indent(-10)
end

-- notesystem
local function hooked_createTooltip(self)
    if self ~= GameTooltip then return end
    local name, unit = self:GetUnit()
    if not IsReadable(name, unit) then return end
    if (name) and (unit) and UnitIsPlayer(unit) and RTC.Notes[name] then
        self:AddLine(RTC.Notes[name])
        self:Show()
    end
end

local function HookUnitTooltip()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and
        Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,
                                                hooked_createTooltip)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", hooked_createTooltip)
    end
end

local function PopupEditBox(dialog)
    return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
end

local function FocusActiveChatWindow()
    if ChatFrameUtil and ChatFrameUtil.FocusActiveWindow then
        ChatFrameUtil.FocusActiveWindow()
    elseif ChatEdit_FocusActiveWindow then
        ChatEdit_FocusActiveWindow()
    end
end

local EditEntry
function RTC.EditNote(entry)
    StaticPopup_Hide("RollTrackerClassic_AddNote")
    if entry then
        EditEntry = entry
        StaticPopup_Show("RollTrackerClassic_AddNote", entry)
    end
end

function RTC.notes_clear()
    wipe(RTC.Notes)
    DEFAULT_CHAT_FRAME:AddMessage(RTC.MSGPREFIX .. L["MsgNotesCleared"],
                                  RTC.DB.ColorChat.r, RTC.DB.ColorChat.g,
                                  RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
end

function RTC.notes_list()
    local txt = ""
    for name, note in pairs(RTC.Notes) do
        if note and note ~= "" and name then
            txt = name .. " " .. note .. "|n" .. txt
        end
    end
    if txt ~= "" then RTC.Tool.CopyPast(txt) end
end

local function EnterHyperlink(_, link)
    local part = RTC.Tool.Split(link, ":")

    if part[1] == "player" then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
        GameTooltip:ClearLines()

        local guid = UnitGUID(part[2])
        if guid then
            GameTooltip:SetHyperlink("|Hunit:" .. guid .. "|h[" .. part[2] ..
                                         "]|h")
        else
            GameTooltip:AddLine(part[2])
            GameTooltip:AddLine(RTC.Notes[part[2]] or "")
        end

        if RTC.DB.LootTracker.Enable then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.MsgPastLoots)
            local count = 0
            for i = #RollTrackerForeverZLoot, 1, -1 do
                local loot = RollTrackerForeverZLoot[i]
                if loot.name == part[2] then
                    RTC.LootList_AddItem(loot, GameTooltip)
                    count = count + 1
                    if count == 10 then break end
                end
            end
        end
        GameTooltip:Show()
    elseif part[1] == "spell" or part[1] == "unit" or part[1] == "item" or
        part[1] == "enchant" or part[1] == "player" or part[1] == "quest" or
        part[1] == "trade" then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
        GameTooltip:ClearLines()
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end
end

local function LeaveHyperlink() GameTooltip:Hide() end

local function ClickHyperlink(_, link)
    local part = RTC.Tool.Split(link, ":")
    if part[1] == "player" then RTC.EditNote(part[2]) end
end

local function initHyperlink(frame)
    frame:SetHyperlinksEnabled(true);
    frame:SetScript("OnHyperlinkEnter", EnterHyperlink)
    frame:SetScript("OnHyperlinkLeave", LeaveHyperlink)
    frame:SetScript("OnHyperlinkClick", ClickHyperlink)

    if StaticPopupDialogs["RollTrackerClassic_AddNote"] == nil then
        HookUnitTooltip()

        StaticPopupDialogs["RollTrackerClassic_AddNote"] = {
            text = L.MsgAddNote,
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = 1,
            maxLetters = 48,
            countInvisibleLetters = true,
            editBoxWidth = 350,
            OnAccept = function(self)
                RTC.Notes[EditEntry] = PopupEditBox(self):GetText()
            end,
            OnShow = function(self)
                PopupEditBox(self):SetText(RTC.Notes[EditEntry] or "");
                PopupEditBox(self):SetFocus();
            end,
            OnHide = function(self)
                FocusActiveChatWindow();
                PopupEditBox(self):SetText("");
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent();
                RTC.Notes[EditEntry] = PopupEditBox(parent):GetText()
                parent:Hide();
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide();
            end,
            timeout = 0,
            exclusive = 1,
            whileDead = 1,
            hideOnEscape = 1
        }
    end
end

-- Init
function RTC.Init()
    L = RTC.GetLocale()

    RTC.CSV_Transfer_Table = {}

    RTC.rollArray = {}
    RTC.rollNames = {}
    RTC.rollUndoArray = {}
    RTC.rollUndoNames = {}
    RTC.lootUndo = {}
    RTC.lastItem = nil

    RTC.LootHistoryCloseTimer = 0
    RTC.LootHistoryCountHandle = 0
    RTC.LootHistoryHandle = {}
    RTC.LootHistoryCleardRollID = {}

    -- using strings from GlobalStrings.lua
    RTC.PatternRoll = RTC.Tool.CreatePattern(RANDOM_ROLL_RESULT)
    RTC.PatternLoot = RTC.Tool.CreatePattern(LOOT_ITEM, true)
    RTC.PatternLootOwn = RTC.Tool.CreatePattern(LOOT_ITEM_SELF, true)

    -- settings
    if not RollTrackerForeverZDB then RollTrackerForeverZDB = {} end -- fresh DB
    RTC.DB = RollTrackerForeverZDB
    if not RTC.DB.Minimap then RTC.DB.Minimap = {} end
    if not RTC.DB.CustomLocales then RTC.DB.CustomLocales = {} end
    if not RollTrackerForeverZLoot then RollTrackerForeverZLoot = {} end
    if not RTC.DB.LootTracker then RTC.DB.LootTracker = {} end
    if not RTC.DB.LootTracker.Rarity then RTC.DB.LootTracker.Rarity = {} end
    if not RTC.DB.LootTracker.ItemType then RTC.DB.LootTracker.ItemType = {} end

    local Realm = GetRealmName()
    if not RTC.DB.Notes then RTC.DB.Notes = {} end
    if not RTC.DB.Notes[Realm] then RTC.DB.Notes[Realm] = {} end
    RTC.Notes = RTC.DB.Notes[Realm]

    local x, y, w, h = RTC.DB.X, RTC.DB.Y, RTC.DB.Width, RTC.DB.Height
    if not x or not y or not w or not h then
        RTC.SaveAnchors()
    else
        RollTrackerClassicMainWindow:ClearAllPoints()
        RollTrackerClassicMainWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        RollTrackerClassicMainWindow:SetWidth(w)
        RollTrackerClassicMainWindow:SetHeight(h)
    end

    -- Language
    RollTrackerClassicMainWindowTitle:SetText(string.format(
                                                  RTC.TxtEscapePicture,
                                                  RTC.IconDice) .. RTC.Title)

    RollTrackerClassicFrameRollButton:SetText(string.format(
                                                  RTC.TxtEscapePicture,
                                                  RTC.IconDice) .. L["BtnRoll"])
    RollTrackerClassicFrameOffSpecButton:SetText(string.format(
                                                   RTC.TxtEscapePicture,
                                                   RTC.IconGreed) ..
                                                   L["BtnOffSpec"])
    RollTrackerClassicFramePassButton:SetText(string.format(
                                                  RTC.TxtEscapePicture,
                                                  RTC.IconPass) .. L["BtnPass"])

    -- RollTrackerClassicFrameClearButton:SetText(L["BtnClear"])
    RollTrackerClassicFrameAnnounceButton:SetText(L["BtnAnnounce"])
    RollTrackerClassicFrameNotRolledButton:SetText(L["BtnNotRolled"])
    RollTrackerClassicFrameHelperButton:Hide()
    RTC.ResizeButtons()

    RollTrackerForeverZLootFrameClearButton:SetText(L["BtnClear"])

    RollTrackerClassicCSVFrameExportButton:SetText(L["BtnCSVExport"])

    -- slash command
    local function doDBSet(DB, var, value)
        if value == nil then
            DB[var] = not DB[var]
        elseif tContains({"true", "1", "enable"}, value) then
            DB[var] = true
        elseif tContains({"false", "0", "disable"}, value) then
            DB[var] = false
        end
        DEFAULT_CHAT_FRAME:AddMessage(
            RTC.MSGPREFIX .. "Set " .. var .. " to " .. tostring(DB[var]),
            RTC.DB.ColorChat.r, RTC.DB.ColorChat.g, RTC.DB.ColorChat.b,
            RTC.DB.ColorChat.a)
        RTC.OptionsUpdate()
    end

    RTC.Tool.SlashCommand({"/rtc", "/rolltracker", "/rolltrackerclassic"}, {
        {
            "clear", "", {
                {"rolls", L["SlashClearRolls"], RTC.ClearRolls, true},
                {"loot", L["SlashClearLoot"], RTC.ClearLoot, true},
                {"lootrolls", L["SlashClearLootRolls"], RTC.LootHistoryClear},
                {"notes", L["SlashClearNotes"], RTC.notes_clear}
            }
        }, {
            "undo", "", {
                {"rolls", L["SlashUndoRolls"], RTC.UndoRolls, true},
                {"loot", L["SlashUndoLoot"], RTC.UndoLoot, true}
            }
        }, {"announce", "", {{"%", L["SlashAnnounce"], RTC.RollAnnounce}}},
        {"notrolled", L["SlashNotRolled"], RTC.NotRolled},
        {"close", L["SlashClose"], RTC.HideWindow},
        {"reset", L["SlashReset"], RTC.ResetWindow},
        {{"config", "setup", "options"}, L["SlashConfig"], RTC.Options.Open, 1},
        {"about", L["SlashAbout"], RTC.Options.Open, 4},
        {"debug", "", {{"%", "", RTC.AddRoll}}},
        {"notes", L["SlashNotes"], RTC.notes_list},
        {"start", "", {{"%", L["SlashStart"], RTC.StartRoll}}}, {
            {"countdown", "count", "cd"}, "",
            {{"%", L["SlashCountdown"], RTC.StartCountdown}}
        }, {
            "loottracker", "",
            {{"%", L["CboxLTEnable"], doDBSet, RTC.DB.LootTracker, "Enable"}}
        }, {"export", L["BtnCSVExport"], RTC.BtnExport}, {
            "raidroll", "", {
                {"list", L["SlashRaidRollList"], RTC.RaidRollList},
                {"", L["SlashRaidRoll"], RTC.RaidRoll}
            }
        }, {"", L["SlashOpen"], RTC.ShowWindow}
    })

    -- Options
    RTC.OptionsInit()

    -- gui
    RTC.MinimapButton.Init(RTC.DB.Minimap, RTC.IconDice, RTC.MenuButtonClick,
                           RTC.Title .. "\n" .. L["MsgTooltip"])

    RTC.Tool.EnableSize(RollTrackerClassicMainWindow, 8, nil, RTC.SaveAnchors)
    RTC.Tool.EnableMoving(RollTrackerClassicMainWindow, RTC.SaveAnchors)

    RTC.Tool.AddTab(RollTrackerClassicMainWindow, L["TabRoll"],
                    RollTrackerClassicFrame)
    RTC.Tool.AddTab(RollTrackerClassicMainWindow, L["TabLoot"],
                    RollTrackerForeverZLootFrame)
    RTC.Tool.AddTab(RollTrackerClassicMainWindow, L["TabCSV"],
                    RollTrackerClassicCSVFrame)

    RTC.PopupDynamic = RTC.Tool.CreatePopup(RTC.OptionsUpdate)

    RTC.Tool.OnUpdate(RTC.Timers)

    local lootHistoryFrame = GetLootHistoryFrame()
    if lootHistoryFrame then
        hooksecurefunc(lootHistoryFrame, "Hide", RTC.LootHistoryHide)
    end

    initHyperlink(RollTrackerRollText)
    initHyperlink(RollTrackerForeverZLootFrame_MessageFrame)
    RTC.OptionsUpdate()
    -- tabs and resize grips are created here, after the skin was applied
    RTC.LocalizeForeverLayout()
    RTC.LayerForeverSkin()
end

local lastCountDown
function RTC.Timers()
    if RTC.LootHistoryCloseTimer > 0 and RTC.LootHistoryCloseTimer < time() and
        RTC.LootHistoryCountHandle <= 0 then
        if RTC.DB.AutoCloseLootRolls then RTC.LootHistoryClose() end
        RTC.LootHistoryCloseTimer = 0
        RTC.LootHistoryCountHandle = 0
    end

    if RTC.Countdown ~= nil then
        local sec = math.floor(RTC.Countdown - GetTime() + 0.999)
        if sec > 5 then sec = math.floor((sec + 9) / 10) * 10 end

        if sec ~= lastCountDown then
            lastCountDown = sec
            if sec > 0 then
                RTC.AddChat(RTC.MSGPREFIX .. sec)
            else
                RTC.RollAnnounce()
                RTC.lastItem = nil
                if RTC.DB.ClearOnAnnounce then RTC.ClearRolls() end
                if RTC.DB.CloseOnAnnounce then RTC.HideWindow() end
                RTC.Countdown = nil
                lastCountDown = nil
            end
        end
    end
end

function RTC.StartCountdown(x)
    local ti = GetTime() + (x or RTC.DB.DefaultCD)
    if RTC.Countdown == nil or RTC.Countdown < ti then RTC.Countdown = ti end
end

function RTC.StopCountdown() RTC.Countdown = nil end

-- Event handler

local function Event_ADDON_LOADED(arg1)
    if arg1 == TOCNAME then RTC.Init() end
    RTC.Tool.AddDataBrocker(RTC.IconDice, RTC.MenuButtonClick, RTC.MenuToolTip)
end

local function Event_START_LOOT_ROLL(arg1, _, arg3)
    -- START_LOOT_ROLL: rollID, rollTime, lootHandle
    if RTC.DB.AutoLootRolls then RTC.LootHistoryShow(arg1) end
    if arg3 then -- loothandle CAN be nil
        RTC.LootHistoryHandle[arg3] = true
        RTC.LootHistoryCountHandle = RTC.LootHistoryCountHandle + 1
    end
    RTC.LootHistoryCloseTimer = 0
end

local function Event_LOOT_ROLLS_COMPLETE(arg1)
    -- LOOT_ROLLS_COMPLETE: lootHandle
    if RTC.LootHistoryHandle[arg1] == true then
        RTC.LootHistoryHandle[arg1] = nil
        RTC.LootHistoryCountHandle = RTC.LootHistoryCountHandle - 1
        if RTC.LootHistoryCountHandle <= 0 then
            RTC.LootHistoryCountHandle = 0
            wipe(RTC.LootHistoryHandle)
            RTC.LootHistoryCloseTimer = time() + (RTC.DB.AutoCloseDelay or 5)
        end
    end
end

local function Event_CHAT_MSG_LOOT(arg1)
    if not IsReadable(arg1) then return end
    -- %s receives loot : %s|Hitem :%d :%d :%d :%d|h[%s]|h%s.
    local name, item = string.match(arg1, RTC.PatternLoot)
    if not name or not item then
        name = GetUnitName("player")
        item = string.match(arg1, RTC.PatternLootOwn)
    end

    if name ~= nil and item ~= nil then RTC.AddLoot(name, item) end
end

local function Event_CHAT_MSG_SYSTEM(arg1)
    if not IsReadable(arg1) then return end
    for name, roll, low, high in string.gmatch(arg1, RTC.PatternRoll) do
        -- print(".."..name.." "..roll.." "..low.." "..high)
        RTC.AddRoll(name, roll, low, high)
    end
end

local function Event_Generic_CHAT_MSG(msg, name)
    if not IsReadable(msg, name) then return end
    local dopass = false
    if RTC.PassTags[msg] then dopass = true end
    if dopass then
        name = RTC.Tool.Split(name, "-")[1]
        RTC.AddRoll(name, "0", "1", "100")
    end

    if string.sub(msg, 1, string.len(RTC.MSGPREFIX_START)) ==
        RTC.MSGPREFIX_START then
        if RTC.DB.ClearOnStart then RTC.ClearRolls() end
        if RTC.DB.OpenOnStart then RTC.ShowWindow(1) end
    end
end

local BACKDROP_TUTORIAL_16_16 = BACKDROP_TUTORIAL_16_16 or {
    bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileEdge = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {left = 3, right = 5, top = 3, bottom = 5}
}
function RTC.OnLoad(self)
    -- print("rtc-onload")
    if RTC.FOREVER and RTC.ApplyForeverSkin then
        RTC.ApplyForeverSkin(self)
    else
        if Mixin and BackdropTemplateMixin then
            Mixin(self, BackdropTemplateMixin)
        end
        self:SetBackdrop(BACKDROP_TUTORIAL_16_16)
    end
    if self.SetResizeBounds then
        self:SetResizeBounds(194, 170)
    else
        self:SetMinResize(194, 170)
    end

    RTC.Tool.RegisterEvent("ADDON_LOADED", Event_ADDON_LOADED)
    RTC.Tool.RegisterEvent("START_LOOT_ROLL", Event_START_LOOT_ROLL)
    RTC.Tool.RegisterEvent("LOOT_ROLLS_COMPLETE", Event_LOOT_ROLLS_COMPLETE)

    RTC.Tool.RegisterEvent("CHAT_MSG_LOOT", Event_CHAT_MSG_LOOT)
    RTC.Tool.RegisterEvent("CHAT_MSG_SYSTEM", Event_CHAT_MSG_SYSTEM)

    RTC.Tool.RegisterEvent("CHAT_MSG_PARTY", Event_Generic_CHAT_MSG)
    RTC.Tool.RegisterEvent("CHAT_MSG_PARTY_LEADER", Event_Generic_CHAT_MSG)
    RTC.Tool.RegisterEvent("CHAT_MSG_RAID", Event_Generic_CHAT_MSG)
    RTC.Tool.RegisterEvent("CHAT_MSG_RAID_LEADER", Event_Generic_CHAT_MSG)
end

-- Roll

function RTC.RaidRoll()
    RTC.IsRaidRoll = RTC.GetPlayerList(true)
    RandomRoll(1, #RTC.IsRaidRoll)
end

function RTC.RaidRollList()
    local party = RTC.GetPlayerList(true)
    for i, entry in ipairs(party) do RTC.AddChat(i .. ". " .. entry.name) end
end

function RTC.AddRoll(name, roll, low, high)
    local ok = false
    if name == "*" then
        for i = 1, 5 do
            RTC.AddRoll("rndmainSpec" .. i, tostring(random(1, 100)), "1", "100")
            RTC.AddRoll("rndoffSpec" .. i, tostring(random(1, 99)), "1", "99")
        end
        return
    end

    if RTC.IsRaidRoll and low == "1" and tonumber(high) == #RTC.IsRaidRoll and
        name == GetUnitName("player") then
        roll = tonumber(roll)
        RTC.AddChat(RTC.MSGPREFIX ..
                        string.format(L["MsgRaidRoll"],
                                      RTC.IsRaidRoll[roll].name, roll))
        RTC.IsRaidRoll = nil
        return
    end

    if not RTC.AllowInInstance() then return end

    -- check for rerolls. >1 if rolled before
    if RTC.DB.MainAndOffSpecMode then
        if (RTC.DB.IgnoreDouble == false or RTC.rollNames[name] == nil or
            RTC.rollNames[name] == 0) and
            ((low == "1" and high == "99") or (low == "1" and high == "100")) then
            ok = true
        end
    else
        if (RTC.DB.IgnoreDouble == false or RTC.rollNames[name] == nil or
            RTC.rollNames[name] == 0) and
            (RTC.DB.RejectOutBounds == false or (low == "1" and high == "100")) then
            ok = true
        end
    end

    if ok then

        if RTC.DB.PromoteRolls and tonumber(roll) == 69 then roll = "101" end

        RTC.rollNames[name] = RTC.rollNames[name] and RTC.rollNames[name] + 1 or
                                  1
        table.insert(RTC.rollArray, {
            Name = name,
            Roll = tonumber(roll),
            Low = tonumber(low),
            High = tonumber(high),
            Count = RTC.rollNames[name]
        })

        RTC.ShowWindow(1)

        if RTC.allRolled and RTC.DB.AutmaticAnnounce then
            RTC.BtnAnnounce()
        elseif RTC.Countdown then
            RTC.StartCountdown(RTC.DB.CDRefresh)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format(RTC.MSGPREFIX ..
                                                        L["MsgCheat"], name,
                                                    roll, low, high),
                                      RTC.DB.ColorChat.r, RTC.DB.ColorChat.g,
                                      RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
    end
end

function RTC.SortRolls(a, b) return a.Roll < b.Roll end

function RTC.SortRollsRev(a, b) return a.Roll > b.Roll end

function RTC.FormatRollText(roll, _, partyName)
    local colorTied = RTC.Tool.RGBtoEscape(RTC.DB.ColorNormal)
    local colorCheat =
        ((roll.Low ~= 1 or roll.High ~= 100) or (roll.Count > 1)) and
            RTC.Tool.RGBtoEscape(RTC.DB.ColorCheat) or colorTied
    local txtRange = (roll.Low ~= 1 or roll.High ~= 100) and
                         format(" (%d-%d)", roll.Low, roll.High) or ""

    local colorName
    local iconClass
    local colorRank = RTC.Tool.RGBtoEscape(RTC.DB.ColorGuild)
    local rank = ""

    if partyName[roll.Name] and partyName[roll.Name].class then
        colorName = "|c" ..
                        RAID_CLASS_COLORS[partyName[roll.Name].class].colorStr
        iconClass = RTC.Tool.IconClass[partyName[roll.Name].class]
    end
    if colorName == nil or RTC.DB.ColorName == false then
        colorName = colorCheat
    end
    if iconClass == nil or RTC.DB.ShowClassIcon == false then iconClass = "" end
    if RTC.DB.ColorName == false then colorRank = colorCheat end

    if RTC.DB.ShowGuildRank and partyName[roll.Name] and
        partyName[roll.Name].rank then
        rank = " " .. partyName[roll.Name].rank
    end

    local txtCount = roll.Count > 1 and format(" [%d]", roll.Count) or ""

    return "|Hplayer:" .. roll.Name .. "|h" .. colorTied ..
               string.format("%3d", roll.Roll) .. ": " .. iconClass .. colorName ..
               roll.Name .. colorRank .. rank .. "|r " .. colorCheat .. txtRange ..
               "|r " .. colorCheat .. txtCount .. "|h\n"
end

function RTC.UpdateRollList()
    local rollText = ""

    local party, partyName = RTC.GetPlayerList()

    table.sort(RTC.rollArray, RTC.SortRolls)

    -- format and print rolls, check for ties
    if RTC.DB.MainAndOffSpecMode then
        local rtxt = ""
        for _, roll in pairs(RTC.rollArray) do
            if roll.Roll > 0 and roll.High == 100 then
                rtxt = RTC.FormatRollText(roll, party, partyName) .. rtxt
            end
        end
        rollText = RTC.Tool.RGBtoEscape(RTC.DB.ColorInfo) .. L["TxTMainSpec"] .. "\n" .. rtxt
        rtxt = ""
        for _, roll in pairs(RTC.rollArray) do
            if roll.Roll == 0 or roll.High == 99 then
                rtxt = RTC.FormatRollText(roll, party, partyName) .. rtxt
            end
        end
        rollText = rollText .. "\n" .. RTC.Tool.RGBtoEscape(RTC.DB.ColorInfo) .. L["TxTOffSpec"] .. "\n" .. rtxt
    else
        for _, roll in pairs(RTC.rollArray) do
            rollText = RTC.FormatRollText(roll, party, partyName) .. rollText
        end
    end

    if IsInGroup() then
        rollText = rollText .. RTC.Tool.RGBtoEscape(RTC.DB.ColorInfo) ..
                       L["TxtLine"] .. "\n"
        local gtxt = RTC.Tool.RGBtoEscape(RTC.DB.ColorInfo)
        local missClasses = {}
        RTC.allRolled = true
        for _, p in ipairs(party) do
            if RTC.rollNames[p.name] == nil or RTC.rollNames[p.name] == 0 then
                local iconClass = RTC.Tool.IconClass[partyName[p.name].class]
                local rank = ""
                if iconClass == nil or RTC.DB.ShowClassIcon == false then
                    iconClass = ""
                else
                    missClasses[partyName[p.name].class] =
                        missClasses[partyName[p.name].class] and
                            missClasses[partyName[p.name].class] + 1 or 1
                end
                if RTC.DB.ShowGuildRank and partyName[p.name] and
                    partyName[p.name].rank then
                    rank = " " .. partyName[p.name].rank
                end
                gtxt = gtxt .. "|Hplayer:" .. p.name .. "|h" .. iconClass ..
                           p.name .. rank .. "|h\n"
                RTC.allRolled = false
            end
        end
        local ctxt = ""
        if RTC.CLASSIC_ERA then
            local isHorde = (UnitFactionGroup("player")) == "Horde"
            for _, class in pairs(RTC.Tool.Classes) do
                -- for class,count in pairs(missClasses) do
                if not (isHorde and class == "PALADIN") and
                    not (not isHorde and class == "SHAMAN") then
                    ctxt = ctxt .. RTC.Tool.IconClass[class] ..
                               (missClasses[class] or 0) .. " "
                end
            end
            if ctxt ~= "" then
                ctxt = ctxt .. "\n" .. L["TxtLine"] .. "\n"
            end
        end

        rollText = rollText .. ctxt .. gtxt
    end

    RollTrackerRollText:SetText(rollText)
    RollTrackerClassicFrameStatusText:SetText(
        string.format(L["MsgNbRolls"], #RTC.rollArray))

    if #RTC.rollArray == 0 and #RTC.rollUndoArray > 0 then
        RollTrackerClassicFrameClearButton:SetText(L["BtnUndo"])
    else
        RollTrackerClassicFrameClearButton:SetText(L["BtnClear"])
    end

    if RTC.ForeverRollList then RTC.UpdateForeverRollList() end
end

function RTC.ClearRolls(doMsg)
    if #RTC.rollArray > 0 then
        if doMsg then
            DEFAULT_CHAT_FRAME:AddMessage(RTC.MSGPREFIX .. L["MsgRollCleared"],
                                          RTC.DB.ColorChat.r,
                                          RTC.DB.ColorChat.g,
                                          RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
        end

        RTC.rollUndoArray = RTC.rollArray
        RTC.rollUndoNames = RTC.rollNames
        RTC.rollArray = {}
        RTC.rollNames = {}
    end
    RTC.UpdateRollList()
end

function RTC.UndoRolls(doMsg)
    if #RTC.rollUndoArray > 0 then
        if doMsg then
            DEFAULT_CHAT_FRAME:AddMessage(RTC.MSGPREFIX .. L["MsgUndoRoll"],
                                          RTC.DB.ColorChat.r,
                                          RTC.DB.ColorChat.g,
                                          RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
        end
        RTC.rollArray = RTC.rollUndoArray
        RTC.rollNames = RTC.rollUndoNames
        RTC.rollUndoArray = {}
        RTC.rollUndoNames = {}
        RTC.UpdateRollList()
    end
end

function RTC.NotRolled()
    if IsInGroup() or IsInRaid() then
        local party = RTC.GetPlayerList()
        local names = ""
        for _, p in ipairs(party) do
            if RTC.rollNames[p.name] == nil or RTC.rollNames[p.name] == 0 then
                names = names .. ", " .. p.name
            end
        end
        names = string.sub(names, 3)

        if names ~= "" then
            RTC.AddChat(RTC.MSGPREFIX ..
                            string.format(L["MsgNotRolled"], L["pass"]))
            RTC.AddChat(names)
        end
    end
end

function RTC.StartRoll(...)
    local msg
    local item = RTC.Tool.Combine({...})
    RTC.ShowWindow(1)
    RTC.ClearRolls()
    if RTC.DB.MainAndOffSpecMode then
        msg = L["MsgStartMainAndOffSpecMode"]
    else
        msg = L["MsgStart"]
    end
    RTC.AddChat(RTC.MSGPREFIX_START .. string.format(msg, L["pass"]))
    if item and item ~= "" and item ~= " " then
        RTC.AddChat(RTC.MSGPREFIX .. string.format(L["MsgNextItem"], item))

        if RTC.DB.AutoCountdownWithItem then
            RTC.lastItem = item
            RTC.StartCountdown()
        end
    end
    RTC.AddChat(L["MsgBar"])
end

function RTC.RollAnnounce(numbers)
    local winNum = 0
    local winName = ""
    local max = -1
    local addPrefix = ""
    local msg = ""
    local list = {}
    numbers = (tonumber(numbers) or RTC.DB.AnnounceList or 1)
    if numbers == 1 then numbers = 0 end

    table.sort(RTC.rollArray, RTC.SortRollsRev)

    if RTC.DB.MainAndOffSpecMode then -- MS/OS roll
        for _, roll in pairs(RTC.rollArray) do
            if (RTC.DB.AnnounceIgnoreDouble == false or roll.Count == 1) and
                (roll.Roll > 0 and roll.Low == 1 and roll.High == 100) then
                if roll.Roll == max then
                    winNum = winNum + 1
                    winName = winName .. ", " .. roll.Name
                elseif roll.Roll > max then
                    max = roll.Roll
                    winNum = 1
                    winName = roll.Name
                end
                if numbers > 0 then
                    numbers = numbers - 1
                    tinsert(list, roll.Roll .. " " .. roll.Name .. " (" .. roll.Low .. "-" .. roll.High .. ")")
                end
            end
        end

        if winNum == 0 then
            for _, roll in pairs(RTC.rollArray) do
                if (RTC.DB.AnnounceIgnoreDouble == false or roll.Count == 1) and
                    (roll.Roll == 0 or (roll.Low == 1 and roll.High == 99)) then

                    if roll.Roll == max then
                        winNum = winNum + 1
                        winName = winName .. ", " .. roll.Name
                    elseif roll.Roll > max then
                        max = roll.Roll
                        winNum = 1
                        winName = roll.Name
                    end
                    if numbers > 0 then
                        numbers = numbers - 1
                        tinsert(list, roll.Roll .. " " .. roll.Name .. " (" .. roll.Low .. "-" .. roll.High .. ")")
                    end
                end
            end
            addPrefix = L["TxTOffSpec"] .. "! "
        else
            addPrefix = L["TxTMainSpec"] .. "! "
        end
    else -- regular roll
        for _, roll in pairs(RTC.rollArray) do

            if (RTC.DB.AnnounceIgnoreDouble == false or roll.Count == 1) and
                (RTC.DB.AnnounceRejectOutBounds == false or
                    (roll.Low == 1 and roll.High == 100)) then

                if roll.Roll == max and roll.Roll ~= 0 then
                    winNum = winNum + 1
                    winName = winName .. ", " .. roll.Name
                elseif roll.Roll > max and roll.Roll ~= 0 then
                    max = roll.Roll
                    winNum = 1
                    winName = roll.Name
                end
                if numbers > 0 then
                    numbers = numbers - 1
                    tinsert(list, roll.Roll .. " " .. roll.Name .. " (" ..
                                roll.Low .. "-" .. roll.High .. ")")
                end
            end
        end
    end

    if winNum == 1 and RTC.lastItem == nil then
        msg = RTC.MSGPREFIX .. addPrefix ..
                  string.format(L["MsgAnnounce"], winName, max)
    elseif winNum == 1 and RTC.lastItem ~= nil then
        msg = RTC.MSGPREFIX .. addPrefix ..
                  string.format(L["MsgAnnounceItem"], winName, RTC.lastItem, max)
    elseif winNum > 1 and RTC.lastItem == nil then
        msg = RTC.MSGPREFIX .. addPrefix ..
                  string.format(L["MsgAnnounceTie"], winName, max)
    elseif winNum > 1 and RTC.lastItem ~= nil then
        msg = RTC.MSGPREFIX .. addPrefix ..
                  string.format(L["MsgAnnounceTieItem"], winName, RTC.lastItem,
                                max)
    elseif RTC.Countdown then
        msg = RTC.MSGPREFIX .. L["MsgForcedAnnounce"]
    end

    RTC.AddChat(msg)
    for _, out in ipairs(list) do RTC.AddChat(out) end

    RTC.StopCountdown()
end

-- Loot

function RTC.AddLoot(name, lootitem)
    if name == nil or lootitem == nil or not RTC.DB.LootTracker.Enable then
        return
    end

    local ok = false
    if IsInRaid() then
        local count = GetNumGroupMembers()
        if RTC.DB.LootTracker.TrackSRaid and count <= 10 then
            ok = true
        elseif RTC.DB.LootTracker.TrackBRaid and count >= 11 then
            ok = true
        end
    elseif IsInGroup() then
        if RTC.DB.LootTracker.TrackGroup then ok = true end
    elseif RTC.DB.LootTracker.TrackSolo then
        ok = true
    end

    if not ok then return end

    local _, PartyNames = RTC.GetPlayerList()
    local t = time()
    local class
    if PartyNames[name] then class = PartyNames[name].class end

    local loot = {["name"] = name, ["class"] = class, ["timestamp"] = t}
    -- RTC.DB.DEBUGHELP_ITEM=lootitem

    local itemString = string.match(lootitem, "|H(.+)%[")
    if not itemString then return end

    loot.itemName, loot.itemLink, loot.itemRarity, loot.itemLevel, _, _, _, _, _, loot.itemIcon, loot.itemSellPrice, loot.itemType =
        GetItemInfo(itemString)

    if loot.itemLink == nil then
        -- item not in the client cache yet: retry once it has been loaded
        if not RTC._pendingLoot then RTC._pendingLoot = {} end
        local key = name .. "#" .. lootitem
        local itemID = tonumber(string.match(itemString, "item:(%d+)"))
        if itemID and Item and Item.CreateFromItemID and not RTC._pendingLoot[key] then
            RTC._pendingLoot[key] = true
            Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
                RTC._pendingLoot[key] = nil
                RTC.AddLoot(name, lootitem)
            end)
        end
        return
    end

    loot.ItemCount = tonumber(string.match(lootitem, "|rx(%d+)") or 1)

    if RTC.DB.LootTracker.Rarity[loot.itemRarity] or
        RTC.DB.LootTracker.ItemType[loot.itemType] or
        RTC.whitelist[string.match(loot.itemLink, "item:(.-):") or 0] then

        while #RollTrackerForeverZLoot >= RTC.DB.LootTracker.NbLoots do
            tremove(RollTrackerForeverZLoot, 1)
        end

        tinsert(RollTrackerForeverZLoot, loot)
        RTC.CSVList_AddItem(loot)
        RTC.LootList_AddItem(loot)
        RTC.UpdateLootList()
    end
end

function RTC.ClearLoot(doMsg)
    if #RollTrackerForeverZLoot > 0 then
        if doMsg then
            DEFAULT_CHAT_FRAME:AddMessage(RTC.MSGPREFIX .. L["MsgLootCleared"],
                                          RTC.DB.ColorChat.r,
                                          RTC.DB.ColorChat.g,
                                          RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
        end
        RTC.lootUndo = RollTrackerForeverZLoot
        RollTrackerForeverZLoot = {}
        RTC.OptionsUpdate()
    end
end

function RTC.UndoLoot(doMsg)
    if #RTC.lootUndo > 0 then
        if doMsg then
            DEFAULT_CHAT_FRAME:AddMessage(RTC.MSGPREFIX .. L["MsgUndoLoot"],
                                          RTC.DB.ColorChat.r,
                                          RTC.DB.ColorChat.g,
                                          RTC.DB.ColorChat.b, RTC.DB.ColorChat.a)
        end
        RollTrackerForeverZLoot = RTC.lootUndo
        RTC.lootUndo = {}
        RTC.OptionsUpdate()
    end
end

function RTC.LootList_AddItem(loot, frame)
    local colorName
    local iconClass
    local icon
    if not loot.itemIcon or not RTC.DB.LootTracker.ShowIcon then
        icon = ""
    else
        icon = string.format(RTC.TxtEscapeIcon, loot.itemIcon)
    end

    if loot.class then
        colorName = "|c" .. RAID_CLASS_COLORS[loot.class].colorStr
        iconClass = RTC.Tool.IconClass[loot.class]
    end
    if colorName == nil or RTC.DB.ColorName == false then colorName = "" end
    if iconClass == nil or RTC.DB.ShowClassIcon == false then iconClass = "" end

    local stack
    if loot.ItemCount ~= nil and loot.ItemCount > 1 then
        stack = "x" .. loot.ItemCount
    else
        stack = ""
    end

    local Text

    if frame == nil then
        local name =
            "|Hplayer:" .. loot.name .. "|h" .. iconClass .. colorName ..
                loot.name .. "|r|h"

        if RTC.DB.LootTracker.ShortMessage then
            Text = name .. " " .. icon .. loot.itemLink .. stack
        else
            Text = string.format(L["MsgLootLine"],
                                 date("%y-%m-%d %H:%M", loot.timestamp), name,
                                 icon .. loot.itemLink .. stack)
        end
        RollTrackerForeverZLootFrame_MessageFrame:AddMessage(Text, RTC.DB
                                                                 .ColorScroll.r,
                                                             RTC.DB.ColorScroll
                                                                 .g, RTC.DB
                                                                 .ColorScroll.b,
                                                             RTC.DB.ColorScroll
                                                                 .a)
    else
        Text = date("%y-%m-%d %H:%M", loot.timestamp) .. " " .. icon ..
                   loot.itemLink .. stack
        frame:AddLine(Text, RTC.DB.ColorScroll.r, RTC.DB.ColorScroll.g,
                      RTC.DB.ColorScroll.b)
    end
end

function RTC.LootListInit()

    RollTrackerForeverZLootFrame_MessageFrame:SetFading(false);
    if RTC.DB.LootTracker.SmallFont then
        RollTrackerForeverZLootFrame_MessageFrame:SetFontObject(
            GameFontNormalSmall);
    else
        RollTrackerForeverZLootFrame_MessageFrame:SetFontObject(GameFontNormal);
    end
    RollTrackerForeverZLootFrame_MessageFrame:SetJustifyH("LEFT");
    RollTrackerForeverZLootFrame_MessageFrame:SetHyperlinksEnabled(true);
    RollTrackerForeverZLootFrame_MessageFrame:SetTextCopyable(true);
    RollTrackerForeverZLootFrame_MessageFrame:Clear()
    RollTrackerForeverZLootFrame_MessageFrame:SetMaxLines(RTC.DB.LootTracker
                                                              .NbLoots)

    if RTC.DB.LootTracker.Enable then
        for _, loot in ipairs(RollTrackerForeverZLoot) do
            RTC.LootList_AddItem(loot)
        end
    else
        RollTrackerForeverZLootFrame_MessageFrame:AddMessage(
            L["MsgLTnotenabled"], RTC.DB.ColorScroll.r, RTC.DB.ColorScroll.g,
            RTC.DB.ColorScroll.b, RTC.DB.ColorScroll.a)
    end
end

function RTC.UpdateLootList()

    if RTC.DB.LootTracker.Enable then
        RollTrackerForeverZLootFrameStatusText:SetText(string.format(
                                                           L["MsgNbLoots"],
                                                           #RollTrackerForeverZLoot))
    else
        RollTrackerForeverZLootFrameStatusText:SetText("")
    end

    if #RollTrackerForeverZLoot == 0 and #RTC.lootUndo > 0 then
        RollTrackerForeverZLootFrameClearButton:SetText(L["BtnUndo"])
    else
        RollTrackerForeverZLootFrameClearButton:SetText(L["BtnClear"])
    end
end

function RTC.ScrollLootList(self, delta)
    self:SetScrollOffset(self:GetScrollOffset() + delta * 5);
    self:ResetAllFadeTimes()
end

function RTC.ScrollCSVList(self, delta)
    self:SetScrollOffset(self:GetScrollOffset() + delta * 5);
    self:ResetAllFadeTimes()
end

function RTC.CSVList_AddItem(loot, hide)

    RTC.CSV_Transfer_Table["%%"] = "%"
    RTC.CSV_Transfer_Table["%name%"] = loot.name
    RTC.CSV_Transfer_Table["%class%"] = loot.class
    RTC.CSV_Transfer_Table["%timestamp%"] = loot.timestamp
    RTC.CSV_Transfer_Table["%dd%"] = date("%d", loot.timestamp)
    RTC.CSV_Transfer_Table["%mm%"] = date("%m", loot.timestamp)
    RTC.CSV_Transfer_Table["%yy%"] = date("%y", loot.timestamp)
    RTC.CSV_Transfer_Table["%HH%"] = date("%H", loot.timestamp)
    RTC.CSV_Transfer_Table["%MM%"] = date("%M", loot.timestamp)
    RTC.CSV_Transfer_Table["%SS%"] = date("%S", loot.timestamp)
    RTC.CSV_Transfer_Table["%iname%"] = loot.itemName
    RTC.CSV_Transfer_Table["%irarity%"] = loot.itemRarity
    RTC.CSV_Transfer_Table["%iraritytxt%"] =
        _G["ITEM_QUALITY" .. (loot.itemRarity or "") .. "_DESC"] or ""
    RTC.CSV_Transfer_Table["%ilevel%"] = loot.itemLevel
    RTC.CSV_Transfer_Table["%iid%"] = string.match(loot.itemLink, "item:(.-):")
    RTC.CSV_Transfer_Table["%iprice%"] = loot.itemSellPrice
    RTC.CSV_Transfer_Table["%icount%"] = loot.ItemCount or 1
    RTC.CSV_Transfer_Table["%itype%"] = loot.itemType or 99
    RTC.CSV_Transfer_Table["%itypetxt%"] =
        (loot.itemType and GetItemClassInfo(loot.itemType)) or ""

    local text = string.gsub(RTC.DB.LootTracker.CSVexport, "%%%w-%%",
                             RTC.CSV_Transfer_Table)

    if hide then
        return text
    else
        RollTrackerClassicCSVFrame_MessageFrame:AddMessage(text, RTC.DB
                                                               .ColorScroll.r,
                                                           RTC.DB.ColorScroll.g,
                                                           RTC.DB.ColorScroll.b,
                                                           RTC.DB.ColorScroll.a)
    end
end

function RTC.CSVListInit()

    RollTrackerClassicCSVFrame_MessageFrame:SetFading(false);
    RollTrackerClassicCSVFrame_MessageFrame:SetFontObject(GameFontNormalSmall);
    RollTrackerClassicCSVFrame_MessageFrame:SetJustifyH("LEFT");
    RollTrackerClassicCSVFrame_MessageFrame:SetHyperlinksEnabled(true);
    RollTrackerClassicCSVFrame_MessageFrame:SetTextCopyable(true);
    RollTrackerClassicCSVFrame_MessageFrame:Clear()
    RollTrackerClassicCSVFrame_MessageFrame:SetMaxLines(RTC.DB.LootTracker
                                                            .NbLoots)

    for _, loot in ipairs(RollTrackerForeverZLoot) do
        RTC.CSVList_AddItem(loot)
    end
end

function RTC.BtnExport()
    local Text = ""
    for _, loot in ipairs(RollTrackerForeverZLoot) do
        Text = Text .. RTC.CSVList_AddItem(loot, true) .. "\n"
    end
    RTC.Tool.CopyPast(Text)
end

-- WoW: Forever look & feel
-- Re-skins the main window with the modern flat panel used by the game's own
-- windows (e.g. the Loot Rolls window) and moves the header buttons into the title bar.
local function TitleIconButton(parent, texture, tooltip, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    button.isForeverChrome = true
    button:SetNormalTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip())
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function SetLevelTree(frame, level)
    frame:SetFrameLevel(level)
    for _, child in ipairs({frame:GetChildren()}) do
        SetLevelTree(child, level + 1)
    end
end

-- The panel template pins its border (NineSlice, level 500) and title bar (510)
-- to absolute frame levels, which drew them over the window content and hid the
-- close/settings buttons. Put everything on explicit levels relative to the window.
function RTC.LayerForeverSkin()
    local self = RollTrackerClassicMainWindow
    local panel = self.ForeverPanel
    if not panel then return end
    local base = self:GetFrameLevel()

    panel:SetFrameLevel(base)
    if panel.Bg then panel.Bg:SetFrameLevel(base) end
    if panel.NineSlice then panel.NineSlice:SetFrameLevel(base + 1) end

    for _, child in ipairs({self:GetChildren()}) do
        if child ~= panel and not child.isForeverChrome then
            SetLevelTree(child, base + 3)
        end
    end

    if panel.TitleContainer then panel.TitleContainer:SetFrameLevel(base + 8) end
    for _, button in ipairs(self.ForeverChrome) do
        button:SetFrameLevel(base + 10)
    end
end

-- Swap the legacy UIPanelScrollFrameTemplate arrows/slider for the modern thin scroll bar
local hiddenParent
local function ModernizeScrollFrame(scrollFrame)
    if not (ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar) then return end
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame")
        hiddenParent:Hide()
    end
    if scrollFrame.ScrollBar then scrollFrame.ScrollBar:SetParent(hiddenParent) end

    local bar = CreateFrame("EventFrame", nil, scrollFrame, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 8, 0)
    bar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 8, 0)
    bar:SetHideIfUnscrollable(true)
    ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, bar)
    bar:Update()
    scrollFrame.ModernScrollBar = bar
end

-- WoW: Forever roll list, inset panels and action bar
local ROW_HEIGHT, HEADER_HEIGHT = 20, 16
local BUTTON_HEIGHT, GAP = 22, 2

local function ClassRGB(class)
    local c = class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
end

local function RowOnEnter(row)
    local d = row.data
    if d and d.name then EnterHyperlink(nil, "player:" .. d.name) end
end

local function RowOnClick(row)
    local d = row.data
    if d and d.name then RTC.EditNote(d.name) end
end

local function InitRollRow(row, d)
    row.data = d
    local isHeader = d.kind == "header"
    row.Header:SetShown(isHeader)
    row.Roll:SetShown(not isHeader)
    row.Name:SetShown(not isHeader)
    row.Rank:SetShown(not isHeader)
    row.Info:Hide()
    row.Check:Hide()
    row.ClassIcon:Hide()
    row.WinnerBar:SetShown(d.winner == true)
    row.Stripe:SetShown(not isHeader and d.stripe == true and not d.winner)
    row:SetAlpha(1)
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", RowOnClick)

    if isHeader then
        row.Header:SetText(d.text)
        row:EnableMouse(false)
        return
    end
    row:EnableMouse(true)

    -- roll number
    if d.kind == "missing" then
        row.Roll:SetFontObject(GameFontDisableMed2)
        row.Roll:SetText("-")
    elseif d.winner then
        row.Roll:SetFontObject(GameFontNormalMed2)
        row.Roll:SetText(d.roll)
    elseif d.outOfRange then
        row.Roll:SetFontObject(GameFontDisableMed2)
        row.Roll:SetText(d.roll)
    else
        row.Roll:SetFontObject(GameFontHighlightMed2)
        row.Roll:SetText(d.roll)
    end

    -- class icon
    if d.class and RTC.DB.ShowClassIcon and GetClassAtlas then
        row.ClassIcon:SetAtlas(GetClassAtlas(string.lower(d.class)))
        row.ClassIcon:SetDesaturated(d.kind == "missing")
        row.ClassIcon:Show()
    end

    -- name, then the guild rank in a small dim font (truncated first)
    row.Name:SetText(d.name)
    row.Rank:SetText(RTC.DB.ShowGuildRank and d.rank or "")
    row.Rank:SetShown(not isHeader)
    local r, g, b = ClassRGB(d.class)
    if not (r and RTC.DB.ColorName) then r, g, b = 1, 1, 1 end
    if d.kind == "missing" then
        row.Name:SetTextColor(r * 0.6, g * 0.6, b * 0.6)
    else
        row.Name:SetTextColor(r, g, b)
    end

    -- right side: checkmark / tie / range / re-roll count
    if d.winner and not d.tie then
        row.Check:Show()
    elseif d.kind == "roll" then
        local info, fontObject
        if d.tie then
            info, fontObject = L["TxtTie"], GameFontNormalSmall
        elseif d.outOfRange then
            info, fontObject = string.format("%d-%d", d.low, d.high), GameFontRedSmall
        elseif d.count > 1 then
            info, fontObject = string.format("x%d", d.count), GameFontNormalSmall
        end
        if info then
            row.Info:SetFontObject(fontObject)
            row.Info:SetText(info)
            if d.count > 1 and not d.tie and not d.outOfRange then
                row.Info:SetTextColor(1, 0.5, 0.25) -- orange: re-roll
            end
            row.Info:Show()
        end
        if d.outOfRange then row:SetAlpha(0.6) end
    end
    -- the name keeps its full width (up to the free space); the rank gets the rest
    local right = row.Check:IsShown() and row.Check or row.Info
    row.Rank:SetPoint("RIGHT", right, "LEFT", -4, 0)
    local free = (row:GetWidth() or 200) - 53 - (right:IsShown() and (right:GetWidth() + 8) or 4)
    row.Name:SetWidth(math.max(20, math.min(row.Name:GetUnboundedStringWidth() + 2, free)))
end

-- winners exactly like RTC.RollAnnounce picks them
local function MarkWinners(entries, accept)
    local max = -1
    for _, e in ipairs(entries) do
        if accept(e) and e.roll > max then max = e.roll end
    end
    local winners = {}
    if max > 0 then
        for _, e in ipairs(entries) do
            if accept(e) and e.roll == max then
                e.winner = true
                tinsert(winners, e)
            end
        end
    end
    if #winners > 1 then
        for _, e in ipairs(winners) do e.tie = true end
    end
    return #winners > 0
end

local function WaitingPlayers(party)
    local missing = {}
    if IsInGroup() then
        for _, p in ipairs(party) do
            if RTC.rollNames[p.name] == nil or RTC.rollNames[p.name] == 0 then
                tinsert(missing, p)
            end
        end
    end
    return missing
end

function RTC.UpdateForeverRollList()
    local list = RTC.ForeverRollList
    if not list or not RTC.DB then return end
    local party, partyName = RTC.GetPlayerList()

    local function entry(roll)
        local p = partyName[roll.Name]
        return {
            kind = "roll", name = roll.Name, roll = roll.Roll, low = roll.Low,
            high = roll.High, count = roll.Count,
            class = p and p.class, rank = p and p.rank or "",
            outOfRange = (roll.Low ~= 1 or roll.High ~= 100) and
                not (RTC.DB.MainAndOffSpecMode and roll.Low == 1 and roll.High == 99)
        }
    end

    -- rollArray is sorted ascending; show highest first
    local rolls = {}
    for i = #RTC.rollArray, 1, -1 do tinsert(rolls, entry(RTC.rollArray[i])) end

    local data = {}
    local function addSection(title, entries)
        if title then
            tinsert(data, {kind = "header", text = string.format("%s (%d)", title, #entries)})
        end
        for i, e in ipairs(entries) do
            e.stripe = (i % 2 == 0)
            tinsert(data, e)
        end
    end

    local ignoreDouble = RTC.DB.AnnounceIgnoreDouble
    local function okCount(e) return ignoreDouble == false or e.count == 1 end

    if RTC.DB.MainAndOffSpecMode then
        local ms, offspec = {}, {}
        for _, e in ipairs(rolls) do
            if e.roll > 0 and e.high == 100 then
                tinsert(ms, e)
            elseif e.roll == 0 or e.high == 99 then
                tinsert(offspec, e)
            end
        end
        if not MarkWinners(ms, function(e) return okCount(e) and e.low == 1 end) then
            MarkWinners(offspec, function(e) return okCount(e) and (e.roll == 0 or (e.low == 1 and e.high == 99)) end)
        end
        if #ms > 0 then addSection(L["TxTMainSpec"], ms) end
        if #offspec > 0 then addSection(L["TxTOffSpec"], offspec) end
    else
        local rejectOut = RTC.DB.AnnounceRejectOutBounds
        MarkWinners(rolls, function(e)
            return okCount(e) and e.roll ~= 0 and
                       (rejectOut == false or (e.low == 1 and e.high == 100))
        end)
        addSection(nil, rolls)
    end

    local waiting = WaitingPlayers(party)
    if #waiting > 0 and #data > 0 then
        local missing = {}
        for _, p in ipairs(waiting) do
            tinsert(missing, {kind = "missing", name = p.name, class = p.class, rank = p.rank})
        end
        addSection(L["BtnNotRolled"], missing)
    end

    list.ScrollBox:SetDataProvider(CreateDataProvider(data),
                                   ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    list.Empty:SetShown(#RTC.rollArray == 0)

    -- status strip
    RollTrackerClassicFrameStatusText:SetText(string.format(L["TxtRolled"], #RTC.rollArray))
    list.Waiting.players = waiting
    if #waiting > 0 then
        list.Waiting:SetText(string.format(L["TxtWaiting"], #waiting))
        list.Waiting:Show()
    else
        list.Waiting:Hide()
    end

    -- clear button tooltip follows clear/undo state
    list.ClearTip = (#RTC.rollArray == 0 and #RTC.rollUndoArray > 0) and L["TipUndo"] or L["TipClear"]
    RollTrackerClassicFrameClearButton:SetText("")
end

local function AddInset(parent, region, left, top, right, bottom)
    local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", region, "TOPLEFT", left, top)
    inset:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", right, bottom)
    return inset
end

local function SetTooltip(button, textFunc)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(textFunc())
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", GameTooltip_Hide)
end

local function IconButton(button, atlas, texture)
    button:SetText("")
    button:SetSize(BUTTON_HEIGHT, BUTTON_HEIGHT)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER")
    if atlas then icon:SetAtlas(atlas) else icon:SetTexture(texture) end
    button.ForeverIcon = icon
end

local function OpenActionMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton(L["MenuCountdown"], function() RTC.StartCountdown() end)
        root:CreateButton(L["MenuAnnounceNotRolled"], function() RTC.NotRolled() end)
        root:CreateDivider()
        root:CreateButton(L["BtnClear"], function() RTC.ClearRolls() end)
        local undo = root:CreateButton(L["BtnUndo"], function() RTC.UndoRolls() end)
        undo:SetEnabled(#RTC.rollUndoArray > 0)
    end)
end

local function BuildActionBar(list)
    local helper = RollTrackerClassicFrameHelperButton
    local roll, off, pass = RollTrackerClassicFrameRollButton,
                            RollTrackerClassicFrameOffSpecButton,
                            RollTrackerClassicFramePassButton
    local ann, notr, clear = RollTrackerClassicFrameAnnounceButton,
                             RollTrackerClassicFrameNotRolledButton,
                             RollTrackerClassicFrameClearButton

    for _, b in ipairs({roll, off, pass, ann, clear}) do
        b:SetHeight(BUTTON_HEIGHT)
        b:SetNormalFontObject(GameFontNormal)
        b:SetHighlightFontObject(GameFontHighlight)
        b:SetDisabledFontObject(GameFontDisable)
        b:ClearAllPoints()
    end
    notr:Hide() -- moved to the action menu and the status strip
    notr.Show = notr.Hide

    -- row B (everyone): [Roll .........][OS][P]
    IconButton(pass, nil, RTC.IconPass)
    SetTooltip(pass, function() return L["BtnPass"] end)
    pass:SetPoint("BOTTOMRIGHT", helper, "TOPRIGHT", 0, 2)
    off:SetWidth(64)

    -- row A (leader): [Announce ......][v][x]
    IconButton(clear, "common-search-clearbutton")
    SetTooltip(clear, function() return list.ClearTip or L["TipClear"] end)

    local menu = CreateFrame("Button", nil, RollTrackerClassicFrame, "UIPanelButtonTemplate")
    IconButton(menu, "common-dropdown-a-button")
    menu.ForeverIcon:SetSize(12, 12)
    menu:SetPoint("BOTTOMRIGHT", pass, "TOPRIGHT", 0, GAP)
    menu:SetScript("OnClick", function(self) OpenActionMenu(self) end)
    SetTooltip(menu, function() return L["BtnMore"] end)
    list.MenuButton = menu

    ann:SetPoint("BOTTOMLEFT", helper, "TOPLEFT", 0, 2 + BUTTON_HEIGHT + GAP)
    ann:SetPoint("RIGHT", menu, "LEFT", -GAP, 0)

    -- status strip: "2 rolled" ............ "3 waiting"
    local status = RollTrackerClassicFrameStatusText
    status:SetFontObject(GameFontHighlightSmall)
    status:SetTextColor(1, 1, 1)
    local waiting = CreateFrame("Button", nil, RollTrackerClassicFrame)
    waiting:SetSize(80, 12)
    waiting:SetPoint("BOTTOMRIGHT", RollTrackerClassicFrame, "BOTTOMRIGHT", -2, 2)
    waiting:SetNormalFontObject(GameFontDisableSmall)
    waiting:SetHighlightFontObject(GameFontHighlightSmall)
    waiting:SetText(" ")
    waiting:GetFontString():SetJustifyH("RIGHT")
    waiting:GetFontString():SetAllPoints()
    waiting:SetScript("OnClick", function() RTC.NotRolled() end)
    waiting:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["BtnNotRolled"])
        for _, p in ipairs(self.players or {}) do
            local r, g, b = ClassRGB(p.class)
            GameTooltip:AddLine(p.name, r or 1, g or 1, b or 1)
        end
        GameTooltip:AddLine(L["TipWaiting"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    waiting:SetScript("OnLeave", GameTooltip_Hide)
    list.Waiting = waiting

    -- loot / csv tab buttons
    local lootClear = RollTrackerForeverZLootFrameClearButton
    local export = RollTrackerClassicCSVFrameExportButton
    for _, b in ipairs({lootClear, export}) do
        b:SetHeight(BUTTON_HEIGHT)
        b:SetNormalFontObject(GameFontNormal)
        b:SetHighlightFontObject(GameFontHighlight)
        b:ClearAllPoints()
    end
    lootClear:SetPoint("BOTTOMLEFT", RollTrackerForeverZLootFrameStatusText, "TOPLEFT", 0, 2)
    lootClear:SetPoint("BOTTOMRIGHT", RollTrackerForeverZLootFrameStatusText, "TOPRIGHT", 0, 2)
    export:SetPoint("BOTTOMLEFT", RollTrackerClassicCSVFrame, "BOTTOMLEFT", 0, 0)
    export:SetPoint("BOTTOMRIGHT", RollTrackerClassicCSVFrame, "BOTTOMRIGHT", 0, 0)
    RollTrackerForeverZLootFrame_MessageFrame:SetPoint("BOTTOMRIGHT", lootClear, "TOPRIGHT", -4, 8)
    RollTrackerClassicCSVFrame_MessageFrame:SetPoint("BOTTOMRIGHT", export, "TOPRIGHT", -4, 8)
end

-- Is the leader row ([Announce][menu][clear]) shown for this player?
function RTC.ShowLeaderRow()
    if not (RTC.DB and RTC.DB.AnnounceLeaderOnly) or not IsInGroup() then return true end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- Forever action bar layout:
--   leader row shown:  [Announce ......][v][x]
--                      [Roll .......][OS][P]
--   leader row hidden: [Roll ....][OS][x][P]
local function LayoutActionBar()
    local list = RTC.ForeverRollList
    local roll, off, pass = RollTrackerClassicFrameRollButton,
                            RollTrackerClassicFrameOffSpecButton,
                            RollTrackerClassicFramePassButton
    local ann, clear = RollTrackerClassicFrameAnnounceButton,
                       RollTrackerClassicFrameClearButton
    local showLeader = RTC.ShowLeaderRow()
    ann:SetShown(showLeader)
    list.MenuButton:SetShown(showLeader)

    for _, b in ipairs({roll, off, clear}) do b:ClearAllPoints() end
    roll:SetPoint("BOTTOMLEFT", RollTrackerClassicFrameHelperButton, "TOPLEFT", 0, 2)
    local rightOf = pass
    if showLeader then
        clear:SetPoint("LEFT", list.MenuButton, "RIGHT", GAP, 0)
        list.MenuButton:SetPoint("BOTTOMRIGHT", pass, "TOPRIGHT", -(BUTTON_HEIGHT + GAP), GAP)
    else
        clear:SetPoint("RIGHT", pass, "LEFT", -GAP, 0)
        rightOf = clear
    end
    if RTC.DB.MainAndOffSpecMode then
        off:SetPoint("RIGHT", rightOf, "LEFT", -GAP, 0)
        off:Show()
        rightOf = off
    else
        off:Hide()
    end
    roll:SetPoint("RIGHT", rightOf, "LEFT", -GAP, 0)

    -- Pass gets about a third of the row (Roll keeps the larger share);
    -- with enough room it shows its label next to the icon
    local w = RollTrackerClassicFrameHelperButton:GetWidth() or 0
    local reserved = GAP
    if RTC.DB.MainAndOffSpecMode then reserved = reserved + off:GetWidth() + GAP end
    if not showLeader then reserved = reserved + BUTTON_HEIGHT + GAP end
    local passWidth = math.max(BUTTON_HEIGHT, math.floor((w - reserved) / 3))
    pass:SetWidth(passWidth)
    if passWidth >= 60 then
        pass.ForeverIcon:Hide()
        pass:SetText(string.format(RTC.TxtEscapePicture, RTC.IconPass) .. " " .. L["BtnPass"])
    else
        pass.ForeverIcon:Show()
        pass:SetText("")
    end
    if showLeader then
        list.MenuButton:SetPoint("BOTTOMRIGHT", pass, "TOPRIGHT", -(BUTTON_HEIGHT + GAP), GAP)
    end

    -- list ends above the top button row
    list.Inset:SetPoint("BOTTOM", showLeader and ann or roll, "TOP", 0, 4)
end
RTC.LayoutForeverActionBar = LayoutActionBar

local OriginalResizeButtons = RTC.ResizeButtons
function RTC.ResizeButtons()
    if not RTC.DB then return end
    if not RTC.ForeverRollList then return OriginalResizeButtons() end
    LayoutActionBar()
end

-- countdown: the game's loot roll timer bar replaces the status strip
local OriginalStartCountdown = RTC.StartCountdown
function RTC.StartCountdown(x)
    OriginalStartCountdown(x)
    if RTC.Countdown then
        local left = RTC.Countdown - GetTime()
        if not RTC.CountdownTotal or left > RTC.CountdownTotal or
            not RTC.CountdownShown then
            RTC.CountdownTotal = left
        end
    end
end

local function UpdateTimerBar()
    local list = RTC.ForeverRollList
    if not list or not list.Timer then return end
    local timer = list.Timer
    local active = RTC.Countdown ~= nil and RTC.CountdownTotal and RTC.CountdownTotal > 0
    if not active then
        if RTC.CountdownShown then
            RTC.CountdownShown = nil
            RTC.CountdownTotal = nil
            timer:Hide()
            RollTrackerClassicFrameStatusText:Show()
            list.Waiting:SetAlpha(1)
        end
        return
    end
    if not RTC.CountdownShown then
        RTC.CountdownShown = true
        timer:Show()
        RollTrackerClassicFrameStatusText:Hide()
        list.Waiting:SetAlpha(0)
    end
    local left = math.max(0, RTC.Countdown - GetTime())
    local pct = math.min(1, left / RTC.CountdownTotal)
    local full = timer:GetWidth() - 4
    timer.Fill:SetShown(pct > 0)
    timer.Fill:SetWidth(math.max(1, full * pct))
    timer.Text:SetText(math.ceil(left))
end

local OriginalTimers = RTC.Timers
function RTC.Timers()
    OriginalTimers()
    UpdateTimerBar()
end

local function BuildTimerBar(list)
    local timer = CreateFrame("Frame", nil, RollTrackerClassicFrame)
    timer:SetHeight(13)
    timer:SetPoint("BOTTOMLEFT", RollTrackerClassicFrame, "BOTTOMLEFT", 0, 1)
    timer:SetPoint("BOTTOMRIGHT", RollTrackerClassicFrame, "BOTTOMRIGHT", 0, 1)
    timer.Background = timer:CreateTexture(nil, "BACKGROUND")
    timer.Background:SetAtlas("lootroll-timer-background")
    timer.Background:SetAllPoints()
    timer.Fill = timer:CreateTexture(nil, "ARTWORK")
    timer.Fill:SetAtlas("lootroll-timer-fill", true)
    timer.Fill:SetPoint("LEFT", 2, 0)
    timer.Border = timer:CreateTexture(nil, "OVERLAY")
    timer.Border:SetAtlas("lootroll-timer-border")
    timer.Border:SetAllPoints()
    timer.Text = timer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timer.Text:SetPoint("CENTER", 0, 1)
    timer:Hide()
    list.Timer = timer
end

-- the game's resize handle under the window (height); edges still resize width
local function BuildResizeHandle(list)
    local window = RollTrackerClassicMainWindow
    local handle = CreateFrame("Button", nil, window)
    handle:SetSize(32, 12)
    handle:SetPoint("TOP", window, "BOTTOM", 0, 3)
    local tex = handle:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas("lootroll-resizehandle")
    tex:SetAllPoints()
    handle:SetHighlightAtlas("lootroll-resizehandle", "ADD")
    handle:SetScript("OnMouseDown", function()
        window:StartSizing("BOTTOM", true)
    end)
    handle:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        RTC.SaveAnchors()
    end)
    handle.isForeverChrome = true
    tinsert(window.ForeverChrome, handle)
    list.ResizeHandle = handle
end

-- keep the handle clear of the tabs when the loot tracker shows them
function RTC.PlaceForeverResizeHandle()
    local list = RTC.ForeverRollList
    if not (list and list.ResizeHandle) then return end
    local window = RollTrackerClassicMainWindow
    local tabsShown = window.Tabs and window.Tabs[1] and window.Tabs[1]:IsShown()
    list.ResizeHandle:ClearAllPoints()
    if tabsShown then
        list.ResizeHandle:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", -12, 3)
    else
        list.ResizeHandle:SetPoint("TOP", window, "BOTTOM", 0, 3)
    end
end

local function BuildEmptyState(inset)
    local empty = CreateFrame("Frame", nil, inset)
    empty:SetAllPoints()
    local icon = empty:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas("lootroll-icon-need")
    icon:SetSize(24, 24)
    icon:SetAlpha(0.35)
    icon:SetPoint("CENTER", 0, 12)
    local text = empty:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    text:SetPoint("TOP", icon, "BOTTOM", 0, -4)
    local hint = empty:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOP", text, "BOTTOM", 0, -2)
    empty.Text, empty.Hint = text, hint
    return empty
end

function RTC.BuildForeverLayout()
    if not (CreateScrollBoxListLinearView and ScrollUtil and
        ScrollUtil.InitScrollBoxListWithScrollBar and CreateDataProvider and
        MenuUtil) then
        ModernizeScrollFrame(RollTrackerClassicFrameRollScrollFrame)
        return
    end

    local list = {}
    BuildActionBar(list)

    -- roll list: inset + ScrollBox rows instead of the text block
    RollTrackerClassicFrameRollScrollFrame:Hide()
    local inset = CreateFrame("Frame", nil, RollTrackerClassicFrame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", RollTrackerClassicFrame, "TOPLEFT", -2, 2)
    inset:SetPoint("RIGHT", RollTrackerClassicFrame, "RIGHT", 2, 0)
    inset:SetPoint("BOTTOM", RollTrackerClassicFrameAnnounceButton, "TOP", 0, 4)

    local box = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
    box:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
    box:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -14, 4)
    local bar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("RollTrackerForeverZRollRowTemplate", InitRollRow)
    view:SetElementExtentCalculator(function(_, d)
        return d.kind == "header" and HEADER_HEIGHT or ROW_HEIGHT
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    if ScrollUtil.AddManagedScrollBarVisibilityBehavior then
        ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
    end

    list.Inset, list.ScrollBox, list.ScrollBar = inset, box, bar
    list.Empty = BuildEmptyState(inset)
    BuildTimerBar(list)
    BuildResizeHandle(list)
    RTC.ForeverRollList = list

    -- leader row follows group leader / assistant changes
    local function refresh() if RTC.DB then LayoutActionBar() end end
    RTC.Tool.RegisterEvent("GROUP_ROSTER_UPDATE", refresh)
    RTC.Tool.RegisterEvent("PARTY_LEADER_CHANGED", refresh)

    -- loot and csv tabs: put the message frames on inset panels
    AddInset(RollTrackerForeverZLootFrame, RollTrackerForeverZLootFrame_MessageFrame, -4, 4, 4, -4)
    AddInset(RollTrackerClassicCSVFrame, RollTrackerClassicCSVFrame_MessageFrame, -4, 4, 4, -4)
end

-- texts created before the locale was loaded
function RTC.LocalizeForeverLayout()
    local list = RTC.ForeverRollList
    if not list then return end
    list.Empty.Text:SetText(L["TxtNoRolls"])
    list.Empty.Hint:SetText(L["TxtNoRollsHint"])
    RollTrackerClassicFrameRollButton:SetText(
        string.format(RTC.TxtEscapePicture, RTC.IconDice) .. " " .. L["BtnRoll"])
    RollTrackerClassicFrameOffSpecButton:SetText(L["BtnOffSpec"])
    RollTrackerClassicFrameClearButton:SetText("")
    RTC.LayoutForeverActionBar()
end

function RTC.ApplyForeverSkin(self)
    if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo and
        C_XMLUtil.GetTemplateInfo("DefaultPanelFlatTemplate")) then
        if Mixin and BackdropTemplateMixin then
            Mixin(self, BackdropTemplateMixin)
        end
        self:SetBackdrop(BACKDROP_TUTORIAL_16_16)
        return
    end

    local panel = CreateFrame("Frame", nil, self, "DefaultPanelFlatTemplate")
    panel:SetAllPoints()
    panel.isForeverChrome = true
    self.ForeverPanel = panel
    self.ForeverChrome = {}
    self:SetClampedToScreen(true)

    -- title text inside the panel's title bar
    local title = RollTrackerClassicMainWindowTitle
    title:SetParent(panel.TitleContainer)
    title:SetDrawLayer("OVERLAY")
    title:ClearAllPoints()
    title:SetPoint("TOP", panel.TitleContainer, "TOP", 0, -5)
    title:SetPoint("LEFT", panel.TitleContainer, "LEFT", -20, 0)
    title:SetPoint("RIGHT", panel.TitleContainer, "RIGHT", -30, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    -- modern close button
    local close = CreateFrame("Button", nil, self, "UIPanelCloseButtonDefaultAnchors")
    close:SetScript("OnClick", function() RTC.BtnClose() end)
    close.isForeverChrome = true
    tinsert(self.ForeverChrome, close)

    -- replace the old header buttons with flat icon buttons in the title bar
    RollTrackerClassicMainWindowCloseButton:Hide()
    RollTrackerClassicMainWindowSettingsButton:Hide()
    RollTrackerClassicMainWindowLootTable:Hide()

    local settings = TitleIconButton(panel, "Interface\\Buttons\\UI-OptionsButton",
                                     function() return L["BtnConfig"] end,
                                     function() RTC.BtnSettings() end)
    settings:SetPoint("RIGHT", close, "LEFT", 0, -1)
    tinsert(self.ForeverChrome, settings)

    local loot = TitleIconButton(panel, RTC.IconLoot,
                                 function() return L["BtnLootRolls"] end,
                                 function() RTC.LootHistoryShow() end)
    loot:SetPoint("RIGHT", settings, "LEFT", -2, 0)
    tinsert(self.ForeverChrome, loot)

    RTC.BuildForeverLayout()

    RTC.LayerForeverSkin()
end

-- Addon compartment (the addon button list under the minimap calendar)
function RollTrackerClassic_OnAddonCompartmentClick(_, buttonName, menuButton)
    if buttonName == "RightButton" then
        RTC.PopupMinimap(menuButton or UIParent)
    elseif IsShiftKeyDown() then
        RTC.LootHistoryShow()
    else
        RTC.ToggleWindow()
    end
end

function RollTrackerClassic_OnAddonCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    RTC.MenuToolTip(GameTooltip)
    GameTooltip:Show()
end

function RollTrackerClassic_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
