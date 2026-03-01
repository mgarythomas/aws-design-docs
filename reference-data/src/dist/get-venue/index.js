"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handler = void 0;
const handler = async (event) => {
    try {
        const mic = event.pathParameters?.mic;
        if (!mic) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'Missing mic parameter' })
            };
        }
        console.log(`Fetching venue data for MIC: ${mic}`);
        // TODO: Implement actual database lookup
        const dummyResponse = {
            mic: mic,
            name: "Dummy Venue",
            countryCode: "US",
            status: "ACTIVE"
        };
        return {
            statusCode: 200,
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(dummyResponse),
        };
    }
    catch (err) {
        console.error(err);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Internal Server Error' }),
        };
    }
};
exports.handler = handler;
