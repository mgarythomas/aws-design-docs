import { describe, it, expect } from 'vitest';
import { handler } from './index';
import { APIGatewayProxyEvent } from 'aws-lambda';

describe('get-market-data-snapshot lambda', () => {
    it('should return 400 when figi is missing', async () => {
        const event = {
            pathParameters: {}
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(400);
        expect(JSON.parse(result.body).message).toBe('Missing figi parameter');
    });

    it('should return 200 and dummy data when figi is provided', async () => {
        const event = {
            pathParameters: {
                figi: 'BBG000BMQKR3'
            }
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(body.figi).toBe('BBG000BMQKR3');
        expect(body.entries).toHaveLength(2);
    });
});
