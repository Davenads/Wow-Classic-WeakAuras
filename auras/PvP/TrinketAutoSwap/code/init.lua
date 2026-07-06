-- PvP Trinket Auto-Swap — Controller — Actions ▸ On Init
-- Builds aura_env state + all helpers for the AGM / Insignia / MR resolver.
-- Item IDs (Classic Era, verified): AGM 19024, Insignia(Ally Pala) 18864, Minor Recombobulator 4381.

local cfg = aura_env.config or {}
local iotaOverride = tonumber(cfg.iotaId)     -- explicit Insignia id; nil => auto-detect at runtime

aura_env.cfg = {
    enabled = (cfg.enabled ~= false),         -- master on/off (Custom Option)
    agmId   = tonumber(cfg.agmId)   or 19024, -- Arena Grand Master  https://www.wowhead.com/classic/item=19024
    iotaId  = iotaOverride           or 18864, -- Insignia — auto-detected unless pinned (default Ally Pala)
    mrId    = tonumber(cfg.mrId)    or 4381,  -- Minor Recombobulator  https://www.wowhead.com/classic/item=4381
    minGap  = tonumber(cfg.minGap)  or 1.0,   -- seconds between equip attempts (debounce)
    agmLock = tonumber(cfg.agmLock) or 20,    -- keep AGM equipped this long (s) after its on-use
    equipCd = tonumber(cfg.equipCd) or 30,    -- ignore cooldowns <= this (the trinket equip lockout)
    swapBuffer = tonumber(cfg.swapBuffer) or 1, -- extra s so a swapped-in on-use's lockout fully covers its CD tail
    swapMargin = tonumber(cfg.swapMargin) or 5, -- anti-thrash: only swap an equipped on-CD on-use out for a benched one that is >= this many s sooner
    stackAgm   = (cfg.stackAgm ~= false),     -- if 2 AGMs owned, wear both for +2% dodge while idle
    debug   = cfg.debug == true,
}
-- 2-AGM mode: pre-equip an on-use trinket once its remaining CD is within this window, so its
-- ~30s equip lockout overlaps the CD tail and it's usable the instant the lockout ends.
aura_env.cfg.swapBackAt = aura_env.cfg.equipCd + aura_env.cfg.swapBuffer
-- true => user pinned iotaId in Custom Options; skip auto-detect and honor their value.
aura_env.iotaLocked = iotaOverride ~= nil

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
-- Equipping a trinket triggers a ~30s equip lockout (anti hot-swap). That is NOT the item's
-- real use cooldown, so ignore any cooldown whose duration is <= cfg.equipCd — otherwise a
-- freshly equipped trinket reads as "on CD" and the resolver swaps it straight back out.
function aura_env.CdLeft(itemId)
    if not itemId then return 0 end
    local start, dur = itemCooldown(itemId)
    if not start or start == 0 or not dur or dur == 0 then return 0 end
    if dur <= aura_env.cfg.equipCd then return 0 end  -- equip lockout, not the real use CD
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

-- Total AGM copies the character owns = bag copies (GetItemCount excludes equipped) plus any
-- worn in slot 13/14. >=2 unlocks 2-AGM mode (wear both for +2% dodge; on-use shares one 30m CD).
function aura_env.AgmCount()
    local A = aura_env.cfg.agmId
    local n = GetItemCount(A) or 0
    if GetInventoryItemID("player", 13) == A then n = n + 1 end
    if GetInventoryItemID("player", 14) == A then n = n + 1 end
    return n
end

-- Flavor-aware bag readers (globals on Era; C_Container on Cata/MoP).
local function bagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
    return GetContainerNumSlots(bag)
end
local function bagItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then return C_Container.GetContainerItemID(bag, slot) end
    return GetContainerItemID(bag, slot)
end

-- Auto-detect the PvP Insignia by name ("Insignia of the ...") so the aura is faction/class-
-- agnostic with zero config. Scans worn trinket slots first, then bags. English clients only;
-- other locales pin iotaId. Returns an item id or nil.
function aura_env.DetectInsignia()
    local function isInsignia(itemId)
        if not itemId then return false end
        local n = GetItemInfo(itemId)
        return n ~= nil and n:find("Insignia of the", 1, true) ~= nil
    end
    for _, s in ipairs({ 13, 14 }) do
        local id = GetInventoryItemID("player", s)
        if isInsignia(id) then return id end
    end
    for bag = 0, 4 do
        for slot = 1, (bagSlots(bag) or 0) do
            if isInsignia(bagItemID(bag, slot)) then return bagItemID(bag, slot) end
        end
    end
    return nil
end

-- Point cfg.iotaId at the detected Insignia unless the user pinned it. Cheap; safe to call often.
function aura_env.RefreshInsignia()
    if aura_env.iotaLocked then return end
    local found = aura_env.DetectInsignia()
    if found and found ~= aura_env.cfg.iotaId then
        aura_env.cfg.iotaId = found
        if aura_env.cfg.debug then print("|cff66ccff[TRK]|r insignia detected: " .. found) end
    end
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

