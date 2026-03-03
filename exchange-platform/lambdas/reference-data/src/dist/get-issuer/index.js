"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handler = void 0;
const handler = async (event) => {
    try {
        const lei = event.pathParameters?.lei;
        if (!lei) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'Missing lei parameter' })
            };
        }
        console.log(`Fetching issuer data for LEI: ${lei}`);
        // TODO: Implement actual database lookup
        const dummyResponse = {
            lei: lei,
            legalName: "Dummy Issuer Corp",
            legalJurisdiction: "US",
            status: "ACTIVE",
            industryClassifications: []
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
