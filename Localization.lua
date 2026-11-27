local _, RTC = ...

-- Basic localizations

RTC.PassTags = {}
function RTC.GetLocale()
    local DefaultEnGB = {
        ["MsgNbRolls"] = "%d Roll(s)",
        ["MsgRollCleared"] = "All rolls have been cleared.",
        ["MsgUndoRoll"] = "Undo all rolls.",
        ["MsgAnnounce"] = "%s won with a roll of %d.",
        ["MsgAnnounceItem"] = "%s won %s with a roll of %d.",
        ["MsgAnnounceTie"] = "Tie, %s won with a roll of %d.",
        ["MsgAnnounceTieItem"] = "Tie, %s won %s with a roll of %d.",
        ["MsgNotRolled"] = "The following people still need to roll or say '%s'",
        ["MsgCheat"] = "Ignoring %s's roll of %s (%s-%s).", -- (player, roll, max_roll, min_roll)
        ["MsgStart"] = "New roll starting now! Type '/roll' or '%s'",
        ["MsgStartMainAndOffSpecMode"] = "New roll starting now! Type '/roll' for MS, '/roll 99' for OS or '%s'",
        ["MsgNextItem"] = "Next item: %s",
        ["MsgTooltip"] = "|cffff4040Left click|r to open RTC |n|cffff4040Shift+Left click|r to open 'Loot Rolls'|n|cffff4040Right click|r to open options",
        ["MsgBar"] = "==============================",
        ["MsgLocalRestart"] = "The setting is not transferred until after a restart (/reload)",
        ["MsgNbLoots"] = "%d stored loot(s).",
        ["MsgLootLine"] = "%s: %s receives loot: %s", -- date, name, item
        ["MsgLootCleared"] = "All stored loots have been cleared.",
        ["MsgUndoLoot"] = "Undo all loots.",
        ["MsgLTnotenabled"] = "Loot Tracker is not enabled.",
        ["MsgRaidRoll"] = "%s won. (%d)",
        ["MsgForcedAnnounce"] = "No rolls",
        ["MsgStartCD"] = "Start a countdown with right click on [Announce] or '/rtc cd'",
        ["MsgPastLoots"] = "Past loots:",
        ["MsgAddNote"] = "%s note",
        ["MsgNotesCleared"] = "All player notes cleared",
        ["HeaderNotes"] = "Player notes",
        ["TxtNoNotes"] = "No player notes yet. Click a player in the roll list to add one.",
        ["TxTOffSpec"] = "Off Spec",
        ["TxTMainSpec"] = "Main Spec",
        ["TxtLine"] = "------------------------------------------------------------------------------------------------------",
        ["pass"] = "pass",
        ["BtnClear"] = "Clear",
        ["BtnUndo"] = "Undo",
        ["BtnNotRolled"] = "Not rolled",
        ["BtnRoll"] = "Roll",
        ["BtnAnnounce"] = "Announce",
        ["BtnOffSpec"] = "Off Spec",
        ["BtnPass"] = "Pass",
        ["BtnOpen"] = "Open",
        ["BtnConfig"] = "Settings",
        ["BtnLootRolls"] = "Loot Rolls",
        ["BtnOpenLoot"] = "Loot Tracker",
        ["BtnCSVExport"] = "CSV Export",
        ["BtnCancel"] = "Cancel",
        ["BtnRaidRoll"] = "Raid Roll",
        ["BtnColorNormal"] = "Colour text",
        ["BtnColorCheat"] = "Colour cheat",
        ["BtnColorGuild"] = "Colour guild",
        ["BtnColorInfo"] = "Colour info",
        ["BtnColorChat"] = "Colour chat message",
        ["BtnColorScroll"] = "Colour list entry",
        ["EdtWhiteList"] = "Whitelist ItemIds",
        ["EdtNbLoots"] = "Maximum stored loot",
        ["EdtCSVexport"] = "CSV-Export-Format",
        ["EdtCDRefresh"] = "Refresh Countdown after roll (seconds)",
        ["EdtDefaultCD"] = "Default Countdown (seconds)",
        ["EdtAutoCloseDelay"] = "Delayed closing in seconds",
        ["EdtAnnounceList"] = "Entries in the announcement list",
        ["TxtCSVJokers"] = "%% %name% %class% %timestamp% %dd% %mm% %yy% %HH% %MM% %SS%",
        ["TxtCSVJokers2"] = "%iname% %irarity% %iraritytxt% %ilevel% %iid% %iprice% %icount% %itype% %itypetxt%",
        ["TxtCSVJokersTitle"] = "For CSV-Export you can use this jokers:",
        ["TxtItemType"] = "Attention! ItemType is independent of the rarity!",
        ["TabRoll"] = "Rolls",
        ["TabLoot"] = "Loot",
        ["TabCSV"] = "CSV",
        ["PanelLootTracker"] = "Loot Tracker",
        ["HeaderRarity"] = "Track Rarity",
        ["HeaderItemType"] = "Track ItemType",
        ["HeaderSettings"] = "Settings",
        ["HeaderCustomLocales"] = "Localization",
        ["HeaderCSV"] = "CSV-Export",
        ["PanelAbout"] = "About",
        ["HeaderSlashCommand"] = "Slash Commands",
        ["HeaderCredits"] = "Credits",
        ["HeaderInfo"] = "Information",
        ["HeaderUsage"] = "Usage",
        ["Cboxshowminimapbutton"] = "Show minimap button",
        ["CboxLockMinimapButton"] = "Lock minimap button position",
        ["CboxLockMinimapButtonDistance"] = "Minimize minimap button distance",
        ["CboxCloseOnClear"] = "Close window after [Clear]",
        ["CboxClearOnAnnounce"] = "Clear rolls after [Announce]",
        ["CboxCloseOnAnnounce"] = "Close window after [Announce]",
        ["CboxClearOnClose"] = "Clear rolls after [Close]",
        ["CboxIgnoreDouble"] = "Ignore double rolls",
        ["CboxRejectOutBounds"] = "Reject rolls with bounds other than (1-100)",
        ["CboxAnnounceIgnoreDouble"] = "Only with [Announce]: Ignore double rolls",
        ["CboxAnnounceRejectOutBounds"] = "Only with [Announce]: Reject rolls with bounds other than (1-100)",
        ["CboxPromoteRolls"] = "Treat 69 as 101",
        ["CboxAutoCountdownWithItem"] = "Automatically start Countdown when linking item",
        ["CboxMainAndOffSpecMode"] = "Use MS '/roll' and OS '/roll 99' system",
        ["CboxShowNotRolled"] = "Show [Not rolled] button",
        ["CboxAnnounceLeaderOnly"] = "In a group, show [Announce] and the countdown only to the leader and assistants",
        ["CboxAutoLootRolls"] = "Open 'Loot Rolls' automatically",
        ["CboxAutoCloseLootRolls"] = "Automatic close 'Loot Rolls' when everyone has rolled",
        ["CboxClearOnStart"] = "Clear when somebody starts a new roll",
        ["CboxOpenOnStart"] = "Open when somebody starts a new roll",
        ["CboxColorName"] = "Colorize names by class",
        ["CboxShowClassIcon"] = "Show class icon",
        ["CboxOnDebug"] = "Show debug information",
        ["CboxShowGuildRank"] = "Show guild rank",
        ["CboxAutmaticAnnounce"] = "Automatic announce rolls",
        ["CboxNotfiyInnone"] = "Enable on overworld",
        ["CboxNotfiyInpvp"] = "Enable in battleground",
        ["CboxNotfiyInparty"] = "Enable in dungeon",
        ["CboxNotfiyInraid"] = "Enable in raid dungeon",
        ["CboxLTShortMessage"] = "Short Message",
        ["CboxLTTrackSolo"] = "Track solo",
        ["CboxLTTrackGroup"] = "Track party",
        ["CboxLTTrackSRaid"] = "Track raid with 10 or less members",
        ["CboxLTTrackBRaid"] = "Track raid with 11 or more members",
        ["CboxLTEnable"] = "Enable loot tracking",
        ["CboxLTSmallFont"] = "Small font",
        ["CboxLTShowIcon"] = "Show item icon",
        ["SlashClearRolls"] = "Clear rolls",
        ["SlashClearLoot"] = "Clear loot",
        ["SlashClearLootRolls"] = "Clear 'Loot Rolls'",
        ["SlashUndoRolls"] = "Recover last rolls",
        ["SlashUndoLoot"] = "Recover last loots",
        ["SlashAnnounce"] = "Announce winner of the last roll",
        ["SlashNotRolled"] = "Remind everyone who has not rolled",
        ["SlashClose"] = "Close main window",
        ["SlashReset"] = "Reset position of main window",
        ["SlashConfig"] = "Open Configuration",
        ["SlashAbout"] = "Open about",
        ["SlashStart"] = "Announce a new roll, <value> can be empty or itemlink",
        ["SlashOpen"] = "Open main window",
        ["SlashRaidRoll"] = "Roll a player name",
        ["SlashRaidRollList"] = "Output all player",
        ["SlashCountdown"] = "Countdown <value> in seconds",
        ["SlashNotes"] = "Print all notes",
        ["SlashClearNotes"] = "Clear all notes",
        ["SlashSim"] = "Simulate a raid for testing; <value> = number of players (2-12) or 'stop'",
        ["MsgSimStarted"] = "Simulated raid with %d players started. Chat messages stay in your chat window. Stop with /rtc sim stop",
        ["MsgSimStopped"] = "Simulated raid stopped.",
        ["TxtRolled"] = "%d rolled",
        ["TxtWaiting"] = "%d waiting",
        ["TxtTie"] = "tie",
        ["TxtNoRolls"] = "No rolls yet",
        ["TxtNoRollsHint"] = "/roll or press Roll",
        ["MenuCountdown"] = "Start countdown",
        ["TipStopCountdown"] = "Stop countdown",
        ["MenuAnnounceNotRolled"] = "Announce who has not rolled",
        ["BtnMore"] = "More actions",
        ["TipClear"] = "Clear rolls",
        ["TipUndo"] = "Undo clear",
        ["TipRemoveRoll"] = "Remove this roll",
        ["TipWaiting"] = "Click to remind them in chat.",
        ["MsgLootRollsNoClear"] = "The 'Loot Rolls' window is managed by the game on this client and can't be cleared.",
        ["AboutInfo"] = "Have you ever tried to roll the 'Onyxia Hide Backpack' in a raid? RTC collects all roll results and sorts them. Ever thought about whether you wanted something for your second-equip, but didn't know if somebody needed it? RTC can automatically open the Blizzard 'Loot rolls' window, where you can see immediately who needs or has greed.|nIn raid ever lost the overview, who got what? Again, RTC can help you. On request, it records all items, including a variable export function.",
        ["AboutSlashCommand"] = "<value> can be true, 1, enable, false, 0, disable. If <value> is omitted, the current status switches.",
        ["AboutUsage"] = "RTC will automatically open when someone rolls the dice. Double rolls or rolls outside the default range are ignored on request.|nBy default, the automatic opening of 'Loot Rolls' is disabled. Likewise, the 'Loot Tracker' must be turned on manually."
    }

    DefaultEnGB["AboutCredits"] =
        "RollTracker Classic is an updated version of 'RollTracker Lite', originally by Jerry Chong - zanglang@gmail.com.|nWoW: Forever port by Firstgoer, co-authored with Claude."

    -- "pass" is recognised in every language the addon ships
    RTC.PassTags[DefaultEnGB.pass] = true
    for _, locale in pairs(RTC.Locales or {}) do
        if locale.pass then RTC.PassTags[locale.pass] = true end
    end

    local L = {}
    setmetatable(DefaultEnGB,
                 {__index = function(_, k) return "[" .. k .. "]" end})
    setmetatable(L, {__index = DefaultEnGB})

    -- client language
    local clientLocale = RTC.Locales and RTC.Locales[GetLocale()]
    if clientLocale then
        for key, value in pairs(clientLocale) do L[key] = value end
    end

    -- texts the user changed in Options > Localization (applied after /reload)
    local db = RollTrackerForeverZDB
    if db and db.CustomLocales then
        for key, value in pairs(db.CustomLocales) do
            if type(value) == "string" and value ~= "" then
                L[key .. "_org"] = L[key]
                L[key] = value
                if key == "pass" then RTC.PassTags[value] = true end
            end
        end
    end
    return L
end
