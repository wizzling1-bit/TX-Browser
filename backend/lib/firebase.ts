import admin from 'firebase-admin';

export function getFirebaseAdmin() {
  if (!admin.apps.length) {
    const projectId = process.env.FIREBASE_PROJECT_ID || 'tx-browser';
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL || 'firebase-adminsdk-fbsvc@tx-browser.iam.gserviceaccount.com';
    let privateKey = process.env.FIREBASE_PRIVATE_KEY || '';

    if (privateKey.includes('\\n')) {
      privateKey = privateKey.replace(/\\n/g, '\n');
    }

    if (privateKey && clientEmail) {
      try {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey,
          }),
        });
      } catch (err) {
        console.error('Firebase Admin initialization error with cert:', err);
        admin.initializeApp({ projectId });
      }
    } else {
      admin.initializeApp({ projectId });
    }
  }

  return admin;
}

export function getFirebaseMessaging() {
  const fbAdmin = getFirebaseAdmin();
  return fbAdmin.messaging();
}
