# onboard

Flutter attendance-tracking app. Riverpod + Drift (SQLite) + go_router. Barcode scanning for check-in, Excel import for students, XLSX report export.

## Verification before you answer

This graph is built and current (1258 nodes, 1823 edges, 67 communities). **Query it instead of grepping raw files** for anything structural.

```bash
graphify query "how does attendance check-in work"   # BFS from matching symbols
graphify query "what depends on AppDatabase" --budget 3000
graphify explain "AttendanceController"              # one node + neighbors
graphify affected "AppDatabase"                      # blast radius of a change
graphify path "AppDatabase" "ReportService"          # why two things are coupled
graphify god-nodes                                   # architectural hubs
```

`graphify-out/GRAPH_REPORT.md` is for broad architecture only. Its cohesion scores and god-node lists are hub-derived placeholders, not reviewed analysis — do not cite them as findings.

**Rebuild after structural changes** (new feature dir, renamed file, refactor that deletes symbols):

```bash
graphify update .          # AST only, no LLM, no API key, ~10s
```

Run it after edits land, not before. Add new file trees to `.graphifyignore` only if they are generated or platform boilerplate.

## How I want to work here

- **Just run mechanical commands.** `graphify update .`, `dart format`, `dart analyze` — no pre-flight dry runs, no asking for permission first. A failed command is cheaper than a round trip.
- **Verify before answering only when the blast radius is real**: schema migrations, anything touching student data, backup/restore, cross-cutting changes to `lib/core/database/`. Those get `dart analyze` and the test suite.
- **Ask one question, not three.** If scope is ambiguous, state the assumption and proceed.
- **Report what changed, briefly.** No padding, no restating the diff back to me.

## Layout

```
lib/core/         database (Drift tables + 4 repositories), backup, export, router, theme
lib/features/     attendance, students, import, reports, history, dashboard, settings
test/             213 nodes - scenario tests under test/features/scenarios/
```

`lib/core/database/` is the hub. `AppDatabase` touches 17 files directly; every feature goes through the repositories. Changes there ripple everywhere.

**`database.g.dart` is gitignored for graphify purposes** (in `.graphifyignore`) - it is build_runner output. Read the hand-written schema in `lib/core/database/tables.dart` instead. It is still committed to git; only the graph skips it.

Community names in the graph are derived from hub filenames (`attendance_controller.dart`), not semantic labels. `graphify label .` would improve them but needs an LLM backend - only run it if asked.
