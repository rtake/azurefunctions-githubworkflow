GitHub Actionsのワークフローを実行するAzure Functions

## Azure

### リソース作成

```
# リソースグループ作成
az group create --name <ResourceGroupName> -l <RegionName>

# リソース作成
az deployment group create --resource-group <ResourceGroupName> --template-file infra/main.bicep  -p infra/param.bicepparam

# Dry-run
az deployment group what-if -g <ResourceGroupName> -p infra/param.bicepparam

# パラメータの中で定義している場合Bicepを指定しなくてもOK
az deployment group create -g <ResourceGroupName> -p infra/param.bicepparam
```

### デプロイ

```
func azure functionapp publish <FunctionAppName>
```

### ロール割り当て

デプロイしたFunctionsにCognitive Serviceユーザーロールを割り当てる

## GitHub Actions

### エージェント定義アップロード用ワークフロー

エージェント定義をJSON形式で保存し、コミット・Push・PR作成まで実行するワークフロー
Dev環境のAI Foundryにおけるエージェント発行をトリガーとして起動するAzure Functionsによって起動する

### エージェントデプロイ用ワークフロー

mainブランチへのマージ時にエージェントをProd環境のAI Foundryに発行するワークフロー

#### 設定

リポジトリのSecretに以下の変数を設定する

| 変数名                     | 概要                                                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| AZURE_SUBSCRIPTION_ID      | 操作対象のAI Foundryが含まれているサブスクリプションのID                                                                |
| AIFOUNDRY_PROJECT_ENDPOINT | AI Foundryのエンドポイント (例: `https://{ai-services-account-name}.services.ai.azure.com/api/projects/{project-name}`) |
| AZURE_TENANT_ID            | GitHub Actions用のエンタープライズアプリケーションが含まれているテナントのID                                            |
| AZURE_CLIENT_ID            | GitHub Actions用のエンタープライズアプリケーションのID                                                                  |

|
