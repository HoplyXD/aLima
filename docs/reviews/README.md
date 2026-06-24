# docs/reviews/ — cultural / native-speaker review records

One Markdown record per review sign-off, referenced by `review_refs` in the content manifest and
`reviewer_refs` in the artifact-lock packet. The `ContentManifestValidator` resolves each
`review_refs` entry to a file `docs/reviews/<ref>.md`; a missing file fails validation
(CONTENT-R2, ASSET-R7).

**Record shape** (`<ref>.md`):

```
# <Review title>

- Reviewer (name / role / language competency):
- Material reviewed: <artifact lock, folklore labels, regional language, sensitive material>
- Date:
- Outcome: approved / approved-with-changes / rejected
- Notes:
```

Reviews are a team / cultural-consultant responsibility (P12.1, ASSET-R7); an agent must never
fabricate a reviewer or an approval.
