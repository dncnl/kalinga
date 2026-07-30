const { z } = require('zod');

const registerSchema = z.object({
  displayName: z.string().min(1, 'Display name is required').max(100, 'Display name must not exceed 100 characters'),
  householdName: z.string().min(1, 'Household name is required').max(100, 'Household name must not exceed 100 characters'),
});

module.exports = {
  registerSchema
};
