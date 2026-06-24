# data/museum/ — schema contract

Phase 17 authors the **5 fragment fact cards**, the **1 assembled-artifact record**, and the
**≥5 additional Gold museum discoveries** (CLAUDE.md §4-M, CONTENT-R9) here, each backed by a
verified source reference in `docs/sources/`. `gold` finds + the Master Artifact route to the
online API museum (§4-F). Empty until Phase 17; the `.gitkeep` tracks the location.

```json
{
  "schema_version": 1,
  "items": [
    { "record_type": "fragment_fact_card", "id": "<stable_id>", "source_ref": "...", "...": "..." },
    { "record_type": "museum_discovery", "id": "<stable_id>", "source_ref": "...", "...": "..." }
  ]
}
```

- `schema_version` required; stable unique `id` per record.
- Every fact requires a verified `source_ref`; AI output is never a source of fact (§4-L).
