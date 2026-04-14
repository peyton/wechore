# Daily Routine Reliability Pass

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This document follows the repository-level ExecPlan guidance in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

WeChore should be an app someone can open every day to answer three plain questions: what needs doing, where did that request come from, and what should happen next. Before this pass, the app already had the right foundation, but daily use had several reliability gaps: invalid chat creation could produce broken state, the task list screen was not reachable, some failed actions were silent, voice and invite flows had ambiguous edges, and task extraction could create duplicates. This pass audits the repo with Codex and Claude Code, then implements a safe first slice of the highest-leverage fixes.

## Progress

- [x] (2026-04-14 14:05-15:20 PDT) Audited SwiftUI screens, `AppState`, domain models, widgets, CloudKit helpers, tests, and prior repository docs.
- [x] (2026-04-14 15:20 PDT) Ran local Claude Code as a read-only subagent with Codex's 60 candidate proposals. Claude reviewed the list and returned 56 additional proposals plus a top implementation slice.
- [x] (2026-04-14 15:35 PDT) Implemented state-level fixes for blank DM/group creation, participant/contact normalization, invite code normalization and reuse, duplicate task prevention, reminder guards, save-failure rollback, profile updates, and snapshot referential repair.
- [x] (2026-04-14 15:55 PDT) Implemented daily-use UI improvements: reachable Tasks screen, task sections, Mine/All filter, task editing sheet, done/reopen/archive actions, QR expiration copy, visible status banners outside chat, disabled invalid Join/Start/Send actions, message timestamps, and safer voice-recording state.
- [x] (2026-04-14 16:05 PDT) Added unit, integration, and UI test coverage for the accepted reliability slice.
- [x] (2026-04-14 16:22 PDT) Ran `mise exec -- just lint`; all repository lint gates passed.
- [x] (2026-04-14 16:24 PDT) Ran `mise exec -- just test-python`; 37 Python tests passed.
- [x] (2026-04-14 16:27 PDT) Parsed all changed Swift files with `xcrun swiftc -parse`; syntax checks passed.
- [x] (2026-04-14 16:40 PDT) Attempted `mise exec -- just build`; local Xcode generation succeeded, then `xcodebuild` timed out after 600 seconds at `CreateBuildDescription` and was interrupted with no compiler diagnostics.

## Surprises & Discoveries

- Observation: `ChoresView` existed but was not reachable from the chat tree or router.
  Evidence: `rg "ChoresView|All Tasks"` only found the view declaration before this pass.

- Observation: `startDM(displayName:)` could create a DM pointing at a `ChatParticipant` that was never saved when the name was blank.
  Evidence: `addParticipant` returned nil for blank names, and the old code then constructed `ChatParticipant(displayName: displayName)` only for the thread.

- Observation: Settings created a new invite as a hidden side effect when opened.
  Evidence: `SettingsQRCodeSection.task` called `refreshInvite()`, which called `appState.createInvite(for:)`.

- Observation: Claude's highest-priority independent findings largely matched the direct audit: save rollback, blank DM/group guards, due-date semantics, duplicate extracted tasks, and a global task entry point.
  Evidence: Claude Code session `f2801076-1b4e-447f-9a97-0c2bbaf0865e` returned proposals C01-C56 and a top implementation slice including these items.

## Decision Log

- Decision: Implement a reliability-first slice instead of attempting all 116 proposals in one pass.
  Rationale: Many proposals are substantial product features, such as full recurring tasks, CloudKit sync-state design, unread counts, localization, and large file splits. Implementing them all at once would reduce reviewability and raise regression risk. The accepted slice fixes broken state, visible failures, daily task access, and high-friction task editing.
  Date/Author: 2026-04-14 / Codex

- Decision: Make invalid group and DM creation fail at both state and UI layers.
  Rationale: UI disabling helps users, but state-level guards are required for tests, future call sites, widgets, and deep links.
  Date/Author: 2026-04-14 / Codex

- Decision: Reuse active invite payloads by default.
  Rationale: QR screens should be stable and understandable. Creating a new valid code on every view open adds stale invite clutter and makes shared codes harder to reason about.
  Date/Author: 2026-04-14 / Codex

