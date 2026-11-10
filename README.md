# TaskMate

Flutter app for TaskMate: personal tasks with reminders, servers (group tasks,
chat and member ratings), direct messages and notifications. It talks to the
FastAPI backend in `taskmate-server`; the screens follow the original Firebase
version of the app.

## Run it

1. **Windows only, once:** turn on *Developer Mode* (`start ms-settings:developers`).
   Flutter needs symlink support to build any app that uses plugins.
2. Start the backend (`docker compose up` in `taskmate-server`, port 8000).
3. Check `.env`:
   - `API_BASE_URL` – leave empty to use the default (`http://localhost:8000`, or
     `http://10.0.2.2:8000` on the Android emulator). On a real phone use your
     PC's LAN IP, e.g. `http://192.168.1.20:8000`.
   - `GOOGLE_SERVER_CLIENT_ID` – the same OAuth *web* client ID as `GOOGLE_CLIENT_ID`
     in the backend `.env`. Only needed for "Continue with Google".
4. `flutter pub get`, then `flutter run` (pick Windows, Chrome or an Android device).

## How it is put together

```
lib/
  core/        theme, constants, config (.env), formatting helpers
  models/      JSON <-> Dart for the backend's responses
  services/    ApiClient + one class per area of the API, WebSocket, reminders
  providers/   app state (Provider): auth, tasks, chats, alerts, servers
  screens/     one folder per tab (tasks, servers, chats, notifications, profile)
  widgets/     shared widgets (task card, chat view, avatar, rating dialog, ...)
```

- **Sign in / sign up** use the backend's JWT. Registering is two steps: email +
  password, then *Complete Profile* (nothing is created until the second step).
  Forgot password sends a 6-digit code by email.
- **Personal tasks are offline-first.** Changes are saved on the device and pushed
  to `PUT /task/{client_id}` in the background; pull-to-refresh syncs again.
- **Realtime:** one WebSocket (`/ws`) delivers new messages, edits, read receipts and
  notifications. It reconnects by itself.
- **Reminders** (8 AM, 2 PM, 8 PM on the 3 days before a deadline and on the day)
  are scheduled on the device with `flutter_local_notifications` on Android, iOS
  and macOS.

## Tests

`flutter test` runs unit tests for the models, the API client and the task sync,
plus a smoke test that opens every screen against a fake backend. Set `SHOT_DIR`
to a folder to also save a screenshot of each step.
