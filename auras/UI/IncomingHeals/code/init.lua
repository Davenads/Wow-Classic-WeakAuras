-- Incoming Heals Indicator — Actions ▸ On Init (actions.init.custom)
-- Resolves LibHealComm-4.0 ONCE (nil-safe: the aura still loads if no provider addon is
-- present) and stashes the handle + a default icon on aura_env for the TSU to use. When
-- LibHealComm IS present, we hook its callbacks so the trigger re-scans the instant an
-- inbound heal on YOU starts / updates / is delayed / is cancelled — no polling needed.
-- Data-source selection itself lives in tsu.lua (D2 LibHealComm ▸ else D1 native).
-- LibHealComm-4.0 API: https://www.wowace.com/projects/libhealcomm-4-0/pages/api
local HC = LibStub and LibStub("LibHealComm-4.0", true) or nil
aura_env.HC = HC
aura_env.icon = 135953   -- Interface/Icons/Spell_Holy_Heal — generic inbound-heal art

if HC then
    -- Stable string target: re-running On Init (reload / config change) just REPLACES the
    -- same callbacks rather than stacking duplicates.
    local target = "WA_IncomingHeals"

    -- The trailing varargs of every HealComm heal callback are the affected target GUIDs.
    local function affectsPlayer(...)
        local me = UnitGUID("player")
        for i = 1, select("#", ...) do
            if (select(i, ...)) == me then return true end
        end
        return false
    end

    -- HealStarted / HealUpdated / HealDelayed: (event, casterGUID, spellID, healType, endTime,     ...targetGUIDs)
    -- HealStopped:                             (event, casterGUID, spellID, healType, interrupted,  ...targetGUIDs)
    -- arg5 (endTime | interrupted) is ignored here; we re-read amounts fresh in the TSU.
    local function poke(event, casterGUID, spellID, healType, arg5, ...)
        if affectsPlayer(...) then
            WeakAuras.ScanEvents("HEALCOMM_INCOMING")
        end
    end

    HC.RegisterCallback(target, "HealComm_HealStarted", poke)
    HC.RegisterCallback(target, "HealComm_HealUpdated", poke)
    HC.RegisterCallback(target, "HealComm_HealDelayed", poke)
    HC.RegisterCallback(target, "HealComm_HealStopped", poke)
    -- Modifier / trackability changes carry a single GUID (or none) — just rescan.
    HC.RegisterCallback(target, "HealComm_ModifierChanged", function()
        WeakAuras.ScanEvents("HEALCOMM_INCOMING")
    end)
    HC.RegisterCallback(target, "HealComm_GUIDDisappeared", function()
        WeakAuras.ScanEvents("HEALCOMM_INCOMING")
    end)
end
