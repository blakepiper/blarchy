# BLARCHY migrations

BLARCHY migrations are deterministic, one-time repair scripts for existing
installs. They are sourced only from the installed BLARCHY runtime and never
from Omarchy.

## Migration model

Migration source is installed under:

```text
/usr/local/share/blarchy/migrations/*.sh
```

`blarchy migrate` sorts migrations by filename and records completion per user.
Already completed migrations are skipped, scripts must be idempotent, and a
failed migration is not marked complete. The retained `omarchy-migrate` route
may remain as a compatibility wrapper but must use the same BLARCHY-owned
source and state.

Completion markers live under `~/.local/state/blarchy/migrations/`. On the
first v0.2 run, marker filenames from `~/.local/state/omarchy/migrations/` are
imported once so completed historical migrations are not replayed.

Migrations run as the current user. A migration may repair user/session state
and may request privilege explicitly when an unavoidable machine-wide repair
is in scope. Another user running the same repair must detect already-correct
machine state and no-op safely.

## Fresh installs and v0.1 upgrades

A fresh installation records the migrations shipped in its installed release
as the initial baseline, so it does not replay historical upgrade work.

An existing v0.1 installation imports its compatible completion records before
running v0.2 migrations. The v0.2 transition may repair old checkout-backed
paths, command links, environment variables, units, and update state, but must
not delete unrelated user data. Retained config and state under the `omarchy`
namespace remain valid unless a specific migration says otherwise.

Migrations that declare `# blarchy:standalone-safe=false` are excluded from the
standalone path. This prevents inherited boot/snapshot migrations from taking
ownership of an existing Arch installation.

## When migrations run

`blarchy update` refreshes the installed runtime and runs pending migrations in
the visible update terminal. The installer does the same when explicitly rerun
from source. A graphical-login notifier may report pending migrations, but it
does not execute them silently.

Normal `yay -Syu` transactions do not change the BLARCHY runtime or migration
feed and therefore cannot introduce BLARCHY migrations.

Users can inspect or apply them manually:

```bash
blarchy migrate --pending
blarchy migrate
```

## Creating a migration

Put new migrations directly under `migrations/<unix timestamp>.sh`.

- Use mode `0644`; the runner invokes `bash -euo pipefail`.
- Omit a shebang.
- Start with an `echo` describing the change.
- Use `$BLARCHY_PATH` for installed BLARCHY assets. Use `$OMARCHY_PATH` only
  when repairing inherited state or supporting an explicit compatibility path.
- Make every operation safe to rerun.
- Prefer BLARCHY/retained helper commands over direct package-manager calls
  unless the migration is specifically repairing package-helper state.
- Back up user files before a destructive transformation.

`bin/omarchy-upgrade-to-quattro` is retained historical upstream upgrade code.
It is not part of BLARCHY's supported install or update path; do not put new
BLARCHY migration work there.
