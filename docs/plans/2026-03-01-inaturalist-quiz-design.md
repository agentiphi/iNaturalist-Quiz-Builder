# iNaturalist Quiz App — Design Document

**Date:** 2026-03-01
**Platform:** Flutter (Dart)
**Architecture:** Stateless, online-only (Approach A)

---

## Overview

An educational Flutter app that turns any iNaturalist user's observation library into species identification quizzes. The user enters an iNaturalist username, the app fetches their public observations, and generates multiple-choice "Photo → Name" questions using same-family species as distractors.

## Requirements

- No login or backend — enter any iNaturalist username to start
- Quiz format: show observation photo, pick the correct species from 4 choices
- Distractors sourced from the same taxonomic family as the correct answer
- Online-only for v1 — fetch data on demand, no local database
- User-configurable settings for quiz length, display format, etc.

---

## Screens & Navigation

### Flow

```
Home → Loading → Quiz → Results → Home/Quiz
Settings accessible from Home (gear icon)
```

### 1. Home Screen

- Text field to enter an iNaturalist username
- "Start Quiz" button
- Recent usernames list (stored in SharedPreferences) for quick re-selection
- Gear icon in app bar opens Settings

### 2. Loading Screen

- Progress indicator with observation count ("Loading observations... 142 found")
- Validates username exists
- On error, returns to Home with error message

### 3. Quiz Screen

- **App bar:** Score badge (left), progress "7/20" (right), close button
- **Photo area:** Large rounded-corner card (~60% of screen), swipeable for multi-photo observations, dot indicators
- **Answer buttons:** 4 stacked Material buttons — common name (bold) + scientific name (italic), min 48dp height
- **Feedback:** Tap to answer → instant color feedback (green correct, red wrong), other buttons dim, "Next →" slides in
- No timer — learning-focused, no pressure

### 4. Results Screen

- Score display: "15 / 20 correct" with percentage
- Scrollable list of missed questions only (photo thumbnail, user's answer, correct answer)
- Tap missed item to review full photo with species info
- "Try Again" and "New User" buttons

### 5. Settings Screen

| Setting                | Default            | Options                                     |
|------------------------|--------------------|---------------------------------------------|
| Questions per quiz     | 20                 | 5, 10, 20, 30, 50, All                      |
| Quality grade filter   | Research only      | Research, Needs ID, Both                     |
| Answer display format  | Common + Scientific| Common only, Scientific only, Both           |
| Haptic feedback        | On                 | On / Off                                     |
| Photo swipe hints      | On                 | On / Off                                     |

Settings stored in SharedPreferences. Changes take effect on next quiz session.

---

## Data Architecture

### Models

- **Observation** — id, photos (list of URLs), taxon (id, name, commonName, rank, ancestorIds)
- **QuizQuestion** — observation photo URL, correctAnswer (species name), distractors (3 wrong species names), user's selected answer
- **QuizSession** — list of QuizQuestions, current index, score

### API Integration

Two iNaturalist API calls per quiz session:

1. **Fetch observations:**
   ```
   GET /v1/observations?user_id={username}&photos=true&quality_grade=research&per_page=200&order_by=random
   ```
   - `quality_grade=research` for reliable community-verified IDs
   - Paginate with `id_above` for users with 200+ observations

2. **Fetch distractors:**
   ```
   GET /v1/taxa/{ancestor_family_id}?per_page=30
   ```
   - Extract family-level ancestor ID from `taxon.ancestors`
   - Pick 3 random sibling species as wrong answers
   - Batch by unique family to minimize API calls

### Quiz Generation Logic

1. Pick N random observations from fetched pool (N = user's question count setting)
2. For each observation, extract family-level ancestor ID from `taxon.ancestors`
3. Fetch sibling species from that family (batched per unique family)
4. Shuffle 1 correct + 3 distractors into 4 answer slots
5. Fallback: if family has < 3 siblings, climb to order level; if still insufficient, use species from user's other observations

### Rate Limiting

- ~200 observations yield roughly 10-30 unique families
- One taxa API call per unique family — well within iNaturalist's ~1 req/sec guideline
- Respect 200 per_page maximum

---

## Error Handling & Edge Cases

### Network Errors

- API failure → snackbar "Couldn't reach iNaturalist. Check your connection." + retry button
- 15-second timeout per request → same retry UX
- Image load failure → placeholder icon (leaf/camera) + "Photo unavailable", question still playable

### User Input Edge Cases

- Username doesn't exist → "No user found with that name", return to Home
- Zero photo observations → "This user has no photo observations to quiz on"
- Fewer observations than question count → use all available, inform user
- Only 1 species observed → "Need observations of at least 2 species to generate a quiz"

### Distractor Edge Cases

- Family has < 3 sibling species → climb to order level
- No usable siblings at any level (extremely rare) → pull from user's other observations
- Duplicate species across questions allowed; distractors always distinct from correct answer within a question

### Quiz State

- App closed mid-quiz → session lost, starts fresh (acceptable for v1)
- Back button during quiz → confirm dialog: "Quit quiz? Progress will be lost."

---

## UI/UX Details

- Material Design 3 with green primary palette (nature theme)
- Shimmer placeholders while photos load
- Hero animation on photo from quiz → review
- Haptic feedback on answer tap (configurable)
- Large tap targets, accessibility-friendly contrast ratios

---

## Tech Stack

- **Framework:** Flutter
- **State management:** Provider or Riverpod (TBD in implementation plan)
- **HTTP client:** `http` or `dio` package
- **Image loading:** `cached_network_image`
- **Local storage:** `shared_preferences` (settings + recent usernames)
- **No backend, no database, no authentication**
