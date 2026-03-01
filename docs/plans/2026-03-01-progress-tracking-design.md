# Progress Tracking System Design

## Storage
Single JSON file (`progress.json`) in app documents directory, loaded at startup via Riverpod provider.

## Data Models

### SpeciesRecord
- taxonId, scientificName, commonName
- timesCorrect, timesIncorrect
- lastSeenAt (timestamp)
- photoUrl (thumbnail)

### ProgressData
- Map<int, SpeciesRecord> species (keyed by taxonId)
- totalQuizzesTaken, totalQuestionsAnswered
- currentStreak (consecutive quizzes ≥70%)
- bestStreak
- lastQuizDate

## Recording
At quiz completion, iterate answered questions and update each species record.

## Progress Screen
- Summary header: total quizzes, species seen, accuracy %, streak
- Species list: sorted by accuracy (weakest first default), with thumbnail, name, accuracy bar, times seen
- Sort toggle: weakest / most seen / recently seen
- Mastery badges: red (<50%), orange (50-79%), green (≥80%)

## Connected Features
- Weakest species highlight on results screen
- "Practice weak species" button on progress screen
