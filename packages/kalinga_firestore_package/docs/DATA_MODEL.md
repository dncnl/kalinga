# Kalinga Cloud Firestore Data Model
**Schema version:** 1.1.0  
**Database:** Cloud Firestore Native mode  
**Write model:** sensitive domain writes pass through the authenticated Node.js/Express API; Flutter clients use read-only Firestore access where permitted.
Firestore is schemaless, so this package expresses the contract through `schema/kalinga-firestore-schema.json`, server validation, Security Rules, indexes, and the import seed. Empty collections are created only when the first document is written.
## Design boundaries
- Shared care data lives under a **household** and a specific **care recipient**.
- Confidential caregiver support and wellbeing data lives under the caregiver’s **user-owned private path**, not under the household.
- AI output never replaces original human input; original text/audio and machine-generated structures are stored separately.
- Medication dosage is never inferred solely from pill appearance. OCR output remains an unverified draft until confirmed by an authorized person.
- Government services are directory/routing records, not app users and not implied API integrations.
- Client writes are denied by default; the Admin SDK performs writes after API authorization and validation.
## Reference, content, and configuration
| Document path | Purpose | Client reads | Client writes |
|---|---|---|---|
| `_schema/{version}` | Machine-readable data-model version and migration metadata. | authenticated | serverOnly |
| `appConfig/{configId}` | Runtime-safe configuration exposed to authenticated clients. | authenticated | serverOnly |
| `featureFlags/{flagId}` | Feature rollout and pilot controls. | authenticated | serverOnly |
| `supportedLocales/{localeCode}` | Supported interface, speech, translation, and offline capabilities by locale. | publicRead | serverOnly |
| `governmentServices/{serviceId}` | Verified Taiwan government or public-support service directory. | verifiedPublicRead | serverOnly |
| `emergencyPhrasebooks/{phrasebookId}` | Versioned multilingual phrasebook metadata. | authenticatedApprovedOnly | serverOnly |
| `emergencyPhrasebooks/{phrasebookId}/phrases/{phraseId}` | Verified emergency and service-navigation phrases. | authenticatedApprovedOnly | serverOnly |
| `terminologyGlossaries/{glossaryId}` | Versioned care terminology glossary metadata. | authenticatedApprovedOnly | serverOnly |
| `terminologyGlossaries/{glossaryId}/entries/{entryId}` | Approved domain terms used by translation services. | authenticatedApprovedOnly | serverOnly |
| `knowledgeArticles/{articleId}` | Reviewed caregiver micro-training and public-service guidance. | authenticatedApprovedOnly | serverOnly |
| `trainingModules/{moduleId}` | Structured multilingual caregiver training module. | authenticatedApprovedOnly | serverOnly |
| `trainingModules/{moduleId}/lessons/{lessonId}` | Ordered lesson content and knowledge checks. | authenticatedApprovedOnly | serverOnly |
| `safetyRuleSets/{ruleSetId}` | Versioned deterministic routing and escalation rules. | authenticatedApprovedOnly | serverOnly |
| `safetyRuleSets/{ruleSetId}/rules/{ruleId}` | Individual reviewed routing rule; no autonomous diagnosis. | platformAdminOnly | serverOnly |
| `promptTemplates/{templateId}` | Versioned server-side AI prompt templates. | none | serverOnly |
| `modelPolicies/{policyId}` | Allowed AI provider/model usage, fallback, and data-handling policy. | none | serverOnly |

## Partner organizations
| Document path | Purpose | Client reads | Client writes |
|---|---|---|---|
| `organizations/{organizationId}` | Partner NGO, agency, clinic, hospital, community center, or research organization. | authenticatedLimited | serverOnly |
| `organizations/{organizationId}/members/{uid}` | Organization role and scoped permissions. | organizationMembers | serverOnly |
| `organizations/{organizationId}/sites/{siteId}` | Physical or virtual pilot/service site. | organizationMembers | serverOnly |

