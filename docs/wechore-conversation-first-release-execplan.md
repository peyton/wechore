# Ship Conversation-First WeChore

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

After this work, WeChore opens like a lightweight messaging app instead of a household dashboard. A parent sees a chat tree with group chats, direct messages, join/start actions, and Me; opens a conversation; types or records a request such as "Sam please unload the dishwasher tonight"; and sees the task appear automatically in a floating tile at the top of that conversation. The same thread holds normal messages, task status changes, invite actions, and reminders, so the app feels like a chat app with chores embedded rather than a chore app with chat bolted on.

The implementation keeps the current local-first posture. SwiftData stores a Codable snapshot locally, CloudKit stores conversation records and invite records for Apple-owned sync, local notifications schedule reminders, Messages/AirDrop/share sheet move invite links through system apps, and optional iOS 26 Foundation Models extraction improves task understanding only when Apple Intelligence is available on device. iOS 18 remains fully supported through the deterministic rule-based extractor.

## Progress

- [x] (2026-04-14T09:27:17Z) Inspected the existing Tuist SwiftUI app, current chat-first implementation, CloudKit store, route model, tests, and Foundation Models SDK surface.
- [x] (2026-04-14T09:27:17Z) Created this conversation-first release ExecPlan and marked the older chat-first ExecPlan as superseded by removing it from the checked-in docs.
- [x] (2026-04-14T10:13:29Z) Replaced the domain model with conversation-first threads, participants, invites, thread-scoped messages, and thread-scoped tasks while preserving legacy household decode compatibility.
- [x] (2026-04-14T10:13:29Z) Replaced the message suggestion service with async task extraction, including rule-based and iOS 26 Foundation Models implementations.
- [x] (2026-04-14T10:13:29Z) Replaced tab navigation with the WeChat-style chat tree on iPhone and iPad.
- [x] (2026-04-14T10:13:29Z) Rebuilt the conversation view around the floating task tile, invite/share actions, DM/group creation, and simulated nearby join flow.
- [x] (2026-04-14T10:13:29Z) Replaced CloudKit household records with conversation records and invite records.
- [x] (2026-04-14T10:13:29Z) Updated unit, integration, and UI tests for thread scoping, invites, extraction, notifications, and navigation.
- [x] (2026-04-14T10:21:52Z) Ran required verification, including `mise exec -- just lint`, the individual iOS suites, and `just ci`; all passed.

## Surprises & Discoveries

- Observation: The app had already completed an earlier chat-first pass with voice messages and inline suggestions, but it still used a phone `TabView`, a `HouseholdView`, and one household-wide message stream.
  Evidence: `RootView` used `TabView` for `AppRoute.allCases`, `DomainModels.swift` stored `household` plus flat `messages`, and `MessagesView` rendered `appState.household.name`.
- Observation: Xcode 26.5 includes the Foundation Models framework and Swift interfaces, while the app target remains iOS 18.7.
  Evidence: the SDK contains `FoundationModels.framework`, `SystemLanguageModel.default.availability`, `LanguageModelSession.respond(...generating:)`, and `@Generable`.
- Observation: Nearby phone exchange can be implemented with public APIs, but there is no public "NameDrop for arbitrary app payload" API.
  Evidence: the SDK exposes MultipeerConnectivity advertiser/browser and NearbyInteraction discovery tokens; the plan uses MultipeerConnectivity for payload exchange and NearbyInteraction only for proximity confirmation when supported.
- Observation: iPad `NavigationSplitView` visibly shows the chat tree sidebar, but XCTest does not reliably expose the sidebar `List` wrapper's accessibility identifier.
  Evidence: screenshots showed the Pine Chat, Sam, Join or Start, and Me sidebar while `chat.tree` lookup failed; UI tests now assert the visible sidebar actions and thread labels directly.

## Decision Log

- Decision: Keep the word "household" only as a legacy storage/migration concept and remove it from first-run, navigation, chat, and settings copy.
  Rationale: The product should be organized around chats and DMs; existing snapshots still need a source name when converted into the first group chat.
  Date/Author: 2026-04-14 / Codex.
- Decision: Use one default group chat when migrating old snapshots.
  Rationale: Existing data has one member list, one message stream, and one chore list, so a single group preserves all content with the least destructive migration.
  Date/Author: 2026-04-14 / Codex.
- Decision: Auto-create tasks for clear requests and keep ambiguous requests as draft task suggestions in the floating tile.
  Rationale: The parent should not have to manage details when the request names a participant and action, but ambiguous assignments still need a lightweight confirmation point.
  Date/Author: 2026-04-14 / Codex.
