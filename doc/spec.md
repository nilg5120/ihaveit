# アプリ要件定義書 v2

## 1. 目的
- GitHub の private repository を、安全に閲覧・更新するためのクライアントを提供する。
- Flutter で複数プラットフォームに同一の操作体験を提供する。

## 2. 対象ユーザー
- 自分の GitHub private repository を日常的に参照・軽微編集したい開発者。

## 3. スコープ
### 3.1 MVP に含める
- GitHub Personal Access Token (PAT) の入力、検証、保存、削除。
- 認証済みユーザーとして private repository 一覧を取得、表示。
- repository 内のディレクトリ/ファイル一覧を表示。
- テキストファイル内容の表示。
- テキストファイル内容の編集・保存（GitHub Contents API 経由）。
- API エラー時のメッセージ表示と再試行。

### 3.2 MVP に含めない
- Pull Request 作成。
- ブランチ作成/切替。
- 差分比較表示。
- マージ競合解決。
- リポジトリ横断の高度検索。

## 4. ユースケース
1. ユーザーは PAT を入力して保存し、認証に成功する。
2. ユーザーは private repository 一覧を更新日時順で閲覧する。
3. ユーザーは repository を開き、ディレクトリ階層を辿ってファイルを開く。
4. ユーザーはテキストファイルを編集し、保存して GitHub 上に反映する。
5. ユーザーはログアウトして保存済みトークンを削除する。

## 5. 機能要件
### FR-01 認証トークン管理
- PAT を入力できること。
- 保存前に `/user` API で検証すること。
- 有効なトークンのみ永続化すること。
- トークンを明示的に削除できること。

### FR-02 repository 一覧表示
- `/user/repos` から private repository を取得すること。
- 最大 100 件、更新日時順で取得すること。
- 一覧は pull-to-refresh で再取得できること。

### FR-03 repository 内容表示
- `/repos/{owner}/{repo}/contents/{path}` から階層表示できること。
- ディレクトリは遷移、ファイルは内容表示に遷移すること。

### FR-04 ファイル表示
- Base64 エンコードされたテキストをデコードして表示できること。
- 取得失敗時はエラー表示とリトライを提供すること。

### FR-05 ファイル編集・保存
- テキストファイルを編集できること。
- 保存時に Contents API の PUT を使い、`sha` と `branch` を指定すること。
- 保存成功時は更新後の内容を画面に反映すること。

### FR-06 エラーハンドリング
- HTTP ステータス 2xx 以外はエラーとして扱うこと。
- API の `message` がある場合は優先表示すること。
- 各画面でリトライ可能であること。

## 6. 非機能要件
### NFR-01 セキュリティ
- トークンは `flutter_secure_storage` に保存すること。
- 通信は GitHub API (HTTPS) を利用すること。
- トークン文字列をログ出力しないこと。

### NFR-02 可用性・操作性
- 読み込み中はローディング表示を行うこと。
- 通信失敗時にユーザーが復帰可能な UI（再試行）を提供すること。

### NFR-03 保守性
- API 呼び出し処理をクライアントクラスに集約すること。
- モデルクラスを明示し、JSON 変換責務を分離すること。

## 7. 外部インターフェース
### 7.1 利用 API
- `GET /user`
- `GET /user/repos?per_page=100&sort=updated&visibility=private`
- `GET /repos/{owner}/{repo}/contents/{path}?ref={branch}`
- `PUT /repos/{owner}/{repo}/contents/{path}`

### 7.2 HTTP ヘッダー
- `Accept: application/vnd.github+json`
- `User-Agent: ihaveit-app`
- `Authorization: Bearer <token>`（認証時）

## 8. データ要件
### 8.1 GitHubRepo
- `name`
- `owner`
- `isPrivate`
- `defaultBranch`
- `description`
- `language`
- `updatedAt`

### 8.2 RepoContent
- `name`
- `path`
- `type` (`file` / `dir`)
- `size`
- `sha`
- `encoding`
- `content`
- `downloadUrl`
- `url`

## 9. 受け入れ基準
- 有効な PAT 入力後、認証に成功して repository 一覧へ遷移できること。
- private repository が一覧表示されること。
- 任意 repository の階層を辿ってファイル表示できること。
- テキストファイル編集後、保存操作で GitHub に反映されること。
- 無効トークンや権限不足時に、原因が分かるエラーメッセージを表示すること。
- サインアウトで保存トークンが削除され、再起動後も未認証状態になること。

## 10. 将来拡張候補
- OAuth 認証対応。
- ブランチ選択 UI。
- 差分表示（保存前プレビュー）。
- 画像やバイナリのプレビュー。
- 監査ログや編集履歴表示。
