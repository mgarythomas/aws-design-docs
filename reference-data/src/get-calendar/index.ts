import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
        const businessCenter = event.pathParameters?.businessCenter;

        if (!businessCenter) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'Missing businessCenter parameter' })
            };
        }

        console.log(`Fetching trading calendar for Business Center: ${businessCenter}`);

        // TODO: Implement actual database lookup
        const dummyResponse = {
            businessCenter: businessCenter,
            calendarYear: new Date().getFullYear(),
            holidays: [
                `${new Date().getFullYear()}-01-01`,
                `${new Date().getFullYear()}-12-25`
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
