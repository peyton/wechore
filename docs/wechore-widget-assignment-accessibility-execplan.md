# Ship Widgets, One-Way Assignment, and Elder-Friendly Task Controls

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

After this work, WeChore is usable as a glanceable chore hub from the Home Screen and Lock Screen, and the in-app chat flow matches the mental model of assigning chores by message. A user can pin chosen conversations to widgets, jump straight into a chat, see task status without opening the app, and mark supported tasks done from widgets. In DMs, sending a chore assigns it to the recipient. In group chats, WeChore asks who should get the chore with large participant bubbles before creating the task.

The work also makes the main task surface safer for older adults. Task controls must remain readable at accessibility text sizes, buttons must have reliable hit targets, voice recording must not require a sustained press, and task completion must be undoable.

## Progress

- [x] (2026-04-14T11:25:00Z) Reviewed the existing chat-first app, current tests, Tuist project, WidgetKit/AppIntents SDK surface, and simulator screenshots.
- [x] (2026-04-14T11:25:00Z) Confirmed baseline `mise exec -- just lint` and `mise exec -- just test-unit` pass before changes.
- [x] (2026-04-14T12:15:00Z) Added shared app-group snapshot storage, deep links, assignment state, and widget reload plumbing.
- [x] (2026-04-14T12:45:00Z) Added production and dev widget extension targets with WidgetKit/AppIntents code.
- [x] (2026-04-14T13:10:00Z) Updated chat, settings, task tile, invite, toast, and voice UI for the requested behavior.
- [x] (2026-04-14T13:35:00Z) Added tests for widgets, assignment, deep links, accessibility, metadata, and undo.
- [x] (2026-04-14T13:42:00Z) Ran required verification and documented outcomes.

## Surprises & Discoveries

- Observation: The current app already has conversation-first navigation, rule-based and optional Foundation Models task extraction, DMs, group chats, voice messages, CloudKit records, invites, and a floating task tile.
  Evidence: `AppState.postMessage` extracts `TaskDraft`s, `RootView` opens `ChatTreeView`, and `CloudKitConversationStore` writes thread/task/message/invite records.
- Observation: The task tile visibly breaks at `.accessibility3`.
  Evidence: the iPhone simulator screenshot with `UITEST_LARGE_TEXT` clipped “Load dishwasher” into narrow columns and truncated “Remind” and “Done”.
- Observation: The SDK supports the required iOS widget families and AppIntent-backed interactive controls.
  Evidence: WidgetKit exposes `.systemSmall`, `.systemMedium`, `.systemLarge`, `.systemExtraLarge`, `.accessoryInline`, `.accessoryCircular`, `.accessoryRectangular`, `AppIntentTimelineProvider`, and AppIntent control/button APIs in the iOS 26.5 simulator SDK while the deployment target remains iOS 18.7.

## Decision Log

- Decision: Add a shared source set compiled into both the app and widget extension rather than making the widget import the app target.
  Rationale: Widget extensions cannot safely depend on app UI/runtime code; compiling shared model, store, deep-link, and projection code into each target keeps the extension small and extension-safe.
  Date/Author: 2026-04-14 / Codex.
- Decision: Keep SwiftData as the app's source of truth and mirror the current snapshot into an app-group JSON file after every successful app save.
  Rationale: The existing app uses a single Codable snapshot already, so a mirrored compact JSON snapshot gives widgets fast access without a second database or new dependency.
  Date/Author: 2026-04-14 / Codex.
- Decision: DM task assignment is based on message author and thread participants, not task text.
  Rationale: The product rule says opening a DM to someone means assigning chores to them; mentions should not override that one-way behavior.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

Completed. WeChore now has production and dev widget extension targets, app-group shared snapshot storage, deep-link routing, AppIntent-backed widget actions, widget favorites, one-way DM chore assignment, group assignee chips, undo after completion, tap-to-record voice controls, explicit invite creation, dismissible status toasts, and a task tile that remains usable at large accessibility text sizes.

The final implementation stayed within Apple frameworks and the existing Tuist/SwiftData shape. The widget extension compiles only shared model/storage/deep-link code plus widget source, and it does not import app UI or runtime-only services. The main compromise is that Lock Screen inline remains open/glance-only because that family has too little space for a safe completion control; larger supported families expose actions where WidgetKit supports them.

## Context and Orientation

The repository root is `/Users/peyton/.codex/worktrees/f041/wechore`. The iOS app lives in `app/WeChore`. Tuist generates the Xcode project from `app/WeChore/Project.swift`; app source is under `app/WeChore/Sources`, tests are under `app/WeChore/Tests`, `app/WeChore/IntegrationTests`, and `app/WeChore/UITests`, and repository validation is exposed through the root `justfile`.

A widget extension is a separate iOS target that runs outside the main app to draw Home Screen and Lock Screen widgets. AppIntents are small actions the system can run from widgets or Shortcuts, such as marking a task done. An app group is an Apple entitlement that lets the app and extension read and write files in the same container.

## Plan of Work

First, add the shared model/storage foundation. Extend task drafts with explicit assignment state, add widget favorite settings, add deep-link parsing/building, and add a shared JSON snapshot store that reads and writes `ChoreSnapshot` in the app group. Wrap the existing SwiftData repository in a composite repository that mirrors every successful save to the shared store and can recover from the shared store if SwiftData has no snapshot. Add a widget reloader protocol so tests can assert reloads without invoking WidgetKit.

