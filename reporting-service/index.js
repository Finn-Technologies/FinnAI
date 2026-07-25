/**
 * FinnAI In-App AI Response Reporting Service
 * Compatible with Cloudflare Workers, Vercel Serverless, or Node.js Hono/Express.
 */

const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const MAX_REPORTS_PER_WINDOW = 10;
const ipRequestCounts = new Map();

function isRateLimited(ip) {
  const now = Date.now();
  const entry = ipRequestCounts.get(ip) || { count: 0, resetTime: now + RATE_LIMIT_WINDOW_MS };
  if (now > entry.resetTime) {
    entry.count = 0;
    entry.resetTime = now + RATE_LIMIT_WINDOW_MS;
  }
  entry.count += 1;
  ipRequestCounts.set(ip, entry);
  return entry.count > MAX_REPORTS_PER_WINDOW;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Only accept POST to /v1/reports
    if (request.method !== 'POST' || url.pathname !== '/v1/reports') {
      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const clientIp = request.headers.get('cf-connecting-ip') || request.headers.get('x-forwarded-for') || '127.0.0.1';
    if (isRateLimited(clientIp)) {
      return new Response(JSON.stringify({ error: 'Too many reports submitted. Please try again later.' }), {
        status: 429,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    try {
      const body = await request.json();
      const { reportId, category, assistantResponse, timestamp, appVersion, modelTier, userPrompt, additionalDetails } = body;

      // Validate required fields
      if (!reportId || !category || !assistantResponse || !timestamp || !appVersion || !modelTier) {
        return new Response(JSON.stringify({ error: 'Missing required report fields' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Enforce bounded payload size limits
      if (assistantResponse.length > 32000 || (userPrompt && userPrompt.length > 32000)) {
        return new Response(JSON.stringify({ error: 'Report content exceeds size limits' }), {
          status: 413,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const reportRecord = {
        reportId,
        category,
        assistantResponse,
        timestamp,
        serverReceivedAt: new Date().toISOString(),
        appVersion,
        modelTier,
        userPrompt: userPrompt || null,
        additionalDetails: additionalDetails || null,
      };

      // Store in KV or database if environment bindings exist
      if (env && env.REPORTS_KV) {
        await env.REPORTS_KV.put(`report:${reportId}`, JSON.stringify(reportRecord));
      } else {
        console.log('[FINN_REPORT_RECEIVED]', JSON.stringify(reportRecord));
      }

      return new Response(JSON.stringify({ success: true, reportId }), {
        status: 201,
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (err) {
      console.error('Report processing error:', err);
      return new Response(JSON.stringify({ error: 'Invalid JSON payload' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }
  },
};
