# Requirements-to-Schema Traceability

This checklist verifies that the proposed product capabilities have an explicit storage, privacy, processing, and audit location.

| Product capability | Primary records | Supporting records | Completion check |
|---|---|---|---|
| Multilingual onboarding and voice-first preferences | `users`, `supportedLocales`, `preferences` | `devices` | Included |
| Multiple care-recipient profiles | `households/.../careRecipients` | `assignments`, `members` | Included |
| Caregiver native-language voice observations | `observations` | `mediaAssets`, `processingJobs`, `aiRuns` | Included |
| Structured bilingual summaries | `observations.translations`, `reports` | `terminologyGlossaries`, `promptTemplates` | Included |
| Original voice/text preserved | `observations.originalText`, `originalAudioAssetId` | `mediaAssets`, `aiRuns.inputHash` | Included |
| Family instruction translation | `instructions` | `instruction steps`, glossary, AI jobs | Included |
| Teach-back understanding verification | `instruction confirmations` | `threads/messages` for clarification | Included |
| Care routines and reminders | `tasks`, `taskEvents` | `scheduledWork`, notifications | Included |
| Medication reminders | `medications`, `medicationEvents` | `documents`, OCR AI runs, alerts | Included |
| No AI dosage inference | verification fields and disabled `aiDiagnosis` flag | model policy and audit | Included |
| Vital-sign and trend charts | `measurements`, `dailySummaries`, `weeklySummaries` | care-plan thresholds | Included |
| Care plan and approved escalation thresholds | `carePlans` | `safetyRuleSets` | Included |
| Caregiver/family clarification | `threads`, `messages` | entity links | Included |
| Daily/shift handover | `handovers` | tasks, observations, incidents | Included |
| Emergency phrasebook and one-tap call preparation | `emergencyPhrasebooks`, `emergencySessions` | government services, safety rules | Included |
| 110/119/113/1955/1966/1990 routing | `governmentServices` | service-routing rules, referrals | Included |
| Private worker-support path | `users/.../privateSupportRequests` | private messages, referrals, private media | Included |
| Private caregiver wellbeing check-ins | `wellbeingCheckIns` | support requests | Included |
| Family/clinician/NGO access by consent | `members`, `organizationLinks`, `accessGrants` | consents, audit events | Included |
| Generated clinic or family report | `reports` | access grants, documents | Included |
| File privacy and malware metadata | `mediaAssets`, `privateMediaAssets` | Storage signed URLs | Included |
| FCM notifications and persistent inbox | `devices`, `notificationOutbox`, `notifications`, `alerts` | scheduled work | Included |
| Offline retry and duplicate prevention | sync mixin, `idempotencyKeys` | processing jobs | Included |
| AI traceability and human review | `processingJobs`, `aiRuns` | prompt/glossary/rule versions | Included |
| Data access/export/correction/deletion | `consents`, `dataSubjectRequests` | soft-delete and retention fields | Included |
| Security audit trail | `auditEvents` | access grants and server request IDs | Included |
| Caregiver training/micro-learning | `trainingModules`, `lessons`, `trainingProgress` | knowledge articles | Included |
| One-agency/clinic/NGO pilot | `organizations`, `pilotStudies` | sites, participants, sessions, feedback, metrics | Included |
| Versioned schema evolution | `_schema`, `migrations` | collection manifest | Included |

## Deliberately not modeled as autonomous capability

- Medical diagnosis, prescription, or unrestricted symptom triage.
- Automatic medication-dose determination from a photograph.
- Confirmation that a government agency received a call or case without an official integration.
- Continuous caregiver location tracking or productivity scoring.
- Household access to confidential worker-support records without explicit consent.
