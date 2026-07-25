import assert from 'node:assert';
import worker from './index.js';

class MockKV {
  constructor() {
    this.store = new Map();
    this.ttls = new Map();
  }
  async get(key) {
    return this.store.get(key) || null;
  }
  async put(key, val, options) {
    this.store.set(key, val);
    if (options && options.expirationTtl) {
      this.ttls.set(key, options.expirationTtl);
    }
  }
}

async function runTests() {
  console.log('Running Cloudflare Worker Reporting Backend Tests...');

  // Test 1: Missing KV returns 503
  {
    const req = new Request('https://reports.finnai.app/v1/reports', { method: 'POST' });
    const res = await worker.fetch(req, {}, {});
    assert.strictEqual(res.status, 503);
    console.log('✓ Test 1: Missing KV returns 503');
  }

  // Test 2: Missing RATE_LIMIT_SALT returns 503
  {
    const kv = new MockKV();
    const req = new Request('https://reports.finnai.app/v1/reports', { method: 'POST' });
    const res = await worker.fetch(req, { REPORTS_KV: kv }, {});
    assert.strictEqual(res.status, 503);
    console.log('✓ Test 2: Missing RATE_LIMIT_SALT returns 503');
  }

  // Test 3: Reject unknown field returns 400
  {
    const kv = new MockKV();
    const req = new Request('https://reports.finnai.app/v1/reports', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        reportId: 'rep_123',
        category: 'other',
        assistantResponse: 'test response',
        timestamp: new Date().toISOString(),
        appVersion: '1.0.0',
        modelTier: 'Bonsai 4B',
        unknownField: 'hacked',
      }),
    });
    const res = await worker.fetch(req, { REPORTS_KV: kv, RATE_LIMIT_SALT: 'test_salt' }, {});
    assert.strictEqual(res.status, 400);
    console.log('✓ Test 3: Reject unknown field returns 400');
  }

  // Test 4: Valid report submission returns 201 with 30-day TTL
  {
    const kv = new MockKV();
    const req = new Request('https://reports.finnai.app/v1/reports', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        reportId: 'rep_valid_123',
        category: 'harmfulOrDangerous',
        assistantResponse: 'test response text',
        timestamp: new Date().toISOString(),
        appVersion: '1.0.0',
        modelTier: 'Bonsai 4B',
      }),
    });
    const res = await worker.fetch(req, { REPORTS_KV: kv, RATE_LIMIT_SALT: 'test_salt' }, {});
    assert.strictEqual(res.status, 201);
    assert.strictEqual(kv.ttls.get('report:rep_valid_123'), 30 * 24 * 3600);
    console.log('✓ Test 4: Valid report submission returns 201 with 30-day retention TTL');
  }

  // Test 5: Real Rate Limiting (Sends 10 requests, asserts 11th gets HTTP 429)
  {
    const kv = new MockKV();
    const env = { REPORTS_KV: kv, RATE_LIMIT_SALT: 'rate_limit_secret_salt_2026' };
    const clientIp = '203.0.113.195';

    for (let i = 1; i <= 10; i++) {
      const req = new Request('https://reports.finnai.app/v1/reports', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'cf-connecting-ip': clientIp,
        },
        body: JSON.stringify({
          reportId: `rep_ratelimit_${i}`,
          category: 'other',
          assistantResponse: `Response ${i}`,
          timestamp: new Date().toISOString(),
          appVersion: '1.0.0',
          modelTier: 'Bonsai 4B',
        }),
      });

      const res = await worker.fetch(req, env, {});
      assert.strictEqual(res.status, 201, `Request ${i} should succeed with 201`);
    }

    // 11th request from same IP must be rate limited with 429
    const blockedReq = new Request('https://reports.finnai.app/v1/reports', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'cf-connecting-ip': clientIp,
      },
      body: JSON.stringify({
        reportId: 'rep_ratelimit_11',
        category: 'other',
        assistantResponse: 'Response 11',
        timestamp: new Date().toISOString(),
        appVersion: '1.0.0',
        modelTier: 'Bonsai 4B',
      }),
    });

    const blockedRes = await worker.fetch(blockedReq, env, {});
    assert.strictEqual(blockedRes.status, 429, 'Request 11 must be rate limited with HTTP 429');
    const blockedBody = await blockedRes.json();
    assert.strictEqual(blockedBody.error, 'Too many reports submitted. Please try again later.');
    console.log('✓ Test 5: Real rate limiting verified (10 succeeded, 11th rejected with HTTP 429)');
  }

  console.log('All backend tests passed successfully!');
}

runTests().catch((err) => {
  console.error('Backend test failure:', err);
  process.exit(1);
});
