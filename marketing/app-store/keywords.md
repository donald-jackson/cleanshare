<!-- ASO research + chosen App Store keyword string. -->
<!-- The chosen CSV below is extracted verbatim into fastlane/metadata/en-US/keywords.txt. -->
<!-- Edit here first, then regenerate keywords.txt to match. -->

# App Store Keywords (ASO)

The App Store gives one 100-character keyword field (comma-separated, no spaces
counted toward search relevance the way you'd hope — Apple ignores spaces after
commas for indexing but they still cost characters, so we omit them). This file
records the chosen string, the alternatives we weighed, and the plan to iterate.

## Chosen (v1.0)

```
privacy,photo,metadata,exif,gps,share,strip,clean,open source,free
```

This is 64 characters — comfortably under the 100-char limit, leaving headroom
to add destination-app terms in v1.1 (see A/B plan). The ten terms cover the
three ways people actually search for this tool: by the *concern* (`privacy`,
`metadata`, `exif`, `gps`), by the *action* (`share`, `strip`, `clean`), and by
the *qualities* that win the install once they've found us (`open source`,
`free`). `photo` is the single highest-volume head term we can plausibly rank
for as a niche utility; pairing it with the long-tail privacy terms is how a
small app gets discovered without competing head-on with photo editors.

## Alternatives considered

| Keyword | Why considered | Why rejected |
|---|---|---|
| `viewexif` | Direct competitor app name; people search competitor names | Branded competitor term — low intent for us, and Apple may treat ranking on a rival's name unfavorably; better to win generic `exif` |
| `metapho` | Another competitor (metadata viewer/editor) people search by name | Same branded-competitor problem; spends a slot on a term that signals "viewer," not "stripper" |
| `anonymous` | Captures the privacy/anonymity intent behind stripping metadata | Too broad and ambiguous — dominated by messaging/VPN/chat apps; our relevance signal would be drowned out |
| `location` | High-volume, matches the GPS-removal benefit | Almost entirely captured by Maps/navigation/find-my intent; `gps` is the more precise, less-contested term for our use case |
| `scrub` | Vivid verb for what the app does to metadata | Lower search volume than `strip`/`clean`; redundant with two action verbs we already include |
| `whatsapp` | Names the most common share destination | Held back for the v1.1 A/B test rather than spent in v1.0 baseline (see below) |

## A/B test plan for v1.1+

**Hypothesis:** Searchers think in terms of *where* they're sending the photo
("clean photo for whatsapp") more than the abstract action. Adding
destination-app names will capture higher-intent long-tail traffic.

**Variant B keyword string:** drop the two most generic action terms (`clean`,
`strip` — already strongly implied by `metadata`+`exif`) and add destination
terms:

```
privacy,photo,metadata,exif,gps,share,open source,free,whatsapp,signal,messenger
```

**How to measure:** Ship Variant B in a single point release and watch App Store
Connect → App Analytics for ~2–3 weeks per variant (sequential, not concurrent —
the keyword field can't be split-tested natively):

1. **Search-tab impressions** — does total impression volume rise? Confirms the
   new terms are actually surfacing the app.
2. **Tap-through rate** (impressions → product-page views) from the Search
   source — confirms the new traffic is relevant, not just noise.
3. **Conversion** (product-page views → downloads) from Search — the bottom-line
   signal that destination-term searchers install at least as well as the
   baseline.

Keep the winner; if Variant B's conversion drops despite higher impressions,
revert to the v1.0 string — that means the destination traffic was lower-intent.

## Title-field keywords

The app **name** ("CleanShare") and **subtitle** ("Strip metadata before
sharing") are already indexed by App Store search and weighted *more* heavily
than the keyword field. So the words `clean`, `share`, `strip`, `metadata`, and
`sharing` already earn ranking from the title/subtitle. We deliberately do not
burn keyword-field slots re-stating "cleanshare" or "before sharing" — those
characters go to terms the title doesn't already cover (`privacy`, `exif`,
`gps`, `open source`, `free`).
