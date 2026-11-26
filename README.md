# RollTracker Forever Z
This project is an addon for World of Warcraft: Forever (interface 16001), Classic Era and Mists of Pandaria Classic.
The WoW: Forever port lives at https://github.com/Firstgoer/RollTrackerForeverZ.
It is a continuation of RollTracker Classic, which had been marked as abandoned on CurseForge.

Most of the credit for this addon goes to its original authors, and the original project can be found [here](https://www.curseforge.com/wow/addons/rolltracker-classic-z).

RTCZ collects all roll results, sorts them, and automatically opens when someone rolls the dice.
Double rolls or rolls outside the default range are ignored on request.

## Slash Commands
All slash commands start with /rtc, and the following commands are currently available.

### /rtc clear rolls
This command will clear the rolls.

### /rtc clear loot
This command will clear the loot.

### /rtc clear lootrolls
This command will clear the 'Loot Rolls' (classic clients only; on WoW: Forever the game manages that window).

### /rtc undo rolls
This command will recover the last rolls.

### /rtc undo loot
This command will recover the last loots.

### /rtc announce
This command will announce the winner of the last roll.

### /rtc notrolled
This command will remind everyone who has not rolled.

### /rtc close
This command will close main window.

### /rtc reset
This command will reset the position of the main window.

### /rtc config/setup/options
This command will open the Configuration window.

### /rtc about
This command will open the About window.

### /rtc start <value>
This command will announce a new roll. An item link can be given.

### /rtc loottracker <value>
This command will enable or disable loot tracking.

### /rtc
This command will open the Main window.

## Credits
- Russian translation by tierggg and Hubbotu; WoW: Forever Russian translation by Firstgoer and Claude
- Korean translation by BattleE, classe82
- Simplified Chinese translation by kokpk
- Baudzilla for the graphics/idea of the resize-code
- RollTracker Classic is an updated version of "RollTracker Lite", originally by Jerry Chong - zanglang@gmail.com.
- WoW: Forever port by Firstgoer, co-authored with Claude.
- Mists Classic maintenance by [MrFIXIT](https://www.curseforge.com/members/mrfixlt/followers).

## WoW: Forever notes
- While the game's chat messaging lockdown is active (boss encounters, Mythic+, rated PvP), chat messages are hidden from addons and addons may not send chat. RTC can't see /roll results during that time and prints its announcements only to your own chat window.
- The addon folder must be named `RollTrackerForeverZ` (the TOC files and saved settings use that name).
