# Dreamflow / GitHub Sync Check

This file was added specifically to verify that Dreamflow is pulling the current `main` branch from `EMSCodeSim/CPRFlow`.

Expected after the next Dreamflow pull:
- `SYNC_CHECK.md` appears in the project root beside `pubspec.yaml`.
- The CPR evaluation screen contains large `CPR` and `PAUSE` controls with automatic compression-fraction calculation.
- Instructor workflow data is restored from local SharedPreferences after restart.

Verified source state before adding this marker:
- The exported Dreamflow ZIP already matched GitHub `main` byte-for-byte for `.dreamflow`, `pubspec.yaml`, `lib/main.dart`, `lib/app/app_state.dart`, `lib/services/preferences_service.dart`, `lib/screens/ccf_evaluation_screen.dart`, and `lib/screens/widgets/temporary_data_banner.dart`.

Do not edit `.dreamflow` manually; Dreamflow labels it as auto-generated.