- Decision: Use CloudKit public records for short invite-code lookup and thread-root CKShares for actual conversation sharing.
  Rationale: This avoids a WeChore-operated backend while still making invite codes usable across devices.
  Date/Author: 2026-04-14 / Codex.
- Decision: Keep Foundation Models optional and behind `@available(iOS 26.0, *)` with strict fallback.
  Rationale: iOS 18.7 is the minimum target, and CI must pass without an Apple Intelligence-capable simulator.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

WeChore now opens to a chat tree on iPhone and a split chat tree on iPad, with no bottom tab bar. Group chats and DMs own messages, participants, invites, active tasks, task drafts, task activity, and reminders. Clear text or voice requests create active tasks in the floating conversation tile; ambiguous requests stay as one-tap drafts. Marking a task done posts a lightweight activity update in the thread. Join or Start supports new group chats, DMs, invite codes, share/AirDrop invite payloads, and a simulated nearby join path backed by the public-API nearby service shell.

Legacy snapshots decode into one default group chat so old members, messages, chores, and voice metadata remain attached to a conversation. Foundation Models extraction is optional behind iOS 26 availability and strict runtime fallback; CI and UI tests use deterministic rule-based/fake paths, so Apple Intelligence is not required on the simulator.

Verification completed from `/Users/peyton/.codex/worktrees/f2b7/wechore`:

    mise exec -- just lint
    just test-unit
    just test-integration
    just test-ui
    just test-ui-ipad
    just ci

The simulator logs include expected CoreData/CloudKit warnings about no iCloud account while tests use fake/in-memory sync paths. They did not fail the suites.

## Context and Orientation

The repository root is `/Users/peyton/.codex/worktrees/f2b7/wechore`. The iOS app lives under `app/WeChore`. SwiftUI views are in `app/WeChore/Sources/Views`, domain models are in `app/WeChore/Sources/Models`, services are in `app/WeChore/Sources/Services`, route/theme/runtime helpers are in `app/WeChore/Sources/Shared`, and tests are under `app/WeChore/Tests`, `app/WeChore/IntegrationTests`, and `app/WeChore/UITests`.

Tuist generates the Xcode project from `app/Workspace.swift` and `app/WeChore/Project.swift`. Repository commands are exposed through `just`; run them from the repository root. The repository instruction in `AGENTS.md` requires `mise exec -- just lint` to pass before reporting any code/config/test/doc development task as complete.

A "group chat" is a conversation with two or more participants. A "DM" is a direct message conversation with exactly one other participant and the current user. A "thread" means either a group chat or DM. A "floating task tile" means the task summary surface pinned at the top of a conversation. A "task draft" means an extracted chore request that needs one-tap confirmation before it becomes an active task. "Foundation Models" means Apple's iOS 26 on-device LLM framework that powers Apple Intelligence.

## Plan of Work

First, change the model layer. Add `ChatThread`, `ChatThreadKind`, `ChatParticipant`, `ThreadInvite`, `InvitePayload`, `TaskDraft`, and `TaskActivity`. Keep `Household` only so old snapshots decode. Add `threadID` to messages and chores, plus source message, reminder policy, and notification state to chores. Implement `ChoreSnapshot` custom decoding so snapshots without threads migrate into one default group chat with all existing participants, messages, chores, and voice attachments attached to that thread.

Second, replace message suggestions with async extraction. Rename the service concept to `TaskExtractionEngine`, add `RuleBasedTaskExtractionEngine` using the existing NaturalLanguage and `NSDataDetector` behavior, and add `FoundationModelsTaskExtractionEngine` in the same service file behind `#if canImport(FoundationModels)` and `@available(iOS 26.0, *)`. The app should select the Foundation Models engine only on iOS 26 when `SystemLanguageModel.default.availability == .available`; otherwise it must use the rule-based engine. UI tests should inject a deterministic fake engine.

Third, rewrite app state around conversations. Add methods to create group chats, start DMs, create invites, accept invite URLs/codes, start simulated nearby joins, post messages into a thread, post voice messages into a thread, create tasks from extracted drafts, confirm drafts, update task status, append task activity messages, and schedule reminders with thread context. Old methods can remain as thin compatibility wrappers only if tests or auxiliary screens still need them.

