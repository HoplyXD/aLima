aLima
“Every object remembers. Someone just has to listen.”
A Cozy AI-Powered Historical Restoration Roguelite
GAME DESIGN DOCUMENT — PROJECT PROPOSAL
AI Game On! • AI Fest 2026
Theme: “Giving Our History a New Heartbeat through the Intelligence of Tomorrow”
[DECYFER] • Region VI – Western Visayas • Iloilo City • West Visayas State University
Contents
1. Executive Summary
2. Theme Alignment
3. Game Overview
4. Narrative Premise
5. Design Pillars
6. Core Gameplay Loop
7. Compliance with Official Jam Mechanics
8. The Regional Heritage Artifact (the “Master Artifact”)
9. Game Systems
10. AI Integration & Disclosure
11. Technical Overview
12. Art & Audio Direction
13. Development Roadmap
14. The June 30 Vertical Slice (50% Milestone)
15. Ethics, Copyright & Cultural Responsibility
16. Team
17. Closing: Why “aLima”
Appendix A — Glossary
1. Executive Summary
aLima is a cozy, narrative-driven restoration roguelite set in a small family-owned junk shop in Western Visayas. After the mysterious disappearance of their uncle — a renowned Chronographer — the player inherits a journal bound in Chronos Emulsion, a rare substance that exists outside the flow of time. The journal is the only thing the uncle leaves behind; the player begins with nothing else.
The uncle’s final experiment went catastrophically wrong. While attempting to restore the Master Artifact — a genuine Western Visayas heritage object he believed could mend fractured timelines — it shattered into five fragments, and the uncle himself was scattered across time, existing everywhere and nowhere at once. Before he was lost, he poured what remained into the journal, binding it in Chronos Emulsion. That journal is what now holds the junk shop and its surroundings in a repeating five-day loop. Set into its first page is an empty case shaped for five fragments; until the case is filled, the week cannot truly end.
By day, players sort incoming scrap deliveries, searching for objects that contain Temporal Echoes — the lingering memories, emotions, and stories left behind by previous owners. Through tactile restoration mini-games, artifact authentication, and historical investigation, players recover these forgotten histories. Every restored object clears the static surrounding a memory, allowing fresh ink to appear within the journal as the uncle reconstructs his lost past from within the timestream.
The game’s progression is built around knowledge rather than resources. Each loop resets money, inventory, and upgrades, but discoveries persist. Because the journal sits outside time, anything seated in its case — and every entry written in it — survives the reset, which is exactly why recovered fragments and journal knowledge carry over while money and stock do not. Across multiple loops, players uncover the interconnected stories of five local residents — the lima (“five”) characters — whose lives intersected with the uncle, and to whom he entrusted the five fragments before he vanished.
As knowledge accumulates, the journal evolves into a planning tool, revealing ghostly traces of future events and helping players orchestrate increasingly efficient loops. Each recovered fragment is hidden within the city’s scrap stream through procedural placement, so every playthrough unfolds differently. To locate them, players rely on AI-generated Cultural Echoes — regional melodies, ambient sounds, and Kinaray-a phrases that intensify as they approach a fragment, culminating in the sound of a heartbeat.
Ultimately, players pursue the “Perfect Loop”: a single cycle in which all five fragments are recovered in the right order and seated into the journal’s case. When the case is full and the journal’s final pages are restored, the loop the journal sustains releases, the timeline resumes its natural flow, and the uncle is finally pulled back from the void.
aLima’s answer to the theme is structural rather than decorative. Preservation is not a side activity layered onto the experience — it is the central mechanic, the narrative foundation, and the means by which both history and time itself are restored.
2. Theme Alignment
“Giving Our History a New Heartbeat through the Intelligence of Tomorrow”
• A new heartbeat, literally. The final Cultural Echo — the cue that a fragment is within reach — is a soft heartbeat. Every restoration revives an object that was one conveyor belt away from being melted down.
• The intelligence of tomorrow, in service of yesterday. AI in aLima is diegetic, not a development shortcut: an AI scanner identifies and contextualizes objects, AI-driven buyers negotiate in natural language, AI logic hides the artifact anew for every player, and AI-generated soundscapes guide discovery.
• History passed from hand to hand. “Alima” is the Kinaray-a word for “hand.” The uncle passes history into the protagonist’s hands; the player passes it forward into the community’s digital museum.
• From junk shop to living museum. The game’s economic engine (a scrapyard that destroys objects) and its emotional engine (a museum that saves them) are in constant, playable tension — the exact tension the theme describes.
3. Game Overview
Attribute
Detail
Working Title
aLima
Genre
Cozy restoration sim × narrative roguelite
Platform
PC (Windows) primary; HTML5/web build planned for the AI Fest exhibit booth
Engine
Godot 4.x (planned) — open-source, strong 2D toolset, audio bus control for the Cultural Echo system, exports to desktop and web
Mode
Single-player
Session Length
≈10–13 minutes real per in-game day (1 real minute = 1 in-game hour); ≈1 hour per five-day loop; full story arc 6–10 hours
Target Audience
Teens and adults; players of Unpacking, PowerWash Simulator, Strange Horticulture, and Coffee Talk
Input
Mouse-first; controller- and touch-friendly
Language
English UI; Kinaray-a and Hiligaynon cultural lines, always subtitled
Team Size
3 members — see Section 16

