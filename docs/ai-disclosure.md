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
| 2026-06-15 | OpenAI Codex | Documentation and repository audit | Reconciled `CLAUDE.md`, `README.md`, and `docs/PRD.md`; created the canonical implementation checklist; inspected the Godot project and Git state. | Team must review all requirements and cultural wording. No historical claim, art, audio, or runtime response was generated. Existing invariants and requirement IDs were preserved. | Documentation only |

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
