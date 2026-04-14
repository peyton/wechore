# Claude CI And Release Improvement Pass

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This document follows the repository-level ExecPlan guidance in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

The user asked Codex to run `claude -p`, gather at least fifty improvement ideas, pay special attention to GitHub CI and App Store release issues, and then implement the useful improvements directly. The local Claude CLI was invoked three times, but local Claude settings routed the prompt into long-running plan and agent workflows that never returned stdout before timeout. This pass therefore uses Claude's attempted review surface plus direct repository inspection to implement a coherent maintenance-sized set of improvements: GitHub Actions should be less flaky and less likely to waste TestFlight uploads, release scripts should fail fast on missing or mismatched App Store settings, App Store metadata should be testable without network access, universal links should be validated as part of the static site, and Swift URL construction should avoid avoidable force unwraps.

## Progress

- [x] (2026-04-14 14:05Z) Ran `claude -p` from the repository root and received 25 suggestions.
- [x] (2026-04-14 14:10Z) Reviewed the codebase areas named by Claude: domain models, app state, repositories, SwiftUI views, widget code, web CSS, and tests.
- [x] (2026-04-14 14:39Z) Implemented accepted data integrity changes in `app/WeChore/Sources/Models/DomainModels.swift`, `app/WeChore/Sources/Services/AppState.swift`, `app/WeChore/Sources/Services/Repository.swift`, and `app/WeChore/Sources/Services/ReminderScheduler.swift`.
- [x] (2026-04-14 14:45Z) Implemented accepted UI polish in `app/WeChore/Sources/Views/OnboardingView.swift`, `app/WeChore/Sources/Views/ChoresView.swift`, and widget/site styling.
- [x] (2026-04-14 14:50Z) Added Swift and Python tests for the repaired behavior and documentation checks.
- [x] (2026-04-14 15:10Z) Ran `mise exec -- just lint`, `mise exec -- just test-python`, and an XcodeBuildMCP simulator build. `just test-unit` and XcodeBuildMCP `test_sim` both hung in Xcode test execution and were stopped.
- [x] (2026-04-14 14:55Z) Ran three new `claude -p` attempts asking for at least 50 CI/App Store focused improvements; each hung or timed out without returning stdout.
- [x] (2026-04-14 14:55Z) Inspected GitHub workflows, release scripts, App Store metadata, CloudKit scripts, static site validation, and existing Python/Swift tests for the second pass.
- [x] (2026-04-14 15:02Z) Implemented CI workflow hardening, release preflight validation, version/build validation, App Store Connect record validation, AASA validation, and Swift URL safety fixes.
- [x] (2026-04-14 15:04Z) Updated tests and docs for the new release gates.
- [x] (2026-04-14 15:05Z) Ran `mise exec -- just test-python`; all 37 Python tests passed.
- [x] (2026-04-14 15:06Z) Ran the release preflight CLI with release-like environment variables; it passed.
- [x] (2026-04-14 15:06Z) Ran `mise exec -- just lint`; lint passed with 0 SwiftLint violations.
- [x] (2026-04-14 15:07Z) Attempted `mise exec -- just test-unit` and `mise exec -- just build`; both Xcode commands stalled after `CreateBuildDescription` and were stopped.

## Surprises & Discoveries

- Observation: The first `claude -p` text-mode run exited successfully but emitted no text. Running again with `--output-format json` produced a structured result.
  Evidence: The second run returned 25 suggestions and wrote a Claude-local plan file under `/Users/peyton/.claude/plans/`.

- Observation: The repository already had `CONTRIBUTING.md`, but it only described contribution restrictions and did not name the repo-local validation commands.
  Evidence: The file now includes internal development commands and `tests/test_ci_workflow.py` asserts they remain documented.

- Observation: Xcode test execution hung twice, once through `mise exec -- just test-unit` and once through XcodeBuildMCP `test_sim`, while the simulator build succeeded.
  Evidence: `mise exec -- just test-unit` stalled for over ten minutes with `.build/test-unit-iphone.xcodebuild.log` stopped at `CreateBuildDescription`. XcodeBuildMCP `build_sim` succeeded, while `test_sim` timed out after 120 seconds.

