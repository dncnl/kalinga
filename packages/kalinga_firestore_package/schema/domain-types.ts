/**
 * GENERATED FILE. Source: kalinga-firestore-schema.json + enums.json + contracts-manifest.json.
 * Run `npm run generate:contracts` after changing the authoritative schema.
 */

export type TimestampLike = unknown;

export type LocaleCode = 'zh-TW' | 'en' | 'id' | 'vi' | 'fil' | 'ceb';
export type HouseholdRole = 'householdAdmin' | 'family' | 'caregiver' | 'careCoordinator' | 'clinician' | 'agencyStaff';
export type MembershipStatus = 'invited' | 'active' | 'suspended' | 'removed';
export type Visibility = 'privateToAuthor' | 'selectedUsers' | 'household' | 'careTeam';
export type RecordStatus = 'draft' | 'processing' | 'ready' | 'shared' | 'archived' | 'cancelled';
export type Urgency = 'none' | 'information' | 'attention' | 'urgent' | 'emergency';
export type ServiceCategory = 'police' | 'fireMedicalEmergency' | 'protection' | 'labor' | 'longTermCare' | 'generalForeignerSupport' | 'dementiaSupport' | 'caregiverSupport' | 'occupationalInjury';
export type SupportCategory = 'salary' | 'rest' | 'healthcareAccess' | 'injury' | 'harassment' | 'unsafeWork' | 'documentRetention' | 'interpretation' | 'contract' | 'immigration' | 'other';
export type ObservationCategory = 'appetite' | 'hydration' | 'sleep' | 'mood' | 'behavior' | 'mobility' | 'pain' | 'elimination' | 'medication' | 'vitalSigns' | 'skin' | 'breathing' | 'fall' | 'other';
export type InstructionRiskLevel = 'routine' | 'careSensitive' | 'highRisk';
export type InstructionStatus = 'draft' | 'sent' | 'needsClarification' | 'confirmed' | 'completed' | 'cancelled';
export type TaskCategory = 'medication' | 'meal' | 'hydration' | 'mobility' | 'hygiene' | 'measurement' | 'appointment' | 'exercise' | 'repositioning' | 'household' | 'other';
export type TaskEventStatus = 'pending' | 'completed' | 'skipped' | 'refused' | 'notAvailable' | 'needsHelp' | 'cancelled';
export type MedicationVerificationStatus = 'unverified' | 'familyConfirmed' | 'clinicianConfirmed';
export type MedicationEventStatus = 'scheduled' | 'completed' | 'skipped' | 'refused' | 'notAvailable' | 'needsClarification' | 'cancelled';
export type MeasurementType = 'bloodPressure' | 'temperature' | 'oxygenSaturation' | 'bloodGlucose' | 'heartRate' | 'weight' | 'respiratoryRate' | 'other';
export type MeasurementSource = 'manual' | 'bluetoothDevice' | 'ocr' | 'imported';
export type IncidentCategory = 'fall' | 'injury' | 'medicationIssue' | 'missingPerson' | 'careConflict' | 'abuseConcern' | 'propertyDamage' | 'other';
export type AlertType = 'observationChange' | 'instructionMismatch' | 'missedTask' | 'missedMedication' | 'measurementOutsideCarePlan' | 'supportRequest' | 'emergency' | 'system';
export type AIJobType = 'speechToText' | 'translation' | 'textToSpeech' | 'structuredObservation' | 'instructionExtraction' | 'ocr' | 'summary' | 'routing';
export type AIJobStatus = 'queued' | 'processing' | 'completed' | 'failed' | 'cancelled' | 'needsReview';
export type ConsentType = 'terms' | 'privacyPolicy' | 'storeAudio' | 'shareCareData' | 'shareWithClinician' | 'shareSupportRequest' | 'useForResearch' | 'locationForEmergency';
export type DataSubjectRequestType = 'access' | 'export' | 'correction' | 'deletion' | 'restrictProcessing' | 'withdrawConsent';
export type EmergencySessionStatus = 'prepared' | 'callInitiated' | 'userReportedConnected' | 'cancelled';
export type ReferralStatus = 'draft' | 'prepared' | 'userInitiated' | 'submittedByPartner' | 'acknowledged' | 'closed' | 'cancelled';
export type NotificationStatus = 'queued' | 'sent' | 'delivered' | 'failed' | 'read' | 'dismissed';
export type AccessPermission = 'view' | 'comment' | 'download' | 'share';
export type PilotParticipantType = 'caregiver' | 'family' | 'careCoordinator' | 'clinician' | 'observer';
export type TrainingProgressStatus = 'notStarted' | 'inProgress' | 'completed' | 'expired';
export type OrganizationType = 'ngo' | 'careAgency' | 'clinic' | 'hospital' | 'communityCenter' | 'government' | 'researchInstitution' | 'other';

export interface TranslationValue {
  text: string;
  provider: string | null;
  model: string | null;
  generatedAt: TimestampLike | null;
  reviewedByUser: boolean;
  reviewedByUid: string | null;
  reviewedAt: TimestampLike | null;
  sourceHash: string | null;
}

export interface AuditFields {
  createdAt: TimestampLike;
  createdBy: string;
  updatedAt: TimestampLike;
  updatedBy: string;
}

export interface SoftDeleteFields {
  deletedAt: TimestampLike | null;
  deletedBy: string | null;
  deletionReason: string | null;
}

export interface RetentionFields {
  retentionUntil: TimestampLike | null;
  legalHold: boolean;
}

export interface SyncFields {
  clientGeneratedId: string | null;
  clientCreatedAt: TimestampLike | null;
  lastModifiedByDeviceId: string | null;
  version: number;
  syncState: 'server' | 'synced' | 'conflict';
}

export interface LocalizedTextFields {
  originalLanguage: LocaleCode;
  originalText: string;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
}

/**
 * Firestore path: _schema/{version}
 * Machine-readable data-model version and migration metadata.
 * Client read policy: authenticated; client write policy: serverOnly.
 */
export interface SchemaVersionDocument {
  version: string;
  database: string;
  releasedAt: TimestampLike;
  compatibleApiVersions: string[];
  collectionManifest: string[];
  breakingChanges: string[];
  migrationNotes: string[];
  active: boolean;
}

/**
 * Firestore path: appConfig/{configId}
 * Runtime-safe configuration exposed to authenticated clients.
 * Client read policy: authenticated; client write policy: serverOnly.
 */
export interface AppConfigDocument extends AuditFields {
  minimumAppVersion: string;
  recommendedAppVersion: string;
  maintenanceMode: boolean;
  defaultLocale: LocaleCode;
  supportedLocaleCodes: LocaleCode[];
  supportEmail: string | null;
  privacyPolicyVersion: string;
  termsVersion: string;
  maxVoiceSeconds: number;
  maxUploadBytes: number;
  offlinePhrasebookVersion: string;
  serviceDirectoryVersion: string;
}

/**
 * Firestore path: featureFlags/{flagId}
 * Feature rollout and pilot controls.
 * Client read policy: authenticated; client write policy: serverOnly.
 */
export interface FeatureFlagDocument extends AuditFields {
  enabled: boolean;
  description: string;
  allowedRoles: HouseholdRole[];
  allowedPilotStudyIds: string[];
  percentageRollout: number;
  startsAt: TimestampLike | null;
  endsAt: TimestampLike | null;
}

/**
 * Firestore path: supportedLocales/{localeCode}
 * Supported interface, speech, translation, and offline capabilities by locale.
 * Client read policy: publicRead; client write policy: serverOnly.
 */
