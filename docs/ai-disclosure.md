# aLima AI Usage Disclosure

This is the running disclosure log for AI used during development or inside the game. Append entries when a new AI tool, model, generated asset, runtime integration, or materially AI-assisted workflow is introduced. Do not remove old entries; add corrections as new dated rows.

## Disclosure Rules

- Record the tool/model, date, area, concrete use, human review, and shipped output.
- Distinguish development assistance from runtime AI visible to players.
- Record generated art, music, voices, dialogue, lore, code, and research separately.
- Historical claims require verification against credible sources; AI output is never a source of fact.
- Never use or imitate copyrighted recordings or undisclosed third-party assets.
- Runtime keys and prompts stay in the backend; no secret is committed to the Godot client.

## Usage Log

| Date | Tool / model | Area | Use | Human review and safeguards | Shipped output |
|---|---|---|---|---|---|
| 2026-06-15 | Kimi Code CLI (Moonshot AI) | Phase 0 clock stabilization and documentation | AI-assisted implementation: added minute-level placeholder clock progression (`7:00 AM` → `7:01 AM`) derived from configurable `seconds_per_hour`; preserved dialogue pause/resume and day/loop wrapping; added focused GUT tests (`tests/test_shop_clock.gd`); updated `docs/phase-task.md`, `docs/PROMPT_CONTEXT.md`, and `CLAUDE.md` with verified command results and the bare-`godot` 4.5.1 blocker. | Team must review the clock math, test coverage, and documentation accuracy. No historical claim, art, audio, dialogue, or runtime AI was generated. | `scripts/shop/shop_controller.gd`, `scenes/ui/shop_hud.gd`, `tests/test_shop_clock.gd` + `.uid`, documentation updates |
| 2026-06-15 | OpenAI Codex | Documentation and repository audit | Reconciled `CLAUDE.md`, `README.md`, and `docs/PRD.md`; created the canonical implementation checklist; inspected the Godot project and Git state. | Team must review all requirements and cultural wording. No historical claim, art, audio, or runtime response was generated. Existing invariants and requirement IDs were preserved. | Documentation only |
| 2026-06-15 | OpenAI Codex | Prompt engineering and repository audit | Inspected all tracked source, scenes, assets, narrative prototypes, project settings, documentation, Git history, and local verification tools; created `docs/PROMPT_CONTEXT.md` as canonical context for future implementation prompts. | Findings distinguish verified runtime behavior from plans and assumptions. No game feature, historical claim, art, audio, or runtime AI output was generated. Team review remains required before using prompts or submission claims. | Documentation only |
| 2026-06-15 | Claude Code (Claude Opus 4.8) | Phase 0 repository and Shop stabilization | AI-assisted refactor: consolidated three duplicate Shop controllers into a typed controller (`scripts/shop/shop_controller.gd`) plus a presentation-only HUD (`scenes/ui/shop_hud.gd`); stabilized `scenes/Shop.tscn` (revealed HUD, removed the stray test button); vendored GUT 9.6.0 with a headless smoke test; added pinned gdtoolkit lint/format config and a GitHub Actions CI workflow; set up the Godot 4.6.3 PATH selection and `.gitignore` hygiene. | Team must review the refactor and tooling. No historical claim, art, audio, dialogue, or runtime AI was generated; existing placeholder Auntie/"coming soon" prose was migrated verbatim from prior code. All checks pass under Godot 4.6.3 (clean import, GUT 7/7, gdformat, gdlint). | GDScript controller/HUD split, GUT smoke test, CI workflow, lint/format + GUT config |
| 2026-06-15 | Kimi Code CLI (Moonshot AI) | Phase 1 core architecture and data | AI-assisted implementation: created typed models (`scripts/models/`), shared enums/validation helpers, `DataRepository` (`scripts/core/data_repository.gd`), core autoloads (`EventBus`, `GameState`, `SaveService`), deterministic run context, and Phase 1 slice JSON fixtures under `data/`; added GUT coverage in `tests/models/` and `tests/core/`; updated `project.godot`, `docs/phase-task.md`, `docs/PROMPT_CONTEXT.md`, `CLAUDE.md`, and this disclosure. | Team must review all schemas, fixture data, and tests. No historical claim, art, audio, dialogue, or runtime AI was generated. Fixtures use explicit placeholder audio-path strategy and artifact-agnostic data. All checks pass under Godot 4.6.3 (import, GUT 49/49, gdformat, gdlint). | Typed models, repository, autoloads, data fixtures, tests, documentation |

## Planned Runtime AI

These systems are planned but are not implemented merely because they appear here:

| System | Planned role | Required safeguards |
|---|---|---|
| Object scanner | Suggest identification, materials, period, condition, relevance, and modification signs | Backend-only call, verified source data, cached fallback, player chooses final verdict |
| Marketplace negotiation | Generate guarded buyer dialogue and offers | Backend-only call, persona/guardrail prompts, rate limiting, sanitized input, cached fallback |
| Cultural Echo source generation | Help produce original regional soundscape source material | Human curation, native-speaker review, no sampling or imitation of protected/traditional recordings |

## Review Gate

Before every milestone submission:

- [ ] Review this log against commits, assets, prompts, runtime dependencies, and generated content.
- [ ] Add missing historical-source and native-speaker review notes.
- [ ] Confirm no secrets, copyrighted source material, or undisclosed AI output ships.
- [ ] Include the final disclosure in the submitted repository and milestone package.
