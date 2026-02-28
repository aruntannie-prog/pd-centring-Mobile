# PD Centring — Flutter App

## Run in 3 steps

### Step 1 — Install Flutter (skip if done)
https://docs.flutter.dev/get-started/install
- Windows: download zip → extract to C:\flutter → add C:\flutter\bin to PATH
- Mac: brew install flutter  OR  download zip → add to PATH

### Step 2 — Install dependencies
```
cd pd_centring
flutter pub get
```

### Step 3 — Run
```
# On your phone (USB debug ON):
flutter run

# As desktop app (Windows/Mac):
flutter run -d windows
flutter run -d macos

# As web in browser:
flutter run -d chrome
```

## Screens
- Splash → auto advances after 3s
- Dashboard → stats, today's count, quick actions, recent bills
- Bills Register → filter by status, search, tap any bill
- Bill Detail → see materials, tap "Mark as Returned" per material
- New Bill / DC → type toggle, customer, site, materials with auto due dates
- Customers → list of 985 clients
- Filter → tap status/date options → results appear live
- Reports → KPIs, top materials, top locations

## Tech
- Flutter 3.x + Dart 3.x
- Provider (state management)
- SharedPreferences (local storage)
- Google Fonts (Playfair Display + Plus Jakarta Sans)