4. Narrative Premise
The protagonist spends their days helping their father run the family junk shop: weighing scrap, sorting bottles, and flattening cardboard. Before mysteriously disappearing, their uncle — a Chronographer who studied the memories hidden within objects — leaves behind a worn journal bound in Chronos Emulsion. It is the only thing he leaves; the artifact’s five fragments are already gone, entrusted to five people he trusted.
The journal contains restoration techniques, sketches, and authenticity notes, but many pages are incomplete or faded. Stranger still, new writing sometimes appears on its own.
Inspired by the inheritance, the protagonist creates a small restoration corner inside the shop. Instead of sending every unusual item to recycling, they rescue selected objects, restoring and investigating them. Some items contain Temporal Echoes — the lingering memories and emotions of past owners. Some help pay the bills. Others reveal forgotten stories from the community.
As more objects are restored, the journal slowly repairs itself, revealing clues about the uncle’s fate and the shattered Master Artifact. Bound in Chronos Emulsion, the journal sits outside the flow of time — it is both what keeps the five days looping and the one thing that survives each reset. Inside its cover is an empty case cut for five fragments, waiting to be filled.
Then, at the end of the fifth day, the week resets. The shop returns to normal, but the journal — and everything seated in its case — remains. To break the loop, the player must find the artifact’s five missing pieces, seat them into the journal’s case, and restore the stories that time itself has forgotten.
5. Design Pillars
Pillar
What It Means in Play
History in your hands
Restoration is tactile and skill-based. AI can identify an object, but only the player’s hands can bring it back — and careless hands can destroy it.
Knowledge is the only currency that survives
The five-day loop wipes money and stock, never learning. The journal, techniques, museum records, and story clues persist — the player gets stronger by understanding, not hoarding.
AI assists; the player judges
The scanner suggests, flags, and contextualizes, but counterfeits ensure it is never blindly trusted. Final verdicts — authentic, replica, modified, significant — belong to the player.
Every find feeds the museum
Culturally significant discoveries flow through the City-Wide Portal into a shared digital museum, turning private play into public memory.

