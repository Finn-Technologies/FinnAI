/**
 * FinnAI In-App AI Response Reporting Service
 * Target Platform: Cloudflare Workers + KV Storage
 */

const ALLOWED_CATEGORIES = new Set([
  'harmfulOrDangerous',
  'hateOrHarassment',
  'sexualContent',
  'childSafety',
  'selfHarm',
  'illegalOrDeceptive',
  'falseOrMisleading',
  'other',
]);

const MAX_ASSISTANT_RESPONSE_LENGTH = 4000;
const MAX_USER_PROMPT_LENGTH = 2000;
const MAX_ADDITIONAL_DETAILS_LENGTH = 1000;
const MAX_REPORTS_PER_HOUR = 10;

async function hashKey(ip, salt) {
  const hour = new Date().toISOString().substring(0, 13); // YYYY-MM-DDTHH
  const encoder = new TextEncoder();
  const data = encoder.encode(`${ip}:${salt}:${hour}`);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Endpoint route verification
    if (request.method !== 'POST' || url.pathname !== '/v1/reports') {
      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // MANDATORY KV BINDING VERIFICATION: Return HTTP 503 if REPORTS_KV binding is missing
    if (!env || !env.REPORTS_KV) {
      return new Response(
        JSON.stringify({ error: 'Reporting service storage unconfigured' }),
        {
          status: 503,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Content-Type validation
    const contentType = request.headers.get('content-type') || '';
    if (!contentType.includes('application/json')) {
      return new Response(
        JSON.stringify({ error: 'Content-Type must be application/json' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Durable Rate Limiting via KV
    const clientIp =
      request.headers.get('cf-connecting-ip') ||
      request.headers.get('x-forwarded-for') ||
      '127.0.0.1';
    const serverSalt = env.RATE_LIMIT_SALT || 'finn_ai_default_salt_2026';
    const rateLimitHash = await hashKey(clientIp, serverSalt);
    const rateLimitKey = `ratelimit:${rateLimitHash}`;

    const currentCountStr = await env.REPORTS_KV.get(rateLimitKey);
    const currentCount = currentCountStr ? parseInt(currentCountStr, 10) : 0;

    if (currentCount >= MAX_REPORTS_PER_HOUR) {
      return new Response(
        JSON.stringify({ error: 'Too many reports submitted. Please try again later.' }),
        {
          status: 429,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    try {
      const body = await request.json();
      const {
        reportId,
        category,
        assistantResponse,
        timestamp,
        appVersion,
        modelTier,
        userPrompt,
        additionalDetails,
      } = body;

      // Validate required fields
      if (
        !reportId ||
        typeof reportId !== 'string' ||
        !category ||
        !assistantResponse ||
        typeof assistantResponse !== 'string' ||
        !timestamp ||
        !appVersion ||
        !modelTier
      ) {
        return new Response(
          JSON.stringify({ error: 'Missing or invalid required report fields' }),
          {
            status: 400,
            headers: { 'Content-Type': 'application/json' },
          }
        );
      }

      // Allowlist validation for category
      if (!ALLOWED_CATEGORIES.has(category)) {
        return new Response(JSON.stringify({ error: 'Invalid report category' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Enforce payload length limits
      if (
        assistantResponse.length > MAX_ASSISTANT_RESPONSE_LENGTH ||
        (userPrompt && userPrompt.length > MAX_USER_PROMPT_LENGTH) ||
        (additionalDetails && additionalDetails.length > MAX_ADDITIONAL_DETAILS_LENGTH)
      ) {
        return new Response(
          JSON.stringify({ error: 'Report content exceeds character limits' }),
          {
            status: 400,
            headers: { 'Content-Type': 'application/json' },
          }
        );
      }

      // Increment rate limit counter in KV (1 hour TTL)
      await env.REPORTS_KV.put(rateLimitKey, (currentCount + 1).toString(), {
        expirationTtl: 3600,
      });

      // Construct privacy-preserving report record (NO IP stored)
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

      // Store in Cloudflare KV
      await env.REPORTS_KV.put(`report:${reportId}`, JSON.stringify(reportRecord));

      return new Response(JSON.stringify({ success: true, reportId }), {
        status: 201,
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: 'Invalid JSON payload' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }
  },
};
