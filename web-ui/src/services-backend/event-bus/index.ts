
import { internalHandler } from "../internal/index";

/**
 * Simulates an AWS EventBridge or SQS Queue.
 * In a real deployment, this would use AWS SDK to putEvents or sendMessage.
 */
export const publishEvent = async (source: string, detailType: string, detail: any) => {
  console.log(`[EventBus] Published event: Source=${source}, Type=${detailType}`);

  // Simulate Async Processing (e.g., SQS triggering Lambda)
  // We use setImmediate or setTimeout to decouple the execution from the request response
  setTimeout(async () => {
    try {
      console.log(`[EventBus] Processing event asynchronously...`);
      await internalHandler(detail);
      console.log(`[EventBus] Event processed successfully.`);
    } catch (error) {
      console.error(`[EventBus] Error processing event:`, error);
    }
  }, 1000); // 1 second delay to simulate network/queue latency

  return {
    eventId: `evt-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    status: "Published"
  };
};
