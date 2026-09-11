import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Écran Profil (optionnel) : prénom, nom, date de naissance, genre.
/// Premier remplissage → bonus de points (CF completeProfile).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  String _gender = '';
  bool _busy = false;
  bool _loading = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
    } catch (_) {
      // Hors ligne : on garde le formulaire vide (pas de crash).
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final data = doc.data() ?? <String, dynamic>{};
    if (!mounted) return;
    setState(() {
      _firstNameController.text = data['firstName'] as String? ?? '';
      _lastNameController.text = data['lastName'] as String? ?? '';
      _birthDateController.text = data['birthDate'] as String? ?? '';
      _gender = data['gender'] as String? ?? '';
      _completed = data['profileCompleted'] == true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('completeProfile')
          .call({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'birthDate': _birthDateController.text,
        'gender': _gender,
      });
      final bonus = (result.data as Map?)?['bonus'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bonus > 0
              ? 'Profil enregistré — +$bonus points de bonus !'
              : 'Profil enregistré.'),
        ),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible pour le moment. Réessaie.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 25);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_completed)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F3EE),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Text(
                      'Complète ton profil (optionnel) et reçois des '
                      'points bonus. Ces infos servent à personnaliser '
                      'ton expérience.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _birthDateController,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  decoration: const InputDecoration(
                    labelText: 'Date de naissance (optionnel)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gender.isEmpty ? null : _gender,
                  decoration: const InputDecoration(
                    labelText: 'Genre (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'homme', child: Text('Homme')),
                    DropdownMenuItem(value: 'femme', child: Text('Femme')),
                    DropdownMenuItem(
                        value: 'autre', child: Text('Autre / ne pas dire')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? ''),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
    );
  }
}
