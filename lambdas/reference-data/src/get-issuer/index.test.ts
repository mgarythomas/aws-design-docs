import { describe, it, expect } from 'vitest';
import { handler } from './index';
import { APIGatewayProxyEvent } from 'aws-lambda';

describe('get-issuer lambda', () => {
    it('should return 400 when lei is missing', async () => {
        const event = {
            pathParameters: {}
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(400);
        expect(JSON.parse(result.body).message).toBe('Missing lei parameter');
    });

    it('should return 200 and dummy data when lei is provided', async () => {
        const event = {
            pathParameters: {
                lei: '549300G19KEE21R33259'
            }
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(body.lei).toBe('549300G19KEE21R33259');
        expect(body.legalName).toBe('Dummy Issuer Corp');
    });
});
