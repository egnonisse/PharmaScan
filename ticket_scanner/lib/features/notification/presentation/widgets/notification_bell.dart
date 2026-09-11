import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Cloche de notifications avec bulle du nombre de non lues.
///
/// Compte les annonces actives (collection announcements) non marquées
/// comme lues par l'utilisateur (users/{uid}/readAnnouncements).
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final announcementsStream = FirebaseFirestore.instance
        .collection('announcements')
        .where('active', isEqualTo: true)
        .snapshots();
    final readStream = uid == null
        ? const Stream<QuerySnapshot>.empty()
        : FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('readAnnouncements')
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: announcementsStream,
      builder: (context, announcementsSnapshot) {
        final total =
            announcementsSnapshot.hasData
                ? announcementsSnapshot.data!.docs.length
                : 0;
        return StreamBuilder<QuerySnapshot>(
          stream: readStream,
          builder: (context, readSnapshot) {
            final readCount = readSnapshot.data?.docs.length ?? 0;
            final unread = (total - readCount).clamp(0, total);
            return IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                backgroundColor: AppColors.secondary,
                child: const Icon(Icons.notifications_rounded),
              ),
            );
          },
        );
      },
    );
  }
}
