# SpendWise — Daily Expense Tracker

Flutter expense tracker with offline SQLite storage, optional Firebase Auth + Firestore sync, budgets, recurring expenses, CSV export, and a companion Node backend.

## Features

- Expense CRUD with delete confirmation + Undo
- Default + custom categories
- Monthly summary (donut + daily bar charts)
- Search / filter / sort
- Currency + light/dark/system theme
- **Monthly budget** with overspend alert
- **Recurring expenses** (daily / weekly / monthly)
- **CSV export** (share sheet)
- **Firebase Auth + Firestore sync** (after you configure Firebase)
- Optional **REST backend** (`../spendwise-backend`)
- **AI Quick add** (natural language → confirm table for one or many → save; Groq via backend)
- **Auto category suggestion** (keyword rules + optional LLM)
- **Ask expenses** chat agent (tool calling; SQLite tools run on device)
- **Monthly AI insights** + **budget advice** (aggregates only)

## Privacy (AI)

- AI is **off by default**. Settings → **Allow AI features** asks for consent before any text is sent.
- Quick add / category suggest: only the short text you type (+ category names) goes to the server.
- Ask agent: the model requests tools; **totals and expense rows are read from on-device SQLite** and returned as tool results. Raw history is not uploaded as a dump.
- Monthly insights / budget advice: **aggregated numbers only** (totals by category), not individual notes.
- The Groq API key lives on the **server** (`GROQ_API_KEY`), never in the Flutter app.
- You confirm every parsed expense before it is written to SQLite.
- Server enforces a **daily request limit** (`AI_DAILY_LIMIT`).

## Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter + Dart |
| State | Provider |
| Local DB | sqflite |
| Cloud | Firebase Auth + Cloud Firestore |
| Charts | fl_chart |
| Export | csv + share_plus |
| Backend | Node.js + Express + Firebase Admin |

## Run the app

```bash
cd spendwise-flutter
flutter pub get
flutter run
```

Firebase is optional. Until you configure it, the app stays offline-only.  
See [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md) — **you create the Firebase project / Auth**.

## Run the backend

```bash
cd ../spendwise-backend
cp .env.example .env
# add serviceAccountKey.json from Firebase
npm install
npm run dev
```

Default backend URL is the Render deploy:
`https://spendwise-backend-ck66.onrender.com`

Override in Settings → Backend API URL (local emulator: `http://10.0.2.2:3000`).

## Tests

```bash
flutter test
```

## Project structure

```
lib/
  models/ providers/ screens/ widgets/ data/ services/ theme/ utils/
docs/
  FIREBASE_SETUP.md
  requirements docx
```
