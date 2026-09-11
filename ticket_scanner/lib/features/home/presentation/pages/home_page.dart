import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notification/presentation/widgets/notification_bell.dart';
import '../../../pharmacy/presentation/widgets/pharmacy_sheet.dart';
import '../../data/repositories/firebase_home_repository.dart';
import '../../domain/entities/contributor_profile.dart';
import '../../domain/entities/points_event.dart';
import '../../../../features/pharmacy/domain/entities/pharmacy.dart';
import '../../../../features/pharmacy/data/repositories/firebase_pharmacy_repository.dart';
import '../../../campaign/presentation/widgets/campaign_carousel.dart';
import '../../../announcement/presentation/widgets/announcement_popup_host.dart';
import '../../../legal/presentation/widgets/medical_warning_host.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FirebaseHomeRepository(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );

    return BlocProvider(
      create: (_) => HomeCubit(repository: repository)..start(),
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.appBarStart, AppColors.appBarEnd],
              ),
            ),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PharmaScan'),
              SizedBox(height: 1),
              Text(
                'Comparez. Payez juste.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => context.push('/scanner'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scanner un ticket',
            ),
            const NotificationBell(),
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Réglages',
            ),
          ],
        ),
        body: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            return BlocBuilder<HomeCubit, HomeState>(
              builder: (context, home) {
                // Pull-to-refresh : relance le profil + l'historique, et les
                // StreamBuilders (campagnes, gardes, médicaments récents) se
                // resynchronisent via Firestore temps réel.
                return RefreshIndicator(
                  onRefresh: () => context.read<HomeCubit>().refresh(),
                  child: ListView(
                    // Marge basse généreuse : le dernier bloc (historique)
                    // reste pleinement visible au-dessus de la barre système.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                    // Avertissement médical (1er lancement) puis popup
                    // d'annonce (dashboard) — widgets invisibles.
                    const MedicalWarningHost(),
                    const AnnouncementPopupHost(),
                    _SearchBar(onTap: () => context.push('/search')),
                    const SizedBox(height: 14),
                    const CampaignCarousel(),
                    const SizedBox(height: 14),
                    _ContributorHeader(profile: home.profile),
                    const SizedBox(height: 14),
                    const _OnDutySection(),
                    const SizedBox(height: 14),
                    const _PopularMedsSection(),
                    const SizedBox(height: 14),
                    Text(
                      'Historique',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (home.isLoading && home.events.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (home.events.isEmpty)
                      Text(
                        'Aucun événement pour le moment.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ...home.events.map(
                        (e) => _PointsEventTile(
                          event: e,
                          currencyCode: settings.currencyCode,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Barre de recherche : carte blanche dans le contenu (Option A validée).
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.field),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.field),
            boxShadow: AppShadows.searchBar,
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  readOnly: true,
                  showCursor: false,
                  onTap: onTap,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un médicament ou une pharmacie…',
                    hintStyle:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge contributeur (points + reçus validés + niveau) — carte avec ombre douce.
class _ContributorHeader extends StatelessWidget {
  const _ContributorHeader({required this.profile});

  final ContributorProfile profile;

  @override
  Widget build(BuildContext context) {
    final tier = profile.tier;
    final next = profile.nextThreshold;
    final progressLabel = next == null
        ? 'Niveau maximum'
        : 'Encore ${profile.pointsToNext} points '
            'pour passer ${tier.label} → ${_nextTierLabel(tier)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF7E6C4), AppColors.gold],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.icon),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33D4AF37),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _tierIcon(tier),
                  color: const Color(0xFF6B4D0A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contributeur ${tier.label}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.contributions} reçu'
                      '${profile.contributions > 1 ? 's' : ''} scanné'
                      '${profile.contributions > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${profile.points} pts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: next == null
                  ? 1
                  : ((profile.points / next).clamp(0.0, 1.0)),
              minHeight: 6,
              backgroundColor: const Color(0xFFE8EFE9),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static IconData _tierIcon(ContributorTier tier) => switch (tier) {
        ContributorTier.bronze => Icons.workspace_premium_rounded,
        ContributorTier.silver => Icons.military_tech_rounded,
        ContributorTier.gold => Icons.emoji_events,
      };

  static String _nextTierLabel(ContributorTier tier) => switch (tier) {
        ContributorTier.bronze => 'Argent',
        ContributorTier.silver => 'Or',
        ContributorTier.gold => '',
      };
}

/// Pharmacies de garde aujourd'hui, triées par distance (si GPS dispo).
class _OnDutySection extends StatelessWidget {
  const _OnDutySection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pharmacy>>(
      stream: const FirebasePharmacyRepository().watchPharmacies(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final today = _todayIso();
        final onDuty = snapshot.data!
            .where((p) => p.isOnDutyOn(today))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Pharmacies de garde',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/search'),
                    child: const Text('Voir tout'),
                  ),
                ],
              ),
              if (onDuty.isEmpty)
                Text(
                  'Aucune pharmacie de garde aujourd\'hui.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                ...onDuty.take(3).map(
                      (p) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () => showPharmacySheet(
                          context,
                          pharmacy: p,
                          isOnDuty: true,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.iconBg,
                            borderRadius: BorderRadius.circular(AppRadii.icon),
                          ),
                          child: const Icon(
                            Icons.local_pharmacy_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: p.commune == null
                            ? null
                            : Text(
                                p.commune!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  static String _todayIso() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

/// Chips rapides : médicaments populaires (recherche pré-remplie).
class _PopularMedsSection extends StatelessWidget {
  const _PopularMedsSection();

  /// Fallback affiché tant qu'aucun reçu n'a été scanné.
  static const _fallbackMeds = [
    'paracétamol',
    'amoxicilline',
    'ibuprofène',
    'vitamine c',
    'doliprane',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Médicaments récents',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/search'),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Les médicaments RÉELLEMENT scannés (priceEntries), les plus
        // récents d'abord, dédupliqués par nom. Fallback sur la liste de
        // démarrage si la base est vide.
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('priceEntries')
              .orderBy('scannedAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData) {
              return _ChipsRow(meds: _fallbackMeds);
            }
            final seen = <String>{};
            final recent = <String>[];
            for (final doc in snapshot.data!.docs) {
              final name = ((doc.data() as Map?)?['medicationName'] as String?)
                      ?.trim() ??
                  '';
              if (name.isEmpty) continue;
              final key = name.toLowerCase();
              if (seen.add(key)) {
                recent.add(name);
                if (recent.length >= 10) break;
              }
            }
            if (recent.isEmpty) {
              return _ChipsRow(meds: _fallbackMeds);
            }
            return _ChipsRow(meds: recent);
          },
        ),
      ],
    );
  }
}

/// Rangée de chips cliquables (nom → recherche pré-remplie).
class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.meds});

  final List<String> meds;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final med in meds)
          ActionChip(
            avatar: const Icon(Icons.medication_rounded,
                size: 18, color: AppColors.primary),
            label: Text(med),
            labelStyle: Theme.of(context).textTheme.labelMedium,
            onPressed: () =>
                context.push('/search?q=${Uri.encodeQueryComponent(med)}'),
          ),
      ],
    );
  }
}

class _PointsEventTile extends StatelessWidget {
  const _PointsEventTile({
    required this.event,
    required this.currencyCode,
  });

  final PointsEvent event;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (event.receiptId != null) {
      subtitleParts.add('Reçu: ${event.receiptId!.substring(0, 8)}…');
    }
    if (event.amount != null) {
      subtitleParts.add(
        'Montant: ${MoneyFormatter.formatAmount(event.amount!, currencyCode)}',
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.iconBg,
            borderRadius: BorderRadius.circular(AppRadii.icon),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        title: Text(
          '+${event.pointsAdded} points',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }
}
