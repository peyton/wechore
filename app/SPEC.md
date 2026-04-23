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

- Onboarding is a single screen: name plus either start first chat or join by invite code.
- Chats is the first screen and lists recent group chats and DMs, plus Task Inbox and Me, without a bottom tab bar.
- New Chat is a unified modal that starts group chats, starts DMs, and joins existing chats (code/QR guidance/nearby simulation).
- Conversation shows the compact task rail, messages, voice/text composer, manual task fallback entry, and invite sheet.
- Task Inbox shows cross-chat overdue/today/upcoming/recently-done tasks and deep-links back to source chats.
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
