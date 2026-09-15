# CLAUDE.md

プロジェクトで作業するときの手順とルール。

## 変更時の基本フロー（必ずこの順で行う）

1. **状況整理・修正方針の確認**（実装に着手する前に必ず行う。自明な軽微修正でも省略しない）
   - 対象のコード・挙動を調査し、現状と問題点（原因・影響範囲）を整理する
   - 整理した内容と修正方針（どこを・なぜ・どう直すか）をユーザーに提示する
   - ユーザーの確認を得てから次のステップに進む。指摘や方針変更があれば整理からやり直す
2. **ワークツリー作成**（修正・機能追加時はワークツリーを作成してから作業する。ブランチ名は必ず `worktree/<type>/<name>` 形式にする: `worktree/fix/〇〇`・`worktree/feat/〇〇`・`worktree/refactor/〇〇`・`worktree/docs/〇〇`・`worktree/chore/〇〇` など）
   - **注意**: `EnterWorktree(name: ...)` はブランチ名を自動変換してしまうため使用しない。必ず以下の 2 ステップで行う:
     ```bash
     # Step 1: 正しいブランチ名でワークツリーを作成
     git worktree add -b worktree/<type>/<name> .claude/worktrees/<name>
     # Step 2: 作成したワークツリーに入る
     EnterWorktree(path: ".claude/worktrees/<name>")
     ```
3. **実装**（プロジェクトでバージョン番号を管理している場合、ワークツリー内ではバージョンフィールドを変更しない。理由は下記「バージョン管理」参照）
4. **検証**（下記「検証」を実施）
5. **コミット前確認**（実装・検証が終わったら、コミットする前に必ずユーザーに確認を取る。**省略しない**）
   - 何を・なぜ・どう直したかを簡潔に提示し、コミットしてよいか確認する
   - 確認が取れるまで次のステップに進まない
6. **コミット**（確認が取れたら、下記「コミット」の規約に従いコミットする）
7. **main へのマージ**（**ユーザーから明示的に指示があったときのみ**。マージ前に必ず確認する。必ずマージコミットを作成する（`--no-ff`））
8. **バージョン更新**（プロジェクトでバージョン番号を管理している場合のみ。**main へのマージ直後・main 上で実施**。下記「バージョン管理」参照。マージしない限りこのステップは発生しない）
9. **プッシュ**（**ユーザーから明示的に指示があったときのみ**。自動では行わない）
10. **リリース後のクリーンアップ**（プッシュ完了後に必ず実施する）
   - **ワークツリーの削除**:
     - ワークツリー内にいる場合は先に `ExitWorktree(action: "keep")` で抜けてから削除する
     - `git worktree remove .claude/worktrees/<name>` でワークツリーディレクトリを削除
     - `git branch -d worktree/<type>/<name>` でブランチを削除
   - **起動したサーバー・ツールの停止**: 検証用に起動したシミュレータ等を必要に応じて終了させる

## 検証

> **コードを修正した場合は、ビルドだけでなく必ず動作確認まで行う。**

ビルドもテストも **Mac 上で実行する**（下記「開発構成」参照）。コマンドは「補助コマンド」節を参照。

- **ビルド（必須）**: エラー 0 を確認する。
- **テスト（必須）**: `** TEST SUCCEEDED **` を確認する。
  **テストの件数と結果は xcresult から読む。** `xcodebuild` の生ログを `grep` で数えると実際と合わない。**取りこぼすことも、重複して数えることもある**——並列シミュレータ（`Clone N of ...`）の出力が同じ行に混ざって行が壊れる場合と、繰り返し実行されるテスト（パフォーマンス計測など）が複数回 `passed` 行を出す場合の両方を実測した。
- **動作確認**: シミュレータの操作は `xcrun simctl` を SSH 越しに使う（`boot` / `io <udid> screenshot` / `listapps`）。画面を目視したいときはスクリーンショットを `scp` で取り寄せる。
- **実機必須の機能**: GPS（Core Location / Core Motion のバックグラウンド動作）はシミュレータでは正しく検証できないため、実機接続での確認が必須。
- **大きめの変更時**: Release 構成でのビルドも確認する。
- **後から足した回帰テストは、修正を一時的に戻して落ちることを確かめる**。通ったことしか見ていないテストは、修正を戻しても通る＝何も守っていない可能性がある。確かめ方は「補助コマンド」節を参照。
- **修正後の確認は徹底する**。「たぶん直っているだろう」でコミットしない。

