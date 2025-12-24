# アプリ仕様書

## 概要
- 名前: Private Repo Viewer (Flutter)
- 目的: GitHub のプライベートリポジトリ一覧とリポ内容・ファイルを閲覧するための簡易ビューア。
- 対応プラットフォーム: Flutter 対応ターゲット (Android/iOS/Web/Windows/macOS/Linux)。

## 主要画面とフロー
- HomePage: 起動時にトークンを Secure Storage から読み込み。ロード中はスピナー。トークン未保存なら TokenInputPage、保存済みなら RepoListPage へ遷移。
- TokenInputPage: PAT を入力・保存する画面。保存ボタンでバリデーション→保存→ステータス表示。保存中はボタンを無効化・スピナー表示。
- RepoListPage: プライベートリポジトリをリスト表示 (最大 100 件、更新順)。Pull-to-refresh 対応。タップで RepoDetailPage へ。AppBar 下に外部ステータスメッセージ表示可。ログアウトボタンでトークン削除。
- RepoDetailPage: 指定リポのディレクトリ／ファイル一覧を表示。ディレクトリはさらにネスト表示、ファイルは FileViewerPage へ。Pull-to-refresh 対応。
- FileViewerPage: GitHub Contents API でファイルを取得し、Base64 ならデコードして全文を SelectableText で表示。取得失敗時はリトライ付きのエラービュー。
- 共通エラービュー: `_ErrorView` がメッセージとリトライボタンを表示。

## データモデル・ストレージ
- トークンストア: `GitHubTokenStore` 抽象。`SecureTokenStore` は `FlutterSecureStorage` にキー `github_token` で保存。`InMemoryTokenStore` はテスト用途のメモリ実装。
- GitHub データモデル:
  - `GitHubUser`: `login`。
  - `GitHubRepo`: `name`, `owner`, `isPrivate`, `defaultBranch`, `description`, `language`, `updatedAt`。
  - `RepoContent`: `name`, `path`, `type` (`file`|`dir`), `size`, `encoding`, `content`, `downloadUrl`。`decodedContent` で Base64 をデコード。

## ネットワーク/API
- クライアント: `GitHubClient` (`package:http` 使用)。
- 共通ヘッダー: `Accept: application/vnd.github+json`, `User-Agent: ihaveit-app`, `Authorization: Bearer <token>` (設定時)。
- エンドポイント:
  - `/user`: ログインユーザー取得 (`fetchViewer`)。トークン妥当性チェックに使用。
  - `/user/repos`: プライベートリポ一覧取得 (`fetchRepos`)。クエリ `per_page=100`, `sort=updated`, `visibility=private`。
  - `/repos/{owner}/{repo}/contents/{path}?ref=<branch>`: コンテンツ取得 (`fetchContents`)。ファイル時は単一要素リストに整形。
- エラーハンドリング: HTTP 2xx 以外で `GitHubException(statusCode, message)` を送出。API メッセージ抽出に失敗した場合はレスポンスボディをそのまま使用。

## 状態管理・UI動作
- アプリ全体はステートフル Widget で実装し、`FutureBuilder` と `RefreshIndicator` を使用した都度フェッチ型。キャッシュなし。
- トークン入力後は即時 API 呼び出しで妥当性確認し、成功時のみ保存・画面更新。
- サインアウト時にストレージとクライアントのトークンをクリアし、状態メッセージをリセット。

## 既知の制約/注意点
- リポ一覧はページング未対応 (100 件固定)。
- GitHub Contents API の制限に依存: 大容量ファイルやバイナリは内容表示不可、サイズ制約未対処。
- オフラインやレートリミットへのリトライ／バックオフは未実装。
- トークンスコープはユーザーに依存 (`repo` スコープの PAT が必要)。
