"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
const index_1 = require("./index");
(0, vitest_1.describe)('get-market-data-snapshot lambda', () => {
    (0, vitest_1.it)('should return 400 when figi is missing', async () => {
        const event = {
            pathParameters: {}
        };
        const result = await (0, index_1.handler)(event);
        (0, vitest_1.expect)(result.statusCode).toBe(400);
        (0, vitest_1.expect)(JSON.parse(result.body).message).toBe('Missing figi parameter');
    });
    (0, vitest_1.it)('should return 200 and dummy data when figi is provided', async () => {
        const event = {
            pathParameters: {
                figi: 'BBG000BMQKR3'
            }
        };
        const result = await (0, index_1.handler)(event);
        (0, vitest_1.expect)(result.statusCode).toBe(200);
        const body = JSON.parse(result.body);
        (0, vitest_1.expect)(body.figi).toBe('BBG000BMQKR3');
        (0, vitest_1.expect)(body.entries).toHaveLength(2);
    });
});