6. Core Gameplay Loop
The daily clock. Each in-game hour passes in one real minute (1 minute = 1 hour). A shop day runs 07:00–20:00, so a full day is about 13 minutes of real play and a five-day loop roughly an hour. NPCs knock only inside fixed time windows (listed per character in 9.7); answering the door is the player’s choice, and an unanswered visitor simply moves on — which can open or close entire routes. (This 1-minute-per-hour clock replaces the earlier 10-minute figure.)
Daily Loop (one in-game day)
1.  Morning delivery. A fresh batch of scrap arrives: recyclables, damaged household objects, old photographs, broken watches, tarnished jewelry, locked containers, forgotten keepsakes.
2.  Triage. Limited storage, time, and money force the player to choose which objects to rescue before the rest is bulk-recycled. A faint glow hints at rarity — but the glow can lie.
3.  Restore. Tactile cleaning mini-games: brushing, wiping, rust removal, polishing, paper care, frame repair, photo restoration, engraving reveals. The wrong tool damages value permanently.
4.  Scan & judge. The AI scanner proposes an identification; the player cross-references the uncle’s journal to confirm, doubt, or overrule it.
5.  Decide. Sell on the AI-driven marketplace, return it to a person it belongs to, or preserve it in the digital museum.
6.  Evening. Journal updates, shop upkeep, story interactions, and preparation for tomorrow’s delivery.
Weekly Meta-Loop. At the end of Day 5, the week resets. Across repeating cycles the player anticipates events, prepares the right tools in advance, completes character story routes, releases fragments into the world, and tracks them down through Cultural Echoes — until all five fragments are seated in the journal’s case and the final cycle unlocks.
7. Compliance with Official Jam Mechanics
This section maps every required AI Game On! mechanic to its concrete implementation in aLima.
Official Requirement
Implementation in aLima
Hidden Heritage Artifact — a secret in-game relic
The Master Artifact, a regional heritage object shattered into five fragments. None is handed to the player at the start — the player begins with only the journal, and all five fragments are hidden in the game world and physically discovered, then seated into the journal’s case.
Regional Artifact — a unique item from local history
A real Western Visayas artifact (the “Master Artifact” is its in-fiction name). Final selection is in progress from four time-themed candidates (Section 8); all systems are artifact-agnostic, so the choice locks in without architectural cost.
AI Procedural Placement — never in the same spot twice
The Spawn Director: a constraint-weighted AI placement system that hides each fragment in a different pile, container, nested object, or day for every player and run, with per-player spawn-history exclusion (9.8).
Discovery Cues — AI-generated “Cultural Echoes”
A four-band proximity audio system: melody, ambient nature sounds, and Kinaray-a phrases that grow louder and clearer with proximity, resolving into a heartbeat at the object (9.9).
API Unlock / ADK — portal call + in-game found screen
An “Artifact Found” screen triggers a call to the City-Wide Portal API, saving the item and its real-world history to the player’s profile. A mock service mirrors the official contract until portal access is granted (9.10).
Digital Museum — portal turns finds into a gallery
An online API museum holds the Gold finds and the Master Artifact, while Purple-and-below items are archived in the Journal (9.10).
Artifact upload + lore video — per official mechanics
The team will produce a physical/visual artifact replica and a lore video framed as animated pages of the uncle’s journal, narrating the artifact’s history and its five-way division (Section 8).

8. The Regional Heritage Artifact (the “Master Artifact”)
Status: the final artifact is intentionally not yet locked. Selection will be completed after cultural research and consultation during the official workshops (June 20 and 27), and locked before asset production for the June 30 milestone. The “Master Artifact” is the uncle’s in-fiction name for a real Western Visayas heritage object — physical, time-themed, and rebuilt from five fragments. Because every system references “the artifact” as a data definition — a name, five components, a history record, and an echo set — the final choice carries no architectural risk.
Candidate Artifacts (all split naturally into five fragments and are physically reassembled)
Candidate
Five-piece logic
Why it fits
The Heirloom Timepiece (frontrunner) — a mantel/pendulum clock from an Ilonggo bahay-na-bato
escapement (the “tick”/heart) · dial face · hands · gear train · pendulum
Literally about time; bench-scale to rebuild; rooted in Iloilo’s ancestral homes; the tick is the heartbeat; “re-forging broken pieces” = restoring it.
The Ampolleta — a Manila-galleon sand-glass
upper bulb · lower bulb · base plate · top plate · pillar frame
The sand running out is the five-day loop; recovered from a Panay-coast wreck of the galleon trade.
The Belfry Clockwork — tower-clock movement in the Jaro Belfry lineage
mainspring · gear train · escapement · dial · strike hammer
Iloilo City’s own landmark, repeatedly broken and rebuilt; the movement is bench-scale even though the tower is not.
The Mariner’s Astrolabe / Nocturnal — a brass sky-clock
mater · rete · alidade · rule · throne ring
Tells the hour by sun and stars; trade-era; assembles cleanly from nested parts.

 
Selection Criteria
• Cultural verifiability with local sources, validated during the official workshops and mentoring.
• Respectful representation — folklore framed as folklore, history framed as history.
• A five-part division that feels natural rather than forced (the division drives the title, the loop, and the ending).
• Strength as a physical artifact upload and a lore-video subject.
• In-game visual readability at small sprite sizes.
Exclusions. The Code of Kalantiaw is excluded as a documented 20th-century hoax (disproven by William Henry Scott, 1968). The Maragtas may inform flavor but is treated as oral tradition, never presented as archaeological fact.
9. Game Systems
9.1 Scrap Deliveries & Triage
Daily deliveries are the game’s card draw. Storage, time, and money are limited, so every rescued object is a bet. Each object carries a faint glow indicating apparent rarity — apparent, because the glow reflects how an object looks, not what it is. Counterfeits can shine; treasures can look like trash.
Glow
Apparent Meaning
White
Common object — typically honest recyclables
Green
Uncommon find
Blue
Potentially valuable antique
Purple
Rare or unusual object
Gold
Historically significant find
Flickering
Connected to a hidden story or character route

