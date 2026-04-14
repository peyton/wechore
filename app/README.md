# WeChore App

WeChore is a SwiftUI iPhone and iPad app for assigning chores, tracking progress, sending reminders, and turning in-app messages into reviewable chore suggestions.

## Architecture

- `WeChore/Sources/Models` contains Codable domain models and the SwiftData snapshot cache.
- `WeChore/Sources/Services` contains app state, CloudKit, notification, message suggestion, and communication handoff services.
- `WeChore/Sources/Shared` contains routing and visual tokens.
- `WeChore/Sources/Views` contains the SwiftUI screens.
- `WeChore/Tests` contains unit tests.
- `WeChore/IntegrationTests` contains fake CloudKit integration coverage.
- `WeChore/UITests` contains end-to-end iPhone and iPad simulator coverage.

## Build

Run from the repository root:

```text
just bootstrap
just generate
just run
```

The app target is `WeChore` for production and `WeChoreDev` for local development. The deployment target is iOS 18.7.
