# data/counterfeits/ — schema contract

Phase 13 authors the **6 journal-solvable counterfeit variants** (CLAUDE.md §4-M, CONTENT-R8)
here. Counterfeits are detectable only by cross-referencing evidence (§4-G); the player makes the
final call. Empty until Phase 13; the `.gitkeep` tracks the location.

```json
{
  "schema_version": 1,
  "items": [
    {
      "record_type": "counterfeit_variant",
      "id": "<stable_id>",
      "template_id": "<scrap_object_template id>",
      "tells": ["..."],
      "cross_reference_refs": ["..."]
    }
  ]
}
```

- `schema_version` required; stable unique `id` per record.
- `template_id` references a `data/objects/` template (never a fragment — §4-C).
