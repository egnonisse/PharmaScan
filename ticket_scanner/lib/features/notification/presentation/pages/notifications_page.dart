import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Centre de notifications in-app : liste des annonces actives publiées
/// depuis le dashboard, avec état lu / non lu (bulle dans l'AppBar).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _markAsRead(BuildContext context, String announcementId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('readAnnouncements')
        .doc(announcementId)
        .set({'readAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // PAS de orderBy : where(active)+orderBy(createdAt) exigerait un index
    // composite (erreur « query requires an index » → page en erreur).
    // Tri côté client.
    final announcementsRef = FirebaseFirestore.instance
        .collection('announcements')
        .where('active', isEqualTo: true)
        .snapshots();
    final readRef = uid == null
        ? const Stream<QuerySnapshot>.empty()
        : FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('readAnnouncements')
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: announcementsRef,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les notifications.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              // Tri côté client : plus récentes d'abord.
              final at = (a.data() as Map?)?['createdAt'] as Timestamp?;
              final bt = (b.data() as Map?)?['createdAt'] as Timestamp?;
              if (at == null && bt == null) return 0;
              if (at == null) return 1;
              if (bt == null) return -1;
              return bt.compareTo(at);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Text('Aucune notification pour le moment.'),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: readRef,
            builder: (context, readSnapshot) {
              final readIds = <String>{
                for (final doc in readSnapshot.data?.docs ?? const [])
                  doc.id,
              };

              return RefreshIndicator(
                onRefresh: () async {
                  // Les streams Firestore se resynchronisent seuls ; le
                  // délai garde le spinner visible.
                  await Future.delayed(const Duration(milliseconds: 800));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final doc in docs)
                      _NotificationTile(
                        id: doc.id,
                        data: doc.data() as Map<String, dynamic>? ?? const {},
                        isRead: readIds.contains(doc.id),
                        onTap: () => _markAsRead(context, doc.id),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.id,
    required this.data,
    required this.isRead,
    required this.onTap,
  });

  final String id;
  final Map<String, dynamic> data;
  final bool isRead;
  final VoidCallback onTap;

  IconData get _icon => switch (data['type']) {
        'promo' => Icons.local_offer_rounded,
        'rappel' => Icons.alarm_rounded,
        _ => Icons.info_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '';
    final message = data['message']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isRead ? AppColors.chipBg : AppColors.iconBg,
            borderRadius: BorderRadius.circular(AppRadii.icon),
          ),
          child: Icon(
            _icon,
            color: isRead ? AppColors.textMuted : AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
