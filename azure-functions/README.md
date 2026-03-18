GitHub Actionsのワークフローを実行するAzure Functions

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
