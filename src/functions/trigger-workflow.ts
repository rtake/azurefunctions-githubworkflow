import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from "@azure/functions";
import { DefaultAzureCredential } from "@azure/identity";
import { fetchAgentDefinition } from "../azure/agent-service";
import { fetchAgentName } from "../azure/management";
import { triggerGitHubWorkflow } from "../github-actions/trigger-workflow";

const AGENT_DEPLOYMENTS_OPERATION_NAME =
  "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write";
const AGENT_DEPLOYMENTS_MESSAGE =
  "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write";

const NO_RELEVANT_OPERATION_MESSAGE = "Not relevant operation";

module.exports = async function (context, req) {
  console.log("Received request:", req);

  const {
    data: { alertContext },
  } = JSON.parse(req.rawBody);

  const {
    operationName,
    properties: { entity, message },
  } = alertContext;

  if (operationName !== AGENT_DEPLOYMENTS_OPERATION_NAME) {
    context.res = {
      status: 200,
      body: NO_RELEVANT_OPERATION_MESSAGE,
    };
    return;
  }

  if (message !== AGENT_DEPLOYMENTS_MESSAGE) {
    context.res = {
      status: 200,
      body: NO_RELEVANT_OPERATION_MESSAGE,
    };
    return;
  }

  try {
    const credential = new DefaultAzureCredential();

    const parts = entity.split("/");
    const subscriptionId = parts[2];
    const resourceGroup = parts[4];
    const accountName = parts[8];
    const projectName = parts[10];
    const appName = parts[12];
    const deploymentName = parts[14];

    const agentName = await fetchAgentName({
      credential,
      subscriptionId,
      resourceGroup,
      accountName,
      projectName,
      appName,
      deploymentName,
    });

    const agentDefinition = await fetchAgentDefinition({
      credential,
      accountName,
      projectName,
      agentName,
    });

    await triggerGitHubWorkflow(agentDefinition, deploymentName);
  } catch (err) {
    console.error("Error triggering GitHub workflow:", err);

    context.res = {
      status: 500,
      body: "Error triggering GitHub workflow",
    };
    return;
  }

  context.res = {
    status: 200,
    body: "Workflow triggered",
  };
};

app.http("trigger-workflow", {
  methods: ["POST"],
  authLevel: "function",
  handler: module.exports,
});
