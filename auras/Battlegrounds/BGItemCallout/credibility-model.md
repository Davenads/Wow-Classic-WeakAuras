# Credibility Model & Recommendations — BG Item Callout (19 WSG)

> Additional design context for the corroboration/evidence layer of `BGICHub`
> (`code/init.lua`). This is **not** implementation status — see `aura.md` for that.
> This file answers one question: *how do you make a BM-consume accusation in the 19
> bracket that the community actually trusts, and how far can this tool credibly go?*

---

## 1. The problem this tool exists to solve

In the 19 twink bracket there is a community "no-consumes" gentleman's ruleset (potions,
engineering gadgets, and — depending on the pocket meta — the AGM trinket break the
bracket's balance). Enforcement is **social**: name the offender, the community reacts.

The whole difficulty is **credibility**, not detection. Detection is trivial — the combat
log already tells every nearby client who used what. The hard part is that a chat line is
**trivially forgeable**:

```
[21:14:07] Swiftness Potion used by Xandrella
```

Anyone can type that. A screenshot of it proves nothing. So an accusation is only worth
anything if it carries evidence that a **lie can't cheaply reproduce**.

---

## 2. The hard ceiling: no cryptographic proof is possible here

Worth stating plainly so nobody chases a dead end:

- The WA is a **public, importable string**. Any secret baked into it (an HMAC key, a
  signing seed) is readable by anyone who imports it → it provides zero security.
- WoW's addon bus has **no PKI and no identity attestation** beyond the sender name.
- The custom-Lua sandbox blocks `loadstring`/`io`/file access, so a client can't even do
  local key storage cleanly, and couldn't verify a peer's identity if it did.

**Conclusion:** the ceiling of what this tool can achieve is **social proof by quantity of
independent, server-verified witnesses** — never mathematical proof. Design accordingly.
The goal is to make a report *tamper-evident and community-auditable*, not tamper-proof.

---

## 3. The one primitive that carries all the weight

Everything credible in this design rests on a single unspoofable fact:

> When a client receives a `CHAT_MSG_ADDON` message, the **`sender`** field is stamped by
> the **server**, not by the payload. A client cannot claim to be someone else.

