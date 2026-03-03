import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: './',
    fullyParallel: true,
    retries: 0,
    workers: 1,
    reporter: 'list',
    use: {
        // The DMZ Edge API Gateway base path
        baseURL: process.env.BASE_URL || 'https://api.yourdomain.com/v1',
        extraHTTPHeaders: {
            'Content-Type': 'application/json',
        },
    },
});
