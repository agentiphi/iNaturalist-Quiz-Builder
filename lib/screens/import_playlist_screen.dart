import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/playlist.dart';
import '../providers/playlist_provider.dart';

class ImportPlaylistScreen extends ConsumerWidget {
  final String name;
  final List<String> usernames;

  const ImportPlaylistScreen({
    super.key,
    required this.name,
    required this.usernames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Import Playlist')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.playlist_add_check,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${usernames.length} users: ${usernames.join(", ")}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(playlistProvider.notifier).addPlaylist(Playlist(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        usernames: usernames,
                      ));
                  context.go('/');
                },
                icon: const Icon(Icons.save),
                label: const Text('Save & Go Home'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final encoded = usernames.join(',');
                  context.go('/loading/$encoded');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Quiz Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
