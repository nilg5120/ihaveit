import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'github_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key, GitHubClient? client, GitHubTokenStore? tokenStore})
      : _client = client ?? GitHubClient(),
        _tokenStore = tokenStore ?? const SecureTokenStore();

  final GitHubClient _client;
  final GitHubTokenStore _tokenStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Private Repo Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomePage(client: _client, tokenStore: _tokenStore),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.client, required this.tokenStore});

  final GitHubClient client;
  final GitHubTokenStore tokenStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _token;
  bool _loadingToken = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _hydrateToken();
  }

  Future<void> _hydrateToken() async {
    final stored = await widget.tokenStore.readToken();
    if (!mounted) return;
    if (stored != null && stored.isNotEmpty) {
      widget.client.updateToken(stored);
      setState(() => _token = stored);
    }
    setState(() => _loadingToken = false);
  }

  Future<void> _saveToken(String token) async {
    setState(() {
      _statusMessage = 'Validating token...';
    });
    try {
      widget.client.updateToken(token);
      await widget.client.fetchViewer();
      await widget.tokenStore.writeToken(token);
      if (!mounted) return;
      setState(() {
        _token = token;
        _statusMessage = 'Authenticated successfully';
      });
    } on GitHubException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Authentication error: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Failed to save token: $error');
    }
  }

  Future<void> _signOut() async {
    await widget.tokenStore.clear();
    widget.client.updateToken(null);
    if (!mounted) return;
    setState(() {
      _token = null;
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingToken) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_token == null) {
      return TokenInputPage(
        onSave: _saveToken,
        statusMessage: _statusMessage,
      );
    }
    return RepoListPage(
      client: widget.client,
      tokenStore: widget.tokenStore,
      onSignOut: _signOut,
      statusMessage: _statusMessage,
    );
  }
}

class TokenInputPage extends StatefulWidget {
  const TokenInputPage({super.key, required this.onSave, this.statusMessage});

  final Future<void> Function(String token) onSave;
  final String? statusMessage;

  @override
  State<TokenInputPage> createState() => _TokenInputPageState();
}

