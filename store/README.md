# App Store listing — copy-paste pack

Everything App Store Connect asks for, written against what the app actually
does. Fields are in the order the console presents them. Character limits are
Apple's and are already respected.

**Nothing here can be filled in automatically** — App Store Connect has no API
key on the build machine, and the console needs an interactive sign-in.

```
store/
  README.md            this file — every field, ready to paste
  sample-images/       drop tour photos here (see its own README)
  screenshots/
    6.9-inch/          1320 × 2868 — iPhone, required
    13-inch/           2064 × 2752 — iPad, required while the app ships for iPad
```

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

**Sign-in required:** Yes. Apple rejects a login-gated app without working
credentials.

The demo workspace exists and is seeded:

| Field | Value |
| --- | --- |
| Demo email | `demo@makutano.co.tz` |
| Demo password | *not written down here — paste it straight into App Store Connect* |
| Workspace | Serengeti Trails Safaris (`serengeti-trails-safaris`) |

It holds 5 customers and enquiries, 5 WhatsApp threads with 22 messages, 2
quotations (one accepted), 1 confirmed booking with a deposit paid, 1 trip with
driver, guide and vehicle assigned, plus 4 crew and 3 vehicles. Every name,
number and email is invented; the emails are all `@example.com`.

Two things about it that are easy to undo by accident:

- **Its trial runs to 2027-12-31.** Apple re-reviews against these same
  credentials on every resubmission and for support enquiries months later. If
  the trial lapses the reviewer's login becomes a paywall and the build is
  rejected for a broken demo account. Do not delete or suspend the workspace
  after a release.
- **It is in the production database**, alongside real tenants. Anything seeded
  into it must stay scoped to that tenant id.

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

## Screenshots

Numbered in upload order. Both sets are captured and sized correctly; upload
them as they are, no resizing.

| Set | Size | Device | Why |
| --- | --- | --- | --- |
| `6.9-inch/` | 1320 × 2868 | iPhone 16 Pro Max | The required iPhone slot. A set here covers the smaller iPhones automatically. |
| `13-inch/` | 2064 × 2752 | iPad Pro 13-inch (M4) | **Required**, because the app ships with iPad support — see below. |

Capture on those two simulators and the pixels come out exactly right. Anything
else is refused on upload: the iPhone 16 Pro, for instance, is 1206 × 2622,
which is not an accepted size.

The shots, in order:

1. **Home** — the day at a glance: the Today card, the listings, what needs a
   reply, what to continue
2. **Inbox** — the shared WhatsApp inbox, threads with real previews and unread
   counts
3. **A conversation** — one thread open, messages both ways
4. **Trip** — the departure with driver, guide, vehicle and lodges assigned
5. **Home, dark** *(iPhone only)* — the same screen in dark mode
6. **A conversation, dark** *(iPhone only)*

### The iPad set is not optional

`TARGETED_DEVICE_FAMILY` is `"1,2"` — Flutter's default, not a decision anyone
took — so the app is submitted as a universal build and App Store Connect will
demand iPad screenshots. It also means Apple reviews the iPad experience, which
is why `lib/core/responsive.dart` exists: on a 13-inch screen the phone layout
was being stretched to fill it, and that is a Guideline 4.0 rejection.

If iPad support is ever dropped, set the family to `"1"` and this whole set goes
away with it.

### Two things that will spoil the shoot

**The Today card is scoped to the calendar day.** All three of its tiles come
from SQL of the form `where created_at::date = current_date`, so on any day after
the data was seeded the card reads `0 / 0 / USD 0`. Either shoot on the day the
demo data was written, or re-date the demo rows to the capture day first.
Nothing else on the app behaves this way — "Needs you" and "Continue working"
are state-based and hold indefinitely.

**There is no tracking screenshot, deliberately.** `vehicleSnapshot` and
`vehicleHistory` both call the tracking provider live; no positions are stored in
Connect's own tables. Putting a vehicle on the demo map would mean registering a
fake device in the live Traccar server next to real customer trackers. The demo
vehicles therefore show "tracking not set up", which is true. The Description
still describes live tracking because the feature is real — it is just not one of
the four screens.

Everything shown must come from the demo workspace: reviewers read the messages,
and these images are public once the listing is live.
