# SafeGuard — Community Security & Emergency Response

SafeGuard is a community security and emergency response mobile platform with
AI-assisted incident classification. It is demonstrated for **Kakoba Division,
Mbarara City** (see `SafeGuard_Expanded_Proposa.docx` in the parent folder).

Built with **Flutter** and **Firebase** (Auth, Firestore, Storage, Cloud
Messaging, Cloud Functions).

## Features

- **Role-based experience** - Citizens, Responders and Administrators get
  tailored shells after sign-in.
- **Incident reporting** with GPS location (Kakoba fallback), multiple photo
  evidence and category pills.
- **AI-assisted classification** - a Cloud Function (`classifyIncident`)
  keyword-classifies reports, assigns a priority, confidence and summary, and
  flags duplicates. Swap `keywordClassify()` in `functions/index.js` for a
  Vertex AI / LLM call without changing anything else.
- **Panic SOS** - 3-second countdown, GPS pin, one-tap emergency call list,
  dispatched to nearby responders, escalated if none are in range, and pushed
  to trusted contacts.
- **Live incident map** with color-coded category markers around Kakoba.
- **Responder console** - claim/assign, advance status (assigned, in progress,
  resolved, closed).
- **Admin dashboard** - incident analytics (fl_chart), hotspots, hotlines,
  responder assignment, community alert broadcast, and user management
  (suspend / reactivate / delete).
- **Community alerts** - severity-graded broadcasts sent via Cloud Messaging.
- **Notifications** - in-app inbox plus Firebase push.

## Demo mode (no Firebase required)

Without a Firebase project the app **automatically falls back** to a seeded
in-memory repository (`DemoRepository`) so you can run the whole product
instantly.

```bash
flutter pub get
flutter run                      # any platform
```

Demo accounts (password `demo1234`):

| Role | Email |
| --- | --- |
| Citizen | citizen@demo.safeguard |
| Responder | responder@demo.safeguard |
| Administrator | admin@demo.safeguard |

Force demo mode even when Firebase is configured:

```bash
flutter run --dart-define=DEMO_MODE=true
```

## Wiring up Firebase (live mode)

1. Create a Firebase project and enable **Authentication (email/password)**,
   **Cloud Firestore**, **Storage**, **Cloud Messaging** and **Functions**.
2. Register the Android app (package `com.example.safesecurity` by default).
3. Drop `google-services.json` into `android/app/`. Then either:
   - `firebase init` + `firebase deploy --only firestore:rules,storage` to
     publish the rules in `firestore.rules` / `storage.rules`, and
     `cd functions && npm install && firebase deploy --only functions`; or
   - `firebase init emulators` and use Firebase Emulator Suite locally.
4. The incident map uses **OpenStreetMap** via `flutter_map` — no API key or
   billing account is required. An internet connection is needed to load map
   tiles.
5. Emulators (optional): `firebase emulators:start`.

## Repository layer

All screens talk to a single `IRepository` interface:

- `lib/repositories/demo_repository.dart` - seeded in-memory implementation.
- `lib/repositories/firebase_repository.dart` - live Firebase implementation.

The bootstrap in `lib/main.dart` tries Firebase first and falls back to demo.

## Backend (functions/)

- `classifyIncident` - AI-assisted classification + duplicate detection.
- `notifyIncidentOnCreate` - push admins + nearby responders.
- `onIncidentChanged` - status updates & responder assignment notifications.
- `notifySos` - responder dispatch (radius), trusted-contact alerting, escalation.
- `broadcastCommunityAlert` - fan out alerts to every user with FCM.

## Verification

```bash
cd safesecurity
flutter analyze      # should report "No issues found!"
flutter test         # boots the app into login screen (demo mode)
flutter build apk --debug
```