# iOS/iPadOS ネイティブアプリ移行 検討メモ（引き継ぎ資料）

作成日: 2026-07-19（web-maintenance-note リポジトリにて起票）
移設日: 2026-08-06
目的: 現行の Web版（React + TS + Vite PWA, `web-maintenance-note`）を、iOS/iPadOS 向けのフルネイティブアプリ（SwiftUI）に移行するための検討記録。

**このドキュメントの位置づけ: 議論フェーズの記録。リポジトリ作成・初期Xcodeプロジェクト生成までは完了。実装（データモデル設計以降）はこれから。**

---

## 1. 移行の動機（なぜネイティブ化するか）

「ネイティブアプリという形」への憧れではなく、PWA では技術的に実現できない3つの機能が動機。

1. **バックグラウンドでの通知**: 現在の PWA は Web Notification API に依存しており、アプリを開いていない時に自動で通知を飛ばせない（サーバー無しでは不可能）。
2. **バックグラウンド GPS ロギング**: PWA の Geolocation API はページ破棄と同時に停止する。Google マップのタイムラインのような「常時ロギング」を実現したい。ツーリング中の走行ログを記録するのが主目的。
3. **Liquid Glass デザイン**: Apple 純正アプリのような本物の質感（`glassEffect` 等のネイティブ API）を求める。CSS での模倣では妥協できないと判断し、フルネイティブ書き直しを選択。

---

## 2. 決定事項サマリー

| 項目 | 結論 |
|---|---|
| アプリの形態 | SwiftUI によるフルネイティブアプリ（Capacitor 等のラップ方式ではない） |
| 対象OS | iOS + iPadOS（iPad は `NavigationSplitView` 等で正しく最適化する） |
| データ層 | SwiftData（Dexie/IndexedDB からの置き換え） |
| グラフ | Swift Charts（Recharts からの置き換え） |
| 通知 | UserNotifications framework でローカル通知を OS 予約。無料 Personal Team でも問題なく使用可 |
| GPS ロギング設計 | 下記「4. GPSロギングの設計」参照。常時ロギング・省電力優先 |
| デザイン | 本物の Liquid Glass（ネイティブ API）。CSS 模倣は不採用 |
| データ移行 | 既存の Web版インポート/エクスポート機能を使って SwiftData へ初期移行 |
| 配布方法 | AltStore Classic（無料 Apple ID、Mac + AltServer による週次自動再署名） |
| 同期方式 | iCloud/CloudKit ではなく **Cloudflare Workers + D1** で自前の同期APIを構築（下記「5. 同期方式」参照） |
| Web版の扱い | 完全移行し、Web版のメンテナンスは停止する |
| 開発環境 | **Mac 必須**。Xcode は macOS 専用のため Windows では開発不可 |
| リポジトリ | `native-maintenance-note`（本リポジトリ）として新規作成済み |
| Bundle Identifier | `com.ramilen.NativeMaintenanceNote`（確定・以降変更しない） |

---

## 3. 配布方法: AltStore Classic

- ストア配布は考えていない（本人希望）。個人利用のみ。
- 無料 Apple ID + Xcode でのサイドロードは **7日ごとに証明書が失効**する制約がある（Apple の free tier 仕様）。
- **AltStore Classic**（AltServer をMacに常駐させ、同一Wi-Fi上で自動的に署名延長する仕組み）を採用すれば、手動でのXcode再ビルドなしに運用できる。
- 日本でも 2025年12月18日の「スマホソフトウェア競争促進法」施行により **AltStore PAL**（Apple公式の代替マーケットプレイス）が利用可能になったが、
  - iPad は対象外（iPhoneのみ）
  - 自作アプリの配布には結局 Apple Developer Program（$99/年）+ Notarization が必要
  - → 今回の要件（無料・iPad含む）には合わないため、**AltStore Classic（非公式・従来方式）を採用**。
- リスク: Apple の OS アップデートで一時的に動かなくなることが過去に何度かあった（数日〜数週間で復旧する実績はある）。

