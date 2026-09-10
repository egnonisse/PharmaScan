import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Écran de connexion par numéro + QUESTION SECRÈTE (validé par LEO —
/// remplace le SMS : zéro coût, reconnexion protégée).
///
/// Flux :
/// 1. Numéro → loginByPhone
///    - not-found → INSCRIPTION : dropdown question + réponse → linkPhone
///    - needsSecret → RECONNEXION : la question s'affiche → réponse
///    - succès → compte restauré
/// 2. « Plus tard » → anonyme.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _LoginStep { phone, secret, registering }

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _answerController = TextEditingController();
  String _questionId = '';
  String _secretQuestionText = '';
  bool _busy = false;
  _LoginStep _step = _LoginStep.phone;

  @override
  void dispose() {
    _phoneController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    final phone = _phoneController.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      _snack('Numéro invalide (ex : 07 07 07 07 07).');
      return;
    }
    setState(() => _busy = true);
    try {
      final functions = FirebaseFunctions.instance;

      if (_step == _LoginStep.phone) {
        // Phase 1 : le numéro existe-t-il ?
        try {
          final result = await functions
              .httpsCallable('loginByPhone')
              .call({'phone': phone});
          final data = result.data as Map? ?? {};
          if (data['needsSecret'] == true) {
            setState(() {
              _step = _LoginStep.secret;
              _secretQuestionText =
                  data['question'] as String? ?? 'Question secrète';
            });
            _snack('Compte trouvé — réponds à ta question secrète.');
            return;
          }
          _snack('Bienvenue ! Ton compte est restauré.');
          if (mounted) context.go('/home');
          return;
        } catch (e) {
          if (!e.toString().contains('not-found')) rethrow;
          // Numéro libre → inscription (dropdown question).
          setState(() => _step = _LoginStep.registering);
          return;
        }
      }

      if (_step == _LoginStep.secret) {
        // Phase 2 : réponse à la question secrète.
        await functions
            .httpsCallable('loginByPhone')
            .call({'phone': phone, 'answer': _answerController.text});
        _snack('Bienvenue ! Ton compte est restauré.');
        if (mounted) context.go('/home');
        return;
      }

      // Inscription : question + réponse obligatoires.
      if (_questionId.isEmpty) {
        _snack('Choisis une question secrète.');
        return;
      }
      if (_answerController.text.trim().length < 3) {
        _snack('Réponse trop courte (3 caractères minimum).');
        return;
      }
      await functions.httpsCallable('linkPhone').call({
        'phone': phone,
        'securityQuestionId': _questionId,
        'securityAnswer': _answerController.text,
      });
      _snack('Compte créé. Ton code de parrainage est dans les Réglages.');
      if (mounted) context.go('/home');
    } catch (e) {
      final text = e.toString();
      final message = text.contains('failed-precondition')
          ? 'Réponse incorrecte. Réessaie.'
          : text.contains('already-exists')
              ? 'Ce numéro est déjà utilisé par un autre compte.'
              : text.contains('invalid-argument')
                  ? 'Question secrète et réponse requises.'
                  : 'Impossible pour le moment. Réessaie.';
      _snack(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
          children: [
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
              switch (_step) {
                _LoginStep.phone => 'Bienvenue sur PharmaScan',
                _LoginStep.secret => 'Vérification',
                _LoginStep.registering => 'Crée ton compte',
              },
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              switch (_step) {
                _LoginStep.phone => 'Comparez. Payez juste.',
                _LoginStep.secret => _secretQuestionText,
                _LoginStep.registering =>
                  'Choisis une question secrète pour protéger ton compte.',
              },
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            // Champ numéro (masqué pendant la phase secrète).
            if (_step != _LoginStep.secret)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: const Color(0xFFE4EBE7)),
                      borderRadius: BorderRadius.circular(AppRadii.field),
                    ),
                    child: const Text('+225',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: _step == _LoginStep.phone,
                      decoration: InputDecoration(
                        hintText: '07 00 00 00 00',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.field),
                          borderSide:
                              const BorderSide(color: Color(0xFFE4EBE7)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.field),
                          borderSide:
                              const BorderSide(color: Color(0xFFE4EBE7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.field),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            // Question secrète (inscription : dropdown).
            if (_step == _LoginStep.registering) ...[
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('securityQuestions')
                    .where('active', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final questions = (snapshot.data?.docs ?? []).toList()
                    ..sort((a, b) => ((a.data() as Map?)?['order'] as num? ?? 0)
                        .compareTo((b.data() as Map?)?['order'] as num? ?? 0));
                  return DropdownButtonFormField<String>(
                    initialValue: _questionId.isEmpty ? null : _questionId,
                    decoration: InputDecoration(
                      labelText: 'Question secrète',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.field),
                      ),
                    ),
                    items: [
                      for (final doc in questions)
                        DropdownMenuItem(
                          value: doc.id,
                          child: Text(
                            (doc.data() as Map?)?['text'] as String? ?? '?',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _questionId = v ?? ''),
                  );
                },
              ),
            ],
            // Réponse (inscription + reconnexion).
            if (_step != _LoginStep.phone) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _answerController,
                decoration: InputDecoration(
                  labelText: 'Ta réponse',
                  hintText: _step == _LoginStep.secret
                      ? 'La réponse choisie à l\'inscription'
                      : 'Réponse mémorable (3 caractères min)',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                ),
              ),
            ],
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
                  : Text(switch (_step) {
                      _LoginStep.phone => 'Continuer',
                      _LoginStep.secret => 'Vérifier',
                      _LoginStep.registering => 'Créer mon compte',
                    }),
            ),
            // « Plus tard » : volontairement DISCRET (lien texte léger) —
            // le bouton principal (création de compte) reste dominant.
            TextButton(
              onPressed: () => context.go('/home'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.bodySmall,
              ),
              child: const Text('Plus tard (essayer sans compte)'),
            ),
            const SizedBox(height: 10),
            Text(
              'Ton numéro est ton identifiant. Ta question secrète protège '
              'ton compte si tu changes de téléphone.',
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
