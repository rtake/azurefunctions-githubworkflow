# azure-agentservice-cicd

## 概要

本リポジトリは、Azure AI Foundry Agent Serviceでエージェントを発行した際に、その定義を自動的にGitHubへ反映してPull Requestを作成し、マージを契機に本番環境へ反映するGitOpsパイプラインです。

エージェント定義をコードとして管理し、Gitを通じて変更履歴・レビュー・承認フローを適用するGitOps運用を実現することを目的として構築しました。\
これにより以下を実現します。

- エージェント定義の変更履歴の可視化
- Pull Requestベースのレビュー・承認プロセス
- 開発環境と本番環境の分離による安全な変更管理
- 本番環境への変更統制(ガバナンス強化)

Gitを唯一の正とするGitOps運用により、変更の透明性と再現性を担保します。

## アーキテクチャ概要

本システムは、開発環境でのエージェント発行を起点として、GitHubを経由し、本番環境へ反映する構成になっています。

![](/docs/system-architecture.png)

### 処理フロー

1. 開発環境のAI Foundryでエージェントを発行
2. アクティビティログが出力される
3. Azure Monitorでアクティビティログアラートがトリガーされる
4. Azure Functions(parse log)がイベントを解析
5. Queue Storageにメッセージを投入
6. Azure Functions(export agent)がQueueをトリガーとして起動
7. GitHub Actionsを呼び出しPull Requestを作成
8. Pull Requestをレビュー・マージ
9. マージをトリガーとして本番環境のAI Foundryへエージェントを発行

## コンポーネント

### Azure Monitor

エージェントの発行操作を検知するアラートを定義します。\
アクティビティログではエージェント発行だけを直接抽出することが難しいため、エージェント操作ログ全般をParse log functionに渡し、その中でエージェント発行を抽出します。

### Azure Functions

#### Parse log Function ([detect-agent-publish.ts](./azure/functions/src/functions/detect-agent-publish.ts))

アクティビティログイベントを受信し、必要な情報を抽出してQueue Storageへメッセージを送信します。

#### Export agent Function ([upload-agent-from-queue.ts](./azure/functions/src/functions/upload-agent-from-queue.ts))

Queueメッセージをトリガーとして起動し、エージェント定義を取得してGitHub Actions workflowを呼び出します。

### Queue Storage

非同期処理のためのバッファとして機能し、一時的な障害時のリトライ制御も担います。

### GitHub Actions

#### PR作成ワークフロー ([agent-pr.yml](.github/workflows/agent-pr.yaml))

外部から手動実行できるよう、トリガーとしてworkflow_dispatchイベントを定義しています。

以下の処理を実行します:

1. ブランチ作成
2. エージェント定義JSONの保存
3. 作成したブランチ上でコミット・Push
4. Pull Request作成

#### 本番デプロイワークフロー ([deploy-agent.yaml](.github/workflows/deploy-agent.yaml))

mainへのPull Requestのマージをトリガーとして起動します。

1. AI Foundryのアクセストークンを取得
2. 本番環境のAI Foundryにエージェント発行APIを実行

## デプロイ手順

### 前提

- Azure CLIがインストールされていること
- 対象サブスクリプションにログイン済みであること

### デプロイ

```
# リソースグループ作成
az group create \
  --name <ResourceGroupName> \
  -l <RegionName>

# リソース作成
cd azure/
az deployment group create \
  --resource-group <ResourceGroupName> \
  --template-file infra/main.bicep \
  -p infra/param.bicepparam
```

#### (参考) Dry-run

```
az deployment group what-if \
  -g <ResourceGroupName> \
  -p infra/param.bicepparam
```

### Azure Functionsのデプロイ

リソース作成後、Azure Functionsをビルドしデプロイします。

```
cd azure/functions
npm install
npm run build # ビルド
func azure functionapp publish <FunctionAppName> # デプロイ
```

Azure Functionsの環境変数に以下の値を設定します。

