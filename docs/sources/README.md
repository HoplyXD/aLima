# docs/sources/ — verified historical source records

One Markdown record per cited source, referenced by `source_refs` in the content manifest, the
artifact-lock packet (`data/artifacts/packets/artifact_lock.json`), and museum fact cards
(`data/museum/`). The `ContentManifestValidator` resolves each `source_refs` entry to a file
`docs/sources/<ref>.md`; a missing file fails validation (CONTENT-R2, ASSET-R5).

**Record shape** (`<ref>.md`):

```
# <Source title>

- Author / institution:
- Citation / locator:
- Accessed / verified date:
- Used for: <which facts/IDs this source backs>
- Notes: <folklore is labelled as folklore; Code of Kalantiaw excluded as fact (§4-L)>
```

Records are authored by the team during the workshop / cultural consultation (P12.1) and Phases
13–17. AI output is never a source of fact.
