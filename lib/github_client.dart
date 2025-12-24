import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubClient {
  GitHubClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _token;

  void updateToken(String? token) {
    _token = token?.trim();
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'ihaveit-app',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${_token!}';
    }
    return headers;
  }

  Future<GitHubUser> fetchViewer() async {
    final uri = Uri.parse('https://api.github.com/user');
    final response = await _httpClient.get(uri, headers: _headers());
    _throwIfError(response);
    return GitHubUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<GitHubRepo>> fetchRepos() async {
    final uri = Uri.https(
      'api.github.com',
      '/user/repos',
      <String, String>{
        'per_page': '100',
        'sort': 'updated',
        'visibility': 'private',
      },
    );
    final response = await _httpClient.get(uri, headers: _headers());
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((repo) => GitHubRepo.fromJson(repo as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<RepoContent>> fetchContents({
    required String owner,
    required String repo,
    String path = '',
    String? ref,
  }) async {
    final encodedPath = path.isEmpty ? '' : '/$path';
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/contents$encodedPath',
      ref == null ? null : <String, String>{'ref': ref},
    );
    final response = await _httpClient.get(uri, headers: _headers());
    _throwIfError(response);
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic> && body['type'] == 'file') {
      return [RepoContent.fromJson(body)];
    }
    if (body is List<dynamic>) {
      return body.map((item) => RepoContent.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw const FormatException('Unexpected content payload');
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw GitHubException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(response.body),
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // ignore parse errors and fall back to raw body.
    }
    return body;
  }
}

class GitHubRepo {
  GitHubRepo({
    required this.name,
    required this.owner,
    required this.isPrivate,
    required this.defaultBranch,
    required this.description,
    required this.language,
    required this.updatedAt,
  });

  final String name;
  final String owner;
  final bool isPrivate;
  final String defaultBranch;
  final String? description;
  final String? language;
  final DateTime? updatedAt;

  factory GitHubRepo.fromJson(Map<String, dynamic> json) {
    return GitHubRepo(
      name: json['name'] as String,
      owner: (json['owner'] as Map<String, dynamic>?)?['login'] as String? ?? '',
      isPrivate: json['private'] as bool? ?? false,
      defaultBranch: json['default_branch'] as String? ?? 'main',
      description: json['description'] as String?,
      language: json['language'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }
}

class RepoContent {
  RepoContent({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.encoding,
    required this.content,
    required this.downloadUrl,
  });

  final String name;
  final String path;
  final String type; // "file" | "dir"
  final int size;
  final String? encoding;
  final String? content;
  final String? downloadUrl;

  factory RepoContent.fromJson(Map<String, dynamic> json) {
    return RepoContent(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
      size: json['size'] as int? ?? 0,
      encoding: json['encoding'] as String?,
      content: json['content'] as String?,
      downloadUrl: json['download_url'] as String?,
    );
  }

  bool get isDirectory => type == 'dir';

  String? get decodedContent {
    if (content == null || encoding != 'base64') {
      return content;
    }
    final normalized = content!.replaceAll('\n', '');
    return utf8.decode(base64.decode(normalized));
  }
}

class GitHubUser {
  GitHubUser({required this.login});

  final String login;

  factory GitHubUser.fromJson(Map<String, dynamic> json) {
    return GitHubUser(login: json['login'] as String? ?? '');
  }
}

class GitHubException implements Exception {
  const GitHubException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'GitHubException($statusCode): $message';
}
