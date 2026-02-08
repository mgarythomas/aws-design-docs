import { NextResponse } from 'next/server';
import { dmzHandler } from '@/services-backend/dmz/index';

export async function POST(request: Request) {
  try {
    const data = await request.json();
    console.log("API Route: Received submission");

    // Simulate Lambda event structure if needed, or just pass body
    const result = await dmzHandler(data);

    // dmzHandler returns { statusCode, body: string }
    return NextResponse.json(JSON.parse(result.body), { status: result.statusCode });
  } catch (error: any) {
    console.error("API Error:", error);
    return NextResponse.json({ message: "Internal Server Error", error: error.message }, { status: 500 });
  }
}
