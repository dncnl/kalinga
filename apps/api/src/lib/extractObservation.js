const Anthropic = require('@anthropic-ai/sdk');

const client = new Anthropic();

const OBSERVATION_CATEGORIES = [
  'appetite', 'hydration', 'sleep', 'mood', 'behavior', 'mobility', 'pain',
  'elimination', 'medication', 'vitalSigns', 'skin', 'breathing', 'fall', 'other',
];

const EXTRACT_TOOL = {
  name: 'record_observation',
  description: 'Record structured details extracted from a caregiver\'s voice log about an elder.',
  input_schema: {
    type: 'object',
    properties: {
      categories: {
        type: 'array',
        items: { type: 'string', enum: OBSERVATION_CATEGORIES },
        description: 'Which aspects of care this note touches on.',
      },
      comparisonToUsual: {
        type: 'string',
        enum: ['better', 'same', 'worse', 'unknown'],
        description: "How the elder's condition compares to their usual baseline.",
      },
      structuredObservation: {
        type: 'object',
        properties: {
          summary: { type: 'string' },
          sleep: { type: ['string', 'null'] },
          appetite: { type: ['string', 'null'] },
          mood: { type: ['string', 'null'] },
        },
        required: ['summary'],
      },
      safetyAssessment: {
        type: 'object',
        properties: {
          concernLevel: { type: 'string', enum: ['none', 'low', 'medium', 'high'] },
          concerns: { type: 'array', items: { type: 'string' } },
          recommendFollowUp: { type: 'boolean' },
        },
        required: ['concernLevel', 'concerns', 'recommendFollowUp'],
      },
    },
    required: ['categories', 'comparisonToUsual', 'structuredObservation', 'safetyAssessment'],
  },
};

// Takes the caregiver's original-language transcript (not the translation —
// extraction should work off what they actually said) and pulls out the
// fields ObservationDocument needs.
async function extractObservation({ transcript }) {
  const response = await client.messages.create({
    model: 'claude-sonnet-5',
    max_tokens: 1024,
    tools: [EXTRACT_TOOL],
    tool_choice: { type: 'tool', name: 'record_observation' },
    messages: [
      {
        role: 'user',
        content: `A migrant caregiver recorded this voice note about the elder they care for. Extract structured details. Flag any safety concerns (e.g. falls, refusing food/water, medication issues, sudden behavior change) even if the caregiver didn't call them out explicitly.\n\nTranscript:\n"""\n${transcript}\n"""`,
      },
    ],
  });

  const toolUse = response.content.find((block) => block.type === 'tool_use');
  if (!toolUse) {
    throw new Error('Model did not return structured observation data');
  }

  return toolUse.input;
}

module.exports = { extractObservation, OBSERVATION_CATEGORIES, client };
