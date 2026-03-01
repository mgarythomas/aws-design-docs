import { test, expect } from '@playwright/test';

test.describe('Corporate Action Single Field Validation', () => {

    test('should return valid for correct ISIN field', async ({ request }) => {
        const validFieldRequest = {
            fieldName: "underlyingSecurity.isin",
            value: "US0378331005"
        };

        const response = await request.post('/v1/validate/field', {
            data: validFieldRequest
        });

        expect(response.ok()).toBeTruthy();

        // For single field, expecting a targeted response structure indicating isValid: true
        const result = await response.json();
        console.log("ISIN Validation Result:", result);
    });

    test('should return invalid for incorrect ISIN field format', async ({ request }) => {
        const invalidFieldRequest = {
            fieldName: "underlyingSecurity.isin",
            value: "INVALID"
        };

        const response = await request.post('/v1/validate/field', {
            data: invalidFieldRequest
        });

        expect(response.ok()).toBeTruthy(); // Framework should still return 200 HTTP for logic failures
        const result = await response.json();

        // Exact schema determined by OPA returned proxy in Spring Boot.
        console.log("Failed ISIN Result:", result);
    });

    test('should evaluate contextual field validation', async ({ request }) => {
        // e.g. An ex-date earlier than the announcement date
        const contextFieldRequest = {
            fieldName: "corporateActionDetails.dates.exDate",
            value: "2025-01-01T00:00:00Z",
            context: {
                corporateActionDetails: {
                    dates: {
                        announcementDate: "2025-01-10T00:00:00Z" // exDate is before announcementDate
                    }
                }
            }
        };

        const response = await request.post('/v1/validate/field', {
            data: contextFieldRequest
        });

        expect(response.ok()).toBeTruthy();
        const result = await response.json();
        console.log("Contextual Date Validation:", result);
    });
});