9.2 Restoration Mini-Games
Each object type demands its own touch: brushing away dust, wiping grime, lifting rust, polishing metal, cleaning fragile paper, repairing frames, restoring faded photographs, revealing hidden engravings, and inspecting damaged mechanisms. Using the wrong tool can erase details, lower condition, or permanently destroy value. Better tools are purchased with profits from ordinary finds — and some delicate techniques can only be learned from people, not shops.
9.3 The Uncle’s Journal
The journal is the player’s archive, guide, and progression system in one. Every restored object earns an entry: estimated origin, materials, weight range, recommended cleaning method, counterfeit indicators, historical context, price ranges, best condition and sale records, discovered variants, the uncle’s handwritten notes, and AI-generated annotations from verified records. All Purple-rarity-and-below finds are archived here (Gold finds and the Master Artifact go to the online museum — see 9.10). The journal is also the central mystery — sketches of the Master Artifact, faded symbols, and references to the five people the uncle trusted become legible only as the player completes story routes.
Set into the journal’s first page is an empty case shaped for the five fragments of the Master Artifact; the player seats each fragment here as it is recovered. Because the journal is bound in Chronos Emulsion and sits outside time, it is the loop’s anchor — and anything in its case persists across resets. This is the in-fiction reason recovered fragments and all journal knowledge survive each loop while money and stock do not.
9.4 The AI Object Scanner
After cleaning, the protagonist scans objects with an AI-powered phone app, which proposes: object type, possible time period, detected materials, visible markings, condition, cultural relevance, a suggested price range, and signs of modification or counterfeiting. The scanner is an assistant, not an oracle. For suspicious items the player cross-references the journal — a fake may betray itself through wrong weight, modern fasteners, artificial wear, poorly copied engravings, or a suspicious seller history. The final verdict is always the player’s.
9.5 The AI-Driven Marketplace
Restored items are sold here — this is the player’s real economy. Buyers respond through an AI-driven chat with distinct personalities, budgets, and motives: a collector hunting rarities, an aggressive reseller, a student on a budget, a sentimental gift buyer, a hobbyist obsessed with condition — and a suspicious buyer who keeps asking about objects marked with a certain symbol. The player accepts, rejects, or banters/haggles an item’s worth; accurate descriptions and honest restoration raise prices. But profit is not always the right answer — some objects should never be sold.
9.6 The Five-Day Loop
At the end of Day 5, the week restarts. The cause is the uncle’s journal itself: bound in Chronos Emulsion, it anchors the surrounding days in a five-day loop until its fragment-case is filled. The loop is the roguelite engine: early runs reveal opportunities too late; later runs prepare for them in advance.
Resets Each Loop
Persists Forever
Money and temporary upgrades
Journal entries and techniques
Ordinary inventory
Scanned object records
Marketplace listings
Digital-museum entries
Unfinished customer requests
Story clues and unlocked dialogue
Daily event outcomes
Legacy items, leads, and fragments seated in the journal’s case

