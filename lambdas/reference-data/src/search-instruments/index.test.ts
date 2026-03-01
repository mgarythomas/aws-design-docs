import { describe, it, expect } from 'vitest';
import { handler } from './index';
import { APIGatewayProxyEvent } from 'aws-lambda';

describe('search-instruments lambda', () => {
    it('should return 200 and dummy data when searching by ticker', async () => {
        const event = {
            queryStringParameters: {
                ticker: 'CBA'
            }
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(Array.isArray(body)).toBe(true);
        expect(body[0].ticker).toBe('CBA');
    });

    it('should return 200 and generic dummy data when query params are missing', async () => {
        const event = {
            queryStringParameters: null
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(200);
        const body = JSON.parse(result.body);
        expect(body[0].ticker).toBe('DUMMY');
    });
});
