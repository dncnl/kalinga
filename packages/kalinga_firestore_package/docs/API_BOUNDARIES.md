# Suggested Node.js API Write Boundaries

The database package does not implement the Express API, but these endpoint boundaries match the security model and collection paths.

| Endpoint group | Typical operations | Primary collections |
|---|---|---|
| `/v1/users/me` | profile, preferences, devices, consent | `users`, `preferences`, `devices`, `consents` |
| `/v1/households` | create, invite, accept, member management | `households`, `members`, `invitations` |
| `/v1/care-recipients` | profile, assignment, care plan | `careRecipients`, `assignments`, `carePlans` |
| `/v1/observations` | create local draft, upload voice, process, confirm, share | `observations`, `mediaAssets`, `processingJobs`, `aiRuns` |
| `/v1/instructions` | create, translate, extract steps, teach-back, clarify | `instructions`, `steps`, `confirmations`, `threads` |
| `/v1/tasks` | recurring tasks and event completion | `tasks`, `taskEvents`, `scheduledWork` |
| `/v1/medications` | verified medication entry, OCR draft, reminders | `medications`, `medicationEvents`, `documents`, `aiRuns` |
| `/v1/measurements` | record/import measurement and evaluate care-plan threshold | `measurements`, `carePlans`, `alerts` |
| `/v1/incidents` | record non-routine event and link emergency session | `incidents`, `emergencySessions` |
| `/v1/handovers` | create and acknowledge handover | `handovers`, related care records |
| `/v1/reports` | generate, export, grant access, expire share token | `reports`, `accessGrants`, `mediaAssets` |
| `/v1/help` | list verified services, prepare phrase, record user-initiated connection | `governmentServices`, `emergencySessions`, `serviceReferrals` |
| `/v1/private-support` | confidential case, message, referral | private support subcollections |
| `/v1/training` | module progress and quiz results | training collections |
| `/v1/data-rights` | access/export/correct/delete/restrict | `dataSubjectRequests`, audit |

All mutation endpoints should accept `Idempotency-Key` and `If-Match`/document version where applicable.
