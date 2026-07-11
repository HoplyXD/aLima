# Credits — aLima

The authoritative attribution list for *aLima*. **Add an entry the moment you bring in any
third-party asset, library, font, or sound** — don't leave it to submission night. Mark your
own work as "original — Team aLima" so original vs. third-party is always unambiguous.

Per-entry fields that matter for licensing: **author** (CC-BY requires it) and **license**.
AI tools/models are logged separately in [docs/ai-disclosure.md](docs/ai-disclosure.md).

> **Mentor ruling (Sir Mark, 2026-06):** free 3D assets from itch.io and other sites are
> allowed **as long as they are CC0 or credited here.** So every third-party asset below
> needs its author + source + license filled in (or be confirmed CC0). Rows marked
> _"to confirm"_ still need the teammate who added them to look up the source/license.

---

## Team

| Name | Roles |
|---|---|
| Francis Gabriel Austria | Lead developer · game design |
| Om Shanti Limpin | Developer · design · narrative · **artist · UI** |
| Jorge Maverick Acidre | Developer · design · **3D modeler · character artist** |

WVSU, Iloilo City.

---

## Engine & Libraries (tools, not assets)

| Component | Author | License | Used for |
|---|---|---|---|
| Godot Engine 4.6.3 | Godot contributors | MIT | Game engine |
| NobodyWho | nobodywho-ooo | EUPL-1.2 | On-device LLM buyer banter (`addons/nobodywho/`) — used UNMODIFIED; see `addons/nobodywho/LICENSE.txt` |
| GUT 9.6.0 | bitwes | MIT | Godot unit testing (`addons/gut/`) |
| gdtoolkit (gdformat/gdlint) | Scony | MIT | GDScript format/lint (dev only) |
| Express + Node deps | respective authors | MIT (per package) | Backend LLM proxy / mock Portal |
| story-teller (2D book with animated 3D pages) | Sanchit Gulati — https://github.com/sanchitgulati/story-teller | The Unlicense (public domain) | The journal's page-turn technique — a 2D book whose pages animate as 3D turnable pages (`scenes/Book/`) |
| 3D book model/scene | _to confirm (teammate sourced separately)_ | _to confirm_ | The journal's 3D book itself (geometry/cover) — different source from story-teller; teammate to confirm |

> **NobodyWho is EUPL-1.2** (copyleft). You CAN ship it in a proprietary/commercial game —
> the copyleft only binds modifications to NobodyWho's *own* source, and we use the addon
> **unmodified**. Obligations: keep its license text with it (`addons/nobodywho/LICENSE.txt`),
> credit it (this file), and point to its source. For the submission build, copy the upstream
> `LICENSE` from the NobodyWho release for the complete legal text.

---

## 3D Models

Grouped by folder under `assets/3d Assets/` (each folder is likely one source pack — confirm
per pack). Original Team aLima work is marked as such; everything else is **to confirm**.

