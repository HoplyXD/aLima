# aLima — Story Bible

> **Status: finalized on paper — pending two gates.** This document locks the game's narrative —
> premise, loop framing, all character routes beat-by-beat with dialogue, the cross-route item web,
> and every ending — *before* any of it is wired into code. Implementation (Phase 15/16/19) follows
> this document. Nothing here is shipped until:
>
> - [ ] **Team read-through and approval** of the finalized flow (do not self-certify).
> - [ ] **Native-speaker review** of every Hiligaynon / Kinaray-a line (CLAUDE.md §4-Q, ASSET-R4).
>   All dialect text in this document — carried-over *and* newly drafted — is working-draft quality.
>
> **Authority order** is unchanged: `CLAUDE.md` §4 invariants → `README.md` GDD → `docs/PRD.md`
> → `docs/phase-task.md`. This bible sits below the PRD and above the raw data: it is the complete
> script-level source for narrative, built on the structural decisions of
> `docs/route-dialogue-compendium.md` (v2). Where existing `data/routes/routes.json` text conflicts
> with an invariant, the conflict is **flagged in §12**, never silently resolved here or in data.
>
> **Markup convention.** Dialogue is quoted with the in-game BBCode intact: `[i]…[/i]` is a stage
> direction, `[b]Note saved:[/b]` / `[b]Lead saved:[/b]` are journal-note system lines. Lines
> carried over from `data/routes/routes.json` are **verbatim**. Newly authored material is tagged
> **[NEW]** and is review-pending like everything else.

---

## 1. Premise, Theme & Tone

### 1.1 Premise

The player inherits the family junk shop in a Western Visayas barangay — and, with it, a worn
journal bound in **Chronos Emulsion**, a substance that sits outside the flow of time. It belonged
to **Yuyu**, the player's grand-uncle: a *Chronographer*, a scholar of the memories held inside
objects. Yuyu vanished while trying to restore a regional heritage object — the **Master Artifact**
— which shattered into **five fragments**. Before he disappeared, he entrusted one fragment to each
of five people he trusted.

The journal now holds the shop and its surroundings in a repeating **five-day loop**. Set into its
first page is an empty case shaped for five fragments. Until the case is filled, the week cannot
truly end. New writing sometimes appears in the journal on its own — Yuyu, wherever he is,
reconstructing his past one cleared page at a time.

**Lola** — the player's grandmother, Yuyu's younger sister — ran this shop before the player. She
is gone now, but her voice frames the whole game: it was Lola who used to say the word *alima* the
way the game means it. *(Kinship canonized here for the first time — see §12, decision note N1.)*

### 1.2 The Alima motif

*Alima* is the Kinaray-a word for **hand**. Hidden inside it is *lima* — **five**. Five days in
every loop. Five fragments of one artifact. Five people Yuyu trusted. The whole story is the motif
enacted: history is not stored, it is **passed forward, hand to hand** — from a stranger's basket
to the player's workbench, from a junk heap to a city's museum, from a vanished uncle to a stubborn
niece or nephew. Every route ends the same way at its core: someone who has been holding a piece of
the past too tightly finally opens their hand.

Yuyu's own rule — spoken back to the player by every character who learned from him — is the
narrative engine of the mechanics: **no one may simply hand you your own history.** You must find
it, clean it, and understand it with your own hands. (This is invariant §4-B worn as theme.)

### 1.3 Tone & voice

