# App Store Compliance Notes

WeChore targets iOS 18.7 and later on iPhone and iPad.

## Privacy

WeChore stores app data locally with SwiftData. Shared household data uses Apple CloudKit sharing through user iCloud accounts. The app does not operate a third-party server for chore sync and does not include ads, analytics SDKs, or cross-app tracking.

## Messaging Boundary

WeChore does not read Messages app conversations. Message suggestions are generated only from text typed inside WeChore. Suggestions are reviewable and are not committed as chores until the user accepts them.

## Voice And Text Handoff

The app does not implement in-app VoIP. Voice actions open FaceTime Audio when a handle is available and fall back to Phone when a phone number is available. Text reminder nudges use Apple Messages handoff.

## Notifications

Due-date reminders are local notifications scheduled by the device after notification permission is allowed.

## Website

The static site in `web/` includes support and privacy pages, public contact addresses, and copy that explains local storage, CloudKit sharing, notifications, message suggestions, and Apple system handoff.
