-- Behavior tests for the BGICHub corroboration engine (Phase 3a).
-- Runs after bgic_stubs.lua + init.lua in the same Lua state.

local pass, fail = 0, 0
local function ok(cond, msg)
    if cond then pass = pass + 1; print("  ok  " .. msg)
    else fail = fail + 1; print("  FAIL " .. msg) end
end
local function eq(a, b, msg)
    ok(a == b, msg .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")")
end

local H = BGICHub
assert(H, "BGICHub did not initialize")

-- Drivers ---------------------------------------------------------------------
local function fireCLE(sub, guid, name, flags, spellId, now)
    _now = now
    _cle = { 0, sub, false, guid, name, flags, 0, "", 0, "", "", spellId }
    H._on(H, "COMBAT_LOG_EVENT_UNFILTERED")
end
local function fireAddon(payload, sender)
    H._on(H, "CHAT_MSG_ADDON", "BGIC", payload, "INSTANCE_CHAT", sender)
end
local function keyCount(guid, spellId, bucket)
    return H.witnessCount(guid .. "|" .. spellId .. "|" .. bucket)
end

local FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY   -- 16
local HOSTILE  = COMBATLOG_OBJECT_REACTION_HOSTILE    -- 64
local MINE     = COMBATLOG_OBJECT_AFFILIATION_MINE    -- 1

-- Fresh match -----------------------------------------------------------------
_instanceType = "pvp"
H._on(H, "PLAYER_ENTERING_WORLD")
resetSinks()

