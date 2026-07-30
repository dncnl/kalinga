# Feature: Household join codes (family/caregiver) + invite-flow authz fixes

Replaces the email-based invite idea with a simpler join-code model: a
caregiver generates a short code, shares it with a family member or another
caregiver through whatever channel they want (text, verbally, WhatsApp —
not built or sent by this app), and the recipient enters that code
**after** registering, when the app asks "are you a family member or a
caretaker?" No email infrastructure, no deep-link/universal-link problem to
solve.

## Why this replaced the email-invite direction

An earlier pass on this branch built full email delivery (Nodemailer +
SendGrid) for the pre-existing token-based invite flow. Before shipping
that, a security review of the same invite flow surfaced three
authorization gaps (below). Fixing those didn't require email at all, and
once the accept step moved to "type a code in during onboarding" instead of
"click a link from an email," the whole justification for email delivery,
and for tying a code to one specific invitee email, went away. Decision:
drop the email work entirely, keep the flow reachable only through the
onboarding "family or caretaker?" screen. All Nodemailer/SendGrid/mailer.js
code has been removed from this branch.

## Design decisions made this session

1. **Join code is a pure shared secret — no email tie-in.** The caregiver
   picks a role (`family`/`caregiver`) and gets a code back; nothing about
   *who* the code is for is recorded or checked. Whoever registers and
   types a valid, unexpired, not-yet-used code claims that role. This is
   the same trust model as a classroom/workspace join code. Rejected
   alternative: requiring the family member to register with a
   caregiver-declared email and checking it at accept time — more secure
   against a leaked code, but adds friction (the family member has to know
   to use one specific email) that doesn't fit "ask after registration."
2. **Short human-typeable code, not a long token.** Was a 48-char hex
   string (fine when pasted from a link, painful typed from memory or off
   a phone screen). Now an 8-character code from a 31-symbol alphabet
   (`ABCDEFGHJKMNPQRSTUVWXYZ23456789` — excludes 0/O and 1/I/L to avoid
   misreads), case-insensitive on entry. ~39.6 bits of entropy
   (31^8 ≈ 852B combinations) — combined with single-use + 7-day expiry,
   that's not brute-forceable at any practical request rate, so no
   additional rate-limiting was added for this.

## Gaps found in the pre-existing invite flow and fixed

1. **No role check on invite creation** — any active household member
   (including a `family`-role member who was themselves invited) could
   mint a `caregiver` invite with a care-recipient assignment attached —
   privilege escalation. Fixed: `authorizeHousehold.js` adds
   `canCreateInvites`, gating creation to `householdAdmin`/`caregiver`
   roles. (`isHouseholdMember` unchanged, still used by every other
   household-scoped route.)
2. **The token hash was decorative** — the invitation doc stored a
   `tokenHash`, but the lookup doc (`inviteTokens/{token}`) used the *raw*
   token as its own document ID right next to it, so the hash protected
   nothing (a Firestore data leak would have handed over live, usable
   tokens). Fixed: `inviteTokens` is now keyed by the code's hash; the raw
   code is never persisted anywhere, only ever held in memory and wherever
   the caregiver shares it.
3. ~~Accept never checked who's accepting~~ — this was fixed earlier in
   this session (checking the accepting user's email against the invite),
   then **deliberately reverted** once the design moved to a pure join-code
   model (decision #1 above) — there's no invitee email to check against
   anymore, by design.

Not changed: `GET /invites/:code` is still unauthenticated by necessity (an
onboarding screen may want to preview "who invited you, for whom" before
the user commits to entering it as their final answer) and returns
inviter/patient names to anyone holding a valid code. No email is returned
now (there isn't one).

## What's backend-only vs. still needed on mobile

Backend (this branch): `POST /households/:householdId/invitations` (now
just `{ intendedRole, careRecipientId? }` → `{ code }`), `GET /invites/:code`
(preview), `POST /invites/:code/accept` (claim, post-registration). All
three already existed in some form; this branch changed their shape and
closed the two authz gaps above.

**Not built here, flagged for whoever picks up mobile next:**
- The actual "are you a family member or a caretaker?" onboarding screen
  and its branch into either `POST /households/bootstrap` (caretaker) or a
  code-input field calling the two invite endpoints above (family member).
- `apps/mobile/lib/services/invite_service.dart`, `invite_sheet.dart`, and
  `family_register_page.dart` all still assume the **old** contract
  (`invitedEmail` required at creation, `email` in the GET response,
  email-locked registration form, `/invite/:token` deep-link route) and
  will need to be reworked, not just re-pointed, to match this new
  contract. They have not been touched in this branch.

## Progress

- [x] `authorizeHousehold.js`: `canCreateInvites` (householdAdmin/caregiver
      only).
- [x] `invites.js`: role-gated creation, short 8-char join code (no email),
      hashed-code-keyed lookup doc, no identity check on accept (by
      design).
- [x] Tests: `invites.test.js` rewritten for the new contract (code format,
      no invitedEmail, `/invites/:code` naming, an explicit test asserting
      any authenticated uid can accept — documenting the join-code trust
      model rather than accidentally regressing it later);
      `authorizeHousehold.test.js` covers `canCreateInvites` for
      no-membership/family/caregiver/householdAdmin. Full suite:
      130/133 passing — the 3 failures are pre-existing OpenRouter
      rate-limit flakes in `extractObservation`/`observations-process`
      tests, unrelated to this branch.
- [ ] Mobile onboarding screen + rewired `InviteService`/`invite_sheet.dart`/
      `family_register_page.dart` — not started, see above.
- [ ] Live test against real Firebase — not done in this environment.
