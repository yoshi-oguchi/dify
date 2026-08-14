# Cursor Cloud Agents まとめ

最終確認日: 2026-08-14（公式ドキュメント優先）

この文書は Cursor 公式ドキュメントを優先して、Cloud Agents の概要・ローカル Agent との違い・起動方法・料金の考え方を日本語でまとめたものです。仕様は変更されうるため、実装や課金の最終確認は出典 URL を参照してください。

---

## Cursor Cloud Agents とは何か

出典: [Cloud Agents](https://cursor.com/docs/cloud-agent) / [What are background agents?](https://cursor.com/help/ai-features/background-agents) / [Cloud Agents (Help)](https://cursor.com/help/ai-features/cloud-agents)

Cloud Agents は、ローカル PC ではなく **クラウド上の隔離された仮想マシン (VM)** で動く Cursor のコーディング Agent です。Agent の基本（ツールをループで呼び出し、目標に向かって自律的に作業する）はローカル Agent と同じですが、実行場所がクラウドの開発環境になります。

以前は **Background Agents** と呼ばれていました。

### できること

- リポジトリのクローン、依存関係のインストール、シークレット、起動コマンド、ネットワークアクセスを備えた開発環境で作業する
- 機能実装、バグ修正、テスト作成、PR 作成まで一気通貫で進める
- 自分の VM 上でビルド・テスト・アプリ操作ができる（デスクトップとブラウザの computer use）
- スクリーンショット・動画・ログなどの **成果物 (artifacts)** を PR に付けて、ブランチをローカルに checkout しなくても検証できる
- チーム向けに設定した **MCP サーバー**（HTTP / stdio、OAuth 対応）を使い、DB・API・外部サービスに接続する
- フロント / バックエンド / インフラ / 共有ライブラリなど、**複数リポジトリ** をまたいで変更し、変更したリポジトリに PR を開く（long-running はマルチリポジトリ環境では未対応）
- 自分のラップトップがオンラインである必要がない。並列に何体でも起動できる

### 仕組み（概要）

1. アカウント管理者がソース管理を接続する（GitHub / GitLab / Bitbucket Cloud / Azure DevOps）
2. Agent がリポジトリをクローンし、**別ブランチ** で作業する
3. 変更をリモートへ push し、PR などで引き継ぐ
4. 環境は snapshot、`.cursor/environment.json`、Dockerfile、Builds などで事前準備できる

有効な開発環境がないと、コードは書けてもテストや API 呼び出しで作業を閉じられない、というのが公式の立場です。環境セットアップが効果を左右する最大のポイントです。

### 利用条件

- **有料プラン** が必要（Start / Pro / Pro+ / Ultra / Teams / Enterprise）
- ログイン済みで、対象リポジトリへの権限があること
- リポジトリと依存リポジトリ / サブモジュールへの **読み書き権限** があること

---

## ローカル Agent との違い

出典: [Cloud Agents](https://cursor.com/docs/cloud-agent) / [Cursor Agent overview](https://cursor.com/docs/agent/overview) / [How does "Move to Cloud" handle my file state?](https://cursor.com/help/ai-features/cloud-agents) / [What are background agents?](https://cursor.com/help/ai-features/background-agents)

どちらも「ツールをループで使う Agent」ですが、実行場所と前提が大きく違います。

| 観点 | ローカル Agent | Cloud Agents |
| --- | --- | --- |
| 実行場所 | 自分のマシン上のワークスペース | クラウドの隔離 VM |
| ネット切断 | マシンがオフラインだと止まる | ラップトップを閉じても動き続ける |
| 並列実行 | ローカル資源に依存 | 何体でも並列起動できる |
| 作業対象 | 今開いているローカルファイル（未コミット変更も含む） | リモートリポジトリのクリーンな git 状態から開始 |
| 成果物 | IDE 内の編集・チェックポイント | 別ブランチ + PR。スクリーンショット / 動画 / ログ |
| 検証 | ローカルのターミナル・ブラウザ | VM 上でビルド・テスト・computer use。リモートデスクトップで自分でも操作可能 |
| 起動面 | Cursor Desktop（エディタ）が中心 | Desktop / Web / Slack / GitHub / Linear / API / iOS など |
| 環境 | 自分のローカルセットアップ | snapshot / `environment.json` / Builds で再現 |
| フック | ユーザーレベルの `~/.cursor/hooks.json` も使える | リポジトリの `.cursor/hooks.json`（Enterprise はチーム / 企業フックも）。IDE 専用フックやホームディレクトリのフックは使えない |
| 課金 | プランの included usage + on-demand | 選択モデルの **API pricing**。初回利用時に spend limit を設定 |

補足:

- Desktop の **Move to Cloud** は会話履歴とコンテキストは引き継ぎますが、**未コミットのローカル変更は送りません**。最新状態で動かしたい場合は、先に commit または stash してください。
- Cloud Agents は自分のマシンを汚しません。コマンドはサンドボックス VM 内で実行されます。
- Cloud Agents はキュレーションされたモデルから選びます。対応モデルではコンテキストウィンドウサイズも選べます。

---

## 起動方法（Desktop / Web / Slack / GitHub）

出典: [How to access](https://cursor.com/docs/cloud-agent) / [How do I start a Cloud Agent task?](https://cursor.com/help/ai-features/cloud-agents) / [Slack](https://cursor.com/docs/integrations/slack) / [GitHub](https://cursor.com/docs/integrations/github)

前提として、アカウント管理者がソース管理を接続している必要があります。GitHub の場合は [Integrations](https://cursor.com/dashboard/integrations) から Cursor GitHub App を入れ、対象リポジトリへのアクセスを付与します。

### Desktop

出典: [How to access](https://cursor.com/docs/cloud-agent) / [Cloud Agents (Help)](https://cursor.com/help/ai-features/cloud-agents)

1. Cursor Desktop で Agent 入力欄の下のドロップダウンから **Cloud** を選ぶ
2. リポジトリとタスクを指定して起動する
3. 既存のローカル会話をクラウドへ移す場合は **Move to Cloud** を使う（未コミット変更は含まれない）

起動した Agent は [cursor.com/agents](https://cursor.com/agents) やモバイルからも続けて確認できます。

### Web

出典: [How to access](https://cursor.com/docs/cloud-agent)

1. 任意のデバイスで [cursor.com/agents](https://cursor.com/agents) を開く
2. リポジトリ（または Environment）とプロンプトを指定して起動・管理する
3. Android では Chrome で同 URL を開き、**Install App** で PWA 化できる

Web は環境・シークレット・MCP の管理にも使います。ダッシュボードは [Cloud Agents dashboard](https://cursor.com/dashboard/cloud-agents) です。

### Slack

出典: [Slack integration](https://cursor.com/docs/integrations/slack)

1. [Cursor integrations](https://cursor.com/dashboard/integrations) で Slack を Connect する（または [installation page](https://cursor.com/api/install-slack-app)）
2. セットアップ時にリポジトリ接続、**usage-based pricing の有効化**、プライバシー設定を確認する
3. チャンネルで `@cursor`（または `@Cursor`）に続けてプロンプトを書く

よく使うコマンド:

| コマンド | 意味 |
| --- | --- |
| `@Cursor [prompt]` | Cloud Agent を起動。既存スレッドでは follow-up |
| `@Cursor agent [prompt]` | スレッド内で新しい Agent を強制起動 |
| `@Cursor settings` | チャンネルのデフォルトリポジトリなどを設定 |
| `@Cursor list my agents` | 実行中の Agent を一覧 |

オプション例: `repo=acme/backend`、`env=Platform`、`branch=dev`、`model=opus`、`autopr=false`

完了すると Slack に通知が来て、作成された GitHub PR を開けます。

### GitHub

出典: [How to access](https://cursor.com/docs/cloud-agent) / [GitHub integration](https://cursor.com/docs/integrations/github) / [Fixing CI Failures](https://cursor.com/docs/cloud-agent/capabilities)

1. 管理者が GitHub App をインストールし、対象リポジトリへのアクセスを付ける
2. **GitHub の PR または Issue に `@cursor` とコメント** して起動する（Bitbucket は PR コメント）
3. 例: `@cursor please fix the CI failures`

CI 自動修復（GitHub Actions、Teams 向け）の制御:

- `@cursor autofix off` / `@cursor autofix on`
- グローバル無効化は [Dashboard → Cloud Agents → My Settings](https://cursor.com/dashboard/cloud-agents)

自己ホストワーカーへ回す場合は `@cursoragent self_hosted=true ...` や `pool=<name>` も使えます。詳細は [Self-hosted pool](https://cursor.com/docs/cloud-agent/self-hosted-pool) を参照してください。

### その他の起動面（参考）

出典: [How to access](https://cursor.com/docs/cloud-agent)

対象外ですが、公式には次もあります。

- **iOS**: [Cursor iOS app](https://cursor.com/docs/cloud-agent/mobile)
- **Linear**: `@cursor`
- **API**: [Cloud Agent API](https://cursor.com/docs/cloud-agent/api/endpoints)
- **Automations**: スケジュールや GitHub / Slack / Linear / webhook イベントから起動（[cursor.com/automations](https://cursor.com/automations)）

---

## 料金の考え方（API pricing / spend limit）

出典: [Billing (Cloud Agents)](https://cursor.com/docs/cloud-agent) / [Models & Pricing](https://cursor.com/docs/models-and-pricing) / [Usage-based charges](https://cursor.com/help/account-and-billing/overages) / [Team Pricing](https://cursor.com/docs/account/teams/pricing) / [Usage and limits](https://cursor.com/help/models-and-usage/usage-limits)

### API pricing

Cloud Agents は、選んだモデルの **API pricing（トークン課金）** で請求されます。対応モデルではコンテキストウィンドウサイズを選べますが、大きいほどトークン消費とコストが増えます。

公式の整理:

1. プランに含まれる **included usage** から先に消費される
2. 使い切ったあとは **on-demand（従量）** に進む（有効化が必要）
3. 単価はモデルごとの公開 API 価格。Teams / Enterprise でサードパーティモデルを直接選ぶ場合は、さらに Cursor Token Rate（100 万トークンあたり $0.25）が乗る
4. Cursor 第一世代モデル（Grok 4.6 / Grok 4.5 / Composer 2.5）と Auto Cost は Cursor Token Rate の対象外

個人プランの included usage の目安（Other Models プール）:

| プラン | 月額 | Other Models の included |
| --- | --- | --- |
| Start（インドのみ） | ₹649/月（税込） | $0（Cursor Models と Cloud Agents は含む） |
| Pro | $20/月 | $20 |
| Pro Plus | $60/月 | $70 |
| Ultra | $200/月 | $400 |

モデル単価の一覧は [Model pricing](https://cursor.com/docs/models-and-pricing.md#model-pricing) を見てください。単価は変動します。

### Spend limit

初回利用時に **spend limit（支出上限）** の設定を求められます。上限は「従量課金がどこまで進んでよいか」のキャップです。

実務上のポイント:

- Slack セットアップでも **usage-based pricing の有効化** が求められます
- on-demand をオフにすると、included usage を使い切った時点で追加リクエストは止まります
- 上限はダッシュボードの [Spending](https://cursor.com/dashboard/spending) / Billing から確認・変更します
- Teams はチーム全体の月次上限を設定できます。メンバー単位の上限は Enterprise の Enhanced Spend Limits です
- コミュニティサポートの補足（公式 docs より詳細）: ハードリミット直前だと spend-based rate limiter により起動できないことがある。上限と現在支出のあいだに余裕を残す

課金の実体は「VM のアイドル時間」ではなく、**Agent が動いているときのトークン消費** です。タスクが終わり、フォローアップもなければ新しいトークンは消費されません。

料金の最終確認は [cursor.com/dashboard/spending](https://cursor.com/dashboard/spending) と [Models & Pricing](https://cursor.com/docs/models-and-pricing) を見てください。

---

## 自分で試す次の 3 ステップ

1. **ソース管理と支出上限を先に用意する**  
   [Integrations](https://cursor.com/dashboard/integrations) で GitHub（または GitLab / Bitbucket / Azure DevOps）を接続し、[Spending](https://cursor.com/dashboard/spending) で usage-based pricing と spend limit を確認する。有料プランでないと起動できません。

2. **いちばん近い面から 1 本起動する**  
   Desktop なら Agent 入力下の **Cloud**、ブラウザなら [cursor.com/agents](https://cursor.com/agents) で、小さなタスク（テスト追加やドキュメント修正など）を投げる。未コミット変更は送られないので、必要な変更は先に push する。

3. **普段のコミュニケーションから起動してみる**  
   Slack なら `@Cursor in <repo>, <やりたいこと>`、GitHub なら PR / Issue に `@cursor <やりたいこと>`。完了通知と PR を開き、artifacts や diff をレビューしてからマージする。

関連ドキュメント: [Cloud agent setup](https://cursor.com/docs/cloud-agent/setup) / [Capabilities](https://cursor.com/docs/cloud-agent/capabilities) / [Security and network](https://cursor.com/docs/cloud-agent/security-network)
