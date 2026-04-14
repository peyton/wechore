# App Store Compliance Notes

WeChore targets iOS 18.7 and later on iPhone and iPad.

## Privacy

WeChore stores app data locally with SwiftData. Shared chat and task data uses Apple CloudKit sharing through user iCloud accounts. The app does not operate a third-party server for sync and does not include ads, analytics SDKs, or cross-app tracking.

## Encryption

`app/WeChore/Info.plist` sets `ITSAppUsesNonExemptEncryption` to `false`. The
app uses Apple's platform networking, CloudKit, and local device APIs and does
not include custom or non-exempt encryption. This lets App Store Connect answer
the export compliance encryption prompt from the uploaded binary metadata.

## Messaging Boundary

WeChore does not read Messages app conversations. Task extraction runs only on text typed inside WeChore or voice transcripts recorded inside WeChore. Clear requests can create tasks automatically with undo/edit affordances; ambiguous requests stay as reviewable drafts until the user confirms them.

## Voice And Text Handoff

The app does not implement in-app VoIP. Voice actions open FaceTime Audio when a handle is available and fall back to Phone when a phone number is available. Text reminder nudges and invite links use Apple Messages and share-sheet handoff.

## Notifications

Due-date reminders are local notifications scheduled by the device after notification permission is allowed. CloudKit subscriptions can surface shared task changes from other participants.

## Website

The static site in `web/` includes support and privacy pages, public contact addresses, and copy that explains local storage, CloudKit sharing, notifications, task extraction, invite links, and Apple system handoff.
