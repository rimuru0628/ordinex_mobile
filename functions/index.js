'use strict';

const crypto = require('node:crypto');
const { initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { defineSecret } = require('firebase-functions/params');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const {
  FLAG_THRESHOLD,
  classifyGenerationScores,
  findGenerationScores,
  isAllowedCloudinaryImageUrl,
} = require('./image_check_logic');

initializeApp();

const HIVE_API_KEY = defineSecret('HIVE_API_KEY');
const HIVE_ENDPOINT = 'https://api.hivemoderation.com/api/v2/task/sync';

exports.checkSubmittedReportImage = onDocumentCreated(
  {
    document: 'reports/{reportId}',
    region: 'asia-southeast1',
    timeoutSeconds: 60,
    memory: '256MiB',
    secrets: [HIVE_API_KEY],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const report = snapshot.data();
    const imageUrl = report.imageUrl;
    if (typeof imageUrl !== 'string' || imageUrl.length === 0) return;

    const reportRef = getFirestore().collection('reports').doc(snapshot.id);
    try {
      await reportRef.set(
        {
          imageAiCheck: {
            status: 'checking',
            provider: 'hive',
            model: 'ai_generated_media',
            threshold: FLAG_THRESHOLD,
            startedAt: FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );

      if (!isAllowedCloudinaryImageUrl(imageUrl)) {
        throw new Error('Report image URL is outside the configured Cloudinary account.');
      }

      const response = await fetch(HIVE_ENDPOINT, {
        method: 'POST',
        headers: {
          authorization: `token ${HIVE_API_KEY.value()}`,
          accept: 'application/json',
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          user_id: hashForProvider(report.userId || snapshot.id),
          post_id: snapshot.id,
          url: imageUrl,
          models: ['ai_generated_media'],
        }),
        signal: AbortSignal.timeout(45000),
      });

      if (!response.ok) {
        throw new Error(`Hive API returned HTTP ${response.status}.`);
      }

      const payload = await response.json();
      const scores = findGenerationScores(payload);
      if (!scores) throw new Error('Hive response did not include image generation scores.');
      const status = classifyGenerationScores(scores, FLAG_THRESHOLD);

      const result = {
        status,
        provider: 'hive',
        model: 'ai_generated_media',
        aiGeneratedConfidence: scores.aiGenerated,
        notAiGeneratedConfidence: scores.notAiGenerated,
        threshold: FLAG_THRESHOLD,
        checkedAt: FieldValue.serverTimestamp(),
      };

      await reportRef.set({ imageAiCheck: result }, { merge: true });

      if (status === 'flagged' || status === 'inconclusive') {
        try {
          await createReviewNotification(snapshot.id, report, result);
        } catch (notificationError) {
          logger.error('Could not create the image review notification.', {
            reportId: snapshot.id,
            error: notificationError instanceof Error
              ? notificationError.message
              : String(notificationError),
          });
        }
      }
    } catch (error) {
      logger.error('Report image check could not be completed.', {
        reportId: snapshot.id,
        error: error instanceof Error ? error.message : String(error),
      });

      const result = {
        status: 'unavailable',
        provider: 'hive',
        model: 'ai_generated_media',
        threshold: FLAG_THRESHOLD,
        checkedAt: FieldValue.serverTimestamp(),
      };
      await reportRef.set({ imageAiCheck: result }, { merge: true });
      try {
        await createReviewNotification(snapshot.id, report, result);
      } catch (notificationError) {
        logger.error('Could not create the image review notification.', {
          reportId: snapshot.id,
          error: notificationError instanceof Error
            ? notificationError.message
            : String(notificationError),
        });
      }
    }
  },
);

function hashForProvider(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

async function createReviewNotification(reportId, report, result) {
  const db = getFirestore();
  const confidence = result.aiGeneratedConfidence;
  const flagged = result.status === 'flagged';
  const unavailable = result.status === 'unavailable';
  const title = flagged
    ? 'Evidence photo needs review'
    : unavailable
      ? 'Evidence photo could not be checked'
      : 'Evidence photo check was inconclusive';

  await db.collection('admin_notifications').doc(`image-review-${reportId}`).set(
    {
      type: 'image_review_required',
      title,
      body: flagged
        ? `Report ${report.reportReference || reportId} has a strong AI-generation signal. Please verify the evidence.`
        : unavailable
          ? `Report ${report.reportReference || reportId} could not be checked automatically. Please review the evidence.`
          : `Report ${report.reportReference || reportId} has an inconclusive image check. Please verify the evidence.`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
      meta: {
        reportId,
        reportRef: report.reportReference || reportId,
        category: report.category || '',
        imageAiCheckStatus: result.status,
        ...(confidence == null ? {} : { aiGeneratedConfidence: confidence }),
      },
    },
    { merge: true },
  );
}