- Decision: Treat `ChoresView` as the daily Tasks surface and make it reachable from the chat tree.
  Rationale: Chat-first remains intact, but daily use needs one place to see overdue, today, upcoming, blocked, no-date, and recently completed tasks.
  Date/Author: 2026-04-14 / Codex

- Decision: Document deferred work rather than silently dropping it.
  Rationale: The user explicitly asked for a broad audit. The unimplemented items should remain visible for future passes.
  Date/Author: 2026-04-14 / Codex

## Outcomes & Retrospective

This pass turns the existing app from a chat-only path into a more routine-ready task tool while preserving the product identity. A user can now open a global Tasks surface, filter Mine/All, scan sections by urgency, edit task details, reopen or archive completed work, see status messages outside the conversation screen, avoid invalid blank chats, reuse existing QR invites, and get clearer behavior around voice, reminders, and deep links. The remaining work is mostly larger-scope product design, CloudKit operational visibility, and codebase decomposition.

Validation completed for repository lint, Python tests, and Swift syntax parsing. Full local Xcode build execution remained blocked by the existing `CreateBuildDescription` hang behavior documented by prior repo notes; the build process produced no Swift compiler errors before the timeout.

## Context and Orientation

The main Swift app lives in `app/WeChore`. The local-first state object is `app/WeChore/Sources/Services/AppState.swift`. Persistent state is a Codable `ChoreSnapshot` defined in `app/WeChore/Sources/Models/DomainModels.swift`. `app/WeChore/Sources/Views/MessagesView.swift` contains the conversation screen, composer, floating task tile, and Join/Start screen. `app/WeChore/Sources/Views/ChoresView.swift` is the global task screen. Settings and QR invite views live in `app/WeChore/Sources/Views/SettingsView.swift` and `app/WeChore/Sources/Views/InviteQRCodeView.swift`. Widgets live in `app/WeChore/WidgetExtension/Sources/WeChoreWidgets.swift`. Unit tests live in `app/WeChore/Tests/WeChoreTests.swift`.

## Codex Audit Proposals

Codex proposed these 60 repo-grounded features, fixes, and improvements before Claude review.

1. Block blank or repeated default group-chat creation in state and UI.
2. Validate DM creation so a blank name cannot create a thread referencing a participant that was never saved.
3. Trim and normalize names, group titles, contacts, and invite codes consistently before persistence.
4. Disable Join/Start buttons when required fields are blank.
5. Accept invite codes pasted with spaces or hyphens by normalizing to alphanumerics.
6. Add a status banner to Join/Start and Settings so failures outside conversation are visible.
7. Add manual task editing for title, assignee, due date, notes, and status.
8. Add archive/hide completed tasks from active lists while preserving history.
9. Add reopen actions from task rows, not only the transient undo toast.
10. Add blocked reason support instead of only a blocked status.
11. Add a real due-date picker and due presets instead of only Due Tomorrow.
12. Section task lists into overdue, today, upcoming, blocked, and done.
13. Clarify All Tasks versus current user's tasks in `ChoresView`.
14. Add Mine/All task filters to support daily use.
15. Show overflow counts and a path to all tasks when a conversation has more than three active tasks.
16. Prevent duplicate tasks created from confirmed drafts and automatic extraction.
17. Preserve draft text or report clearly if async message posting fails.
18. Guard reminders so done or archived tasks are not scheduled.
19. Improve reminder plan behavior for no due date and past due dates.
20. Surface deep-link failures with clear status instead of silently ignoring missing threads or tasks.
21. Cancel or clean up voice recording when leaving a conversation or switching modes.
22. Report empty voice transcripts instead of silently dropping the recording.
23. Format voice durations as minutes and seconds.
24. Add timestamps to message bubbles and system activity.
25. Disable the Send button when the message is blank.
26. Close or update the action panel after actions so UI state stays obvious.
27. Show QR invite expiration date/time near the code.
28. Reuse an existing active invite for a thread instead of creating a new invite on every QR refresh.
29. Make invite-code generation collision-safe against active invites.
30. Stop Settings/My QR from creating a new invite as a hidden side effect unless the user asks.
31. Add current-user profile editing in Settings.
32. Add diagnostics/support copy for sync, notifications, app version, and local state.
33. Improve privacy copy with exact boundaries: no iMessage ingestion, no server, on-device extraction.
34. Reduce task extraction false positives by requiring clearer task verbs or household-action context.
35. Detect self-assignment phrases such as "I'll take out trash".
36. Treat "today" and "tonight" as end-of-day due dates rather than start-of-day dates.
37. Avoid direct `Date()` and `Calendar.current` use in views where app clock or deterministic tests should apply.
38. Preserve participant order when creating group chats instead of using `Set` order.
39. Normalize snapshot participant IDs so threads do not reference missing participants.
40. Add orphan task/message/draft cleanup or repair in snapshot normalization.
41. Improve widget projection for blocked, overdue tasks, and stale favorites.
42. Add AppIntent error handling when widget mark-done fails.
43. Add tests for blank DM/group creation, invite code normalization, duplicate extraction, and due-date interpretation.
44. Add UI tests for Join/Start validation and QR expiration copy.
45. Split the large `MessagesView.swift` file into smaller files.
46. Split the large `AppState.swift` file into focused services or extensions without changing external behavior.
47. Add SwiftUI previews for core states: empty chat, many tasks, large text, and dark mode.
48. Improve Dynamic Type handling in composer, task action grids, and QR card.
49. Add localization-ready strings or centralize repeated user-facing copy.
50. Add more explicit CloudKit sync states and retry actions.
51. Add task search or filtering within a busy household.
52. Add a daily digest or today view that makes the app a routine without gamification.
53. Add recurring task support for weekly/daily chores if it can remain lightweight.
54. Add reminder snooze/reschedule from task rows.
55. Keep first-run seeded examples only for preview/testing, never production.
56. Ensure repository save errors do not leave UI state pretending an operation succeeded.
57. Add accessibility identifiers and labels for all controls that alter data.
58. Add App Store/privacy metadata tests for any new permission text.
59. Keep dependencies lean and avoid server/backend features.
60. Document accepted and deferred scope in an ExecPlan.

