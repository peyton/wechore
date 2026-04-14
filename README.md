# WeChore

WeChore is an Apple-first chat and task app for iPhone and iPad. It organizes chores around group chats and DMs, keeps task reminders and progress local-first with SwiftData, CloudKit sharing, local notifications, and on-device extraction, and turns plain requests in a conversation into lightweight task tiles.

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
| App Store check          | `just appstore-check` |
| TestFlight upload        | `just testflight-upload` |
| Cloudflare setup         | `just cloudflare-setup` |
| Cloudflare web deploy    | `just cloudflare-deploy` |

## Layout

```text
app/          Tuist workspace, Swift source, unit tests, integration tests, UI tests
web/          Static App Store compliance and marketing site
scripts/      Repo-local tooling wrappers and validation helpers
tests/        Python tests for repo tooling, metadata, CI, and web assets
docs/         Product, CloudKit, CI, App Store, and ExecPlan documentation
```

## Product Boundaries

WeChore does not run a third-party server, does not read iMessage conversations, and does not build in-app VoIP. Collaboration uses CloudKit conversation sharing, invite links, invite codes, and nearby exchange through public Apple APIs. Voice and message reminders hand off to Apple system apps such as FaceTime, Phone, AirDrop, and Messages.

Release and hosting steps are documented in `docs/release-and-distribution.md`.