| Model / pack (files) | Author | Source | License |
|---|---|---|---|
| **Oton Death Mask** | Team aLima (Jorge Maverick Acidre) | original | — (original) |
| Bookcase set (`Bookcase/`: Book Stack, Book, Bookcase with Books, Books (1), Magic book, Short Closet, books, brown book) | **Book Stack** — Danni Bittman; _other books to confirm_ | **Book Stack** — Poly Pizza; _others to confirm_ | **Book Stack** — CC-BY; _others to confirm_ |
| Paper (`Paper/`: Debris Papers, Envelopes) | _to confirm_ | _to confirm_ | _to confirm_ |
| Plants (`Plants/Plants - Assorted shelf plants.glb`) | Jakers_H | Poly Pizza | CC-BY |
| Modular Sushi Restaurant Kit | Quaternius | Poly Pizza / https://quaternius.com/packs/sushirestaurantkit.html | CC0 1.0 (public domain) |
| Walls & Floors (`Walls and Floors/`: Door, Floating Shelf, Normal Wall, Wood Floor) | **Floating Shelf** — Zsky; _Door / Normal Wall / Wood Floor to confirm_ | **Floating Shelf** — Poly Pizza; _others to confirm_ | **Floating Shelf** — CC-BY; _others to confirm_ |
| FireLog (`FireLog/`: Fire.glb, trn_Log.fbx) | **trn_Log.fbx** — soi; _Fire.glb to confirm_ | **trn_Log.fbx** — [Medieval Interior Asset Pack (itch.io)](https://soi.itch.io/medieval-interior-asset-pack); _Fire.glb to confirm_ | **trn_Log.fbx** — free for any use incl. commercial; _Fire.glb to confirm_ |
| Apple (`Apple/trn_Apple.fbx`) | soi | [Medieval Interior Asset Pack (itch.io)](https://soi.itch.io/medieval-interior-asset-pack) | Free for any use incl. commercial (itch.io) |
| Candelabra (`Candelabra/trn_Candelabra.fbx`) | soi | [Medieval Interior Asset Pack (itch.io)](https://soi.itch.io/medieval-interior-asset-pack) | Free for any use incl. commercial (itch.io) |
| Candle Cup (`CandleCup/trn_CandleCup.fbx`) | soi | [Medieval Interior Asset Pack (itch.io)](https://soi.itch.io/medieval-interior-asset-pack) | Free for any use incl. commercial (itch.io) |
| Candles (`Candles/`: trn_Candle, trn_CandleFlame, trn_Candle_Half_COL, trn_Candle_full, trn_Candle_half) | soi | [Medieval Interior Asset Pack (itch.io)](https://soi.itch.io/medieval-interior-asset-pack) | Free for any use incl. commercial (itch.io) |
| Fireplace (`Fireplace/`: trn_Fireplace, trn_Fireplace_Tube) | soi | [Medieval Interior Asset Pack (itch.io)](https://soi.itch.io/medieval-interior-asset-pack) | Free for any use incl. commercial (itch.io) |

> The `trn_*.fbx` models (Apple, Candelabra, Candle Cup, Candles, Fire Log, Fireplace) all come
> from **one asset pack**: the **[Medieval Interior Asset Pack by soi](https://soi.itch.io/medieval-interior-asset-pack)**
> (itch.io) — its model list matches these files exactly. soi's page states *"free to use for
> any purpose"* (incl. commercial) rather than a formal CC0 deed, so treat it as free for any
> use / no attribution required; we credit it here anyway (jam rule + good practice).

### Incoming itch.io packs (sourced by Jorge, 2026-06 — not yet imported into `assets/`)

Planned use: the **tools** packs supply restoration/cleaning tools; the **house-items** packs
supply ordinary artifacts to clean. Licenses verified against each pack's itch.io page (and
bundled `Licence.txt` where present).

| Pack | Author | Source | License | Planned use |
|---|---|---|---|---|
| Low Poly Tools | sjolle (Squareish Design) | https://sjolle.itch.io/low-poly-tools | **CC0 1.0** — confirmed by bundled `Licence.txt` and itch page | Restoration **tools** (axe, chisel, saw, hammer, drill, wrench, pliers, screwdriver, …) |
| Low Poly House Items 1 | sjolle (Squareish Design) | https://sjolle.itch.io/low-poly-house-items-1 | **CC0 1.0** — author comment: "CC0. Do as you please with it" | **Artifacts** to clean (books, candlesticks, lamps, vases, cups, picture frames, bell, glasses, compass, …) |
| Low Poly House Items 02 | sjolle (Squareish Design) | https://sjolle.itch.io/low-poly-house-items-02 | **CC0 1.0** — Squareish Design's blanket license (`Licence.txt`); the pack's own page states only "Free of use" | **Artifacts** to clean (cards, chess set, dice, coins, keys, letters, inkwell, matches, nails, needles, paper, …) |

> **CC0 = no attribution required**, but we credit the sjolle/Squareish Design packs here
> anyway (good practice + the jam's content rule).
>
> **Dropped:** Oxygen3D's *Painting Tools Asset Pack*
> (https://oxygen3d.itch.io/painting-tools-asset-pack) was considered but **not used** — its
> itch page states **no license at all** (no CC0/CC-BY), so it fails the jam's "CC0 or credited"
> rule. Tools are sourced from the CC0 Low Poly Tools pack instead.

---

## Audio · Music · SFX

| Asset | Author | Source | License |
|---|---|---|---|
| Universal UI/Menu Soundpack | Nathan Gibson | https://cyrex-studios.itch.io/universal-ui-soundpack?download#google_vignette | CC BY 4.0 |
| BGM music | Maharlikang Bahandi (band) | Provided directly by a band member (a teammate's dad) | CC-BY |
| _(add entries)_ | | | |

---

## Fonts

| Font | Author | Source | License |
|---|---|---|---|
| Augusta | Dieter Steffmann | https://www.dafont.com/augusta.font | 100% Free (dafont) — personal & commercial use |
| Cloister Black | Dieter Steffmann | https://www.dafont.com/cloister-black.font | 100% Free (dafont) — personal & commercial use |
| Roman Antique | Dieter Steffmann | https://www.dafont.com/roman-antique.font | 100% Free (dafont) — personal & commercial use |
| _(add entries)_ | | | |

---

## AI tools & generated content

See [docs/ai-disclosure.md](docs/ai-disclosure.md) — required for the AI Game On! jam.
