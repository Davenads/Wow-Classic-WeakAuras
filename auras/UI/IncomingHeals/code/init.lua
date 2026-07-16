-- Incoming Heals Indicator — Actions ▸ On Init (actions.init.custom)
-- Resolves LibHealComm-4.0 ONCE (nil-safe: the aura still loads if no provider addon is
-- present) and stashes the handle, a fallback icon, and a per-healer cast cache on aura_env.
-- The cast cache lets the TSU show the REAL inbound-heal spell icon (GetNextHealAmount does
-- not return a spellID, so we capture it from the callbacks) and the heal type.
-- Data-source selection itself lives in tsu.lua (D2 LibHealComm ▸ else D1 native).
-- LibHealComm-4.0 API: https://www.wowace.com/projects/libhealcomm-4-0/pages/api
local HC = LibStub and LibStub("LibHealComm-4.0", true) or nil
aura_env.HC = HC
-- Fallback art as a texture PATH (not a numeric fileID — some IDs render as "?" on Era).
aura_env.icon = "Interface\\Icons\\Spell_Holy_Heal"
aura_env.casts = aura_env.casts or {}   -- [casterGUID] = { spellID, healType, endTime }

if HC then
    -- Stable string target: re-running On Init (reload / config change) just REPLACES the
    -- same callbacks rather than stacking duplicates.
    local target = "WA_IncomingHeals"
    local casts = aura_env.casts

    -- The trailing varargs of every HealComm heal callback are the affected target GUIDs.
    local function affectsPlayer(...)
        local me = UnitGUID("player")
        for i = 1, select("#", ...) do
            if (select(i, ...)) == me then return true end
        end
        return false
    end

    -- HealStarted / HealUpdated / HealDelayed: (event, casterGUID, spellID, healType, endTime, ...targetGUIDs)
    -- Cache the spellID + healType for casts that land on US, then rescan.
    local function onStart(event, casterGUID, spellID, healType, endTime, ...)
        if affectsPlayer(...) then
            casts[casterGUID] = { spellID = spellID, healType = healType, endTime = endTime }
            WeakAuras.ScanEvents("HEALCOMM_INCOMING")
        end
    end
    -- HealStopped: (event, casterGUID, spellID, healType, interrupted, ...targetGUIDs)
    local function onStop(event, casterGUID)
        casts[casterGUID] = nil
        WeakAuras.ScanEvents("HEALCOMM_INCOMING")
    end

    HC.RegisterCallback(target, "HealComm_HealStarted", onStart)
    HC.RegisterCallback(target, "HealComm_HealUpdated", onStart)
    HC.RegisterCallback(target, "HealComm_HealDelayed", onStart)
    HC.RegisterCallback(target, "HealComm_HealStopped", onStop)
    -- Modifier changes (Mortal Strike etc.) carry a single GUID (or none) — just rescan.
    HC.RegisterCallback(target, "HealComm_ModifierChanged", function()
        WeakAuras.ScanEvents("HEALCOMM_INCOMING")
    end)
    HC.RegisterCallback(target, "HealComm_GUIDDisappeared", function(event, guid)
        if guid then casts[guid] = nil end
        WeakAuras.ScanEvents("HEALCOMM_INCOMING")
    end)
end