### 3.1 技術的な注意点
- **Bundle Identifier を一貫させること**。再ビルド・再インストールを繰り返す際にBundle IDがぶれると、SwiftDataのローカルデータが消えるリスクがある。→ `com.ramilen.NativeMaintenanceNote` で確定済み。
- **大文字小文字にも注意**。Apple の App ID 登録は大文字小文字を区別しないため、無料 Personal Team では既に登録済みの表記（キャメルケース）と異なる大文字小文字でビルドしようとすると「登録できない」エラーになる。実機ビルド時は必ずこの表記のまま使うこと。
- 万一ローカルデータが消えても、Cloudflare 側に同期データがあれば復元できる（5章参照）。

---

## 4. GPSロギングの設計

「常時ロギング」かつ「最高精度は不要」という要件のため、Google マップのタイムラインに近いハイブリッド設計を採用する。

| 状態 | 使う仕組み | 精度 | 電池影響 |
|---|---|---|---|
| 静止中（大半の時間） | Significant-Change Location Service | 粗い（〜数百m、約500m移動 or セルタワー切替で発火） | ほぼゼロ |
| 移動検知後 | Core Motion（活動認識）→ 継続的な位置情報更新（`CLLocationManager`, `allowsBackgroundLocationUpdates`） | 中精度（`distanceFilter` で調整、`activityType = .automotiveNavigation` 推奨） | 移動中のみ発生 |

### 設計のポイント
- **Significant-Change Location Service** は `Background Modes`（location）Capability を使わずに動作し、アプリが完全終了していてもOSが再起動して呼び出してくれる特性がある。「常時ロギング」の土台として最適。
- 移動検知後に通常の継続更新へ切り替えることで、精度と電池のバランスを取る。停止を検知したら Significant-Change のみの待機モードへ戻す。
- `distanceFilter` は 10〜20m 程度が現実的な落としどころ（`kCLDistanceFilterNone` は精度最高だが電池を大きく消費する）。

### 実機検証結果（2026/08/07）
- 無料 Personal Team（実機: Ramilen's iPhone15PM）に、Significant-Change Location Serviceのみを使う最小スキャフォールド（`LocationLogger.swift`）をインストールして検証。
- 権限フローは「未決定 → 使用中のみ許可 → 常に許可」の2段階昇格がダイアログ操作のみで完了（Settingsアプリへの誘導は不要だった）。
- アプリを完全終了させた状態で約15時間・広範囲（福岡市内、緯度33.25〜33.59/経度130.4〜130.55）を移動し、45件の位置更新ログを記録。
- ログ中、`locationManagerDidChangeAuthorization`（CLLocationManager新規初期化時に必ず1回発火する）が離れた時刻に複数回記録されており、うち少なくとも2回はユーザーがアプリを手動で開いていないタイミングだった。これは**OSによるバックグラウンド再起動が実際に機能した**ことを示す強い状況証拠。
- **結論**: 無料 Personal Team でも Background Modes（location, Significant-Change方式）は実用レベルで動作すると判断。完全な確証（Xcodeのデバッグログ等での直接確認）ではないが、実運用上は問題ないレベルの根拠が得られた。

### 残っているリスク
- **長期ツーリング（7日以上）と AltStore Classic の再署名ルールが衝突する可能性**。証明書失効は基本的に「新規起動のブロック」であり、動作中のバックグラウンド処理を即座に止めるものではない可能性が高いが、確証はない。旅先でアプリを開けなくなるリスクは残る。
- 「常に許可」の位置情報権限は2段階の同意フロー（まず「使用中のみ」→ 後から「常に」への昇格）が必要。iOSが定期的に「バックグラウンドで位置情報を使用しています」という確認ダイアログを出すのは正常な仕様。
- 今回検証したのはSignificant-Changeのみ。移動検知後のCore Motion連携・継続的位置情報更新（表の2行目）は未実装・未検証のまま。

---

## 5. 同期方式: Cloudflare Workers + D1

