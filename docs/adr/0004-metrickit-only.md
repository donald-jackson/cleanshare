# 4. Telemetry is MetricKit-only, opt-in, on-device

- Status: Accepted
- Date: 2026-06-04

## Context and Problem Statement

Every shipping app eventually wants to know whether it is crashing and how it
performs in the field. The industry-default answer is a third-party SDK —
Firebase Crashlytics, Sentry, Bugsnag, Mixpanel, Amplitude — which collects
crash traces and usage metrics and transmits them to a vendor's backend.

CleanShare's entire value proposition is that it strips identifying metadata and
keeps the user's files on-device. Bundling a telemetry SDK that phones home —
even one that only sends "anonymous" crash data — would directly contradict that
promise and undermine the "We test for it on every commit" claim. The threat
model treats any unsanctioned network egress as a defect, not a feature.

We still want a way to diagnose crashes. The question is how to get diagnostics
without collecting data or making network calls.

## Decision

CleanShare uses **Apple's MetricKit only**, with diagnostics **opt-in**,
processed **on-device**, and exported **manually** by the user. There is **no
auto-transmission** and there are **no third-party telemetry SDKs**.

Concretely (PLAN.md §18.2):

1. Subscribe to `MXMetricManager` delegate callbacks to receive crash and
   performance reports that iOS already collects on-device.
2. Persist the last 5 reports in a rolling buffer in the app container.
3. Surface them in Settings → "Diagnostics" → "Export Last 5 Crash Reports",
   exported by the user via AirDrop or Mail.
4. The feature is **default off**; the user must opt in, and nothing leaves the
   device unless the user explicitly exports it.

### Hard rules (PLAN.md §18.1)

- No third-party telemetry SDKs — Firebase, Mixpanel, Amplitude, Sentry,
  Bugsnag, Crashlytics are all forbidden.
- No `URLSession` calls at runtime, except inside the tests that verify we make
  none.
- No identifier-shaped `UserDefaults` keys (`installationDate`,
  `firstLaunchID`, etc.).
- No `identifierForVendor` reads.

### Alternatives considered

- **A third-party crash SDK (Crashlytics/Sentry/Bugsnag).** Rejected: it
  requires a runtime network connection and a vendor backend, violating the
  on-device-only guarantee and the "Data Not Collected" App Store posture. This
  is the option the ADR exists to rule out.
- **Self-hosted crash endpoint** (our own backend receiving MetricKit payloads).
  Rejected: CleanShare has no backend by design, and adding one introduces a
  network surface, an operational burden, and a data-collection disclosure we do
  not want to make.
- **No diagnostics at all.** Considered, but MetricKit gives us on-device crash
  visibility at zero privacy cost, so there is no reason to forgo it.

## Consequences

- **Positive:** the app collects no data and makes no telemetry network calls,
  keeping every App Store privacy category answerable "Data Not Collected".
- **Positive:** MetricKit is a first-party framework, so it adds no third-party
  runtime dependency (consistent with [[0002-no-third-party-deps]]).
- **Positive:** the no-network stance is mechanically enforced —
  `scripts/check-no-trackers.sh` greps the build for forbidden SDK symbols and a
  network-silence XCUITest fails if any `URLSession` call is attempted
  (PLAN.md §18.3).
- **Negative:** we get no aggregate field telemetry. We cannot see crash rates
  across the user base; we only see a report if a user chooses to opt in and
  manually send one. Debugging field issues is slower as a result — an
  acceptable trade for the privacy guarantee.

## References

- PLAN.md §18 (Telemetry — none, by design and by CI)
- PLAN.md §18.1 (hard rules), §18.2 (MetricKit crash reporting), §18.3 (verification)
- `scripts/check-no-trackers.sh` (forbidden-symbol gate)
- [[0001-record-architecture-decisions]]
- [[0002-no-third-party-deps]]
