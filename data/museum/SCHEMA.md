# data/museum/ — museum content contract

This directory holds the artifact-agnostic museum content contract. The final
history is gated on **verified sources** (`docs/sources/`, §4-L) and the
**Phase 12 artifact lock** (`data/artifacts/packets/artifact_lock.json`). Until
those gates close, every record here is a structural placeholder with
`verification_status: source-verification-pending`; AI output is never entered as
a source of fact.

## File

- `museum_records.json` — the single authored record file.

## Record shape

```json
{
  "schema_version": 1,
  "records": [
    {
      "id": "<stable_unique_id>",
      "record_type": "fragment_fact_card" | "assembled_artifact" | "gold_discovery",
      "subject_ref": "<fragment_id_or_artifact_id_or_empty>",
      "title": "<display title>",
      "fact_card": "SOURCE VERIFICATION PENDING — ...",
      "photo_ref": "<optional res:// path or empty>",
      "timeline_entry": "<pending or verified timeline note>",
      "regional_story": "<pending or verified regional note>",
      "character_memory_refs": ["<character_id>"],
      "source_ref": "<planned source id in docs/sources/>",
      "verification_status": "source-verification-pending" | "artifact-lock-pending" | "verified"
    }
  ]
}
```

## Validation rules (see `scripts/museum/museum_content_validator.gd`)

1. `schema_version` must be `1`.
2. Every record must have a unique `id` and a valid `record_type`.
3. `source_ref` must be present for all records.
4. Records with `verification_status == "verified"` must have a resolvable
   `docs/sources/<source_ref>.md` file; pending statuses do not fail validation
   but produce warnings so the gate is visible.
5. Count check (Phase 16 contract): at least 5 `fragment_fact_card` records,
   exactly 1 `assembled_artifact` record, and at least 5 `gold_discovery`
   records. The file currently meets these counts with placeholder pending
   content; the facts themselves become real only after source verification.

## Phase note

The old SCHEMA stub said "Phase 17 authors" the records. That was a phase-numbering
drift. The real gate is the verified source packet + artifact lock (Phase 12 / P12.1
and CONTENT-R1). Phase 16 stands up the contract, validation, and pending stubs;
final verified text is authored by the team/cultural consult once the gates close.