- iCloud/CloudKit は SwiftData と統合が深く本来は第一候補だが、**無料 Personal Team では利用不可**（Push通知・iCloud・App Groups等は有料 Apple Developer Program 専用の entitlement）。
- 代替として **Cloudflare Workers（サーバーレス関数）+ D1（サーバーレスSQLite）** で自前の同期APIを構築する方針。
  - Apple の entitlement 制限と無関係のため、無料 Personal Team のままで実装可能。
  - Workers は TypeScript で書けるため、Web版で培った知見をそのまま活かせる。
  - 無料枠は個人利用なら十分（Workers: 1日10万リクエスト、D1: 個人のメンテ記録程度なら余裕）。
  - 認証はシンプルなトークン方式で十分（個人利用のため OAuth 等は過剰）。
  - 同期ロジックは「最終更新が勝つ」程度の単純な方式で十分（単一ユーザーの複数端末利用のため）。
- 副次的メリット: AltStore Classic の署名失効や端末側のデータ消失があっても、Cloudflare側のデータから復元できる（バックアップの役割も兼ねる）。

---

## 6. 開発環境: Mac 必須

- Xcode は **macOS 専用**。Windows/Linux 版は存在せず、ビルド・シミュレータ起動・コード署名は Mac 上でしか行えない。
- Web版の検証方針（「型チェックだけでなく必ずアプリを起動して実行確認する」）を踏襲するなら、検証は Mac 上でしか成立しない。
- **結論**: iOS開発セッションは Mac 側で完結させる。

---

## 7. リポジトリ・環境セットアップ（完了）

- 別リポジトリ `native-maintenance-note` として新規作成済み。
  https://github.com/Ramilen-L-Emuruk/native-maintenance-note
- `.gitignore`: GitHub公式 Swift.gitignore
- `LICENSE`: MIT
- Bundle Identifier: `com.ramilen.NativeMaintenanceNote`（確定・以降変更しない。§3.1参照）
- Xcode 26.6 で iOS App テンプレート（SwiftUI, Swift, SwiftData）から初期プロジェクトを生成済み。
  配置: `native-maintenance-note/NativeMaintenanceNote/`（Xcode標準の1階層ネスト構成）
- `xcode-select` を Command Line Tools から `/Applications/Xcode.app/Contents/Developer` へ切り替え済み。

### 決定: 無料のまま進める（2026/08/07判断）
§4の実機検証結果を踏まえ、**当面は無料 Personal Teamのまま開発を進める**ことに決定。

- iCloud/CloudKit を使いたい場合は有料必須 → 今回は不採用（§5の通りCloudflare Workers + D1で代替するため無関係）
- 無料 Personal Team での Background Modes（GPS）の安定性 → §4の実機検証で概ね良好と確認
- 長期ツーリング中（7日超）の AltStore Classic 署名失効リスク → 残存リスクとして引き続き注視（§4「残っているリスク」参照）

有料化（Apple Developer Program, $99/年）は上記の残存リスクが実際に問題化した場合に再検討する。有料化した場合のメリット: AltStore Classicの週次メンテナンスが不要になる（Ad-Hoc配布やTestFlightに切り替え可能）。Cloudflare同期は有料化後もそのまま使い続けて問題ない。

### 完了: CLAUDE.md の作成
- このリポジトリ用の CLAUDE.md（ビルド確認コマンド、テスト方針、コミット規約等）は作成済み。

---

## 8. 次のアクション

1. ~~実機での Background Modes（GPS）検証を最優先で実施し、無料/有料判断を確定させる~~（完了。§4・§7参照。無料 Personal Teamのまま進める判断）
2. `planner` エージェント or 計画モードで、以下のフェーズ分割を実装計画に落とし込む
   - データモデル（SwiftData）設計
   - 基本CRUD画面の実装
   - 燃費計算・グラフ（Swift Charts）
   - 通知機能（UserNotifications）
   - GPSロギング本実装（今回検証したSignificant-Changeに加えて、Core Motion連携・移動検知後の継続的位置情報更新を実装。検証用の`LocationLogger.swift`/`LocationVerificationView.swift`は本実装に置き換える想定）
   - Cloudflare Workers + D1 の同期API構築
   - Liquid Glass デザインの磨き込み
   - AltStore Classic での配布設定
3. 既存 Web版のエクスポート機能でデータをバックアップし、SwiftData への移行パスを確認する
4. ~~このリポジトリ用の CLAUDE.md を作成する~~（完了）
