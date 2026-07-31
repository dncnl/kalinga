# Kalinga — Setup & End-to-End Testing

For groupmates picking this branch up. `README.md` covers repo layout and the
git/secrets rules; **this** doc covers the part that actually blocks people:
getting Google Cloud auth working, and then walking the whole app to check
nothing is broken.

Budget ~30 minutes the first time, most of it waiting on installs.

---

## Part 0 — What still needs a human

Read this before you trust anything. The branch was developed with
`FIREBASE_STORAGE_BUCKET` **unset**, so the two Storage-dependent features
were built and unit-tested but **never run against real infrastructure**.
That variable is now documented in §1.6; once it's set, these should work —
but "should" is not "does", and nobody has confirmed it yet.

**Priority 1 — never exercised end to end, needs someone to actually try:**

| What | Why it wasn't verified | Where to check it |
|---|---|---|
| **F4 voice log** — record → transcribe → translate → trend chart | Needs Cloud Storage; bucket was unset | Part 3, Step 3 |
| **F7 medication label scan** — photo → OCR draft → confirm → schedule | Same; also needs a real medicine box to photograph | Part 3, Step 6 |
| **F0 multi-recipient scoping** — 2+ elders, switching between them | Only one recipient was ever created during development | Part 3, Step 2 |
| **Family account linked to 2+ recipients** → picker screen | Only the single-recipient path was tested | Part 3, Step 9b |

The first two are backend-integration risk (does the pipeline actually run?).
The second two are correctness risk, and F0 is the more serious of the pair:
every feature scopes to a `careRecipientId`, so if switching elders leaks data
between profiles, that's a **stop-and-fix**, not a polish item.

**Priority 2 — known, low severity, not yet fixed:**

- `apps/mobile/lib/pages/meds_page.dart` (~line 164) still filters times with
  `^\d{2}:\d{2}$`, which accepts nonsense like `25:99`. The equivalent
  server-side checks were tightened to a real clock-time pattern; this client
  one wasn't. The server is authoritative for reminder generation, so the
  blast radius is small, but it's the same bug class.
- `activity_page.dart` still renders **four hardcoded fixture entries**
  ("Family replied…", "Alert sent…"). It's reachable from the 🔔 icon and
  presents invented medical events as this elder's real history. Every other
  screen is on live data. Either wire it to the observations feed or hide the
  bell before showing this to anyone outside the team.

