-- Incoming Heals Indicator — Trigger ▸ Custom ▸ Trigger State Updater ("stateupdate")
-- Shows a single state while a heal is inbound on YOU, timed to its land-time, carrying the
-- REAL spell icon + rich fields (amount / caster / heal type / modifier / overheal) for the
-- %c text. Graceful-degrade data source:
--   D2  LibHealComm-4.0 (aura_env.HC)  -> spell icon + amount + land-time + caster + type + modifier.
--   D1  native UnitGetIncomingHeals    -> amount only, direct casts only, no land-time.
--   (else)                             -> hide.
-- Custom Variables box:
--   { amount = "number", rawAmount = "number", hasAmount = true, casterName = "string",
--     casterGUID = "string", spellName = "string", healType = "string",
--     modifier = "number", overheal = "bool" }
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
            local modifier = HC:GetHealModifier(guid) or 1
            local raw = HC:GetHealAmount(guid, HC.ALL_HEALS, endTime) or amount
            local incoming = raw * modifier

            -- Real spell icon + type from the cast we cached on the callback (fallback: generic art).
            local cast    = healerGUID and aura_env.casts[healerGUID]
            local spellID = cast and cast.spellID
            local icon    = (spellID and GetSpellTexture(spellID)) or aura_env.icon
            local spellNm = spellID and (GetSpellInfo(spellID)) or nil

            local healType
            if cast and cast.healType then
                local t = cast.healType
                if     HC.CHANNEL_HEALS and t == HC.CHANNEL_HEALS then healType = "Channel"
                elseif HC.HOT_HEALS     and t == HC.HOT_HEALS     then healType = "HoT"
                elseif HC.BOMB_HEALS    and t == HC.BOMB_HEALS    then healType = "Bomb"
                else                                                   healType = "Direct" end
            end

            -- Overheal: does the inbound amount exceed your missing health?
            local missing  = UnitHealthMax("player") - UnitHealth("player")
            local overheal = missing >= 0 and incoming > missing

            -- Stable swipe length: recompute only when the soonest land-time changes.
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
                icon           = icon,
                name           = spellNm or who or "Incoming Heal",
                amount         = math.floor(incoming + 0.5),
                rawAmount      = math.floor(raw + 0.5),
                hasAmount      = true,
                casterName     = who,
                casterGUID     = healerGUID,
                spellName      = spellNm,
                healType       = healType,
                modifier       = modifier,
                overheal       = overheal,
            }
            return true
        end
        aura_env.curEnd = nil
    end

    -- ===== D1: native fallback (amount only, no land-time / caster / type) =====
    local inc = UnitGetIncomingHeals and UnitGetIncomingHeals("player")
    if inc and inc > 0 then
        local missing  = UnitHealthMax("player") - UnitHealth("player")
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
            rawAmount      = math.floor(inc + 0.5),
            hasAmount      = true,
            casterName     = nil,
            casterGUID     = nil,
            spellName      = nil,
            healType       = nil,
            modifier       = 1,
            overheal       = missing >= 0 and inc > missing,
        }
        return true
    end

    return hide()
end
