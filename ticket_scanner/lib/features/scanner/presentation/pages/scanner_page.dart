import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/receipt_extraction.dart';
import '../../domain/services/receipt_parser.dart';
import '../cubit/scanner_cubit.dart';
import '../cubit/scanner_state.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  Future<void> _requestPermissionAndScan(BuildContext context) async {
    final cubit = context.read<ScannerCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Scanner un reçu ?'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nous utilisons la caméra pour scanner votre reçu de '
                  'pharmacie et en extraire les informations (pharmacie, '
                  'date, médicaments, prix).',
                ),
                SizedBox(height: 12),
                Text(
                  'Votre reçu contient des données de santé. L\'image est '
                  'traitée LOCALEMENT sur votre appareil (OCR) et ne quitte '
                  'jamais votre téléphone. Seules les informations extraites '
                  'sont enregistrées, sans lien avec votre identité.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12),
                Text(
                  'En continuant, vous consentez à ce traitement. '
                  'Détails : Réglages → Consentement scan reçus.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final granted = await cubit.requestCameraPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission caméra refusée.')),
        );
      }
      return;
    }

    await cubit.scanFromCamera();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScannerCubit(parser: const ReceiptParser()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scanner un reçu'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<ScannerCubit, ScannerState>(
            builder: (context, state) {
              final extraction = state.extraction;

              return ListView(
                children: [
                  FilledButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () => _requestPermissionAndScan(context),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: Text(
                      state.isLoading ? 'Traitement en cours…' : 'Prendre une photo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () => context.read<ScannerCubit>().scanFromGallery(),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Choisir depuis la galerie'),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (extraction != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Résultats OCR',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _ExtractionCard(extraction: extraction),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: extraction.isValidForMvp
                          ? () {
                              // On envoie même si certains champs sont null :
                              // la page de confirmation laissera l'utilisateur éditer.
                              context.push(
                                '/confirmation',
                                extra: (extraction, state.imagePath),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Continuer'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExtractionCard extends StatelessWidget {
  const _ExtractionCard({required this.extraction});

  final ReceiptExtraction extraction;

  @override
  Widget build(BuildContext context) {
    final montantText = extraction.montantTotal == null
        ? '—'
        : extraction.montantTotal!.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pharmacie : ${extraction.pharmacyName ?? '—'}'),
            const SizedBox(height: 8),
            Text('Date : ${extraction.dateTicket ?? '—'}'),
            const SizedBox(height: 8),
            if (extraction.heureTicket != null) ...[
              Text('Heure : ${extraction.heureTicket}'),
              const SizedBox(height: 8),
            ],
            Text('Montant total : $montantText'),
            const SizedBox(height: 12),
            Text(
              'Médicaments (${extraction.items.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            if (extraction.items.isEmpty)
              const Text('Aucun médicament détecté.')
            else
              ...extraction.items.map(
                (item) => Text(
                  '• ${item.name} : ${item.price.toStringAsFixed(2)}'
                  '${item.quantity > 1 ? ' (x${item.quantity})' : ''}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
