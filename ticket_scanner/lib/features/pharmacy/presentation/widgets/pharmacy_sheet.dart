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
