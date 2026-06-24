# data/temporal-echoes/ — schema contract

Phase 15 authors the **15 Temporal Echo memories** and **10 mystery-journal pages**
(CLAUDE.md §4-M, CONTENT-R6) here, connecting ordinary objects to all five fragment-holder routes
and the uncle. Distinct from the slice `data/echoes/` audio echo-sets: these are the narrative
Temporal Echo memories + mystery pages. Empty until Phase 15; the `.gitkeep` tracks the location.

```json
{
  "schema_version": 1,
  "items": [
    { "record_type": "temporal_echo", "id": "<stable_id>", "route_ref": "...", "...": "..." },
    { "record_type": "mystery_page", "id": "<stable_id>", "page_index": 0, "...": "..." }
  ]
}
```

- `schema_version` required; stable unique `id` per record.
- Folklore is framed as folklore, never archaeological fact (§4-L).
