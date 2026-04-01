import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
  output,
} from "@azure/functions";
import { AgentDeploymentData } from "../azure/management";
import { QUEUE_CONNECTION_STRING, QUEUE_NAME } from "../azure/queue";

const AGENT_DEPLOYMENTS_OPERATION_NAME =
  "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write";
const AGENT_DEPLOYMENTS_MESSAGE =
  "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write";

const queueOutput = output.storageQueue({
  queueName: QUEUE_NAME,
  connection: QUEUE_CONNECTION_STRING,
});

export async function detectAgentPublish(
  req: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const body = (await req.json()) as any;
  const {
    data: { alertContext },
  } = body;
  // context.log("Alert context: %o", alertContext);

  const {
    operationName,
    properties: { entity, message },
  } = alertContext;

  if (operationName !== AGENT_DEPLOYMENTS_OPERATION_NAME) {
    return {
      status: 200,
      body: `operationName ${operationName} is not relevant, ignore`,
    };
  }

  if (message !== AGENT_DEPLOYMENTS_MESSAGE) {
    return {
      status: 200,
      body: `message ${message} is not relevant, ignore`,
    };
  }

  // Parse necessary information from the entity. The entity has a format like:
  // /subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.CognitiveServices/accounts/{accountName}/projects/{projectName}/applications/{appName}/agentDeployments/{deploymentName}
  const parts = entity.split("/");
  const subscriptionId = parts[2];
  const resourceGroup = parts[4];
  const accountName = parts[8];
  const projectName = parts[10];
  const appName = parts[12];
  const deploymentName = parts[14];
  context.log(
    "Parsed entity - subscriptionId: %o, resourceGroup: %o, accountName: %o, projectName: %o, appName: %o, deploymentName: %o",
    subscriptionId,
    resourceGroup,
    accountName,
    projectName,
    appName,
    deploymentName,
  );

  const agentData: AgentDeploymentData = {
    subscriptionId,
    resourceGroup,
    accountName,
    projectName,
    appName,
    deploymentName,
  };

  context.extraOutputs.set(queueOutput, agentData);
  // context.log("Sent message to queue %o", QUEUE_NAME);

  return {
    status: 202,
    body: `Agent published at ${accountName}/${projectName}`,
  };
}

app.http("detect-agent-publish", {
  methods: ["POST"],
  authLevel: "anonymous",
  extraOutputs: [queueOutput],
  handler: detectAgentPublish,
});
