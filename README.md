# iNaturalist Quiz Builder

A Flutter app that generates species identification quizzes from [iNaturalist](https://www.inaturalist.org/) observations. Enter any iNaturalist username and test your knowledge of the species they've observed.

## Features

- **Photo to Name** — See a photo, pick the species name from four choices
- **Name to Photo** — See a species name, pick the correct photo from four choices
- **Family Identification** — See a photo, identify which taxonomic family it belongs to
- **Multi-user playlists** — Combine observations from multiple users into one quiz
- **Progress tracking** — Track accuracy per species, streaks, and weak areas
- **Practice weak species** — Focus on species you struggle with
- **Deep link sharing** — Share playlists via `inaturalistquiz://` links
- **Configurable settings** — Question count, quality grade filter, answer format, 80+ languages

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- An Android or iOS device/emulator

### Run

```bash
flutter pub get
flutter run
```

### Test

```bash
flutter test
flutter analyze
```

## Architecture

- **State management**: [Riverpod](https://riverpod.dev/) (NotifierProvider pattern)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **API**: [iNaturalist API v1](https://api.inaturalist.org/v1/) (no auth required)
- **Persistence**: SharedPreferences (settings), JSON files (progress, playlists)

### Project structure

```
lib/
  models/         # Data classes (Observation, QuizQuestion, Settings, etc.)
  providers/      # Riverpod state management
  screens/        # Full-page UI widgets
  services/       # API client, quiz generation engine
  widgets/        # Reusable UI components
  data/           # Static data (locale list)
```

## How it works

1. Fetches a user's observations from iNaturalist (up to 500, paginated)
2. Resolves taxonomic ancestry (family/order) via batch taxa lookups
3. Fetches related species from the same families for realistic distractors
4. Generates quiz questions with four choices each
5. Tracks per-species accuracy across sessions

## License

MIT