class _TokenInputPageState extends State<TokenInputPage> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final token = _controller.text.trim();
    if (token.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(token);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter GitHub token')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To browse private repositories, store a GitHub Personal Access Token with repo scope.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token',
                border: OutlineInputBorder(),
              ),
              enabled: !_saving,
              obscureText: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _handleSave,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock),
                label: const Text('Save & validate'),
              ),
            ),
            if (widget.statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(widget.statusMessage!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class RepoListPage extends StatefulWidget {
  const RepoListPage({
    super.key,
    required this.client,
    required this.tokenStore,
    required this.onSignOut,
    this.statusMessage,
  });

  final GitHubClient client;
  final GitHubTokenStore tokenStore;
  final Future<void> Function() onSignOut;
  final String? statusMessage;

  @override
  State<RepoListPage> createState() => _RepoListPageState();
}

class _RepoListPageState extends State<RepoListPage> {
  late Future<List<GitHubRepo>> _reposFuture;

  @override
  void initState() {
    super.initState();
    _reposFuture = widget.client.fetchRepos();
  }

  Future<void> _refresh() async {
    setState(() {
      _reposFuture = widget.client.fetchRepos();
    });
    await _reposFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Private Repos'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              widget.onSignOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: widget.statusMessage == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.statusMessage!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<GitHubRepo>>(
          future: _reposFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: 'Failed to load repositories: ${snapshot.error}',
                onRetry: _refresh,
              );
            }
            final repos = snapshot.data ?? [];
            if (repos.isEmpty) {
              return const Center(child: Text('No private repositories found'));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: repos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final repo = repos[index];
                return ListTile(
                  title: Text(repo.name),
                  subtitle: Text(repo.description ?? 'No description'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (repo.isPrivate)
                        const Chip(
                          label: Text('private'),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (repo.language != null) Text(repo.language!),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RepoDetailPage(
                          repo: repo,
                          client: widget.client,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class RepoDetailPage extends StatefulWidget {
  const RepoDetailPage({super.key, required this.repo, required this.client, this.path = ''});

  final GitHubRepo repo;
  final GitHubClient client;
  final String path;

  @override
  State<RepoDetailPage> createState() => _RepoDetailPageState();
}

class _RepoDetailPageState extends State<RepoDetailPage> {
  late Future<List<RepoContent>> _contentsFuture;

  @override
  void initState() {
    super.initState();
    _contentsFuture = _load();
  }

  Future<List<RepoContent>> _load() {
    return widget.client.fetchContents(
      owner: widget.repo.owner,
      repo: widget.repo.name,
      path: widget.path,
      ref: widget.repo.defaultBranch,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _contentsFuture = _load();
    });
    await _contentsFuture;
  }

  String _childPath(String child) {
    if (widget.path.isEmpty) return child;
    return '${widget.path}/$child';
  }

  @override
  Widget build(BuildContext context) {
    final titlePath = widget.path.isEmpty ? widget.repo.name : '${widget.repo.name}/${widget.path}';
    return Scaffold(
      appBar: AppBar(title: Text(titlePath)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<RepoContent>>(
          future: _contentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: 'Failed to load content: ${snapshot.error}',
                onRetry: _refresh,
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('No content at this path'));
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(item.isDirectory ? Icons.folder : Icons.insert_drive_file),
                  title: Text(item.name),
                  subtitle: Text(item.isDirectory ? 'Directory' : 'File - ${item.size} bytes'),
                  onTap: () {
                    if (item.isDirectory) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RepoDetailPage(
                            repo: widget.repo,
                            client: widget.client,
                            path: _childPath(item.name),
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FileViewerPage(
                            repo: widget.repo,
                            client: widget.client,
                            path: _childPath(item.name),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class FileViewerPage extends StatefulWidget {
  const FileViewerPage({
    super.key,
    required this.repo,
    required this.client,
    required this.path,
  });

  final GitHubRepo repo;
  final GitHubClient client;
  final String path;

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  late Future<RepoContent> _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = _loadFile();
  }

  Future<RepoContent> _loadFile() async {
    final contents = await widget.client.fetchContents(
      owner: widget.repo.owner,
      repo: widget.repo.name,
      path: widget.path,
      ref: widget.repo.defaultBranch,
    );
    if (contents.isEmpty) {
      throw StateError('No content returned');
    }
    return contents.first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoContent>(
      future: _fileFuture,
      builder: (context, snapshot) {
        final actions = <Widget>[];
        if (snapshot.hasData) {
          final content = snapshot.data!;
          final canEdit = content.isFile && content.decodedContent != null;
          if (canEdit) {
            actions.add(
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _openEditor(content),
                icon: const Icon(Icons.edit),
              ),
            );
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.path),
            actions: actions,
          ),
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorView(
                  message: 'Failed to load file: ${snapshot.error}',
                  onRetry: () async {
                    setState(() {
                      _fileFuture = _loadFile();
                    });
                  },
                );
              }
              final content = snapshot.data;
              if (content == null) {
                return const Center(child: Text('File not found'));
              }
              final decoded = content.decodedContent ?? 'This file cannot be displayed.';
              return Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: SelectableText(decoded),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openEditor(RepoContent content) async {
    final updated = await Navigator.of(context).push<RepoContent>(
      MaterialPageRoute(
        builder: (_) => FileEditorPage(
          repo: widget.repo,
          client: widget.client,
          path: widget.path,
          content: content,
        ),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        _fileFuture = Future.value(updated);
      });
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }
}

class FileEditorPage extends StatefulWidget {
  const FileEditorPage({
    super.key,
    required this.repo,
    required this.client,
    required this.path,
    required this.content,
  });

  final GitHubRepo repo;
  final GitHubClient client;
  final String path;
  final RepoContent content;

  @override
  State<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends State<FileEditorPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.content.decodedContent ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.client.updateFile(
        owner: widget.repo.owner,
        repo: widget.repo.name,
        path: widget.path,
        content: _controller.text,
        sha: widget.content.sha,
        branch: widget.repo.defaultBranch,
        message: 'Update ${widget.path}',
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.path}'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText: 'Edit file content',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                enabled: !_saving,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

abstract class GitHubTokenStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> clear();
}

class SecureTokenStore implements GitHubTokenStore {
  const SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'github_token';

  @override
  Future<void> clear() => _storage.delete(key: _tokenKey);

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) => _storage.write(key: _tokenKey, value: token);
}

class InMemoryTokenStore implements GitHubTokenStore {
  String? _token;

  @override
  Future<void> clear() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }
}
