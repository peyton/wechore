# Contributing

WeChore is source-available for review only and is not open source.

External contributions are not accepted unless they are covered by a separate
written agreement with Peyton Randolph that assigns or licenses the necessary
intellectual property rights. Do not submit pull requests, patches, issues with
implementation code, assets, product copy, or other copyrightable material
unless that written agreement is already in place.

Ideas, security reports, and support questions may be sent to the contact
addresses listed on the WeChore website. Submission of any material does not
grant permission to use, copy, modify, distribute, publish, deploy, submit to an
app marketplace, or create derivative works from WeChore.

## Internal Development

Use the repo-local commands so a clean checkout can reproduce the same tooling
state:

```text
just bootstrap
just generate
mise exec -- just lint
mise exec -- just test-python
```

For app validation, run the focused iOS test targets before release work:

```text
mise exec -- just test-unit
mise exec -- just test-integration
mise exec -- just test-ui
mise exec -- just test-ui-ipad
```

Run `mise exec -- just ci` before cutting release branches or archives. Keep new
automation behind the existing `just` recipes instead of adding one-off global
tool requirements.
