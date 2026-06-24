# docs/provenance/ — asset & content provenance records

One Markdown record per shipped asset / text source / generated intermediate, referenced by
`provenance_refs` in the content manifest. The `ContentManifestValidator` resolves each
`provenance_refs` entry to a file `docs/provenance/<ref>.md`; a missing file fails validation
(CONTENT-R2, ASSET-R5). Unresolved provenance blocks release.

**Record shape** (`<ref>.md`):

```
# <Asset / content title>

- Origin: original | CC0 | credited third-party (author · source · license)
- Linked CREDITS.md entry: <yes/no — every third-party asset must be in CREDITS.md, §4-L>
- AI involvement: <none | tool/model; cross-reference docs/ai-disclosure.md row>
- Used for: <which content IDs>
- Verified by / date:
```

No third-party IP; audio is original / folk-*inspired*, never sampled (§4-L).
