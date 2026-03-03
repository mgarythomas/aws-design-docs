"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
const index_1 = require("./index");
(0, vitest_1.describe)('get-issuer lambda', () => {
    (0, vitest_1.it)('should return 400 when lei is missing', async () => {
        const event = {
            pathParameters: {}
        };
        const result = await (0, index_1.handler)(event);
        (0, vitest_1.expect)(result.statusCode).toBe(400);
        (0, vitest_1.expect)(JSON.parse(result.body).message).toBe('Missing lei parameter');
    });
    (0, vitest_1.it)('should return 200 and dummy data when lei is provided', async () => {
        const event = {
            pathParameters: {
                lei: '549300G19KEE21R33259'
            }
        };
        const result = await (0, index_1.handler)(event);
        (0, vitest_1.expect)(result.statusCode).toBe(200);
        const body = JSON.parse(result.body);
        (0, vitest_1.expect)(body.lei).toBe('549300G19KEE21R33259');
        (0, vitest_1.expect)(body.legalName).toBe('Dummy Issuer Corp');
    });
});
