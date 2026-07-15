-- Incoming Heals Indicator — Trigger ▸ Custom ▸ Trigger State Updater ("stateupdate")
-- Shows a single state while a heal is inbound on YOU, timed to its land-time, carrying the
-- predicted amount + caster as custom fields. Graceful-degrade data source:
--   D2  LibHealComm-4.0 (aura_env.HC)  -> amount + land-time + caster, incl. HoTs/channels.
--   D1  native UnitGetIncomingHeals    -> amount only, direct casts only, no land-time.
--   (else)                             -> hide.
-- Declare in the Custom Variables box:  { amount = "number", hasAmount = true, casterName = "string" }
-- Events box:  HEALCOMM_INCOMING, UNIT_HEAL_PREDICTION, PLAYER_ENTERING_WORLD
-- LibHealComm-4.0 API: https://www.wowace.com/projects/libhealcomm-4-0/pages/api
function(allstates, event, ...)
    local now  = GetTime()
    local guid = UnitGUID("player")

    local function hide()
        allstates[""] = { show = false, changed = true }
        return true
    end

    if not guid then return hide() end

    -- ===== D2: LibHealComm (rich) =====
    local HC = aura_env.HC
    if HC then
        local amount, _, endTime, healerGUID = HC:GetNextHealAmount(guid)
        if amount and endTime and endTime > now then
            -- Sum every heal landing by that time, scaled by the active heal modifier.
            local incoming = HC:GetHealAmount(guid, HC.ALL_HEALS, endTime) or amount
            incoming = incoming * (HC:GetHealModifier(guid) or 1)

            -- Cache the bar/swipe length so repeated rescans don't reset it to full each
            -- time; only recompute when the soonest land-time actually changes.
            if aura_env.curEnd ~= endTime then
                aura_env.curEnd = endTime
                aura_env.curDur = endTime - now
            end

            local who = healerGUID and select(6, GetPlayerInfoByGUID(healerGUID)) or nil
            allstates[""] = {
                show           = true,
                changed        = true,
                progressType   = "timed",
                duration       = aura_env.curDur,
                expirationTime = endTime,
                autoHide       = true,
                icon           = aura_env.icon,
                name           = who or "Incoming Heal",
                amount         = math.floor(incoming + 0.5),
                hasAmount      = true,
                casterName     = who,
            }
            return true
        end
        aura_env.curEnd = nil
    end

    -- ===== D1: native fallback (amount only, no land-time) =====
    local inc = UnitGetIncomingHeals and UnitGetIncomingHeals("player")
    if inc and inc > 0 then
        allstates[""] = {
            show           = true,
            changed        = true,
            progressType   = "timed",
            duration       = 1.5,            -- native gives no land-time; show a brief window
            expirationTime = now + 1.5,
            autoHide       = true,
            icon           = aura_env.icon,
            name           = "Incoming Heal",
            amount         = math.floor(inc + 0.5),
            hasAmount      = true,
            casterName     = nil,
        }
        return true
    end

    return hide()
end
