
import { CorporateActionSchema } from "../shared/schema";
import { encrypt } from "@/lib/encryption";

// Mock database (in-memory for simulation)
const db: { id: string, encryptedData: string }[] = [];

/**
 * Internal Service Handler
 * This function is triggered by an event (e.g., from SQS/EventBridge via Lambda).
 * It processes the corporate action submission asynchronously.
 */
export const internalHandler = async (data: CorporateActionSchema) => {
  console.log("Internal Service: Processing event...", JSON.stringify(data, null, 2));

  // Business Logic: Check for duplicates
  const idToCheck = data.corporateActionGeneralInformation.officialCorporateActionEventID;
  const exists = db.find(item => item.id === idToCheck);

  if (exists) {
      console.warn(`Internal Service: Duplicate submission detected for ID: ${idToCheck}`);
      return { status: "Conflict", message: "Duplicate ID" };
  }

  // Encrypt the payload before storing
  let encryptedPayload = "";
  try {
      const payloadString = JSON.stringify(data);
      encryptedPayload = encrypt(payloadString);
  } catch (error) {
      console.error("Internal Service: Encryption failed. Check ENCRYPTION_KEY env var.", error);
      // In a real async flow, we would probably retry or dead-letter this.
      // For simulation, we log error but continue (or could return error status)
      return { status: "Error", message: "Encryption Failed" };
  }

  // Simulate DB save (latency)
  await new Promise(resolve => setTimeout(resolve, 500));

  db.push({
      id: idToCheck,
      encryptedData: encryptedPayload
  });

  console.log(`Internal Service: Successfully saved ENCRYPTED Corporate Action ${idToCheck}`);
  console.log("Internal Service: Current DB count:", db.length);
  console.log("Internal Service: Last encrypted entry:", encryptedPayload.substring(0, 50) + "...");

  return { status: "Success", id: idToCheck };
};