## Claude Code Proposals

Claude Code reviewed Codex's list against the repo and added these 56 items. Items marked with an asterisk were implemented fully or partially in this pass.

1. C01*: Add `.disabled(!canSend)` to the Send button in `MessagesView.swift`.
2. C02*: Fix `startDM` orphan participant creation on blank names in `AppState.swift`.
3. C03*: Add duplicate checks to the `confirmDraft` and automatic extraction paths.
4. C04*: Resolve today/tonight/tomorrow due dates to end-of-day instead of start-of-day.
5. C05*: Stop Settings from auto-creating invites on every open.
6. C06*: Cancel voice recording on conversation disappear.
7. C07*: Restore the persisted snapshot on save failure to prevent in-memory divergence.
8. C08*: Add timestamps to message bubbles.
9. C09*: Disable Start Group when the title is blank.
10. C10*: Disable Start DM when the name is blank.
11. C11*: Normalize invite codes by stripping hyphens and spaces.
12. C12*: Add a reopen button for completed tasks.
13. C13*: Add date/preset due controls to the task creation panel.
14. C14*: Section active chores into Overdue, Today, Upcoming, and Blocked.
15. C15*: Add Mine/All toggle to `ChoresView`.
16. C16*: Add overflow count and navigation from `FloatingTaskTile`.
17. C17*: Show QR invite expiration date.
18. C18*: Reuse active invite instead of creating a new invite on each QR request.
19. C19*: Guard reminder scheduling against done or archived tasks.
20. C20*: Detect self-assignment phrases such as "I'll".
21. C21*: Add profile editing to Settings.
22. C22*: Add a task editing sheet from `ChoreRow`.
23. C23*: Close the action panel after invite/QR actions.
24. C24*: Show status messages for deep-link failures.
25. C25*: Notify the user on empty voice transcript.
26. C26*: Format voice durations as minutes/seconds.
27. C27*: Add invite-code collision checks.
28. C28*: Validate orphan participant IDs in snapshot normalization.
29. C29*: Add diagnostics section to Settings.
30. C30: Add task search in `ChoresView`.
31. C31*: Add Today or daily task view.
32. C32: Reduce extraction false positives with a confidence threshold.
33. C33: Add SwiftUI previews for core views.
34. C34: Split `MessagesView.swift` into focused files.
35. C35: Split `AppState.swift` into extensions by domain.
36. C36: Replace `Date()`/`Calendar.current` in views with an injected clock.
37. C37*: Preserve draft text on post-message failure.
38. C38: Add explicit CloudKit sync states and retry.
39. C39*: Add tests for blank DM/group edge cases.
40. C40*: Add tests for due-date interpretation.
41. C41: Add contextual accessibility labels to action buttons.
42. C42*: Add MarkTaskDoneIntent error handling.
43. C43: Prioritize overdue/blocked tasks in widget sorting.
44. C44*: Add privacy copy explaining no server and on-device-only extraction.
45. C45: Add unread count reset when opening a thread.
46. C46: Add pull-to-refresh on `ChoresView` and `ChatTreeView`.
47. C47: Add swipe-to-complete gesture on `ChoreRow`.
48. C48: Add haptic feedback on task completion.
49. C49: Add keyboard shortcut or submit behavior for Send.
50. C50: Remember conversation scroll position across navigation.
51. C51*: Add task count badge or count text to the Tasks sidebar row.
52. C52*: Make `ChoresView` reachable from `ChatTreeView`.
53. C53: Use relative formatting for recent message times.
54. C54: Use relative chat timestamps in the thread list.
55. C55*: Confirm or cancel recording when toggling voice mode.
56. C56: Consolidate duplicated short-date formatting helpers.

