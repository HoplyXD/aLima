# data/marketplace/ — schema contract

Phase 18 (economy & disposition) authors marketplace listing/offer data here. Empty until then;
the `.gitkeep` keeps the versioned location tracked. `DataRepository` does **not** load this
directory yet — a loader is added with the content in Phase 18.

Each JSON file uses the standard envelope:

```json
{
  "schema_version": 1,
  "items": [
    { "record_type": "marketplace_listing", "id": "<stable_id>", "...": "..." }
  ]
}
```

- Top-level `schema_version` (currently `1`) is required and validated.
- Every record has a stable string `id`; duplicate IDs fail validation.
- Buyer personas live in `data/buyers/`; this directory is for listings/offers, not personas.
