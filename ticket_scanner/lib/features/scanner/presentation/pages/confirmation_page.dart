import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/money/money_formatter.dart';
import '../../data/repositories/firebase_receipt_repository.dart';
import '../../domain/entities/receipt_extraction.dart';
import '../cubit/confirmation_cubit.dart';
import '../cubit/confirmation_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class ConfirmationPage extends StatefulWidget {
  const ConfirmationPage({super.key});

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  final TextEditingController _pharmacyController = TextEditingController();
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  /// Lignes de médicaments éditables (draft local).
  List<ReceiptItem> _items = [];

  /// Chemin de la photo du reçu (envoyée au serveur pour archivage).
  String? _imagePath;

  /// Noms des pharmacies connues (autocomplétion du champ Pharmacie).
  List<String> _pharmacyNames = [];

  bool _initialized = false;

  Future<void> _loadPharmacies() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pharmacies')
          .limit(1000)
          .get();
      if (!mounted) return;
      setState(() {
        _pharmacyNames = snapshot.docs
            .map((d) => (d.data()['name'] as String?)?.trim() ?? '')
            .where((n) => n.isNotEmpty)
            .toList()
          ..sort();
      });
    } catch (_) {
      // Hors ligne : l'utilisateur saisit librement.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final extra = GoRouterState.of(context).extra;
    final extraction = switch (extra) {
      (final ReceiptExtraction e, final String? _) => e,
      final ReceiptExtraction e => e,
      _ => null,
    };
    final imagePath = switch (extra) {
      (final ReceiptExtraction _, final String? path) => path,
      _ => null,
    };
    if (extraction == null || _initialized) return;

    _initialized = true;
    _pharmacyController.text = extraction.pharmacyName ?? '';
    _montantController.text = extraction.montantTotal?.toStringAsFixed(2) ?? '';
    _dateController.text = extraction.dateTicket ?? '';
    _items = List<ReceiptItem>.from(extraction.items);
    _imagePath = imagePath;

    // Autocomplétion pharmacie (811 officines connues).
    _loadPharmacies();
  }

  @override
  void dispose() {
    _pharmacyController.dispose();
    _montantController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _updateItem(int index, String name, double price) {
    setState(() {
      _items[index] = ReceiptItem(name: name, price: price);
    });
  }

  void _addItem() {
    setState(() {
      _items.add(const ReceiptItem(name: '', price: 0));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final extraction = switch (extra) {
      (final ReceiptExtraction e, final String? _) => e,
      final ReceiptExtraction e => e,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation')),
      body: BlocProvider(
        create: (_) =>
            ConfirmationCubit(repository: const FirebaseReceiptRepository()),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            if (extraction == null || !_initialized) {
              return const Center(child: Text('Aucune donnée OCR.'));
            }
            return _ConfirmationForm(
              settings: settings,
              pharmacyController: _pharmacyController,
              montantController: _montantController,
              dateController: _dateController,
              pharmacyNames: _pharmacyNames,
              items: _items,
              imagePath: _imagePath,
              onUpdateItem: _updateItem,
              onAddItem: _addItem,
              onRemoveItem: _removeItem,
            );
          },
        ),
      ),
    );
  }
}

class _ConfirmationForm extends StatelessWidget {
  const _ConfirmationForm({
    required this.settings,
    required this.pharmacyController,
    required this.montantController,
    required this.dateController,
    required this.pharmacyNames,
    required this.items,
    required this.imagePath,
    required this.onUpdateItem,
    required this.onAddItem,
    required this.onRemoveItem,
  });

  final SettingsState settings;
  final TextEditingController pharmacyController;
  final TextEditingController montantController;
  final TextEditingController dateController;
  final List<String> pharmacyNames;
  final List<ReceiptItem> items;
  final String? imagePath;
  final void Function(int, String, double) onUpdateItem;
  final VoidCallback onAddItem;
  final void Function(int) onRemoveItem;

  /// Ouvre le sélecteur de pharmacie (liste filtrable, sélection obligatoire).
  Future<void> _showPharmacyPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _PharmacyPickerSheet(
        pharmacies: pharmacyNames,
        initialQuery: pharmacyController.text,
        onSelected: (name) {
          pharmacyController.text = name;
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _onSuccess(BuildContext context, ConfirmationState state) {
    context.read<ConfirmationCubit>().reset();
    context.go('/home');
    // Analytics : ticket validé + points crédités (fire-and-forget, jamais bloquant).
    final montant = double.tryParse(montantController.text.replaceAll(',', '.'));
    AppAnalytics().logTicketSubmitted(amount: montant ?? 0);
    AppAnalytics().logPointsEarned(points: state.pointsAdded);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('+${state.pointsAdded} points crédités !')),
    );
  }

