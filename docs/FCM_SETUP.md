# FCM broadcast setup (Android)

Admin broadcast pushes (semester updates, announcements) use Firebase Cloud Messaging.
Local class reminders stay on-device (`ClassNotificationService`); FCM is operator-only.

## 1. Firebase Console (one-time)

1. Create a Firebase project (or reuse an existing DevClub project).
2. Add an **Android app** with package name `com.devclub.classgrid`.
3. Download **`google-services.json`** and place it at
   `app/android/app/google-services.json` (copy from
   `app/android/app/google-services.json.example` as a template, then replace all
   `REPLACE_ME` values with the downloaded file).
4. In Google Cloud for the same project, enable **Firebase Cloud Messaging API**.
5. Create a **service account** with **Firebase Cloud Messaging Admin** (or use an
   existing Firebase Admin SDK service account). Download the JSON key.

**Never commit the service account JSON.** Client `google-services.json` is safe to commit.

Add to `.gitignore` (already in repo):

```
**/firebase-service-account*.json
```

## 2. Local backend

In `server/.env`:

```bash
FIREBASE_SERVICE_ACCOUNT_PATH=/absolute/path/to/firebase-service-account.json
```

Run migration `016` (see `server/db/migrations/016_user_fcm_tokens.sql`), then restart the API.

Without `FIREBASE_SERVICE_ACCOUNT_PATH`, token registration still works; `POST /api/admin/push`
returns `503 fcm_unconfigured`.

## 3. Production (Azure VM)

1. Run migration on Postgres:
   ```bash
   sudo bash -c 'set -a && source /etc/classgrid/db.env && set +a && /opt/classgrid-db/migrate.sh'
   ```
2. Copy the service account JSON to the VM:
   ```bash
   sudo install -m 640 -o root -g azureuser \
     ./firebase-service-account.json /etc/classgrid/firebase-service-account.json
   ```
3. Append to `/etc/classgrid/api.env`:
   ```bash
   FIREBASE_SERVICE_ACCOUNT_PATH=/etc/classgrid/firebase-service-account.json
   ```
4. Deploy API: `./deploy.sh --api`
5. Ship a new APK with real `google-services.json` baked in:
   ```bash
   ./scripts/release-android-apk.sh --build
   ```

## 4. Verification

| Check | How |
|-------|-----|
| Token registration | Install app → row in `user_fcm_tokens` (kerberos NULL for guests) |
| Topic broadcast | Firebase Console → Cloud Messaging → topic `classgrid_broadcast` |
| Admin panel | `/admin/push` → audience **All app installs** or **Signed-in devices only** |
| Missing FCM config | API push returns `fcm_unconfigured`; app boots without crash |
| Local reminders | Calendar bell still schedules **local** alarms (unchanged) |

## Architecture notes

- Every Android install subscribes to topic `classgrid_broadcast` (covers guests + **audience: all**).
- Signed-in devices also register FCM tokens via `POST /api/me/fcm-token` for **audience: signed_in**.
- Invalid tokens are removed from `user_fcm_tokens` when FCM returns `registration-token-not-registered`.
