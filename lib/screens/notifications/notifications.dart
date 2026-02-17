import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (user != null) {
      debugPrint("🔔 Fetching notifications for User UID: ${user.uid}");
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 4,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestoreService.getUserNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading updates...');
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No new notifications',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification['isRead'] ?? false;
              final timestamp = notification['createdAt'] as Timestamp?;

              // Simple date formatting
              String timeText = '';
              if (timestamp != null) {
                final dt = timestamp.toDate();
                final now = DateTime.now();
                if (now.difference(dt).inDays == 0) {
                  timeText =
                      "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
                } else {
                  timeText = "${dt.day}/${dt.month}";
                }
              }

              return Dismissible(
                key: Key(notification['id']),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  // TODO: Implement delete in FirestoreService if needed,
                  // for now just visually remove or ignore.
                },
                child: InkWell(
                  onTap: () async {
                    if (!isRead) {
                      await firestoreService.markNotificationAsRead(
                        user.uid,
                        notification['id'],
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRead
                            ? Colors.grey.withValues(alpha: 0.2)
                            : AppTheme.primaryRed.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        if (!isRead)
                          BoxShadow(
                            color: AppTheme.primaryRed.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRead
                                ? Colors.grey[100]
                                : AppTheme.primaryRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconForType(notification['type']),
                            color: isRead ? Colors.grey : AppTheme.primaryRed,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification['title'] ?? 'Notification',
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 16,
                                        color: isRead
                                            ? Colors.black87
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    timeText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notification['body'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
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
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'booking':
        return Icons.confirmation_number_outlined;
      case 'offer':
        return Icons.local_offer_outlined;
      case 'security':
        return Icons.security;
      default:
        return Icons.notifications_outlined;
    }
  }
}
