# WeChore App Spec

## Product Summary

WeChore is a local-first household chore app for iPhone and iPad. Users can create a household, add members, assign chores, set due dates, check progress, send reminders, and use in-app messages to create suggested chores.

## Goals

- Make shared household work visible without a server-owned account.
- Keep assignments, due dates, and progress easy to scan.
- Let reminders and voice/text nudges use Apple system apps.
- Suggest chores from messages typed inside WeChore without reading outside conversations.
- Sync shared household records through CloudKit sharing.

## Non-Goals

- No third-party backend.
- No in-app VoIP, CallKit stack, or custom calling service.
- No iMessage ingestion.
- No ads, analytics SDKs, subscriptions, or social feed.

## Core Screens

- Onboarding captures the user's display name, household name, and optional phone or FaceTime handle.
- Chores shows assigned work, status, due dates, progress controls, reminder actions, and voice handoff actions.
- Messages lets users post household messages and review suggested chores before accepting them.
- Household shows members and CloudKit sharing status.
- Settings shows notification, privacy, support, and sync controls.

## Apple API Use

- SwiftData stores a local Codable snapshot.
- CloudKit stores deterministic records and creates `CKShare` metadata for shared households.
- UserNotifications schedules local chore due reminders.
- NaturalLanguage and `NSDataDetector` extract chore suggestions on device.
- FaceTime, Phone, and Messages are opened through Apple URL and MessageUI handoff.

## Success Criteria

From a clean checkout, `just ci` should pass. Running `just run` should open the app, complete onboarding, create a chore, post a message, accept a suggestion, mark a chore done, and expose reminder and voice/text handoff actions.
