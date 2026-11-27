-- luacheck configuration (run by .github/workflows/lint.yml)
std = "lua51"
max_line_length = false
codes = true

-- third-party libraries are checked by their own projects
exclude_files = {
    "Lib/LibStub/**",
    "Lib/CallbackHandler-1.0/**",
    "Lib/LibDataBroker-1.1/**",
    "Lib/LibDBIcon-1.0/**",
    ".release/**",
}

-- The WoW API and Blizzard UI are hundreds of globals that are read freely.
-- Writing a global that isn't listed below is still reported, which catches
-- a forgotten "local".
ignore = {
    "113", -- accessing an undefined global (WoW API / Blizzard UI)
    "212", -- unused argument (event and script handler signatures)
    "61.", -- whitespace style
}

globals = {
    -- saved variables and the addon table
    "RollTrackerClassic_Addon",
    "RollTrackerForeverZDB",
    "RollTrackerForeverZLoot",
    -- addon compartment callbacks named in the TOC
    "RollTrackerClassic_OnAddonCompartmentClick",
    "RollTrackerClassic_OnAddonCompartmentEnter",
    "RollTrackerClassic_OnAddonCompartmentLeave",
    -- frames from RollTrackerClassic.xml the code adds fields to
    "RollTrackerClassicMainWindow",
    -- Blizzard tables / frames the addon adds entries to
    "StaticPopupDialogs",
    "SlashCmdList",
    "LootHistoryFrame",
}

-- the GPI helper libraries are older shared code: only report real problems
-- (errors and global writes), not style
files["Lib/LibGPIToolBox.lua"] = {ignore = {"21.", "23.", "31.", "4..", "621"}}
files["Lib/LibGPIOptions.lua"] = {ignore = {"21.", "23.", "31.", "4..", "621"}}
files["Lib/LibGPIMinimapButton.lua"] = {ignore = {"21.", "23.", "31.", "4..", "621"}}
