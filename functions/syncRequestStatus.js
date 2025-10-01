const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Initialize admin app if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Cloud Function to sync request.status into conversations
 */
exports.syncRequestStatusToConversations = onDocumentUpdated(
  "requests/{requestId}",
  async (event) => {
    console.log("🔄 Syncing requestStatus to conversations");

    const requestId = event.params.requestId;
    const afterData = event.data.after.data();

    if (!afterData) {
      console.log('❌ No afterData found');
      return;
    }

    const newStatus = afterData.status;

    if (!newStatus) {
      console.log('❌ No status found in request');
      return;
    }

    try {
      // Find conversations linked to this requestId
      const conversationsSnapshot = await db
        .collection('conversations')
        .where('requestId', '==', requestId)
        .get();

      if (conversationsSnapshot.empty) {
        console.log(`ℹ️ No conversations found for requestId: ${requestId}`);
        return;
      }

      const batch = db.batch();

      conversationsSnapshot.forEach((doc) => {
        console.log(`🔄 Updating conversation ${doc.id} with status ${newStatus}`);
        batch.update(doc.ref, { requestStatus: newStatus });
      });

      await batch.commit();

      console.log('✅ requestStatus synced to conversations');
    } catch (error) {
      console.error('❌ Error syncing requestStatus:', error.message);
    }
  }
);