## User-owned and private data
| Document path | Purpose | Client reads | Client writes |
|---|---|---|---|
| `users/{uid}` | User profile linked to Firebase Authentication UID. | selfOnly | serverOnly |
| `users/{uid}/devices/{deviceId}` | Push-notification and device registration. | selfOnly | serverOnly |
| `users/{uid}/preferences/{preferenceId}` | Accessibility, notification, privacy, and interface preferences. | selfOnly | serverOnly |
| `users/{uid}/notifications/{notificationId}` | User notification inbox corresponding to FCM delivery. | selfOnly | serverOnly |
| `users/{uid}/trainingProgress/{moduleId}` | Per-user training progress and assessment results. | selfOnly | serverOnly |
| `users/{uid}/wellbeingCheckIns/{checkInId}` | Private caregiver wellbeing check-in, separate from household care records. | selfOnly | serverOnly |
| `users/{uid}/privateSupportRequests/{requestId}` | Confidential worker-support case preparation and routing. | selfAndExplicitGrantees | serverOnly |
| `users/{uid}/privateSupportRequests/{requestId}/messages/{messageId}` | Confidential messages or case notes within a support request. | selfAndExplicitGrantees | serverOnly |
| `users/{uid}/privateSupportRequests/{requestId}/referrals/{referralId}` | User-consented handoff to a public service or partner organization. | selfAndExplicitGrantees | serverOnly |
| `users/{uid}/privateMediaAssets/{assetId}` | Metadata for confidential audio, image, or document files. | selfAndExplicitGrantees | serverOnly |
| `users/{uid}/consents/{consentId}` | Versioned informed consent and withdrawal record. | selfOnly | serverOnly |
| `users/{uid}/dataSubjectRequests/{requestId}` | Personal-data access, export, correction, deletion, restriction, or consent withdrawal request. | selfOnly | serverOnly |
| `users/{uid}/emergencySessions/{sessionId}` | User-initiated emergency preparation/call session without claiming agency receipt. | selfOnly | serverOnly |

