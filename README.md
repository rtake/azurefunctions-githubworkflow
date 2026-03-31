# azure-agentservice-gitops

## 概要

![](/docs/concept.png)

本リポジトリは、Azure AI FoundryのAgent Serviceでエージェントを発行した際に、その定義を自動的にGitHubへ反映してPull Requestを作成し、マージ後に本番環境へ反映するGitOpsパイプラインです。

**エージェント定義をコードとして管理し、Git上で変更履歴・レビュー・承認フローを適用するGitOps運用を実現する**ことを目的として構築しました。

これにより以下を実現します。

- エージェント定義の変更履歴の可視化
- Pull Requestベースのレビュー・承認プロセス
- 開発環境と本番環境の分離による安全な変更管理
- 本番環境への変更統制(ガバナンス強化)

## アーキテクチャ概要

本システムは、開発環境でのエージェント発行を起点として、GitHubを経由し、本番環境へ反映する構成になっています。

![](/docs/system-architecture.png)

AI Foundryはリソース(アカウント)単位で分離し、GitHub上で同じエージェント名で管理します。
開発環境のエージェント定義やプロジェクト構造は `/agents/projects` 以下に反映されます。ファイルの命名規則は `/agents/projects/{PROJECT_NAME}/{AGENT_NAME}.json` です。

mainブランチにマージされたエージェントは、本番環境のAI Founsryアカウントの `prod` プロジェクトで作成・発行されます。
デプロイ先のプロジェクト名を変更したい場合は [deploy-agent.yaml](/.github/workflows/deploy-agent.yaml) の `PROJECT_NAME` を変更してください。その際、AI Foundry側にも同じ名前のプロジェクトが作成されていることを確認してください。

開発環境のエージェント名が本番環境にそのまま対応するため、本番用のAI Foundryに該当のエージェントが存在しない場合にはワークフロー ([deploy-agent.yaml](/.github/workflows/deploy-agent.yaml)) の中で作成します。

### 処理フロー

1. 開発環境のAI Foundryでエージェントを発行する
2. エージェント操作に伴うアクティビティログが出力される
3. Azure Monitorのアクティビティログアラートが発火し、アクショングループ経由でParse Log Functionが起動される
4. Parse Log Functionがイベントを解析し、エージェント発行イベントのみを抽出する
5. 抽出した情報をQueue Storageへメッセージとして送信する
6. Export Agent FunctionがQueueをトリガーとして起動する
7. Export Agent Functionがエージェント定義を取得し、GitHub Actions(workflow_dispatch)を呼び出す
8. GitHub Actionsがブランチを作成し、エージェント定義をコミットしてPull Requestを作成する
9. Pull Requestをレビュー・マージする
10. mainへのマージをトリガーとしてGitHub Actionsが起動し、OIDCによる認証でAzureにアクセスする
11. 本番環境のAI Foundryに対してエージェント発行APIを実行する

## コンポーネント

### Azure Monitor

エージェントの発行操作を検知するアラートを定義します。

アクティビティログではエージェント発行だけを直接抽出することが難しいため、エージェント操作ログ全般をParse Log Functionに渡し、その中でエージェント発行を抽出します。

### Azure Functions

#### Parse log Function ([detect-agent-publish.ts](/azure/functions/src/functions/detect-agent-publish.ts))

アクティビティログイベントを受信し、必要な情報を抽出してQueue Storageへメッセージを送信する関数です。

#### Export Agent Function ([upload-agent-from-queue.ts](/azure/functions/src/functions/upload-agent-from-queue.ts))

Queueメッセージをトリガーとして起動し、エージェント定義を取得して、GitHub Actions workflowを呼び出す関数です。

### Queue Storage

非同期処理のためのバッファとして機能し、一時的な障害時のリトライ制御も担います。

### GitHub Actions

#### PR作成ワークフロー ([agent-pr.yml](.github/workflows/agent-pr.yaml))

GitHubにエージェント定義をJSON形式でアップロードするワークフローです。

外部から手動実行できるように、workflow_dispatchイベントをトリガーとして定義しています。

mainブランチからブランチを新規作成し、そのブランチ上でエージェント定義をコミット・Pushし、PR作成まで行います。

#### 本番デプロイワークフロー ([deploy-agent.yaml](.github/workflows/deploy-agent.yaml))

mainブランチへのPRマージをトリガーとして起動し、本番用のAI Foundryにアップロードし公開するワークフローです。

(処理概要)

