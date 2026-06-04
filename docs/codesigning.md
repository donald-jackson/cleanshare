# Code Signing

CleanShare ships from one maintainer's Apple Developer Program account, but anyone
can clone the repo and run the app on their own device or simulator without that
account. Two flows are documented here:

- **[Contributor flow](#contributor-flow)** — build and run on your own hardware with
  your own (free or paid) Apple ID. No access to the maintainer's certificates.
- **[Maintainer flow](#maintainer-flow)** — produce the signed, distributable build
  that goes to TestFlight and the App Store via Fastlane Match.

The Xcode project itself is generated from `project.yml` by XcodeGen and is gitignored.
Signing is driven entirely by `.xcconfig` files so that no team ID or bundle ID ever
gets baked into checked-in project state. See PLAN.md §12.

---

## Contributor flow

You do **not** need the maintainer's signing assets, the private signing repo, or any
secret. You sign with your own Apple ID using Xcode's automatic signing.

### 1. Run bootstrap

```bash
./scripts/bootstrap.sh
```

This prompts for your **Team ID** and a **bundle prefix**, then writes
`Config/Local.xcconfig` (which is gitignored). It also runs `brew bundle`, installs the
Ruby gems, and regenerates the Xcode project.

### 2. `Config/Local.xcconfig`

The file bootstrap writes looks like this:

```
// Config/Local.xcconfig (gitignored — never commit this)
DEVELOPMENT_TEAM_OVERRIDE = ABCDE12345
BUNDLE_PREFIX = dev.alice.cleanshare
```

- `DEVELOPMENT_TEAM_OVERRIDE` — your 10-character Apple Developer Team ID. For a free
  Apple ID this is your personal team. Find it in Xcode → Settings → Accounts, or in the
  Apple Developer portal.
- `BUNDLE_PREFIX` — a reverse-DNS prefix unique to you (e.g. `dev.alice.cleanshare`).
  Using your own prefix avoids colliding with the shipping `dev.cleanshare.app` bundle
  IDs, which only the maintainer can provision.

`Config/Debug.xcconfig` consumes these via `#include? "Local.xcconfig"`:

```
#include? "Local.xcconfig"
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = $(DEVELOPMENT_TEAM_OVERRIDE)
PRODUCT_BUNDLE_IDENTIFIER = $(BUNDLE_PREFIX).app
```

With automatic signing on, Xcode requests and manages a development provisioning profile
for your team the first time you build to a device.

### 3. Free Apple ID limitations

A **free** Apple ID (no $99/yr Developer Program membership) works for local development,
but Apple imposes real limits you need to know about:

- **7-day re-signing.** Apps signed with a free Apple ID expire after 7 days. Re-build
  and re-install from Xcode to renew. (Paid memberships get 1-year profiles.)
- **No App Groups entitlement.** Free accounts cannot provision the
  `group.dev.cleanshare.app` App Group. The extension ↔ host workspace and the
  `cleanshare://handoff?t=<token>` URL-scheme re-share both depend on the shared App Group
  container. When the App Group is unavailable, the extension falls back to handing the
  cleaned file off through `UIDocumentPickerViewController` (the Files picker) instead of
  the seamless host re-share. See PLAN.md §6.2.
- **Three-app install limit** and no push/associated-domains entitlements (CleanShare uses
  none of those, so only the App Group limit is material here).

If you only run in the **iOS Simulator**, signing is bypassed entirely
(`CODE_SIGNING_ALLOWED=NO`) and none of the above applies — but the App Group still
requires a provisioned profile to exercise the seamless handoff path, so the simulator
also exercises the `UIDocumentPickerViewController` fallback unless you build with a paid
team.

---

## Maintainer flow

Production signing uses **Fastlane Match** against a separate **private** GitHub repo,
`<maintainer>/cleanshare-signing`, which stores the encrypted certificates and
provisioning profiles. The public repo references it only through environment variables —
no signing material ever lands in this repository. See PLAN.md §12.1.

### `fastlane/Matchfile`

```ruby
git_url(ENV["MATCH_GIT_URL"])
storage_mode("git")
type("development")
app_identifier(["dev.cleanshare.app", "dev.cleanshare.app.ShareExtension"])
username(ENV["FASTLANE_APPLE_ID"])
team_id(ENV["FASTLANE_TEAM_ID"])
```

### Fastlane lanes (`fastlane/Fastfile`)

| Lane | Purpose |
|---|---|
| `test` | Run the test suite on the simulator with no signing. |
| `certs` | Fetch dev + appstore certs/profiles. `readonly: true`. |
| `beta` | Build + upload to TestFlight (`match appstore` readonly, `gym`, `pilot`). |
| `release` | Build + upload + stage App Store metadata. `submit_for_review: false`. |

Both `beta` and `release` call Match with **`readonly: true`** so CI can never create or
revoke certificates — only the maintainer's local machine does that (run `fastlane certs`
locally, or `match` directly, when assets need to be rotated).

### Required secrets (GitHub `release` environment)

These live ONLY on the maintainer's machine and in the GitHub `release` environment.
They are never in source and are not needed by forks. See PLAN.md §11.7.

| Secret | Purpose |
|---|---|
| `MATCH_PASSWORD` | Symmetric passphrase encrypting the Match git repo. |
| `MATCH_GIT_URL` | URL of the PRIVATE signing repo `<maintainer>/cleanshare-signing`. |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64(`user:ghp_xxx`) with `repo` scope on the signing repo. |
| `ASC_KEY_ID` | App Store Connect API key ID. |
| `ASC_ISSUER_ID` | App Store Connect issuer ID. |
| `ASC_API_KEY_BASE64` | base64 of the `.p8` App Store Connect API key. |
| `FASTLANE_APPLE_ID` | Maintainer Apple ID (Match username). |
| `FASTLANE_TEAM_ID` | Developer Program team ID. |

**Forks need none of these.** The `release.yml` workflow targets the `release`
environment, which does not exist in forks, so it simply skips. PR CI runs for everyone.

For the full step-by-step ship procedure, see [`release-process.md`](./release-process.md).