## Plan of Work

The accepted implementation slice touches the app in four layers. First, strengthen data invariants in `DomainModels.swift` and `AppState.swift` so bad inputs do not produce orphan references, duplicate active tasks, or silent save divergence. Second, wire those fixes through SwiftUI in `RootView.swift`, `MessagesView.swift`, `ChoresView.swift`, `SettingsView.swift`, and `InviteQRCodeView.swift` so users have clear daily task access and visible feedback. Third, update widget intent behavior so failed mark-done actions are not silent. Fourth, add focused tests in `WeChoreTests.swift`, `WeChoreIntegrationTests.swift`, and `WeChoreUITests.swift`.

Deferred work is still important but should be separate: CloudKit sync-state design, task search, recurring chores, snooze/reschedule, unread counts, view-file decomposition, SwiftUI previews, localization, and full clock injection in views.

## Concrete Steps

Work from `/Users/peyton/.codex/worktrees/893a/wechore`.

After edits, run:

    mise exec -- just lint

When practical, also run:

    mise exec -- just test-python
    mise exec -- just test-unit

If Xcode build or test execution hangs locally, capture the last meaningful lines and report the blocker rather than claiming success.

## Validation and Acceptance

The required gate is `mise exec -- just lint`; it must pass before the task is reported complete. The behavioral acceptance for this pass is: blank groups and DMs cannot create broken state, pasted invite codes with spaces or hyphens work, duplicate extracted tasks do not create extra active chores, today/tonight due dates land at end of day, failed saves restore the persisted snapshot, completed tasks cannot schedule reminders, empty voice transcripts report a clear status, Settings does not create QR invites until the user asks, the chat list has a Tasks entry, and the Tasks view supports Mine/All filtering, urgency sections, editing, reopen, and archive.

## Idempotence and Recovery

The changes are additive and safe to rerun. If validation fails, inspect the first compiler, linter, or test error and make the smallest fix. If a save operation fails in app code, `AppState.save(_:)` now attempts to reload the last persisted snapshot and reports a failure message so UI state does not continue pretending the failed operation succeeded.

## Artifacts and Notes

Claude Code was invoked with `claude -p --output-format json --permission-mode bypassPermissions --tools "Read,Grep,Glob,LS,Bash"` and instructed not to edit files. The command completed successfully and returned proposals C01-C56. Several proposals remain deferred because they are better handled as independent feature passes with their own tests and design decisions.

Final verification for this pass:

- `mise exec -- just lint` passed.
- `mise exec -- just test-python` passed with 37 tests.
- Changed Swift files passed `xcrun swiftc -parse`.
- `mise exec -- just build` timed out after 600 seconds at `CreateBuildDescription`; the last meaningful output was `** BUILD INTERRUPTED **` and `error: Recipe 'build' was terminated on line 23 by signal 15`.