-- Resolve the desired 2-trinket loadout -> an ordered list { id1, id2 } (may repeat, e.g.
-- { agm, agm } in 2-AGM mode). Mirrors the §3 decision table in plan.md; §13 covers 2-AGM.
function aura_env.Desired()
    local c = aura_env.cfg
    local A, I, M  = c.agmId, c.iotaId, c.mrId
    local Ir, Ar   = aura_env.IsReady(I), aura_env.IsReady(A)
    local mAvail   = aura_env.IsReady(M) and aura_env.Owned(M)

    local function soonest(a, b)
        return aura_env.CdLeft(a) <= aura_env.CdLeft(b) and a or b
    end

    -- 2-AGM mode (Model B): both AGMs share one 30m on-use CD, but their +1% dodge passives
    -- stack, so keep >=1 AGM worn always. Fill the other slot with the best on-use trinket
    -- that's ready or returning within swapBackAt (Insignia > MR); otherwise the 2nd AGM
    -- (+2% total dodge) while both on-use trinkets are >30s out. AGM always worn => no lock.
    if c.stackAgm and aura_env.AgmCount() >= 2 then
        local function usableSoon(x)
            return aura_env.Owned(x) and aura_env.CdLeft(x) <= c.swapBackAt
        end
        if usableSoon(I) then return { A, I }
        elseif usableSoon(M) then return { A, M }
        else return { A, A } end
    end

    local pick
    if Ir and Ar then
        pick = { I, A }                                    -- rows 1,2
    elseif Ir then                                         -- IoTA up, AGM down
        if mAvail then pick = { I, M }                     -- row 3
        else           pick = { I, A } end                 -- row 4 (MR unavailable -> keep AGM)
    elseif Ar then                                         -- AGM up, IoTA down
        if mAvail then pick = { A, M }                     -- row 5
        else           pick = { A, I } end                 -- row 6
    else                                                   -- both down
        if mAvail then pick = { A, M }                     -- row 7
        else           pick = { A, soonest(I, M) } end     -- row 8
    end

    -- AGM 20s post-use lock: force-keep AGM regardless of the table.
    if aura_env.agmLockUntil and GetTime() < aura_env.agmLockUntil
       and pick[1] ~= A and pick[2] ~= A then
        local other
        if Ir then other = I
        elseif mAvail then other = M
        else other = soonest(I, M) end
        pick = { A, other }
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

    local want = aura_env.Desired()       -- { id1, id2 } — may contain a duplicate (2x AGM)
    local id13 = GetInventoryItemID("player", 13)
    local id14 = GetInventoryItemID("player", 14)

    -- Multiset compare {id13,id14} vs want: greedily claim each want slot with a distinct
    -- equipped copy, so { AGM, AGM } needs two physically equipped AGMs (not one counted twice).
    local matched = { false, false }
    local function claim(equippedId)
        if equippedId == nil then return false end
        for i = 1, 2 do
            if not matched[i] and want[i] == equippedId then matched[i] = true; return true end
        end
        return false
    end
    local ok13 = claim(id13)
    local ok14 = claim(id14)
    if ok13 and ok14 then aura_env.pending = false; return end  -- already correct

    local now = GetTime()
    if aura_env.lastEquip and (now - aura_env.lastEquip) < c.minGap then return end

    -- Equip one unmet want entry per call (events reconverge). Overwrite a slot whose item
    -- isn't needed, else an empty slot.
    local target
    if id13 and not ok13 then target = 13
    elseif id14 and not ok14 then target = 14
    elseif not id13 then target = 13
    elseif not id14 then target = 14 end
    if not target then aura_env.pending = false; return end

    -- Anti-thrash hysteresis: never swap an equipped, on-cooldown ON-USE trinket (Insignia/MR)
    -- out for a benched on-use trinket unless the incoming one is usable NOW or meaningfully
    -- (swapMargin s) sooner. Kills the 13<->14 flicker when two on-use CDs are close, or when a
    -- duplicate copy's readiness momentarily flips. AGM (the passive anchor) is never gated, and
    -- replacing an empty slot or an untracked/junk trinket is always allowed. A blocked swap just
    -- holds the current loadout (no equip => no event cascade => no thrash).
    local function okToSwap(incoming, slot)
        if incoming == c.agmId then return true end
        local displaced = GetInventoryItemID("player", slot)
        if not displaced then return true end
        if displaced ~= c.iotaId and displaced ~= c.mrId then return true end
        if aura_env.IsReady(incoming) then return true end
        return aura_env.CdLeft(incoming) <= (aura_env.CdLeft(displaced) - c.swapMargin)
    end

    for i = 1, 2 do
        if not matched[i] then
            local id = want[i]
            -- EquipItemByName pulls from BAGS, so a fresh equip needs a spare bag copy. For a
            -- 2nd AGM this is guaranteed (AgmCount>=2 means the unequipped copy sits in bags).
            if (GetItemCount(id) or 0) > 0 and okToSwap(id, target) then
                EquipItemByName(id, target)
                aura_env.lastEquip = now
                if c.debug then print("|cff66ccff[TRK]|r equip " .. id .. " -> slot " .. target) end
                return
            end
        end
    end
    aura_env.pending = false
end

-- Seed the Insignia id from current bags/equipment on load (re-checked each tick in on_show).
aura_env.RefreshInsignia()
