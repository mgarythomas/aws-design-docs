import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
        const ticker = event.queryStringParameters?.ticker;
        const mic = event.queryStringParameters?.mic;

        console.log(`Searching instruments for ticker: ${ticker}, mic: ${mic}`);

        // TODO: Implement actual database lookup
        const dummyResponse = [
            {
                figi: "BBG000DUMMY1",
                issuerLei: "12345678901234567890",
                ticker: ticker || "DUMMY",
                mic: mic || "XNYS",
                assetClass: "EQUITY",
                currency: "USD"
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