export interface SupportedLocaleDocument extends AuditFields {
  localeCode: LocaleCode;
  displayNameEnglish: string;
  displayNameNative: string;
  enabled: boolean;
  interfaceSupported: boolean;
  speechToTextSupported: boolean;
  textToSpeechSupported: boolean;
  onlineTranslationSupported: boolean;
  offlineTranslationSupported: boolean;
  offlinePhrasebookSupported: boolean;
  fallbackLocale: LocaleCode | null;
  notes: string | null;
}

/**
 * Firestore path: governmentServices/{serviceId}
 * Verified Taiwan government or public-support service directory.
 * Client read policy: verifiedPublicRead; client write policy: serverOnly.
 */
export interface GovernmentServiceDocument extends AuditFields {
  serviceId: string;
  officialName: string;
  shortName: string;
  category: ServiceCategory;
  phoneNumber: string | null;
  officialUrl: string | null;
  onlineChatUrl: string | null;
  supportedLanguages: Array<LocaleCode | string>;
  operatingHours: Record<string, unknown>;
  localizedDescriptions: Partial<Record<LocaleCode, string>>;
  eligibilityNotes: Partial<Record<LocaleCode, string>>;
  emergency: boolean;
  verificationStatus: 'verified' | 'requiresPreLaunchVerification' | 'retired';
  lastVerifiedAt: TimestampLike | null;
  verifiedBy: string | null;
  sourceUrl: string | null;
  displayOrder: number;
  enabled: boolean;
}

/**
 * Firestore path: emergencyPhrasebooks/{phrasebookId}
 * Versioned multilingual phrasebook metadata.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface EmergencyPhrasebookDocument extends AuditFields {
  name: string;
  version: string;
  supportedLocales: LocaleCode[];
  status: 'draft' | 'approved' | 'retired';
  reviewedBy: string | null;
  reviewedAt: TimestampLike | null;
  effectiveFrom: TimestampLike | null;
  supersedesId: string | null;
}

/**
 * Firestore path: emergencyPhrasebooks/{phrasebookId}/phrases/{phraseId}
 * Verified emergency and service-navigation phrases.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface EmergencyPhraseDocument extends AuditFields {
  category: ServiceCategory | string;
  scenarioKey: string;
  localizedText: Partial<Record<LocaleCode, string>>;
  localizedAudioAssetIds: Partial<Record<LocaleCode, string>>;
  recommendedServiceId: string | null;
  requiresImmediateCall: boolean;
  displayOrder: number;
  status: 'draft' | 'approved' | 'retired';
}

/**
 * Firestore path: terminologyGlossaries/{glossaryId}
 * Versioned care terminology glossary metadata.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface TerminologyGlossaryDocument extends AuditFields {
  name: string;
  sourceLocales: LocaleCode[];
  targetLocales: LocaleCode[];
  version: string;
  status: 'draft' | 'approved' | 'retired';
  reviewedBy: string | null;
  reviewedAt: TimestampLike | null;
  effectiveFrom: TimestampLike | null;
}

/**
 * Firestore path: terminologyGlossaries/{glossaryId}/entries/{entryId}
 * Approved domain terms used by translation services.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface TerminologyEntryDocument extends AuditFields {
  category: 'medication' | 'careTask' | 'emergency' | 'governmentService' | 'bodyPart' | 'symptomDescription' | 'rights' | 'other';
  sourceLocale: LocaleCode;
  targetLocale: LocaleCode;
  sourceTerm: string;
  approvedTranslation: string;
  alternatives: string[];
  doNotTranslate: boolean;
  caseSensitive: boolean;
  notes: string | null;
  status: 'draft' | 'approved' | 'retired';
}

/**
 * Firestore path: knowledgeArticles/{articleId}
 * Reviewed caregiver micro-training and public-service guidance.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface KnowledgeArticleDocument extends AuditFields {
  slug: string;
  category: string;
  title: Partial<Record<LocaleCode, string>>;
  summary: Partial<Record<LocaleCode, string>>;
  contentBlocks: Record<string, unknown>[];
  sourceUrls: string[];
  audienceRoles: HouseholdRole[];
  status: 'draft' | 'approved' | 'retired';
  reviewedBy: string | null;
  reviewedAt: TimestampLike | null;
  version: number;
  offlineAvailable: boolean;
  tags: string[];
}

/**
 * Firestore path: trainingModules/{moduleId}
 * Structured multilingual caregiver training module.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface TrainingModuleDocument extends AuditFields {
  slug: string;
  title: Partial<Record<LocaleCode, string>>;
  description: Partial<Record<LocaleCode, string>>;
  category: string;
  audienceRoles: HouseholdRole[];
  estimatedMinutes: number;
  status: 'draft' | 'approved' | 'retired';
  version: number;
  prerequisiteModuleIds: string[];
  reviewedBy: string | null;
  reviewedAt: TimestampLike | null;
}

/**
 * Firestore path: trainingModules/{moduleId}/lessons/{lessonId}
 * Ordered lesson content and knowledge checks.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface TrainingLessonDocument extends AuditFields {
  order: number;
  title: Partial<Record<LocaleCode, string>>;
  contentBlocks: Record<string, unknown>[];
  quizQuestions: Record<string, unknown>[];
  status: 'draft' | 'approved' | 'retired';
  estimatedMinutes: number;
}

/**
 * Firestore path: safetyRuleSets/{ruleSetId}
 * Versioned deterministic routing and escalation rules.
 * Client read policy: authenticatedApprovedOnly; client write policy: serverOnly.
 */
export interface SafetyRuleSetDocument extends AuditFields {
  name: string;
  version: string;
  status: 'draft' | 'approved' | 'retired';
  supportedLocales: LocaleCode[];
  reviewedBy: string | null;
  reviewedAt: TimestampLike | null;
  effectiveFrom: TimestampLike | null;
  supersedesId: string | null;
  scope: 'serviceRouting' | 'carePlanThresholds' | 'emergencyPhrases';
}

/**
 * Firestore path: safetyRuleSets/{ruleSetId}/rules/{ruleId}
 * Individual reviewed routing rule; no autonomous diagnosis.
 * Client read policy: platformAdminOnly; client write policy: serverOnly.
 */
export interface SafetyRuleDocument extends AuditFields {
  ruleKey: string;
  category: ServiceCategory | string;
  inputMode: 'userSelected' | 'keywordAssist' | 'carePlanThreshold';
  triggerPatterns: Partial<Record<LocaleCode, string[]>>;
  requiredStructuredFields: string[];
  recommendedServiceId: string | null;
  messageKey: string;
  urgency: Urgency;
  requiresUserConfirmation: boolean;
  active: boolean;
  displayOrder: number;
  notes: string | null;
}

/**
 * Firestore path: promptTemplates/{templateId}
 * Versioned server-side AI prompt templates.
 * Client read policy: none; client write policy: serverOnly.
 */
export interface PromptTemplateDocument extends AuditFields {
  task: AIJobType;
  version: string;
  template: string;
  inputSchemaVersion: string;
  outputSchemaVersion: string;
  allowedModels: string[];
  status: 'draft' | 'approved' | 'retired';
  reviewedBy: string | null;
  reviewedAt: TimestampLike | null;
}

/**
 * Firestore path: modelPolicies/{policyId}
 * Allowed AI provider/model usage, fallback, and data-handling policy.
 * Client read policy: none; client write policy: serverOnly.
 */
export interface ModelPolicyDocument extends AuditFields {
  task: AIJobType;
  primaryProvider: string;
  primaryModel: string;
  fallbacks: Record<string, unknown>[];
  sendAudioToProvider: boolean;
  sendImageToProvider: boolean;
  redactionRequired: boolean;
  maxRetries: number;
  timeoutMs: number;
  status: 'active' | 'inactive';
  effectiveFrom: TimestampLike;
}

