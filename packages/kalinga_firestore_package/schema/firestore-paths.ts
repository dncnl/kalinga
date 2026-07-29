/**
 * Type-safe Firestore path helpers for the Kalinga Node.js API.
 * This is not a substitute for authorization or runtime validation.
 */
export const paths = {
  user: (uid: string) => `users/${uid}`,
  userDevices: (uid: string) => `users/${uid}/devices`,
  userPreferences: (uid: string) => `users/${uid}/preferences`,
  userNotifications: (uid: string) => `users/${uid}/notifications`,
  privateSupportRequests: (uid: string) => `users/${uid}/privateSupportRequests`,
  privateSupportRequest: (uid: string, requestId: string) => `users/${uid}/privateSupportRequests/${requestId}`,
  privateSupportMessages: (uid: string, requestId: string) => `users/${uid}/privateSupportRequests/${requestId}/messages`,
  privateSupportReferrals: (uid: string, requestId: string) => `users/${uid}/privateSupportRequests/${requestId}/referrals`,
  userConsents: (uid: string) => `users/${uid}/consents`,
  userEmergencySessions: (uid: string) => `users/${uid}/emergencySessions`,

  household: (householdId: string) => `households/${householdId}`,
  householdMembers: (householdId: string) => `households/${householdId}/members`,
  householdMember: (householdId: string, uid: string) => `households/${householdId}/members/${uid}`,
  householdInvitations: (householdId: string) => `households/${householdId}/invitations`,
  careRecipients: (householdId: string) => `households/${householdId}/careRecipients`,
  careRecipient: (householdId: string, recipientId: string) => `households/${householdId}/careRecipients/${recipientId}`,
  assignments: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/assignments`,
  carePlans: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/carePlans`,
  observations: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/observations`,
  instructions: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/instructions`,
  instructionSteps: (householdId: string, recipientId: string, instructionId: string) => `${paths.instructions(householdId, recipientId)}/${instructionId}/steps`,
  instructionConfirmations: (householdId: string, recipientId: string, instructionId: string) => `${paths.instructions(householdId, recipientId)}/${instructionId}/confirmations`,
  tasks: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/tasks`,
  taskEvents: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/taskEvents`,
  medications: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/medications`,
  medicationEvents: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/medicationEvents`,
  measurements: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/measurements`,
  incidents: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/incidents`,
  handovers: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/handovers`,
  appointments: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/appointments`,
  reports: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/reports`,
  alerts: (householdId: string, recipientId: string) => `${paths.careRecipient(householdId, recipientId)}/alerts`,

  governmentServices: () => 'governmentServices',
  processingJobs: () => 'processingJobs',
  aiRuns: () => 'aiRuns',
  auditEvents: () => 'auditEvents'
} as const;
