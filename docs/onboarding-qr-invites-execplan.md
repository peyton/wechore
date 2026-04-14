# Simplify Onboarding and QR Invites

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan follows the ExecPlan requirements in `/Users/peyton/.agents/PLANS.md`.

## Purpose / Big Picture

After this work, a new WeChore user moves through a few simple onboarding screens instead of a single cluttered form. The screens explain that the app is a chat interface, offer practical ways to find people through nearby discovery, Contacts, and QR invites, then open the app into chat. Existing users can quickly find their own QR code from the chat tree or Me screen, and another person can scan that QR code with the iPhone Camera app because it encodes a WeChore universal invite link.

## Progress

- [x] (2026-04-14T12:00:00Z) Inspected the existing SwiftUI onboarding, chat tree, join/start, settings, invite payload, associated domain entitlement, and static web site.
- [x] (2026-04-14T13:20:00Z) Refactored `app/WeChore/Sources/Views/OnboardingView.swift` into simple paged onboarding screens with generated SwiftUI hero assets and explicit nearby, contacts, and QR options.
- [x] (2026-04-14T13:20:00Z) Added a native QR renderer and visible My QR surfaces for the first/default chat.
- [x] (2026-04-14T13:20:00Z) Updated Join or Start and conversation invite surfaces so scanning and sharing QR invites are clear.
- [x] (2026-04-14T13:20:00Z) Added the Apple App Site Association file under `web/.well-known/` so Camera-scanned universal links can open the app.
- [x] (2026-04-14T13:20:00Z) Updated tests and ran `mise exec -- just lint` from the repository root.

## Surprises & Discoveries

- Observation: The app already has `InvitePayload.universalURL`, `wechore.peyton.app` associated-domain entitlement, and Contacts usage copy in `Info.plist`, but the web site does not yet publish an Apple App Site Association file.
  Evidence: `app/WeChore/WeChore.entitlements` contains `applinks:wechore.peyton.app`; `web/` has no `.well-known/apple-app-site-association` file.
- Observation: The existing invite flow creates shareable codes and universal URLs but never renders a QR code.
  Evidence: `AppState.createInvite(for:)` stores `latestInvitePayload`; `ConversationView` only switches from an Invite button to a share-sheet button.
- Observation: Focused unit-test attempts stalled before Swift compilation began, while the required lint path completed normally.
  Evidence: two `mise exec -- just test-unit` runs stopped at Xcode build-description generation with no further log output; `mise exec -- just lint` completed with zero violations.

## Decision Log

- Decision: Use code-generated SwiftUI hero art instead of generated raster images.
  Rationale: The requested assets are explanatory onboarding graphics that need to match the existing app icon, SF Symbol usage, and dynamic color scheme. Code-native assets avoid binary churn and remain accessible in dark mode.
  Date/Author: 2026-04-14 / Codex.
- Decision: QR codes should encode `InvitePayload.universalURL.absoluteString`.
  Rationale: iPhone Camera recognizes HTTPS QR codes and can route them into the app when the associated domain is configured, while the same link also remains shareable outside QR scanning.
  Date/Author: 2026-04-14 / Codex.
- Decision: Contacts and nearby discovery should be offered in onboarding without forcing either permission before the user reaches chat.
  Rationale: The user asked for the offers and clarity, while forcing permission prompts during setup would slow the chat-first path.
  Date/Author: 2026-04-14 / Codex.

## Outcomes & Retrospective

WeChore now presents onboarding as three simple screens: chat-first explanation, people-finding options, and a short profile/first-chat setup. The app offers nearby discovery, Contacts picking, QR scanning, and Camera-app scanning during setup without blocking the user on permissions. The chat tree now includes My QR, Settings includes a QR section, conversations can show an invite QR after creating an invite, and Join or Start explains Camera scanning. QR codes are rendered with Core Image from the existing universal invite URL. The static website now includes `web/.well-known/apple-app-site-association` for `/join*` links.

Verification completed:

    mise exec -- just lint

Focused unit-test runs were attempted twice but stalled inside `xcodebuild` before compilation; both runs were terminated to avoid leaving hung sessions.

## Context and Orientation

The repository root is `/Users/peyton/.codex/worktrees/a676/wechore`. The iOS app is under `app/WeChore`. SwiftUI screens are in `app/WeChore/Sources/Views`, shared theme and route types are in `app/WeChore/Sources/Shared`, and app state is in `app/WeChore/Sources/Services/AppState.swift`. The static website used for universal links is under `web/`.

