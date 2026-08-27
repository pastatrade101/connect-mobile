# Makutano Connect — mobile

The inbox in a pocket, and the notification that brings you to it.

Built against Connect's mobile API (`/api/mobile/v1`), which carries the **same
session a browser does** over a bearer header. Every permission, visibility rule and
workspace capability therefore applies to this app unchanged, and a session revoked
in the portal is revoked here.

## Running it

```bash
flutter run                                        # production
flutter run --dart-define=MAKUTANO_API_URL=http://localhost:5188   # local server
```

## Shape

```
lib/
  core/      api.dart · theme.dart · notifications.dart · workspace.dart
  widgets/   primitives.dart   — MobileHeader, AttentionRow, WorkRow, CompactStats…
  screens/   login · home · inbox · thread · work · more · create_enquiry_sheet
```

Home answers three questions in one viewport: what needs me, what do I do next, what
happened today. Navigation is Home · Inbox · **+** · Work · More, and the centre
button offers only what this workspace and this person can actually create.

## Push notifications

The server already sends Firebase messages to whoever holds a thread (`push.ts` in
Connect, `POST /api/mobile/v1/devices` to register a token). To switch real push on:

1. Create a Firebase project, add the iOS and Android apps, and drop in
   `google-services.json` / `GoogleService-Info.plist`.
2. Add `firebase_core` + `firebase_messaging` to `pubspec.yaml`.
3. Call `Notifications.instance.attachPushToken(token)` with the FCM token at
   sign-in. The poller in `notifications.dart` stands down automatically.
4. Put the service-account JSON in Connect's `FCM_SERVICE_ACCOUNT` env var.

Until then the app polls the inbox while it is running and raises a real system
notification for anything new — honest, and it works today.