| 変数         | 説明                                                                                                            |
| ------------ | --------------------------------------------------------------------------------------------------------------- |
| GITHUB_OWNER | GitHubリポジトリのユーザー名                                                                                    |
| GITHUB_REPO  | GitHubのリポジトリ名                                                                                            |
| GITHUB_TOKEN | GitHub Actions用のシークレット。GitHubのアカウントページのDeveloper settings -> Fine-grained tokensを作成します |

以下の変数は `az deployment create` コマンドを実行した際に自動で設定されます。

| 変数                    | 説明                                                                                              |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| QUEUE_CONNECTION_STRING | Queue storageの接続文字列                                                                         |
| QUEUE_NAME              | 2つのAzure Functionsを接続するために使用するキューの名前 (このリポジトリでは `queue-agentdeploy`) |

### アラート設定

アラートのアクショングループにデプロイした関数を追加します。
リソースグループの中のアクショングループの編集画面に進み、アクションに `detect-agent-publish` を追加します。

![](/docs/action-group.png)

### GitHub Actionsの設定

GitHub Actions workflowからAI Foundryのリソースを操作するためにアプリの登録が必要です。
以下のページを参考にして登録してください。\
[OpenID Connect で Azure ログイン アクションを使用](https://learn.microsoft.com/ja-jp/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux#use-the-azure-login-action-with-openid-connect)

その上で、リポジトリのSecretに以下の変数を設定してください。

| 変数名                     | 概要                                                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| AZURE_SUBSCRIPTION_ID      | 操作対象のAI Foundryが含まれているサブスクリプションのID                                                                |
| AIFOUNDRY_PROJECT_ENDPOINT | AI Foundryのエンドポイント (例: `https://{ai-services-account-name}.services.ai.azure.com/api/projects/{project-name}`) |
| AZURE_TENANT_ID            | GitHub Actions用のエンタープライズアプリケーションが含まれているテナントのID                                            |
| AZURE_CLIENT_ID            | GitHub Actions用のエンタープライズアプリケーションのID                                                                  |

![](/docs/github-secrets.png)

## テスト

`detect-agent-publish` を起動することでパイプラインの挙動をテストすることができます。\
.envにURLとキーを記載し, シェルスクリプトを実行します。\
GitHub上でワークフローが起動し、PR作成が確認できたら成功です。

```
cd azure/functions/test-scripts/upload-agent-to-github
bash trigger.sh
```

## 設計上のポイント

- アクティビティログに対して[ログ検索アラート](https://learn.microsoft.com/ja-jp/azure/azure-monitor/alerts/tutorial-log-alert)ではKQLを用いた詳細なフィルタリングが可能であるため、Parse log functionの呼び出し回数を抑えることが可能ですが。**課金が発生する**ため、今回はアクティビティログを採用しました ([参考: Azure MonitorでAgent Serviceのエージェントデプロイを自動検知する](https://zenn.dev/rtake/articles/412888054140d0#%E3%82%A2%E3%83%A9%E3%83%BC%E3%83%88%E3%81%AE%E7%A8%AE%E9%A1%9E%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6))
- アクティビティログの解析処理と、GitHub Actionsを起動してPull Requestを作成する処理を分離し、責務を明確にしました
- エージェント定義をGitHubにアップロードするworkflowはworkflow_dispatchで起動する構成としました。これにより、Azure FunctionsにGitHubのシークレットを持たせず、認証情報の管理範囲を最小化しました
- 開発環境での変更はPull Requestとして可視化し、レビュー・マージを経たものだけが本番環境に反映されるようにすることで、GitOpsとしての統制を担保しました
- 本番環境への反映はmainへのマージをトリガーとして実行し、Gitの状態と本番環境の状態を一致させる構成にしています

## 今後の改善ポイント

- Parse Log Functionの呼び出し元をSecure webhookに限定し、アクショングループからのみ呼び出せるようにする ([セキュア Webhook アクション グループを作成する](https://learn.microsoft.com/ja-jp/azure/azure-monitor/alerts/itsm-connector-secure-webhook-connections-azure-configuration#create-a-secure-webhook-action-group))