- Observation: In this second pass, `claude -p` could not provide the requested 50-item list because the local Claude setup entered plan/agent workflows and produced no stdout before timeout.
  Evidence: The plain `claude -p` command was killed after hanging with no output, and two `timeout ... claude -p --output-format json ...` attempts exited with code 124 and no stdout. The `.claude/projects/.../d37f28ff-...jsonl` log shows Claude launched agents instead of returning the requested list.

- Observation: Xcode build and test execution still stalls locally after generating the Tuist workspace and reaching `CreateBuildDescription`.
  Evidence: `timeout 900 mise exec -- just test-unit` and `timeout 600 mise exec -- just build` both stopped producing output at `CreateBuildDescription` and were terminated manually with signal 15.

## Decision Log

- Decision: Implement a focused subset of Claude's suggestions rather than all 25 literally.
  Rationale: Some suggestions are already implemented (`lastStatusMessage` is visible in `MessagesView` and `ChoresView`), some are too broad for one coherent pass (full localization, adding previews to every SwiftUI view), and some require product design beyond a maintenance pass (full Multipeer browser presentation flow). The accepted scope targets correctness, user feedback, and verifiable tests.
  Date/Author: 2026-04-14 / Codex

- Decision: Treat invite cleanup as a model invariant and app-state save concern.
  Rationale: Expired invites should be removed whenever snapshots normalize, and creating or accepting invites should also prune stale entries before adding or looking up codes.
  Date/Author: 2026-04-14 / Codex

- Decision: Keep `normalizeConversationState()` backward compatible by pruning expired invites only when a caller provides `now`.
  Rationale: Existing snapshot construction and decode paths use old fixture dates. Pruning by default would erase valid fixtures created with historical test clocks. AppState save/load paths pass the injected clock so live behavior still prunes expired invite state.
  Date/Author: 2026-04-14 / Codex

- Decision: Replace duplicate pending reminders before adding a new request.
  Rationale: `UNUserNotificationCenter` keys pending notifications by identifier, but explicitly removing the existing identifier first makes the intended deduplication behavior clear and makes the fake scheduler testable.
  Date/Author: 2026-04-14 / Codex

- Decision: Keep the second pass focused on CI and App Store release readiness rather than attempting to implement fifty unrelated product features.
  Rationale: The user explicitly highlighted GitHub CI and App Store release issues, and a coherent pass can harden workflows, metadata validation, and release scripts without destabilizing the app with broad UX/product changes.
  Date/Author: 2026-04-14 / Codex

## Outcomes & Retrospective

The first pass implemented the accepted maintenance-sized improvements: expired invite cleanup, safe invite URL fallback, invalid and duplicate manual chore rejection, reminder deduplication, repository mirroring error propagation, onboarding/profile validation, manual Add Task disabling, widget dynamic colors, static-site dark-mode CSS, and contributor setup documentation. Python tests passed, the required lint gate passed, and a simulator build succeeded. Swift unit test execution could not be completed because Xcode test execution hung before producing test results.

The second pass implemented the CI and release-readiness improvements: explicit workflow timeouts, pinned Xcode selection, TestFlight path filters, release metadata preflight, App Store Connect record mismatch detection, stricter version/build number validation, malformed key handling, universal-link validation, and safer Swift URL construction. The required lint gate passed, all Python tests passed, and the release preflight CLI passed with release-like environment variables. Local Xcode build and unit-test execution remain blocked by the same `CreateBuildDescription` stall observed in the earlier pass.

## Context and Orientation

