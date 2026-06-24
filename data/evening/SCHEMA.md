# data/evening/ — schema contract

Phase 18 authors evening-summary / upkeep plan data here (CLAUDE.md §4-N: the evening loop is
mandatory, not flavor-only). Empty until then; the `.gitkeep` tracks the location.

```json
{
  "schema_version": 1,
  "items": [
    { "record_type": "evening_plan", "id": "<stable_id>", "upkeep": {}, "...": "..." }
  ]
}
```

- `schema_version` required; stable unique `id` per record.
