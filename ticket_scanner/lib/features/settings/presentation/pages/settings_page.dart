import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../legal/presentation/widgets/legal_section.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Devise',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Devise d’affichage',
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.currencyCode,
                    isExpanded: true,
                    items: SettingsCubit.supportedCurrencies()
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: state.isLoading
                        ? null
                        : (value) {
                            if (value == null) return;
                            cubit.setCurrencyCode(value);
                          },
                  ),
                ),
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
              const SizedBox(height: 20),
              // Parrainage : code perso + saisie d'un code (points bonus).
              const _ReferralSection(),
              const SizedBox(height: 20),
              // Compte : numéro lié + profil (optionnel, bonus points).
              const _AccountSection(),
              const SizedBox(height: 20),
              // Partager l'app avec l'entourage (bouche-à-oreille).
              Card(
                child: ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Partager PharmaScan'),
                  subtitle: const Text(
                    'Invite ton entourage à comparer les prix des '
                    'médicaments',
                  ),
                  onTap: () => SharePlus.instance.share(
                    ShareParams(
                      text: 'PharmaScan — Comparez. Payez juste.\n\n'
                          'Compare les prix des médicaments dans les '
                          'pharmacies près de chez toi et trouve les '
                          'pharmacies de garde.\n\n'
                          'Télécharge ici : '
                          'https://play.google.com/store/apps/details'
                          '?id=com.softhubapp.scanapp',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const LegalSection(),
              const SizedBox(height: 24),
              // Version de l'app : indispensable pour le support et pour
              // vérifier qu'une mise à jour est bien arrivée.
              Center(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return Text(
                      info == null
                          ? 'PharmaScan'
                          : 'PharmaScan ${info.version} '
                              '(${info.buildNumber})',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Section Compte : numéro lié (connexion simple) + profil optionnel.
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final phone = (data['phone'] as String?) ?? '';
        final firstName = (data['firstName'] as String?) ?? '';
        final completed = data['profileCompleted'] == true;

        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: AppColors.primary),
                title: Text(phone.isEmpty
                    ? 'Lier mon numéro'
                    : (firstName.isNotEmpty ? 'Compte de $firstName' : 'Mon compte')),
                subtitle: Text(phone.isEmpty
                    ? 'Retrouve tes points et ton parrainage si tu changes '
                        'de téléphone'
                    : phone),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push('/login'),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined,
                    color: AppColors.primary),
                title: const Text('Mon profil'),
                subtitle: Text(completed
                    ? 'Complété — merci !'
                    : 'Optionnel : prénom, date de naissance, genre '
                        '(bonus points)'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push('/profile'),
              ),
              if (phone.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.logout,
                      color: Theme.of(context).colorScheme.error),
                  title: const Text('Se déconnecter'),
                  subtitle: const Text(
                      'Tu pourras te reconnecter avec ton numéro et ta '
                      'question secrète'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    // Retour au splash : relance le cycle (nouveau compte
                    // anonyme) puis l'écran de connexion.
                    if (context.mounted) context.go('/');
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Section Parrainage : code perso + partage + saisie d'un code.
/// Le bonus (parrain ET filleul) est crédité au PREMIER scan du filleul.
class _ReferralSection extends StatefulWidget {
  const _ReferralSection();

  @override
  State<_ReferralSection> createState() => _ReferralSectionState();
}

class _ReferralSectionState extends State<_ReferralSection> {
  final _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activateCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('activateReferral');
      final result = await callable.call({'code': code});
      final sponsorName = (result.data as Map?)?['sponsorName'] ?? 'ton parrain';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenue ! Tu es parrainé par $sponsorName. '
            'Le bonus arrive à ton premier scan.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('not-found')) return 'Code introuvable. Vérifie et réessaie.';
    if (text.contains('failed-precondition')) {
      return text.contains('propres')
          ? 'Tu ne peux pas utiliser ton propre code.'
          : 'Tu as déjà un parrain.';
    }
    if (text.contains('invalid-argument')) return 'Code invalide.';
    return 'Impossible pour le moment. Réessaie plus tard.';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final code = (data['referralCode'] as String?) ?? '';
        final referredByName = (data['referredByName'] as String?) ?? '';
        final activated = data['referralActivated'] == true;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Parrainage',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Ton code parrain :',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4F3EE),
                          borderRadius: BorderRadius.circular(AppRadii.field),
                        ),
                        child: Text(
                          code.isEmpty ? '…' : code,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Partager mon code',
                      icon: const Icon(Icons.share, color: AppColors.primary),
                      onPressed: code.isEmpty
                          ? null
                          : () => SharePlus.instance.share(
                                ShareParams(
                                  text: 'PharmaScan — Comparez. Payez juste.\n\n'
                                      'Utilise mon code de parrainage '
                                      '$code pour gagner des points bonus '
                                      'à ton premier scan.\n\n'
                                      'Télécharge ici : '
                                      'https://play.google.com/store/apps/details'
                                      '?id=com.softhubapp.scanapp',
                                ),
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Chaque filleul qui scanne son premier ticket rapporte '
                  'des points bonus à vous deux.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 12),
                if (referredByName.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F2),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Text(
                      activated
                          ? 'Parrainage validé — merci $referredByName !'
                          : 'Parrainé par $referredByName — le bonus arrive '
                              'à ton premier scan.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Code de parrainage',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submitting ? null : _activateCode,
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Valider'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

