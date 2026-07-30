# Kalinga API

Node.js / Express REST API for the Kalinga care-coordination platform.
Uses Firebase Admin SDK to write to Cloud Firestore and verify Firebase Auth tokens.

---

## Prerequisites

- Node.js >= 20
- npm >= 9
- Firebase CLI (`npm install -g firebase-tools`)
- Access to the `kalinga-bc97f` Firebase project (ask your team lead)

---

## Quick Start

### 1 — Install dependencies

```bash
cd apps/api
npm install
```

### 2 — Create your local .env

```bash
cp .env.example .env
```

Open `.env` and choose your mode (see sections below).

---

## Running Locally (Emulator Mode — recommended for development)

### Step A — Start the Firebase Emulator Suite

```bash
cd packages/kalinga_firestore_package
npm run emulators
```

Wait until you see all emulators ready (Auth on :9099, Firestore on :8080).

### Step B — Configure .env for emulator

In `apps/api/.env`, uncomment the emulator lines and leave
`GOOGLE_APPLICATION_CREDENTIALS` commented out:

```env
PORT=3000
FIREBASE_PROJECT_ID=kalinga-bc97f
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
```

### Step C — Start the API

```bash
cd apps/api
npm run dev
```

You should see:
```
[firebase] auth emulator  : 127.0.0.1:9099
[firebase] firestore emul : 127.0.0.1:8080
[firebase] running mode   : EMULATOR
API running on port 3000
```

---

## Running Against Live Firebase (Production Mode)

> ⚠️  Only do this when you are ready to write real data to `kalinga-bc97f`.
> Demo data must NEVER be sent to the production project.

### Step A — Download a service account key

1. Open [Firebase Console](https://console.firebase.google.com/) → select `kalinga-bc97f`
2. Project Settings → Service Accounts tab
3. Click **Generate new private key** → confirm → download the JSON file
4. Rename it to `serviceAccountKey.json`
5. Place it at `apps/api/serviceAccountKey.json`

> The file is already blocked by `.gitignore`. Never commit it.

### Step B — Configure .env for production

In `apps/api/.env`, comment out the emulator vars and uncomment the credentials line:

```env
PORT=3000
FIREBASE_PROJECT_ID=kalinga-bc97f
GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
```

### Step C — Start the API

```bash
cd apps/api
npm run dev
```

You should see:
```
[firebase] auth emulator  : NOT SET
[firebase] firestore emul : NOT SET
[firebase] running mode   : PRODUCTION
API running on port 3000
```

---

## Available Scripts

| Command | Description |
|---|---|
| `npm run dev` | Start with nodemon (auto-restarts on file changes) |
| `npm start` | Start without nodemon (for production containers) |

---

## API Endpoints

### POST /auth/register

Registers a new user and creates their household in Firestore.

**Headers**
```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

**Body**
```json
{
  "displayName": "Jane Doe",
  "householdName": "Doe Household"
}
```

**Success 201**
```json
{
  "uid": "abc123",
  "householdId": "xyz789"
}
```

**Error responses**
| Status | Meaning |
|---|---|
| 400 | Validation failed (missing/invalid body fields) |
| 401 | Missing or invalid Firebase ID token |
| 409 | User already registered |
| 500 | Internal server error |

---

## Security Notes

- `uid` and `email` are always taken from the verified Firebase token — never from the request body.
- `householdId` is generated server-side.
- All timestamps use `FieldValue.serverTimestamp()`.
- The registering user is always assigned `role: householdAdmin`.
- Batch writes are atomic — partial Firestore writes cannot occur.