WeChore is an Apple-first iOS app with a static website and repo-local automation. The Swift app lives under `app/WeChore`. The main local-first state object is `AppState` in `app/WeChore/Sources/Services/AppState.swift`; it owns a `ChoreSnapshot`, accepts messages, creates chores, handles invite payloads, schedules reminders, and saves through a `ChoreRepository`. Domain model types live in `app/WeChore/Sources/Models/DomainModels.swift`. The repository layer is in `app/WeChore/Sources/Services/Repository.swift`; `CompositeChoreRepository` mirrors state between the primary app store and shared app-group storage for widgets. The task list view is `app/WeChore/Sources/Views/ChoresView.swift`, onboarding is `app/WeChore/Sources/Views/OnboardingView.swift`, and conversation UI is `app/WeChore/Sources/Views/MessagesView.swift`. The widget code is in `app/WeChore/WidgetExtension/Sources/WeChoreWidgets.swift`. The static website lives in `web/`.

An invite is a short-lived object represented by `ThreadInvite` and `InvitePayload`. A snapshot is the persisted state bundle for household, participants, threads, chores, messages, suggestions, invites, and settings. Normalizing a snapshot means repairing old or inconsistent data before saving or rendering.

## Plan of Work

For the second pass, first harden GitHub Actions. Add explicit job timeouts to CI, pin the Xcode selector away from `latest`, make shell behavior explicit, and narrow TestFlight's push trigger to app and release-tooling paths so documentation or website-only merges do not upload a new build. Add a release preflight step before the network App Store Connect check.

Second, add repo-local release validation. A new Python module under `scripts/app_store_connect/` should validate required signing and App Store Connect environment, check release metadata in `Info.plist`, `WeChore.entitlements`, `PrivacyInfo.xcprivacy`, and `web/.well-known/apple-app-site-association`, and fail with clear messages before Xcode spends time archiving. Existing release scripts should invoke it after setting production defaults.

Third, tighten version and App Store Connect helpers. `scripts.tooling.resolve_versions` should reject malformed explicit marketing versions, malformed explicit build numbers, and non-integer GitHub run metadata. `scripts.app_store_connect.check` should wrap malformed base64 private keys in a clear `AppStoreConnectError` and verify the returned App Store app record has the expected name, SKU, locale, and bundle id.

Fourth, remove remaining avoidable Swift URL force unwraps in deep-link and settings URL construction. Add focused tests around these safer helpers and the new Python release validations.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/ad9a/wechore`.

Run:

    mise exec -- just lint

This passed on 2026-04-14.

before finishing. Also run targeted tests when practical:

    mise exec -- just test-python

This passed with 31 tests on 2026-04-14.

If Swift tooling is available and time allows, run:

    mise exec -- just test-unit

This was attempted and stopped after Xcode hung. XcodeBuildMCP `build_sim` was used as the compile check and succeeded.

## Validation and Acceptance

The pass is accepted when `mise exec -- just lint` passes. Targeted tests should demonstrate that expired invites are pruned, invalid manual chores are rejected, duplicate manual chores do not get created by repeated taps or calls, repository mirroring failures are not silently swallowed, and static site dark-mode support is present.

User-visible acceptance: onboarding cannot be completed with blank profile fields; the Add Task button is disabled for blank input and repeated identical submissions do not create duplicate chores; invite code lookup ignores expired invites; widgets and the marketing site remain readable in dark mode.

## Idempotence and Recovery

The edits are additive and can be rerun safely. Invite cleanup removes only expired invites. Duplicate task prevention rejects only active chores in the same thread with the same normalized title and assignee. If a validation command fails, inspect the first concrete compiler, linter, or test error, make the smallest fix, and rerun the same command.

## Artifacts and Notes

Claude's accepted high-priority themes were data integrity, stale invite cleanup, duplicate action prevention, docs, and tests. Broad suggestions deferred from this pass include full localization, every-view previews, complete nearby invite browsing UI, and CloudKit retry behavior.

## Interfaces and Dependencies

No new third-party dependencies should be added. Existing Swift and Python tooling remains unchanged. New helper methods should stay inside the existing types unless reuse across files is needed. Tests should use the existing `InMemoryChoreRepository`, `CapturingReminderScheduler`, and local Python pytest style.