**Known-incomplete by design** (fine for the pilot, don't file bugs):

- Settings toggles and both language dropdowns are inert local state. The
  transcription locale is still hardcoded (`demoLocale = 'fil'` in
  `api_config.dart`), so changing "Your language" changes nothing yet.
- Reminder times are generated in **UTC**, so they fire at the wrong local
  time outside UTC.
- No push notifications — reminders only surface while the app is open.
- Insights look at the current week only.

---

## Part 1 — One-time setup

### 1.1 What needs to be true before anything works

The API is not self-contained. It talks to five Google services, all on the
**same GCP/Firebase project (`kalinga-bc97f`)**:

| Service | Used by |
|---|---|
| Firestore | everything |
| Cloud Storage | voice-log audio, medication label photos |
| Cloud Speech-to-Text | voice log → transcript |
| Cloud Translation | caregiver's language → Mandarin |
| Vertex AI (Gemini) | RAG answers, observation extraction, label OCR |

If any of these isn't enabled or you aren't authenticated, the app still
launches and the UI still renders — you just get 502s or empty results on the
features that need them. That failure mode is confusing, so do this part
properly first.

### 1.2 Get access

Ask a project owner to add your Google account to Firebase project
`kalinga-bc97f` (Firebase Console → Project Settings → Users and permissions).
You need at least **Editor**, because you'll be calling Vertex AI, Speech and
Translate.

### 1.3 You do not need any API keys for Google

Worth stating plainly, because people go hunting for keys that don't exist:

**All five Google services above authenticate with the same identity.** Under
ADC that's your `gcloud` login; when deployed it's the service account. There
is **no** Speech key, **no** Translate key, **no** Vertex AI key, **no**
Firestore key. `googleAuthOptions()` in `src/firebase.js` hands that one
identity to every `@google-cloud/*` client.

Two things that look like keys but aren't:

- **`OPENROUTER_API_KEY`** is the only real API key in the project, and it's
  **optional** — it's the non-Google fallback LLM provider, used only if you
  set `LLM_PROVIDER=openrouter`. Leave it empty and everything still works on
  Vertex AI.
- **The `apiKey` in `firebase_options.dart` / `google-services.json`** is
  Firebase *client* config. It is committed on purpose and is not a secret —
  it ships inside every built app binary anyway, and Firebase's security model
  rests on Firestore/Storage rules, not on hiding it. You don't set it up and
  you don't rotate it. See README §4.

So: do §1.4 below, and you're authenticated for everything.

### 1.4 Authenticate — pick ONE of these

There are two supported ways to authenticate the API. Don't do both.

**Option A — Application Default Credentials (recommended for local dev).**
Nothing secret ever touches the repo. This is what the branch was developed
and tested with.

```bash
gcloud auth login
gcloud config set project kalinga-bc97f
gcloud auth application-default login
```

That last command opens a browser and writes a credential file to your user
profile. `firebase.js` falls back to it automatically when
`FIREBASE_SERVICE_ACCOUNT` is unset.

**Option B — service account key JSON.** Only if ADC won't work for you.
Firebase Console → Project Settings → Service Accounts → Generate new private
key, then paste the **entire JSON on one line** into `FIREBASE_SERVICE_ACCOUNT`
in `.env`. Never commit it. See README §4 — this key is full backend access.

### 1.5 Enable the APIs

Once, per project. Someone has probably already done this, but it's harmless
to re-run:

```bash
gcloud services enable \
  speech.googleapis.com \
  translate.googleapis.com \
  aiplatform.googleapis.com \
  firestore.googleapis.com \
  storage.googleapis.com
```

### 1.6 API env file

```bash
cd apps/api
cp .env.example .env
```

Then edit `.env`. A working ADC-based setup looks like this:

```ini
PORT=8081

# Leave BOTH of these empty when using ADC (Option A above).
FIREBASE_SERVICE_ACCOUNT=
FIREBASE_STORAGE_BUCKET=kalinga-bc97f.firebasestorage.app

# Required when FIREBASE_SERVICE_ACCOUNT is empty — firebase.js reads the
# project id from here, and Vertex AI needs it.
GOOGLE_CLOUD_PROJECT=kalinga-bc97f

VERTEX_AI_LOCATION=us-central1

# Only needed if you set LLM_PROVIDER=openrouter as a fallback.
OPENROUTER_API_KEY=
```

Two things people get wrong here:

- **`GOOGLE_CLOUD_PROJECT` is not optional under ADC.** `firebase.js` derives
  `projectId` from the service-account JSON *or* this variable. With both
  empty, Vertex AI calls fail with a confusing project error.
- **`FIREBASE_STORAGE_BUCKET` must be set** for the voice log (F4) and the
  medication label scan (F7). These are the only two features that touch
  Cloud Storage. With it empty, `getBucket()` throws and both return 502 —
  while every other screen keeps working normally, which is exactly why it's
  easy to miss. This bit us during development: the branch was built with it
  unset, so F4 and F7 were never exercised on a device (see
  [§What still needs a human](#part-0--what-still-needs-a-human)).

  The value above is correct for this project and is not a secret — it's
  already in the committed `google-services.json` and `firebase_options.dart`.

**Verify your credentials can actually reach the bucket** before blaming the
app. This is worth doing once; it isolates auth problems from app problems:

```bash
cd apps/api
node -e "require('dotenv').config({quiet:true}); const fb=require('./src/firebase'); (async()=>{ try { const b=fb.getBucket(); console.log('bucket:', b.name); const [e]=await b.exists(); console.log('reachable:', e); } catch(err){ console.log('FAILED:', err.message); } })()"
```

Expect `reachable: true`. If it prints `FAILED`, your ADC login or project
access is the problem, not the code.

### 1.7 Install and seed

```bash
# API
cd apps/api
npm install
node src/rag/ingest.js     # one-time: embeds the reference docs into ragChunks
npm run dev                # http://localhost:8081

# Mobile (second terminal)
cd apps/mobile
flutter pub get
```

`ingest.js` is what makes "Ask" and the F1 "while you wait" guidance return
real cited answers. Skip it and those come back empty. Re-run it only when
`src/rag/sources/` changes — chunk ids are deterministic, so it overwrites
rather than duplicates.

Confirm the API is alive before touching the app:

```bash
curl http://localhost:8081/health     # {"status":"ok"}
```

### 1.8 Emulator networking

`apps/mobile/lib/api_config.dart` already handles this:

- Android emulator → `http://10.0.2.2:8081` (the emulator's alias for your
  machine; `localhost` inside the emulator means the emulator itself)
- Windows/web/iOS simulator → `http://localhost:8081`
- **Physical Android phone** → neither works. Use your machine's LAN IP:
  ```bash
  flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8081
  ```
  and make sure your firewall allows inbound 8081.

### 1.9 Run it

```bash
cd apps/mobile
flutter devices                       # confirm your emulator is listed
flutter run -d emulator-5554          # use the id from `flutter devices`
```

---

## Part 2 — Automated tests

Run these before the manual walkthrough. They're fast and catch most
regressions.

```bash
cd apps/api    && node --test      # 167 tests
cd apps/mobile && flutter test     # 13 tests
cd apps/mobile && flutter analyze  # should report no errors
```

The API tests mock Firestore and the LLM client, so they need **no** GCP
credentials — they'll pass on a machine that hasn't done Part 1 at all. If
these fail, don't bother with the manual pass; something is genuinely broken.

Worth knowing what a few of them protect, since they're the ones you must not
"fix" by loosening:

- `test/symptomTriage.test.js` — asserts every red-flag answer escalates to
  emergency, and that non-boolean answers (`"true"`, `1`, `"yes"`) can't trip
  one. This is the code that decides whether to tell someone to call 119.
- `test/reminderCheckin.test.js` — asserts answering about lunch never
  fabricates a sleep or mood score.
- `test/insights_test.dart` — asserts insight text never contains diagnostic
  language, and that silent days aren't read as "average".

---

## Part 3 — End-to-end walkthrough

This is the full demo path. Do it on a **freshly wiped app** so you're
exercising first-run behaviour:

```bash
adb shell pm clear com.kalinga.mobile
```

(`adb` lives at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` on Windows
if it isn't on your PATH.)

Use throwaway emails — anything unique works, these are real Firebase Auth
accounts on the shared project.

### Step 1 — Caregiver sign-up

1. Launch → **Sign up** → **I'm the caregiver**
2. Name / email / password (6+ chars) → **Create account**
3. Language screen → **Continue**
4. Add a care recipient: name + age → save

**Expect:** you land on Home, header shows the recipient's name, greeting says
"Haven't logged … yet today."

**Check the household bootstrapped exactly once** — it should not re-create on
every launch:

```bash
adb shell "run-as com.kalinga.mobile cat /data/data/com.kalinga.mobile/shared_prefs/FlutterSharedPreferences.xml"
```

You should see one `kalinga.householdId`, one `kalinga.careRecipientId`, and
`kalinga.role=caregiver`. Force-stop and relaunch — the ids must not change.

### Step 2 — Add a second recipient, confirm scoping

Tap the header → **Add another profile** → create a second one → switch
between them. Every screen (Home, Log, Meds, Reminders, profile) must follow
the selected recipient. This is F0, and it's the invariant everything else
depends on — if a screen shows the wrong elder's data, stop and report it.

### Step 3 — Voice log (F4) 🚩 UNVERIFIED

> **This step has never been run end to end.** Treat a failure here as
> expected-unknown rather than a regression, and report what you see.

Home → **Start daily log** → hold the mic → speak a few seconds → release.

**Expect:** "Logged — processing…". The trend chart fills in a few seconds
later once transcription, translation and extraction finish server-side.

**Work through it in this order if it fails** — the pipeline has four stages
and they fail differently:

1. **Upload** — API terminal shows the `upload-url` and `process` calls
   returning 200. If not, it's `FIREBASE_STORAGE_BUCKET` (§1.6).
2. **Transcription** — `processObservationJob` logs failures. "No speech
   detected in recording" means the audio uploaded fine but was silent; the
   emulator records **host** audio, so check your OS mic isn't muted.
   A Speech API error means `speech.googleapis.com` isn't enabled.
3. **Translation** — a Translate error here still leaves the observation
   saved; it just won't have Mandarin.
4. **Rollup** — the chart is driven by a Firestore listener on
   `weeklySummaries`, so it can lag a second or two behind. Pull to refresh.

The observation doc's `status` field tracks all of this (`processing` →
`ready`, or `cancelled` + `processingError`), so check Firestore directly if
the terminal isn't conclusive.

### Step 4 — Symptom check-in (F1)

Home → **Something is wrong** → **She fell down** → **Yes** to "Did she hit
her head?" → No, No → optionally type a note → **See what to do**.

**Expect:**
- A red **"Call 119 now"** banner — hitting the head is a red flag, and this
  is decided by a fixed rule table server-side, not by a model
- A **Call 119** button (opens the dialler pre-filled; it does *not* auto-dial)
- **"The family sees this"** showing a Mandarin summary that reads as
  statements, e.g. 「她跌倒了，頭部受傷。請立即撥打119。」 — no question marks
- **"While you wait"** guidance appearing a moment later, with a source line

**Then check the opposite direction:** run it again choosing **Not eating or
drinking** and answering **No** to everything. You should get the calm teal
"Keep watching her" — not an alarm. A triage screen that shouts at every input
is useless.

### Step 5 — Reminders + check-in (F2 + F3)

1. Home → **Schedules** (quick action) → **Add a reminder**
2. Label **Eating**, set a time **earlier than now**, save
3. Back to Home — a **"Today's reminders"** section appears with the reminder
   outlined in teal and "How did it go?"
4. Tap it → answer "About half" and "No" → **Save**

**Expect:** you return to Home and the reminder is now ticked and struck
through **immediately** (no restart needed). The answers are written as an
observation, so they feed the same trend chart as the voice log.

Then add an **Exercise** reminder and confirm it asks a *different* question
set, and a **Medication** one and confirm it just completes with no questions.

### Step 6 — Medication label scan (F7) 🚩 UNVERIFIED

> **Never run against a real photo.** The extraction logic has unit tests
> (`test/extractMedicationLabel.test.js`) but the Vertex vision call has not
> been exercised. Needs Storage **and** Vertex AI configured.

Meds → add via photo → photograph any medicine box or pharmacy label. A label
displayed on another screen photographs fine; so does picking an existing
image from the emulator's gallery.

**Expect — the review sheet is the whole point of this feature.** After the
scan a sheet appears reading *"Kalinga read this from the photo — check it's
correct. Nothing is scheduled until you confirm."* with every field editable.
Three things to check:

1. **Nothing is scheduled until you hit Confirm.** Dismiss the sheet without
   confirming, then go to Home — the medicine must **not** appear in today's
   schedule. Under the hood the draft is saved with
   `verificationStatus: 'unverified'`, and `generate-today` explicitly skips
   unverified medications. This is the human-in-the-loop step the schema
   requires; if an unconfirmed scan ever schedules a dose, that's a serious
   bug.
2. **Unreadable fields come back blank, not guessed.** Photograph a label with
   something deliberately missing — e.g. one with no dosing frequency printed.
   The times field should be empty and dosage blank, rather than a plausible
   invention. The prompt forbids inferring from pill appearance, and a test
   asserts that instruction survives.
3. **A blurry or angled photo should come back low-confidence**, which is what
   tells the caregiver to look carefully.

Then edit a field in the sheet, **Confirm**, and check the medicine now
appears on Home with your edit — confirming is also how corrections are made.

### Step 7 — Profile: must-remember + insights (F5)

Header → the ⓘ on the recipient → scroll down.

- **MUST REMEMBER** → **Add** → category **Allergy**, text "Allergic to
  peanuts" → Save. It should persist and render with an amber warning border.
- **WHAT WE ARE NOTICING** → with only a day or two of logs this must say
  *"Not enough logs yet to see a pattern."* — **not** "everything looks fine".
  Claiming reassurance we can't support is a bug, not a nicety.

### Step 8 — Emergency + phrasebook (F6)

Bottom nav → **Help**.

- Four numbers: 119, 110, 1955, 0800 024 111. Tap **1955** — the dialler
  should open pre-filled. Don't press call.
- Scroll: Mandarin phrasebook with Han script + pronunciation, then
  **"Talking to the elder"** with the Hokkien set (romanization only, by
  design — see README §9).

### Step 9 — Family invite → viewer

1. Profile page → **Invite family or caregiver** → **Create invite code**
2. **Write the 8-character code down** (e.g. `GT5Z7DM5`). It's shown once and
   only its hash is stored server-side, so you can't recover it later.
3. Settings (gear) → scroll → **Sign out**
4. **Sign up** → **I'm a family member** → type the code → **Continue** →
   name, their own email, password → **Start reading**

(There are two family entry points and they're easy to mix up: **Sign up →
I'm a family member** is code-first, for someone who has never used the app.
**Log in → I'm a family member** is for an existing family account and skips
the code entirely. Test the sign-up path here; the login path is Step 9b.)

**Expect:** you land on the viewer for **that specific recipient**, in
Mandarin, read-only, with a **登出 · Sign out** button (not "Back to caregiver
app" — that's the caregiver's preview label).

**Then test session restore:** force-stop and relaunch. You should see
"Opening your family view…" and land back on the viewer — *not* on a caregiver
home screen, and *not* creating a household for the family account.

### Step 9b — Family login (the other entry point)

Sign out of the family account, then **Log in** → **I'm a family member** →
that same email and password. No code this time.

**Expect:** straight to the viewer for their recipient. If a family account is
ever linked to more than one recipient it should show a picker instead; with
one recipient it must not.

Also confirm the prefs show `kalinga.role=family` and **no** `householdId` —
a family account creating a household is the specific bug this guards against:

```bash
adb shell "run-as com.kalinga.mobile cat /data/data/com.kalinga.mobile/shared_prefs/FlutterSharedPreferences.xml"
```

### Step 10 — Failure states

Sign out, then deliberately break things:

| Do this | Expect |
|---|---|
| Log in with a wrong password | "Wrong email or password. Check both and try again." — not a Firebase stack trace |
| Enter invite code `WRONGCOD` | Bilingual "that code isn't valid or has expired" |
| `adb shell svc wifi disable; adb shell svc data disable` then log in | "No connection. Check your internet and try again." |
| Re-enable network, log in as a *different* caregiver | None of the previous account's recipients or reminders visible |

Every one of these must be a calm inline message. A raw exception, a silent
no-op, or an alarming red wall is a bug — these users are often reading in a
second or third language under stress.

---

## Part 4 — Gotchas we hit

Real things that cost time during development, so you don't rediscover them:

- **The emulator's system process can crash** (`DeadSystemException` in the
  log). It's Android dying, not the app. It usually self-recovers; relaunch
  the app with `adb shell monkey -p com.kalinga.mobile 1`.
- **`flutter run` after `pm clear` loses your session** — that's correct
  behaviour, not a bug. You'll need to log in again.
- **Pressing the back/ESC key inside a bottom sheet closes the whole sheet**,
  not just the keyboard. To dismiss the keyboard use the ⌄ chevron at the
  bottom-left of the IME.
- **Reminder times are interpreted in UTC** by `generate-today` (same as the
  existing medication events). On a machine well off UTC a reminder set for
  "08:00" may not appear as due when you expect. Known limitation, not a
  regression — flagged for whoever does timezone support.
- **The first `flutter run` after a clean checkout is slow** (Gradle may
  download the NDK, ~2–5 min). It isn't hung.
- **`flutter analyze` reports a handful of `info`/`warning` lints** that
  pre-date this branch. Zero **errors** is the bar.

---

## Part 5 — Reporting a problem

Include:

1. Which step above, and what you expected vs. saw
2. A screenshot (`adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png`)
3. **The API terminal output** — most backend failures print there and
   nowhere else
4. Whether `curl http://localhost:8081/health` still returns ok
5. Whether `node --test` in `apps/api` passes

Point 3 is the one people skip and it's usually where the answer is.
