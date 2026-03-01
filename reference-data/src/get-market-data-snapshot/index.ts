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

        console.log(`Fetching market data snapshot for FIGI: ${figi}`);

        // TODO: Implement actual database/cache lookup
        const dummyResponse = {
            figi: figi,
            timestamp: new Date().toISOString(),
            entries: [
                {
                    entryType: "0", // Bid
                    price: 150.25
                },
                {
                    entryType: "1", // Offer
                    price: 150.30
                }
            ]
        };

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
