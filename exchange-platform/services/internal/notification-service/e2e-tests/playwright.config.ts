import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: './tests',
    fullyParallel: true,
    retries: process.env.CI ? 2 : 0,
    workers: process.env.CI ? 1 : undefined,
    reporter: 'html',
    use: {
        // DMZ endpoint or Internal endpoint based on testing scope. 
        // We'll target the internal service mock initially since DMZ lambda routing to EKS isn't complete yet.
        baseURL: process.env.BASE_URL || 'http://localhost:8080',
        extraHTTPHeaders: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        },
    },
});
