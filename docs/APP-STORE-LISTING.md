# App Store listing — copy-paste pack

Everything App Store Connect asks for, written against what the app actually
does. Fields are in the order the console presents them. Character limits are
Apple's and are already respected.

**Nothing here can be filled in automatically** — App Store Connect has no API
key on the build machine, and the console needs an interactive sign-in.

---

## App Information

| Field | Value |
| --- | --- |
| Name (30) | `Makutano Connect` |
| Subtitle (30) | `Run your safari business` |
| Primary category | Business |
| Secondary category | Travel |
| Content rights | Does not contain, show, or access third-party content |
| Age rating | **4+** — nothing in the questionnaire applies. Answer *None* to every violence, sexual content, profanity, horror, gambling, contests and drugs question; *No* to unrestricted web access; *No* to user-generated content shown publicly (chats are private, between an operator and their own customer). |

## Pricing and Availability

Free. Available in all territories — the customers are Tanzanian operators, but
their staff travel and TestFlight testers may be anywhere.

## Version Information (1.1.2)

**Promotional text** (170, editable without a new build)

```
Answer WhatsApp enquiries, send quotes and follow every vehicle on one map —
from the seat of the car, not the office.
```

**Description** (4000)

```
Makutano Connect is the operator's app for a Tanzanian tour business. It puts
the day's work — enquiries, quotes, trips and vehicles — on the phone of whoever
is actually running it.

WHAT YOU CAN DO

Inbox
Every WhatsApp enquiry lands in one shared inbox. Reply from the app, hold a
conversation so a colleague does not answer it twice, and pick it back up on the
web without losing the thread.

Enquiries and quotes
Turn an enquiry into a quotation without retyping it. Send it, revise it, and
see when the traveller opens it.

Trips
The operational half of a booking: who is driving, which vehicle, what is still
missing before departure. A trip that is blocked and leaving soon says so.

Live vehicle tracking
See where the fleet is on a full-screen map, switch between vehicles, and follow
a route over the last six or twenty-four hours. Positions come from each
vehicle's own tracker, not from this phone — the app never reads your location.

Travellers
Names, numbers and history for the people you have actually carried.

WHO IT IS FOR

Tour operators and safari companies in Tanzania and East Africa, and the guides,
drivers and office staff who work with them. You need a Makutano Connect
workspace to sign in; the app is the companion to connect.makutano.co.tz, not a
separate product.

Sign in with the account your workspace owner created for you.
```

**Keywords** (100, comma-separated, no spaces after commas)

```
safari,tour operator,tanzania,fleet,tracking,whatsapp,quotation,booking,trip,travel,itinerary,arusha
```

**Support URL** — `https://connect.makutano.co.tz/legal/terms`
**Marketing URL** — `https://connect.makutano.co.tz`
**Copyright** — `2026 Makutano`
**Version** — set the record to **1.1.2** (it currently reads 1.0 and must match the build)

## App Privacy

Answers are derived from the code, not assumed.

**Does this app collect data?** Yes.

| Data type | Collected | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| Contact info — name, email, phone | Yes | Yes | No | App functionality |
| User content — messages, photos in chats | Yes | Yes | No | App functionality |
| Identifiers — user ID, push token | Yes | Yes | No | App functionality |
| Contacts | No | | | |
| **Location** | **No** | | | The app displays VEHICLE positions from the server. It has no location package, no `NSLocation*UsageDescription`, and never reads this device's location. |
| Purchases, financial info | No | | | |
| Browsing history, search history | No | | | |
| Diagnostics, usage data, analytics | No | | | Firebase is present for push messaging only; no analytics SDK is linked. |

**Tracking (ATT):** No. The app does not track users across apps or websites and
links no data to third-party data for advertising. No `NSUserTrackingUsageDescription`
is needed and none is present.

**Privacy Policy URL** — `https://connect.makutano.co.tz/legal/privacy` (live, 200)

## App Review Information

**Sign-in required:** Yes. This is the blocker to sort before submitting —
Apple rejects a login-gated app without working credentials.

Create a demo workspace with representative data (a few enquiries, one trip, one
vehicle reporting positions) and put its email and password in the demo account
fields. Do not use a real customer workspace: reviewers will read the messages.

**Notes for the reviewer**

```
Makutano Connect is a business app for tour operators. It requires an account on
the operator's own workspace; there is no public sign-up in the app, because
workspaces are created by the business owner on the web at
connect.makutano.co.tz.

Use the demo credentials above. Everything in that workspace is test data.

Live vehicle tracking: positions come from GPS trackers fitted to the operator's
vehicles and are read from our server. The app does not request or use the
location of the device it runs on, which is why no location permission is
requested.

WhatsApp: the Inbox shows messages the operator receives through their own
WhatsApp Business account via the official WhatsApp Cloud API. The app is not
affiliated with or endorsed by WhatsApp or Meta.
```

**Export compliance** — handled in code. `ITSAppUsesNonExemptEncryption` is set
to `false` in `Info.plist`, which is correct: the app uses only standard HTTPS
and no proprietary cryptography. Apple will stop asking on every upload.

## Screenshots — the one thing that still needs a person

Required: at least one 6.5-inch set. Accepted sizes are **1242 × 2688** or
**1284 × 2778** portrait.

These cannot be generated unattended, because every screen worth showing is
behind a sign-in and the password must not pass through tooling. The workable
split is: boot the simulator and install the app, a human types the password
once, then the screens are captured and resized to the exact pixel dimensions.

Suggested five, in order:

1. **Inbox** — the shared WhatsApp inbox, a few conversations
2. **Live map** — full-screen tracking with a vehicle selected and its card open
3. **Trip** — one trip showing readiness
4. **Quotation** — a quote ready to send
5. **Home** — the day at a glance

Avoid real customer names and numbers; use the demo workspace.