Example. On Day 2, the Elderly Auntie asks for help restoring a faded photograph. In the first run, the player lacks the photo-restoration kit and can only record a clue. Next loop, the player earns aggressively on Day 1, buys the kit early, and restores the photograph when she returns — revealing the uncle standing beside her family. The same five days now tell a deeper story.
9.7 Character-Driven Story Routes
Five “lima” characters knew the uncle and each hold one fragment. Four of them have a completable character ending; the Mysterious Buyer has no ending of his own but supplies the fifth fragment; the uncle’s own thread (Yuyu) is the final ending. Each route begins as an ordinary customer or buyer; attention, preparation, and the right restorations uncover a complete story.
Route
Arc & Schedule
Completion Reward
Elderly Auntie (Shine)
Restoring her family photographs and keepsakes reveals the uncle in her family’s past. 

Schedule: 12:00pm–2:00pm on Days 1, 3, 5. 

Tie to the uncle: his first love, from long before your grandmother.
Fragment released • code to the uncle’s Safe • clue to the uncle’s locked drawer
Local Artisan (Lave)
An artisan teaches the hardest lesson: preservation is not making things look new — patina is part of the story. 

Schedule: 1:00pm–2:00pm on Days 2, 4, 5 (appears only after you have helped the Elderly Auntie — Lave will not share a shop with the scrap hauler and replaces the Trash Scavenger). 

Tie to the uncle: the Auntie’s grandchild, raised on her stories of the uncle.
Fragment released • delicate restoration tool • access to fragile objects
Trash Scavenger (Ayla)
A scrap hauler convinced her junk is treasure. Humor her and clean her hauls and she pays well; keep your distance from the Elderly Auntie Grandchild and she eventually trusts you. 

Schedule: 1:00pm–2:00pm on Days 2, 4, 5 (only if you have NOT helped the Elderly Auntie). 
Tie to the uncle: the hauler who fed the uncle a steady stream of curios and “treasure.” Holds one of the five fragments.
Fragment released • lead to the Local Archeologist (persists across loops)
Archeologist (Sam)
An archeologist recognizes your tools and tests your dedication, revealing that true mastery lies in re-forging broken pieces while honoring the soul of the original maker. 

Schedule: 3:00pm–5:00pm on Day 1; 08:00am–11:00am on Days 3, 5 (requires the Scavenger’s lead, which persists across loops — so on a later/Perfect Loop he is available from Day 1). 

