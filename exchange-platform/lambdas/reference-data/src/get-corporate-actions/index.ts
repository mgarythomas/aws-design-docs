import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
        const figi = event.pathParameters?.figi;

        if (!figi) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'Missing figi parameter' })
            };
        }

        console.log(`Fetching corporate actions for FIGI: ${figi}`);

        // TODO: Implement actual database lookup
        const dummyResponse = [
            {
                eventId: "CA-2026-001",
                eventType: "DVCA",
                figi: figi,
                exDate: "2026-03-15",
                terms: {
                    grossDividendRate: 1.50,
                    currency: "USD"
                }
            }
        ];

        return {
            statusCode: 200,
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(dummyResponse),
        };
    } catch (err) {
        console.error(err);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Internal Server Error' }),
        };
    }
};
