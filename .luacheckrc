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
    -- Shared cross-icon state frame for WSG Callout Bars (a named global frame; children
    -- don't share aura_env, so the friendly-FC tracker lives here).
    "WSGCalloutHub",
    -- Shared cross-child state frame for Betty's BG Item Callout (timestamps, corroboration,
    -- addon bus). Children don't share aura_env, so the hub is a named global frame.
    "BGICHub",
}

-- WoW + WeakAuras + Classic API surface (read-only). Not exhaustive — add IDs you use.
read_globals = {
    -- WeakAuras
    "WeakAuras", "Private", "OptionsPrivate", "WA_IterateGroupMembers",
    -- Addon comms (battleground callout auras)
    "C_ChatInfo",
    -- Time / core
    "GetTime", "GetServerTime", "date", "time", "debugprofilestop",
    "C_Timer", "C_UnitAuras", "C_Spell", "C_Item", "C_ClassTalents", "C_Traits",
    "C_SpecializationInfo", "C_Map", "Enum", "bit", "strsplit", "strjoin",
    "string", "table", "math", "wipe", "tinsert", "tremove", "tContains",
    "CopyTable", "unpack", "select", "format", "gsub", "strtrim", "tonumber", "tostring",
    -- Units
    "UnitExists", "UnitName", "UnitGUID", "UnitClass", "UnitRace", "UnitLevel",
    "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType", "UnitAffectingCombat",
    "UnitIsUnit", "UnitIsPlayer", "UnitIsDead", "UnitIsDeadOrGhost", "UnitCanAttack", "UnitInRange",
    "UnitReaction", "UnitClassification", "UnitCreatureType", "UnitBuff", "UnitDebuff",
    "UnitAura", "UnitCastingInfo", "UnitChannelInfo", "AuraUtil",
    -- Spells / cooldowns (legacy globals still present on Classic)
    "GetSpellInfo", "GetSpellCooldown", "GetSpellCharges", "GetSpellSubtext",
    "GetSpellTexture", "GetSpellCount", "IsUsableSpell", "IsSpellKnown",
    "IsPlayerSpell", "GetSpellBookItemInfo", "GetSpellBaseCooldown",
    "IsCurrentSpell", "GetTalentInfo", "GetSpecialization", "GetSpecializationInfo",
    "GetNumTalentTabs", "GetActiveTalentGroup",
    -- Totems (Shaman) — native on current Era/SoD/Cata/MoP clients
    "GetTotemInfo", "MAX_TOTEMS",
    -- Items / equipment
    "GetItemInfo", "GetItemCooldown", "GetInventoryItemID", "GetInventoryItemLink",
    "GetInventoryItemTexture", "GetInventoryItemCooldown", "IsEquippedItem", "GetItemCount",
    "GetItemIcon",
    "GetWeaponEnchantInfo", "EquipItemByName", "C_Container",
    "GetContainerNumSlots", "GetContainerItemID",
    -- Combat log
    "CombatLogGetCurrentEventInfo", "CombatLogGetCurrentEntry",
    -- Misc info
    "GetTime", "InCombatLockdown", "IsInInstance", "IsInGroup", "IsInRaid", "LE_PARTY_CATEGORY_INSTANCE",
    "GetNumGroupMembers", "UnitGroupRolesAssigned", "GetRaidTargetIndex",
    "GetShapeshiftForm", "GetShapeshiftFormInfo", "GetInstanceInfo", "GetZoneText",
    "GetRealZoneText", "GetSubZoneText", "PlaySound", "PlaySoundFile", "SOUNDKIT",
    "GetAreaSpiritHealerTime",
    -- Combat-log object flags
    "COMBATLOG_OBJECT_REACTION_HOSTILE", "COMBATLOG_OBJECT_REACTION_FRIENDLY",
    "COMBATLOG_OBJECT_AFFILIATION_MINE",
    -- Chat / CVars / output (announcer auras)
    "SendChatMessage", "UnitFactionGroup", "GetCVar", "SetCVar", "print",
    -- Frames / input (click-button auras)
    "CreateFrame", "IsControlKeyDown", "IsShiftKeyDown", "IsAltKeyDown",
    "UnitIsGroupLeader", "UnitIsGroupAssistant",
    -- Macro-set globals read by the trinket auto-swap controller
    "TRK_PAUSED", "TRK_DEBUG", "TRK_IOTA",
    -- Build / flavor constants
    "GetBuildInfo", "WOW_PROJECT_ID", "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_CATACLYSM_CLASSIC", "WOW_PROJECT_MISTS_CLASSIC", "WOW_PROJECT_MAINLINE",
    "GetLocale", "geterrorhandler",
}

exclude_files = {
    "auras/**/aura.json",
    "tools/node_modules",
}
