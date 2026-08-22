-- WSG Callout Bars — Actions → On Init (per-icon click button)
-- Normal click: this icon's enemy-FC location callout.
-- Ctrl+click:   OUR flag carrier's status (name + HP, plus mana if a mana class).
-- Shift+click:  ENEMY carrier status (HP; mana & CC when a token is readable) — sent as a
--               RAID_WARNING if you're group lead/assist, otherwise to /bg.
-- Cross-icon state (both carriers, bus-received enemy HP, helpers) lives on the named global
-- frame WSGCalloutHub (children don't share aura_env); created once by whichever icon loads first.
if not WSGCalloutHub then
    local NS = CreateFrame("Frame", "WSGCalloutHub")

    local function strip(n) return n and n:gsub("%-.*$", "") or n end
    NS.strip = strip

    -- Effective faction (mercenary-aware): merc buffs 81748/81744 flip your side. Guarded for
    -- Classic Era (no merc mode / possibly nil spell info) -> UnitFactionGroup fallback.
    local function myFaction()
        if GetSpellInfo and AuraUtil and AuraUtil.FindAuraByName then
            local a = GetSpellInfo(81748)
            local h = GetSpellInfo(81744)
            if a and AuraUtil.FindAuraByName(a, "player") then return "Alliance" end
            if h and AuraUtil.FindAuraByName(h, "player") then return "Horde" end
        end
        return UnitFactionGroup("player")
    end
    NS.myFaction = myFaction

    -- Relevant PvP CC (lowercase enUS names) — union of hard CC + snares. enUS only.
    local CC_WATCH = {
        ["hammer of justice"]=true, ["kidney shot"]=true, ["cheap shot"]=true, ["bash"]=true,
        ["concussion blow"]=true, ["intimidation"]=true, ["war stomp"]=true, ["pounce"]=true,
        ["frost nova"]=true, ["entangling roots"]=true, ["counterattack"]=true, ["frostbite"]=true,
        ["polymorph"]=true, ["freezing trap effect"]=true, ["blind"]=true, ["gouge"]=true,
        ["sap"]=true, ["fear"]=true, ["psychic scream"]=true, ["seduction"]=true,
        ["howl of terror"]=true, ["scatter shot"]=true, ["intimidating shout"]=true,
        ["wyvern sting"]=true, ["repentance"]=true, ["scare beast"]=true,
        ["hamstring"]=true, ["crippling poison"]=true, ["wing clip"]=true, ["concussive shot"]=true,
        ["frost shock"]=true, ["curse of exhaustion"]=true, ["piercing howl"]=true, ["mind flay"]=true,
        ["cone of cold"]=true, ["blast wave"]=true, ["chilled"]=true, ["frostbolt"]=true,
        ["earthbind"]=true, ["dazed"]=true, ["improved hamstring"]=true, ["daze"]=true,
    }

    -- WSG flag-carry buff spell IDs (wowhead.com/classic):
    --   23333 Warsong Flag    = the HORDE flag    (held by an Alliance carrier)
    --   23335 Silverwing Flag = the ALLIANCE flag (held by a Horde carrier)
    local FLAG_WARSONG, FLAG_SILVERWING = 23333, 23335

    -- Who carries each flag (realm-stripped). Maintained from WSG system messages.
    NS.fc = { alliance = nil, horde = nil }
    NS.recvHP, NS.recvTS = nil, 0     -- enemy carrier HP received over the WSGFCNamesHP bus

    -- Passive receiver on the community / EnemyFCAnnouncer HP bus (no broadcast, no ticker):
    -- lets Shift show enemy HP even when nobody is targeting the carrier.
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix("WSGFCNamesHP")
    end

    NS:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
    NS:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    NS:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    NS:RegisterEvent("CHAT_MSG_ADDON")
    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
        if event == "PLAYER_ENTERING_WORLD" then
            NS.fc.alliance, NS.fc.horde = nil, nil
            NS.recvHP, NS.recvTS = nil, 0
            return
        end
        if event == "CHAT_MSG_ADDON" then
            if a1 ~= "WSGFCNamesHP" or type(a2) ~= "string" then return end
            local nm = a2:match("^(.*)@")
            local hp = tonumber(a2:match("@(.+)$") or "")
            local efc = NS.enemyFCName and NS.enemyFCName()
            if nm and hp and efc and strip(nm) == efc then
                NS.recvHP, NS.recvTS = hp, GetTime()
            end
            return
        end
        -- CHAT_MSG_BG_SYSTEM_* : a1 = message text
        local msg = a1
        if type(msg) ~= "string" then return end
        local fc = NS.fc
        local faction = msg:match("The (%a+) [Ff]lag")
        local picked = msg:match("[Ff]lag was picked up by (.-)!")
        if picked and faction then
            picked = strip(picked)
            if faction == "Alliance" then
                fc.alliance = picked
            elseif faction == "Horde" then
                fc.horde = picked
            end
        elseif msg:find("was dropped by") or msg:find("was returned") then
            if faction == "Alliance" then
                fc.alliance = nil
            elseif faction == "Horde" then
                fc.horde = nil
            end
        elseif msg:find("[Cc]aptured") or msg:find("[Ff]lags are reset")
            or msg:find("flags are now placed") or msg:find("battle has begun") then
            fc.alliance, fc.horde = nil, nil
        end
    end)

    -- Scan our OWN group for whoever holds the ENEMY flag buff. Own-team auras are always
    -- readable across the whole map, so this finds OUR carrier with zero dependence on chat
    -- parsing, message-format drift, or zone-in timing (the FlagCarriers aura's documented
    -- "optional enhancement"). Matches by spellId (UnitAura's 10th return, locale-independent).
    -- Returns (unit, strippedName) or nil.
    local function ourFCScan()
        local mine = myFaction()
        local wantID = (mine == "Alliance") and FLAG_WARSONG
                    or (mine == "Horde") and FLAG_SILVERWING or nil
        if not wantID then return nil end
        local units = { "player" }
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, (GetNumGroupMembers() or 0) do units[#units + 1] = prefix .. i end
        for _, u in ipairs(units) do
            if UnitExists(u) then
                for i = 1, 40 do
                    local nm, _, _, _, _, _, _, _, _, sid = UnitAura(u, i, "HELPFUL")
                    if not nm then break end
                    if sid == wantID then return u, strip(UnitName(u)) end
                end
            end
        end
        return nil
    end
    NS.ourFCScan = ourFCScan

    -- OUR carrier = teammate holding the ENEMY flag (opposite of our effective faction).
    -- Prefer the live raid-aura scan; fall back to the chat-tracked name if the scan misses.
    function NS.ourFCName()
        local _, name = ourFCScan()
        if name then return name end
        local mine = myFaction()
        if mine == "Alliance" then return NS.fc.horde end
        if mine == "Horde" then return NS.fc.alliance end
        return nil
    end

    -- ENEMY carrier = the enemy holding OUR flag.
    function NS.enemyFCName()
        local mine = myFaction()
        if mine == "Alliance" then return NS.fc.alliance end
        if mine == "Horde" then return NS.fc.horde end
        return nil
    end

    -- Resolve a FRIENDLY name to a live token (raid/party health & power always readable).
    local function resolveUnit(name)
        if not name then return nil end
        name = strip(name)
        if strip(UnitName("player")) == name then return "player" end
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, (GetNumGroupMembers() or 0) do
            local u = prefix .. i
            if UnitExists(u) and strip(UnitName(u)) == name then return u end
        end
        return nil
    end
    NS.resolveUnit = resolveUnit

    -- Find a live HOSTILE token for a name: own target/focus/mouseover, then nameplates (HP
    -- only), then raidNtarget (any teammate's target). nil if nobody can currently see them.
    local function findEnemyUnit(name)
        if not name then return nil end
        name = strip(name)
        local function ok(u)
            return UnitExists(u) and strip(UnitName(u)) == name and UnitCanAttack("player", u)
        end
        for _, u in ipairs({ "target", "focus", "mouseover" }) do
            if ok(u) then return u end
        end
        for i = 1, 40 do
            if ok("nameplate" .. i) then return "nameplate" .. i end
        end
        for i = 1, 40 do
            if ok("raid" .. i .. "target") then return "raid" .. i .. "target" end
        end
        return nil
    end
    NS.findEnemyUnit = findEnemyUnit

    -- Active CC on a unit (name + remaining seconds), matched vs CC_WATCH, capped at 3.
    local function scanCC(u)
        local out = {}
        for i = 1, 40 do
            local nm, _, _, _, _, expiry = UnitAura(u, i, "HARMFUL")
            if not nm then break end
            if CC_WATCH[nm:lower()] then
                local remain = (expiry and expiry > 0) and (expiry - GetTime()) or nil
                if remain and remain > 0 then
                    out[#out + 1] = nm .. " " .. math.floor(remain + 0.5) .. "s"
                else
                    out[#out + 1] = nm
                end
                if #out >= 3 then break end
            end
        end
        return out
    end

    -- " — Name 47% HP, 80% mana" for OUR carrier (mana omitted for rage/energy classes).
    function NS.FCSuffix()
        local u, name = ourFCScan()          -- live scan gives unit + name together
        if not name then                      -- scan missed -> chat-tracked fallback name
            name = NS.ourFCName()
            u = name and resolveUnit(name) or nil
        end
        if not name then return " — FC unknown" end
        if not u then return " — " .. name .. " (out of group?)" end
        local out = " — " .. name
        local hx = UnitHealthMax(u)
        if hx and hx > 0 then
            out = out .. " " .. math.floor(UnitHealth(u) / hx * 100 + 0.5) .. "% HP"
        end
        if UnitPowerType and UnitPowerType(u) == 0 then
            local mx = UnitPowerMax(u, 0)
            if mx and mx > 0 then
                out = out .. ", " .. math.floor(UnitPower(u, 0) / mx * 100 + 0.5) .. "% mana"
            end
        end
        return out
    end

    -- ENEMY carrier status ("Name 34% HP, 12% mana, Hamstring 4s") or nil if no enemy is
    -- carrying. HP prefers a live read; else falls back to a fresh bus value (marked "~").
    function NS.EFCStatus()
        local name = NS.enemyFCName()
        if not name then return nil end
        local u = findEnemyUnit(name)
        local hpStr, extra = nil, {}
        if u then
            local hx = UnitHealthMax(u)
            if hx and hx > 0 then
                hpStr = math.floor(UnitHealth(u) / hx * 100 + 0.5) .. "% HP"
            end
            if UnitPowerType and UnitPowerType(u) == 0 then
                local mx = UnitPowerMax(u, 0)
                if mx and mx > 0 then
                    extra[#extra + 1] = math.floor(UnitPower(u, 0) / mx * 100 + 0.5) .. "% mana"
                end
            end
            local cc = scanCC(u)
            for i = 1, #cc do extra[#extra + 1] = cc[i] end
        end
        if not hpStr then
            local now = GetTime()
            if NS.recvHP and (now - (NS.recvTS or 0)) < 5 then
                hpStr = "~" .. math.floor(NS.recvHP * 100 + 0.5) .. "% HP"
            end
        end
        local body = name
        if hpStr then body = body .. " " .. hpStr end
        if #extra > 0 then body = body .. ", " .. table.concat(extra, ", ") end
        if not hpStr and #extra == 0 then body = body .. " (no read)" end
        return body
    end
end

-- ── this icon's click button ──────────────────────────────────────────────────
local NS = WSGCalloutHub
local ENEMY_MSG = "EFC Is Horde Tunnel"
local OURFC_MSG = "Our FC Is Horde Tunnel"
local LOC_LABEL = "Horde Tunnel"

local r = aura_env.region
if not r.btn_ann then
    local b = CreateFrame("Button", nil, r, "SecureActionButtonTemplate")
    b:SetAllPoints()
    b:RegisterForClicks("AnyUp")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b.c = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.c:SetAllPoints()
    r.btn_ann = b
end

r.btn_ann:SetScript("OnClick", function(self)
    if not NS then
        SendChatMessage(ENEMY_MSG, "INSTANCE_CHAT")
        return
    end
    if IsControlKeyDown() then
        SendChatMessage(OURFC_MSG .. NS.FCSuffix(), "INSTANCE_CHAT")
    elseif IsShiftKeyDown() then
        local status = NS.EFCStatus()
        if not status then
            SendChatMessage(ENEMY_MSG, "INSTANCE_CHAT")   -- no enemy carrier -> plain location
            return
        end
        if GetTime() - (NS.lastAnn or 0) < 3 then return end   -- throttle enriched sends
        NS.lastAnn = GetTime()
        local body = (LOC_LABEL ~= "") and ("EFC " .. LOC_LABEL .. " — " .. status)
                                        or  ("EFC " .. status)
        local canWarn = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        SendChatMessage(body, canWarn and "RAID_WARNING" or "INSTANCE_CHAT")
    else
        SendChatMessage(ENEMY_MSG, "INSTANCE_CHAT")
    end
end)
