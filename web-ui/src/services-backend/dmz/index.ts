
import { corporateActionSchema } from "../shared/schema";
import { publishEvent } from "../event-bus/index";

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

  console.log("DMZ Service: Validation successful. Publishing event to Internal Service...");

  // Publish Event for Async Processing (Simulates SQS/EventBridge)
  const eventResult = await publishEvent(
    "com.mycorp.corporate-actions.dmz",
    "CorporateActionSubmission",
    result.data
  );

  console.log(`DMZ Service: Event published successfully. ID: ${eventResult.eventId}`);

  return {
    statusCode: 202, // Accepted
    body: JSON.stringify({
      message: "Submission received and queued for processing.",
      eventId: eventResult.eventId
    }),
  };
};
