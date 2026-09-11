import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/firebase_announcement_repository.dart';
import '../../domain/entities/announcement.dart';

/// Hôte de popups in-app (annonces du dashboard).
///
/// Widget invisible à placer dans la home : écoute les annonces actives et
/// affiche en popup la plus récente non rejetée (UNE par session). Les
/// annonces `oncePerUser` sont mémorisées localement (shared_preferences).
class AnnouncementPopupHost extends StatefulWidget {
  const AnnouncementPopupHost({super.key});

  @override
  State<AnnouncementPopupHost> createState() => _AnnouncementPopupHostState();
}

class _AnnouncementPopupHostState extends State<AnnouncementPopupHost> {
  static const _repository = FirebaseAnnouncementRepository();
  static const _prefsKey = 'dismissed_announcements';

  /// Bloqué dès la première candidature : une seule popup par session.
  bool _locked = false;

  Future<bool> _isDismissed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey)?.contains(id) ?? false;
  }

  Future<void> _markDismissed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? <String>[];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_prefsKey, list);
    }
  }

  void _maybeShow(List<Announcement> announcements) {
    if (_locked || announcements.isEmpty) return;
    _locked = true;
    // Après le frame (showDialog pendant le build est interdit).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // La première annonce non rejetée gagne (les autres attendront
      // une future session — une seule popup à la fois).
      for (final announcement in announcements) {
        if (announcement.oncePerUser &&
            await _isDismissed(announcement.id)) {
          continue;
        }
        if (!mounted) return;
        await _showDialog(announcement);
        return;
      }
    });
  }

  Future<void> _showDialog(Announcement announcement) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _AnnouncementDialog(
        announcement: announcement,
      ),
    );
    // Fermeture (bouton, back système ou tap à l'extérieur).
    if (announcement.oncePerUser) {
      await _markDismissed(announcement.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: _repository.watchActiveAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _maybeShow(snapshot.data!);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({required this.announcement});

  final Announcement announcement;

  static const _typeIcons = {
    'promo': Icons.local_offer_rounded,
    'rappel': Icons.alarm_rounded,
    'info': Icons.info_rounded,
  };

  static const _typeColors = {
    'promo': Color(0xFF19B28A),
    'rappel': Color(0xFF9C6B30),
    'info': Color(0xFF0E7A5F),
  };

  Future<void> _openCta(BuildContext context) async {
    final uri = Uri.tryParse(announcement.ctaUrl ?? '');
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Icône dégradée utilisée quand il n'y a pas d'image.
  Widget _fallbackIcon(Color color, IconData icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[announcement.type] ?? Icons.info_rounded;
    final color = _typeColors[announcement.type] ?? const Color(0xFF0E7A5F);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      icon: announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(
                announcement.imageUrl!,
                width: 180,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackIcon(color, icon),
              ),
            )
          : _fallbackIcon(color, icon),
      title: Text(
        announcement.title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      content: Text(
        announcement.message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (announcement.hasCta) ...[
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openCta(context);
            },
            child: Text(announcement.ctaLabel!),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
      ],
    );
  }
}
