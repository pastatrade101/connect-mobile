# App Store listing — what to paste, and where

Work top to bottom with App Store Connect open beside this. Every value is final:
copy it as-is. Nothing here can be automated — the console needs an interactive
sign-in.

**Start at** [appstoreconnect.apple.com](https://appstoreconnect.apple.com) →
**My Apps** → **Makutano Connect**. Everything below is on one of four pages in
the left sidebar.

| # | Page | What goes there | Time |
| --- | --- | --- | --- |
| 1 | General → **App Information** | Name, subtitle, category, age rating | 3 min |
| 2 | General → **Pricing and Availability** | Free, all countries | 1 min |
| 3 | General → **App Privacy** | The data questionnaire + privacy policy URL | 10 min |
| 4 | iOS App → **1.1.2 Prepare for Submission** | Everything else | 15 min |

Do **App Privacy** early even though it looks optional — Apple blocks submission
until it is answered, and it is the longest form.

**Have ready:** the demo account password, from your password manager. It is the
only thing not written down here, and it goes in on page 4.

---

## 1. App Information

*Sidebar → General → App Information*

| Field | Paste this | Where on the page |
| --- | --- | --- |
| Name | `Makutano Connect` | Localizable Information |
| Subtitle | `Run your safari business` | Localizable Information |
| Primary category | **Business** | General Information |
| Secondary category | **Travel** | General Information |

**Content Rights** → Edit → *Does not contain, show, or access third-party
content*.

**Age Rating** → Edit → answer **None** to every question about violence, sexual
content, profanity, horror, gambling, contests and drugs; **No** to unrestricted
web access; **No** to user-generated content shown publicly. Chats are private
between an operator and their own customer, so that last one is genuinely No.
The result should read **4+**.

---

## 2. Pricing and Availability

*Sidebar → General → Pricing and Availability*

- **Price:** Free
- **Availability:** all countries and regions

The customers are Tanzanian, but their staff travel and testers may be anywhere.

---

## 3. App Privacy

*Sidebar → General → App Privacy*

**Privacy Policy URL** — this field is on this page, not the version page:

```
https://connect.makutano.co.tz/legal/privacy
```

Then **Data Collection** → Edit → **Yes, we collect data**, and tick exactly
these three:

| Tick this | Then answer |
| --- | --- |
| **Contact Info** — name, email, phone | Linked to user: **Yes** · Tracking: **No** · Purpose: **App Functionality** |
| **User Content** — messages, photos in chats | Linked to user: **Yes** · Tracking: **No** · Purpose: **App Functionality** |
| **Identifiers** — user ID, push token | Linked to user: **Yes** · Tracking: **No** · Purpose: **App Functionality** |

**Leave everything else unticked**, including these, which are easy to get wrong:

| Do not tick | Because |
| --- | --- |
| **Location** | The app shows *vehicle* positions sent from our server. It has no location package, no `NSLocation*UsageDescription`, and never reads the device's location. |
| Diagnostics / Analytics | Firebase is present for push messaging only. No analytics SDK is linked. |
| Contacts, Purchases, Financial Info, Browsing History | Not collected. |

**Tracking (ATT):** No. Nothing is linked to third-party data for advertising,
and there is no `NSUserTrackingUsageDescription` in the app.

---

## 4. Version page — "1.1.2 Prepare for Submission"

*Sidebar → iOS App → 1.1.2 Prepare for Submission*

Everything below is on this single page, in the order you meet it scrolling down.

### Screenshots

Top of the page, under **App Previews and Screenshots**. There is a device
selector — upload each set to its own tab:

| Tab | Folder | Files |
| --- | --- | --- |
| **iPhone 6.9"** | `screenshots/6.9-inch/` | 6 |
| **iPad 13"** | `screenshots/13-inch/` | 4 |

Upload them as they are. They are already the exact pixel sizes Apple requires,
and they are numbered in the order they should appear.

### Promotional Text

Editable later without a new build.

```
Answer WhatsApp enquiries, send quotes and follow every vehicle on one map —
from the seat of the car, not the office.
```

### Description

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

### Keywords

Comma-separated, no spaces after the commas.

```
safari,tour operator,tanzania,fleet,tracking,whatsapp,quotation,booking,trip,travel,itinerary,arusha
```

### General Information

| Field | Value |
| --- | --- |
| Support URL | `https://connect.makutano.co.tz/legal/terms` |
| Marketing URL | `https://connect.makutano.co.tz` |
| Copyright | `2026 Makutano` |
| Version | **1.1.2** — change it; the record still says 1.0 and it must match the build |

### Build

Click **+** next to Build and pick **1.1.2 (7)**.

It only appears once Apple finishes processing the upload — usually 10 to 30
minutes. If the **+** is not there yet, the build is still processing.

### App Review Information

Bottom of the page. Tick **Sign-in required**, then:

| Field | Value |
| --- | --- |
| User name | `demo@makutano.co.tz` |
| Password | *from your password manager* |

**Notes** — paste this in:

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

Then **Save**, and **Add for Review** when you are ready.

---

## Things you do NOT have to do

- **Export compliance.** `ITSAppUsesNonExemptEncryption` is `false` in
  `Info.plist`, so App Store Connect never asks. If you go looking for the
  prompt, you will not find one — that is correct.
- **Resize any screenshot.** Both sets are already exact.
- **Sign in as the demo account to check it.** It is seeded and verified.

---

## The demo workspace

Sign-in: `demo@makutano.co.tz` · workspace **Serengeti Trails Safaris**.

It holds 5 customers and enquiries, 5 WhatsApp threads with 22 messages, 4 tours
with photos, 2 quotations (one accepted), 1 confirmed booking with a deposit
paid, 1 trip with driver, guide and vehicle assigned, plus 4 crew and 3
vehicles. Every name, number and email is invented.

**Do not delete or suspend it after a release.** Apple re-reviews against these
same credentials on every resubmission and for support enquiries months later.
Its trial is held to **2027-12-31** for that reason — if the trial lapses, the
reviewer's login becomes a paywall and the build is rejected for a broken demo
account.

It also lives in the **production** database alongside real tenants, so anything
seeded into it must stay scoped to its own tenant id.

---

## Notes for whoever maintains this

Everything above is what to do. This is why.

**The iPad set is not optional.** `TARGETED_DEVICE_FAMILY` is `"1,2"` — Flutter's
default, not a decision anyone took — so the app is submitted as universal, App
Store Connect demands iPad screenshots, and Apple reviews the iPad experience.
That is why `lib/core/responsive.dart` exists: on a 13-inch screen the phone
layout was being stretched to fill it, which is a Guideline 4.0 rejection. Drop
iPad support by setting the family to `"1"` and this whole set goes away.

**Re-shooting screenshots.** Capture on an **iPhone 16 Pro Max** simulator
(1320 × 2868) and an **iPad Pro 13-inch (M4)** simulator (2064 × 2752) and the
pixels come out right with no resizing. Other devices are refused on upload — the
iPhone 16 Pro, for instance, is 1206 × 2622, which is not an accepted size.
`xcrun simctl io <udid> screenshot <file>` writes the native resolution.

**The Today card is scoped to the calendar day.** All three of its tiles come from
SQL of the form `where created_at::date = current_date`, so on any day after the
demo data was seeded it reads `0 / 0 / USD 0`. Re-shooting means re-dating the
demo rows to the capture day first. Nothing else behaves this way — "Needs you"
and "Continue working" are state-based and hold indefinitely.

**There is no tracking screenshot, on purpose.** `vehicleSnapshot` and
`vehicleHistory` both call the tracking provider live; no positions are stored in
Connect's own tables. Putting a vehicle on the demo map would mean registering a
fake device in the live Traccar server next to real customer trackers. The demo
vehicles show "tracking not set up", which is true. The Description still
describes live tracking because the feature is real — it is simply not one of the
shots.

**Screenshots are public once the listing is live**, and reviewers read the
messages in them. Everything shown must come from the demo workspace.
