# Quiz Types + Playlists — Design Document

**Date:** 2026-03-05

---

## Overview

Extend the iNaturalist Quiz app with two new quiz formats (Name-to-Photo, Family ID) and a playlist system that combines observations from multiple iNaturalist users. Playlists can be saved locally and shared via deep links.

---

## Quiz Type System

### Types

| Type | Prompt | Choices | Distractor Source |
|------|--------|---------|-------------------|
| `photoToName` (existing) | Photo | 4 species names (text) | Same-family species from taxa API |
| `nameToPhoto` (new) | Species name | 4 photos (2x2 grid) | Photos from same-family species via taxa API `default_photo` |
| `familyId` (new) | Photo | 4 family names (text) | Other families from user's observations (same iconic taxon preferred) |

### Model Changes

- `QuizType` enum: `photoToName`, `nameToPhoto`, `familyId`
- `QuizQuestion`: add `QuizType type` field
- `AnswerChoice`: add optional `String? photoUrl` (used for nameToPhoto choices)
- `TaxonSummary`: add optional `String? photoUrl` parsed from taxa API `default_photo.medium_url`

### Quiz Engine Changes

- `generateQuestions()`: accept a `QuizType` parameter
- For `nameToPhoto`: build choices with photos from TaxonSummary (correct species photo from observation, distractor photos from taxa API)
- For `familyId`: correct answer is the observation's family name, distractors are other family names from the user's observations (same iconic taxon preferred)
- Existing `photoToName` logic unchanged

### UI Changes

- Quiz screen checks `question.type` and renders either text buttons or a 2x2 photo grid
- Name-to-Photo prompt: display species name prominently instead of a photo
- Family ID: same layout as Photo-to-Name but with family names as choices

---

## Playlist System

### Model

```dart
class Playlist {
  final String id;           // UUID
  final String name;
  final List<String> usernames;
  final DateTime createdAt;
}
```

Stored as JSON array in app documents directory (`playlists.json`), similar to progress.dart.

### Home Screen Changes

- Multi-username input: text field with chip display. Type username, press Enter/comma to add as chip. Remove chips with X button.
- Single username still works as before (backward compatible)
- Quiz type selector: segmented button below username input (Photo-to-Name, Name-to-Photo, Family ID)
- "Save as Playlist" button appears when 2+ usernames entered
- Saved playlists section below recent users: tap to launch, long-press to edit/delete

### Loading Screen Changes

- Accept `List<String>` usernames instead of single string
- Fetch observations for each username sequentially
- Show progress: "Loading user 2/3..."
- Merge all observations into one pool, then generate quiz as normal

### Storage

- `PlaylistProvider` (Notifier) manages playlist CRUD
- Persisted to `playlists.json` in app documents
- Follows same pattern as ProgressNotifier (async load with completer)

---

## Sharing

### Deep Link Format

```
inaturalistquiz://playlist?name=Local%20Birders&users=kueda,loarie
```

### Implementation

- Android: intent filter in `AndroidManifest.xml` for `inaturalistquiz://` scheme
- Flutter: handle incoming deep links via `GoRouter`'s redirect or initial link handling
- Share button on saved playlists opens system share sheet with the deep link URL
- Receiving the link opens the app, parses usernames, and prompts user to save the playlist
- No backend required — all data encoded in the URL

---

## Navigation Changes

- Home screen: quiz type selector + multi-user input + saved playlists
- Loading screen: multi-username support with per-user progress
- `/playlists` route not needed — playlists managed inline on home screen
- Quiz and Results screens unchanged (work off provider state)
- New deep link handler route for incoming playlist links

---

## Settings Changes

- Add "Default quiz type" setting (defaults to photoToName)
- Existing settings (questions per quiz, quality grade, etc.) apply to all quiz types