1. AI Foundry APIとARM APIのアクセストークンを取得
2. 変更されたエージェント定義をAI Foundryにアップロードし[agent version](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/publish-agent#understand-agent-applications-and-deployments)を新規作成
3. デプロイメントを新規作成
4. アプリケーションの向き先を新規作成したデプロイメントに設定

## デプロイ手順

- Azure CLIがインストールされており、対象サブスクリプションにログイン済みであることを前提とします。

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

デプロイ前に構成の変更をレビューしたい場合は以下のDry-run用コマンドを実行してください。

```
cd azure/
az deployment group what-if \
  --resource-group <ResourceGroupName> \
  --template-file infra/main.bicep \
  -p infra/param.bicepparam
```

### Azure Functionsのデプロイ

リソース作成後、Azure Functionsをビルドしデプロイしてください。

```
cd azure/functions
npm install
npm run build # ビルド
func azure functionapp publish <FunctionAppName> # デプロイ
```

Azure Functionsの環境変数に以下の値を設定します。

| 変数         | 説明                                                                                                                    |
| ------------ | ----------------------------------------------------------------------------------------------------------------------- |
| GITHUB_OWNER | GitHubリポジトリのユーザー名                                                                                            |
| GITHUB_REPO  | エージェント定義を管理するGitHubのリポジトリ名名                                                                        |
| GITHUB_TOKEN | GitHub Actions用のシークレット。GitHubのアカウントページのDeveloper settings -> Fine-grained tokensを作成して設定します |

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

#### アプリの登録・ロール割り当て

本番デプロイワークフローからAI Foundryのリソースを操作するために、テナント上にサービスプリンシパルが必要です。
以下のページを参考にして、テナント上にワークフロー用のアプリケーションを登録してください。

[OpenID Connect で Azure ログイン アクションを使用](https://learn.microsoft.com/ja-jp/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux#use-the-azure-login-action-with-openid-connect)

作成したサービスプリンシパル(Azure管理画面上ではエンタープライズアプリケーションとして扱われます)に以下のロールを割り当ててください

| ロール                          | スコープ            |
| ------------------------------- | ------------------- |
| `Azure AI ユーザー`             | AI Foundry (本番用) |
| `Cognitive Services 共同作成者` | AI Foundry (本番用) |
| `共同作成者`                    | リソースグループ    |

#### リポジトリのシークレットと変数の設定

リポジトリのシークレットに以下の変数を設定してください。

| 変数名                | 概要                                                                         |
| --------------------- | ---------------------------------------------------------------------------- |
| AZURE_SUBSCRIPTION_ID | 操作対象のAI Foundryが含まれているサブスクリプションのID                     |
| AZURE_TENANT_ID       | GitHub Actions用のエンタープライズアプリケーションが含まれているテナントのID |
| AZURE_CLIENT_ID       | GitHub Actions用のエンタープライズアプリケーションのID                       |

リポジトリの構成変数に、mainへのマージ時にエージェントをデプロイする(=本番用の)AI Foundryのアカウント名とリソースグループ名を設定してください。

| 変数名                 | 概要                     |
| ---------------------- | ------------------------ |
| AIFOUNDRY_ACCOUNT_NAME | AI Foundryのアカウント名 |
| RESOURCE_GROUP_NAME    | リソースグループ名       |

![](/docs/githubactions-vars.png)

## テスト

### アラート発報からPR作成までのテスト

.envに `detect-agent-publish` のURLとキーを記載し、[trigger.sh](/azure/functions/test-scripts/upload-agent-to-github/trigger.sh)を実行すると、アラートが発報し、PR作成までの処理が起動します。
GitHub上でワークフローが起動し、PR作成が確認できたら成功です。

```
cd azure/functions/test-scripts/upload-agent-to-github
bash trigger.sh
```

### E2Eテスト

開発用のAI Foundryのプロジェクトでエージェントを新規作成・発行すると、アラート発報・Azure Functions起動・GitHub Actions起動を経てPRが作成されます。

![](/docs/aifoundry-dev-publish.png)

![](/docs/auto-generated-pr.png)

PRがマージされると、GitHub Actionsのワークフローが起動し、本番用のAI Foundryの `prod` プロジェクトに同名のエージェントが作成・発行されます。

![](/docs/prod-workflow.png)

![](/docs/prod-agent.png)

## 設計上のポイント

- [ログ検索アラート](https://learn.microsoft.com/ja-jp/azure/azure-monitor/alerts/tutorial-log-alert)ではKQLを用いた詳細なフィルタリングが可能であるため、Parse Log Functionの呼び出し回数を抑えることが可能ですが、課金が発生するため、今回は無料で利用可能なアクティビティログを採用しました ([参考: Azure MonitorでAgent Serviceのエージェントデプロイを自動検知する](https://zenn.dev/rtake/articles/412888054140d0#%E3%82%A2%E3%83%A9%E3%83%BC%E3%83%88%E3%81%AE%E7%A8%AE%E9%A1%9E%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6))
- アクティビティログの解析処理と、GitHub Actionsを起動してPull Requestを作成する処理を分離し、責務を明確にしました
- エージェント定義をGitHubにアップロードするworkflowはworkflow_dispatchで起動する構成としました。これにより、Azure FunctionsにGitHubのシークレットを持たせず、認証情報の管理範囲を最小化しました
- 開発環境での変更はPull Requestとして可視化し、レビュー・マージを経たものだけが本番環境に反映されるようにすることで、GitOpsとしての統制を担保しました

## 今後の改善点

- エージェントJSONを削除した際の挙動を修正する (https://github.com/rtake/azure-agentservice-gitops/actions/runs/23637637137/job/68850332115)
- GitHub Actions用のサービスプリンシパルをBicepでデプロイできるようにする
- Azure Functionsの環境変数の値をKey Vault等から安全に参照できるようにする(現在の構成ではデプロイのたびに環境変数の設定が必要)
- Parse Log Functionの呼び出し元をSecure webhookに限定し、アクショングループからのみ呼び出せるようにする ([セキュア Webhook アクション グループを作成する](https://learn.microsoft.com/ja-jp/azure/azure-monitor/alerts/itsm-connector-secure-webhook-connections-azure-configuration#create-a-secure-webhook-action-group))
- ネットワーク閉域化
