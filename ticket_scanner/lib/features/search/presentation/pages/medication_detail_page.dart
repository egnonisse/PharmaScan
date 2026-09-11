import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../cubit/medication_detail_cubit.dart';

/// Fiche médicament : prix comparés + informations (base prix + ANSM).
/// Paramètres de route : `name` (nom normalisé) et `title` (nom affiché).
class MedicationDetailPage extends StatefulWidget {
  const MedicationDetailPage({super.key, required this.name, this.title});

  final String name;
  final String? title;

  @override
  State<MedicationDetailPage> createState() => _MedicationDetailPageState();
}

class _MedicationDetailPageState extends State<MedicationDetailPage> {
  late final MedicationDetailCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = MedicationDetailCubit(
      normalizedName: widget.name,
      displayName: widget.title ?? widget.name,
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _share() {
    final currency = context.read<SettingsCubit>().state.currencyCode;
    final best = _bestPriceText(currency);
    SharePlus.instance.share(
      ShareParams(
        text: 'PharmaScan — Comparez. Payez juste.\n\n'
            '${widget.title ?? widget.name}\n'
            'Prix dès $best.\n\n'
            'Compare les prix des médicaments en pharmacie : '
            'https://play.google.com/store/apps/details?id=com.softhubapp.scanapp',
      ),
    );
  }

  String _bestPriceText(String currency) {
    final state = _cubit.state;
    if (state is MedicationDetailReady && state.prices.isNotEmpty) {
      return MoneyFormatter.formatAmount(state.prices.first.price, currency);
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MedicationDetailCubit, MedicationDetailState>(
      bloc: _cubit,
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Fiche médicament'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
          ),
          body: switch (state) {
            MedicationDetailLoading() =>
              const Center(child: CircularProgressIndicator()),
            MedicationDetailError(message: final msg) => Center(
                child: Text(msg),
              ),
            MedicationDetailReady() =>
              BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, settings) => _buildContent(
                  context,
                  state,
                  settings.currencyCode,
                ),
              ),
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    MedicationDetailReady state,
    String currencyCode,
  ) {
    final med = state.medication;
    final molecule = (med?.dcis.isNotEmpty ?? false)
        ? med!.dciLabel
        : (state.prices.isNotEmpty
            ? state.prices.first.therapeuticGroup
            : null);
    final group =
        state.prices.where((p) => p.therapeuticGroup != null).map((p) => p.therapeuticGroup!).firstOrNull;
    final code =
        state.prices.where((p) => p.code != null).map((p) => p.code!).firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── En-tête ──────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (molecule != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MoleculeBadge(text: molecule),
                ),
              Text(
                state.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
              ),
              if (med?.form != null) ...[
                const SizedBox(height: 4),
                Text(
                  med!.form!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
              if (group != null || med?.routes != null || code != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (group != null) _Tag(text: group),
                    if (med?.routes != null) _Tag(text: 'Voie ${med!.routes}'),
                    if (code != null) _Tag(text: 'Code $code'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Prix comparés ────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prix comparés — ${state.prices.length} '
                'source${state.prices.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              if (state.prices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aucun prix connu pour ce médicament. '
                    'Scanne un ticket pour révéler son prix !',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                )
              else
                for (var i = 0; i < state.prices.length; i++)
                  _PriceRow(
                    index: i,
                    priceInfo: state.prices[i],
                    currencyCode: currencyCode,
                  ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scanner un prix',
                      primary: true,
                      onTap: () => context.push('/scanner'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share_rounded,
                      label: 'Partager',
                      onTap: _share,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Informations ─────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informations',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              _KvRow(label: 'Molécule (DCIS)',
                  value: med?.dciLabel.isNotEmpty == true ? med!.dciLabel : '—'),
              _KvRow(label: 'Groupe thérapeutique', value: group ?? '—'),
              _KvRow(label: 'Forme', value: med?.form ?? '—'),
              _KvRow(label: "Voie d'administration", value: med?.routes ?? '—'),
              _KvRow(label: 'Laboratoire', value: med?.titulaire ?? '—'),
              _KvRow(label: 'Code national', value: code ?? '—'),
              _KvRow(
                label: 'Statut',
                value: state.ansmStatus ?? '—',
                valueColor: state.ansmStatus != null
                    ? AppColors.primary
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Les prix réels sont ajoutés par la communauté PharmaScan à '
          'chaque ticket scanné.\nComparez. Payez juste.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class _MoleculeBadge extends StatelessWidget {
  const _MoleculeBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F3EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        border: Border.all(color: const Color(0xFFE4EBE7)),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.index,
    required this.priceInfo,
    required this.currencyCode,
  });

  final int index;
  final MedicationPriceInfo priceInfo;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final isBest = index == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBest
                    ? AppColors.primary
                    : const Color(0xFFF1F4F2),
              ),
              child: Text(
                isBest && !priceInfo.isOfficial
                    ? '${index + 1}'
                    : (priceInfo.isOfficial ? '—' : '${index + 1}'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isBest ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          priceInfo.pharmacyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 6),
                        _MiniBadge(
                          label: 'LE MOINS CHER',
                          color: AppColors.primary,
                          background: const Color(0xFFE4F3EE),
                        ),
                      ] else if (priceInfo.isOfficial) ...[
                        const SizedBox(width: 6),
                        _MiniBadge(
                          label: 'RÉFÉRENCE',
                          color: AppColors.textMuted,
                          background: const Color(0xFFF1F4F2),
                        ),
                      ],
                    ],
                  ),
                  if (priceInfo.scannedAt != null)
                    Text(
                      'Relevé le ${_formatDate(priceInfo.scannedAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              MoneyFormatter.formatAmount(priceInfo.price, currencyCode),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: primary ? null : Border.all(color: const Color(0xFFE4EBE7)),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20, color: primary ? Colors.white : AppColors.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
