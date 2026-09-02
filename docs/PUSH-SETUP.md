# Turning on push notifications

Everything in the code is already done. What is left is the part only the account
owner can do: create the Firebase project, and hand its credentials to the two
sides — the phone (config files) and the server (a service account).

Until that happens the app still notifies, by polling the inbox once a minute while
it is open. Push replaces that automatically the moment a token registers.

Identifiers this build uses — Firebase will ask for them exactly:

| | |
|---|---|
| Android package name | `tz.co.makutano.makutano_connect` |
| iOS bundle ID | `tz.co.makutano.makutanoConnect` |
| Notification channel (Android) | `makutano_inbox` |

---

## 1 · Create the Firebase project — 3 minutes

1. Go to <https://console.firebase.google.com> and sign in with the Google account
   that should own this. **Create a project**, call it `Makutano Connect`.
2. Google Analytics: **turn it off**. Nothing here uses it.

## 2 · Android — the phone half

3. In the project, **Add app → Android**.
   - Android package name: `tz.co.makutano.makutano_connect`
   - Nickname: `Connect Android`. Leave the SHA-1 field empty.
4. Download `google-services.json` and put it here:

   ```
   makutano-connect-mobile/android/app/google-services.json
   ```

   That is all Android needs. The Gradle wiring is already in place and switches
   itself on when it finds the file (and stays quiet when it does not).

## 3 · iOS — only if you want push on iPhones

This part needs a paid **Apple Developer Program** membership. Skip it for now if
you are starting with Android; nothing else depends on it.

5. **Add app → Apple**, bundle ID `tz.co.makutano.makutanoConnect`.
6. Download `GoogleService-Info.plist`. Open `ios/Runner.xcworkspace` in Xcode and
   drag the file onto the **Runner** group — tick *Copy items if needed* and make
   sure **Runner** is checked under *Add to targets*. Dropping it in Finder is not
   enough; Xcode has to know about it.
7. Apple Developer → **Certificates, Identifiers & Profiles → Keys → +** →
   tick **Apple Push Notifications service (APNs)** → Continue → Register →
   **Download** the `.p8`. Apple lets you download it once. Note the **Key ID** on
   that page and your **Team ID** (top right of the developer portal).
8. Firebase → ⚙ **Project settings → Cloud Messaging → Apple app configuration →
   APNs authentication key → Upload**: the `.p8`, the Key ID, the Team ID.
9. Still in Xcode, **Runner target → Signing & Capabilities → + Capability**:
   add **Push Notifications**, then add **Background Modes** and tick
   *Remote notifications*. (The Info.plist entry is already committed; the
   entitlement itself has to be added here because it is tied to your team.)

> The iOS **Simulator can never receive a real push** — Apple does not give it an
> APNs token. Test on a real iPhone. On the simulator the app notices and falls
> back to polling, which is why alerts still work there.

## 4 · The server half — one environment variable

10. Firebase → ⚙ **Project settings → Service accounts → Generate new private key**.
    A JSON file downloads. It is a secret: it can send push to your users.
11. Turn it into one safe line (JSON in a `.env` file gets mangled by quotes and
    newlines — the server accepts base64 for exactly this reason):

    ```bash
    base64 -i ~/Downloads/makutano-connect-firebase-adminsdk.json | tr -d '\n' | pbcopy
    ```

12. On the production server, add it to Connect's `.env` and restart:

    ```bash
    ssh -i ~/.ssh/makutano_connect_deploy -p 2807 makutano@194.163.139.108
    cd /home/makutano/app/services/connect
    echo "FCM_SERVICE_ACCOUNT=<paste the base64 here>" >> .env
    docker compose up -d
    ```

    No migration is needed — the `device_tokens` table already exists in production.

## 5 · Check it works

13. Install the app on a real phone and sign in. On launch it asks Firebase for a
    token and registers it at `POST /api/mobile/v1/devices`.
14. Confirm the device arrived:

    ```sql
    select platform, device_name, created_at from device_tokens order by created_at desc;
    ```

15. Have someone WhatsApp the business number. The phone of whoever holds that
    thread should buzz within a second or two. If nobody holds it, everyone who
    could pick it up is notified — owners, admins and managers, never the whole
    company for every ping.

## What gets pushed today

| When | Who hears about it |
|---|---|
| A customer sends a WhatsApp message | The assignee — or, if unassigned, owners/admins/managers |
| A thread is handed to someone | That person (never the one doing the handing) |
| A private thread receives a message | Only its assignee. Never anyone else. |

Tapping any of them opens that conversation directly.

## If it does not work

- **No token on iOS** — almost always the missing Push Notifications capability
  (step 9) or a simulator. The app logs `push unavailable:` with the reason.
- **Token registers but nothing arrives** — check the server has the variable:
  `docker compose exec connect printenv FCM_SERVICE_ACCOUNT | head -c 20`.
  Empty means push is inert (by design — Connect never errors over a missing key).
- **Android builds fail after adding the file** — the package name in
  `google-services.json` must match `tz.co.makutano.makutano_connect` exactly.

---

# Rive artwork (optional)

`RiveArt` plays `assets/rive/<name>.riv` when the file exists and shows a coded
animation when it does not, so no screen is ever blank waiting for artwork.

Slots the app already looks for:

| file | where it appears |
|---|---|
| `assets/rive/splash.riv` | first launch, while the session is restored |
| `assets/rive/empty_inbox.riv` | the inbox with no conversations |
| `assets/rive/empty_work.riv` | Work with nothing open |
| `assets/rive/success.riv` | after something completes |

Drop a `.riv` in with the matching name — no code change, it takes over on the
next launch.

**One build gotcha, already worked around.** `rive_native` 0.1.11's podspec runs
its setup from the `Pods` directory, where there is no `pubspec.yaml`, so a clean
iOS build fails with *"Could not find a file named pubspec.yaml"*. Run this once
from the project root and the build script finds its marker and skips:

```bash
dart run rive_native:setup --verbose --platform ios
```

Anyone cloning this repo will hit the same thing on their first iOS build.
