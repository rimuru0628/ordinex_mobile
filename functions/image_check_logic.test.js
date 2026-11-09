'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  classifyGenerationScores,
  findGenerationScores,
  isAllowedCloudinaryImageUrl,
} = require('./image_check_logic');

function hiveResponse(aiScore, notAiScore) {
  return {
    status: [{
      response: {
        output: [{
          classes: [
            { class: 'not_ai_generated', score: notAiScore },
            { class: 'ai_generated', score: aiScore },
            { class: 'other_image_generators', score: 0 },
          ],
        }],
      },
    }],
  };
}

test('reads the generated and non-generated scores from Hive response output', () => {
  assert.deepEqual(findGenerationScores(hiveResponse(0.97, 0.03)), {
    aiGenerated: 0.97,
    notAiGenerated: 0.03,
  });
});

test('flags at Hive recommended 0.9 AI-generated threshold', () => {
  const scores = findGenerationScores(hiveResponse(0.9, 0.1));
  assert.equal(classifyGenerationScores(scores), 'flagged');
});

test('marks a strong not-AI-generated result clear', () => {
  const scores = findGenerationScores(hiveResponse(0.02, 0.98));
  assert.equal(classifyGenerationScores(scores), 'clear');
});

test('routes low-confidence results to manual review as inconclusive', () => {
  const scores = findGenerationScores(hiveResponse(0.52, 0.48));
  assert.equal(classifyGenerationScores(scores), 'inconclusive');
});

test('rejects malformed or incomplete score payloads', () => {
  assert.equal(findGenerationScores({ status: 'failed' }), null);
  assert.equal(findGenerationScores(hiveResponse(Number.NaN, 0.5)), null);
  assert.throws(() => classifyGenerationScores(null), TypeError);
});

test('accepts only HTTPS image URLs in the configured Cloudinary account', () => {
  assert.equal(
    isAllowedCloudinaryImageUrl(
      'https://res.cloudinary.com/zq9gopfc/image/upload/v123/reports/evidence.jpg',
    ),
    true,
  );
  assert.equal(
    isAllowedCloudinaryImageUrl(
      'https://evil.example/zq9gopfc/image/upload/reports/evidence.jpg',
    ),
    false,
  );
  assert.equal(
    isAllowedCloudinaryImageUrl(
      'https://res.cloudinary.com/other/image/upload/reports/evidence.jpg',
    ),
    false,
  );
  assert.equal(
    isAllowedCloudinaryImageUrl(
      'http://res.cloudinary.com/zq9gopfc/image/upload/reports/evidence.jpg',
    ),
    false,
  );
});