Cozy, golden-hour, unhurried. Grief is present in every route but handled gently — the game's
emotional register is *pagpadayon*: carrying on, tending, mending. Humor is small and human (Ayla's
bravado, Maverick's theatre, Yuyu returning mid-sentence). Nothing screams; the loudest thing in
the game is a heartbeat under a junk pile. Dialogue is short, concrete, and physical — people talk
while their hands are busy.

### 1.4 Language & cultural framing

- English UI; **Hiligaynon and Kinaray-a lines are flavor and heart**, always subtitled, always
  translated in context. Newly drafted lines in this document deliberately keep dialect *lighter*
  than the carried-over scenes, reusing patterns already present in the authored text, to minimize
  the native-speaker correction surface. **Every dialect line is review-pending** (§4-Q).
- **Folklore is framed as folklore** (§4-L). Family sayings are attributed to the family member,
  not to history. The scanner's "facts" derive from verified records only. The **Code of
  Kalantiaw** is excluded as a source of fact; Maragtas-adjacent material may flavor lore only as
  oral tradition, explicitly framed as such.
- "Yuyu" is treated as a **family nickname**, not a dialect word.
- The Master Artifact is **not yet locked** (decision D1). Everywhere this document touches the
  artifact or a fragment, the object is described generically — "a worked piece, smaller than a
  fist, older than it should be" — and marked with *(artifact-agnostic — D1)*.

---

## 2. How the Story Sits on the Gameplay Loop

### 2.1 One day (07:00–20:00; Day 1 = Monday … Day 5 = Friday)

| Clock | Space | What happens | Where story lives |
|---|---|---|---|
| 07:00 | Inside | Shop opens; journal on the bench | Journal notes, new static-cleared ink |
| Morning | Outside | **Forage** the scrapyard; **hand off** scrap to Ayla (~1 hr sort) | Ayla's routine banter (§6.3); Cultural Echo hunt if a fragment is `RELEASED` |
| 08:00–11:00 (D3/5), 15:00–17:00 (D1) | Inside | **Sam's** visit window | Route beats §7 |
| Midday | Inside | Ayla knocks with the sorted **delivery** → **triage** | Delivery/triage flavor |
| 12:00–14:00 (D1/3/5) | Inside | **Nang Shine's** window | Route beats §4 |
| 13:00–14:00 (D2/4/5) | Inside | **Nong Lave's** window | Route beats §5 |
| Afternoon | Inside | **Restore** (3D bench) → **scan & judge** → **decide** (sell / return / museum / journal) | Beat objects flow through restoration + the RETURN disposition (DISP-R3); Temporal Echoes fire at the bench |
| 17:00–18:00 (daily) +07:00–09:00 (D5) | Inside | **Mr. Maverick's** window | Route beats §8 |
| Evening → 20:00 | Inside | Evening summary, journal, upkeep | Ending vignettes land here |

An unanswered knock is **consumed** — the visitor moves on, and that route may close for the loop
(ROUTE-R6). The clock runs in both spaces, so a morning spent hunting an Echo in the yard is a
morning Sam may knock unanswered.

### 2.2 The five-day loop

At the end of Day 5 the week folds back to Day 1. In-fiction the cause is the journal itself: the
Chronos Emulsion anchors the surrounding days until its case is filled. The pacing contract
(ROUTE-R7 / D13): **one fragment-holder route completes per loop** — the windows conflict and
Ayla's completion has a multi-step gate — so a full playthrough is **≈5 loops**, roughly one route
and one seated fragment per loop, ending in the loop where the fifth fragment seats (§10).

Hunting and seating an already-`RELEASED` fragment in the yard is a **parallel activity** — it
never competes with the one-route-per-loop budget. A typical good loop = *finish one new person,
seat one old fragment.*

### 2.3 What persists — the split as narrative device

| The week erases (reset) | The journal keeps (persists) |
|---|---|
| Money, stock, listings, unfinished requests, daily events | Journal entries, learned techniques, scanned records, museum entries |
| | Story clues, unlocked dialogue, **leads** (Ayla's lead to Sam, the Safe code, the drawer clue) |
| | **Seated fragments** — permanent, never re-hunted |

Narratively: the world forgets, **people and the journal remember**. Characters keep their
route progress across loops because their scenes live in the journal's persistent record — the
player is not re-earning trust each week; they are continuing conversations the week keeps trying
to erase. (Invariant §4-A, honored exactly.)

### 2.4 How a fragment actually reaches the player — release, hunt, seat

No character ever hands over a fragment (§4-B). The in-fiction device, used consistently by all
five routes:

> **Every keeping-place is already in the yard.** Years ago, each holder's fragment — tucked in a
> tin, a toolbox, a crate, a lot of house-clearance salvage — drifted into the junk stream, the
> way lost things in this barangay always drift toward the yard. The holders know *of* it; none of
> them can walk to it. **Completing a route is the moment the holder finally tells the whole
> truth** — what they were given, what it was hidden in, how it was lost — and that telling is
> what lets the Chronos-bound journal begin to *listen* for it. From that day the yard sounds
> different: the Cultural Echoes rise (Hum → Melody → Voice → Heartbeat), and somewhere out there
> an utterly ordinary object is carrying something extraordinary.

Mechanically this is the fragment lifecycle `LOCKED → RELEASED → SEATED` (§4-B): route completion
sets `RELEASED`; the **Spawn Director** promotes an ordinary openable to *carrier* and hides it —
somewhere new every loop, because the heaps reshuffle with each reset while the journal keeps
listening (§4-C, §4-H, PRD §12). The player tracks it by ear, carries it inside, **cleans** it,
**opens** it (the two-stage gate, §4-D), and the fragment seats in the journal's case — permanent,
silent, done (§4-I).

### 2.5 Where the AI systems sit in the fiction

The scanner **suggests** and the player judges (§4-G) — in-story, the player is learning Yuyu's
discipline: never let the tool render the verdict. The Portal Unlock after each seating reveals a
**verified real-world fact** about the region's heritage (fact cards authored in Phase 16 against
`docs/sources/`; artifact-agnostic until D1). Gold finds and the Master Artifact go to the online
museum; Purple-and-below live in the journal (§4-F).

---

## 3. Cast

| Character | Route id | Space | Fragment | Reward(s) | Ending? |
|---|---|---|---|---|---|
| **Nang Shine** — the Elderly Auntie | `auntie` | Inside, Days 1/3/5, 12:00–14:00 | `fragment_01` | `safe_code`, `drawer_clue`; **unlocks Nong Lave** | Yes (§10.1) |
| **Nong Lave** — the Local Artisan | `artisan` | Inside, Days 2/4/5, 13:00–14:00 | `fragment_02` | `delicate_tool` (fragile-object access) | Yes (§10.2) |
| **Ayla** — the Trash Scavenger | `scavenger` | **Outside — every open day** (permanent delivery NPC) | `fragment_03` | `archeologist_lead` (free, from daily contact) | Yes (§10.3) |
| **Sam** — the Archeologist | `archeologist` | Inside, 15:00–17:00 Day 1 / 08:00–11:00 Days 3/5 | `fragment_04` | `excavation_tools` (digs Ayla's lunchbox; sturdy-object access) | Yes (§10.4) |
| **Mr. Maverick** — the Mysterious Buyer | `buyer` | Inside, daily 17:00–18:00, +07:00–09:00 Day 5 | releases `fragment_05` | `encoded_ledger`, investigation evidence | **No** — fifth-fragment source (§8) |
| **Yuyu** — Uncle's Legacy | `yuyu` | Inside — the finale | — | Master Artifact whole · the Perfect Loop | The finale (§9) |

- **Nang Shine.** Frail knock, ampaw in the basket, a lifetime of not-quite-saying things. Yuyu's
  first love, long before the player's Lola was old enough to mind the shop.
- **Nong Lave.** Shine's grandson. Forearms like rope, hands stained the color of old varnish. The
  keeper of the *dulom* — the patina that is "eighty years of hands," not dirt. His Lola (Shine)
  learned to see the old-in-the-true from a man in her old photographs.
- **Ayla.** Shoves the door instead of knocking. Louder than her hurt. Daughter of a scrap-man who
  sold to "a Manong with a notebook" — Yuyu — and who always said the junkyard is the busiest
  museum in town. She runs the yard and sorts everything the player forages.
- **Sam.** Measures a room from across it. The last person who saw Yuyu. His creed — *show the
  break, don't erase it* — is Yuyu's, quoted back with the seam showing.
- **Mr. Maverick.** Dressed a half-step nicer than the shop deserves. Keeps a battered ledger in
  handwriting that isn't his, and a decades-old promise to a man who trusted him to deal honestly.
- **Yuyu.** Returns mid-sentence, translucent at the edges, as if five days were a held breath.

**The spiral mark.** A small spiral pressed or carved into an object's base — easy to miss — is
**Yuyu's mark**, left on pieces that passed through his hands. It threads through three routes:
Lave's beat 3 dedication carries it (§5), Maverick's tip names it and his qualifying trade tests it
(§8), and the fifth fragment's carrier bears it (§8, beat B3). *(Canonized here — decision note
N2, §12.)*

---

## 4. Route — Nang Shine, the Elderly Auntie (`auntie`)

| | |
|---|---|
| Window | 12:00–14:00, Days 1, 3, 5 (inside) |
| Prerequisites | None — the always-open first thread |
| Holds | `fragment_01` |
| Rewards | `safe_code` (§ PRD CACHE-R1), `drawer_clue` (CACHE-R2); completing her **unlocks Nong Lave** |
| Beat objects | `auntie_photo_faded`, `auntie_frame_portrait`, `auntie_halfphoto_torn` *(already authored in `data/objects/objects.json`)* |

Her three beats are already authored in `data/routes/routes.json` and are carried over
**unchanged**:

| Beat | Day | Object | Restoration action | Summary (verbatim from data) |
|---|---|---|---|---|
| `auntie_beat_1` | 1 | `auntie_photo_faded` | brushing · paper care · photo restoration | "Auntie brings a faded family photo. Brush off the dust, lift the grime and water stain, and restore the faded image." |
| `auntie_beat_2` | 3 | `auntie_frame_portrait` | wiping · polishing · frame repair | "She returns with her framed portrait. Clean the glass, polish the tarnished corners, and consolidate the cracked molding." |
| `auntie_beat_3` | 5 | `auntie_halfphoto_torn` | paper care · tape-residue removal · archival rejoin | "On the final day she shares a photograph torn in two. Clean both halves, remove the old tape, then rejoin them with archival tape to reveal the uncle. Completing it releases her fragment." |

### 4.1 Intro scene (Day 1 window; verbatim)

> **Nang Shine:** [i]A frail knock. She peers over your shoulder at the half-open biscuit tin.[/i] Ay, kamusta na? Nakita mo na ang sulod?
>
> **You:** I cleaned what I could, Nang Shine — but the water damage... I don't have the right kit yet for paper this fragile. I don't want to ruin it trying.
>
> **Nang Shine:** Ah, husto man na. Indi gid kinahanglan dasohon. [i]She tucks the tin back into her basket — habit, not mistrust.[/i] That's the right call, anak.
>
> **Nang Shine:** Kon may husto ka na nga gamit — ihatag ko liwat ina sa imo. May— [i]She hesitates, then waves the thought away with a small laugh.[/i] Wala, lain lang. Old woman things. Same time Wednesday, ha?
>
> [b]Note saved:[/b] Nang Shine's photo — paper too fragile for current tools. Needs the proper kit. She seemed to recognize something in it before I could ask.

*Design note.* Her opening scene seeds two threads at once: the fragile-paper problem that Nong
Lave's `delicate_tool` later solves in general (§5), and the flicker of recognition that pays off
in the return scene. The specific Day-1 photo (`auntie_photo_faded`) is restorable with the
starting kit's paper tools; the *"right kit"* line refers to the worst-damaged pieces later in her
arc and keeps the tonal bridge to Lave.

### 4.2 Return scene (after restoring the photo; verbatim)

> **Nang Shine:** [i]She steps in without quite waiting, a paper bag of ampaw peeking from her basket.[/i] Maayong hapon, anak. Ay— [i]her basket lowers as her eyes catch the photograph on the table.[/i]
>
> **You:** Sulod, Nang Shine. We finished cleaning something — from the tin you dropped off.
>
> **Nang Shine:** [i]She lifts the restored photo with both hands. A young woman laughing; beside her, a young man caught mid-turn, like he'd been looking at her instead of the camera.[/i] Ay sus, gali ti, kami gid ini.
>
> [i]A low hum rises from beneath the floorboards. For one heartbeat the corner is a wide porch, the same two faces, younger — then it folds back. A Temporal Echo.[/i]
>
> **Nang Shine:** [i]A hand pressed to her chest, eyes wet.[/i] Diutay lang... pero amo gid na. That was him. That was Yuyu.
>
> **You:** You knew him? Before—
>
> **Nang Shine:** Before your Lola, anak. Way, way before. [i]She presses the photo gently back into your hands.[/i] Keep it safe for me, ha? Maybe it wants to stay here, sa imo anay, until I am.
>
> [b]Note saved:[/b] Yuyu and Nang Shine — his first love, long before Lola. The bahay-na-bato in the photo still stands here in Iloilo.

*The Temporal Echo here is the game's first: a bench-side memory, inside the shop (Temporal Echoes
stay inside; Cultural Echoes belong to the yard — compendium §1.3).*

### 4.3 Beat 2 — the framed portrait (Day 3) **[NEW connective scene]**

