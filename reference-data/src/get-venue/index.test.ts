import { describe, it, expect } from 'vitest';
import { handler } from './index';
import { APIGatewayProxyEvent } from 'aws-lambda';

describe('get-venue lambda', () => {
    it('should return 400 when mic is missing', async () => {
        const event = {
            pathParameters: {}
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(400);
        expect(JSON.parse(result.body).message).toBe('Missing mic parameter');
    });

    it('should return 200 and dummy data when mic is provided', async () => {
        const event = {
            pathParameters: {
                mic: 'XASX'
            }
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(body.mic).toBe('XASX');
        expect(body.status).toBe('ACTIVE');
    });
});
