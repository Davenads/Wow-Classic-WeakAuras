-- luacheck config for WeakAuras custom Lua (WoW Classic).
-- Run:  luacheck auras shared
--
-- WeakAuras code blocks are top-level anonymous functions pasted into the game, so we
-- relax a few rules that don't fit that authoring style.

std = "lua51+wow"
max_line_length = false
codes = true

-- Files here are code-block fragments, not modules: they define a bare function or set
-- fields on aura_env at the top level.
allow_defined_top = true
unused_args       = false
self              = false

-- The WeakAuras sandbox context (writable within custom code).
globals = {
    "aura_env",
}

-- WoW + WeakAuras + Classic API surface (read-only). Not exhaustive — add IDs you use.
read_globals = {
    -- WeakAuras
    "WeakAuras", "Private", "OptionsPrivate",
    -- Time / core
    "GetTime", "GetServerTime", "date", "time", "debugprofilestop",
    "C_Timer", "C_UnitAuras", "C_Spell", "C_Item", "C_ClassTalents", "C_Traits",
    "C_SpecializationInfo", "C_Map", "Enum", "bit", "strsplit", "strjoin",
    "string", "table", "math", "wipe", "tinsert", "tremove", "tContains",
    "CopyTable", "unpack", "select", "format", "gsub", "strtrim", "tonumber", "tostring",
    -- Units
    "UnitExists", "UnitName", "UnitGUID", "UnitClass", "UnitRace", "UnitLevel",
    "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitAffectingCombat",
    "UnitIsUnit", "UnitIsPlayer", "UnitIsDead", "UnitIsDeadOrGhost", "UnitCanAttack",
    "UnitReaction", "UnitClassification", "UnitCreatureType", "UnitBuff", "UnitDebuff",
    "UnitAura", "UnitCastingInfo", "UnitChannelInfo", "AuraUtil",
    -- Spells / cooldowns (legacy globals still present on Classic)
    "GetSpellInfo", "GetSpellCooldown", "GetSpellCharges", "GetSpellSubtext",
    "GetSpellTexture", "GetSpellCount", "IsUsableSpell", "IsSpellKnown",
    "IsPlayerSpell", "GetSpellBookItemInfo", "GetSpellBaseCooldown",
    "IsCurrentSpell", "GetTalentInfo", "GetSpecialization", "GetSpecializationInfo",
    "GetNumTalentTabs", "GetActiveTalentGroup",
    -- Items / equipment
    "GetItemInfo", "GetItemCooldown", "GetInventoryItemID", "GetInventoryItemLink",
    "GetInventoryItemTexture", "GetInventoryItemCooldown", "IsEquippedItem", "GetItemCount",
    "GetWeaponEnchantInfo", "EquipItemByName", "C_Container",
    -- Combat log
    "CombatLogGetCurrentEventInfo", "CombatLogGetCurrentEntry",
    -- Misc info
    "GetTime", "InCombatLockdown", "IsInInstance", "IsInGroup", "IsInRaid",
    "GetNumGroupMembers", "UnitGroupRolesAssigned", "GetRaidTargetIndex",
    "GetShapeshiftForm", "GetShapeshiftFormInfo", "GetInstanceInfo", "GetZoneText",
    "GetRealZoneText", "GetSubZoneText", "PlaySound", "PlaySoundFile",
    -- Chat / CVars / output (announcer auras)
    "SendChatMessage", "UnitFactionGroup", "GetCVar", "SetCVar", "print",
    -- Macro-set toggle flag read by the trinket auto-swap controller
    "TRK_PAUSED",
    -- Build / flavor constants
    "GetBuildInfo", "WOW_PROJECT_ID", "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_CATACLYSM_CLASSIC", "WOW_PROJECT_MISTS_CLASSIC", "WOW_PROJECT_MAINLINE",
    "GetLocale", "geterrorhandler",
}

exclude_files = {
    "auras/**/aura.json",
    "tools/node_modules",
}