(See `code/init.lua` → `NS.onAddon` — the payload's `name`/`reaction` are display-only; the
`sender` argument is the only trusted identity, and it's what `recordWitness` stores.)

This means forgery is **capped at "the number of distinct accounts you personally control
and have physically present in this BG."** You cannot inflate a witness count by replaying
messages or editing payloads — each fake still resolves to one real server-stamped account.

That single property is what turns "N witnesses saw it" from noise into evidence.

---

## 4. How the current evidence report works (recap of the shipped design)

Grouped by the event key `casterGUID | spellId | floor(serverTime / 4)` with ±1 bucket
tolerance (`NS.resolveKey`), so every witness's slightly-different detection time still
folds into one event. Witness set = **distinct server-stamped senders** (`NS.witnesses`).
On demand (self-whisper `bgic` / `bgic last`), `NS.buildReport` prints, per event:

```
[MM/DD/YY HH:MM:SS] Swiftness Potion (2379)
  caster: Xandrella (enemy)  guid=Player-...-...
  witnesses (3): Betty (you), Charlie, Dave   [EVIDENCE]
  key: Player-...-...|2379|<bucket>
```

- `[EVIDENCE]` = witness count `>= cfg.minWitnesses` (2) distinct server-verified accounts.
- `[info]` = a solo sighting (still true, just uncorroborated).
- Matches snapshot to `aura_env.saved.matches` (last 5) on leaving the BG, so a report
  survives to be pulled up / screenshotted afterward.

**Why this beats a typed accusation:** a fake chat line names nobody real. A report naming
several actual, server-verified witnesses is **checkable** — you can go ask the named
players "did you see this too?" The evidence is corroboration by quantity and independence
of witnesses.

---

## 5. Threat model

| Attack | Defense in place | Residual risk |
|---|---|---|
| Fabricated chat line ("X used a pot") | Report requires real server-stamped senders; a lie names nobody | None for the report itself; the lie is just a chat line with no evidence |
| Impersonating another witness | `sender` is server-stamped, unspoofable | None |
| Replaying / editing addon payloads to inflate count | Each message still resolves to one real `sender`; dedupe is by sender | None beyond the multibox case below |
| **Multiboxer** brings N of their own alts, all present, to manufacture N "witnesses" | Not blocked by the sender stamp alone | **Real.** This is the one genuine forgery vector. Mitigated by *witness-independence* signals (§6.3), not eliminated |
| Offender uses a consume nobody nearby is running the WA for | — | **False negative.** Adoption + range limited; unfixable in principle |
| Consume fires a spell ID we don't track (rank variants, SoD runes, new items) | — | **False negative / silent failure.** #1 practical bug class (§6.4) |
| Editing an extracted/pasted report after the fact | — | **Real for the artifact.** The trust anchor is the live witness list, not the file; only in-the-moment corroboration is authoritative (§7) |

---

## 6. Recommendations, ranked by credibility impact

### 6.1 Maximize adoption — the single biggest lever
Every additional person running the WA raises the witness count on *every* event, which:
- makes each genuine report stronger, and
- makes sock-puppeting **proportionally obvious** — 2 fake witnesses among 8 real ones is
  laughable; among 2 total it's decisive.

Design implications (mostly already honored):
- **Dead-simple install:** one import string, zero required config.
- **Quiet by default:** `reportMode="ondemand"` — no auto-spam. Spammy addons get
  uninstalled, which *shrinks the witness network* and weakens everyone's evidence. Keep
  any public auto-announce opt-in and evidence-tier-only.

### 6.2 Live confirmation at report time (upgrades deferred Phase 3c)
The strongest possible evidence is **"players present *right now* confirm they saw X,"**
not "I hold stored packets." A HELLO/census + confirm handshake at report time forces a
faker's alts to all be **present and actively responding**, a much higher bar than replaying
captured messages. This is a real credibility upgrade, not polish — worth prioritizing over
cosmetic Phase 3b work when live tuning becomes possible.

### 6.3 Report witness *independence*, not just count
A raw count is gameable by one multiboxer. Independence is not. Recommend enriching each
witness record (where cheaply available at witness time) with:
- **Faction** — cross-faction corroboration is near-ironclad: an *enemy* has zero incentive
  to fabricate evidence *for* you.
- **Guild** — distinct guilds ⇒ far less plausible collusion.

Then the report reads its own strength honestly:
- `witnesses (4): 2 factions, 3 guilds` → strong.
- `witnesses (3): same guild, same faction` → weak / self-suspicious.

Optional stronger tier: `[STRONG]` = `>= 2` witnesses spanning **both** factions;
`[EVIDENCE]` = `>= 2` any; `[info]` = solo. This directly *exposes* the multibox vector
(§5) instead of pretending the count defeats it.

> Note: faction/guild would need to be captured at witness time from the caster/witness
> context and carried in the ledger; the payload is `<=255` chars, so keep additions terse
> (a single faction char is cheap; guild is optional and larger). This is a future-phase
> enhancement, called out here as a design direction — not a request to implement now.

### 6.4 Spell-ID coverage discipline — the #1 reason these tools silently fail
A missing ID means the offender is invisible and the tool looks broken/partial, which
**erodes community trust** faster than anything. Maintain `NS.trackedItems` against the live
19 meta and mind Classic's ID rules:
- **Ranked spells are separate IDs** in Classic — track *all* rank IDs or match by **name**.
- **SoD rune abilities have their own IDs** — look them up on `wowhead.com/classic/`, not
  Retail DB.
- Candidate additions already flagged in `aura.md` notes: **Free Action Potion (6615)**,
  stun grenades (Thermal/Iron), **Net-o-Matic (13099)**. Verify each ID and its actual
  logged `_CAST_SUCCESS` spellId in-game before shipping (see the Magic Dust 1090 caveat).

### 6.5 Conservative tagging + a recognizable, versioned format
False positives cost trust disproportionately. Keep the evidence bar conservative, keep the
report format stable and version-stamped so the community recognizes a genuine artifact at a
glance (the payload already carries `NS.schema`; consider a visible format version on the
report header too).

### 6.6 Keep the reputation layer OUT of the WA (community-side only)
Do **not** bake a trusted-witness whitelist into the WA — it's public and would be gamed.
The WA should emit **raw, auditable witness names**; the community maintains reputation
(a Discord trusted-list) as a *social* layer on top. The tool's job is honest data; humans
do the judgment.

---

## 7. On the SavedVariables extractor tool

**Recommendation: build it, but scope it correctly.**

- **What it is:** an author/maintainer-side Node script that reads WoW's
  `WTF\Account\<ACCOUNT>\SavedVariables\WeakAuras.lua`, finds this aura's `saved.matches`,
  and dumps them into diffable / Discord-postable files in-repo.
- **What it's *for*:** turning ephemeral in-game reports into a durable, shareable archive
  (offender history over time, easy posting, version control).
- **What it is *not*:** a credibility mechanism. An extracted text file is exactly as
  editable as a screenshot. It faithfully transcribes the witness list; **the trust still
  lives in that witness list**, which the community verifies by asking the named players.
- **Boundary:** it lives in `tools/`, never in the distributed WA, and it only *reads*
  SavedVariables — the in-game addon cannot and should not write files itself (sandbox
  blocks `io`).

So: yes to the extractor as a publishing convenience; no illusion that it hardens evidence.

---

## 8. Honest limitations to publish alongside the tool

Transparency is itself a trust builder — stating the limits makes people believe the parts
that *do* hold:

1. **Range + adoption bound detection.** Only players in combat-log range who also run the
   WA can witness. Low adoption ⇒ many real offenses go uncorroborated (`[info]`, not
   `[EVIDENCE]`). This is a *false-negative* tool, not a dragnet.
2. **A determined multiboxer can manufacture witnesses** up to the number of alts they have
   present. Independence signals (§6.3) expose this; they don't eliminate it.
3. **Any text artifact is editable.** Only *live, in-the-moment* corroboration is
   authoritative. Treat a pasted/extracted report as a *pointer to witnesses to ask*, not as
   self-proving.
4. **Identity is per-character.** GUID is stable for a character, but faction changes /
   remakes complicate long-term offender tracking. The WA reports what it sees; persistent
   identity is a community concern.
5. **Not tamper-proof — tamper-*evident by audit*.** The design's honesty is the point.

---

## 9. Bottom line

The corroboration-by-independent-server-verified-witnesses model is the correct primitive
and is near the theoretical ceiling for a public WA. Push credibility in this order:

1. **Adoption** (witness density).
2. **Live confirmation at report time** (deferred Phase 3c).
3. **Witness-independence signals** (faction/guild), with an optional cross-faction
   `[STRONG]` tier.
4. **Spell-ID coverage discipline** (don't silently fail).

The SavedVariables extractor is a useful *publishing* convenience, not a trust mechanism.
And be radically transparent about the limits — that honesty is precisely what makes the
community trust this over a hand-typed accusation.
