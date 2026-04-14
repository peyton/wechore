# CloudKit Setup

WeChore uses Apple CloudKit and `CKShare` for conversation sharing. There is no WeChore-operated sync server.

## Defaults

- Production bundle ID: `app.peyton.wechore`
- Development bundle ID: `app.peyton.wechore.dev`
- Production container: `iCloud.app.peyton.wechore`
- Development container: `iCloud.app.peyton.wechore.dev`
- Team ID default: `3VDQ4656LX`

These values are defined in `scripts/tooling/wechore.env` and passed into Tuist through environment variables.

## Commands

```text
just cloudkit-doctor
just cloudkit-export-schema
just cloudkit-validate-schema
```

`cloudkit-doctor` checks that `xcrun cktool` can see the configured team. `cloudkit-export-schema` writes the current schema to `.state/cloudkit/wechore-cloudkit-schema.json`. `cloudkit-validate-schema` verifies that the exported schema is valid JSON.

## Conversation Record Shape

The Swift `CloudKitConversationStore` writes deterministic record names into the custom zone `wechore-conversations`.

- `ChatThread.<id>`
- `ChatParticipant.<id>`
- `Chore.<id>`
- `ChoreMessage.<id>`
- `TaskActivity.<id>`
- `ThreadInvite.<id>`

Thread-root `CKShare` metadata uses the chat title. Invite codes resolve through short-lived public invite records, while the shared conversation itself stays in the user's CloudKit account. This record shape is covered by unit and integration tests with fake CloudKit clients.
