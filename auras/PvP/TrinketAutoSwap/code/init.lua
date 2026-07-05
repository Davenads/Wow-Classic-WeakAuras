-- PvP Trinket Auto-Swap — Controller — Actions ▸ On Init
-- Builds aura_env state + all helpers for the AGM / Insignia / MR resolver.
-- Item IDs (Classic Era, verified): AGM 19024, Insignia(Ally Pala) 18864, Minor Recombobulator 4381.

local cfg = aura_env.config or {}

aura_env.cfg = {
    enabled = (cfg.enabled ~= false),         -- master on/off (Custom Option)
    agmId   = tonumber(cfg.agmId)   or 19024, -- Arena Grand Master  https://www.wowhead.com/classic/item=19024
    iotaId  = tonumber(cfg.iotaId)  or 18864, -- Insignia of the Alliance (Paladin)  item=18864
    mrId    = tonumber(cfg.mrId)    or 4381,  -- Minor Recombobulator  https://www.wowhead.com/classic/item=4381
    minGap  = tonumber(cfg.minGap)  or 1.0,   -- seconds between equip attempts (debounce)
    agmLock = tonumber(cfg.agmLock) or 20,    -- keep AGM equipped this long (s) after its on-use
    debug   = cfg.debug == true,
}

-- Flavor-aware item-cooldown getter (global on Era; C_Container/C_Item on Cata/MoP).
local function itemCooldown(itemId)
    if C_Container and C_Container.GetItemCooldown then
        return C_Container.GetItemCooldown(itemId)
    elseif C_Item and C_Item.GetItemCooldown then
        return C_Item.GetItemCooldown(itemId)
    end
    return GetItemCooldown(itemId)
end

-- Remaining cooldown (seconds) for an item id; 0 = ready.
function aura_env.CdLeft(itemId)
    if not itemId then return 0 end
    local start, dur = itemCooldown(itemId)
    if not start or start == 0 or not dur or dur == 0 then return 0 end
    local left = (start + dur) - GetTime()
    return left > 0 and left or 0
end

function aura_env.IsReady(itemId)
    return aura_env.CdLeft(itemId) <= 0
end

function aura_env.Owned(itemId)
    if itemId == nil then return false end
    if (GetItemCount(itemId) or 0) > 0 then return true end
    -- GetItemCount excludes EQUIPPED items; a trinket in slot 13/14 still counts as owned.
    return aura_env.SlotOf(itemId) ~= nil
end

-- Which trinket slot (13/14) currently holds itemId, or nil.
function aura_env.SlotOf(itemId)
    if itemId == nil then return nil end
    if GetInventoryItemID("player", 13) == itemId then return 13 end
    if GetInventoryItemID("player", 14) == itemId then return 14 end
    return nil
end

-- Detect AGM's on-use firing (ready -> not ready) and start the keep-equipped lock.
function aura_env.WatchAGM()
    local ready = aura_env.IsReady(aura_env.cfg.agmId)
    if aura_env.agmPrevReady == nil then
        aura_env.agmPrevReady = ready
    elseif aura_env.agmPrevReady and not ready then
        aura_env.agmLockUntil = GetTime() + aura_env.cfg.agmLock
    end
    aura_env.agmPrevReady = ready
end

-- Resolve the desired 2-trinket set -> { [itemId]=true, [itemId]=true }.
-- Mirrors the §3 decision table in plan.md.
function aura_env.Desired()
    local c = aura_env.cfg
    local A, I, M  = c.agmId, c.iotaId, c.mrId
    local Ir, Ar   = aura_env.IsReady(I), aura_env.IsReady(A)
    local mAvail   = aura_env.IsReady(M) and aura_env.Owned(M)

    local function soonest(a, b)
        return aura_env.CdLeft(a) <= aura_env.CdLeft(b) and a or b
    end

    local pick = {}
    if Ir and Ar then
        pick[I] = true; pick[A] = true                     -- rows 1,2
    elseif Ir then                                         -- IoTA up, AGM down
        if mAvail then pick[I] = true; pick[M] = true      -- row 3
        else           pick[I] = true; pick[A] = true end  -- row 4 (MR unavailable -> keep AGM)
    elseif Ar then                                         -- AGM up, IoTA down
        if mAvail then pick[A] = true; pick[M] = true      -- row 5
        else           pick[A] = true; pick[I] = true end  -- row 6
    else                                                   -- both down
        if mAvail then pick[A] = true; pick[M] = true      -- row 7
        else           pick[A] = true; pick[soonest(I, M)] = true end -- row 8
    end

    -- AGM 20s post-use lock: force-keep AGM regardless of the table.
    if aura_env.agmLockUntil and GetTime() < aura_env.agmLockUntil and not pick[A] then
        pick = { [A] = true }
        if Ir then pick[I] = true
        elseif mAvail then pick[M] = true
        else pick[soonest(I, M)] = true end
    end

    return pick
end

-- Apply the desired loadout (OUT OF COMBAT ONLY). One swap per call; events reconverge.
function aura_env.Apply()
    local c = aura_env.cfg
    -- TRK_PAUSED is a plain global toggled by an out-of-sandbox macro (the sandbox blocks
    -- SlashCmdList, so the aura can't register its own /command):
    --   /run TRK_PAUSED = not TRK_PAUSED; print("[Trinket Swap] "..(TRK_PAUSED and "PAUSED" or "ACTIVE"))
    -- Resets to ACTIVE on /reload or login (default-on). For a persistent off, disable the aura.
    if not c.enabled or TRK_PAUSED then aura_env.pending = false; return end
    if InCombatLockdown() then aura_env.pending = true; return end
    if not EquipItemByName then return end  -- sandbox blocked equipping

    local want = aura_env.Desired()
    local id13 = GetInventoryItemID("player", 13)
    local id14 = GetInventoryItemID("player", 14)

    -- Already correct? (both wanted ids equipped, any order.)
    local correct = true
    for id in pairs(want) do
        if id ~= id13 and id ~= id14 then correct = false break end
    end
    if correct then aura_env.pending = false; return end

    local now = GetTime()
    if aura_env.lastEquip and (now - aura_env.lastEquip) < c.minGap then return end

    for id in pairs(want) do
        if id ~= id13 and id ~= id14 and (aura_env.Owned(id) or aura_env.SlotOf(id)) then
            local target
            if id13 and not want[id13] then target = 13
            elseif id14 and not want[id14] then target = 14
            elseif not id13 then target = 13
            elseif not id14 then target = 14 end
            if target then
                EquipItemByName(id, target)
                aura_env.lastEquip = now
                if c.debug then print("|cff66ccff[TRK]|r equip " .. id .. " -> slot " .. target) end
                return
            end
        end
    end
    aura_env.pending = false
end
