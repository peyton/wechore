# Build The WeChore MVP Monorepo

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

After this work, a user can build and run WeChore, complete onboarding, create household chores, assign them to a member, send local reminders, post in-app messages, accept on-device chore suggestions from those messages, and hand off a voice or text nudge to Apple system apps. The repository will also contain a static marketing/support/privacy website, documentation, linting, tests, and GitHub Actions that call the same `just` commands used locally.

## Progress

- [x] (2026-04-14 06:25Z) Researched the empty WeChore repo, the Sunclub reference repo, available Xcode/Tuist tooling, and applicable Apple-only implementation constraints.
- [x] (2026-04-14 06:31Z) Started the monorepo implementation with the required ExecPlan, root README, and directory layout.
- [x] (2026-04-14 06:53Z) Created Tuist app workspace, Swift domain models, SwiftData snapshot cache, SwiftUI app shell, CloudKit fakes, reminder/message/voice services, and MVP tests.
- [x] (2026-04-14 06:58Z) Created static website, docs, scripts, Python tooling tests, GitHub Actions, and generated icon assets.
- [ ] Finish UI flow polish and make all iPhone/iPad UI tests pass.
- [ ] Run full `just ci` and record final outcomes.

## Surprises & Discoveries

- Observation: The repository began as a detached worktree with only an empty `README.md`.
  Evidence: `rg --files` returned only `README.md`, and `git status --short --branch` returned `## HEAD (no branch)`.
- Observation: The Xcode installation is newer than the target OS and supports iOS simulator SDK 26.5, so an iOS 18.7 deployment target can be generated and built locally.
  Evidence: `xcodebuild -version` returned `Xcode 26.5`; `xcrun --sdk iphonesimulator --show-sdk-version` returned `26.5`.
- Observation: SwiftData loads under CloudKit-aware constraints when the app has CloudKit entitlements, even when the app stores a single local snapshot.
  Evidence: `just test-unit` initially crashed until `StoredAppSnapshot` used default values and no unique constraint.
- Observation: The current suggestion acceptance flow needs better post-accept visibility.
  Evidence: `just test-ui` can tap the suggestion accept row, but still fails when the created chore is not discoverable on the Chores tab without further UI scrolling/landing polish.

## Decision Log

- Decision: Store the MVP domain graph as a single Codable SwiftData snapshot record instead of modeling every relationship as separate SwiftData objects.
  Rationale: This keeps the first version small, deterministic, and easy to migrate while still using SwiftData as the required local cache. The public domain model remains explicit and testable.
  Date/Author: 2026-04-14 / Codex.
- Decision: Use FaceTime Audio URL handoff first, then `tel:` fallback, and use MessageUI for typed reminders.
  Rationale: This satisfies voice and message convenience without building VoIP, CallKit, a push server, or any third-party dependency.
  Date/Author: 2026-04-14 / Codex.
- Decision: Use NaturalLanguage tokenization plus deterministic parsing and `NSDataDetector` for suggestions, not Foundation Models.
  Rationale: The app must support iOS 18.7, and the suggestions must be predictable enough for local tests.
  Date/Author: 2026-04-14 / Codex.
- Decision: Keep UI-test reminder scheduling on a fake scheduler.
  Rationale: UI tests should verify WeChore's flow without invoking the system notification authorization sheet.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

- Passing: `just bootstrap`, `just generate`, `just build`, `just test-python`, `just web-check`, `just test-unit`, and `just test-integration`.
- Failing: `just test-ui` has one remaining flow failure around message suggestion acceptance leading back to visible chore tracking.
- Not yet rerun after the latest iPhone finding: `just test-ui-ipad`, `just lint`, and full `just ci`.

## Context and Orientation

The repository root is `/Users/peyton/.codex/worktrees/1de2/wechore`. The app lives under `app/WeChore`, the static site under `web`, project scripts under `scripts`, root-level Python validation under `tests`, and documentation under `docs`. Tuist is the Xcode project generator: running `just generate` should create `app/WeChore.xcworkspace` from `app/Workspace.swift` and `app/WeChore/Project.swift`.

The phrase local-first means the app works without a WeChore-operated server. User data is stored locally with SwiftData and can be shared with household members through the user's iCloud account via CloudKit sharing. CKShare means Apple's CloudKit object that lets an iCloud user share records with other iCloud users.

## Plan of Work

Create the Sunclub-style repo tooling first, then the app, then tests and docs. The app should compile without third-party packages. Swift source should keep UI in small SwiftUI views, domain logic in pure Swift services, CloudKit behind protocols, and test hooks behind `UITEST_*` launch arguments.

The static site should be a committed HTML/CSS site with support and privacy pages, local SVG assets, public contact emails, and no placeholder App Store links.

## Concrete Steps

Run all commands from `/Users/peyton/.codex/worktrees/1de2/wechore`.

1. Add repository files and scripts.
2. Run `just bootstrap` to install pinned tools and create the Python environment.
3. Run `just generate` to generate the Tuist workspace.
4. Run `just lint`, `just test-python`, `just test-unit`, `just test-ui`, `just test-ui-ipad`, `just build`, and `just web-check`.
5. Fix failures until the commands pass or a platform credential limitation blocks further progress.

## Validation and Acceptance

The MVP is accepted when `just ci` passes locally, or when every failing command is documented with the exact blocker. Manual behavior should be visible by running `just run`, completing onboarding, adding a chore, posting a message like `Sam please unload dishwasher tomorrow`, accepting the generated suggestion, marking the chore done, and opening the voice/text reminder controls.

## Idempotence and Recovery

The scripts must be safe to rerun. Generated Xcode workspaces, derived data, caches, and web build output live in ignored directories and can be removed with `just clean`. CloudKit helper scripts must fail with clear setup instructions when credentials are unavailable instead of mutating live CloudKit state unexpectedly.

## Artifacts and Notes

Initial repo evidence:

    ## HEAD (no branch)
    README.md

Tool evidence:

    Xcode 26.5
    Build version 17F5012f
    tuist 4.180.0
    just 1.49.0

## Interfaces and Dependencies

Swift protocols required by the MVP are `ChoreRepository`, `HouseholdSyncing`, `CloudKitDatabaseClient`, `ReminderScheduling`, `MessageSuggestionGenerating`, `SystemCommunicationOpening`, and `ClockProviding`. The app uses only Apple frameworks: SwiftUI, SwiftData, CloudKit, UserNotifications, NaturalLanguage, MessageUI, Foundation, and UIKit.

Revision note: Created the initial plan before code implementation so the remaining implementation can be resumed from this document alone.
