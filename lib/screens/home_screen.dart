import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../models/playlist.dart';
import '../models/quiz_question.dart' show QuizType;
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<String> _usernames = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addUsernameFromField() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !_usernames.contains(text)) {
      setState(() => _usernames.add(text));
      _controller.clear();
    }
  }

  void _startQuiz() {
    final pendingText = _controller.text.trim();
    if (pendingText.isNotEmpty && !_usernames.contains(pendingText)) {
      setState(() => _usernames.add(pendingText));
      _controller.clear();
    }

    if (_usernames.isEmpty) {
      _formKey.currentState?.validate();
      return;
    }

    final encoded = _usernames.join(',');
    context.go('/loading/$encoded');
  }

  void _showSavePlaylistDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Playlist'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Playlist name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              ref.read(playlistProvider.notifier).addPlaylist(Playlist(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    usernames: List.from(_usernames),
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _sharePlaylist(Playlist playlist) {
    final uri = Uri(
      scheme: 'inaturalistquiz',
      host: 'playlist',
      queryParameters: {
        'name': playlist.name,
        'users': playlist.usernames.join(','),
      },
    );
    Share.share('Check out my iNaturalist quiz playlist!\n$uri');
  }

  @override
  Widget build(BuildContext context) {
    final recentUsernames = ref.watch(recentUsernamesProvider);
    final playlists = ref.watch(playlistProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('iNaturalist Quiz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Progress',
            onPressed: () => context.go('/progress'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.eco,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Test your species knowledge!',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter an iNaturalist username to quiz yourself on their observations.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Quiz type selector
              SegmentedButton<QuizType>(
                segments: const [
                  ButtonSegment(
                    value: QuizType.photoToName,
                    label: Text('Photo'),
                    icon: Icon(Icons.image, size: 18),
                  ),
                  ButtonSegment(
                    value: QuizType.nameToPhoto,
                    label: Text('Name'),
                    icon: Icon(Icons.text_fields, size: 18),
                  ),
                  ButtonSegment(
                    value: QuizType.familyId,
                    label: Text('Family'),
                    icon: Icon(Icons.account_tree, size: 18),
                  ),
                ],
                selected: {ref.watch(settingsProvider).quizType},
                onSelectionChanged: (selected) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateQuizType(selected.first);
                },
              ),
              const SizedBox(height: 24),
              // Username chips
              if (_usernames.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _usernames.map((username) {
                      return Chip(
                        label: Text(username),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() => _usernames.remove(username));
                        },
                      );
                    }).toList(),
                  ),
                ),
              if (_usernames.isNotEmpty) const SizedBox(height: 8),
              // Username text field
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'iNaturalist Username',
                    hintText: 'e.g. kueda',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textInputAction: TextInputAction.go,
                  onFieldSubmitted: (_) {
                    if (_controller.text.trim().isNotEmpty) {
                      _addUsernameFromField();
                    } else {
                      _startQuiz();
                    }
                  },
                  validator: (value) {
                    if (_usernames.isEmpty &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Save as Playlist button
              if (_usernames.length >= 2)
                TextButton.icon(
                  onPressed: _showSavePlaylistDialog,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Save as Playlist'),
                ),
              ElevatedButton.icon(
                onPressed: _startQuiz,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Quiz'),
              ),
              // Recent usernames
              if (recentUsernames.isNotEmpty) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: recentUsernames.map((username) {
                    return ActionChip(
                      label: Text(username),
                      avatar: const Icon(Icons.history, size: 18),
                      onPressed: () {
                        if (!_usernames.contains(username)) {
                          setState(() => _usernames.add(username));
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
              // Saved playlists
              if (playlists.isNotEmpty) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Playlists',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...playlists.map((playlist) => Card(
                      child: ListTile(
                        title: Text(playlist.name),
                        subtitle: Text(playlist.usernames.join(', ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share, size: 20),
                              onPressed: () => _sharePlaylist(playlist),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => ref
                                  .read(playlistProvider.notifier)
                                  .removePlaylist(playlist.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          final encoded = playlist.usernames.join(',');
                          context.go('/loading/$encoded');
                        },
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
