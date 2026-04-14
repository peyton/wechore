# WeChore App Spec

## Product Summary

WeChore is a local-first messaging/task app for iPhone and iPad. Users create group chats and DMs, invite people through share links, invite codes, or nearby exchange, and turn plain chat requests into task tiles with reminders and completion updates.

## Goals

- Make shared work visible inside the conversations where requests happen.
- Keep assignments, due dates, progress, reminders, and completion status easy to scan at the top of each chat.
- Let invites, reminders, and voice/text nudges use Apple system apps.
- Extract tasks from messages and voice transcripts typed or recorded inside WeChore without reading outside conversations.
- Sync shared conversation records through CloudKit sharing.

## Non-Goals

- No third-party backend.
- No in-app VoIP, CallKit stack, or custom calling service.
- No iMessage ingestion.
- No ads, analytics SDKs, subscriptions, or social feed.

## Core Screens

- Onboarding captures the user's display name, first group chat name, and optional contact handle.
- Chats is the first screen and lists group chats, DMs, Join or Start, and Me without a bottom tab bar.
- Conversation shows the floating task tile, messages, voice/text composer, invite/share controls, and task activity.
- Join or Start creates group chats, starts DMs, accepts invite codes, and simulates nearby join in tests.
- Me shows notification, privacy, support, and sync controls.

## Apple API Use

- SwiftData stores a local Codable snapshot.
- CloudKit stores deterministic conversation records and creates `CKShare` metadata for shared chats.
- CloudKit public records back short invite-code lookup.
- UserNotifications schedules task reminders with thread context.
- NaturalLanguage, `NSDataDetector`, and optional iOS 26 Foundation Models extract task drafts on device.
- ShareLink, AirDrop, Messages, FaceTime, Phone, MultipeerConnectivity, and optional NearbyInteraction use public Apple APIs for invite and reminder flows.

## Success Criteria

From a clean checkout, `just ci` should pass. Running `just run` should open the app, complete onboarding, start or join a chat, type or record a task request, see the task in the floating tile, mark it done, and use invite/reminder/share actions.