## プランモード

- プランモードに入ったとき、前回のプランが**完了済み**（実装・コミット済み）の場合は、既存プランファイルを修正せず**新規プランファイルを作成**する。
- 前回プランが未完了（作業途中）の場合のみ、既存プランファイルを引き続き更新してよい。

## コミット

- **Conventional Commits**（`feat` / `fix` / `refactor` / `docs` / `chore` / `perf` / `ci`）。説明は日本語。
- コミットメッセージ末尾に必ず付与する。**モデル名はその時作業している Claude モデルに合わせる**（ハーネスが指定するモデル名を使用する。特定モデルに固定しない）:
  ```
  Co-Authored-By: Claude <モデル名> <noreply@anthropic.com>
  ```
  例（Sonnet 5 で作業時）: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
- プロジェクトでバージョン番号を管理している場合、ワークツリー内のコミットではバージョンフィールドを変更しない（下記「バージョン管理」参照）。
- **コミット前に必ずユーザーに確認を取る。省略しない**。同一セッション内で別の修正のコミット許可をもらっていても、その修正のコミット許可を個別にもらっていない場合は確認する。

## マージ

- **ファストフォワード可能な場合でも、必ずマージコミットを作成する（`git merge --no-ff`）**。
  - 例: `git merge --no-ff worktree/feat/〇〇`
  - 理由: 各機能・修正の単位（ブランチ）を履歴上で明確に残すため。

## バージョン管理

現時点ではバージョン番号の管理は未導入（Xcodeプロジェクトの `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` を使うかは今後判断）。導入する場合は以下の方針に従う。

**バージョン確定は「main へのマージが完了した直後・main 上」でのみ行う。** ワークツリー内やマージ前のブランチではバージョンフィールドを変更しない。

