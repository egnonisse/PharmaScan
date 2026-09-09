import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Écran de connexion par numéro (SANS SMS — MVP validé par LEO).
/// - Le numéro existe déjà → le compte revient (loginByPhone, migration)
/// - Le numéro est libre → il crée/lie le compte (linkPhone)
/// « Plus tard » → compte anonyme (inchangé).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = _phoneController.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 8 || _busy) return;
    setState(() => _busy = true);
    try {
      final functions = FirebaseFunctions.instance;
      String message;
      try {
        final result = await functions
            .httpsCallable('loginByPhone')
            .call({'phone': phone});
        final points = (result.data as Map?)?['points'] ?? 0;
        message = 'Bienvenue ! Ton compte est restauré ($points points).';
      } catch (e) {
        if (!e.toString().contains('not-found')) rethrow;
        // Numéro libre → inscription.
        await functions.httpsCallable('linkPhone').call({'phone': phone});
        message = 'Compte créé. Ton code de parrainage est dans les '
            'Réglages.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      final message = text.contains('already-exists')
          ? 'Ce numéro est déjà utilisé par un autre compte.'
          : text.contains('invalid-argument')
              ? 'Numéro invalide (ex : 07 07 07 07 07).'
              : 'Impossible pour le moment. Réessaie.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
          children: [
            // Logo
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF19B178), AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_pharmacy,
                    color: Colors.white, size: 38),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Bienvenue sur PharmaScan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Comparez. Payez juste.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            // Champ numéro avec préfixe CI
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: const Color(0xFFE4EBE7)),
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF77F00), Colors.white],
                            stops: [0.33, 0.33],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('+225',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '07 00 00 00 00',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.field),
                        borderSide: const BorderSide(color: Color(0xFFE4EBE7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.field),
                        borderSide: const BorderSide(color: Color(0xFFE4EBE7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.field),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _continue,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continuer'),
            ),
            TextButton(
              onPressed: () => context.pop(),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              child: const Text('Plus tard (essayer sans compte)'),
            ),
            const SizedBox(height: 10),
            Text(
              'Ton numéro est ton identifiant : il te retrouve tes points '
              'et ton parrainage si tu changes de téléphone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
