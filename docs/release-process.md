# Release Process

This is the maintainer checklist for shipping a CleanShare version to TestFlight and the
App Store. Releases are driven by an annotated, signed git tag that triggers
`.github/workflows/release.yml`. Signing prerequisites are in
[`codesigning.md`](./codesigning.md); the secrets list is in PLAN.md §11.7.

CleanShare is on-device only — there is no backend to deploy. A "release" means a signed
binary uploaded to App Store Connect plus its metadata, screenshots, and review notes.

---

## 1. Pre-flight checks

Before tagging, on `main` with a clean working tree:

- [ ] `main` is green: PR CI (`pr.yml`), CodeQL (`codeql.yml`), and the nightly build all
      passing.
- [ ] `make verify-strip` passes locally (metadata is actually stripped from fixtures).
- [ ] `bash scripts/check-no-trackers.sh` passes (no forbidden third-party SDK symbols).
- [ ] `CHANGELOG.md` has an entry for the version you're about to cut.
- [ ] Version string in the project / Info.plist matches the tag you'll push (build number
      is set automatically by Fastlane from `GITHUB_RUN_NUMBER`).
- [ ] Fastlane metadata under `fastlane/metadata/` and review notes under
      `fastlane/review_information/` are current.
- [ ] Screenshots in `screenshots/iPhone-6.9/` and `screenshots/iPad-13/` are up to date.
- [ ] `release` environment secrets are present in GitHub (see PLAN.md §11.7).

---

## 2. Tag and push

Create an **annotated, signed** tag and push only the tag:

```bash
git tag -sa v0.X.Y -m "CleanShare v0.X.Y"
git push origin v0.X.Y
```

The tag matches the `v*.*.*` pattern that `release.yml` listens for. (You can also run the
workflow manually via **Actions → Release → Run workflow** and pick the `release` or
`beta` lane.)

---

## 3. Watch `release.yml`

The workflow runs on `macos-15` against the `release` environment, which is a **manual
approval gate** — a maintainer must approve the run in the GitHub UI before it proceeds.

It then:

1. Decodes `ASC_API_KEY_BASE64` to `~/.private_keys/AuthKey.p8`.
2. Regenerates the Xcode project (`./scripts/generate-project.sh`).
3. Runs `bundle exec fastlane release` (or `beta` if you chose that lane).

The `release` lane bumps the build number, fetches appstore signing via Match
(`readonly`), builds with `gym`, uploads the build with `pilot`, and stages metadata +
screenshots with `deliver` using **`submit_for_review: false`**. Nothing is auto-submitted
to App Review.

Watch the run to completion:

```bash
gh run watch
```

---

## 4. TestFlight

After `pilot` uploads, the build appears in **App Store Connect → TestFlight**. Apple
processes the binary (a few minutes to an hour). Once processing finishes:

- Verify the build shows up under the internal/Nightly TestFlight group.
- Smoke-test on a real device through TestFlight: run the share-sheet flow on a photo and a
  video, confirm the cleaned output and that the share sheet re-presents.
- Provide export-compliance answers if prompted (CleanShare does no non-exempt
  encryption).

The optional `nightly.yml` workflow uploads `main` to a "Nightly" TestFlight group every
day; that path uses the same signing but is not part of a tagged release.

---

## 5. App Store Connect — manual submit

`deliver` already staged the metadata, screenshots, and the build selection, but it did
**not** submit. In App Store Connect:

1. Open the version you just staged under **App Store → iOS App**.
2. Confirm the uploaded build is attached.
3. Confirm metadata, screenshots, age rating, and the **App Privacy** answers (every
   category is "Data Not Collected").
4. Press **Submit for Review**.

---

## 6. Post-approval release

When Apple approves, the version moves to **Pending Developer Release** (assuming you chose
manual release, which is the default for CleanShare so the maintainer controls timing).

1. Press **Release this version** when ready.
2. The build goes live on the App Store (rollout is typically within a few hours).
3. Push the corresponding GitHub release notes / mark the GitHub tag's release published if
   you maintain one.

---

## Pre-release device smoke test

CI builds the targets and `swift test` covers the Core engine, but the
extension → host handoff can only be exercised on a real device through the real
share sheet. We shipped a regression once (9.01) where the extension fell back to
the Files dialog instead of re-presenting the system share sheet, and no automated
test caught it. **Run this checklist on a physical iPhone before every TestFlight
upload.**

Install the build under test (TestFlight or a development build), then:

1. **Photo from Photos app.** Open Photos → pick a photo → Share → **CleanShare**.
   Verify the **system share sheet** re-appears with the cleaned file (NOT the
   Files "Save to…" dialog).
2. **Photo from WhatsApp.** Open WhatsApp → a chat → attach/share a photo →
   **CleanShare**. Verify the share sheet appears so you can route the cleaned
   photo onward.
3. **Live Photo from Photos app.** Open Photos → pick a Live Photo → Share →
   **CleanShare**. Verify the **consent sheet** appears first (still image vs.
   keep motion), then the share sheet after you choose.
4. **1-minute 4K video.** Share a ~1-min 4K clip → **CleanShare**. Verify the
   share sheet appears within ~1 second (passthrough is near-realtime — a long
   stall means re-encoding regressed).
5. **Offline / lossy network.** Settings → Developer →
   **Network Link Conditioner** = 100% Loss (or enable Airplane Mode), then
   repeat steps 1–4.
   CleanShare must still work end to end — it does zero network I/O, so total
   packet loss must not change any behaviour.

If any step lands on the Files dialog, stalls, or fails, **do not ship** — file
it against the handoff ladder in `ShareViewController` and re-test.

---

## Rollback / hotfix

There is no server to roll back. If a shipped build has a serious bug:

- Cut a patch version (`v0.X.Y+1`) through the same flow.
- For a build still in review, you can **Reject** the submission in App Store Connect and
  resubmit.
- For a live build, expedited review can be requested from Apple in genuine emergencies.
