'use strict';

const FLAG_THRESHOLD = 0.9;
const CLOUDINARY_HOST = 'res.cloudinary.com';
const CLOUDINARY_NAME = 'zq9gopfc';

function findGenerationScores(value) {
  if (Array.isArray(value)) {
    for (const item of value) {
      const result = findGenerationScores(item);
      if (result) return result;
    }
    return null;
  }

  if (value && typeof value === 'object') {
    if (Array.isArray(value.classes)) {
      const aiGenerated = value.classes.find((item) => item.class === 'ai_generated');
      const notAiGenerated = value.classes.find((item) => item.class === 'not_ai_generated');
      if (aiGenerated && notAiGenerated) {
        const aiScore = Number(aiGenerated.score);
        const humanScore = Number(notAiGenerated.score);
        if (
          Number.isFinite(aiScore) &&
          Number.isFinite(humanScore) &&
          aiScore >= 0 && aiScore <= 1 &&
          humanScore >= 0 && humanScore <= 1
        ) {
          return { aiGenerated: aiScore, notAiGenerated: humanScore };
        }
      }
    }

    for (const child of Object.values(value)) {
      const result = findGenerationScores(child);
      if (result) return result;
    }
  }
  return null;
}

function classifyGenerationScores(scores, threshold = FLAG_THRESHOLD) {
  if (
    !scores ||
    !Number.isFinite(scores.aiGenerated) ||
    !Number.isFinite(scores.notAiGenerated)
  ) {
    throw new TypeError('Valid AI-generated and not-AI-generated scores are required.');
  }
  if (scores.aiGenerated >= threshold) return 'flagged';
  if (scores.notAiGenerated >= threshold) return 'clear';
  return 'inconclusive';
}

function isAllowedCloudinaryImageUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' &&
      url.hostname === CLOUDINARY_HOST &&
      url.pathname.startsWith(`/${CLOUDINARY_NAME}/image/upload/`);
  } catch (_) {
    return false;
  }
}

module.exports = {
  FLAG_THRESHOLD,
  classifyGenerationScores,
  findGenerationScores,
  isAllowedCloudinaryImageUrl,
};