/**
 * Firestore path: ragSources/{sourceId}
 * Raw RAG knowledge-base source documents (Taiwan health authority, WHO, peer-reviewed research, ...) that back the symptom-checker and /rag/ask. Chunked + embedded into ragChunks by apps/api/src/rag/ingest.js.
 * Client read policy: none; client write policy: serverOnly.
 */
export interface RagSourceDocument extends AuditFields {
  title: string;
  publisher: string;
  url: string;
  retrievedAt: string;
  category: string;
  text: string;
}

/**
 * Firestore path: ragChunks/{chunkId}
 * Chunked + embedded RAG corpus, derived from ragSources. Retrieved by cosine similarity against a query embedding for grounded symptom-checker/RAG answers.
 * Client read policy: none; client write policy: serverOnly.
 */
export interface RagChunkDocument {
  sourceId: string;
  sourceTitle: string;
  sourcePublisher: string;
  sourceUrl: string;
  sourceRetrievedAt: string;
  sourceCategory: string;
  chunkIndex: number;
  text: string;
  embedding: number[];
}

/**
 * Firestore path: organizations/{organizationId}
 * Partner NGO, agency, clinic, hospital, community center, or research organization.
 * Client read policy: authenticatedLimited; client write policy: serverOnly.
 */
export interface OrganizationDocument extends AuditFields {
  name: string;
  type: OrganizationType;
  registrationName: string | null;
  countryCode: string;
  address: Record<string, unknown> | null;
  contactEmail: string | null;
  contactPhone: string | null;
  website: string | null;
  status: 'active' | 'inactive';
  dataProcessingAgreementVersion: string | null;
  verifiedAt: TimestampLike | null;
  verifiedBy: string | null;
}

/**
 * Firestore path: organizations/{organizationId}/members/{uid}
 * Organization role and scoped permissions.
 * Client read policy: organizationMembers; client write policy: serverOnly.
 */
export interface OrganizationMemberDocument extends AuditFields {
  uid: string;
  role: 'organizationAdmin' | 'coordinator' | 'clinician' | 'researcher' | 'viewer';
  permissions: Record<string, boolean>;
  status: 'active' | 'suspended' | 'removed';
  joinedAt: TimestampLike;
  invitedBy: string;
}

/**
 * Firestore path: organizations/{organizationId}/sites/{siteId}
 * Physical or virtual pilot/service site.
 * Client read policy: organizationMembers; client write policy: serverOnly.
 */
export interface OrganizationSiteDocument extends AuditFields {
  name: string;
  type: 'office' | 'clinic' | 'hospitalUnit' | 'communityCenter' | 'virtual';
  address: Record<string, unknown> | null;
  timezone: string;
  contactName: string | null;
  contactEmail: string | null;
  contactPhone: string | null;
  status: 'active' | 'inactive';
}

/**
 * Firestore path: users/{uid}
 * User profile linked to Firebase Authentication UID.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface UserDocument extends AuditFields {
  uid: string;
  displayName: string;
  avatarAssetId: string | null;
  emailNormalized: string | null;
  phoneE164: string | null;
  preferredLanguage: LocaleCode;
  additionalLanguages: LocaleCode[];
  preferredInputMode: 'voice' | 'text' | 'mixed';
  timezone: string;
  accountStatus: 'active' | 'suspended' | 'deleted';
  onboardingCompleted: boolean;
  termsVersionAccepted: string | null;
  privacyVersionAccepted: string | null;
  lastActiveAt: TimestampLike | null;
}

/**
 * Firestore path: users/{uid}/devices/{deviceId}
 * Push-notification and device registration.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface UserDeviceDocument extends AuditFields {
  deviceId: string;
  platform: 'android' | 'ios' | 'web';
  fcmToken: string;
  appVersion: string;
  osVersion: string | null;
  locale: LocaleCode;
  timezone: string;
  notificationsEnabled: boolean;
  lastActiveAt: TimestampLike;
  revokedAt: TimestampLike | null;
}

/**
 * Firestore path: users/{uid}/preferences/{preferenceId}
 * Accessibility, notification, privacy, and interface preferences.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface UserPreferenceDocument extends AuditFields {
  preferenceId: 'accessibility' | 'notifications' | 'privacy' | 'interface';
  values: Record<string, unknown>;
  schemaVersion: string;
}

/**
 * Firestore path: users/{uid}/notifications/{notificationId}
 * User notification inbox corresponding to FCM delivery.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface UserNotificationDocument extends AuditFields {
  type: string;
  title: Partial<Record<LocaleCode, string>> | string;
  body: Partial<Record<LocaleCode, string>> | string;
  deepLink: string | null;
  relatedEntityPath: string | null;
  status: NotificationStatus;
  sentAt: TimestampLike | null;
  deliveredAt: TimestampLike | null;
  readAt: TimestampLike | null;
  expiresAt: TimestampLike | null;
  priority: 'normal' | 'high';
}

/**
 * Firestore path: users/{uid}/trainingProgress/{moduleId}
 * Per-user training progress and assessment results.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface TrainingProgressDocument extends AuditFields {
  moduleId: string;
  moduleVersion: number;
  status: TrainingProgressStatus;
  completedLessonIds: string[];
  quizAttempts: Record<string, unknown>[];
  startedAt: TimestampLike | null;
  completedAt: TimestampLike | null;
  expiresAt: TimestampLike | null;
}

/**
 * Firestore path: users/{uid}/wellbeingCheckIns/{checkInId}
 * Private caregiver wellbeing check-in, separate from household care records.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface WellbeingCheckInDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  mood: number | null;
  fatigue: number | null;
  painOrInjury: boolean;
  needsHealthcare: boolean;
  needsPrivateSupport: boolean;
  originalLanguage: LocaleCode;
  note: string | null;
  recommendedServiceIds: string[];
  visibility: 'privateToAuthor';
}

/**
 * Firestore path: users/{uid}/privateSupportRequests/{requestId}
 * Confidential worker-support case preparation and routing.
 * Client read policy: selfAndExplicitGrantees; client write policy: serverOnly.
 */
export interface PrivateSupportRequestDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  category: SupportCategory;
  status: 'draft' | 'prepared' | 'userContactedService' | 'referred' | 'closed' | 'cancelled';
  originalLanguage: LocaleCode;
  originalDescription: string;
  translatedSummary: Partial<Record<LocaleCode, string>>;
  recommendedServiceId: string | null;
  preferredContactMethod: 'call' | 'chat' | 'inPerson' | 'none';
  consentToShare: boolean;
  sharedWithOrganizationIds: string[];
  sharedWithUserIds: string[];
  incidentDate: TimestampLike | null;
  locationText: string | null;
  safetyConcern: boolean;
  lastActivityAt: TimestampLike;
}

/**
 * Firestore path: users/{uid}/privateSupportRequests/{requestId}/messages/{messageId}
 * Confidential messages or case notes within a support request.
 * Client read policy: selfAndExplicitGrantees; client write policy: serverOnly.
 */
export interface PrivateSupportMessageDocument extends AuditFields, SoftDeleteFields {
  senderType: 'user' | 'supportPartner' | 'system';
  senderUid: string | null;
  senderOrganizationId: string | null;
  originalLanguage: LocaleCode;
  originalText: string;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
  mediaAssetIds: string[];
  visibility: 'privateToAuthor' | 'sharedWithGrantees';
  sentAt: TimestampLike;
}

/**
 * Firestore path: users/{uid}/privateSupportRequests/{requestId}/referrals/{referralId}
 * User-consented handoff to a public service or partner organization.
 * Client read policy: selfAndExplicitGrantees; client write policy: serverOnly.
 */