The current onboarding screen is `OnboardingView`. It is a single scroll view with three text fields. The main app shell is `RootView`: after onboarding it shows a chat tree on iPhone and a split chat tree on iPad. `InvitePayload` in `DomainModels.swift` already creates an HTTPS join URL on `https://wechore.peyton.app/join`, and `WeChoreDeepLink` parses that URL into an invite.

## Plan of Work

First, replace the single onboarding form with a paged SwiftUI flow. The first page explains that WeChore is chat with tasks, using a generated hero illustration of chat bubbles and task chips. The second page presents ways to find people: nearby chat discovery, Contacts integration, QR invite scanning, and Camera-app scanning. The last page asks only for the name and first chat name, keeping contact entry optional and secondary. The final action completes onboarding through `AppState.completeOnboarding`.

Second, add a small QR rendering helper based on Core Image. The helper should take a string and return a non-interpolated `UIImage` so SwiftUI can display crisp QR codes. Build a reusable `InviteQRCodeCard` view that can show the QR code, code text, Camera-app instruction, and a share action.

Third, expose QR invites. Add My QR to the chat tree and settings so the user can find their own code quickly. Add QR guidance to Join or Start so users understand that another person can scan a WeChore QR with Camera or paste an invite code. Keep the app chat-first and do not add a tab bar.

Fourth, add `web/.well-known/apple-app-site-association` with the production and development bundle IDs for `/join*`. This makes the universal invite URL suitable for Camera-app QR scanning once the site is deployed.

Finally, update UI/unit tests to cover the new onboarding flow, My QR discovery, and QR renderer. Run `mise exec -- just lint` from the repository root and record the result.

## Concrete Steps

Run commands from `/Users/peyton/.codex/worktrees/a676/wechore`.

1. Edit `app/WeChore/Sources/Views/OnboardingView.swift`.
2. Add `app/WeChore/Sources/Shared/QRCodeRenderer.swift` and reusable QR views.
3. Edit `app/WeChore/Sources/Views/RootView.swift`, `MessagesView.swift`, and `SettingsView.swift`.
4. Add `web/.well-known/apple-app-site-association`.
5. Update `app/WeChore/Tests/WeChoreTests.swift` and `app/WeChore/UITests/WeChoreUITests.swift`.
6. Run `mise exec -- just lint`.

## Validation and Acceptance

Acceptance is user-visible. A fresh launch shows a short onboarding sequence with clear chat-first language and generated hero art. The flow offers nearby chat, Contacts, and QR scanning, then creates the first chat. After onboarding, the chat tree has a clear My QR entry. Opening My QR or the Settings QR section shows a scannable QR code, the invite code, Camera-app instructions, and share affordance. Join or Start explains how to scan a QR code through Camera and still supports invite-code entry, nearby join, group chats, and DMs.

The required repository gate is:

    mise exec -- just lint

This command must pass before reporting the task complete. Focused tests should also pass if time allows.

## Idempotence and Recovery

The work is source, tests, docs, and static web files only. Re-running QR generation simply renders from the current invite payload. If an invite cannot be created because there is no chat, the UI should show a short fallback instead of crashing. If lint fails, fix the reported Swift, Python, web, or shell issue and rerun the same command.

## Artifacts and Notes

Relevant current facts:

    OnboardingView.swift: one ScrollView with name, first group chat, and FaceTime/phone fields.
    RootView.swift: chat tree has Join or Start and Me actions.
    DomainModels.swift: InvitePayload.universalURL is https://wechore.peyton.app/join?... .
    WeChore.entitlements: associated domains include applinks:wechore.peyton.app.
    web/: no .well-known/apple-app-site-association file yet.

## Interfaces and Dependencies

Use Apple frameworks already available to the app target: SwiftUI, UIKit, CoreImage, and CoreImage.CIFilterBuiltins. No third-party packages are needed.

The new helper should provide a simple interface similar to:

    enum QRCodeRenderer {
        static func makeImage(from text: String, scale: CGFloat) -> UIImage?
    }

Reusable QR views should accept an `InvitePayload` and render `payload.universalURL.absoluteString`.

Revision note: Created before implementation to make the onboarding and QR invite work resumable from this document alone.

Revision note: Updated after implementation to record completed onboarding, QR, universal-link, test, and lint work plus the Xcode unit-test stall.
