// Deterministic, non-authoritative concern nudge for free-text chat.
//
// This is NOT urgency scoring — it never decides urgency and nothing here
// is stored as a safety assessment on its own. It only decides whether to
// show the caregiver a banner suggesting the tap-based triage
// (symptomTriage.js) or 119, for the same reason that file gives for never
// letting a model decide: a false "that sounds fine" here is worse than an
// unnecessary nudge. So the check is a plain keyword match, not an LLM call.
//
// Keyword lists are short and deliberately mirror symptomTriage.js's six
// categories — not a translation-quality effort, just enough recall to
// catch an obviously-described emergency and point at the real flow.
const KEYWORDS = {
  breathing: [
    'cant breathe', "can't breathe", 'hard to breathe', 'difficulty breathing', 'gasping', 'short of breath',
    'hirap huminga', 'di makahinga', // fil
    'lisod ginhawa', 'dili maka-ginhawa', // ceb
    'sesak napas', 'susah bernapas', // id
    'khó thở', 'không thở được', // vi
  ],
  chestPain: [
    'chest pain', 'chest hurts', 'tightness in chest',
    'masakit ang dibdib', 'sumasakit ang dibdib', // fil
    'sakit sa dughan', // ceb
    'sakit dada', 'nyeri dada', // id
    'đau ngực', 'đau tức ngực', // vi
  ],
  fall: [
    'fell down', 'she fell', 'he fell', 'fell and',
    'nahulog', 'natumba', // fil
    'nahulog siya', 'natumba siya', // ceb
    'jatuh', 'terjatuh', // id
    'bị ngã', 'té ngã', // vi
  ],
  confusion: [
    'very confused', 'not making sense', 'cant recognize', "can't recognize", 'face drooping', 'slurred speech',
    'nalilito', 'hindi makakilala', // fil
    'nalibog', // ceb
    'bingung', 'linglung', // id
    'lú lẫn', 'không nhận ra', // vi
  ],
  fever: [
    'very hot', 'high fever', 'burning up', 'hard to wake',
    'lagnat', 'mataas ang lagnat', // fil
    'hilanat', // ceb
    'demam tinggi', 'panas tinggi', // id
    'sốt cao', // vi
  ],
  notEating: [
    'not eating', 'wont eat', "won't eat", 'not drinking', 'refusing food',
    'ayaw kumain', 'hindi kumakain', // fil
    'dili mokaon', // ceb
    'tidak mau makan', 'tidak mau minum', // id
    'không chịu ăn', 'không ăn', // vi
  ],
};

// Same labels as symptomTriage.js so a matched key can drop straight into
// the tap-based flow's `?symptom=` entry point without a lookup table.
const LABELS = {
  breathing: 'Hard to breathe',
  chestPain: 'Chest pain',
  fall: 'She fell down',
  confusion: 'More confused than usual',
  fever: 'Fever / very hot',
  notEating: 'Not eating or drinking',
};

const CATEGORIES = {
  breathing: 'breathing',
  chestPain: 'pain',
  fall: 'fall',
  confusion: 'behavior',
  fever: 'vitalSigns',
  notEating: 'appetite',
};

// First match wins — order lists breathing/chestPain/fall (the ones with
// the shortest path to 119) ahead of the rest.
const ORDER = ['breathing', 'chestPain', 'fall', 'confusion', 'fever', 'notEating'];

function detectConcern(text) {
  if (!text || typeof text !== 'string') return null;
  const lower = text.toLowerCase();

  for (const symptomKey of ORDER) {
    if (KEYWORDS[symptomKey].some((phrase) => lower.includes(phrase))) {
      return { symptomKey, label: LABELS[symptomKey], category: CATEGORIES[symptomKey] };
    }
  }
  return null;
}

module.exports = { detectConcern, KEYWORDS, LABELS, CATEGORIES };
