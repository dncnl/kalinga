# Fix: "Add another profile" redirects straight back to /home

Branch: `fix/add-another-profile-redirect-loop`, cut from `main`.

## Bug report (from Ralph)

"Add Another Patient is not working."

## Root cause

`router.dart`'s redirect guard treated `/patient` as onboarding-only:

```dart
final onboarding = loc == '/language' || loc == '/patient';
if (onboarding) return '/home';
```

This runs whenever `SelectedProfile.hasProfile` is true. `ProfilePickerPage`'s
"Add another profile" button pushes `/patient` again for exactly that case
(a caregiver who already has a profile) — so the redirect fired before the
page ever rendered and bounced straight back to `/home`. The button looked
completely broken; it never even showed the form.

## Fix

Dropped `/patient` from that guard, kept `/language` (re-picking a
language once a profile exists never makes sense, and nothing revisits
`/language` intentionally the way `/patient` gets reused for "add
another"). Confirmed `/patient` doesn't need the guard's help: it already
branches correctly on `editing` (create vs. edit) regardless of
`hasProfile`, and navigates itself on success
(`prototype_patient_page.dart`'s `context.go('/home')` /
`context.pop()`), so nothing relied on the redirect to leave the page.

## Status

- [x] Fixed in `router.dart`, `flutter analyze` clean, mobile suite 15/15
- [ ] Manual verification: from an existing profile, Profiles → Add
      another profile → form appears (not an instant bounce to /home)
- [ ] PR, merge to `main`
