import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/pharmacy.dart';

/// Ouvre la fiche pharmacie (bottom sheet) : coordonnées, téléphones
/// avec appel direct, distance si dispo.
Future<void> showPharmacySheet(
  BuildContext context, {
  required Pharmacy pharmacy,
  double? distanceKm,
  bool isOnDuty = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Respecte la barre de navigation Android (insets du bas).
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => _PharmacySheet(
      pharmacy: pharmacy,
      distanceKm: distanceKm,
      isOnDuty: isOnDuty,
    ),
  );
}

class _PharmacySheet extends StatelessWidget {
  const _PharmacySheet({
    required this.pharmacy,
    required this.distanceKm,
    required this.isOnDuty,
  });

  final Pharmacy pharmacy;
  final double? distanceKm;
  final bool isOnDuty;

  Future<void> _call(BuildContext context, String phone) async {
    final uri =
        Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l\'appel.')),
        );
      }
    }
  }

  /// Nettoie la commune pour la recherche Maps : coupe aux repères
  /// (« FACE », « APRES », « ROUTE », « / »...) qui rendent la requête
  /// inexploitable — Google trouve la pharmacie par son NOM.
  static String _cleanCommune(String commune) {
    var c = commune;
    for (final token in [
      'FACE', 'APRES', 'PRES ', 'CARREFOUR', 'ROUTE', 'AVENUE',
      'BOULEVARD', 'RUE ', 'TEL', 'ENTRE', 'DERRIERE', '/',
    ]) {
      final i = c.toUpperCase().indexOf(token);
      if (i > 0) c = c.substring(0, i).trim();
    }
    if (c.length > 30) c = c.substring(0, 30).trim();
    return c;
  }

  Future<void> _navigate(BuildContext context) async {
    final name = Uri.encodeComponent(pharmacy.name);
    final commune = pharmacy.commune != null
        ? _cleanCommune(pharmacy.commune!)
        : null;
    final candidates = <Uri>[
      // 1. Google Maps en navigation directe (si coordonnées)
      if (pharmacy.lat != null && pharmacy.lng != null)
        Uri.parse(
            'google.nav:geo:${pharmacy.lat},${pharmacy.lng}?q=$name'),
      // 2. Sélecteur d'app de navigation (Maps, Waze, ...)
      if (pharmacy.lat != null && pharmacy.lng != null)
        Uri.parse(
            'geo:0,0?q=${pharmacy.lat},${pharmacy.lng}($name)'),
      // 3. Fallback web : NOM + commune nettoyée uniquement (jamais
      //    l'adresse brute pleine de repères — Google trouve la
      //    pharmacie par son nom dans Google Maps/Business).
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$name'
          '${commune != null && commune.isNotEmpty ? '+${Uri.encodeComponent(commune)}' : ''}'),
    ];
    for (final uri in candidates) {
      final isLast = uri == candidates.last;
      try {
        if (isLast || await canLaunchUrl(uri)) {
          // externalApplication : ouvre TOUJOURS l'app externe (jamais
          // de WebView interne — plus fiable pour la navigation).
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {
        // continue vers le fallback suivant
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la navigation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final phones = [
      if (pharmacy.phone1 != null && pharmacy.phone1!.isNotEmpty)
        pharmacy.phone1!,
      if (pharmacy.phone2 != null && pharmacy.phone2!.isNotEmpty)
        pharmacy.phone2!,
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_pharmacy_rounded, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pharmacy.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isOnDuty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DE GARDE',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (pharmacy.commune != null || pharmacy.address != null)
              Text([
                if (pharmacy.commune != null) pharmacy.commune!,
                if (pharmacy.address != null) pharmacy.address!,
              ].join(' • ')),
            if (distanceKm != null) ...[
              const SizedBox(height: 4),
              Text('À ${_formatDistance(distanceKm!)} de toi'),
            ],
            if (phones.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Téléphone', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final phone in phones)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_rounded),
                  title: Text(phone),
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => _call(context, phone),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Appeler'),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _navigate(context),
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Itinéraire'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
