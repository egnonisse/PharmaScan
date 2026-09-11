import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pharmacy/domain/entities/pharmacy.dart';
import '../../../pharmacy/presentation/pages/pharmacies_page.dart';
import '../../../pharmacy/presentation/widgets/pharmacy_sheet.dart';
import '../../data/repositories/firebase_price_repository.dart';
import '../../data/repositories/firebase_medication_repository.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/price_entry.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

/// Vue recherche : 2 onglets.
/// - Médicaments : recherche par nom, résultats groupés par médicament,
///   chaque médicament déplie la liste des pharmacies triées par prix croissant.
/// - Pharmacies : pharmacies de garde / communes, triées par distance.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  int _tabIndex = 0;

  /// Debounce de la recherche réactive (350 ms après la dernière frappe).
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Lance la recherche avec debounce (recherche réactive pendant la frappe).
  void _scheduleSearch(SearchCubit cubit, String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      cubit.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _TabBar(
              index: _tabIndex,
              onChanged: (i) => setState(() => _tabIndex = i),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                const PharmaciesPage(),
                _buildMedicationTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationTab(BuildContext context) {
    final query = _controller.text.trim();
    return BlocProvider(
      create: (_) {
        final cubit = SearchCubit(
          repository: const FirebasePriceRepository(),
          medicationRepository: const FirebaseMedicationRepository(),
        );
        if (query.length >= 3) {
          cubit.search(query);
        } else {
          cubit.loadPopular();
        }
        return cubit;
      },
      child: Builder(
        builder: (searchContext) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  // Recherche réactive : lance la recherche pendant la frappe
                  // (debounce 350 ms côté State).
                  _scheduleSearch(searchContext.read<SearchCubit>(), value);
                },
                onSubmitted: (value) {
                  _debounceTimer?.cancel();
                  AppAnalytics().logSearch(query: value);
                  searchContext.read<SearchCubit>().search(value);
                },
                decoration: InputDecoration(
                  labelText: 'Nom du médicament',
                  hintText: 'Ex : paracétamol, amoxicilline…',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => searchContext
                        .read<SearchCubit>()
                        .search(_controller.text),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, settings) {
                  return BlocBuilder<SearchCubit, SearchState>(
                    builder: (context, state) {
                      if (state.isSearching) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (state.query.isEmpty) {
                        // Médicaments populaires affichés par défaut.
                        if (state.isSearching) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (state.results.isEmpty) {
                          return const Center(
                            child: Text('Aucun prix pour le moment. '
                                'Scanne un ticket pour contribuer !'),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async {
                            searchContext.read<SearchCubit>().loadPopular();
                            await Future.delayed(
                                const Duration(milliseconds: 800));
                          },
                          child: ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              Text(
                                'Médicaments populaires',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ..._buildPriceGroups(
                                context,
                                state.results,
                                settings.currencyCode,
                              ),
                            ],
                          ),
                        );
                      }
                      if (state.errorMessage != null) {
                        return Center(
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        );
                      }
                      if (state.results.isEmpty && state.medications.isEmpty) {
                        return const Center(
                          child: Text(
                            'Aucun résultat. Essaie un autre nom ou scanne '
                            'un ticket pour ajouter un prix.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          // Relance la recherche courante (ex : après une
                          // coupure réseau) + délai pour le spinner.
                          searchContext
                              .read<SearchCubit>()
                              .search(_controller.text);
                          await Future.delayed(
                              const Duration(milliseconds: 800));
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                          if (state.results.isNotEmpty) ...[
                            Text(
                              'Prix trouvés',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ..._buildPriceGroups(
                              context,
                              state.results,
                              settings.currencyCode,
                            ),
                            if (state.medications.isNotEmpty)
                              const SizedBox(height: 16),
                          ],
                          if (state.medications.isNotEmpty) ...[
                            Text(
                              'Médicaments (prix indisponible)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            for (final med in state.medications)
                              _MedicationTile(medication: med),
                          ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Génére les cartes de résultats AVEC prix, groupées par médicament et
/// triées par prix croissant (moins cher en premier).
List<Widget> _buildPriceGroups(
  BuildContext context,
  List<PriceEntry> entries,
  String currencyCode,
) {
  final groups = <String, List<PriceEntry>>{};
  for (final entry in entries) {
    groups.putIfAbsent(entry.medicationName, () => []).add(entry);
  }
  for (final list in groups.values) {
    list.sort((a, b) => a.price.compareTo(b.price));
  }
  final sortedNames = groups.keys.toList()..sort((a, b) => a.compareTo(b));

  return [
    for (final name in sortedNames)
      Card(
        child: ExpansionTile(
          leading: const Icon(Icons.medication_rounded),
          title: InkWell(
            onTap: () => context.push(
              '/medication?name=${Uri.encodeComponent(name)}'
              '&title=${Uri.encodeComponent(name)}',
            ),
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          subtitle: Text(
            'Dès ${MoneyFormatter.formatAmount(groups[name]!.first.price, currencyCode)} '
            '— ${groups[name]!.length} pharmacie${groups[name]!.length > 1 ? 's' : ''}',
          ),
          children: [
            for (final entry in groups[name]!)
              ListTile(
                dense: true,
                leading: const Icon(Icons.local_pharmacy_rounded),
                title: Text(
                  entry.pharmacyName ?? entry.pharmacyId,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  MoneyFormatter.formatAmount(entry.price, currencyCode),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _openPharmacySheet(context, entry.pharmacyId),
              ),
          ],
        ),
      ),
  ];
}

/// Fiche d'un médicament SANS prix (référentiel ANSM) : nom, DCI,
/// laboratoire, et invitation à scanner un ticket pour révéler le prix.
class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.medication_rounded),
        onTap: () => context.push(
          '/medication?name=${Uri.encodeComponent(medication.name)}'
          '&title=${Uri.encodeComponent(medication.name)}',
        ),
        title: Text(
          medication.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (medication.dcis.isNotEmpty)
              Text(
                medication.dciLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            if (medication.titulaire != null &&
                medication.titulaire!.isNotEmpty)
              Text(
                medication.titulaire!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            const SizedBox(height: 2),
            Text(
              'Prix indisponible — scanne un ticket pour le révéler',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Scanner un ticket',
          icon: const Icon(Icons.qr_code_scanner_rounded),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => context.push('/scanner'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// Ouvre la fiche pharmacie (récupère le doc par id, puis bottom sheet).
Future<void> _openPharmacySheet(BuildContext context, String pharmacyId) async {
  final doc = await FirebaseFirestore.instance
      .collection('pharmacies')
      .doc(pharmacyId)
      .get();
  if (!doc.exists || !context.mounted) return;
  final data = doc.data() ?? <String, dynamic>{};
  final pharmacy = Pharmacy(
    id: doc.id,
    name: data['name'] as String? ?? doc.id,
    address: data['address'] as String?,
    commune: data['commune'] as String?,
    phone1: data['phone1'] as String?,
    phone2: data['phone2'] as String?,
    lat: (data['lat'] as num?)?.toDouble(),
    lng: (data['lng'] as num?)?.toDouble(),
    onDutyDates: (data['onDutyDates'] as List?)?.cast<String>() ?? const [],
  );
  await showPharmacySheet(context, pharmacy: pharmacy);
  AppAnalytics().logPharmacyOpened(pharmacyId: pharmacyId);
}

/// Onglets Médicaments / Pharmacies au style design system (fond gris,
/// onglet actif vert, arrondis 5px).
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'Pharmacies',
            icon: Icons.local_pharmacy_rounded,
            active: index == 0,
            onTap: () => onChanged(0),
          ),
          _TabItem(
            label: 'Médicaments',
            icon: Icons.medication_rounded,
            active: index == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card - 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card - 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
