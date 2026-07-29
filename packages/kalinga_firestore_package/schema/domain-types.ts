/** Core application-facing types. The full catalog is in kalinga-firestore-schema.json. */
export type LocaleCode = 'zh-TW' | 'en' | 'id' | 'vi' | 'fil' | 'ceb';
export type HouseholdRole = 'householdAdmin' | 'family' | 'caregiver' | 'careCoordinator' | 'clinician' | 'agencyStaff';
export type Visibility = 'privateToAuthor' | 'selectedUsers' | 'household' | 'careTeam';
export type Urgency = 'none' | 'information' | 'attention' | 'urgent' | 'emergency';

export interface TranslationValue {
  text: string;
  provider?: string | null;
  model?: string | null;
  generatedAt?: unknown;
  reviewedByUser: boolean;
  reviewedByUid?: string | null;
  reviewedAt?: unknown;
  sourceHash?: string | null;
}

export interface UserDocument {
  uid: string;
  displayName: string;
  preferredLanguage: LocaleCode;
  additionalLanguages: LocaleCode[];
  preferredInputMode: 'voice' | 'text' | 'mixed';
  timezone: string;
  accountStatus: 'active' | 'suspended' | 'deleted';
  onboardingCompleted: boolean;
}

export interface HouseholdMemberDocument {
  uid: string;
  role: HouseholdRole;
  status: 'invited' | 'active' | 'suspended' | 'removed';
  permissions: Record<string, boolean>;
  careRecipientIds: string[];
  displayNameSnapshot: string;
  preferredLanguageSnapshot: LocaleCode;
}

export interface CareRecipientDocument {
  displayName: string;
  preferredName?: string | null;
  preferredLanguages: string[];
  communicationNotes?: string | null;
  careProfile: Record<string, unknown>;
  emergencyContacts: Array<Record<string, unknown>>;
  primaryCaregiverUid?: string | null;
  primaryFamilyContactUid?: string | null;
  status: 'active' | 'inactive' | 'deceased' | 'archived';
}

export interface ObservationDocument {
  authorUid: string;
  inputMode: 'voice' | 'text' | 'structuredForm';
  originalLanguage: LocaleCode;
  originalText: string;
  originalAudioAssetId?: string | null;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
  structuredObservation: Record<string, unknown>;
  categories: string[];
  comparisonToUsual?: 'better' | 'same' | 'worse' | 'unknown' | null;
  observedAt: unknown;
  safetyAssessment: Record<string, unknown>;
  visibility: Visibility;
  allowedUserIds: string[];
  status: 'draft' | 'processing' | 'ready' | 'shared' | 'archived' | 'cancelled';
  reviewedByAuthor: boolean;
}

export interface InstructionDocument {
  createdByUid: string;
  assignedCaregiverUids: string[];
  sourceType: 'family' | 'careCoordinator' | 'clinician' | 'carePlan';
  originalLanguage: LocaleCode;
  originalText: string;
  translations: Partial<Record<LocaleCode, TranslationValue>>;
  riskLevel: 'routine' | 'careSensitive' | 'highRisk';
  confirmationRequired: boolean;
  status: 'draft' | 'sent' | 'needsClarification' | 'confirmed' | 'completed' | 'cancelled';
}

export interface MedicationDocument {
  name: string;
  strength?: string | null;
  dosageText: string;
  schedule: Record<string, unknown>;
  enteredByUid: string;
  verifiedByUid?: string | null;
  verificationStatus: 'unverified' | 'familyConfirmed' | 'clinicianConfirmed';
  sourceType: 'familyEntry' | 'clinicianDocument' | 'labelOcrDraft';
  status: 'active' | 'paused' | 'completed' | 'cancelled';
}

export interface PrivateSupportRequestDocument {
  category: string;
  status: 'draft' | 'prepared' | 'userContactedService' | 'referred' | 'closed' | 'cancelled';
  originalLanguage: LocaleCode;
  originalDescription: string;
  translatedSummary: Partial<Record<LocaleCode, string>>;
  recommendedServiceId?: string | null;
  consentToShare: boolean;
  sharedWithOrganizationIds: string[];
  sharedWithUserIds: string[];
  safetyConcern: boolean;
}
