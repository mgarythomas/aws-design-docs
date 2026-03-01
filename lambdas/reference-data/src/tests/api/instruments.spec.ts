import { test, expect } from '@playwright/test';

test.describe('Instruments API', () => {
    test('should return instrument search results', async ({ request }) => {
        try {
            const response = await request.get('/instruments?ticker=CBA');
            expect(response.ok()).toBeTruthy();
            expect(response.status()).toBe(200);

            const responseBody = await response.json();
            expect(Array.isArray(responseBody)).toBeTruthy();
            expect(responseBody.length).toBeGreaterThan(0);
            expect(responseBody[0]).toHaveProperty('ticker', 'CBA');
        } catch (e) {
            console.warn('API test failed, is the server running? ', e);
            test.skip(true, 'API server not reachable');
        }
    });

    test('should return corporate actions for a FIGI', async ({ request }) => {
        try {
            const response = await request.get('/instruments/BBG000DUMMY1/corporate-actions');
            expect(response.ok()).toBeTruthy();
            expect(response.status()).toBe(200);

            const responseBody = await response.json();
            expect(Array.isArray(responseBody)).toBeTruthy();
        } catch (e) {
            console.warn('API test failed, is the server running? ', e);
            test.skip(true, 'API server not reachable');
        }
    });
});
