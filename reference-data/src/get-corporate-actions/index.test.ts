import { describe, it, expect } from 'vitest';
import { handler } from './index';
import { APIGatewayProxyEvent } from 'aws-lambda';

describe('get-corporate-actions lambda', () => {
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
                figi: 'BBG000DUMMY1'
            }
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(Array.isArray(body)).toBe(true);
        expect(body[0].figi).toBe('BBG000DUMMY1');
    });
});