Fourth, replace the UI shell. The phone root must be a `NavigationStack` whose root is `ChatListView`; no bottom tab bar should exist. The iPad root must be a `NavigationSplitView` with the same chat tree in the sidebar. The chat tree must include group chats, DMs, Join or Start, and Me. The conversation view must show the thread header, floating task tile, message scroll, voice/text composer, and invite/share controls. Settings should be reachable as Me in the tree.

Fifth, replace CloudKit and invite services. Rename the household store to `CloudKitConversationStore`, write records for threads, participants, chores, messages, task activities, and thread invites, and make `CKShare` titles come from the chat title. Add invite-code lookup behavior over in-memory fake records for tests. Add MultipeerConnectivity and optional NearbyInteraction service shells with fake/simulated paths for UI tests.

Finally, update tests and docs. Rewrite unit, integration, and UI tests around conversation navigation, thread scoping, extraction, invites, task tile behavior, and accessibility at large text. Update README, app README, CloudKit docs, and App Store compliance copy so they describe chats/DMs and no longer position the app around households.

## Concrete Steps

Run all commands from `/Users/peyton/.codex/worktrees/f2b7/wechore`.

1. Edit `DomainModels.swift`, `MessageSuggestionEngine.swift`, `CloudKitHouseholdStore.swift`, and `AppState.swift`, then run `just test-unit` to catch model and service regressions.
2. Edit `RootView.swift`, replace `MessagesView.swift` with conversation views, add any join/start/settings views, and run `just test-ui` on iPhone.
3. Update iPad behavior and run `just test-ui-ipad`.
4. Update integration tests and run `just test-integration`.
5. Update docs and run `mise exec -- just lint`, then `just ci`.

## Validation and Acceptance

The implementation is accepted when a fresh seeded launch opens to a chat tree without a bottom tab bar, tapping a group chat opens the conversation, typing `Sam please unload dishwasher tomorrow` creates a task in the floating tile without leaving chat, recording a fake voice message follows the same path, marking the task done posts a status update and removes it from active tile count, Join or Start can start a group, start a DM, join by code, and simulate nearby join, and Me opens settings.

The required command set is:

    mise exec -- just lint
    just test-unit
    just test-integration
    just test-ui
    just test-ui-ipad
    just ci

`mise exec -- just lint` must pass before completion is reported.

## Idempotence and Recovery

All changes are local source, docs, and tests. Generated Xcode workspaces, derived data, screenshots, caches, and build output remain ignored and can be removed with `just clean`. Snapshot migration must be idempotent: decoding an old snapshot should create one default thread, and decoding a new snapshot should preserve its existing threads. Invite codes must be deterministic in tests through injected clocks or fake generators and random in production through UUID-backed generation.

## Artifacts and Notes

Relevant pre-implementation facts:

    RootView phone shell: TabView over AppRoute.allCases
    Existing default route: AppRouter.selectedRoute = .messages
    Existing message model: flat ChoreSnapshot.messages with no threadID
    Existing chore model: flat ChoreSnapshot.chores with no threadID
    Existing sync store: CloudKitHouseholdStore writes Household, Member, Chore, ChoreMessage
    Foundation Models SDK: available in Xcode 26.5, with SystemLanguageModel and LanguageModelSession

## Interfaces and Dependencies

Use only Apple frameworks and repo-local tooling. New service code may import SwiftUI, SwiftData, CloudKit, UserNotifications, NaturalLanguage, MessageUI, Foundation, UIKit, Contacts/ContactsUI, CoreImage for invite QR generation if used, MultipeerConnectivity, NearbyInteraction, CoreTransferable, and FoundationModels behind availability guards. Do not add third-party packages, analytics, a backend service, or runtime dependency installation.

The final service interfaces must include:

    public protocol TaskExtractionEngine: Sendable {
        func extractTasks(from message: ChoreMessage, participants: [ChatParticipant], now: Date) async -> [TaskDraft]
    }

    public protocol ConversationSyncing: Sendable {
        func records(for snapshot: ChoreSnapshot) -> [CKRecord]
        func save(snapshot: ChoreSnapshot) async throws
        func share(for threadID: String, in snapshot: ChoreSnapshot) -> CKShare?
        func invitePayload(for code: String, in snapshot: ChoreSnapshot, now: Date) -> InvitePayload?
    }

    @MainActor
    public protocol NearbyInviteExchanging {
        func startAdvertising(payload: InvitePayload) async
        func startBrowsing() async
        func stop()
    }

Revision note: Created at the start of the conversation-first implementation so the work can be resumed from this document alone.
