# MyClient Mobile

Flutter mobile app for the MyClient POC.

## Current scope

- Flutter app for Android and iOS.
- Hebrew and RTL-first UI.
- Local mock-auth login for backend development.
- Business onboarding.
- Main shell with bottom tabs: Home, Customers, Calls, More.
- First Home screen connected to `GET /businesses/:businessId/home`.

Firebase Phone Auth and FCM are intentionally deferred until the first real-device phase.

## Run locally

Start the backend from the sibling `dev` repo first:

```bash
cd ../dev
docker compose up -d --build
npm run seed:demo
```

Run iOS Simulator against local Core:

```bash
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=AUTH_MODE=mock \
  --dart-define=CORE_BASE_URL=http://localhost:3000
```

Run Android emulator against local Core:

```bash
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=AUTH_MODE=mock \
  --dart-define=CORE_BASE_URL=http://10.0.2.2:3000
```

For a physical device, use a backend URL reachable from that device on the same network.

## Dev login

The first login screen expects:

- `Firebase UID`, for example `firebase_demo_1`.
- mock phone number is optional. Leave it empty unless you specifically test phone-based auto-linking.

Those values should match the output of `npm run seed:demo`.