export interface PrivateSupportReferralDocument extends AuditFields, SoftDeleteFields {
  serviceId: string | null;
  organizationId: string | null;
  status: ReferralStatus;
  preparedSummary: Partial<Record<LocaleCode, string>>;
  consentRecordId: string;
  initiatedAt: TimestampLike | null;
  acknowledgedAt: TimestampLike | null;
  closedAt: TimestampLike | null;
  externalReference: string | null;
  notes: string | null;
}

/**
 * Firestore path: users/{uid}/privateMediaAssets/{assetId}
 * Metadata for confidential audio, image, or document files.
 * Client read policy: selfAndExplicitGrantees; client write policy: serverOnly.
 */
export interface PrivateMediaAssetDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  storagePath: string;
  mediaType: 'audio' | 'image' | 'document';
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  linkedEntityPath: string;
  encryptionKeyVersion: string | null;
  uploadStatus: 'pending' | 'uploaded' | 'scanned' | 'rejected';
  virusScanStatus: 'pending' | 'clean' | 'blocked';
  consentId: string | null;
  capturedAt: TimestampLike | null;
}

/**
 * Firestore path: users/{uid}/consents/{consentId}
 * Versioned informed consent and withdrawal record.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface ConsentRecordDocument extends AuditFields {
  consentType: ConsentType;
  policyVersion: string;
  granted: boolean;
  grantedAt: TimestampLike | null;
  revokedAt: TimestampLike | null;
  scope: Record<string, unknown>;
  evidenceHash: string | null;
  locale: LocaleCode;
  capturedBy: 'self' | 'partner' | 'system';
}

/**
 * Firestore path: users/{uid}/dataSubjectRequests/{requestId}
 * Personal-data access, export, correction, deletion, restriction, or consent withdrawal request.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface DataSubjectRequestDocument extends AuditFields {
  type: DataSubjectRequestType;
  status: 'submitted' | 'underReview' | 'fulfilled' | 'partiallyFulfilled' | 'rejected' | 'cancelled';
  scopePaths: string[];
  requestNote: string | null;
  resolutionNote: string | null;
  submittedAt: TimestampLike;
  completedAt: TimestampLike | null;
  handledBy: string | null;
  exportAssetId: string | null;
}

/**
 * Firestore path: users/{uid}/emergencySessions/{sessionId}
 * User-initiated emergency preparation/call session without claiming agency receipt.
 * Client read policy: selfOnly; client write policy: serverOnly.
 */
export interface EmergencySessionDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  serviceId: string;
  careRecipientPath: string | null;
  emergencyType: string;
  userSelectedFacts: Record<string, unknown>;
  preparedPhrase: Partial<Record<LocaleCode, string>>;
  locationShared: boolean;
  locationSnapshot: Record<string, unknown> | null;
  callInitiatedAt: TimestampLike | null;
  userReportedConnected: boolean;
  status: EmergencySessionStatus;
  endedAt: TimestampLike | null;
}

/**
 * Firestore path: households/{householdId}
 * Shared care household boundary and primary authorization unit.
 * Client read policy: membersOnly; client write policy: serverOnly.
 */
export interface HouseholdDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  name: string;
  timezone: string;
  defaultLocale: LocaleCode;
  status: 'active' | 'paused' | 'archived';
  createdByUid: string;
  primaryFamilyContactUid: string | null;
  organizationLinkIds: string[];
  privacyPolicyVersion: string;
  consentModel: 'individual' | 'householdWithIndividualOverrides';
  dataRegion: string | null;
  archivedAt: TimestampLike | null;
}

/**
 * Firestore path: households/{householdId}/members/{uid}
 * Household membership, role, and scoped permissions.
 * Client read policy: membersOnly; client write policy: serverOnly.
 */
export interface HouseholdMemberDocument extends AuditFields {
  uid: string;
  role: HouseholdRole;
  status: MembershipStatus;
  permissions: Record<string, boolean>;
  careRecipientIds: string[];
  joinedAt: TimestampLike | null;
  invitedByUid: string | null;
  removedAt: TimestampLike | null;
  displayNameSnapshot: string;
  preferredLanguageSnapshot: LocaleCode;
}

/**
 * Firestore path: households/{householdId}/invitations/{invitationId}
 * Secure time-limited invitation to a household.
 * Client read policy: householdAdminsOnly; client write policy: serverOnly.
 */
export interface HouseholdInvitationDocument extends AuditFields {
  intendedRole: HouseholdRole;
  invitedEmailNormalized: string | null;
  invitedPhoneE164: string | null;
  tokenHash: string;
  expiresAt: TimestampLike;
  status: 'pending' | 'accepted' | 'expired' | 'revoked';
  acceptedByUid: string | null;
  acceptedAt: TimestampLike | null;
  permissionsTemplate: Record<string, boolean>;
}

/**
 * Firestore path: households/{householdId}/settings/{settingsId}
 * Household-level care, privacy, notification, and display settings.
 * Client read policy: membersOnly; client write policy: serverOnly.
 */
export interface HouseholdSettingDocument extends AuditFields {
  settingsId: 'care' | 'privacy' | 'notifications' | 'display';
  values: Record<string, unknown>;
  schemaVersion: string;
}

/**
 * Firestore path: households/{householdId}/organizationLinks/{linkId}
 * Consent-aware relationship between a household and partner organization.
 * Client read policy: membersAndOrganizationGrantees; client write policy: serverOnly.
 */
export interface HouseholdOrganizationLinkDocument extends AuditFields {
  organizationId: string;
  siteId: string | null;
  relationshipType: 'careAgency' | 'clinic' | 'ngoSupport' | 'pilot' | 'other';
  status: 'pending' | 'active' | 'suspended' | 'ended';
  permissions: Record<string, boolean>;
  consentRecordIds: string[];
  startsAt: TimestampLike;
  endsAt: TimestampLike | null;
  linkedByUid: string;
}

/**
 * Firestore path: households/{householdId}/accessGrants/{grantId}
 * Explicit, revocable, time-limited access to care resources.
 * Client read policy: grantPartiesAndAdmins; client write policy: serverOnly.
 */
export interface AccessGrantDocument extends AuditFields {
  grantedByUid: string;
  grantedToUid: string | null;
  grantedToOrganizationId: string | null;
  resourcePath: string;
  permissions: AccessPermission[];
  purpose: string;
  consentRecordIds: string[];
  startsAt: TimestampLike;
  expiresAt: TimestampLike | null;
  revokedAt: TimestampLike | null;
  status: 'active' | 'expired' | 'revoked';
}

/**
 * Firestore path: households/{householdId}/threads/{threadId}
 * Structured clarification or care communication thread.
 * Client read policy: participantsAndAuthorizedMembers; client write policy: serverOnly.
 */
export interface CareThreadDocument extends AuditFields {
  careRecipientId: string | null;
  linkedEntityPath: string | null;
  subject: string;
  participantUids: string[];
  participantOrganizationIds: string[];
  status: 'open' | 'resolved' | 'archived';
  lastMessageAt: TimestampLike | null;
  createdByUid: string;
  visibility: Visibility;
}

/**
 * Firestore path: households/{householdId}/threads/{threadId}/messages/{messageId}
 * Original and translated clarification message.
 * Client read policy: threadParticipants; client write policy: serverOnly.
 */
export interface CareThreadMessageDocument extends AuditFields, SoftDeleteFields, SyncFields {
  senderUid: string;
  originalLanguage: LocaleCode;
  originalText: string;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
  mediaAssetIds: string[];
  messageType: 'text' | 'voice' | 'system' | 'clarification';
  sentAt: TimestampLike;
  editedAt: TimestampLike | null;
  deletedForEveryoneAt: TimestampLike | null;
}

/**
 * Firestore path: households/{householdId}/serviceReferrals/{referralId}
 * Household-consented referral to 1966, dementia support, clinic, or other service.
 * Client read policy: authorizedMembersAndGrantees; client write policy: serverOnly.
 */
