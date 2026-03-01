import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: './',
    fullyParallel: true,
    retries: 0,
    workers: 1,
    reporter: 'list',
    use: {
        // Assuming Docker Compose maps Spring Boot to port 8080 locally
        baseURL: process.env.BASE_URL || 'http://localhost:8080',
        extraHTTPHeaders: {
            'Content-Type': 'application/json',
        },
    },
});