Second, update task creation. `AppState.postMessage` should resolve an assignment context for each non-system message. If the thread is a DM, any recognized chore is assigned to the other participant relative to the message author and created immediately. If the thread is a group, the extracted chore remains a confirmable assignment draft, with a preselected participant when extraction found one. Confirming a group draft requires a participant ID.

Third, add WidgetKit and AppIntents. Create production and development widget extension targets in Tuist, add matching widget entitlements, and create extension source under `app/WeChore/WidgetExtension`. The widget extension reads the app-group snapshot, presents configurable conversation widgets for all requested Home Screen and Lock Screen families, opens deep links into the app, and uses `MarkTaskDoneIntent` to complete tasks and reload timelines.

Fourth, improve the app UI. Redesign the floating task tile to use vertical task cards at large text, full action labels, at least 44-point hit targets, undo/reopen, and non-color status labels. Add group assignment bubbles with large participant chips. Make voice recording work as tap-to-record/tap-to-send with cancel while preserving press-and-hold. Stop creating invites on conversation open. Add dismissible status toasts and widget favorite controls in Settings.

Finally, update tests and docs. Add unit and integration coverage for shared storage, widget projections, AppIntent completion, deep links, DM assignment, group assignment, undo, and widget reloads. Add UI tests for large text, DM assignment, group chips, no automatic invite toast, and widget favorites. Add metadata tests that assert targets, entitlements, AppIntents/WidgetKit usage, and supported families.

## Concrete Steps

Run commands from `/Users/peyton/.codex/worktrees/f041/wechore`.

1. Edit shared domain/storage files, then run `mise exec -- just test-unit`.
2. Edit Tuist project and widget extension files, then run `mise exec -- just generate` and `mise exec -- just build`.
3. Edit app UI and UI tests, then run `mise exec -- just test-ui` and `mise exec -- just test-ui-ipad`.
4. Run `mise exec -- just test-integration`, `mise exec -- just test-python`, and `mise exec -- just lint`.
5. Run `mise exec -- just ci` before reporting completion.

## Validation and Acceptance

The implementation is accepted when a seeded iPhone launch can open a DM to Sam, send `Please unload dishwasher tomorrow`, and see the task assigned to Sam; a seeded group launch can send `Please unload dishwasher tomorrow`, see a “Who should do this?” bubble, choose Sam, and then see the task created; the floating task tile remains readable with `UITEST_LARGE_TEXT`; no invite toast appears on conversation open; voice recording can be started and sent with taps; and widget timelines can be built for `.systemSmall`, `.systemMedium`, `.systemLarge`, `.systemExtraLarge`, `.accessoryInline`, `.accessoryCircular`, and `.accessoryRectangular`.

The required command set is:

    mise exec -- just lint
    mise exec -- just test-unit
    mise exec -- just test-integration
    mise exec -- just test-ui
    mise exec -- just test-ui-ipad
    mise exec -- just ci

`mise exec -- just lint` must pass before completion is reported.

Final validation evidence:

    mise exec -- just generate
    # passed

    mise exec -- just lint
    # passed, SwiftLint found 0 violations in 35 Swift files

    mise exec -- just test-unit
    # passed, 24 tests, 0 failures

    mise exec -- just test-integration
    # passed, 6 tests, 0 failures

    mise exec -- just test-ui
    # passed, 10 iPhone UI tests, 0 failures

    mise exec -- just test-ui-ipad
    # passed, 10 iPad UI tests, 0 failures

    mise exec -- just test-python
    # passed, 19 tests, 0 failures

    mise exec -- just ci
    # passed; included repo lint, 19 Python tests, unit, integration, iPhone UI, iPad UI, and Release build of WeChoreDev with WeChoreDevWidgetsExtension

## Idempotence and Recovery

All changes are source, tests, docs, entitlements, and generated project metadata. The shared snapshot store overwrites a single JSON file atomically enough for widget use and can be regenerated from SwiftData by reopening the app. Widget AppIntents must fail gracefully if the shared snapshot is missing or the task was already completed. Generated workspaces and build output remain ignored and can be removed with `just clean`.

## Artifacts and Notes

Baseline evidence:

    mise exec -- just lint
    # passed, SwiftLint found 0 violations

    mise exec -- just test-unit
    # passed, 17 tests, 0 failures

Simulator review evidence:

    UITEST_LARGE_TEXT screenshot showed task title split as "Load dish-wash-er" and action labels truncated as "Re..." and "D...".

## Interfaces and Dependencies

Use Apple frameworks only: SwiftUI, SwiftData, WidgetKit, AppIntents, Foundation, CloudKit, UserNotifications, NaturalLanguage, MessageUI, UIKit, MultipeerConnectivity, NearbyInteraction when available, and FoundationModels behind availability guards.

The final shared interfaces must include `SharedSnapshotStore`, `CompositeChoreRepository`, `WeChoreDeepLink`, `ConversationWidgetIntent`, `ConversationEntity`, `TaskEntity`, `MarkTaskDoneIntent`, `OpenConversationIntent`, and `WidgetTaskSummary`. The widget extension must read and write only the shared snapshot and must not import app view or service code that depends on SwiftData, UIKit, CloudKit, audio, speech, or runtime app state.

Revision note: Created when beginning implementation of the widget, assignment, and accessibility upgrade requested on 2026-04-14.
