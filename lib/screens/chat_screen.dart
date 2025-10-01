// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../constants/colors.dart';
import 'dart:math' as math;

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _sendButtonController;
  late AnimationController _typingController;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();

    // Animation controllers
    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Listen for typing
    _messageController.addListener(_onTypingChanged);
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    if (_isTyping != isCurrentlyTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });

      if (isCurrentlyTyping) {
        _typingController.forward();
      } else {
        _typingController.reverse();
      }
    }
  }

  void _markMessagesAsRead() {
    _chatService.markMessagesAsRead(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Updated background to use AppColors1
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors1.surfaceColor, AppColors1.backgroundColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom header with updated colors
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // Profile avatar with green gradient
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors1.primaryGreen,
                            AppColors1.primaryGreen.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors1.glowGreen,
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _chatService.getUserDetails(widget.otherUserId),
                        builder: (context, snapshot) {
                          final userName = snapshot.data?['name'] ?? 'Chat';
                          final profileImageUrl =
                              snapshot.data?['profileImageUrl'];

                          return CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.transparent,
                            backgroundImage:
                                profileImageUrl != null
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                            child:
                                profileImageUrl == null
                                    ? Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 35,
                                      ),
                                    )
                                    : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // User name with primary text color
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _chatService.getUserDetails(widget.otherUserId),
                        builder: (context, snapshot) {
                          final userName = snapshot.data?['name'] ?? 'Chat';
                          return Text(
                            userName,
                            style: const TextStyle(
                              color: AppColors1.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 35,
                            ),
                          );
                        },
                      ),
                    ),
                    // Back button with green gradient
                    Container(
                      width: 55,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: const LinearGradient(
                          colors: AppColors1.cancelButtonGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors1.glowGreen,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Date banner with updated colors
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors1.cardColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors1.borderGreen, width: 0.5),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    color: AppColors1.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),

              // Messages list
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chatService.getMessages(widget.conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors1.primaryGreen,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: AppColors1.textPrimary),
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: AppColors1.primaryGreen.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: AppColors1.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start the conversation!',
                              style: TextStyle(color: AppColors1.primaryGreen),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe =
                            message.senderId == _chatService.currentUserId;

                        return AnimatedMessageBubble(
                          message: message,
                          isMe: isMe,
                          index: index,
                        );
                      },
                    );
                  },
                ),
              ),

              // Message input with updated colors
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors1.surfaceColor, AppColors1.navBarColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors1.subtleGlow,
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Message input field with green accent
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors1.cardColor,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: AppColors1.borderGreen,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors1.subtleGlow,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: AppColors1.textSubtle,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                          style: const TextStyle(color: AppColors1.textPrimary),
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                    ),

                    // Send button with green gradient
                    const SizedBox(width: 8),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: AppColors1.cancelButtonGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors1.glowGreen,
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Play send animation
    _sendButtonController.reset();
    _sendButtonController.forward();

    // Add haptic feedback
    HapticFeedback.mediumImpact();

    _chatService.sendMessage(widget.conversationId, text);
    _messageController.clear();

    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _sendButtonController.dispose();
    _typingController.dispose();
    super.dispose();
  }
}

// Updated message bubble with new color scheme
class AnimatedMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final int index;

  const AnimatedMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.index,
  }) : super(key: key);

  @override
  _AnimatedMessageBubbleState createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.isMe ? const Offset(1, 0) : const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger the animation based on index
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment:
                widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!widget.isMe) const SizedBox(width: 8),

              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  // Updated gradients using AppColors1
                  gradient:
                      widget.isMe
                          ? const LinearGradient(
                            colors: AppColors1.cancelButtonGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : const LinearGradient(
                            colors: [
                              AppColors1.cardColor,
                              AppColors1.iconBackgroundColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: widget.isMe ? const Radius.circular(4) : null,
                    bottomLeft: !widget.isMe ? const Radius.circular(4) : null,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          widget.isMe
                              ? AppColors1.glowGreen.withOpacity(0.3)
                              : AppColors1.subtleGlow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border:
                      widget.isMe
                          ? null
                          : Border.all(
                            color: AppColors1.borderGreen,
                            width: 0.5,
                          ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message text
                    Text(
                      widget.message.text,
                      style: TextStyle(
                        color:
                            widget.isMe ? Colors.black : AppColors1.textPrimary,
                        fontSize: 16,
                      ),
                    ),

                    // Timestamp and read status
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.jm().format(widget.message.timestamp),
                          style: TextStyle(
                            color:
                                widget.isMe
                                    ? Colors.black.withOpacity(0.7)
                                    : AppColors1.textSubtle,
                            fontSize: 12,
                          ),
                        ),
                        if (widget.isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            widget.message.read ? Icons.done_all : Icons.done,
                            size: 14,
                            color:
                                widget.message.read
                                    ? Colors.black.withOpacity(0.8)
                                    : Colors.black.withOpacity(0.6),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (widget.isMe) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
