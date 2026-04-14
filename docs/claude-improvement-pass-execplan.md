# Claude Improvement Pass

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This document follows the repository-level ExecPlan guidance in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

The user asked Codex to run `claude -p`, gather at least twenty improvement ideas, and then implement the useful improvements directly. After this pass, WeChore should be more resilient to duplicate or invalid user actions, should clean up stale invite state, should provide better contributor documentation, and should have tests around the repaired behavior. A human can see the work by running the app flows for onboarding, task creation, invites, and widgets, and by running the repository validation commands.

## Progress

- [x] (2026-04-14 14:05Z) Ran `claude -p` from the repository root and received 25 suggestions.
- [x] (2026-04-14 14:10Z) Reviewed the codebase areas named by Claude: domain models, app state, repositories, SwiftUI views, widget code, web CSS, and tests.
- [x] (2026-04-14 14:39Z) Implemented accepted data integrity changes in `app/WeChore/Sources/Models/DomainModels.swift`, `app/WeChore/Sources/Services/AppState.swift`, `app/WeChore/Sources/Services/Repository.swift`, and `app/WeChore/Sources/Services/ReminderScheduler.swift`.
- [x] (2026-04-14 14:45Z) Implemented accepted UI polish in `app/WeChore/Sources/Views/OnboardingView.swift`, `app/WeChore/Sources/Views/ChoresView.swift`, and widget/site styling.
- [x] (2026-04-14 14:50Z) Added Swift and Python tests for the repaired behavior and documentation checks.
- [x] (2026-04-14 15:10Z) Ran `mise exec -- just lint`, `mise exec -- just test-python`, and an XcodeBuildMCP simulator build. `just test-unit` and XcodeBuildMCP `test_sim` both hung in Xcode test execution and were stopped.

## Surprises & Discoveries

- Observation: The first `claude -p` text-mode run exited successfully but emitted no text. Running again with `--output-format json` produced a structured result.
  Evidence: The second run returned 25 suggestions and wrote a Claude-local plan file under `/Users/peyton/.claude/plans/`.

- Observation: The repository already had `CONTRIBUTING.md`, but it only described contribution restrictions and did not name the repo-local validation commands.
  Evidence: The file now includes internal development commands and `tests/test_ci_workflow.py` asserts they remain documented.

- Observation: Xcode test execution hung twice, once through `mise exec -- just test-unit` and once through XcodeBuildMCP `test_sim`, while the simulator build succeeded.
  Evidence: `mise exec -- just test-unit` stalled for over ten minutes with `.build/test-unit-iphone.xcodebuild.log` stopped at `CreateBuildDescription`. XcodeBuildMCP `build_sim` succeeded, while `test_sim` timed out after 120 seconds.

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

## Outcomes & Retrospective

The pass implemented the accepted maintenance-sized improvements: expired invite cleanup, safe invite URL fallback, invalid and duplicate manual chore rejection, reminder deduplication, repository mirroring error propagation, onboarding/profile validation, manual Add Task disabling, widget dynamic colors, static-site dark-mode CSS, and contributor setup documentation. Python tests passed, the required lint gate passed, and a simulator build succeeded. Swift unit test execution could not be completed because Xcode test execution hung before producing test results.

## Context and Orientation

WeChore is an Apple-first iOS app with a static website and repo-local automation. The Swift app lives under `app/WeChore`. The main local-first state object is `AppState` in `app/WeChore/Sources/Services/AppState.swift`; it owns a `ChoreSnapshot`, accepts messages, creates chores, handles invite payloads, schedules reminders, and saves through a `ChoreRepository`. Domain model types live in `app/WeChore/Sources/Models/DomainModels.swift`. The repository layer is in `app/WeChore/Sources/Services/Repository.swift`; `CompositeChoreRepository` mirrors state between the primary app store and shared app-group storage for widgets. The task list view is `app/WeChore/Sources/Views/ChoresView.swift`, onboarding is `app/WeChore/Sources/Views/OnboardingView.swift`, and conversation UI is `app/WeChore/Sources/Views/MessagesView.swift`. The widget code is in `app/WeChore/WidgetExtension/Sources/WeChoreWidgets.swift`. The static website lives in `web/`.

An invite is a short-lived object represented by `ThreadInvite` and `InvitePayload`. A snapshot is the persisted state bundle for household, participants, threads, chores, messages, suggestions, invites, and settings. Normalizing a snapshot means repairing old or inconsistent data before saving or rendering.

## Plan of Work

First, update the model and service layer. `InvitePayload.url()` should avoid a force unwrap. `ChoreSnapshot.normalizeConversationState()` should drop expired invites when given a reference date, while preserving compatibility for existing call sites. `AppState` should prune expired invites when creating or accepting invites, validate `assigneeID` and `threadID` in `addChore()`, prevent duplicate add-task behavior through deterministic duplicate checks, and surface repository mirroring errors from `CompositeChoreRepository` instead of silently swallowing them. Reminder scheduling should replace an existing pending notification with the same identifier before adding a new one.

Second, update SwiftUI interactions. Onboarding should disable the final "Open Chat" action until both name and first chat have non-empty trimmed values and should show a plain inline hint. The all-tasks manual add form should disable Add Task when the title is empty and clear it only when a task was actually accepted. The widget should use a dynamic widget background color so system dark mode remains legible. The static website should add `prefers-color-scheme: dark` CSS while preserving current light-mode output.

Third, add tests. Swift unit tests should cover invalid chore IDs, duplicate task prevention, invite pruning, invite URL safety, repository mirroring error propagation, and reminder deduplication in the capturing scheduler. Python or existing metadata tests should assert the website has dark-mode CSS and contributor documentation exists. Existing tests should be adjusted only when behavior intentionally changes.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/01fd/wechore`.

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
