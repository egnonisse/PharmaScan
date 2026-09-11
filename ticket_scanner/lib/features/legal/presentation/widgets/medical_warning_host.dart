import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Avertissement médical affiché une seule fois (premier lancement).
///
/// Widget invisible à placer dans la home. Mémorisation locale via
/// shared_preferences (aucune donnée uploadée). Bouton « En savoir plus »
/// vers la page légale complète.
class MedicalWarningHost extends StatefulWidget {
  const MedicalWarningHost({super.key});

  @override
  State<MedicalWarningHost> createState() => _MedicalWarningHostState();
}

class _MedicalWarningHostState extends State<MedicalWarningHost> {
  static const _prefsKey = 'medical_warning_seen_v1';

  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_locked) return;
    _locked = true;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsKey) ?? false;
    if (seen || !mounted) return;

    final learnMore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB3261E), Color(0xFF8C1D16)],
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 28),
        ),
        title: const Text(
          'Avertissement médical',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'PharmaScan est un outil d\'information sur les prix des '
          'médicaments. Il ne remplace pas un médecin ni un pharmacien.\n\n'
          'En cas d\'urgence, appelez le SAMU (185) ou le 112.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('En savoir plus'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('J\'ai compris'),
          ),
        ],
      ),
    );

    // Mémoriser l'affichage (qu'on en sache plus ou pas).
    await prefs.setBool(_prefsKey, true);
    if (!mounted) return;

    if (learnMore == true) {
      context.push('/legal/medical');
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
