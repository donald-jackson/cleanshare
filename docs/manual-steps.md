# Manual Steps — Human-Only Checklist

This is the list of actions the build agent **cannot** perform. They require interactive
Apple ID login, paid accounts, secret material, domain ownership, or a human in the loop.
Work through them in order; each has a one-line "how" pointer. Related detail lives in
PLAN.md §11.7, §12, §13, §14.3, and §17, plus [`codesigning.md`](./codesigning.md) and
[`release-process.md`](./release-process.md).

CleanShare is on-device only — there is no backend, no analytics, no service credentials.
Everything below is Apple-side identity, signing, DNS, or community plumbing.

---

## Apple Developer & identity

- [ ] **Enroll in the Apple Developer Program** ($99/yr). How: https://developer.apple.com/programs/enroll/
      — individual or org. Record your **Team ID** (Membership page) for `FASTLANE_TEAM_ID`
      and `Config/Local.xcconfig` (`DEVELOPMENT_TEAM_OVERRIDE`).
- [ ] **Reserve the App Store Connect bundle IDs.** How: App Store Connect → Certificates,
      Identifiers & Profiles → Identifiers → register **both**:
      - `solutions.ddj.cleanshare` (host app)
      - `solutions.ddj.cleanshare.ShareExtension` (share extension)
      Enable the **App Groups** capability (`group.solutions.ddj.cleanshare`) on the host ID.
- [ ] **Create the App Store Connect app record** for `solutions.ddj.cleanshare`. How: App Store
      Connect → My Apps → "+" → New App. Name "CleanShare", Photo & Video / Utilities, 4+.

## Code signing (Fastlane Match)

- [ ] **Create the private `cleanshare-signing` GitHub repo.** How: a brand-new **private**
      repo (e.g. `<maintainer>/cleanshare-signing`) that Match uses to store encrypted certs
      and provisioning profiles. Never make it public. See PLAN.md §12.1.
- [ ] **Run Match init + appstore LOCALLY the first time** on the maintainer's Mac (CI is
      `readonly` and will never create/revoke certs). How:
      ```bash
      bundle exec fastlane match init        # point storage at the signing repo URL
      bundle exec fastlane match appstore     # generates the distribution cert + profiles
      ```
      Use a strong `MATCH_PASSWORD`; you'll add it to GitHub secrets below.

## GitHub `release` environment secrets

Add these under Settings → Environments → `release` → Environment secrets (see PLAN.md §11.7):

- [ ] `MATCH_PASSWORD` — symmetric passphrase encrypting the Match git repo.
- [ ] `MATCH_GIT_URL` — URL of the private `cleanshare-signing` repo.
- [ ] `MATCH_GIT_BASIC_AUTHORIZATION` — base64(`user:ghp_xxx`) with `repo` scope on the
      signing repo. How: `printf 'user:ghp_xxx' | base64`.
- [ ] `ASC_KEY_ID` — App Store Connect API key ID. How: App Store Connect → Users and Access
      → Integrations → App Store Connect API → generate a key (Admin or App Manager role).
- [ ] `ASC_ISSUER_ID` — the Issuer ID shown on that same API keys page.
- [ ] `ASC_API_KEY_BASE64` — base64 of the downloaded `.p8` private key. How:
      `base64 -i AuthKey_XXXX.p8 | pbcopy`.
- [ ] `FASTLANE_APPLE_ID` — the Apple ID email used for the developer account.
- [ ] `FASTLANE_TEAM_ID` — the Team ID recorded during enrollment.

## Domain & landing page (`cleanshare.dev`)

- [ ] **Buy the `cleanshare.dev` domain.** How: any registrar (Google Domains successor,
      Namecheap, Cloudflare, etc.). See PLAN.md §14.3.
- [ ] **Add DNS A records pointing at GitHub Pages.** How: at your registrar, create four
      `A` records for the apex `cleanshare.dev`:
      - `185.199.108.153`
      - `185.199.109.153`
      - `185.199.110.153`
      - `185.199.111.153`
- [ ] **Configure the GH Pages custom domain.** How: repo Settings → Pages → Custom domain
      → `cleanshare.dev` → Save, then enable "Enforce HTTPS" once the cert provisions. The
      `marketing/landing/CNAME` file already contains `cleanshare.dev`.
- [ ] **Substitute the real Team ID in the Universal Links AASA file before deploying.** How:
      edit `marketing/landing/.well-known/apple-app-site-association` and replace the
      `<TEAM_ID>` placeholder in `"appID": "<TEAM_ID>.solutions.ddj.cleanshare"` with your Apple
      **Team ID** (same value as `DEVELOPMENT_TEAM_OVERRIDE` in `Config/Local.xcconfig`). The
      file must stay valid JSON with **no** `.json` extension and no comments — Apple's
      parser rejects both. It is served from `https://cleanshare.dev/.well-known/apple-app-site-association`
      and backs the `applinks:cleanshare.dev` associated domain that powers the share
      extension → host handoff. See PLAN.md §6.3.

## App Store submission

- [ ] **Submit the App Store privacy questionnaire** with **every category answered "No"**
      ("Data Not Collected"). How: App Store Connect → App Privacy. CleanShare collects
      nothing; do not check any data type. See PLAN.md §13.2.
- [ ] **Enable the TestFlight public link** for the beta channel. How: App Store Connect →
      TestFlight → enable public link after the first build passes Beta App Review.
      See PLAN.md §13.6.

## Community & branding

- [ ] **Create the `conduct@cleanshare.dev` mailbox** (or update `CODE_OF_CONDUCT.md` with a
      real contact address). How: set up email forwarding/hosting on the domain, then verify
      the address in the Code of Conduct matches. See PLAN.md §17.
- [ ] **Commission a designer for the real app icon.** The committed icon is just a "CS"
      wordmark on the teal→indigo gradient (placeholder from task 4.07). How: brief a
      designer with the icon concept in PLAN.md §14.1 (photo thumbnail + three rising
      sparkles, vibrant teal→indigo gradient, dark mode + iOS 18 tinted variant), then
      replace the generated asset.