export interface ServiceReferralDocument extends AuditFields {
  careRecipientId: string | null;
  serviceId: string | null;
  organizationId: string | null;
  status: ReferralStatus;
  preparedSummary: Partial<Record<LocaleCode, string>>;
  consentRecordIds: string[];
  initiatedByUid: string;
  initiatedAt: TimestampLike | null;
  acknowledgedAt: TimestampLike | null;
  closedAt: TimestampLike | null;
  externalReference: string | null;
}

/**
 * Firestore path: households/{householdId}/mediaAssets/{assetId}
 * Metadata for shared household care files.
 * Client read policy: authorizedMembers; client write policy: serverOnly.
 */
export interface HouseholdMediaAssetDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  storagePath: string;
  mediaType: 'audio' | 'image' | 'document';
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  ownerUid: string;
  careRecipientId: string | null;
  linkedEntityPath: string;
  visibility: Visibility;
  allowedUserIds: string[];
  uploadStatus: 'pending' | 'uploaded' | 'scanned' | 'rejected';
  virusScanStatus: 'pending' | 'clean' | 'blocked';
  capturedAt: TimestampLike | null;
  consentRecordIds: string[];
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}
 * Older adult or other person receiving care.
 * Client read policy: authorizedMembers; client write policy: serverOnly.
 */
export interface CareRecipientDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  displayName: string;
  preferredName: string | null;
  birthDate: string | null;
  sex: 'female' | 'male' | 'other' | 'undisclosed';
  photoAssetId: string | null;
  preferredLanguages: Array<LocaleCode | string>;
  communicationNotes: string | null;
  careProfile: Record<string, unknown>;
  emergencyContacts: Record<string, unknown>[];
  primaryCaregiverUid: string | null;
  primaryFamilyContactUid: string | null;
  status: 'active' | 'inactive' | 'deceased' | 'archived';
  externalIdentifiers: Record<string, string>;
  clinicalDisclaimerAcknowledged: boolean;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/assignments/{caregiverUid}
 * Active or historical caregiver assignment and scopes.
 * Client read policy: authorizedMembers; client write policy: serverOnly.
 */
export interface CareAssignmentDocument extends AuditFields {
  caregiverUid: string;
  startsAt: TimestampLike;
  endsAt: TimestampLike | null;
  status: 'active' | 'paused' | 'ended';
  scopes: string[];
  scheduleNotes: string | null;
  assignedByUid: string;
  temporary: boolean;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/carePlans/{carePlanId}
 * Versioned source of truth for routine, baseline, responsibilities, and agreed actions.
 * Client read policy: authorizedMembers; client write policy: serverOnly.
 */
export interface CarePlanDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  title: string;
  version: number;
  status: 'draft' | 'active' | 'superseded' | 'cancelled';
  effectiveFrom: TimestampLike;
  effectiveUntil: TimestampLike | null;
  baseline: Record<string, unknown>;
  goals: string[];
  routine: Record<string, unknown>[];
  approvedActions: Record<string, unknown>[];
  contactsAndEscalation: Record<string, unknown>[];
  dietaryNotes: string | null;
  mobilityNotes: string | null;
  communicationNotes: string | null;
  medicationPlanReference: string | null;
  approvedByUids: string[];
  approvedAt: TimestampLike | null;
  supersedesPlanId: string | null;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/observations/{observationId}
 * Caregiver-authored structured observation with original voice/text preserved.
 * Client read policy: authorOrAuthorizedVisibility; client write policy: serverOnly.
 */
export interface ObservationDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  authorUid: string;
  inputMode: 'voice' | 'text' | 'structuredForm';
  originalLanguage: LocaleCode;
  originalText: string;
  originalAudioAssetId: string | null;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
  structuredObservation: Record<string, unknown>;
  categories: ObservationCategory[];
  comparisonToUsual: 'better' | 'same' | 'worse' | 'unknown' | null;
  observedAt: TimestampLike;
  safetyAssessment: Record<string, unknown>;
  visibility: Visibility;
  allowedUserIds: string[];
  allowedOrganizationIds: string[];
  status: RecordStatus;
  reviewedByAuthor: boolean;
  reviewedAt: TimestampLike | null;
  threadId: string | null;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}
 * Family or professional care instruction with translation and teach-back.
 * Client read policy: assignedCaregiverOrAuthorizedCareTeam; client write policy: serverOnly.
 */
export interface InstructionDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  createdByUid: string;
  assignedCaregiverUids: string[];
  sourceType: 'family' | 'careCoordinator' | 'clinician' | 'carePlan';
  originalLanguage: LocaleCode;
  originalText: string;
  originalAudioAssetId: string | null;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
  riskLevel: InstructionRiskLevel;
  scheduledAt: TimestampLike | null;
  recurrenceRule: string | null;
  confirmationRequired: boolean;
  status: InstructionStatus;
  clarificationThreadId: string | null;
  carePlanId: string | null;
  validFrom: TimestampLike | null;
  validUntil: TimestampLike | null;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/steps/{stepId}
 * Ordered extracted instruction step.
 * Client read policy: parentReaders; client write policy: serverOnly.
 */
