-- luacheck configuration for LootBooster.
--
-- Run with:  luacheck .

std = "lua51"
max_line_length = false
codes = true

exclude_files = {
	".release/",
}

-- Globals the add-on itself owns.
globals = {
	"LBooster", "LootBoosterDB",
	"SlashCmdList", "SLASH_LOOTBOOSTER_COMMANDLIST1", "SLASH_LOOTBOOSTER_COMMANDLIST2",
}

-- Client API the add-on reads, checked against the Retail 12.1.5 and Forever
-- 1.60.1 UI sources. A call missing from here is a porting bug.
read_globals = {
	"C_AddOns", "C_CurrencyInfo", "C_Item", "ChatTypeInfo", "ColorManager", "ConfirmLootSlot", "CreateFrame",
	"DEFAULT_CHAT_FRAME", "Enum", "GetBuildInfo", "GetCurrentBindingSet", "GetLootSlotInfo", "GetLootSlotLink",
	"GetModifiedClick", "GetNumLootItems", "InCombatLockdown", "IsShiftKeyDown", "LootSlot", "PlaySoundFile",
	"RaidWarningUtil", "SaveBindings", "SetModifiedClick",
	string = { fields = { "trim" } },
}
