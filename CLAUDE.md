# Kalinga

## Tech stack
- Flutter (Android, iOS, Web, Windows)
- Supabase (auth, database, storage)
- Config via `.env` (see `.env.example`; local `.env` gitignored, loaded with `flutter_dotenv`)

## Project description

Kalinga: an AI Care Companion for Migrant Caregivers

### Problem

Taiwan's home-based eldercare system depends on more than 210,000 Southeast Asian migrant caregivers and domestic workers, primarily from Indonesia, the Philippines, and Vietnam (Focus Taiwan, 2026). As of April 2019, migrant workers in Taiwan broke down as 38.4% Indonesian, 31.4% Vietnamese, 21.8% Filipino, and 8.4% Thai and other nationalities (Weng et al., 2021). Most are live-in workers excluded from the Labor Standards Act, meaning they have no guaranteed rest days or hour limits; a June 2025 Ministry of Labor survey found only 65.8% had even one day off per month (Focus Taiwan, 2026).

These caregivers are also chronically underprepared and under-supported for the medical dimension of their work. In a 2022 study, 22% of foreign domestic workers in Taiwan had received no elderly care training before starting their contracts, and 77.9% identified the language barrier as their single biggest workplace difficulty (Wu et al., 2022). Vietnamese caregivers described specific consequences of poor communication where they were being blamed for mistakes they couldn't understand, being unable to relay medical concerns clearly to families, and being unable to communicate at all with Taiwanese Hokkien-speaking elderly residents, since their pre-departure training covers only Mandarin (Wu et al., 2022).

The human cost of this gap is measurable. Among Indonesian domestic workers surveyed in Taiwan, 85.1% reported experiencing sickness while working, but only 48.8% actually sought healthcare and language barriers and inflexible schedules were the main obstacles cited (Weng et al., 2021). Because roughly 94% of Taiwanese who need long-term care receive it at home rather than in an institution (as of a 2017 study cited in home-care research), the migrant caregiver is frequently the only person physically present to notice a decline but has no structured, low-friction way to flag it before it becomes a crisis. This is especially acute in dementia care, a fast-growing subset of home eldercare in Taiwan, where family caregivers report needing far more support and training resources to work effectively alongside migrant care workers (Yen, 2025).

### MVP features

- Chat-based symptom checker in Tagalog/Bisaya/Bahasa Indonesia/Vietnamese, auto-translating and flagging urgency to family and doctor in Mandarin — directly targeting the 77.9% language-barrier bottleneck (Wu et al., 2022)
- Daily voice-log ("how did Grandma sleep, eat, mood today?"), transcribed and turned into a simple trend chart for family/clinic visibility — addressing the health-seeking gap where 85% report sickness but under half seek care (Weng et al., 2021)
- Emergency phrasebook + one-tap call to labor helpline or 119 (INCLUDE OTHER GOV SERVICES)
- Basic med-reminder + dosage photo-recognition, reducing medication errors tied to the training gap (22% of caregivers arrive with no elder-care training; Wu et al., 2022)
- Multi-patient profiles — the caregiver picks who she's logging for (e.g. "Mr. Chen," "Lola Rosa") before any log or check-in, keeping each elder's history, meds, and trends cleanly separated. Every insight, alert, and med-reminder is scoped to the selected profile.