print("T1 enemy first sighting -> event + self-witness + one broadcast")
fireCLE("SPELL_CAST_SUCCESS", "E1", "Xandrella-Whitemane", HOSTILE, 2379, 100) -- bucket 25
eq(keyCount("E1", 2379, 25), 1, "witnesses after own sighting")
eq(#_sent, 1, "exactly one broadcast")
if _sent[1] then eq(_sent[1].payload, "1|EVT|E1|2379|100|e|Xandrella", "broadcast payload (name stripped, reaction 'e')") end
eq(#_chat, 0, "enemy cast produces no ally chat")

print("T2 duplicate enemy cast same bucket -> send-once (no new broadcast)")
fireCLE("SPELL_CAST_SUCCESS", "E1", "Xandrella-Whitemane", HOSTILE, 2379, 101) -- still bucket 25
eq(keyCount("E1", 2379, 25), 1, "still one witness (self, deduped)")
eq(#_sent, 1, "still one broadcast (seen-key suppression)")

print("T3 incoming attestation, +1 bucket -> merges via -1 tolerance, count 2")
fireAddon("1|EVT|E1|2379|104|e|Charlie-Whitemane", "Charlie-Whitemane") -- t=104 -> bucket 26
eq(keyCount("E1", 2379, 25), 2, "remote witness merged into bucket 25")
eq(#_sent, 1, "receiving does not broadcast")

print("T4 self cast (AFFILIATION_MINE) -> ignored entirely")
local sentBefore, chatBefore = #_sent, #_chat
fireCLE("SPELL_CAST_SUCCESS", "SELF", "Me", MINE + FRIENDLY, 2379, 120)
eq(keyCount("SELF", 2379, 30), 0, "no event recorded for self")
eq(#_sent, sentBefore, "no broadcast for self")
eq(#_chat, chatBefore, "no ally announce for self")

print("T5 ally consumable (Rocket Boots) -> corroborated + ally announce")
resetSinks()
fireCLE("SPELL_CAST_SUCCESS", "A1", "Buddy-Whitemane", FRIENDLY, 8892, 200) -- bucket 50
eq(keyCount("A1", 8892, 50), 1, "ally sighting recorded")
eq(#_sent, 1, "ally sighting broadcast")
if _sent[1] then ok(_sent[1].payload:find("|a|", 1, true) ~= nil, "broadcast reaction char 'a' for ally") end
eq(#_chat, 1, "ally announce emitted")
if _chat[1] then
    ok(_chat[1].msg:find("Rocket Boots", 1, true) ~= nil, "ally announce names the item")
    ok(_chat[1].msg:find("(ally)", 1, true) ~= nil, "ally announce carries (ally) tag")
    eq(_chat[1].chan, "INSTANCE_CHAT", "ally announce routed to BG chat")
end

print("T6 ally AGM trinket -> corroborated but NOT announced (excluded)")
resetSinks()
fireCLE("SPELL_CAST_SUCCESS", "A2", "Buddy2-Whitemane", FRIENDLY, 23506, 300) -- bucket 75
eq(keyCount("A2", 23506, 75), 1, "AGM ally sighting is still corroborated")
eq(#_sent, 1, "AGM ally sighting broadcast")
eq(#_chat, 0, "AGM is excluded from ally announces")

print("T7 untracked spellId -> ignored")
resetSinks()
fireCLE("SPELL_CAST_SUCCESS", "E9", "Nobody", HOSTILE, 6615, 400)
eq(#_sent, 0, "untracked cast not broadcast")
eq(#_chat, 0, "untracked cast not announced")

print("T8 incoming addon, wrong schema -> rejected")
fireAddon("2|EVT|E1|2379|100|e|Faker", "Faker-Whitemane")
eq(keyCount("E1", 2379, 25), 2, "schema-mismatch attestation ignored")

print("T9 incoming addon, non-EVT kind -> rejected")
fireAddon("1|HELLO|whatever", "Faker-Whitemane")
eq(keyCount("E1", 2379, 25), 2, "non-EVT payload ignored")

print("T10 incoming addon, untracked spell -> rejected")
fireAddon("1|EVT|Z1|6615|100|e|Faker", "Faker-Whitemane")
eq(keyCount("Z1", 6615, 25), 0, "untracked-spell attestation ignored")

print("T11 duplicate sender for one event -> counted once")
fireAddon("1|EVT|E1|2379|100|e|Dave", "Dave-Whitemane")
eq(keyCount("E1", 2379, 25), 3, "distinct sender Dave added (now 3)")
fireAddon("1|EVT|E1|2379|100|e|Dave", "Dave-Whitemane")
eq(keyCount("E1", 2379, 25), 3, "same sender not double-counted")

print("T12 PLAYER_ENTERING_WORLD wipes the per-match ledger")
H._on(H, "PLAYER_ENTERING_WORLD")
eq(#H.log, 0, "event log emptied on zone-in")
eq(next(H.witnesses), nil, "witness sets emptied on zone-in")
eq(next(H.seen), nil, "seen/broadcast set emptied on zone-in")

print("T13 combat-log watch gated to pvp instances")
_instanceType = "none"; H.refreshZone()
eq(H.registered["COMBAT_LOG_EVENT_UNFILTERED"], nil, "unarmed outside a BG")
_instanceType = "pvp"; H.refreshZone()
eq(H.registered["COMBAT_LOG_EVENT_UNFILTERED"], true, "re-armed inside a BG")

-- ===== Phase 4: reporting =====================================================
-- Fresh match + fresh saved history.
_instanceType = "pvp"
H._on(H, "PLAYER_ENTERING_WORLD")
wipe(aura_env.saved.matches)
resetSinks()
-- Build: one enemy event with 2 witnesses (evidence), one ally event solo (info).
fireCLE("SPELL_CAST_SUCCESS", "E1", "Xandrella-WM", HOSTILE, 2379, 1000)   -- self witness
fireAddon("1|EVT|E1|2379|1001|e|Charlie-WM", "Charlie-WM")                 -- 2nd witness
fireCLE("SPELL_CAST_SUCCESS", "A1", "Buddy-WM", FRIENDLY, 8892, 1000)      -- ally, solo

print("T14 live report classifies evidence vs info and marks self")
local liveRec = { t0 = 1000, t1 = _now, events = H.collectEvents() }
eq(#liveRec.events, 2, "two events collected from the live ledger")
local liveText = table.concat(H.buildReport(liveRec, "live"), "\n")
ok(liveText:find("2 event(s)", 1, true) ~= nil, "report header counts events")
ok(liveText:find("[EVIDENCE]", 1, true) ~= nil, "2-witness enemy event tagged EVIDENCE")
ok(liveText:find("[info]", 1, true) ~= nil, "solo ally event tagged info")
ok(liveText:find("(you)", 1, true) ~= nil, "own witness entry marked (you)")
ok(liveText:find("guid=E1", 1, true) ~= nil, "caster GUID present in report")
ok(liveText:find("Charlie", 1, true) ~= nil, "remote witness named in report")

print("T15 PLAYER_ENTERING_WORLD snapshots the match then wipes the ledger")
_now = 1500
H._on(H, "PLAYER_ENTERING_WORLD")
eq(#aura_env.saved.matches, 1, "one match snapshotted to saved")
eq(#aura_env.saved.matches[1].events, 2, "snapshot preserved both events")
eq(#H.collectEvents(), 0, "live ledger wiped after snapshot")

print("T16 'last' report renders the saved match")
local lastRec = aura_env.saved.matches[#aura_env.saved.matches]
local lastText = table.concat(H.buildReport(lastRec, "last"), "\n")
ok(lastText:find("[EVIDENCE]", 1, true) ~= nil, "saved match still shows EVIDENCE tag")

print("T17 saved history is capped at 5 matches (ring buffer)")
wipe(aura_env.saved.matches)
for i = 1, 6 do
    H._on(H, "PLAYER_ENTERING_WORLD")            -- wipe (empty; no-op snapshot)
    fireCLE("SPELL_CAST_SUCCESS", "G" .. i, "Foe" .. i, HOSTILE, 2379, 2000 + i * 10)
    H._on(H, "PLAYER_ENTERING_WORLD")            -- snapshot this 1-event match
end
eq(#aura_env.saved.matches, 5, "history capped to the last 5 matches")

print("T18 self-whisper debounce absorbs the WHISPER + INFORM double-fire")
H.lastCmd = nil
_clock = 10.0; H.onWhisper("bgic"); eq(H.lastCmd, 10.0, "first command accepted")
_clock = 10.2; H.onWhisper("bgic"); eq(H.lastCmd, 10.0, "duplicate within 0.5s suppressed")
_clock = 11.0; H.onWhisper("bgic"); eq(H.lastCmd, 11.0, "command after window accepted")

print("T19 only self-whispers trigger; 'bgic clear' wipes saved reports")
_clock = 100; H.lastCmd = nil
H._on(H, "CHAT_MSG_WHISPER_INFORM", "bgic clear", "Griefer-WM")   -- not self
eq(#aura_env.saved.matches, 5, "non-self whisper ignored")
_clock = 101
H._on(H, "CHAT_MSG_WHISPER_INFORM", "bgic clear", "Me")          -- self
eq(#aura_env.saved.matches, 0, "self 'bgic clear' cleared saved reports")

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then error(fail .. " test(s) failed") end
