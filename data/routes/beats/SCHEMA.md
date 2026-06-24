# data/routes/beats/ — schema contract

Phase 16 authors the **3 progression beats** for each of the five non-finale routes (Auntie,
Artisan, Scavenger, Archeologist, Buyer), four character endings, the Neutral continuation, and
the Yuyu finale (CLAUDE.md §4-M, CONTENT-R7) here.

**Why a subdir:** `DataRepository` loads every `.json` directly under `data/routes/` through the
route/container parser, which would reject an unrelated stub. This `beats/` subdir is **not**
recursed by `_load_directory`, so the contract lives here without tripping the loader. A dedicated
beat loader is added with the content in Phase 16. Empty until then; the `.gitkeep` tracks it.

```json
{
  "schema_version": 1,
  "items": [
    {
      "record_type": "route_beat",
      "id": "<stable_id>",
      "route_id": "<character_route id>",
      "beat_index": 0,
      "object_template": "<scrap_object_template id>"
    }
  ]
}
```

- `schema_version` required; stable unique `id` per record.
- `route_id` references a `data/routes/` route; `object_template` references a `data/objects/`
  template.
