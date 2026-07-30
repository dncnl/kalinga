# Branding assets

Drop the two logo PNGs in this folder with these exact filenames — the
code already references them by these paths:

- `kalinga-logo-app.png` — square icon mark (the "K heart" icon)
- `kalinga-logo-text.png` — the "Kalinga" wordmark

Referenced from:
- `lib/pages/welcome_page.dart`
- `lib/pages/auth_page.dart`
- `lib/pages/family_register_page.dart`

Already registered in `pubspec.yaml` under `flutter: assets:`, so no
further config is needed once the files are here — just `flutter pub get`
(or hot-restart) after adding them.
