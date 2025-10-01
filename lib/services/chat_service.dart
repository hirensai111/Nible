// lib/services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String get currentUserId => _auth.currentUser!.uid;
  
  // Get all conversations for current user WITHOUT using complex indices
  Stream<List<ConversationModel>> getConversations() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
              .toList();
          
          // Manual sorting by lastMessageTimestamp
          conversations.sort((a, b) {
            final aTimestamp = a.lastMessageTimestamp;
            final bTimestamp = b.lastMessageTimestamp;
            
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1; // null timestamps go last
            if (bTimestamp == null) return -1;
            
            // Sort descending (newest first)
            return bTimestamp.compareTo(aTimestamp);
          });
          
          return conversations;
        });
  }
  
  // Get messages for a specific conversation
  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
  
  // Send a message
  Future<void> sendMessage(String conversationId, String text) async {
    // Create message map
    final messageData = {
      'senderId': currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };
    
    // Add message to subcollection
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(messageData);
    
    // Update conversation with last message info
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({
          'lastMessage': text,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastSenderId': currentUserId,
        });
  }
  
  // Create a new conversation or get existing one
  Future<String> createConversation(String otherUserId, String requestId) async {
    // First check if a conversation already exists for this request
    QuerySnapshot existingConvos = await _firestore
        .collection('conversations')
        .where('requestId', isEqualTo: requestId)
        .where('participants', arrayContains: currentUserId)
        .get();
        
    // If exists, return the ID
    if (existingConvos.docs.isNotEmpty) {
      for (var doc in existingConvos.docs) {
        List<String> participants = List<String>.from(doc['participants']);
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }
    }
    
    // Otherwise create new conversation
    final conversationData = {
      'participants': [currentUserId, otherUserId],
      'requestId': requestId,
      'lastMessage': '',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'isActive': true,
      'lastSenderId': '',
    };
    
    DocumentReference docRef = await _firestore
        .collection('conversations')
        .add(conversationData);
    
    return docRef.id;
  }
  
  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    // Get all unread messages not sent by current user
    QuerySnapshot unreadMessages = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();
        
    // Use batch write for better performance
    WriteBatch batch = _firestore.batch();
    
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    // Commit the batch
    if (unreadMessages.docs.isNotEmpty) {
      await batch.commit();
    }
  }
  
  // Get user details (name and profile image)
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      return {
        'name': data['name'] ?? 'Unknown User',
        'profileImageUrl': data['profileImageUrl'],
      };
    }
    
    return {
      'name': 'Unknown User',
      'profileImageUrl': null,
    };
  }
  
  // Delete or archive a conversation
  Future<void> archiveConversation(String conversationId) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({
          'isActive': false,
        });
  }
}