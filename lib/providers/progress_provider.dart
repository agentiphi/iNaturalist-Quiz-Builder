import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/progress.dart';
import '../models/quiz_session.dart';

class ProgressNotifier extends Notifier<ProgressData> {
  Completer<void>? _loadCompleter;

  @override
  ProgressData build() {
    _loadCompleter = Completer<void>();
    _loadFromFile();
    return ProgressData();
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/progress.json');
  }

  Future<void> _loadFromFile() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final contents = await file.readAsString();
        state = ProgressData.fromJson(
          jsonDecode(contents) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // If file is corrupted, start fresh
    } finally {
      _loadCompleter?.complete();
    }
  }

  Future<void> _saveToFile() async {
    final file = await _file;
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  Future<void> recordQuizCompletion(QuizSession session) async {
    // Wait for any pending file load to complete first
    await _loadCompleter?.future;

    final results = session.questions
        .where((q) => q.isAnswered)
        .map((q) => QuizQuestionResult(
              taxonId: q.taxonId,
              scientificName: q.correctScientificName,
              commonName: q.correctCommonName,
              photoUrl: q.photoUrl,
              correct: q.isCorrect,
            ))
        .toList();

    // Create a new ProgressData instance so Riverpod detects the change
    state = state.withQuizResult(
      results: results,
      scorePercentage: session.scorePercentage,
    );
    await _saveToFile();
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressData>(
  ProgressNotifier.new,
);
