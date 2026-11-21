# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

FluffyChat: Flutter Matrix client (AGPL-3.0). Targets Android, iOS, web, Linux, macOS, Windows. Flutter version pinned in `.fvmrc` (CI reads it). Rust needed (vodozemac E2EE).

## Commands

```sh
flutter pub get
flutter run                                  # debug on host platform
./scripts/prepare-web.sh                     # once before web run/build (vodozemac WASM, LiveKit e2ee worker)
flutter build web

flutter test                                 # unit/widget/golden tests
flutter test test/swipe_to_reply_test.dart   # single file
flutter test --plain-name "<name>"           # single test
dart run golden_screenshot:download_apple_fonts   # needed for golden/screenshot tests (CI does this)

./scripts/prepare_integration_test.sh        # needs docker (Synapse); run before every integration run
flutter test integration_test/mobile_test.dart
```

CI lint gate (`.github/workflows/integrate.yaml`) — all must pass:

```sh
dart format lib/ test/ --set-exit-if-changed
flutter analyze
dart run dart_code_linter:metrics analyze lib
dart run dart_code_linter:metrics check-unused-code lib
dart run dart_code_linter:metrics check-unused-files lib
dart run dart_code_linter:metrics check-unused-l10n lib
dart run license_checker check-licenses -c licenses.yaml --problematic
```

Also enforced in CI: no empty strings in `.arb` files (`grep '": ""'`), `pubspec.lock` up to date, no commented-out Dart code ending in `;`, no unused deps (`dependency_validator`), no unused translations (`sweeper`).

## Architecture

- Entry: `lib/main.dart`. Init order: `AppSettings.init()` → vodozemac init → `ClientManager.getClients()` → `FluffyChatApp`. Android also runs a background-push isolate (`mainIsolateReceivePort`, `utils/background_push.dart`, `notification_background_handler.dart`); startup waits for it.
- Business logic lives in the `matrix` Dart SDK (`Client`, `Room`, `Event`). Repo extends it via extensions in `lib/utils/matrix_sdk_extensions/` rather than own models. Multiple accounts = multiple `Client`s, managed by `utils/client_manager.dart`, exposed via `Matrix.of(context)` (`lib/widgets/matrix.dart`).
- Routing: `go_router`, routes in `lib/config/routes.dart` (`AppRoutes`, with logged-in/out redirects), router instance in `widgets/fluffy_chat_app.dart`. Two-column desktop layout: `widgets/layouts/two_column_layout.dart`.
- Config: `lib/config/app_config.dart` (constants), `setting_keys.dart` (`AppSettings` typed prefs on `SharedPreferences`; also loaded from web `config.json` and MDM on Android/iOS — see `config.sample.json`, `android/app/src/main/res/xml/app_restrictions.xml`).
- UI imports `package:material_ui/material_ui.dart`, NOT `package:flutter/material.dart`.
- Calls: Matrix RTC via LiveKit (`utils/matrix_live_kit_calls`, `pages/call`).
- SQLite storage via sqlcipher (`hooks.user_defines.sqlite3` in pubspec); DB code in `utils/matrix_sdk_extensions/flutter_matrix_dart_sdk_database`.

### Controller/View split (`lib/pages/<feature>/`)

Controller = `StatefulWidget` + `State` subclass named `*Controller` (holds state + action methods); `build` returns a stateless `*View` that takes the controller as only param. Views contain no logic; actions are zero-arg methods on controller so view can pass them as callbacks. Non-trivial calculation → helper in `lib/utils/`. Newer code also uses `ViewModelBuilder` (`widgets/view_model_builder.dart`, `ValueNotifier`-based view models, e.g. `pages/chat/recording_view_model.dart`). File names lower_snake_case.

### Localization

Source of truth: `lib/l10n/intl_en.arb`. Other `.arb` files are managed by Weblate — do not edit them. Generated `lib/l10n/*.dart` is gitignored (produced by `flutter pub get`/`flutter gen-l10n`); import via `package:fluffychat/l10n/l10n.dart`. `/command` hints: add `commandHint_<lowercase>` to `intl_en.arb`, run `scripts/generate_command_hints_glue.sh` to regenerate `lib/pages/chat/command_hints.dart`. After adding a locale run `scripts/generate-locale-config.sh`.

## Conventions (from CONTRIBUTING.md)

- Prefer simple; no abstraction unless used in 2+ places. Avoid `else` — use guards, early returns, `switch`.
- No code comments except to mark workarounds (link upstream issue) or explain unusual *why*.
- Do not add functionality in platform dirs (`android/`, `ios/`, etc.); platform code goes through external packages. Keep dependencies minimal.
- Conventional Commits, signed, one commit per PR, rebase not merge. Every file carries SPDX license header (`scripts/update-license-headers.sh`, `REUSE.toml`).
- Lint specifics in `analysis_options.yaml`: single quotes, trailing commas required, `prefer_final_locals`, `omit_local_variable_types`, `directives_ordering`, `avoid_returning_widgets`, `avoid-dynamic`.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
