import { describe, it, expect } from 'vitest';
import { handler } from './index';
import { APIGatewayProxyEvent } from 'aws-lambda';

describe('get-calendar lambda', () => {
    it('should return 400 when businessCenter is missing', async () => {
        const event = {
            pathParameters: {}
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(400);
        expect(JSON.parse(result.body).message).toBe('Missing businessCenter parameter');
    });

    it('should return 200 and dummy data when businessCenter is provided', async () => {
        const event = {
            pathParameters: {
                businessCenter: 'AUSY'
            }
        } as unknown as APIGatewayProxyEvent;

        const result = await handler(event);
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(body.businessCenter).toBe('AUSY');
        expect(body.calendarYear).toBeDefined();
    });
});
