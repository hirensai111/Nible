import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../screens/chat_screen.dart';

class FloatingChatBubble extends StatefulWidget {
  const FloatingChatBubble({Key? key}) : super(key: key);

  @override
  State<FloatingChatBubble> createState() => _FloatingChatBubbleState();
}

class _FloatingChatBubbleState extends State<FloatingChatBubble> {
  int _unreadMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _listenForUnreadMessages();
  }

  void _listenForUnreadMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
          int count = 0;

          final requestIds =
              snapshot.docs
                  .map(
                    (doc) => (doc.data() as Map<String, dynamic>)['requestId'],
                  )
                  .where((id) => id != null && id != '')
                  .cast<String>()
                  .toSet();

          print('DEBUG: Found request IDs: $requestIds');

          // Use error handling for each request fetch
          final requestDocs = <DocumentSnapshot>[];
          final requestStatusMap = <String, String?>{};

          for (final id in requestIds) {
            try {
              final doc =
                  await FirebaseFirestore.instance
                      .collection('requests')
                      .doc(id)
                      .get();

              requestDocs.add(doc);
              requestStatusMap[doc.id] =
                  doc.exists ? doc.data()!['status'] : null;
              print(
                'DEBUG: Successfully fetched request $id with status: ${requestStatusMap[doc.id]}',
              );
            } catch (e) {
              print('DEBUG: Permission denied for request $id: $e');
              // Skip this request and continue
              requestStatusMap[id] = null;
            }
          }

          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final requestId = data['requestId'];
            final status = requestStatusMap[requestId];

            print(
              'DEBUG: Checking conversation ${doc.id} with requestId: $requestId, status: $status',
            );

            if (status != null &&
                (status == 'pending' ||
                    status == 'accepted' ||
                    status == 'picked_up')) {
              if (data['lastSenderId'] != user.uid &&
                  data['lastSenderId'] != null &&
                  data['lastSenderId'] != "") {
                count++;
                print('DEBUG: Found unread message in conversation ${doc.id}');
              }
            }
          }

          print('DEBUG: Total unread count: $count');

          if (mounted) {
            setState(() {
              _unreadMessageCount = count;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors1.primaryGreen1,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(35),
              onTap: () => _showConversations(context),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const Icon(
                  Icons.message_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        if (_unreadMessageCount > 0)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              child: Center(
                child: Text(
                  _unreadMessageCount > 99
                      ? '99+'
                      : _unreadMessageCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showConversations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) => const ConversationsSheet(),
    );
  }
}

class ConversationsSheet extends StatelessWidget {
  const ConversationsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('User not logged in'));
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('conversations')
                      .where('participants', arrayContains: user.uid)
                      .orderBy('lastMessageTimestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading conversations: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No active conversations',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final conversations = snapshot.data!.docs;

                final requestIds =
                    conversations
                        .map(
                          (doc) =>
                              (doc.data() as Map<String, dynamic>)['requestId'],
                        )
                        .where((id) => id != null && id != '')
                        .cast<String>()
                        .toSet();

                return FutureBuilder<Map<String, String?>>(
                  future: _fetchRequestStatuses(requestIds),
                  builder: (context, requestSnapshot) {
                    if (requestSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final requestStatusMap = requestSnapshot.data ?? {};

                    final activeConversations =
                        conversations.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final requestId = data['requestId'];
                          final status = requestStatusMap[requestId];

                          return status == 'pending' ||
                              status == 'accepted' ||
                              status == 'picked_up';
                        }).toList();

                    if (activeConversations.isEmpty) {
                      return const Center(
                        child: Text(
                          'No active conversations',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: activeConversations.length,
                      itemBuilder: (context, index) {
                        final data =
                            activeConversations[index].data()
                                as Map<String, dynamic>;
                        final conversationId = activeConversations[index].id;
                        final participants =
                            data['participants'] as List<dynamic>;
                        final otherUserId = participants.firstWhere(
                          (id) => id != user.uid,
                          orElse: () => '',
                        );

                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(otherUserId)
                                  .get(),
                          builder: (context, userSnapshot) {
                            final userName =
                                userSnapshot.hasData &&
                                        userSnapshot.data!.exists
                                    ? (userSnapshot.data!.data()
                                            as Map<String, dynamic>)['name'] ??
                                        'User'
                                    : 'Loading...';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors1.primaryGreen,
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                userName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                data['lastMessage'] ?? 'No messages yet',
                                style: const TextStyle(color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing:
                                  data['lastSenderId'] != user.uid
                                      ? Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                      : null,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ChatScreen(
                                          conversationId: conversationId,
                                          otherUserId: otherUserId,
                                        ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String?>> _fetchRequestStatuses(
    Set<String> requestIds,
  ) async {
    final Map<String, String?> statusMap = {};

    for (final id in requestIds) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('requests')
                .doc(id)
                .get();

        statusMap[id] = doc.exists ? doc.data()!['status'] : null;
        print(
          'ConversationsSheet DEBUG: Successfully fetched request $id with status: ${statusMap[id]}',
        );
      } catch (e) {
        print(
          'ConversationsSheet DEBUG: Permission denied for request $id: $e',
        );
        statusMap[id] = null;
      }
    }

    return statusMap;
  }
}
