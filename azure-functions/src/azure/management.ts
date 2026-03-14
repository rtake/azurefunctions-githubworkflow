import { DefaultAzureCredential } from "@azure/identity";

const SCOPE = "https://management.azure.com/.default";

export const fetchAgentName = async ({
  credential,
  subscriptionId,
  resourceGroup,
  accountName,
  projectName,
  appName,
  deploymentName,
}: {
  credential: DefaultAzureCredential;
  subscriptionId: string;
  resourceGroup: string;
  accountName: string;
  projectName: string;
  appName: string;
  deploymentName: string;
}): Promise<string> => {
  const token = await credential.getToken(SCOPE);

  const url =
    `https://management.azure.com/subscriptions/${subscriptionId}` +
    `/resourceGroups/${resourceGroup}` +
    `/providers/Microsoft.CognitiveServices/accounts/${accountName}` +
    `/projects/${projectName}/applications/${appName}` +
    `/agentDeployments/${deploymentName}` +
    `?api-version=2025-10-01-preview`;

  const deploymentRes = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token.token}`,
    },
  });
  const deployment = await deploymentRes.json();
  const { agentName } = deployment.properties.agents[0];

  return agentName;
};
