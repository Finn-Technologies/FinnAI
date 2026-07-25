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

const ALLOWED_FIELDS = new Set([
  'reportId',
  'category',
  'assistantResponse',
  'timestamp',
  'appVersion',
  'modelTier',
  'userPrompt',
  'additionalDetails',
]);

const MAX_ASSISTANT_RESPONSE_LENGTH = 4000;
const MAX_USER_PROMPT_LENGTH = 2000;
const MAX_ADDITIONAL_DETAILS_LENGTH = 1000;
const MAX_REPORTS_PER_HOUR = 10;
const REPORT_RETENTION_TTL_SECONDS = 30 * 24 * 3600; // 30 days retention

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

    // MANDATORY BINDING & SALT VERIFICATION: Return HTTP 503 if REPORTS_KV or RATE_LIMIT_SALT is missing
    if (!env || !env.REPORTS_KV || !env.RATE_LIMIT_SALT || typeof env.RATE_LIMIT_SALT !== 'string' || !env.RATE_LIMIT_SALT.trim()) {
      return new Response(
        JSON.stringify({ error: 'Reporting service configuration incomplete (REPORTS_KV or RATE_LIMIT_SALT missing)' }),
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
    const rateLimitHash = await hashKey(clientIp, env.RATE_LIMIT_SALT);
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
      if (!body || typeof body !== 'object' || Array.isArray(body)) {
        return new Response(JSON.stringify({ error: 'Payload must be a JSON object' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Reject unknown fields
      for (const key of Object.keys(body)) {
        if (!ALLOWED_FIELDS.has(key)) {
          return new Response(
            JSON.stringify({ error: `Unknown field '${key}' in report payload` }),
            {
              status: 400,
              headers: { 'Content-Type': 'application/json' },
            }
          );
        }
      }

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

      // Validate reportId format
      if (!reportId || typeof reportId !== 'string' || reportId.length > 100 || !/^[a-zA-Z0-9_-]+$/.test(reportId)) {
        return new Response(JSON.stringify({ error: 'Invalid or missing reportId' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Validate timestamp
      if (!timestamp || typeof timestamp !== 'string' || isNaN(Date.parse(timestamp))) {
        return new Response(JSON.stringify({ error: 'Invalid or missing timestamp' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Validate types and lengths of required fields
      if (
        !category || typeof category !== 'string' ||
        !assistantResponse || typeof assistantResponse !== 'string' ||
        !appVersion || typeof appVersion !== 'string' || appVersion.length > 50 ||
        !modelTier || typeof modelTier !== 'string' || modelTier.length > 100
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
        (userPrompt && (typeof userPrompt !== 'string' || userPrompt.length > MAX_USER_PROMPT_LENGTH)) ||
        (additionalDetails && (typeof additionalDetails !== 'string' || additionalDetails.length > MAX_ADDITIONAL_DETAILS_LENGTH))
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

      // Store in Cloudflare KV with 30-day retention TTL
      await env.REPORTS_KV.put(`report:${reportId}`, JSON.stringify(reportRecord), {
        expirationTtl: REPORT_RETENTION_TTL_SECONDS,
      });

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
