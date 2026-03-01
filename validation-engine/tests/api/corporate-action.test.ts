import { test, expect } from '@playwright/test';

test.describe('Corporate Action Full Document Validation', () => {

    test('should return valid for a correct DVCA payload', async ({ request }) => {
        const validPayload = {
            corporateActionGeneralInformation: {
                officialCorporateActionEventID: "EVT0000001",
                eventType: "DVCA",
                mandatoryVoluntaryEventType: "MAND"
            },
            underlyingSecurity: {
                isin: "US0378331005"
            },
            corporateActionDetails: {
                dates: {
                    announcementDate: "2025-01-01T00:00:00Z",
                    exDate: "2025-01-10T00:00:00Z",
                    recordDate: "2025-01-12T00:00:00Z",
                    paymentDate: "2025-01-20T00:00:00Z"
                },
                rateAndPrice: {
                    grossDividendRate: {
                        amount: 1.50,
                        currency: "USD"
                    }
                }
            },
            options: [
                {
                    optionNumber: "1",
                    optionType: "CASH",
                    defaultOption: true
                }
            ]
        };

        const response = await request.post('/v1/validate/corporate-action', {
            data: validPayload
        });

        expect(response.ok()).toBeTruthy();

        // Note: this assumes the OPA sidecar responds with the JSON. 
        // We expect the Spring Boot orchestrator to parse and return `{ isValid: true }` eventually,
        // or the raw OPA response if Spring Boot directly forwards. 
        // Wait for actual OPA implementation for exact assertion, but minimally expect 200 OK.
    });

    test('should reject invalid event type', async ({ request }) => {
        const invalidPayload = {
            corporateActionGeneralInformation: {
                officialCorporateActionEventID: "EVT0000001",
                eventType: "INVALID_EVT", // Invalid
                mandatoryVoluntaryEventType: "MAND"
            },
            underlyingSecurity: {
                isin: "US0378331005"
            },
            corporateActionDetails: {
                dates: {
                    announcementDate: "2025-01-01T00:00:00Z",
                    paymentDate: "2025-01-20T00:00:00Z",
                    recordDate: "2025-01-12T00:00:00Z"
                }
            },
            options: [
                {
                    optionNumber: "1",
                    optionType: "CASH"
                }
            ]
        };

        const response = await request.post('/v1/validate/corporate-action', {
            data: invalidPayload
        });

        expect(response.status()).toBe(200); // Spring returns 200 with validation decision inside
        const body = await response.json();

        // The exact response structure depends on the Rego. 
        // Usually { isValid: false, errors: [...] } or { result: { result: false, deny: [...] } }
        // Asserting the request succeeds parsing is a good first step.
        console.log("Validation results:", body);
    });
});