export interface InstructionStepDocument extends AuditFields {
  order: number;
  action: string;
  itemName: string | null;
  quantity: string | null;
  timing: string | null;
  condition: string | null;
  safetyNote: string | null;
  escalationRule: string | null;
  criticalFields: string[];
  sourceSpan: string | null;
  userConfirmed: boolean;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/confirmations/{confirmationId}
 * Teach-back answers and mismatch detection.
 * Client read policy: caregiverAndInstructionCreators; client write policy: serverOnly.
 */
export interface InstructionConfirmationDocument extends AuditFields, RetentionFields {
  caregiverUid: string;
  attemptNumber: number;
  questions: Record<string, unknown>[];
  answers: Record<string, unknown>[];
  allCriticalDetailsMatched: boolean;
  mismatchFields: string[];
  clarificationRequested: boolean;
  confirmedAt: TimestampLike | null;
  status: 'passed' | 'failed' | 'needsClarification' | 'abandoned';
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/tasks/{taskId}
 * Recurring or one-time care task definition.
 * Client read policy: authorizedMembers; client write policy: serverOnly.
 */
export interface CareTaskDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  title: string;
  description: string | null;
  category: TaskCategory;
  createdByUid: string;
  assignedToUids: string[];
  carePlanId: string | null;
  instructionId: string | null;
  timezone: string;
  schedule: Record<string, unknown>;
  nextDueAt: TimestampLike | null;
  completionRequiresNote: boolean;
  completionRequiresMeasurementType: MeasurementType | null;
  status: 'active' | 'paused' | 'completed' | 'cancelled';
  startsAt: TimestampLike | null;
  endsAt: TimestampLike | null;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/taskEvents/{taskEventId}
 * Materialized scheduled occurrence and caregiver-recorded completion.
 * Client read policy: authorizedMembers; client write policy: serverOnly.
 */
export interface CareTaskEventDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  taskId: string;
  scheduledAt: TimestampLike;
  windowStart: TimestampLike | null;
  windowEnd: TimestampLike | null;
  assignedToUids: string[];
  status: TaskEventStatus;
  completedByUid: string | null;
  completedAt: TimestampLike | null;
  caregiverNote: string | null;
  relatedObservationId: string | null;
  relatedMeasurementId: string | null;
  idempotencyKey: string;
  generatedBy: 'scheduler' | 'manual';
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/medications/{medicationId}
 * Verified medication instruction and schedule; never inferred solely from pill appearance.
 * Client read policy: authorizedCareTeam; client write policy: serverOnly.
 */
export interface MedicationDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  name: string;
  genericName: string | null;
  strength: string | null;
  dosageText: string;
  route: string | null;
  schedule: Record<string, unknown>;
  specialInstructions: string | null;
  reason: string | null;
  enteredByUid: string;
  verifiedByUid: string | null;
  verificationStatus: MedicationVerificationStatus;
  sourceType: 'familyEntry' | 'clinicianDocument' | 'labelOcrDraft';
  sourceDocumentAssetId: string | null;
  ocrDraft: Record<string, unknown> | null;
  startsAt: TimestampLike | null;
  endsAt: TimestampLike | null;
  nextDoseAt: TimestampLike | null;
  status: 'active' | 'paused' | 'completed' | 'cancelled';
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/medicationEvents/{eventId}
 * Scheduled medication reminder and caregiver-recorded outcome.
 * Client read policy: authorizedCareTeam; client write policy: serverOnly.
 */
export interface MedicationEventDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  medicationId: string;
  scheduledAt: TimestampLike;
  windowStart: TimestampLike | null;
  windowEnd: TimestampLike | null;
  status: MedicationEventStatus;
  completedByUid: string | null;
  completedAt: TimestampLike | null;
  caregiverNote: string | null;
  refusalReason: string | null;
  relatedObservationId: string | null;
  idempotencyKey: string;
  generatedBy: 'scheduler' | 'manual';
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/measurements/{measurementId}
 * Structured vital sign or other measurement.
 * Client read policy: authorizedCareTeam; client write policy: serverOnly.
 */
export interface MeasurementDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  recordedByUid: string;
  type: MeasurementType;
  values: Record<string, number>;
  unit: string;
  measuredAt: TimestampLike;
  source: MeasurementSource;
  deviceRegistrationId: string | null;
  sourceMediaAssetId: string | null;
  verificationStatus: 'userConfirmed' | 'deviceImported' | 'unverified';
  carePlanId: string | null;
  thresholdEvaluation: Record<string, unknown> | null;
  note: string | null;
  idempotencyKey: string;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/incidents/{incidentId}
 * Non-routine safety or care incident report.
 * Client read policy: authorOrAuthorizedVisibility; client write policy: serverOnly.
 */
export interface IncidentDocument extends AuditFields, SoftDeleteFields, RetentionFields, SyncFields {
  reportedByUid: string;
  category: IncidentCategory;
  occurredAt: TimestampLike;
  originalLanguage: LocaleCode;
  description: string;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
  immediateActionTaken: string | null;
  injurySuspected: boolean;
  emergencySessionId: string | null;
  relatedObservationIds: string[];
  mediaAssetIds: string[];
  visibility: Visibility;
  allowedUserIds: string[];
  status: 'draft' | 'submitted' | 'reviewed' | 'closed';
  reviewedByUid: string | null;
  closedAt: TimestampLike | null;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/handovers/{handoverId}
 * Structured shift/day handover for continuity of care.
 * Client read policy: authorizedCareTeam; client write policy: serverOnly.
 */
export interface CareHandoverDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  periodStart: TimestampLike;
  periodEnd: TimestampLike;
  outgoingCaregiverUid: string;
  incomingCaregiverUid: string | null;
  summary: Partial<Record<LocaleCode, string>>;
  completedTaskEventIds: string[];
  unresolvedTaskEventIds: string[];
  importantObservationIds: string[];
  incidentIds: string[];
  upcomingTaskEventIds: string[];
  acknowledgedByUid: string | null;
  acknowledgedAt: TimestampLike | null;
  status: 'draft' | 'shared' | 'acknowledged' | 'archived';
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/appointments/{appointmentId}
 * Medical, long-term-care, or administrative appointment.
 * Client read policy: authorizedMembers; client write policy: serverOnly.
 */
export interface AppointmentDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  title: string;
  type: 'medical' | 'longTermCare' | 'government' | 'other';
  startsAt: TimestampLike;
  endsAt: TimestampLike | null;
  timezone: string;
  location: Record<string, unknown> | null;
  providerName: string | null;
  organizationId: string | null;
  attendeeUids: string[];
  preparationChecklist: Record<string, unknown>[];
  relatedReportId: string | null;
  status: 'scheduled' | 'completed' | 'cancelled' | 'missed';
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/documents/{documentId}
 * Care-plan, prescription-label, appointment, or identity-support document metadata.
 * Client read policy: authorizedVisibility; client write policy: serverOnly.
 */
export interface CareRecipientAttachmentDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  title: string;
  documentType: 'carePlan' | 'medicationLabel' | 'clinicInstruction' | 'appointment' | 'governmentForm' | 'other';
  mediaAssetId: string;
  uploadedByUid: string;
  issuedAt: TimestampLike | null;
  expiresAt: TimestampLike | null;
  issuerName: string | null;
  visibility: Visibility;
  allowedUserIds: string[];
  verificationStatus: 'unverified' | 'reviewed' | 'verified';
  verifiedByUid: string | null;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/reports/{reportId}
 * Generated bilingual care report for family, coordinator, clinic, or export.
 * Client read policy: authorizedVisibility; client write policy: serverOnly.
 */
export interface CareReportDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  reportType: 'daily' | 'weekly' | 'appointment' | 'handover' | 'custom';
  periodStart: TimestampLike;
  periodEnd: TimestampLike;
  generatedByUid: string;
  sourceEntityPaths: string[];
  localizedContent: Partial<Record<LocaleCode, Record<string, unknown>>>;
  pdfAssetId: string | null;
  shareTokenHash: string | null;
  shareTokenExpiresAt: TimestampLike | null;
  visibility: Visibility;
  allowedUserIds: string[];
  status: 'generating' | 'ready' | 'failed' | 'expired';
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/alerts/{alertId}
 * Persistent alert state used with push notifications.
 * Client read policy: recipientsAndAuthorizedCareTeam; client write policy: serverOnly.
 */
export interface AlertDocument extends AuditFields, SoftDeleteFields, RetentionFields {
  type: AlertType;
  severity: Urgency;
  sourceEntityPath: string;
  recipientUids: string[];
  title: Partial<Record<LocaleCode, string>> | string;
  message: Partial<Record<LocaleCode, string>> | string;
  recommendedServiceId: string | null;
  status: 'active' | 'acknowledged' | 'resolved' | 'dismissed';
  acknowledgedByUid: string | null;
  acknowledgedAt: TimestampLike | null;
  resolvedByUid: string | null;
  resolvedAt: TimestampLike | null;
  expiresAt: TimestampLike | null;
  deduplicationKey: string;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/dailySummaries/{dateKey}
 * Denormalized daily dashboard summary generated by backend.
 * Client read policy: authorizedCareTeam; client write policy: serverOnly.
 */
export interface DailySummaryDocument {
  dateKey: string;
  timezone: string;
  taskCounts: Record<string, unknown>;
  medicationCounts: Record<string, unknown>;
  observationCounts: Record<string, unknown>;
  measurementHighlights: Record<string, unknown>[];
  activeAlertCount: number;
  unresolvedConcernCount: number;
  summaryText: Partial<Record<LocaleCode, string>>;
  generatedFromVersion: number;
  generatedAt: TimestampLike;
}

/**
 * Firestore path: households/{householdId}/careRecipients/{careRecipientId}/weeklySummaries/{weekKey}
 * Denormalized weekly trend summary generated by backend.
 * Client read policy: authorizedCareTeam; client write policy: serverOnly.
 */
export interface WeeklySummaryDocument {
  weekKey: string;
  periodStart: TimestampLike;
  periodEnd: TimestampLike;
  timezone: string;
  trendSeries: Record<string, unknown>;
  notableChanges: Record<string, unknown>[];
  activeAlertCount: number;
  summaryText: Partial<Record<LocaleCode, string>>;
  generatedFromVersion: number;
  generatedAt: TimestampLike;
}

/**
 * Firestore path: processingJobs/{jobId}
 * Asynchronous AI/OCR/translation/TTS processing queue.
 * Client read policy: requesterStatusOnly; client write policy: serverOnly.
 */
export interface ProcessingJobDocument extends AuditFields, RetentionFields {
  task: AIJobType;
  sourceEntityPath: string;
  requestedByUid: string;
  householdId: string | null;
  careRecipientId: string | null;
  status: AIJobStatus;
  priority: 'low' | 'normal' | 'high';
  attemptCount: number;
  maxAttempts: number;
  nextRetryAt: TimestampLike | null;
  leaseOwner: string | null;
  leaseExpiresAt: TimestampLike | null;
  errorCode: string | null;
  errorMessage: string | null;
  inputAssetIds: string[];
  outputEntityPath: string | null;
  idempotencyKey: string;
  queuedAt: TimestampLike;
  startedAt: TimestampLike | null;
  completedAt: TimestampLike | null;
}

/**
 * Firestore path: aiRuns/{runId}
 * Traceability record for each AI provider invocation and human review.
 * Client read policy: entityAuthorizedUsersLimited; client write policy: serverOnly.
 */
export interface AiRunDocument extends AuditFields, RetentionFields {
  jobId: string;
  task: AIJobType;
  provider: string;
  model: string;
  modelVersion: string | null;
  promptTemplateId: string | null;
  promptVersion: string | null;
  glossaryId: string | null;
  glossaryVersion: string | null;
  safetyRuleSetId: string | null;
  safetyRuleVersion: string | null;
  inputEntityPath: string;
  outputEntityPath: string | null;
  inputHash: string;
  outputHash: string | null;
  structuredOutput: Record<string, unknown> | null;
  confidence: number | null;
  redactionApplied: boolean;
  userReviewed: boolean;
  reviewedByUid: string | null;
  reviewOutcome: 'accepted' | 'edited' | 'rejected' | null;
  providerRequestId: string | null;
  latencyMs: number | null;
  tokenUsage: Record<string, unknown> | null;
  status: 'success' | 'failed' | 'needsReview';
  errorCode: string | null;
}

/**
 * Firestore path: notificationOutbox/{messageId}
 * Backend transactional notification queue and delivery audit.
 * Client read policy: none; client write policy: serverOnly.
 */
export interface NotificationOutboxDocument extends AuditFields, RetentionFields {
  recipientUid: string;
  deviceIds: string[];
  notificationType: string;
  payload: Record<string, unknown>;
  deepLink: string | null;
  status: NotificationStatus;
  attemptCount: number;
  nextRetryAt: TimestampLike | null;
  sentAt: TimestampLike | null;
  providerMessageIds: string[];
  errorCode: string | null;
  deduplicationKey: string;
  expiresAt: TimestampLike | null;
}

/**
 * Firestore path: idempotencyKeys/{keyHash}
 * Prevents duplicate API side effects from retries and offline sync.
 * Client read policy: none; client write policy: serverOnly.
 */
export interface IdempotencyKeyDocument {
  keyHash: string;
  scope: string;
  ownerUid: string;
  requestHash: string;
  responseStatus: number | null;
  responseEntityPath: string | null;
  lockedUntil: TimestampLike | null;
  completedAt: TimestampLike | null;
  expiresAt: TimestampLike;
}

/**
 * Firestore path: auditEvents/{auditId}
 * Append-only security and data-access audit trail.
 * Client read policy: platformAdminOnly; client write policy: serverOnly.
 */
export interface AuditEventDocument {
  actorUid: string;
  actorType: 'user' | 'server' | 'admin' | 'organization';
  action: 'create' | 'read' | 'update' | 'share' | 'download' | 'delete' | 'login' | 'consent' | 'export';
  entityPath: string;
  householdId: string | null;
  careRecipientId: string | null;
  organizationId: string | null;
  purpose: string | null;
  requestId: string | null;
  ipHash: string | null;
  deviceId: string | null;
  result: 'allowed' | 'denied' | 'failed';
  metadata: Record<string, unknown>;
  occurredAt: TimestampLike;
  retentionUntil: TimestampLike;
}

/**
 * Firestore path: scheduledWork/{workId}
 * Recurring task/medication event generation and summary jobs.
 * Client read policy: none; client write policy: serverOnly.
 */
export interface ScheduledWorkDocument extends AuditFields, RetentionFields {
  workType: 'generateTaskEvents' | 'generateMedicationEvents' | 'dailySummary' | 'weeklySummary' | 'expireGrants' | 'cleanupRetention';
  targetPath: string;
  schedule: Record<string, unknown>;
  nextRunAt: TimestampLike;
  lastRunAt: TimestampLike | null;
  status: 'active' | 'paused' | 'completed' | 'failed';
  leaseOwner: string | null;
  leaseExpiresAt: TimestampLike | null;
  attemptCount: number;
  errorCode: string | null;
}

/**
 * Firestore path: migrations/{migrationId}
 * Applied database migration record.
 * Client read policy: platformAdminOnly; client write policy: serverOnly.
 */
export interface MigrationDocument extends AuditFields {
  fromVersion: string;
  toVersion: string;
  description: string;
  status: 'planned' | 'running' | 'completed' | 'failed';
  startedAt: TimestampLike | null;
  completedAt: TimestampLike | null;
  appliedBy: string | null;
  checkpoint: Record<string, unknown> | null;
  error: string | null;
}

/**
 * Firestore path: pilotStudies/{studyId}
 * Pilot validation project and governance metadata.
 * Client read policy: pilotMembersOnly; client write policy: serverOnly.
 */
export interface PilotStudyDocument extends AuditFields, RetentionFields {
  name: string;
  description: string;
  status: 'planning' | 'recruiting' | 'active' | 'analysis' | 'completed' | 'cancelled';
  leadOrganizationId: string;
  partnerOrganizationIds: string[];
  protocolVersion: string;
  consentVersion: string;
  startsAt: TimestampLike | null;
  endsAt: TimestampLike | null;
  targetMetrics: string[];
  ethicsReviewReference: string | null;
  dataRetentionUntil: TimestampLike | null;
}

/**
 * Firestore path: pilotStudies/{studyId}/sites/{siteId}
 * Pilot site configuration.
 * Client read policy: pilotMembersOnly; client write policy: serverOnly.
 */
export interface PilotStudySiteDocument extends AuditFields {
  organizationId: string;
  organizationSiteId: string | null;
  name: string;
  status: 'planned' | 'active' | 'completed';
  coordinatorUids: string[];
  targetParticipantCount: number;
  startsAt: TimestampLike | null;
  endsAt: TimestampLike | null;
}

/**
 * Firestore path: pilotStudies/{studyId}/participants/{participantId}
 * Pseudonymous pilot enrollment without unnecessary identity duplication.
 * Client read policy: pilotAuthorizedResearchers; client write policy: serverOnly.
 */
export interface PilotParticipantDocument extends AuditFields {
  participantCode: string;
  userUid: string | null;
  participantType: PilotParticipantType;
  siteId: string | null;
  consentRecordPath: string;
  enrolledAt: TimestampLike;
  withdrawnAt: TimestampLike | null;
  status: 'active' | 'completed' | 'withdrawn';
  cohort: string | null;
  demographicsMinimal: Record<string, unknown> | null;
}

/**
 * Firestore path: pilotStudies/{studyId}/sessions/{sessionId}
 * Usability or field-validation session.
 * Client read policy: pilotAuthorizedResearchers; client write policy: serverOnly.
 */
export interface PilotSessionDocument extends AuditFields {
  participantId: string;
  sessionType: 'onboarding' | 'taskTest' | 'interview' | 'fieldUse' | 'followUp';
  facilitatorUid: string | null;
  startedAt: TimestampLike;
  endedAt: TimestampLike | null;
  scenarioKeys: string[];
  completionMetrics: Record<string, unknown>;
  notesDeidentified: string | null;
  recordingAssetId: string | null;
  status: 'scheduled' | 'completed' | 'cancelled';
}

/**
 * Firestore path: pilotStudies/{studyId}/feedback/{feedbackId}
 * Structured participant feedback and usability measures.
 * Client read policy: pilotAuthorizedResearchers; client write policy: serverOnly.
 */
export interface PilotFeedbackDocument extends AuditFields {
  participantId: string;
  sessionId: string | null;
  instrument: 'SUS' | 'UMUXLite' | 'custom';
  responses: Record<string, unknown>;
  score: number | null;
  freeTextDeidentified: string | null;
  locale: LocaleCode;
  submittedAt: TimestampLike;
}

/**
 * Firestore path: pilotStudies/{studyId}/metricSnapshots/{snapshotId}
 * Aggregated pilot metrics without raw personal content.
 * Client read policy: pilotMembersOnly; client write policy: serverOnly.
 */
export interface PilotMetricSnapshotDocument extends AuditFields {
  periodStart: TimestampLike;
  periodEnd: TimestampLike;
  metricValues: Record<string, number>;
  denominators: Record<string, number>;
  calculationVersion: string;
  generatedAt: TimestampLike;
  generatedBy: string;
  suppressionApplied: boolean;
}

export interface DocumentByPathPattern {
  "_schema/{version}": SchemaVersionDocument;
  "appConfig/{configId}": AppConfigDocument;
  "featureFlags/{flagId}": FeatureFlagDocument;
  "supportedLocales/{localeCode}": SupportedLocaleDocument;
  "governmentServices/{serviceId}": GovernmentServiceDocument;
  "emergencyPhrasebooks/{phrasebookId}": EmergencyPhrasebookDocument;
  "emergencyPhrasebooks/{phrasebookId}/phrases/{phraseId}": EmergencyPhraseDocument;
  "terminologyGlossaries/{glossaryId}": TerminologyGlossaryDocument;
  "terminologyGlossaries/{glossaryId}/entries/{entryId}": TerminologyEntryDocument;
  "knowledgeArticles/{articleId}": KnowledgeArticleDocument;
  "trainingModules/{moduleId}": TrainingModuleDocument;
  "trainingModules/{moduleId}/lessons/{lessonId}": TrainingLessonDocument;
  "safetyRuleSets/{ruleSetId}": SafetyRuleSetDocument;
  "safetyRuleSets/{ruleSetId}/rules/{ruleId}": SafetyRuleDocument;
  "promptTemplates/{templateId}": PromptTemplateDocument;
  "modelPolicies/{policyId}": ModelPolicyDocument;
  "ragSources/{sourceId}": RagSourceDocument;
  "ragChunks/{chunkId}": RagChunkDocument;
  "organizations/{organizationId}": OrganizationDocument;
  "organizations/{organizationId}/members/{uid}": OrganizationMemberDocument;
  "organizations/{organizationId}/sites/{siteId}": OrganizationSiteDocument;
  "users/{uid}": UserDocument;
  "users/{uid}/devices/{deviceId}": UserDeviceDocument;
  "users/{uid}/preferences/{preferenceId}": UserPreferenceDocument;
  "users/{uid}/notifications/{notificationId}": UserNotificationDocument;
  "users/{uid}/trainingProgress/{moduleId}": TrainingProgressDocument;
  "users/{uid}/wellbeingCheckIns/{checkInId}": WellbeingCheckInDocument;
  "users/{uid}/privateSupportRequests/{requestId}": PrivateSupportRequestDocument;
  "users/{uid}/privateSupportRequests/{requestId}/messages/{messageId}": PrivateSupportMessageDocument;
  "users/{uid}/privateSupportRequests/{requestId}/referrals/{referralId}": PrivateSupportReferralDocument;
  "users/{uid}/privateMediaAssets/{assetId}": PrivateMediaAssetDocument;
  "users/{uid}/consents/{consentId}": ConsentRecordDocument;
  "users/{uid}/dataSubjectRequests/{requestId}": DataSubjectRequestDocument;
  "users/{uid}/emergencySessions/{sessionId}": EmergencySessionDocument;
  "households/{householdId}": HouseholdDocument;
  "households/{householdId}/members/{uid}": HouseholdMemberDocument;
  "households/{householdId}/invitations/{invitationId}": HouseholdInvitationDocument;
  "households/{householdId}/settings/{settingsId}": HouseholdSettingDocument;
  "households/{householdId}/organizationLinks/{linkId}": HouseholdOrganizationLinkDocument;
  "households/{householdId}/accessGrants/{grantId}": AccessGrantDocument;
  "households/{householdId}/threads/{threadId}": CareThreadDocument;
  "households/{householdId}/threads/{threadId}/messages/{messageId}": CareThreadMessageDocument;
  "households/{householdId}/serviceReferrals/{referralId}": ServiceReferralDocument;
  "households/{householdId}/mediaAssets/{assetId}": HouseholdMediaAssetDocument;
  "households/{householdId}/careRecipients/{careRecipientId}": CareRecipientDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/assignments/{caregiverUid}": CareAssignmentDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/carePlans/{carePlanId}": CarePlanDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/observations/{observationId}": ObservationDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}": InstructionDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/steps/{stepId}": InstructionStepDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/confirmations/{confirmationId}": InstructionConfirmationDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/tasks/{taskId}": CareTaskDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/taskEvents/{taskEventId}": CareTaskEventDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/medications/{medicationId}": MedicationDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/medicationEvents/{eventId}": MedicationEventDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/measurements/{measurementId}": MeasurementDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/incidents/{incidentId}": IncidentDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/handovers/{handoverId}": CareHandoverDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/appointments/{appointmentId}": AppointmentDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/documents/{documentId}": CareRecipientAttachmentDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/reports/{reportId}": CareReportDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/alerts/{alertId}": AlertDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/dailySummaries/{dateKey}": DailySummaryDocument;
  "households/{householdId}/careRecipients/{careRecipientId}/weeklySummaries/{weekKey}": WeeklySummaryDocument;
  "processingJobs/{jobId}": ProcessingJobDocument;
  "aiRuns/{runId}": AiRunDocument;
  "notificationOutbox/{messageId}": NotificationOutboxDocument;
  "idempotencyKeys/{keyHash}": IdempotencyKeyDocument;
  "auditEvents/{auditId}": AuditEventDocument;
  "scheduledWork/{workId}": ScheduledWorkDocument;
  "migrations/{migrationId}": MigrationDocument;
  "pilotStudies/{studyId}": PilotStudyDocument;
  "pilotStudies/{studyId}/sites/{siteId}": PilotStudySiteDocument;
  "pilotStudies/{studyId}/participants/{participantId}": PilotParticipantDocument;
  "pilotStudies/{studyId}/sessions/{sessionId}": PilotSessionDocument;
  "pilotStudies/{studyId}/feedback/{feedbackId}": PilotFeedbackDocument;
  "pilotStudies/{studyId}/metricSnapshots/{snapshotId}": PilotMetricSnapshotDocument;
}

export type FirestoreDocumentPathPattern = keyof DocumentByPathPattern;
export type DocumentForPathPattern<P extends FirestoreDocumentPathPattern> = DocumentByPathPattern[P];
export type CreateDocumentInput<T> = Omit<T, keyof AuditFields | keyof SoftDeleteFields | keyof RetentionFields | keyof SyncFields>;
export type PatchDocumentInput<T> = Partial<CreateDocumentInput<T>>;

