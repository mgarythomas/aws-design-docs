
import { encrypt, decrypt } from "../lib/encryption";
import { internalHandler } from "./index";
import { CorporateActionSchema } from "../shared/schema";

const sampleData: CorporateActionSchema = {
    corporateActionGeneralInformation: {
        officialCorporateActionEventID: "TEST-ENCRYPT-001",
        eventType: "DVCA",
        mandatoryVoluntaryEventType: "MAND"
    },
    underlyingSecurity: {
        isin: "US1234567890"
    },
    corporateActionDetails: {
        dates: {
            announcementDate: "2023-01-01",
            recordDate: "2023-01-15",
            paymentDate: "2023-01-20"
        }
    },
    options: [
        { optionNumber: "001", optionType: "CASH" }
    ]
};

async function test() {
    console.log("Testing Encryption Utility...");
    const original = "SecretMessage";
    const encrypted = encrypt(original);
    const decrypted = decrypt(encrypted);

    if (original === decrypted && original !== encrypted) {
        console.log("Encryption Utility: PASS");
    } else {
        console.error("Encryption Utility: FAIL");
        process.exit(1);
    }

    console.log("Testing Internal Service Encryption...");
    const result = await internalHandler(sampleData);
    if (result.status === "Success") {
        console.log("Internal Service Handler: PASS");
    } else {
        console.error("Internal Service Handler: FAIL");
        process.exit(1);
    }
}

test();
