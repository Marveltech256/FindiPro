# FindiPro

A Flutter marketplace app for finding local service providers (plumbers, mechanics,
electricians, cleaners, etc.), requesting bookings, and leaving reviews.

## Status of this scaffold

This is a **working UI prototype** wired to local mock data (`lib/data/mock_data.dart`)
so you can run it immediately and see the full flow — no backend required yet.

Screens included:
- Splash → Login → Sign up (with Customer / Service Provider role picker)
- Home: search bar, category grid, top-rated providers
- Category → provider list
- Provider detail: bio, skills, price, reviews, "Request to hire"
- Booking request form (service, date, notes)
- Customer profile tab
- Provider dashboard (accept/decline incoming requests) — not yet linked into
  navigation; wire it in once you have role-based auth (see below)

## Design system

Everything visual lives in **`lib/theme/app_theme.dart`** — colors, fonts, button/input
styles. Right now it's a placeholder navy/teal/gold palette because I couldn't pull your
site's design programmatically (`dev-movie-champ.pantheonsite.io` blocks automated
fetching). **Send me screenshots or your CSS values and I'll update just this one file**
to match your site's Forest Green / Safari Gold / Earth Brown / Sky Blue / Soft Ivory
palette and Playfair Display / Poppins / Inter fonts exactly — no screen code needs to
change.

## Run it

```bash
cd findipro
flutter pub get
flutter run
```

## Next steps to make it real

### 1. Connect Firebase
```bash
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage firebase_messaging
dart pub global activate flutterfire_cli
flutterfire configure
```
Then uncomment the Firebase lines in `pubspec.yaml` and `lib/main.dart`.

### 2. Suggested Firestore structure
```
users/{uid}         -> name, email, role ('customer' | 'provider')
providers/{uid}      -> categoryId, bio, skills[], priceRange, rating, reviewCount, location, available
bookings/{id}        -> providerId, customerId, serviceNeeded, notes, requestedDate, status
reviews/{id}         -> providerId, customerId, rating, comment, date
```

### 3. Replace mock data
Swap `MockData.providers` / `.categories` / `.reviews` in the screens for
`FirebaseFirestore.instance.collection(...).snapshots()` streams. The screens already
consume simple `List<ServiceProvider>` etc., so this is a localized change per screen.

### 4. Auth-gate the dashboard
After sign-up, store `role` on the user doc. On login, route `provider` accounts to
`ProviderDashboardScreen` and `customer` accounts to `HomeScreen`.

### 5. Location
Currently text-based (`location` field on provider, e.g. "Ntinda, Kampala"). If you want
map-based "near me" search later, add `geoflutterfire2` + Google Maps API key — happy to
wire that in when you're ready.

## Android build
Standard Flutter Android build — no native code was touched:
```bash
flutter build apk --release
```