- **理由**: 複数のワークツリーを並行して進めている場合、各セッションがワークツリー作成時点の（まだ更新されていない）古いバージョンを見て同じ番号を選んでしまい、結果的にバージョンが正しく積み上がらない事故が起きる。マージは順番に処理されるため、マージ直後の main 上でバージョンを決めれば常に最新の値を見て +1 できる。
- **手順**（main へのマージ後、毎回省略せず行う）:
  1. バージョンを上げるか（メジャー/マイナー/パッチ/上げない）をユーザーに確認する
  2. 上げる場合、main 上で `.xcodeproj` の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` を更新する
- プッシュ時（ユーザーの明示的指示があったとき）はバージョン更新で作成したタグも一緒に送る: `git push && git push --tags`（または `git push --follow-tags`）。

## コメント・ドキュメント整合性チェック

コードを変更した際は、以下の照合を必ず行う。変更が小さくても省略しない。

### 変更前後に確認すること
- **数値・閾値の一致**: コメントに書かれた秒数・件数・スケール値・インデックス範囲が実コードの値と一致するか。
- **列挙の網羅性**: コメントが列挙する要素（電文種別・層数・ペイン名など）が実装のすべての要素を網羅しているか。
- **UI 説明文と実データの照合**: ユーザーに表示する説明文は、それが参照するデータの実値と一致するか。

### コメント腐敗を防ぐパターン
- 処理の「単位」「対象範囲」「条件」を書いたコメントは、実装変更時に必ず追従させる。
- 「A または B」「A の場合のみ」のような条件を述べるコメントは、実コードの条件式と突き合わせて確認する。
- 古い識別子・旧実装の痕跡（クラス名・ペイン名・関数名）がコメントに残っていないか確認する。

### ドキュメントのプロジェクト構成ツリー
- `README.md` にプロジェクト構成ツリーがある場合、新ファイルを追加した際は必ず追記する。
- 削除・リネームしたファイルも同様に更新する。

## プロジェクト固有の設定

### 概要

- バイクのメンテナンスノート（給油・整備・保険記録）を管理する iOS/iPadOS ネイティブアプリ。
- SwiftUI + SwiftData によるフルネイティブ実装（Web版 `web-maintenance-note` からの完全移行）。
- グラフ表示は Swift Charts。
- 詳細な移行検討経緯・設計判断は [docs/HANDOFF.md](docs/HANDOFF.md) を参照。

### 開発構成

| 役割 | 場所 |
|------|------|
| 編集 | Windows PC（このリポジトリ） |
| ビルド・シミュレータ・実機 | LAN 上の Mac mini M4（`ssh -o BatchMode=yes macmini`） |
| 中継 | GitHub（public） |

以降の記述で使うプレースホルダ: **`<repo>`** は Mac 側のリポジトリの絶対パス、**`<name>`** はワークツリー名（`<repo>/.claude/worktrees/<name>` に置かれる）。

iOS のビルドには macOS が要るが、編集環境は Windows にある。この構成はそれを埋めるためのもの。**Mac 側では編集しない**——この規律だけで衝突が起きない。

Mac は macOS 26.6.1 / Xcode 26.6 / iOS 26.5 SDK。実機（iPhone 15 Pro Max）は常時接続ではないため、GPS 等の実機検証を行うときに Mac へ繋ぐ。接続状況は `xcrun xctrace list devices`（オフラインの実機も列挙される）か `xcrun devicectl list devices` で確かめる。

踏まえておくこと:

- **Mac から GitHub へ push できない。** SSH セッションから macOS キーチェーンを開けず失敗する。fetch / pull は public リポジトリなので通る。**push は必ず Windows から行う。**
- **ワークツリーで作業するときは、Mac 側にも同名のワークツリーを用意する。** `mac` リモート（Mac のリポジトリへ SSH 直結。GitHub を経由しない）でブランチを送り、Mac 側で展開する:
  ```
  git push mac worktree/<type>/<name>
  ssh -o BatchMode=yes macmini "git -C <repo> worktree add .claude/worktrees/<name> worktree/<type>/<name>"
  ```
  **`origin`（GitHub）への push はユーザー承認が要る外向きの操作だが、`mac` への push は LAN 内で完結する**ため検証手順の一部として扱ってよい。
  なお**ワークツリー内のセッションからは、ssh 越しに git を含む複合コマンドを送ると拒否されることがある**。その場合は上のように 1 コマンドずつ送る。
- **以降の細かい修正は `scp` で回す。** ブランチを送り直すより速い。変更ファイルだけ Mac のワークツリーへ直接送る:
  ```
  F=NativeMaintenanceNote/NativeMaintenanceNote/Views/SettingsView.swift   # 送りたいファイル
  W=<repo>/.claude/worktrees/<name>
  ssh -o BatchMode=yes macmini "mkdir -p $W/$(dirname $F)"
  scp -o BatchMode=yes "$F" "macmini:$W/$(dirname $F)/"
  ```
  **宛先は送信元と同じ相対パスへ揃える**（`dirname` で導く）。宛先ディレクトリを決め打ちにすると、別の階層のファイルを送ったときに違う場所へ置かれ、**ビルドは変更前のコードのまま通ってしまう**。
  **`mkdir -p` を省かない。** `scp` は宛先ディレクトリを作らないため、Mac 側にまだ無い階層へ新規ファイルを送ると `No such file or directory` で止まる。
  ファイルはワークツリー内からの相対パスで指定する（`C:/...` は scp がコロンをホスト区切りと解釈するため渡さない）。
- **複数ファイルを送ったら、送り忘れがないか突き合わせる。** `scp` は送り忘れてもエラーを出さず、**Mac 側は古いままビルド・テストに成功してしまう**。両側の変更一覧が一致することを確認する:
  ```
  git status --short                                                            # Windows 側
  ssh -o BatchMode=yes macmini "git -C $W status --short --untracked-files=all"  # Mac 側
  ```
- **Mac へ送った内容は作業ツリーを汚す。** 検証が済んだら戻すか、Windows 側でコミットしてから整合させる。放置すると次に触るときに混乱する。
  まず何が汚れているかを見て、**状態に応じて戻し方を変える**:
  ```
  ssh -o BatchMode=yes macmini "git -C $W status --short --untracked-files=all"
  ssh -o BatchMode=yes macmini "git -C $W checkout -- $F"   #  M = 既存ファイルを上書きした場合
  ssh -o BatchMode=yes macmini "git -C $W clean -f -- $F"   # ?? = 新規ファイルを送った場合
  ```
  **`git checkout --` は追跡中のファイルにしか効かない。** 新規に送ったファイルへ使うと `did not match any file(s) known to git` を返して**何も消さずに終わる**ため、`git clean` が要る。
  **`git checkout -- .` は使わない。** 未コミットの変更を区別なく全部破棄し、復元できない——別の検証で置いたファイルまで巻き込む。
- **リモートのシェルは zsh。** `PIPESTATUS` は効かない（`$?` を使う）。
- Xcode の同期フォルダ（`PBXFileSystemSynchronizedRootGroup`）を使っているため、`.swift` を追加しても `.xcodeproj` への手動登録は要らない。

### 補助コマンド

Mac 上で実行する。使うプレースホルダは 2 つ。

- **`<proj>`** — `.xcodeproj` の絶対パス。ワークツリーで作業中なら `<repo>/.claude/worktrees/<name>/NativeMaintenanceNote/NativeMaintenanceNote.xcodeproj`
- **`<dd>`** — このワークツリー専用の DerivedData。`~/Library/Developer/Xcode/DerivedData/NMN-<name>` とする

**`-project` は絶対パスで渡す。** `ssh macmini "コマンド"` は毎回 `$HOME` を起点とする新しいシェルで動くため、`cd` を明示しない限り相対パスの基準がワークツリーにならない（`cd` してから渡せば相対パスでも通るが、`cd` 忘れの事故を避けるため絶対パスに統一する）。

**`-derivedDataPath` を省かない。** 既定の DerivedData は `NativeMaintenanceNote-<ハッシュ>` という名前で、**どのワークツリーのものか名前から区別できない**。複数のワークツリーを並行して進めると（このプロジェクトの既定の進め方）、下記の xcresult 取得が **別のワークツリーの検証結果を掴む**。エラーは出ず、静かに誤った結果を報告することになる。

| 用途 | コマンド |
|------|----------|
| ビルド | `xcodebuild -project <proj> -derivedDataPath <dd> -scheme NativeMaintenanceNote -destination 'platform=iOS Simulator,name=iPhone 17' build` |
| テスト | 上記の末尾 `build` を `test` に変える |
| Release ビルド | 上記に `-configuration Release` を足す |
| ユニットテストのみ | **テスト行**の末尾に `-only-testing:NativeMaintenanceNoteTests` を足す（`build` に足しても黙って無視される） |

**実在するシミュレータは iPhone 17 / 17 Pro / 17 Pro Max / 17e / iPhone Air と iPad 各種（すべて iOS 26.5）。`iPhone 16` も `iPhone 16e` も存在しない。** 手元の一覧は `xcrun simctl list devices available` で確かめる。

`-quiet` は成功メッセージまで消すため使わない。出力はログへ落とし、成否は `grep -E "^\*\* (BUILD|TEST)"` で拾う。

テストの件数と結果は xcresult から読む（理由は「検証」節）:

```
B=$(ls -dt <dd>/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool get test-results tests --path "$B"
```

**グロブの起点は `<dd>`**（ワークツリー専用の DerivedData）にする。既定の場所を `NativeMaintenanceNote-*` で舐めると、別ワークツリーの結果を拾う。

返る JSON のルートは `testNodes`（`children` ではない）。`nodeType` が `"Test Case"` のノードの `name` と `result` を見る。

**回帰テストが本当に修正を守っているかの確かめ方**（「検証」節が求めるもの）: Mac 上で正しい版を `/tmp/<name>/` へ退避 → `sed` で挙動だけ旧仕様へ戻す → テストを実行して落ちることを確認 → 退避した版を書き戻す。Windows 側の正本には触れないため安全。**退避先にワークツリー名を挟む**のは、`/tmp` が Mac 上の全ワークツリー共有で、同名ファイルを別々のワークツリーで同時に扱うと退避版が取り違わるため。

### 構成メモ

- `NativeMaintenanceNote/`: Xcodeプロジェクトルート（`.xcodeproj` と同階層）。
  - `NativeMaintenanceNote/NativeMaintenanceNote/`: アプリ本体のソースコード。
  - `NativeMaintenanceNote/NativeMaintenanceNoteTests/`: ユニットテスト。
  - `NativeMaintenanceNote/NativeMaintenanceNoteUITests/`: UIテスト。
- `docs/HANDOFF.md`: Web版からの移行検討メモ（動機・設計判断・未解決事項）。
- Bundle Identifier: `com.ramilen.NativeMaintenanceNote`（固定・変更しない。理由は `docs/HANDOFF.md` §3.1 参照）。
- 配布方法: AltStore Classic（無料 Apple ID）を想定。詳細は `docs/HANDOFF.md` §3 参照。
