# BEE-Alert

BEE-Alert is a Flutter app for residents to submit and track community concern reports.

## Automated image review

When a report includes a photo, a Firestore create trigger sends the photo URL to Hive's AI-generated media detector. The function stores its result under `reports/{reportId}.imageAiCheck`:

- `pending` / `checking`: the check has not finished.
- `clear`: no strong AI-generation signal was detected.
- `flagged`: AI-generation confidence met the 0.9 review threshold.
- `inconclusive`: neither class met the confidence threshold.
- `unavailable`: the check could not be completed.

Flagged, inconclusive, and unavailable results create an `image_review_required` document in `admin_notifications`. Reports are not automatically rejected; the image result is a review signal for municipal staff.

The Cloud Function only accepts image URLs hosted in this app's configured Cloudinary account. It sends a hashed user identifier to Hive and keeps the Hive API key on the server.

## Configure and deploy the image check

1. Create a Hive API key with access to AI-Generated Image and Video Detection.
2. Set the key as a Firebase Functions secret:

   ```sh
   firebase functions:secrets:set HIVE_API_KEY --project ordinex-5cfa3
   ```

3. Deploy the trigger:

   ```sh
   firebase deploy --project ordinex-5cfa3 --only functions:checkSubmittedReportImage
   ```

Firebase Cloud Functions deployment requires the Firebase project to be on the Blaze plan. The check stays `unavailable` until the secret is configured and the function is deployed. Hive's detector is not definitive; staff should verify flagged or inconclusive evidence.

## Run the Flutter app

```sh
flutter pub get
flutter run
```
