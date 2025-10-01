const functions = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Use the existing initialized app
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function that sends a notification when a new message is created
 */
exports.notifyNewMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    console.log("🔔 New message notification function triggered");
    
    // Get message data
    const messageData = event.data.data();
    const conversationId = event.params.conversationId;
    
    // If no message data, exit
    if (!messageData) {
      console.log('❌ No message data found');
      return;
    }
    
    // Get sender ID and message content
    const senderId = messageData.senderId;
    const messageText = messageData.text || "New message";
    
    try {
      // Get conversation to find all participants
      const conversationDoc = await db.collection('conversations').doc(conversationId).get();
      const conversationData = conversationDoc.data();
      
      if (!conversationData || !conversationData.participants) {
        console.log('❌ No conversation data or participants found');
        return;
      }
      
      // Get related request info to include in notification
      const requestId = conversationData.requestId;
      let requestInfo = "";
      
      if (requestId) {
        const requestDoc = await db.collection('requests').doc(requestId).get();
        if (requestDoc.exists) {
          const requestData = requestDoc.data();
          requestInfo = ` (${requestData.diningHall || 'Pickup'})`;
        }
      }
      
      // Get sender's name
      const senderDoc = await db.collection('users').doc(senderId).get();
      const senderName = senderDoc.data()?.name || "Someone";
      
      // Find the recipient (all participants except sender)
      const recipients = conversationData.participants.filter(uid => uid !== senderId);
      
      // Send notification to each recipient
      for (const recipientId of recipients) {
        // Get recipient's FCM token
        const recipientDoc = await db.collection('users').doc(recipientId).get();
        const fcmToken = recipientDoc.data()?.fcmToken;
        
        if (!fcmToken) {
          console.log(`❌ No FCM token found for user: ${recipientId}`);
          continue;
        }
        
        // Send notification with improved navigation data
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
            otherUserId: senderId, // Add this to help with navigation
            type: 'new_message',
            click_action: "FLUTTER_NOTIFICATION_CLICK" // Add this for both Android and iOS
          },
          android: {
            priority: "high",
            notification: {
              channelId: "chat_messages",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              tag: `chat_${conversationId}`, // Group notifications by conversation
              color: "#7D2F00" // Hokie maroon color
            }
          },
          apns: {
            headers: {
              "apns-priority": "10"
            },
            payload: {
              aps: {
                category: "NEW_MESSAGE_CATEGORY",
                sound: "default",
                badge: 1,
                contentAvailable: true,
                mutableContent: true
              }
            },
            fcmOptions: {
              // This helps identify the notification type in iOS
              analyticsLabel: "message_notification"
            }
          }
        };
        
        const response = await messaging.send(message);
        console.log(`✅ Message notification sent to ${recipientId}, response:`, response);
      }
    } catch (error) {
      console.error('❌ Error sending message notification:', error.message);
      console.error('❌ Full error:', error);
    }
  }
);