  /// Hors ligne : le reçu est en file d'attente locale, envoi auto plus tard.
  void _onQueuedOffline(BuildContext context) {
    context.read<ConfirmationCubit>().reset();
    context.go('/home');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pas de connexion : reçu enregistré sur ton téléphone. '
          'Il sera envoyé automatiquement au retour du réseau (+10 points).',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final montant = double.tryParse(montantController.text.replaceAll(',', '.'));
    final formattedAmount = montant == null
        ? null
        : MoneyFormatter.formatAmount(montant, settings.currencyCode);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Devise : ${settings.currencyCode}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (formattedAmount != null) Text(formattedAmount),
          const SizedBox(height: 24),
          // Pharmacie : SÉLECTION obligatoire dans la liste (pas de saisie
          // libre — évite les fautes de frappe). Le champ ouvre un sélecteur
          // avec zone de recherche.
          TextField(
            controller: pharmacyController,
            readOnly: true,
            onTap: () => _showPharmacyPicker(context),
            decoration: InputDecoration(
              labelText: 'Pharmacie',
              hintText: 'Tape pour choisir dans la liste',
              helperText: pharmacyController.text.isEmpty
                  ? 'Sélection obligatoire — touche le champ pour chercher'
                  : null,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dateController,
            decoration: const InputDecoration(
              labelText: 'Date du reçu (ex: 31/03/2025)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: montantController,
            decoration: const InputDecoration(
              labelText: 'Montant total',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Médicaments (${items.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('Aucune ligne. Ajoute au moins un médicament.')
          else
            ...List.generate(
              items.length,
              (index) => _ItemEditor(
                key: ValueKey(index),
                initialName: items[index].name,
                initialPrice: items[index].price,
                onChanged: (name, price) => onUpdateItem(index, name, price),
                onRemove: () => onRemoveItem(index),
              ),
            ),
          const SizedBox(height: 24),
          BlocConsumer<ConfirmationCubit, ConfirmationState>(
            listener: (context, state) {
              if (state.status == ConfirmationStatus.success) {
                _onSuccess(context, state);
              }
              if (state.status == ConfirmationStatus.queuedOffline) {
                _onQueuedOffline(context);
              }
            },
            builder: (context, state) {
              if (state.status == ConfirmationStatus.submitting) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      context.read<ConfirmationCubit>().submit(
                            pharmacyName: pharmacyController.text,
                            dateText: dateController.text,
                            montantText: montantController.text,
                            items: items,
                            imagePath: imagePath,
                          );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Valider le reçu'),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Éditeur d'une ligne de médicament (nom + prix), autonome en saisie.
class _ItemEditor extends StatefulWidget {
  const _ItemEditor({
    super.key,
    required this.initialName,
    required this.initialPrice,
    required this.onChanged,
    required this.onRemove,
  });

  final String initialName;
  final double initialPrice;
  final void Function(String name, double price) onChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _priceController = TextEditingController(
      text: widget.initialPrice > 0 ? widget.initialPrice.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _notify() {
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    widget.onChanged(_nameController.text.trim(), price ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _nameController,
              onChanged: (_) => _notify(),
              decoration: const InputDecoration(
                labelText: 'Médicament',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _priceController,
              onChanged: (_) => _notify(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de pharmacie : zone de recherche + liste filtrable.
/// Sélection obligatoire (pas de saisie libre → zéro faute de frappe).
class _PharmacyPickerSheet extends StatefulWidget {
  const _PharmacyPickerSheet({
    required this.pharmacies,
    required this.initialQuery,
    required this.onSelected,
  });

  final List<String> pharmacies;
  final String initialQuery;
  final void Function(String) onSelected;

  @override
  State<_PharmacyPickerSheet> createState() => _PharmacyPickerSheetState();
}

class _PharmacyPickerSheetState extends State<_PharmacyPickerSheet> {
  late final TextEditingController _searchController;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _filtered = _applyFilter(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    final source = widget.pharmacies.isEmpty
        ? const <String>[]
        : widget.pharmacies;
    if (q.isEmpty) return source.take(200).toList();
    return source
        .where((name) => name.toLowerCase().contains(q))
        .take(200)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // ~80% de l'écran : liste confortable.
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Rechercher une pharmacie',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _filtered = _applyFilter(value)),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('Aucune pharmacie trouvée.'),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final name = _filtered[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.local_pharmacy_rounded, size: 20),
                        title: Text(name),
                        onTap: () => widget.onSelected(name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
