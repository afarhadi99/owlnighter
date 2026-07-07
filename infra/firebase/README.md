# Firebase / FCM setup

owlnighter uses **Firebase Cloud Messaging (FCM)** for remote push to the
Flutter app, and delivers to iOS through **APNs** (configured inside Firebase).
Local notifications (`flutter_local_notifications`) handle foreground display
and offline fallback scheduling; this doc only covers the remote/server side.

Push send rights live **on the backend only** — the app never holds the FCM
service-account credentials. It registers its device token via
`POST /v1/push/register`, and the API/worker sends messages through the FCM
HTTP v1 API using a service account.

## 1. Firebase project

1. Create (or reuse) a Firebase project. Note its **Project ID** — this is
   `FCM_PROJECT_ID` in `.env`.
2. Add an **Android app** (package name e.g. `org.owlnighter.app`) and an
   **iOS app** (bundle id) to the project.

## 2. Client config files (gitignored — never commit)

These are matched by `.gitignore` (`**/google-services.json`,
`**/GoogleService-Info.plist`) and must be placed locally / injected in CI:

| File | Download from | Place at |
| --- | --- | --- |
| `google-services.json` | Firebase console → Android app → config | `apps/mobile/android/app/google-services.json` |
| `GoogleService-Info.plist` | Firebase console → iOS app → config | `apps/mobile/ios/Runner/GoogleService-Info.plist` |

Because these are gitignored, Codemagic (see `infra/codemagic.sample.yaml`)
must recreate them from encrypted environment variables during the build.

## 3. APNs auth key (iOS delivery)

FCM cannot deliver to iOS until Apple push credentials are uploaded to Firebase.
Prefer an **APNs auth key** (`.p8`) over a certificate — one key works for all
apps in the team and does not expire annually.

1. Apple Developer → **Certificates, Identifiers & Profiles → Keys** → create a
   key with **Apple Push Notifications service (APNs)** enabled. Download the
   `.p8` (you can only download it once).
2. Note the **Key ID** and your **Team ID**.
3. Firebase console → Project settings → **Cloud Messaging** → Apple app
   configuration → **APNs Authentication Key** → upload the `.p8` with its
   Key ID + Team ID.
4. Enable the **Push Notifications** capability in Xcode for the Runner target,
   and add `remote-notification` to `UIBackgroundModes` if you use background
   data pushes.

## 4. Server credentials (backend send)

The backend authenticates to the FCM HTTP v1 API with a Firebase
**service account** JSON key:

1. Firebase console → Project settings → **Service accounts** → *Generate new
   private key*. This downloads a JSON file (matched by
   `**/service-account*.json` in `.gitignore`).
2. Provide it to the backend as an env var, not a file on disk:
   - Local: `FCM_SERVICE_ACCOUNT_JSON` in `.env` (the whole JSON, single line).
   - Cloud Run: stored in Secret Manager and mounted as `FCM_SERVICE_ACCOUNT_JSON`
     (see `infra/cloud-run/api-service.yaml`).
3. `FCM_PROJECT_ID` must match the `project_id` inside that JSON.

## 5. Send payload shapes

owlnighter sends four push types. All use the FCM **HTTP v1** message shape
(`POST https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send`).

Conventions used across all four:

- A `data` block carries a `type` discriminator plus deep-link params. The app
  routes on `type` and builds the `go_router` path
  `readingpath://plan/{planId}/step/{stepId}` (or the `https://` universal link).
- `data` values are **strings only** (FCM requirement).
- `notification` is included so the OS can display the message when the app is
  backgrounded/killed; the `data` block drives in-app deep-linking.
- `apns.headers.apns-priority: "10"` for user-visible alerts; `android.priority:
  "high"` so time-sensitive nightly nudges are not deferred by Doze.

### 5.1 Nightly reminder

```json
{
  "message": {
    "token": "<device_fcm_token>",
    "notification": {
      "title": "Time for tonight's pages",
      "body": "Your next step is 8 pages. Quick quiz unlocks after you read."
    },
    "data": {
      "type": "nightly_reminder",
      "planId": "9f1c...",
      "stepId": "3ab2...",
      "pages": "8",
      "deepLink": "readingpath://plan/9f1c.../step/3ab2..."
    },
    "android": { "priority": "high", "notification": { "channel_id": "nightly" } },
    "apns": { "headers": { "apns-priority": "10" } }
  }
}
```

### 5.2 Streak warning

```json
{
  "message": {
    "token": "<device_fcm_token>",
    "notification": {
      "title": "Don't lose your streak",
      "body": "Read 5 pages tonight to protect your 12-day streak."
    },
    "data": {
      "type": "streak_warning",
      "planId": "9f1c...",
      "stepId": "3ab2...",
      "streakDays": "12",
      "pagesToSave": "5",
      "deepLink": "readingpath://plan/9f1c.../step/3ab2..."
    },
    "android": { "priority": "high", "notification": { "channel_id": "streak" } },
    "apns": { "headers": { "apns-priority": "10" } }
  }
}
```

### 5.3 Completion celebration

```json
{
  "message": {
    "token": "<device_fcm_token>",
    "notification": {
      "title": "Nice work tonight",
      "body": "You finished tonight's reading and gained 20 XP."
    },
    "data": {
      "type": "completion_celebration",
      "planId": "9f1c...",
      "stepId": "3ab2...",
      "xpGained": "20",
      "streakDays": "13",
      "deepLink": "readingpath://plan/9f1c..."
    },
    "android": { "priority": "high", "notification": { "channel_id": "celebration" } },
    "apns": { "headers": { "apns-priority": "10" } }
  }
}
```

### 5.4 Re-engagement

```json
{
  "message": {
    "token": "<device_fcm_token>",
    "notification": {
      "title": "Your book path is waiting",
      "body": "Pick up where you left off."
    },
    "data": {
      "type": "re_engagement",
      "planId": "9f1c...",
      "stepId": "3ab2...",
      "lastActiveDays": "4",
      "deepLink": "readingpath://plan/9f1c.../step/3ab2..."
    },
    "android": { "priority": "normal", "notification": { "channel_id": "reengagement" } },
    "apns": { "headers": { "apns-priority": "5" } }
  }
}
```

> Re-engagement uses **normal**/`apns-priority: "5"` because it is not
> time-sensitive — this avoids burning the high-priority budget that iOS/Android
> reserve for genuinely urgent alerts, and is friendlier to battery.