She brings the framed portrait of the same porch, glass fogged, molding cracked. While the player
works (wiping, polishing, consolidant on the molding):

> **Nang Shine:** Ang balay nga ina — my father's house. Yuyu would stand outside it for one hour before he had the nerve to knock. [i]She laughs, small.[/i] Isa ka oras, anak. Every Wednesday.
>
> **You:** What changed?
>
> **Nang Shine:** Wala. He never changed. Ako ang nag-untat sa paghulat. [i]She straightens a doily that does not need straightening.[/i] The frame first, ha. One thing at a time.
>
> [b]Note saved:[/b] The porch house was her father's. Yuyu courted her there — Wednesdays — until she stopped waiting. Something ended it that she isn't saying.

Returning the restored portrait (RETURN disposition) yields the **`drawer_clue`**: tucked behind
the backing board is a slip in Yuyu's hand — a reminder about the shop's locked drawer, and where
he kept the habit of writing things down. *(DISP-R3: a lead, never a fragment.)*

### 4.4 Beat 3 — the torn photograph (Day 5) and the release **[NEW connective scene]**

The final photograph is torn in two — deliberately, long ago. Cleaning both halves, lifting the
old tape, and rejoining them with archival tape reveals the full image: young Shine, young Yuyu,
and between them, on the porch table, **a small worked piece, wrapped half-open in cloth**
*(artifact-agnostic — D1)*.

> **Nang Shine:** [i]She looks at the mended seam a long time before she looks at the faces.[/i] Ako ang naggisi sina. The night he told me what he was really keeping in that journal of his. I thought — kon indi ko maintindihan, at least mapaslaw ko. [i]A breath.[/i] Foolish old girl.
>
> **You:** The thing on the table — in the cloth. What was it?
>
> **Nang Shine:** He said, "Shine, this is one of five. Kon may matabo sa akon, keep it. Don't open it. Don't give it away." [i]Her hands fold in her lap.[/i] And I kept it, anak. Sa lata sang biskwit, sa ilalom sang aparador. Forty years.
>
> **Nang Shine:** Then the flood year came, and the salvage cart took the whole aparador while I was at my sister's. Ginbaligya, ginbulad, gindala diri — sa inyo nga yarda, siguro, like everything else this town loses. [i]She meets your eyes, and for once doesn't wave the thought away.[/i] I could not look for it. Ikaw — you can. You have his hands.
>
> [b]Note saved:[/b] Shine kept one of five pieces in a biscuit tin, lost to a salvage cart in the flood year. It's somewhere in the stream that feeds our yard. The journal is listening now.

**→ `fragment_01` = RELEASED.** From the next time the player steps into the yard, the Cultural
Echoes are live for it: Hum → Melody → Voice → Heartbeat, into an ordinary promoted carrier the
Spawn Director hides anew each loop until found (§2.4). She also gives the **`safe_code`** —
"Yuyu's birthday, anak; he never could remember mine" — unlocking the shop Safe in a later loop
(CACHE-R1) and making it an eligible *outer container* for future placements (never a loose
fragment; §4-H).

**Completing this beat unlocks Nong Lave** — she sends him: *"My apo works with wood the way you
work with paper. Kilalaha siya."*

---

## 5. Route — Nong Lave, the Local Artisan (`artisan`)

