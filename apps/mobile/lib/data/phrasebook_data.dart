enum Category { medicalEmergency, dementia, medication, selfAdvocacy }

enum UrgencyLevel { normal, high }

enum PatientLanguage { mandarin, hokkien }

class PhrasebookEntry {
  final String id;
  final String targetPhrase; // displayed text, keeps 他/她 written convention
  final String ttsPhrase; // spoken text, gender resolved — safe for TTS
  final String targetRomanization;
  final String caregiverGloss;
  final Category category;
  final UrgencyLevel urgencyLevel;
  final PatientLanguage patientLanguage;

  const PhrasebookEntry({
    required this.id,
    required this.targetPhrase,
    required this.ttsPhrase,
    required this.targetRomanization,
    required this.caregiverGloss,
    required this.category,
    required this.urgencyLevel,
    required this.patientLanguage,
  });
}

// NOTE: ttsPhrase resolves 他/她 -> 她 for now since the phrasebook is
// currently scoped to Lola Rosa (female patient). If this phrasebook
// becomes patient-agnostic later, ttsPhrase should be generated per-patient
// at read time instead of hardcoded here.
const phrasebookSeed = [
  // Medical Emergency
  PhrasebookEntry(
    id: 'med_001',
    targetPhrase: '他/她失去意識了',
    ttsPhrase: '她失去意識了',
    targetRomanization: 'Tā/tā shīqù yìshì le',
    caregiverGloss: 'He/she is unconscious',
    category: Category.medicalEmergency,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'med_002',
    targetPhrase: '他/她無法呼吸',
    ttsPhrase: '她無法呼吸',
    targetRomanization: 'Tā/tā wúfǎ hūxī',
    caregiverGloss: "He/she can't breathe",
    category: Category.medicalEmergency,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'med_003',
    targetPhrase: '他/她跌倒了',
    ttsPhrase: '她跌倒了',
    targetRomanization: 'Tā/tā diédǎo le',
    caregiverGloss: 'He/she fell down',
    category: Category.medicalEmergency,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'med_004',
    targetPhrase: '他/她胸口痛',
    ttsPhrase: '她胸口痛',
    targetRomanization: 'Tā/tā xiōngkǒu tòng',
    caregiverGloss: 'He/she has chest pain',
    category: Category.medicalEmergency,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'med_005',
    targetPhrase: '請叫救護車',
    ttsPhrase: '請叫救護車',
    targetRomanization: 'Qǐng jiào jiùhùchē',
    caregiverGloss: 'Please call an ambulance',
    category: Category.medicalEmergency,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'med_006',
    targetPhrase: '他/她在流血',
    ttsPhrase: '她在流血',
    targetRomanization: 'Tā/tā zài liúxuè',
    caregiverGloss: 'He/she is bleeding',
    category: Category.medicalEmergency,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'med_007',
    targetPhrase: '他/她發燒了',
    ttsPhrase: '她發燒了',
    targetRomanization: 'Tā/tā fāshāo le',
    caregiverGloss: 'He/she has a fever',
    category: Category.medicalEmergency,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),

  // Dementia
  PhrasebookEntry(
    id: 'dem_001',
    targetPhrase: '他/她意識混亂',
    ttsPhrase: '她意識混亂',
    targetRomanization: 'Tā/tā yìshì hùnluàn',
    caregiverGloss: 'He/she is confused/disoriented',
    category: Category.dementia,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'dem_002',
    targetPhrase: '他/她走失了',
    ttsPhrase: '她走失了',
    targetRomanization: 'Tā/tā zǒushī le',
    caregiverGloss: 'He/she wandered off / is missing',
    category: Category.dementia,
    urgencyLevel: UrgencyLevel.high,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'dem_003',
    targetPhrase: '他/她不認得我',
    ttsPhrase: '她不認得我',
    targetRomanization: 'Tā/tā bù rènde wǒ',
    caregiverGloss: "He/she doesn't recognize me",
    category: Category.dementia,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'dem_004',
    targetPhrase: '他/她情緒激動',
    ttsPhrase: '她情緒激動',
    targetRomanization: 'Tā/tā qíngxù jīdòng',
    caregiverGloss: 'He/she is agitated/upset',
    category: Category.dementia,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),

  // Medication
  PhrasebookEntry(
    id: 'medc_001',
    targetPhrase: '他/她沒吃藥',
    ttsPhrase: '她沒吃藥',
    targetRomanization: 'Tā/tā méi chī yào',
    caregiverGloss: 'He/she missed his/her medication',
    category: Category.medication,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'medc_002',
    targetPhrase: '他/她在嘔吐',
    ttsPhrase: '她在嘔吐',
    targetRomanization: 'Tā/tā zài ǒutù',
    caregiverGloss: 'He/she is vomiting',
    category: Category.medication,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'medc_003',
    targetPhrase: '他/她不肯吃東西',
    ttsPhrase: '她不肯吃東西',
    targetRomanization: 'Tā/tā bùkěn chī dōngxī',
    caregiverGloss: "He/she won't eat",
    category: Category.medication,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'medc_004',
    targetPhrase: '我需要醫生',
    ttsPhrase: '我需要醫生',
    targetRomanization: 'Wǒ xūyào yīshēng',
    caregiverGloss: 'I need a doctor',
    category: Category.medication,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),

  // Self Advocacy
  PhrasebookEntry(
    id: 'self_001',
    targetPhrase: '請幫幫我',
    ttsPhrase: '請幫幫我',
    targetRomanization: 'Qǐng bāngbang wǒ',
    caregiverGloss: 'I need help, please',
    category: Category.selfAdvocacy,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'self_002',
    targetPhrase: '我不明白',
    ttsPhrase: '我不明白',
    targetRomanization: 'Wǒ bù míngbái',
    caregiverGloss: "I don't understand",
    category: Category.selfAdvocacy,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'self_003',
    targetPhrase: '請說慢一點',
    ttsPhrase: '請說慢一點',
    targetRomanization: 'Qǐng shuō màn yīdiǎn',
    caregiverGloss: 'Please speak slowly',
    category: Category.selfAdvocacy,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
  PhrasebookEntry(
    id: 'self_004',
    targetPhrase: '我身體不舒服',
    ttsPhrase: '我身體不舒服',
    targetRomanization: 'Wǒ shēntǐ bù shūfú',
    caregiverGloss: 'I am not feeling well',
    category: Category.selfAdvocacy,
    urgencyLevel: UrgencyLevel.normal,
    patientLanguage: PatientLanguage.mandarin,
  ),
];
