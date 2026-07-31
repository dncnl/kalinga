# F1: free-text chat symptom checker

Branch: `feature/f1-chat-symptom-checker`, cut from `main`.

## Why

Main already has F1 as a tap-based, deterministic triage
(`symptom_check_page.dart` / `symptomTriage.js`) — that stays as the
authoritative urgency path, unchanged. But the original spec calls for a
**chat-based** symptom checker, and main's generic `/rag/ask` chat isn't
care-recipient-scoped and doesn't translate/flag anything to family in
Mandarin. This branch adds that free-text chat entry point alongside the
tap-based flow, not instead of it.

## Design

- New route `POST /households/:hid/care-recipients/:crid/rag/ask`
  (`apps/api/src/routes/rag.js`), sibling to the existing unscoped
  `/rag/ask`. Reuses `answerQuestion()` (Firestore vector search RAG,
  already multilingual) unchanged.
- Records the exchange as an observation (`inputMode: 'text'`, reusing
  `buildObservationDocument`) so it shows up for the family/trends like a
  voice log, with a Mandarin translation via `translateToMandarin`.
- `apps/api/src/lib/chatConcern.js` — a **deterministic keyword match**
  (mirrors `symptomTriage.js`'s six categories, multilingual phrase list),
  not an LLM call. It never asserts urgency; it only optionally nudges the
  caregiver toward the tap-based `/symptom-check` flow. Urgency stays
  exclusively `symptomTriage.js`'s job.
- Mobile: `RagService.askForRecipient()` calls the scoped endpoint when a
  care recipient is selected; `ask_page.dart` shows the Mandarin summary
  and, when present, a tappable concern banner routing to `/symptom-check`.

## Status

- [x] Backend route + `chatConcern.js` + tests (`rag-chat.test.js`, 8 tests)
- [x] Mobile `RagService.askForRecipient()` + `ask_page.dart` wiring
- [x] Full backend suite green (175/175), full mobile suite green (13/13),
      `flutter analyze` clean
- [ ] Manual device/emulator pass on `/ask` (scoped call, Mandarin summary,
      concern banner → `/symptom-check`)
- [ ] PR review, merge to `main`