Tie to the uncle: the last person seen with the uncle before he vanished — the one who got lost in time beside him.
Fragment released • excavation tools • access to Sturdy objects
The Mysterious Buyer (Mr. Maverick) — no ending; support route
A buyer who overpays for objects marked with a certain symbol. Buy from or sell to him on any of Days 1–4, and on Day 5 there`s a chance he hands over the fifth fragment. 


Schedule: appears every day, 5:00pm–6:00pm (and 07:00am–09:00am on Day 5). 

Tie to the uncle: the dealer who for years bought from and sold to the uncle. Holds one of the five fragments.
Fifth fragment delivered on Day 5 • encoded ledger • evidence of the uncle’s unfinished investigation
The Uncle’s Legacy (Yuyu) — final ending
With all five fragments gathered and seated, the journal’s hidden notes finally make sense: the uncle deliberately entrusted the fragments to people he trusted, to be returned only to someone willing to listen.
The Master Artifact made whole • the Perfect Loop • the uncle pulled back from the void

9.8 Fragment Release & AI Procedural Placement (the Spawn Director)
Story gates when. AI decides where. Completing a route never hands the player a fragment directly. Instead, the fragment enters the city’s scrap stream with an in-fiction justification — the Elderly Auntie donates a box of her late husband’s things; the suspicious buyer’s goods are seized and auctioned; the artisan clears out an old workshop. From that moment, the Spawn Director takes over.
• Placement space: delivery piles, shelving, locked containers, specific days and times — and nested inside restorable junk objects (a rusted biscuit tin, a hollow wooden santo, the backing of a framed photo), so discovery flows through the core restoration loop itself.
• Constraint-weighted selection: weighs route state, owned tools, container compatibility, and the player’s own behavior history — deliberately favoring places the player has been neglecting.
• Never-twice guarantee: per-player spawn history is recorded and excluded from future placement; per-run seeds differ across players, so no two discoveries happen in the same place.
• Demonstrability: the 50% gameplay video shows side-by-side runs with the same fragment spawning in different piles, containers, and days.
9.9 Cultural Echoes (Discovery Cues)
When a hidden fragment is nearby, the shop begins to sound different. Echoes are AI-generated, human-curated audio layers mixed by proximity:
Band
Proximity
What the Player Hears
1. The Hum
Far
A low ambient hum, barely separable from shop noise
2. The Melody
Closer
An original folk-style melody in a Western Visayas idiom
3. The Voice
Near
Kinaray-a phrases and ambient sounds tied to the artifact’s story
4. The Heartbeat
At the object
A soft heartbeat — the theme made audible. The object is here.

Accessibility: every echo band has subtitle captions and a visual resonance meter, so the mechanic is playable without audio.
9.10 Portal Unlock & the Digital Museum
The found sequence: discovery → the “Artifact Found” screen (item render, name, origin, condition, fragment count) → API call → a “Portal Unlock” notification revealing the real-world historical fact → a new museum entry.
The game posts each verified discovery (artifact ID, player ID, timestamp, condition, discovery context) to the City-Wide Portal API. Until official portal access is granted, a local mock service mirrors the documented contract one-to-one, so the integration swap is a single endpoint change.
Two archives, by rarity:
• The online API Museum displays the Gold finds and the Master Artifact — the publicly significant pieces, with fact cards, photographs, timelines, regional stories, and character memories.
• The Journal holds Purple-rarity and below — the everyday restored objects and their notes.
Every restored item is a story rescued from being forgotten; together the museum and journal turn the junk shop into a living digital archive.
9.11 Mini-Events
Random and scripted events keep each run distinct: Rush Delivery, Sudden Brownout, Community Request, Suspicious Antique, Rare Buyer Alert, Mystery Box, Rainy-Day Leak, and Tool Breakdown.
9.12 Temporal Echoes (Object Memories)
Distinct from the Cultural Echoes that guide you to fragments (9.9), a Temporal Echo is the memory locked inside an everyday object. Successfully restoring an object releases its Echo: a short memory of a past owner. Each released Echo clears static from a journal page, letting fresh ink surface as the uncle reconstructs his past from within the timestream. Echoes are the connective tissue between ordinary restoration and the larger mystery — some directly reference the five fragment-holders — and they are recorded in the Chronos-bound journal, which is why they persist across loops.
9.13 The Safe & the Locked Drawer
Completing the Elderly Auntie route reveals the code to the uncle’s Safe. Because money resets each loop, the payoff lands in a later loop: once the player knows the code, they can open the Safe at any time, gaining ₱1,000 and — with a chance — a Master Artifact fragment spawned inside. The uncle’s locked drawer is a second gated cache tied to the same route’s clue, holding journal pages and investigation notes.
9.14 Endings & the Perfect Loop
There are five endings: four character endings — Elderly Auntie, Local Artisan, Trash Scavenger, Archeologist — each completed by finishing that person’s route, plus the Uncle’s Legacy (Yuyu) finale. (The Mysterious Buyer has no ending of his own; he supplies the fifth fragment.) Completing none of the routes yields the Neutral outcome: the loop simply repeats.
The Perfect Loop (Yuyu ending) requires all five fragments, gathered in this order within a single cycle:
• Day 1 — Archeologist quest (available from Day 1 once his lead is known from a prior loop).
• Day 2 — Scavenger quest.
• Day 3 — Elderly Auntie.
• Day 4 — Local Artisan.
• Days 1–4 — buy from or sell to the Mysterious Buyer at least once.
• Day 5 — the Buyer hands over the fifth fragment; the player seats it into the journal’s case, completing the Master Artifact. With the case full, the loop the journal sustains releases, the timeline resumes, and the uncle returns.
10. AI Integration & Disclosure
aLima uses AI on two layers: inside the game as live systems the player touches, and in development as disclosed production tools. The team will maintain a complete AI usage log from day one and submit it with every milestone, in line with the jam’s Ethical Use & Copyright rules.
Runtime AI (in-game systems)
System
Planned Tooling
Role & Cultural Function
Object Scanner
LLM API (e.g., Claude) over a curated historical database
Identifies and contextualizes objects against verified Western Visayas records; the player verifies or overrules.
Buyer Negotiation
LLM API with persona and guardrail prompts
Natural-language haggling with distinct buyer motives — modeling how differently communities value heritage.
Spawn Director
Custom constraint-weighted placement logic
Hides each fragment in a new location for every player and run.
Cultural Echo Mixer
Proximity-driven adaptive audio system
Mixes AI-generated regional soundscapes by distance band — the region’s sound becomes the game’s compass.

 
Development AI (production tools, fully disclosed)
Area
Planned Tooling
Use & Safeguard
Art
Image-generation tools
Concepting and texture passes, hand-finished by the team; style-referenced from public-domain cultural documentation only.
Code
Claude Code / AI pair-programming
Systems scaffolding and refactoring; all code reviewed and owned by the team in a public GitHub history.
Music & Audio
AI music generation, human-curated
Original folk-inspired compositions only — no existing recordings of traditional songs are sampled or reproduced.
Story & Text
LLM drafting, human-edited
Dialogue and lore drafts edited for tone and reviewed for cultural accuracy; Kinaray-a lines reviewed by native speakers.

11. Technical Overview
• Engine: Godot 4.x — open-source, excellent 2D tooling, fine-grained audio bus control for the four-band echo mixer, and one-click exports to Windows and HTML5 for the AI Fest booth.
• Architecture: game client ↔ a lightweight Node.js/Express service ↔ the City-Wide Portal API. LLM calls run server-side with rate limiting and cached fallbacks. The team’s lead developer ships production MERN systems, so this layer reuses proven tooling.
• Mock-first portal integration: a local mock service implements the official ADK/API contract; once portal access is granted, integration is a single endpoint swap.
• Offline resilience: the exhibit build ships with cached scanner annotations and pre-generated negotiation content, so the booth demo never depends on venue internet.
• Data: a JSON-defined object database keeps the design artifact-agnostic; per-player spawn history backs the never-twice placement guarantee.
• Repository: public GitHub repository initialized June 1, with a commit history demonstrating the project is built from scratch within the jam window.
12. Art & Audio Direction
Art. Warm, hand-crafted 2D in a pixel/painted hybrid. The palette is golden-hour junk shop: rust, brass, varnished wood, late-afternoon light through dusty louvers. The UI lives inside the fiction — journal paper, masking tape, ballpoint ink. Props are unmistakably Filipino: weighing scales, soft-drink crates, sari-sari signage, santo figures, capiz panels.
Audio. An original folk-inspired score in a Western Visayas idiom — AI-generated, human-curated, and never sampling existing recordings. Kinaray-a and Hiligaynon lines are recorded with native speakers where feasible. The shop itself is an instrument: rain on the roof, the scale’s creak, a tricycle passing — and underneath it all, sometimes, a hum that should not be there.
13. Development Roadmap
The roadmap is built backwards from the official jam milestones.
Dates
Milestone
Focus
June 1
Repo + proposal
GitHub initialized; concept locked; this document
June 12–19
Sprint 1 — core slice
Shop scene, delivery/triage, two cleaning mini-games, object data pipeline
June 20
Official Workshop 1
Apply feedback; artifact candidate review with mentors
June 21–26
Sprint 2 — jam mechanics
Spawn Director, Cultural Echo mixer, Artifact Found screen, mock portal API
June 27
Official Workshop 2
Final artifact lock; ADK/API clarifications
June 28–30
50% submission
Record the three required video beats, finalize AI disclosure list, submit gameplay video + repo (June 30)
July 7
Top 10 announcement
—
July 11
Mentoring session
Refinement plan with mentors
July 12–Aug 2
Content build
Full five-day loop, marketplace AI, all five character routes, museum gallery, final-cycle ending
Aug 3–5
AI Fest, Iloilo City
Exhibit booth (web/offline build); pitching and judging on August 4

14. The June 30 Vertical Slice (50% Milestone)
The 50% build is scoped around exactly what the submission requires to demonstrate, with the rest of the design deferred rather than diluted.
Required in the Gameplay Video
How aLima Shows It
The artifact spawning in different locations
Side-by-side footage of multiple runs: the same fragment hidden in a different pile, container, nested object, and day across three or more seeds
The player finding the item using the “Echo” cues
One complete discovery sequence with all four echo bands audible and captioned, plus the on-screen resonance meter
The API notification showing the “Portal Unlock”
The Artifact Found screen → live API call → Portal Unlock notification with the real-world historical fact → new museum entry

Included in the slice: one shop space; delivery and triage; two to three restoration mini-games; scanner v1 (cached annotations); Spawn Director v1; Cultural Echoes v1; Artifact Found screen with mock portal API; journal v1; and the Elderly-Auntie photograph beat as the emotional showcase.
Deferred to the finalist phase: the full five-day loop economy, live marketplace negotiation AI, the remaining four character routes, and museum gallery polish — all documented here so judges can evaluate the complete design alongside the playable slice.


15. Ethics, Copyright & Cultural Responsibility
• Full AI disclosure. A complete list of AI tools used (art, code, story, music) and how each helped highlight regional culture is maintained from day one and submitted with every milestone.
• Original assets only. No third-party IP; visual and audio assets are original or referenced exclusively from public-domain cultural documentation.
• No harmful or misleading content. Scanner facts derive from verified records; legend is always framed as legend. The game never presents folklore as archaeological fact.
• Cultural respect. Artifact selection and Kinaray-a usage are validated with local sources and native speakers, with consultation during the official workshops and mentoring sessions.
• Player data. Portal synchronization is limited to gameplay-relevant data (discoveries, condition, timestamps) — nothing more.
16. Team
Composition: Student • Region: VI – Western Visayas • City: Iloilo City • School: West Visayas State University
Member
Role
Background
Francis Gabriel Austria
Lead Developer
BS Computer Science, WVSU; ships production full-stack (MERN) systems as a working freelance developer
Om Shanti Limpin
Developer / Design / Narrative
BS Computer Science, WVSU
Jorge Maverick Acidre
Developer / Design
BS Entertainment and Multimedia in Computing, WVSU

All members 18 or older, each belonging to this team only; the team is within the 1–3 member limit.
17. Closing: Why “aLima”
The title comes from the Kinaray-a word alima — “hand.” Hidden inside it is lima — “five.” Five days in every loop. Five fragments of one artifact. Five people the uncle trusted. Hands-on restoration. History handed from an uncle to a nephew, from strangers to a shopkeeper, from a junk shop to a city’s digital museum. The title also nods quietly to the five-peso coin — an ordinary-looking object that still carries meaning beyond its material value.
AI in aLima finds the pattern, names the period, suggests the price. But technology alone cannot restore what has been forgotten. Someone still has to pick the object up, clean it carefully, listen to its story — and place it in another person’s hands. That is how history gets a new heartbeat.

Appendix A — Glossary
• Chronographer — the uncle’s profession: a scholar of the memories held within objects.
• Chronos Emulsion — the substance binding the journal; it exists outside time, anchors the five-day loop, and preserves anything seated in the journal’s case (knowledge and recovered fragments).
• Master Artifact — the uncle’s name for the real Western Visayas heritage object, shattered into five fragments.
• The Journal’s Case — the empty fitting inside the journal, shaped for the five fragments; filling it reassembles the Master Artifact and breaks the loop.
• Fragment — one of the five pieces of the Master Artifact; each held by one of the five characters, then hidden by the Spawn Director.
• Temporal Echo — a memory locked inside an everyday object, released by restoring it; clears journal static (9.12).
• Cultural Echo — the four-band proximity audio that guides the player to a hidden fragment (9.9).
• Perfect Loop — the single cycle in which all five fragments are recovered in order and seated, unlocking the Yuyu ending.


