import { corporateActionSchema } from "../shared/schema";
import { internalHandler } from "../internal/index";

export const dmzHandler = async (event: any) => {
  console.log("DMZ Service: Received submission");

  // Validate schema
  const result = corporateActionSchema.safeParse(event);

  if (!result.success) {
    console.error("DMZ Service: Validation failed", result.error);
    return {
      statusCode: 400,
      body: JSON.stringify({ message: "Validation failed", errors: result.error.format() }),
    };
  }

  console.log("DMZ Service: Validation successful. Forwarding to Internal Service...");

  // Forward to Internal Service
  // In a real scenario, this would be an API call via Internal API Gateway
  const response = await internalHandler(result.data);

  return response;
};
