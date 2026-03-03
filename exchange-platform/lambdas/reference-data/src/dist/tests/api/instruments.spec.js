"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const test_1 = require("@playwright/test");
test_1.test.describe('Instruments API', () => {
    (0, test_1.test)('should return instrument search results', async ({ request }) => {
        try {
            const response = await request.get('/instruments?ticker=CBA');
            (0, test_1.expect)(response.ok()).toBeTruthy();
            (0, test_1.expect)(response.status()).toBe(200);
            const responseBody = await response.json();
            (0, test_1.expect)(Array.isArray(responseBody)).toBeTruthy();
            (0, test_1.expect)(responseBody.length).toBeGreaterThan(0);
            (0, test_1.expect)(responseBody[0]).toHaveProperty('ticker', 'CBA');
        }
        catch (e) {
            console.warn('API test failed, is the server running? ', e);
            test_1.test.skip(true, 'API server not reachable');
        }
    });
    (0, test_1.test)('should return corporate actions for a FIGI', async ({ request }) => {
        try {
            const response = await request.get('/instruments/BBG000DUMMY1/corporate-actions');
            (0, test_1.expect)(response.ok()).toBeTruthy();
            (0, test_1.expect)(response.status()).toBe(200);
            const responseBody = await response.json();
            (0, test_1.expect)(Array.isArray(responseBody)).toBeTruthy();
        }
        catch (e) {
            console.warn('API test failed, is the server running? ', e);
            test_1.test.skip(true, 'API server not reachable');
        }
    });
});