## Household shared-care data
| Document path | Purpose | Client reads | Client writes |
|---|---|---|---|
| `households/{householdId}` | Shared care household boundary and primary authorization unit. | membersOnly | serverOnly |
| `households/{householdId}/members/{uid}` | Household membership, role, and scoped permissions. | membersOnly | serverOnly |
| `households/{householdId}/invitations/{invitationId}` | Secure time-limited invitation to a household. | householdAdminsOnly | serverOnly |
| `households/{householdId}/settings/{settingsId}` | Household-level care, privacy, notification, and display settings. | membersOnly | serverOnly |
| `households/{householdId}/organizationLinks/{linkId}` | Consent-aware relationship between a household and partner organization. | membersAndOrganizationGrantees | serverOnly |
| `households/{householdId}/accessGrants/{grantId}` | Explicit, revocable, time-limited access to care resources. | grantPartiesAndAdmins | serverOnly |
| `households/{householdId}/threads/{threadId}` | Structured clarification or care communication thread. | participantsAndAuthorizedMembers | serverOnly |
| `households/{householdId}/threads/{threadId}/messages/{messageId}` | Original and translated clarification message. | threadParticipants | serverOnly |
| `households/{householdId}/serviceReferrals/{referralId}` | Household-consented referral to 1966, dementia support, clinic, or other service. | authorizedMembersAndGrantees | serverOnly |
| `households/{householdId}/mediaAssets/{assetId}` | Metadata for shared household care files. | authorizedMembers | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}` | Older adult or other person receiving care. | authorizedMembers | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/assignments/{caregiverUid}` | Active or historical caregiver assignment and scopes. | authorizedMembers | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/carePlans/{carePlanId}` | Versioned source of truth for routine, baseline, responsibilities, and agreed actions. | authorizedMembers | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/observations/{observationId}` | Caregiver-authored structured observation with original voice/text preserved. | authorOrAuthorizedVisibility | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}` | Family or professional care instruction with translation and teach-back. | assignedCaregiverOrAuthorizedCareTeam | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/steps/{stepId}` | Ordered extracted instruction step. | parentReaders | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/confirmations/{confirmationId}` | Teach-back answers and mismatch detection. | caregiverAndInstructionCreators | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/tasks/{taskId}` | Recurring or one-time care task definition. | authorizedMembers | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/taskEvents/{taskEventId}` | Materialized scheduled occurrence and caregiver-recorded completion. | authorizedMembers | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/medications/{medicationId}` | Verified medication instruction and schedule; never inferred solely from pill appearance. | authorizedCareTeam | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/medicationEvents/{eventId}` | Scheduled medication reminder and caregiver-recorded outcome. | authorizedCareTeam | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/measurements/{measurementId}` | Structured vital sign or other measurement. | authorizedCareTeam | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/incidents/{incidentId}` | Non-routine safety or care incident report. | authorOrAuthorizedVisibility | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/handovers/{handoverId}` | Structured shift/day handover for continuity of care. | authorizedCareTeam | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/appointments/{appointmentId}` | Medical, long-term-care, or administrative appointment. | authorizedMembers | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/documents/{documentId}` | Care-plan, prescription-label, appointment, or identity-support document metadata. | authorizedVisibility | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/reports/{reportId}` | Generated bilingual care report for family, coordinator, clinic, or export. | authorizedVisibility | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/alerts/{alertId}` | Persistent alert state used with push notifications. | recipientsAndAuthorizedCareTeam | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/dailySummaries/{dateKey}` | Denormalized daily dashboard summary generated by backend. | authorizedCareTeam | serverOnly |
| `households/{householdId}/careRecipients/{careRecipientId}/weeklySummaries/{weekKey}` | Denormalized weekly trend summary generated by backend. | authorizedCareTeam | serverOnly |

## Server and operational data
| Document path | Purpose | Client reads | Client writes |
|---|---|---|---|
| `processingJobs/{jobId}` | Asynchronous AI/OCR/translation/TTS processing queue. | requesterStatusOnly | serverOnly |
| `aiRuns/{runId}` | Traceability record for each AI provider invocation and human review. | entityAuthorizedUsersLimited | serverOnly |
| `notificationOutbox/{messageId}` | Backend transactional notification queue and delivery audit. | none | serverOnly |
| `idempotencyKeys/{keyHash}` | Prevents duplicate API side effects from retries and offline sync. | none | serverOnly |
| `auditEvents/{auditId}` | Append-only security and data-access audit trail. | platformAdminOnly | serverOnly |
| `scheduledWork/{workId}` | Recurring task/medication event generation and summary jobs. | none | serverOnly |
| `migrations/{migrationId}` | Applied database migration record. | platformAdminOnly | serverOnly |

## Pilot and evaluation data
| Document path | Purpose | Client reads | Client writes |
|---|---|---|---|
| `pilotStudies/{studyId}` | Pilot validation project and governance metadata. | pilotMembersOnly | serverOnly |
| `pilotStudies/{studyId}/sites/{siteId}` | Pilot site configuration. | pilotMembersOnly | serverOnly |
| `pilotStudies/{studyId}/participants/{participantId}` | Pseudonymous pilot enrollment without unnecessary identity duplication. | pilotAuthorizedResearchers | serverOnly |
| `pilotStudies/{studyId}/sessions/{sessionId}` | Usability or field-validation session. | pilotAuthorizedResearchers | serverOnly |
| `pilotStudies/{studyId}/feedback/{feedbackId}` | Structured participant feedback and usability measures. | pilotAuthorizedResearchers | serverOnly |
| `pilotStudies/{studyId}/metricSnapshots/{snapshotId}` | Aggregated pilot metrics without raw personal content. | pilotMembersOnly | serverOnly |

## Common document conventions
### `audit` mixin
- `createdAt`: `timestamp`
- `createdBy`: `uid|string`
- `updatedAt`: `timestamp`
- `updatedBy`: `uid|string`

### `softDelete` mixin
- `deletedAt`: `timestamp|null`
- `deletedBy`: `uid|string|null`
- `deletionReason`: `string|null`

### `retention` mixin
- `retentionUntil`: `timestamp|null`
- `legalHold`: `boolean`

### `sync` mixin
- `clientGeneratedId`: `string|null`
- `clientCreatedAt`: `timestamp|null`
- `lastModifiedByDeviceId`: `string|null`
- `version`: `integer>=1`
- `syncState`: `server|synced|conflict`

### `localizedText` mixin
- `originalLanguage`: `localeCode`
- `originalText`: `string`
- `translations`: `map<localeCode, TranslationValue>`

## Collection-level field catalog
The complete field-by-field contract—including required domains, lifecycle, ownership, retention, suggested queries, and notes—is in [`schema/kalinga-firestore-schema.json`](../schema/kalinga-firestore-schema.json). It is the authoritative schema catalog for backend validators and migrations.
