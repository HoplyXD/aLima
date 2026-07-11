# Museum Placeholder Source

This file is a structural placeholder referenced by `data/museum/museum_records.json`
while the records carry `verification_status: source-verification-pending`.

It does **not** contain verified historical claims. Once the team/cultural consult
locks the Phase 12 artifact and sources, this placeholder must be replaced with
real source records (one per `source_ref`) that cite credible, reviewed material
for every museum fact.

Rules:

- Every `verified` record in `data/museum/museum_records.json` must point to a
  real file under `docs/sources/<source_ref>.md`.
- Verified records must not contain "PENDING" placeholder text.
- No AI-generated output may be used as a source of historical fact.
