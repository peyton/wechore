# WeChore

WeChore is an Apple-first chore coordination app for iPhone and iPad. It keeps household chores, reminders, progress checks, and message-derived suggestions local-first with SwiftData, CloudKit sharing, local notifications, and on-device text parsing.

## Build And Run

```text
just bootstrap
just generate
just run
```

Open `app/WeChore.xcworkspace` after generation if you prefer Xcode.

## Common Commands

| Task                     | Command             |
| ------------------------ | ------------------- |
| Bootstrap tools          | `just bootstrap`    |
| Generate Xcode workspace | `just generate`     |
| Build app                | `just build`        |
| Run app                  | `just run`          |
| Unit tests               | `just test-unit`    |
| UI tests on iPhone       | `just test-ui`      |
| UI tests on iPad         | `just test-ui-ipad` |
| Python/tooling tests     | `just test-python`  |
| All validation           | `just ci`           |
| Lint                     | `just lint`         |
| Format                   | `just fmt`          |
| Web check                | `just web-check`    |

## Layout

```text
app/          Tuist workspace, Swift source, unit tests, integration tests, UI tests
web/          Static App Store compliance and marketing site
scripts/      Repo-local tooling wrappers and validation helpers
tests/        Python tests for repo tooling, metadata, CI, and web assets
docs/         Product, CloudKit, CI, App Store, and ExecPlan documentation
```

## Product Boundaries

WeChore does not run a third-party server, does not read iMessage conversations, and does not build in-app VoIP. Collaboration uses CloudKit sharing. Voice and message reminders hand off to Apple system apps such as FaceTime, Phone, and Messages.

## Source Availability And License

WeChore is source-available for review only and is not open source. Copyright (c) 2026 Peyton Randolph. All rights reserved.

No license is granted to use, copy, modify, merge, publish, distribute, sublicense, sell, offer for sale, deploy, submit to an app marketplace, create derivative works from, or otherwise exploit this project in source or binary form without a separate written license from Peyton Randolph.

Any fork, mirror, archive, or copy that exists because of a source hosting platform's functionality must preserve the copyright notice and rights reservation, and must not be distributed, deployed, published, submitted to an app marketplace, or used to create derivative works. No trademark, trade dress, app name, app icon, branding, or design rights are granted.
