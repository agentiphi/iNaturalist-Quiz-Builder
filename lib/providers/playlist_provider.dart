import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';

class PlaylistNotifier extends Notifier<List<Playlist>> {
  @override
  List<Playlist> build() {
    _loadFromFile();
    return [];
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/playlists.json');
  }

  Future<void> _loadFromFile() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final list = jsonDecode(contents) as List<dynamic>;
        state = list
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // If file is corrupted, start fresh
    }
  }

  Future<void> _saveToFile() async {
    final file = await _file;
    await file.writeAsString(
      jsonEncode(state.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> addPlaylist(Playlist playlist) async {
    state = [...state, playlist];
    await _saveToFile();
  }

  Future<void> removePlaylist(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _saveToFile();
  }

  Future<void> updatePlaylist(Playlist updated) async {
    state = state.map((p) => p.id == updated.id ? updated : p).toList();
    await _saveToFile();
  }
}

final playlistProvider = NotifierProvider<PlaylistNotifier, List<Playlist>>(
  PlaylistNotifier.new,
);
