"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
const index_1 = require("./index");
(0, vitest_1.describe)('search-instruments lambda', () => {
    (0, vitest_1.it)('should return 200 and dummy data when searching by ticker', async () => {
        const event = {
            queryStringParameters: {
                ticker: 'CBA'
            }
        };
        const result = await (0, index_1.handler)(event);
        (0, vitest_1.expect)(result.statusCode).toBe(200);
        const body = JSON.parse(result.body);
        (0, vitest_1.expect)(Array.isArray(body)).toBe(true);
        (0, vitest_1.expect)(body[0].ticker).toBe('CBA');
    });
    (0, vitest_1.it)('should return 200 and generic dummy data when query params are missing', async () => {
        const event = {
            queryStringParameters: null
        };
        const result = await (0, index_1.handler)(event);
        (0, vitest_1.expect)(result.statusCode).toBe(200);
        const body = JSON.parse(result.body);
        (0, vitest_1.expect)(body[0].ticker).toBe('DUMMY');
    });
});
