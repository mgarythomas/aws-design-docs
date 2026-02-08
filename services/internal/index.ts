import { CorporateActionSchema } from "../shared/schema";

// Mock database
const db: CorporateActionSchema[] = [];

export const internalHandler = async (data: CorporateActionSchema) => {
  console.log("Internal Service: Received data", JSON.stringify(data, null, 2));

  // Business Logic: Check for duplicates, etc.
  const exists = db.find(item => item.corporateActionGeneralInformation.officialCorporateActionEventID === data.corporateActionGeneralInformation.officialCorporateActionEventID);

  if (exists) {
      console.warn("Internal Service: Duplicate submission detected");
      return {
          statusCode: 409, // Conflict
          body: JSON.stringify({ message: "Duplicate submission: Official Corporate Action Event ID already exists." })
      }
  }

  // Simulate DB save
  db.push(data);
  console.log("Internal Service: Saved to database (simulated)");
  console.log("Current DB count:", db.length);

  return {
    statusCode: 200,
    body: JSON.stringify({ message: "Submission accepted and processed successfully", id: data.corporateActionGeneralInformation.officialCorporateActionEventID }),
  };
};
