# 1. Record architecture decisions

- Status: Accepted
- Date: 2026-06-04

## Context and Problem Statement

CleanShare makes a number of architecturally significant decisions — engine
packaging, the zero-third-party-dependency rule, the extension→host handoff
mechanism, on-device-only telemetry — whose rationale is not self-evident from
the code. Without a durable record, the *why* behind these choices is lost to
git archaeology, and contributors re-litigate settled questions. We need a
lightweight, in-repo way to capture decisions, their context, and their
consequences.

## Decision

We use **Architecture Decision Records (ADRs)** following the
[MADR](https://adr.github.io/madr/) (Markdown Any Decision Records) format.

- ADRs live in `docs/adr/` as numbered Markdown files: `NNNN-kebab-title.md`,
  starting at `0001` (this file).
- Each ADR has a short title, a status, the context/problem, the decision, and
  its consequences. Keep them concise — an ADR is a record, not a design doc
  (long-form architecture stays in `PLAN.md`).
- ADRs are immutable once **Accepted**. To change a past decision, write a *new*
  ADR that supersedes it, rather than editing the old one.

### How to propose a new ADR

1. Copy the structure of an existing ADR into a new file with the next free
   number: `docs/adr/NNNN-your-decision.md`.
2. Set its status to **Proposed** and open a pull request.
3. Discussion happens on the PR. Once consensus is reached and the PR is merged,
   change the status to **Accepted** in the same or a follow-up change.

### Lifecycle

An ADR moves through these states:

- **Proposed** — drafted and under discussion on an open PR.
- **Accepted** — merged and in force. The decision is binding until superseded.
- **Superseded by NNNN** — replaced by a later ADR. The superseding ADR links
  back to the one it replaces; the old ADR is kept for the historical record and
  is not deleted.

A **Rejected** status is also valid for proposals that are declined but worth
keeping a record of (so the question isn't reopened later).

## Consequences

- **Positive:** decisions and their rationale are versioned alongside the code;
  new contributors can read `docs/adr/` to understand the constraints they're
  working within; settled debates stay settled.
- **Positive:** the format is plain Markdown — no tooling required to read,
  write, or review an ADR.
- **Negative:** a small amount of process overhead per significant decision.
  This is intentional friction; trivial decisions do not warrant an ADR.

## References

- MADR format: https://adr.github.io/madr/
- Michael Nygard's original ADR article:
  https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
- PLAN.md §10 (Repository Layout) — enumerates the planned ADR set:
  0002 (no third-party deps), 0003 (extension→host handoff), 0004
  (MetricKit-only telemetry).
