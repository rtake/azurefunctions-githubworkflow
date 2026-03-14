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

export async function triggerWorkflow(
  req: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  context.log("Received request: %o", req);

  const body = (await req.json()) as any;
  const {
    data: { alertContext },
  } = body;
  context.log("Alert context: %o", alertContext);

  const {
    operationName,
    properties: { entity, message },
  } = alertContext;

  if (operationName !== AGENT_DEPLOYMENTS_OPERATION_NAME) {
    return {
      status: 200,
      body: NO_RELEVANT_OPERATION_MESSAGE,
    };
  }

  if (message !== AGENT_DEPLOYMENTS_MESSAGE) {
    return {
      status: 200,
      body: NO_RELEVANT_OPERATION_MESSAGE,
    };
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
    context.log("agentName: %o", agentName);

    const agentDefinition = await fetchAgentDefinition({
      credential,
      accountName,
      projectName,
      agentName,
    });
    context.log("agentDefinition: %o", agentDefinition);

    const triggerResult = await triggerGitHubWorkflow(
      agentDefinition,
      deploymentName,
    );
    context.log("GitHub workflow trigger result: %o", triggerResult);
  } catch (err) {
    context.error("Error triggering GitHub workflow:", err);

    return {
      status: 500,
      body: "Error triggering GitHub workflow",
    };
  }

  return {
    status: 200,
    body: "Workflow triggered",
  };
}

app.http("export-agent", {
  methods: ["POST"],
  authLevel: "function",
  handler: triggerWorkflow,
});
