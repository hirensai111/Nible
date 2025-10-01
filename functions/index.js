const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Notify when a request is accepted
exports.notifyRequestAccepted = onDocumentUpdated("requests/{requestId}", async (event) => {
  const beforeStatus = event.data.before.data().status;
  const afterStatus = event.data.after.data().status;

  // For accepted requests
  if (beforeStatus !== 'accepted' && afterStatus === 'accepted') {
    const userId = event.data.after.data().userId;

    const db = getFirestore();
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log('❌ No FCM token found for user:', userId);
      return;
    }

    try {
      const messaging = getMessaging();
      const message = {
        token: fcmToken,
        notification: {
          title: 'Request Accepted 🎉',
          body: 'A delivery person has accepted your request!',
        },
        data: {
          requestId: event.params.requestId,
          type: 'request_accepted',
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        android: {
          priority: "high",
          notification: {
            channelId: "request_updates",
            clickAction: "FLUTTER_NOTIFICATION_CLICK"
          }
        }
      };

      const response = await messaging.send(message);

      console.log('✅ Notification response:', response);
    } catch (error) {
      console.error('❌ Error sending notification:', error.message);
      console.error('❌ Full error:', error);
    }
  }
  
  // For picked up requests
  if (beforeStatus !== 'picked_up' && afterStatus === 'picked_up') {
    const userId = event.data.after.data().userId;

    const db = getFirestore();
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log('❌ No FCM token found for user:', userId);
      return;
    }

    try {
      const diningHall = event.data.after.data().diningHall || 'Unknown location';
      
      const messaging = getMessaging();
      const message = {
        token: fcmToken,
        notification: {
          title: 'Food Picked Up 🍔',
          body: `Your food has been picked up from ${diningHall}!`,
        },
        data: {
          requestId: event.params.requestId,
          type: 'request_picked_up',
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        android: {
          priority: "high",
          notification: {
            channelId: "request_updates",
            clickAction: "FLUTTER_NOTIFICATION_CLICK"
          }
        }
      };

      const response = await messaging.send(message);

      console.log('✅ Notification response:', response);
    } catch (error) {
      console.error('❌ Error sending notification:', error.message);
      console.error('❌ Full error:', error);
    }
  }
});

// Notify when a new message is created
exports.notifyNewMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    console.log("🔔 New message notification function triggered");

    // Get message data
    const messageData = event.data.data();
    const conversationId = event.params.conversationId;

    if (!messageData) {
      console.log('❌ No message data found');
      return;
    }

    const senderId = messageData.senderId;
    const messageText = messageData.text || "New message";

    try {
      const db = getFirestore();

      // Get conversation to find participants
      const conversationDoc = await db.collection('conversations').doc(conversationId).get();
      const conversationData = conversationDoc.data();

      if (!conversationData || !conversationData.participants) {
        console.log('❌ No conversation data or participants found');
        return;
      }

      // Get related request info
      const requestId = conversationData.requestId;
      let requestInfo = "";

      if (requestId) {
        const requestDoc = await db.collection('requests').doc(requestId).get();
        if (requestDoc.exists) {
          const requestData = requestDoc.data();
          requestInfo = ` (${requestData.diningHall || 'Pickup'})`;
        }
      }

      // Get sender name
      const senderDoc = await db.collection('users').doc(senderId).get();
      const senderName = senderDoc.data()?.name || "Someone";

      // Find recipients (except sender)
      const recipients = conversationData.participants.filter(uid => uid !== senderId);

      const messaging = getMessaging();

      // Send notification to recipients
      for (const recipientId of recipients) {
        const recipientDoc = await db.collection('users').doc(recipientId).get();
        const fcmToken = recipientDoc.data()?.fcmToken;

        if (!fcmToken) {
          console.log(`❌ No FCM token for user: ${recipientId}`);
          continue;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: `Message from ${senderName}${requestInfo}`,
            body: messageText.length > 100 ? messageText.substring(0, 97) + '...' : messageText,
          },
          data: {
            conversationId: conversationId,
            messageId: event.params.messageId,
            senderId: senderId,
            otherUserId: senderId, // Added this for navigation
            type: 'new_message',
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          android: {
            priority: "high",
            notification: {
              channelId: "chat_messages",
              clickAction: "FLUTTER_NOTIFICATION_CLICK"
            }
          }
        };

        const response = await messaging.send(message);
        console.log(`✅ Message notification sent to ${recipientId}`, response);
      }
    } catch (error) {
      console.error('❌ Error sending message notification:', error.message);
      console.error('❌ Full error:', error);
    }
  }
);

// Sync requestStatus to conversations
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
      const db = getFirestore();

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
      console.error('❌ Full error:', error);
    }
  }
);