| | |
|---|---|
| Window | 13:00–14:00, Days 2, 4, 5 (inside) |
| Prerequisites | **Auntie helped** (he is her grandson). No exclusion with Ayla (v2; the old same-slot exclusion is removed) |
| Holds | `fragment_02` |
| Rewards | `delicate_tool` — the legacy tool roll; unlocks fragile-object restoration in general (and retroactively answers Shine's "right kit" problem) |
| Beat objects *(proposed template ids — to be authored in data at P15.1)* | `artisan_santo_wood`, `artisan_lola_notes`, `artisan_baul_lid` |

Only his intro/return dialogue exists in data; his three beats are **[NEW]**, authored here:

| Beat | Day | Object | Restoration action | Advances |
|---|---|---|---|---|
| `artisan_beat_1` **[NEW]** | 2 | `artisan_santo_wood` — an old wooden santo | dry brushing · gentle wiping — **no polish**; preserving the *dulom* | The restraint lesson; passing it is what earns his return |
| `artisan_beat_2` **[NEW]** | 4 | `artisan_lola_notes` — his Lola's annotated photo bundle | paper care · tape-residue removal, using the just-gifted `delicate_tool` | Reveals in writing that Shine's teacher was Yuyu; grants the tool roll |
| `artisan_beat_3` **[NEW]** | 5 | `artisan_baul_lid` — the carved lid of her baul (chest) | grime/wax lift · **engraving reveal** | The spiral-marked dedication; completing it **releases `fragment_02`** |

### 5.1 Beat 1 — the santo and the dulom (Day 2; intro scene, verbatim)

> **Nong Lave:** [i]Forearms like rope, hands stained the color of old varnish. He leans into the doorway.[/i] Maayo nga hapon. May tawag ka guwa nga may bag-o — old wood, daw galing pa sa altar. Mind kung tan-awon ko lang?
>
> **You:** Go ahead, Nong Lave. Found it in this morning's delivery — was about to clean it up.
>
> **Nong Lave:** [i]He sees the brass polish open in your hand, and his shoulders drop a little.[/i] Ay — hulat anay. That brass polish — indi gid na para sa kahoy. You'll strip the patina — the dulom. That's not dirt, anak. That's eighty years of hands.
>
> **You:** I just wanted it to look good before I—
>
> **Nong Lave:** Maayo na siya the way nag-tigulang siya. [i]He sets it down exactly where it was.[/i] Pasensya na ko. Pero kon imo na ginsalakay sang amerilyo — wala ka na sang ma-ibalik.
>
> **Nong Lave:** Ginatudluan ko anay sang akon Lola kon paano makilala ang tinuod nga daan sa ginhimo lang nga daan. Basi makasugod ka diri. [i]He's gone before you can ask which Lola he means.[/i]

*Playable beat:* the santo is on the bench with mixed blemishes. The **correct** restoration is
soft-brush and damp-cloth only; using polish/solvent on the wood applies the wrong-tool damage and
visibly strips the dulom (permanent value loss — the mechanics teaching his lesson). Completing it
with restraint is the gate for his return.

### 5.2 Beat 2 — the tool roll and his Lola's notes (Day 4; return scene verbatim, then [NEW])

> **Nong Lave:** [i]The same careful half-entrance. He watches you work — the soft brush, the restraint — and stops.[/i] Gali ti. Sin-o naghambal sa imo parte sa dulom? Indi ina common nga kaalam sa mga bata subong.
>
> **You:** Someone explained it to me once. It stuck.
>
> **Nong Lave:** [i]He picks up the santo with the respect of someone handling a relative's hands.[/i] Akon Lola usually ang naga-asoy sini — paano makilala ang daan sa tinuod. She learned it from someone too. Sang una pa.
>
> [i]Light catches the santo's chipped shoulder wrong. For half a breath: a family altar, candlelight, a younger Nang Shine's hands lighting a wick beside this very santo. It folds shut.[/i]
>
> **Nong Lave:** [i]He produces a cloth roll of hand-worn tools.[/i] Abyan na ta subong, ha? Diri — para sa mga butang nga maluya gani, indi lang daan. Indi mo na kinahanglan ang polish nga ina.
>
> **Nong Lave:** May ginsulat akon Lola sa iya mga daan nga litrato — parte sa isa nga lalaki nga nakatudlo sa iya. Daw kilala ko na siya gamay, through her. Same time Thursday, ha?

**→ `delicate_tool` granted** (the tool roll; persists as a legacy item, §4-A). The Temporal Echo
confirms what the player may already suspect: his Lola is **Nang Shine**.

**[NEW]** He leaves the photo bundle she annotated. Restoring it (paper care with the new tools —
lifting foxing and old tape without erasing her margin notes) reveals her handwriting:

> [i]In the margins, in a young woman's careful hand: "Ang lalaki nga nagtudlo sa akon magtan-aw — indi sa mata, sa kamot." Beside one photograph, a name is inked and crossed out and inked again.[/i]
>
> [b]Note saved:[/b] Nong Lave's Lola wrote about the man who taught her to see with her hands, not her eyes. The crossed-out name is short. It could be a nickname.

### 5.3 Beat 3 — the baul lid and the release (Day 5) **[NEW]**

He brings the carved lid of his Lola's baul — the one piece of her furniture he kept when the
family lot was cleared. Under a century of wax and candle smoke there is carving nobody has read
in decades. **Engraving reveal** (gentle solvent, then dry brush) uncovers a dedication line and,
at its corner, a **small carved spiral** (§3, the spiral mark):

> [i]The carving, letter by letter, out of the wax: "Ang kamot nga nagatudlo, wala nagauyat." — the hand that teaches does not hold on. In the corner, a spiral, pressed deep, sure of itself.[/i]
>
> **Nong Lave:** [i]He reads it twice. His thumb stops just short of the spiral.[/i] Amo ni siya. The man in her photographs. Ang nagtudlo sa iya — kag sa akon, paagi sa iya. [i]He sets the lid down exactly where it was, the old habit.[/i] Imo Yuyu.
>
> **You:** She never told you?
>
> **Nong Lave:** Ginhambal niya nga may ginbilin siya nga butang sa iya — gamay, nabalot, "indi pag-ablihi." Kept it inside this baul, sa idalom sang mga habol. [i]A long breath.[/i] When we cleared the lot after she moved to my Tita's — the baul went with the hauling truck. Tanan. I kept only the lid.
>
> **Nong Lave:** I know your yard buys those loads, anak. Somewhere out there is an old man's parcel inside an old woman's chest. [i]He almost smiles.[/i] I won't dig for it. Indi ko ni ihatag sa kamot — kag indi man ako ang dapat maghatag. The yard gave it to her stream to carry. Let it give it to you.
>
> [b]Note saved:[/b] Lave's Lola kept a small wrapped piece — "don't open it" — in her baul. The baul was hauled to the yard when the lot was cleared. Only the lid stayed behind. The journal is listening.

**→ `fragment_02` = RELEASED.** *(Note the deliberate echo of Yuyu's rule — "indi ko ni ihatag sa
kamot" — the same refusal Maverick voices in §8. Nobody hands history over.)*

---

## 6. Route — Ayla, the Trash Scavenger (`scavenger`)

| | |
|---|---|
| Availability | **Outside — the scrapyard, every open day.** She is the permanent delivery NPC: she takes the player's foraged scrap, sorts it (~1 in-game hour), and knocks with the delivery. Not a gated visitor. *(v2; the routes.json visitor window is stale — flagged §12.)* |
| Prerequisites for her lead | None — `archeologist_lead` comes **free from daily contact** |
| Prerequisites for her completion | **Sam's `excavation_tools`** (ROUTE-R8) — dig the lunchbox, restore it, then "Show Ayla the lunchbox" |
| Holds | `fragment_03` |
| Beat object *(proposed template id)* | `ayla_lunchbox_rusted` — her father's dented lunchbox |

Her story runs in **two registers** (compendium §3) so daily contact never flattens her arc:

### 6.1 Milestone chain (the route proper)

| Beat | When | Object / action | Advances |
|---|---|---|---|
| `scavenger_beat_1` | Early, at the yard | The dismissed lunchbox (intro scene, verbatim) | Her hurt is planted; the lunchbox disappears back into the heaps |
| `scavenger_beat_2` **[NEW]** | Any later hand-off (daily contact) | — (dialogue only) | She gives the **`archeologist_lead`** — free, ungated, persists |
| `scavenger_beat_3` | After Sam's route (`excavation_tools` owned) | **Dig** the lunchbox from its yard spot · rust removal · **engraving reveal** (initials + date) · "Show Ayla the lunchbox" | Vindication scene (return dialogue, verbatim) → **releases `fragment_03`** |

### 6.2 Beat 1 — the dismissed lunchbox (intro scene, verbatim)

> **Ayla:** [i]The door gets a shove, not a knock. She drops a sack with a clatter.[/i] Oy! May tesoro ko diri, ha! Tan-awa ina nga lunchbox sa imo lamesa — ina, may history ina!
>
> **You:** That one's just rusted tin, Ayla. It's going in the recycle bin.
>
> **Ayla:** [i]Her grin falters for half a second before she covers it, louder.[/i] Indi ka makasiguro sina kon wala ka nag-tan-aw maayo! May sticker pa ina sang daan nga sine — abi mo basura lang, pero—
>
> **You:** It's rust and a torn sticker. I've got better things to restore today.
>
> **Ayla:** [i]She picks the lunchbox back up herself — quick, like it shouldn't sit where it isn't wanted.[/i] Sige lang. Wala man, basura man gali, ikaw ang nakahibalo. Same time Thursday — pero tama lang, indi ko na pilitan.
>
> [b]Note saved:[/b] Ayla brought in a lunchbox, said it had history. Didn't check. She didn't push back twice.

**[NEW — placement note]** After this scene she doesn't bring it again. If asked, she deflects
("Wala lang. Pamangkot lang."). In truth she tossed it back where she found it — deep under a heap
no hand-forage reaches. **Recovering it requires Sam's excavation tools** (ROUTE-R8): the dig spot
surfaces as a marked/diggable yard interaction once the tools are owned. *(This re-sets the v1
"she brings it in" framing to the v2 "excavated from the yard" framing — compendium open task,
resolved here on paper.)*

### 6.3 Routine register — daily hand-off banter pool **[NEW]**

Short, rotating, non-blocking lines at the scrap hand-off (a pool the implementation can draw
from; all review-pending):

1. "Oy! Dali dali — may tesoro sa sulod sina. Mabatyagan ko gid."
2. "Bug-at ni? Maayo. Ang bug-at, may sugilanon."
3. "Kon makakita ka sang nagakislap nga suga sa tinumpok — indi pagbaligya dayon, ha? Tan-awa anay."
4. "Tatay ko anay naghambal: ang junkyard amo ang pinaka-busy nga museo sa banwa. Saying niya lang ina, ha — pero tuod man."
5. "Sort ko ni mga isa ka oras. Indi ka magtindog dira nga nagatulok — makahuya."
6. *(after beat 1, before beat 3)* "Wala ka nakakita sang... wala lang. Pamangkot lang."

Her existing yard state lines (`yard_empty`, `yard_sorting`, `yard_sort_ready` in routes.json)
carry over verbatim as the functional layer of this register.

### 6.4 Beat 2 — the lead to Sam (daily contact) **[NEW]**

Given freely at a hand-off once the player has been foraging a few days — deliberately **not**
gated on her own arc (this is what breaks the Ayla↔Sam dependency cycle, ROUTE-R8):

> **Ayla:** [i]She weighs a rusted bracket in one hand, squints at it like a jeweler.[/i] You know who'd buy this kind of ugly? May kilala ko — nagakutkot sang daan nga mga butang, propesyonal pa. Sa guwa sang syudad ang balay niya, pero nagalibot siya diri kon may lote nga ginabaligya.
>
> **You:** A digger? Like, an archeologist?
>
> **Ayla:** Amo na ang tawag nila kon may diploma ka. [i]She scribbles on the back of a receipt with a pencil stub.[/i] Sam. Hambala nga ako ang nagpadala sa imo — kag indi ka magbinuang sa iya, ha, serioso ina nga tawo.
>
> [b]Lead saved:[/b] Sam, the Archeologist — Ayla's contact who digs old things professionally, outside the city.

**→ `archeologist_lead` granted; persists across loops** (§4-A) — on later loops Sam is available
from Day 1 (ROUTE-R4). *(The two closing "lead" blocks of her authored `return` dialogue in
routes.json bundled this lead into the vindication scene; v2 moves the lead here, earlier. The
data-side split is flagged in §12.)*

### 6.5 Beat 3 — the dig, the initials, the vindication (return scene, verbatim core)

With `excavation_tools` owned: the dig spot in the yard yields `ayla_lunchbox_rusted`. At the
bench: rust removal, then engraving reveal — scratched initials and a date. Then, at the yard,
**"Show Ayla the lunchbox"**:

> **Ayla:** [i]The same shove. She stops — the lunchbox is already on the table, half the rust lifted.[/i] Oy! May tesoro ko diri— ...ay, gina-restore mo na siya?
>
> **You:** Figured I should actually look first.
>
> **Ayla:** Tuod gid ko, bala? Indi tanan nga daan basura. [i]The last rust comes away, revealing scratched initials and a date. She goes quiet for the first time since walking in.[/i]
>
> **Ayla:** ...That's akon Tatay's initials. He used to sell scrap to a Manong with a notebook — said he always paid fair, never haggled mean, even kon basura gid lang ang dala mo.
>
> **You:** The Manong with the notebook — was that—
>
> **Ayla:** Imo Yuyu, siguro gid. [i]She taps the lunchbox once, gently.[/i]

*(Scene carried over verbatim through the Yuyu line; setting re-homed to the yard/bench per
compendium §3. The original scene's final lead-giving blocks are superseded by beat 2 — see §12.)*

**[NEW — continuation and release:]**

> **Ayla:** [i]She turns the lunchbox over twice, like it might still be a trick.[/i] Tatay kept his best finds for that Manong. May isa — gamay, mabug-at para sa kadakuon niya, nabalot sa trapo. The Manong told him: "Tago-a ini. Kon indi ako magbalik, itago mo gihapon." [i]Her jaw works.[/i] Gintago niya sa toolbox sang kariton niya.
>
> **You:** Where's the cart now, Ayla?
>
> **Ayla:** [i]A short, unfunny laugh.[/i] Ginbaligya ko. Kinahanglan namon ang kwarta sang lubong. Wala ko kahibalo kon ano to nga butang — basura, bulawan, wala ko na gin-tan-aw. [i]She looks out at the heaps, and for once her voice is the size of a normal person's.[/i] Diri lang gid to nagtiner, sa amo man ni nga yarda. Pangitaa, ha? Kay indi ko na makaya nga ako ang mangita.
>
> [b]Note saved:[/b] Ayla's Tatay hid a small wrapped piece for Yuyu in his cart's toolbox. She sold the cart into this yard after the funeral. The journal is listening.

**→ `fragment_03` = RELEASED.**

---

## 7. Route — Sam, the Archeologist (`archeologist`)

| | |
|---|---|
| Window | 15:00–17:00 Day 1 (once the lead is known — from Day 1 on later loops, ROUTE-R4); 08:00–11:00 Days 3, 5. *(routes.json's current windows are stale — flagged §12.)* |
| Prerequisites | `archeologist_lead` (from Ayla's daily contact — §6.4) |
| Holds | `fragment_04` |
| Rewards | `excavation_tools` — unearths Ayla's lunchbox (ROUTE-R8) and unlocks sturdy/buried-object restoration in general |
| Beat objects *(proposed template ids)* | `sam_jar_mended` (his lesson piece), `sam_banga_cracked`, `sam_transit_jammed` |

Only his intro/return dialogue exists in data; his three beats are **[NEW]**, authored here:

| Beat | Day | Object | Restoration action | Advances |
|---|---|---|---|---|
| `archeologist_beat_1` **[NEW]** | 1 (or first window) | `sam_jar_mended` | — (the lesson; the player's earlier invisible mend is the prop) | "Show the break" challenge issued |
| `archeologist_beat_2` **[NEW]** | 3 | `sam_banga_cracked` — a broken earthen banga | consolidation with the **seam left legible** — no over-polish, no disguise | Passing the test → return scene → **`excavation_tools`** |
| `archeologist_beat_3` **[NEW]** | 5 | `sam_transit_jammed` — his surveyor's transit, jammed since the last dig | **mechanism inspection** — free the needle without erasing the field scratches | The confession → **releases `fragment_04`** |

### 7.1 Beat 1 — the mended jar (intro scene, verbatim)

> **Sam:** [i]He measures the room from across it before approaching.[/i] Maayo nga aga. I was told there might be something worth seeing here. [i]He lifts the mended jar.[/i] ...This was broken.
>
> **You:** It was. I fixed it — you can barely tell now.
>
> **Sam:** Tuod — you can barely tell. That's the problem. You didn't fix the jar. You erased the part of its history where it broke.
>
> **You:** Isn't that the point of restoration?
>
> **Sam:** Indi gid. A maker built this with two hands. It broke with someone else's. If you hide that, you're just hiding evidence. Real mastery is re-forging it so both hands still show.
>
> **Sam:** Pasensya ko, ah. Pero kon may sunod ka pa nga daan nga butang nga nabuong — don't disguise the break. Show it. Then we'll talk.

### 7.2 Beat 2 — the honest seam (Day 3) **[NEW scene, then return verbatim]**

A broken earthen banga comes through the delivery (or he leaves it — implementation's choice).
The playable test: consolidate the break so the vessel is whole and stable, **leaving the seam
visible** — the restoration explicitly rewards *not* using the disguising finish. When he returns:

> **Sam:** [i]He holds a folded paper. His eyes go straight to the jar — to the visible seam, not hidden.[/i] Maayo nga hapon. Ayla said you'd want this address. You left the break showing.
>
> **You:** Hiding it would just be lying about whose hands touched it.
>
> **Sam:** [i]A real smile, the measuring look gone.[/i] Sige — now we can talk properly. Most people want history invisible. You left it where I could see it.
>
> **Sam:** I knew your Yuyu. Tuod gid — I was the last one who saw him, before— [i]He doesn't finish.[/i] He used to say almost the same thing: indi mo paglimpyohan ang kasaysayan hasta mawala ang ebidensya.
>
> **Sam:** [i]He sets a small, worn case on the table.[/i] A proper excavation kit. There are objects in this city too sturdy for your current methods — I can open that door, kon gusto mo.
>
> [b]Note saved:[/b] Sam was the last person seen with Yuyu before he vanished.

**→ `excavation_tools` granted** (persists; gates Ayla's dig, §6.5, and sturdy-object work).

**[NEW — gloss on the folded paper.]** The "address" Ayla said the player would want is not Sam's —
the player already has that. It is a **lot-transfer record** Sam has carried for years: the paper
trail of a crate mis-auctioned as scrap after his final dig with Yuyu was shut down. The trail's
last line is an address the player knows very well. *"Basaha ang katapusan nga linya."* It is the
player's own yard. Sam has been circling this shop far longer than Ayla's lead has existed — the
lead just finally gave him a reason to knock.

### 7.3 Beat 3 — the transit and the confession (Day 5) **[NEW]**

He brings his own surveyor's transit, jammed since that last dig — he has never let anyone repair
it, and has never used another. **Mechanism inspection**: open the housing, free the seized
needle, clean the pivot — without erasing the field scratches on the casing ("evidence," he says,
"of every site it ever saw").

> **Sam:** [i]He watches the needle swing free for the first time in years, and something in his shoulders unlocks with it.[/i] The last day, we closed the site early. Rain coming. Yuyu stood exactly there— [i]he stops himself placing the memory in your shop, and fails[/i] —somewhere like there, and asked me to keep something. "In context," he said. "Buried things keep better than kept things."
>
> **You:** You buried it?
>
> **Sam:** I catalogued it. Crate 11, wrapped, unlabeled, per his instruction. [i]The old anger, dry as dust.[/i] Then the funding fell through, the site was sealed, and the storage lots went to auction while I was filing appeals. Crate 11 sold as scrap weight. Twelve pesos, the record says.
>
> **Sam:** I have bought junk lots for nine years trying to follow it. The paper ends at your yard. [i]He closes the transit's case with a click.[/i] I will not dig up another man's ground, and I will not hand you a conclusion — indi ko paglimpyohan ang kasaysayan para sa imo. Find it in context. Show me the break.
>
> [b]Note saved:[/b] Yuyu asked Sam to keep a wrapped piece "in context." It was catalogued as Crate 11, auctioned as scrap, and the paper trail ends at our yard. The journal is listening.

**→ `fragment_04` = RELEASED.**

---

## 8. Route — Mr. Maverick, the Mysterious Buyer (`buyer`)

| | |
|---|---|
| Window | Daily 17:00–18:00; **plus 07:00–09:00 on Day 5** |
| Prerequisites | None to meet him. Qualifying condition (D7): **at least one honest deal on Days 1–4**. His climax fires only as the **finale capstone — after the other four fragments are seated** |
| Releases | `fragment_05` — **into a guaranteed Director-placed yard carrier** (ROUTE-R5; never a hand-over — see §12, conflict C1) |
| Rewards | `encoded_ledger` (investigation evidence; epilogue hook) |
| Ending | **None** (END-R1). He is the fifth-fragment source and the finale's doorman |
| Beat object *(proposed template id)* | `buyer_spiral_trinket` — any ordinary spiral-marked piece (§3) |

| Beat | When | Action | Advances |
|---|---|---|---|
| `buyer_beat_1` | Days 1–4 window | Intro scene (verbatim) | The spiral-mark tip; his card |
| `buyer_beat_2` **[NEW]** | Days 1–4 window | Restore and **sell him a spiral-marked piece** without price-anchoring (marketplace beat) | The qualifying honest deal (D7) |
| `buyer_beat_3` **[REWRITTEN — release]** | Day 5, other four seated | The ledger scene → **release** | `fragment_05` → guaranteed yard carrier → the final hunt |

### 8.1 Beat 1 — the card and the spiral (intro scene, verbatim)

> **Mr. Maverick:** [i]Dressed a half-step nicer than the shop deserves. His eyes sweep the shelves once — fast, practiced.[/i] Maayo nga hapon. Thought I'd stop by, see if anything interesting came through.
>
> **You:** Nothing special this week, sorry. Mostly sold straight through the regular buyers.
>
> **Mr. Maverick:** [i]A small, unreadable smile. He sets a blank business card on the counter without quite handing it over.[/i] Sige lang. Some people take a few weeks before they understand which pieces are worth my prices.
>
> **Mr. Maverick:** Though — between us — there are objects out there with a small mark. A spiral, pressed into the base, easy to miss. Kon you ever see one, I'd pay it more attention than the glow suggests.
>
> **You:** Why? What does the mark mean?
>
> **Mr. Maverick:** Lain-lain ang storya. Maybe another time. [i]He's gone before the bell finishes ringing — just a card with a phone number and nothing else.[/i]

### 8.2 Beat 2 — the honest trade (Days 1–4) **[NEW]**

Eventually a **spiral-marked trinket** surfaces in a delivery (ordinary object; the mark is
cosmetic lore, not a mechanic — the Spawn Director owes it nothing). The player restores it and
offers it to Maverick **without asking his price first**. A short scene; his practiced surface
cracks by a millimeter:

> **Mr. Maverick:** [i]He turns the piece over, finds the spiral, and for exactly one second forgets to perform.[/i] ...You didn't name a number.
>
> **You:** You said you'd pay it attention. I wanted to see what that looks like.
>
> **Mr. Maverick:** [i]He pays over the odds without haggling — the first time the shop has seen him do anything without theatre.[/i] Ti. Most sellers price the glow. You priced the... [i]he taps the spiral once[/i] ...provenance. He would have liked that.
>
> **You:** Who—
>
> **Mr. Maverick:** [i]The smile closes like a shutter, but gently.[/i] Sa Biyernes, siguro. Some stories want the week to finish first.
>
> [b]Note saved:[/b] Maverick paid over the odds for the spiral-marked piece — no haggling, no theatre. "He would have liked that." Who?

*(This is the qualifying deal — D7. It can happen in any loop; it persists. Replaying it in later
loops is background trade with lighter lines.)*

### 8.3 Beat 3 — the ledger and the release (Day 5; finale capstone)

**Fires only when the other four fragments are seated** (ROUTE-R5). Opening — verbatim from the
authored scene:

> **Mr. Maverick:** [i]No business-card performance this time. He's already inside, gentler than before.[/i] Maayo nga aga. You sold me that spiral-marked piece without asking my price first. Nobody's done that in a long time, lagi.
>
> **You:** You said you'd pay attention to the mark. Trusting you once wouldn't hurt.
>
> **Mr. Maverick:** [i]He sets a battered ledger on the counter — pages of handwriting that isn't his.[/i] Your Yuyu kept me on a short list of people he trusted to deal honestly. I've kept that list longer than I should have.
>
> **Mr. Maverick:** He asked me to look into something the week before he disappeared. Indi ko gusto i-drop ina nga investigation nga half-done — pero wala ko sang partner. Until now, maybe.

**[REWRITTEN from here — the release replaces the hand-over.]** *(The authored continuation has
him produce the fragment from his coat — that violates §4-B/ROUTE-R5/DISP-R3 and is superseded;
the original lines are quoted for the record in §12, conflict C1. The corrected scene:)*

> **Mr. Maverick:** The thing he asked me to trace — the fifth of five. Ginlagas ko ini nga piyesa sa tatlo ka syudad kag isa ka bangkarote nga auction house. [i]He opens the ledger to a page of columns and dead ends, and turns it to face you.[/i] Last month the trail ended. A mixed lot nobody could place — tipped into *your* yard with the rest of the week's salvage.
>
> **You:** It's been *here*? Then why not just—
>
> **Mr. Maverick:** Buy it back? Walk out there and take it? [i]He closes the ledger, and for once the smile reaches his eyes.[/i] The piece I sold you my attention for — the spiral one — it and its sibling have been speaking to each other all week. Listen on your way out. The yard is loud today.
>
> **Mr. Maverick:** I'm not the type to hand a man his own history, anak. Go find it — it's out there waiting for you, same as it waited for me.
>
> [i]He leaves the ledger on the counter. Encoded — Yuyu's hand, Yuyu's cipher. On the last written page, a spiral.[/i]
>
> [b]Note saved:[/b] The fifth piece is in the yard — released into the stream with a lot Maverick traced for nine years. He left Yuyu's encoded ledger. "Partner," apparently. The journal is listening. Loudly.

**→ `fragment_05` = RELEASED into a guaranteed special placement**: the Spawn Director promotes an
ordinary carrier and hides it in the yard *that same Day 5* (deterministic — D7), so the final
hunt happens in the loop's closing hours: dusk light, all four bands live, one heartbeat under the
junk. **`encoded_ledger` granted** (persists; its decoded contents are epilogue material, §9.3).

---

## 9. The Finale — Yuyu, Uncle's Legacy (`yuyu`)

| | |
|---|---|
| Trigger | **All five fragments seated** — the finale plays in the loop the fifth seats (END-R3: the Perfect Loop is *that* loop; nothing is re-gathered) |
| Reward | The Master Artifact, whole · the Perfect Loop |

### 9.1 The fifth seating and the assembly **[NEW]** *(artifact-agnostic — D1)*

The fifth fragment seats. The case does not simply accept it — the journal **closes itself**, and
every page of static the player never cleared clears at once, ink rushing back like water finding
level. Then the case opens again, and the five pieces are loose, waiting.

The **final restoration** is played, not watched (END-R5): a tactile assembly sequence at the
bench, joining the five pieces in order — each join a small, careful act using the skills the
routes taught (the restraint of the santo, the honest seam, the freed mechanism, the mended
photograph, the fairly-judged trade). *The artifact's identity, geometry, and join order are
deferred to the artifact lock (D1); this scene is authored to the five-part structure only.*

When the last piece joins, the shop's lamplight holds still — the first moment in the whole game
with **no clock running.**

### 9.2 The return (verbatim)

> **Yuyu:** [i]Where there was only lamplight, there is a man — translucent at the edges, already steadying.[/i] —and that's why the Chronos Emulsion shouldn't ever be sealed with— [i]He stops. Looks at you.[/i] ...Ah.
>
> **You:** Yuyu—
>
> **Yuyu:** Naku... look at you. [i]He reaches out, not quite touching your shoulder, like his hands aren't entirely back yet.[/i] How long was I...?
>
> **You:** Five days. Looped. Over and over, until—
>
> **Yuyu:** Until five people I trusted held five pieces, and one stubborn anak went and found every single one of them. [i]He laughs, real this time, a little wet at the edges.[/i]
>
> **Yuyu:** Alima. Passing something forward, hand to hand, until it's too heavy for one person to carry alone. I think I finally understand why your Lola said it like that.

### 9.3 The morning that finally comes **[NEW]**

He closes the journal. The Emulsion goes quiet — not dead, *done*. Outside, for the first time,
the light changes past 20:00; the night actually passes; and the game's last playable beat is
small on purpose: **open the shop door on Saturday morning.** Day 6. The day that never came.

Epilogue montage (each vignette reprises its route's ending, §10 — all four are guaranteed
complete by the finale's own gate):

- **The porch.** Shine and Yuyu, both old now, on the bahay-na-bato porch from the photograph.
  Nobody says anything important. That's the point.
- **The workshop.** Lave fits the restored baul lid onto a new-made chest — old wood and new,
  both hands showing.
- **The yard.** Ayla's cart, repainted: **TESORO**. The lunchbox rides on top, not for sale.
- **The record.** Sam files the final report on Crate 11 — findspot: *a junk shop in Iloilo;
  context: intact.* The player is listed under "recovered by."
- **The ledger.** Maverick, at the counter one last time, decoding pages with the player — Yuyu's
  unfinished investigation becomes the two of them, partners, turning to a fresh page. *(Hook for
  post-game/lore material; contents deferred with D1.)*
- **The museum.** The Portal record for the assembled Master Artifact goes live — the private
  week becomes public memory (§4-F; the assembled-artifact record, §4-M).

Credits over the yard at golden hour. Underneath the folk theme, very faint, a heartbeat — then,
finally, none: nothing hidden anymore.

---

## 10. Endings

Character endings resolve their **arc**, not the game: the loop continues around them until the
Perfect Loop (their post-completion visits replay warmer idle scenes and release nothing new,
ROUTE-R7). Each ending fires on route completion (END-R1) and writes a persistent **ending card**
into the journal. All four are prerequisites-by-construction of the finale (the fifth release
requires the other four seated).

### 10.1 Nang Shine — *"A Photograph, Whole"* **[NEW]**

The evening after `fragment_01` releases, she is on the shop step at closing, ampaw for two.

> **Nang Shine:** Kon makita mo siya, anak — sa diin man siya karon — hambala: the porch is still wide. [i]She pats the mended photograph in your hands, once, like tucking in a child.[/i] Kag hambala, wala na ako nagahulat. Nagapuyo na ako. There is a difference, ha. It took me forty years.

### 10.2 Nong Lave — *"An Apprentice of Old Hands"* **[NEW]**

He burns a small mark into the empty slot of the tool roll he gave away — the player's initials,
beside generations of others.

> **Nong Lave:** Ang roll nga ina — indi na akon. Was never mine, gali. It's a hallway. [i]He hangs the santo's cloth on its hook, unhurried.[/i] Kon may bata nga mag-abot sa imo puertahan someday nga may amerilyo sa kamot — you'll know what to do. Hinay-hinay lang, ha?

### 10.3 Ayla — *"Not Everything Old Is Trash"* **[NEW]**

The lunchbox goes on the shop's shelf — polished, priced at nothing, labeled in her handwriting.

> **Ayla:** [i]She sets it dead center where the light hits, adjusts it twice, dares you to object.[/i] Display lang, ha. Indi baligya. Kon may magpamangkot kon pila — hambala, "sold na. Sang una pa." [i]At the door she stops, doesn't turn around.[/i] ...Salamat kay gintan-aw mo gid. Amo lang to ang ginapangayo ko sa tanan.

### 10.4 Sam — *"The Break, Shown"* **[NEW]**

He brings a copy of his amended site report and puts it on the counter like a shared trophy.

> **Sam:** Nine years of appendices, and the honest version is two pages. [i]He taps the seam of the mended banga on your shelf as he leaves.[/i] History held. Both hands showing. Padayon, kaibahan.

### 10.5 Neutral continuation (END-R2) **[NEW]**

Complete no route in a loop — or in any number of loops — and the week simply folds back. Nothing
is lost (the journal keeps everything), and nothing moves. The journal marks it with one recurring
line of Yuyu's recovered ink, gentle rather than punitive:

> [i]New ink, no hand visible: "Ang semana nagahulat sa imo, indi sa oras." — the week is waiting on you, not on the clock.[/i]

### 10.6 The Buyer's non-ending

Maverick gets no ending card by design (END-R1): his reward *is* the finale's doorway and the
partnership in the epilogue (§9.3). His arc completes the game rather than himself.

### 10.7 The Perfect Loop — Yuyu (END-R3/R5)

Seating the fifth fragment in the loop it releases (§8.3 → hunt → seat) triggers §9. Because
seated fragments persist (§4-A/B), the Perfect Loop is simply *the loop in which the last seat
fills* — no re-gathering, ever.

---

## 11. The Cross-Route Item Web

### 11.1 What each route gives, needs, and gates

| Route | Needs (gate) | Gives | Which it gates |
|---|---|---|---|
| **Auntie** | — | `safe_code`, `drawer_clue`; **Artisan unlock** | Artisan's whole route; Safe cache/outer-container (later loops); drawer pages |
| **Artisan** | Auntie completed | `delicate_tool` | Fragile-object restoration everywhere (incl. the worst paper pieces Shine's thread flagged) |
| **Scavenger (contact)** | — (daily hand-offs) | `archeologist_lead` | Archeologist's whole route |
| **Archeologist** | `archeologist_lead` | `excavation_tools` | **Scavenger's completion** (the lunchbox dig, ROUTE-R8); sturdy/buried objects everywhere |
| **Scavenger (completion)** | `excavation_tools` | releases `fragment_03` | — |
| **Buyer (deals)** | ≥1 honest deal, Days 1–4 (any loop) | `encoded_ledger` at capstone | The capstone itself (D7) |
| **Buyer (capstone)** | four fragments **seated** | releases `fragment_05` (guaranteed yard carrier) | The finale |
| **Yuyu** | all five seated | the Perfect Loop | — |

### 11.2 The dependency graph

```
        Auntie ──────────────► Artisan
        (no gate)               (frag_02)
         frag_01

        Ayla: daily contact ──► archeologist_lead ──► Sam ──► excavation_tools ──► Ayla: completion
        (ungated, free)                              (frag_04)                      (frag_03)

        Maverick: honest deal (Days 1–4, any loop)
                 └─► [waits until frag_01..04 seated] ─► Day-5 capstone ─► frag_05 released ─► FINAL HUNT ─► Yuyu
```

### 11.3 Winnability

- **Loop 1 always has a move.** Auntie is ungated; Ayla's contact (and therefore the lead) is a
  free by-product of the core forage loop; Maverick's qualifying deal needs only the shop's normal
  trade. No opening state can stall.
- **The only apparent cycle — Ayla↔Sam — is broken by design** (ROUTE-R8): Sam needs Ayla's
  *lead*, which comes from daily contact, **not** from completing her; Ayla's *completion* needs
  Sam's tools. The graph is a DAG: `contact → Sam → Ayla-completion`.
- **Nothing is missable.** Leads, completions, tools, and seated fragments all persist (§4-A); an
  unanswered window only costs the loop, never the route. Any loop can be a "wasted" loop with
  zero long-term loss (Neutral, §10.5).
- **Releases never deadlock.** A `RELEASED` fragment is re-placed by the Spawn Director every
  loop until found, never behind an unobtainable tool, never in a repeated spot (§4-B/C/H); the
  hunt is a parallel activity that doesn't compete with the route budget (ROUTE-R7).
- **The capstone cannot fire early or be locked out.** Maverick appears daily; his deal condition
  can be satisfied in any loop and persists; his climax waits for exactly the state (four seated)
  that the rest of the web guarantees is reachable.

### 11.4 The canonical playthrough (≈5 loops; END-R4)

| Loop | Route completed (the one-per-loop slot) | Yard (parallel) | Seated by loop's end |
|---|---|---|---|
| 1 | **Auntie** (Days 1/3/5 beats) → `frag_01` released. Meet everyone; earn Ayla's lead; make Maverick's honest deal | Hunt begins late — may or may not find `frag_01` | 0–1 |
| 2 | **Artisan** → `frag_02` released | Seat `frag_01` | 1–2 |
| 3 | **Sam** → `excavation_tools`; `frag_04` released | Seat `frag_02` | 2–3 |
| 4 | **Ayla** (dig → show) → `frag_03` released | Seat `frag_04` (and `frag_01`/`frag_02` if trailing) | 3–4 |
| 5 | — (no new route needed) | Seat the last trailing fragment → **four seated** → Maverick's Day-5 capstone → `frag_05` released **and hunted that dusk** | **5 → the Perfect Loop** (§9) |

Valid alternate orders are any topological order of the graph (e.g. Auntie → Sam → Ayla → Artisan);
slower players simply take more loops — the web has no failure ordering.

---

## 12. Conflicts & Open Decisions — flagged, not fixed

Nothing below is changed in code or data by this document. Each item needs a team/design
resolution (or an already-made resolution needs its data catch-up) before implementation marks the
related tasks done.

**C1 — The Buyer's authored `return` dialogue hands over the fragment (invariant violation).**
`data/routes/routes.json` (`buyer.dialogue.return`) currently ends:
*"[i]From an inner pocket, wrapped in cloth, he produces a fragment — its spiral mark matching the
trinket you sold him.[/i]"* / *"This is yours now. Seat it properly. I had to be sure you weren't
just another collector chasing the glow."*
This violates §4-B, ROUTE-R5, and DISP-R3 (no character hands over a fragment; RETURN/routes may
grant leads or legacy items, never fragments). It is already superseded on paper — decision **D7
is RESOLVED** (`deterministic_special_delivery`), the compendium §4 prescribes the release, and
§8.3 above is the finalized replacement scene. **Pending: rewrite the data** at implementation
(Phase 15 P15.1 / Phase 19 P19.3). Until then routes.json's buyer `return` is a stale draft.

**C2 — routes.json schedules and prerequisites predate the v2 reform.** In data, Ayla
(`scavenger`) still has a visitor window (Days 2/4/5, 13:00–14:00) and **no completion
prerequisite**, and Sam (`archeologist`) has Days 1/3/5 08:00–11:00. The PRD (ROUTE-R2/R8) and
this bible make Ayla the permanent yard NPC (no window) gated on `excavation_tools` for
completion, and give Sam 15:00–17:00 Day 1 + 08:00–11:00 Days 3/5. **Pending: data update** at
P15.1/P15.2.

**C3 — Ayla's authored `return` scene bundles the Sam lead with the vindication.** The final two
blocks of `scavenger.dialogue.return` give the `archeologist_lead` — but v2 (ROUTE-R8) moves the
lead earlier, to free daily contact (§6.4), which is what breaks the dependency cycle. The
vindication scene (§6.5) keeps the rest verbatim. **Pending: split the scene in data** at P15.1.

**C4 — The Master Artifact is unlocked (decision D1, PENDING_TEAM_DECISION).** Every scene that
touches a fragment or the artifact — Shine's wrapped piece (§4.4), the finale assembly and its
join order (§9.1), Portal fact cards, the ledger's decoded contents (§9.3) — is authored
artifact-agnostically here and **must stay generic until `data/artifacts/packets/artifact_lock.json`
resolves**. The lore video and replica also hang on this.

**C5 — Native-speaker review gate (§4-Q / ASSET-R4).** All Hiligaynon/Kinaray-a — the carried-over
scenes *and* every **[NEW]** line in this document — is working-draft quality, written by
non-native hands, and must pass a native-speaker pass before recording/shipping. Record the review
in `docs/reviews/`. Folklore framing (§1.4) is part of the same review.

**N1 — Kinship canonized (new decision, team may revise).** This bible fixes: Yuyu = the player's
grand-uncle, the elder brother of **Lola** (the player's grandmother, who ran the shop and coined
the *alima* saying). Nothing in the repo contradicted it; nothing had pinned it either. If the
team prefers a different kinship (e.g., Yuyu as Lola's husband's brother), only §1.1/§3 prose
changes — no structure depends on it.

**N2 — The spiral mark canonized as Yuyu's mark (new decision).** Previously only Maverick's
unexplained tip. This bible threads it through Lave's beat 3, Maverick's qualifying trade, and the
finale ledger. Cosmetic/lore only — the Spawn Director and carrier logic owe it nothing (§4-C
untouched: any promoted ordinary object remains a valid carrier regardless of marks).

**N3 — Phase-numbering nit.** `data/routes/beats/SCHEMA.md` says the beats are authored in Phase
16; `docs/phase-task.md` P15.1 owns them. Reconcile when implementing (doc fix, either direction).

**N4 — Proposed object templates.** The new beats name working template ids
(`artisan_santo_wood`, `artisan_lola_notes`, `artisan_baul_lid`, `ayla_lunchbox_rusted`,
`sam_banga_cracked`, `sam_transit_jammed`, `buyer_spiral_trinket`). Only the three `auntie_*`
templates exist in `data/objects/objects.json` today; the rest are **authored at P15.1** with
decal sets, tools, and `deliverable: false` where appropriate (following the Auntie pattern).

---

## 13. Review gates

- [ ] Team read-through: flow, beats, endings, item web approved.
- [ ] Native-speaker review of all Hiligaynon/Kinaray-a lines (record in `docs/reviews/`).
- [ ] C1–C3 data updates scheduled into Phase 15 implementation.
- [ ] D1 artifact lock → revisit §4.4, §9.1, §9.3 for the locked artifact's specifics.

*This document is the narrative source of record from its approval onward. Implementation follows
it; where implementation must deviate, update this file in the same change.*

---

## 14. Implemented Story Canon — 2026-07 build updates

> **Status: IN THE BUILD.** Everything below is wired and playable now (Kimi + Claude story
> revamp waves, 2026-07-02 → 2026-07-04). Dialogue remains working-draft quality and falls under
> the same §13 review gates. Where this section contradicts §4–§8, THIS is what currently ships;
> reconcile at the team read-through.

### 14.1 Day 0 — the day Yuyu vanishes (tutorial)

The player (named at save creation, never modelled or gendered) is on vacation at their
grand-uncle **Tito Yuyu's** junk shop. Yuyu teaches the whole trade in one clockless day:
forage → triage → restore → scan → sell → a solo tricycle delivery to the **Mall**. The sun is
scripted, not clocked: **sunrise** through the cleaning lesson, **noon** across the sale and the
mall trip, **sunset** when the player rides home. They return to an **empty shop** — no Yuyu, no
Alya — and only now does **the journal appear on the table**. Reading Yuyu's last letter blacks
the world out into Day 1, Loop 1. Day 0 never recurs (persistent flag).

### 14.2 Day 1 — waking into the loop

The player wakes on the shop floor ("Did I… black out?"). Yuyu's glasses are on the counter, his
jacket on the hook. Stepping outside, **Alya** — Yuyu's goddaughter, the scavenger — is at the
gate; she becomes the daily scrap-sorting partner and the emotional heart of the first loop.

### 14.3 Alya's questline (implemented end-to-end)

* **Q1 — Yuyu's Glasses (yard, any day):** Alya mentions Yuyu lost his glasses — a gift from her
  late father. Find them in the scrapyard, return them → she opens up → **unlocks the Dump Site**
  ("It's where I used to live with my parents.").
* **Q2 — The Cute Bag (Dump Site):** the Dump Site is Alya's childhood home — including her
  family's **typhoon-broken house**, abandoned after the storms. Find the bag her father gave
  her, **clean it, open it** → a note from Papa + a small artifact → **₱1000** and the bag
  becomes a permanent legacy item.
* **Q3 — The Salakot (Day 5):** the forbidden-zone fence is suddenly broken. Inside lies the
  **salakot Yuyu wore when he disappeared**. Bring it back: **Sam** — a woman archeologist who
  never normally visits — appears at the door first, recognises it, and asks to meet at her
  house.
* **At Sam's house:** Sam and Yuyu investigated the Master Artifact together and were ambushed
  in the Dump Site. Sam **buys the salakot back (₱3000)**. Alya realises the bag's lining holds
  something heavy — Sam has the player take the **dirty bag home, clean it, and open it**: the
  archeologist fragment (`fragment_04`), released as a carrier per §4-B/§4-D (never handed over
  seated). **Selling the salakot to any other buyer fails the quest** for the loop.
* Next loop, the Dump Site and Sam's house stay unlocked (persistent leads).

### 14.4 Fragment sourcing canon (team decision, partially implemented)

| Fragment | Keeper | How it's earned |
|---|---|---|
| `fragment_01` | Nang Shine (auntie) | found **inside the shop safe** once the safe code is learned |
| `fragment_02` | Nong Lave (artisan) | given after completing his **final cleaning quest** |
| `fragment_03` | Ayla (scavenger) | open — resolve with the Sam expansion (see N5) |
| `fragment_04` | Sam (archeologist) | the salakot → bag carrier flow above (**implemented**) |
| `fragment_05` | Mr. Maverick (buyer) | his **end-of-Day-5 "last offer"**: ~**₱50,000** — brutal, demands mastery of haggling + clean restorations (mechanics pending; the shipped build still uses §8's spiral-mark trust flow) |

### 14.5 Schedules & spaces (implemented)

* **Auntie** visits days **1 / 3 / 5**; **Artisan** days **2 / 4 / 5**, only after Auntie's
  first quest; **Alya's** questline runs as yard/dump-site interactions on **2 / 4 / 5** and
  never competes for the shop door.
* New walkable spaces: **Dump Site** (2× yard, Alya's ruined house, forbidden zone), **Sam's
  archeologist house**, and the **Mall** (meet-to-sell handoffs + the physical tool shop).

### 14.6 New open flags (append to §12)

**N5 — Scavenger vs archeologist fragment split.** Q3 delivers `fragment_04` via Sam; Ayla's own
`fragment_03` release path is unwritten. Decide when the Sam storyline expands.

**N6 — Maverick day-5 buy-in vs §8 spiral-mark flow.** The ₱50k last-offer canon (14.4)
replaces §8's trust-gift beat; the build still runs §8. Reconcile before Phase 15 dialogue lock.
