import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: './',
    fullyParallel: true,
    retries: 0,
    workers: 1,
    reporter: 'list',
    use: {
        // The Internal Core API Gateway base path
        baseURL: process.env.BASE_URL || 'https://api.yourdomain.com/internal/v1',
        extraHTTPHeaders: {
            'Content-Type': 'application/json',
        },
    },
});
