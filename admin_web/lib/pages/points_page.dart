import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page « Points » — gestion du programme de fidélité :
/// 1. Configuration : points gagnés par scan (lue par la Cloud Function)
/// 2. Ajustements manuels : +N/-N avec motif (visibles dans l'historique
///    de l'utilisateur dans l'app)
/// 3. Historique global des derniers mouvements de points.
class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  final _configController = TextEditingController();
  final _bronzeController = TextEditingController();
  final _referralController = TextEditingController();
  final _profileController = TextEditingController();
  final _silverController = TextEditingController();
  final _goldController = TextEditingController();
  bool _loading = true;
  bool _savingConfig = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final doc = await FirebaseFirestore.instance
        .collection('pointsConfig')
        .doc('default')
        .get();
    if (!mounted) return;
    final data = doc.data() ?? const {};
    setState(() {
      _configController.text =
          (data['pointsPerReceipt'] as num?)?.toString() ?? '10';
      _referralController.text =
          (data['referralReward'] as num?)?.toString() ?? '20';
      _profileController.text =
          (data['profileBonus'] as num?)?.toString() ?? '50';
      _bronzeController.text =
          (data['bronzeThreshold'] as num?)?.toString() ?? '50';
      _silverController.text =
          (data['silverThreshold'] as num?)?.toString() ?? '200';
      _goldController.text =
          (data['goldThreshold'] as num?)?.toString() ?? '500';
      _loading = false;
    });
  }

  Future<void> _saveConfig() async {
    final value = int.tryParse(_configController.text.trim());
    final referral = int.tryParse(_referralController.text.trim());
    final profileBonus = int.tryParse(_profileController.text.trim());
    final bronze = int.tryParse(_bronzeController.text.trim());
    final silver = int.tryParse(_silverController.text.trim());
    final gold = int.tryParse(_goldController.text.trim());
    if (value == null || value <= 0 ||
        referral == null || referral <= 0 ||
        profileBonus == null || profileBonus <= 0 ||
        bronze == null || silver == null || gold == null) {
      _setStatus('Valeurs invalides (entiers positifs requis).', error: true);
      return;
    }
    if (!(bronze < silver && silver < gold)) {
      _setStatus('Les seuils doivent être croissants : Bronze < Argent < Or.',
          error: true);
      return;
    }
    setState(() => _savingConfig = true);
    try {
      await FirebaseFirestore.instance
          .collection('pointsConfig')
          .doc('default')
          .set({
        'pointsPerReceipt': value,
        'referralReward': referral,
        'profileBonus': profileBonus,
        'bronzeThreshold': bronze,
        'silverThreshold': silver,
        'goldThreshold': gold,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _setStatus('✅ Config enregistrée (points/scan = $value, '
          'parrainage = $referral, '
          'niveaux $bronze/$silver/$gold). L\'app met à jour les niveaux '
          'automatiquement.');
    } catch (e) {
      _setStatus('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  void _setStatus(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Gestion des points',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Le programme de fidélité : points gagnés au scan de reçus, '
          'niveaux Bronze/Argent/Or, ajustements manuels motivés.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),

        // --- 1. Configuration ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configuration',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _configController,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points gagnés par scan',
                    border: OutlineInputBorder(),
                    helperText:
                        'Lu par la Cloud Function à chaque scan (fallback 10).',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _referralController,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points de parrainage (bonus)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Crédités au parrain ET au filleul au premier scan '
                        'du filleul (fallback 20).',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _profileController,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points profil complété (bonus)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Crédités au premier remplissage du profil '
                        '(fallback 50).',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bronzeController,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Seuil Bronze',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _silverController,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Seuil Argent',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _goldController,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Seuil Or',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Niveaux basés sur les POINTS (lus par l\'app à chaque '
                  'ouverture — changements immédiats).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _savingConfig || _loading ? null : _saveConfig,
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(_savingConfig ? 'Enregistrement…' : 'Enregistrer'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- 2. Ajustements manuels ---
        _buildAdjustmentSection(context),
        const SizedBox(height: 16),

        // --- 3. Historique global ---
        Text('Derniers mouvements de points',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('pointsEvents')
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Erreur : ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Text('Aucun mouvement pour le moment.');
            }
            return Column(
              children: [
                for (final doc in docs)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      (doc.data() as Map?)?['reason'] == null
                          ? Icons.receipt_long
                          : Icons.manage_accounts,
                      size: 20,
                    ),
                    title: Text(
                      '+${(doc.data() as Map?)?['pointsAdded'] ?? 0} pts',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      (doc.data() as Map?)?['reason']?.toString() ??
                          'Scan de reçu'
                              '${(doc.data() as Map?)?['receiptId'] != null ? ' (auto)' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      doc.reference.parent.parent?.id.substring(0, 6) ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Ajustement manuel : sélection utilisateur + montant + motif.
  Widget _buildAdjustmentSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajustements manuels',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Bonus (ex : correction, geste commercial) ou retrait, avec '
              'motif visible par l\'utilisateur dans son historique.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('points', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('Aucun utilisateur.');
                return Column(
                  children: [
                    for (final doc in docs)
                      _UserAdjustRow(doc: doc, onDone: _setStatus),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'ajustement pour UN utilisateur.
class _UserAdjustRow extends StatefulWidget {
  const _UserAdjustRow({required this.doc, required this.onDone});

  final QueryDocumentSnapshot doc;
  final void Function(String, {bool error}) onDone;

  @override
  State<_UserAdjustRow> createState() => _UserAdjustRowState();
}

class _UserAdjustRowState extends State<_UserAdjustRow> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _applying = false;

  Future<void> _apply(int sign) async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      widget.onDone('Montant invalide.', error: true);
      return;
    }
    final delta = sign * amount;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      widget.onDone('Motif obligatoire (visible par l\'utilisateur).',
          error: true);
      return;
    }

    setState(() => _applying = true);
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doc.id);
      final currentPoints =
          (widget.doc.data() as Map?)?['points'] as num? ?? 0;
      final newPoints = (currentPoints + delta).clamp(0, 1 << 30);

      // Mise à jour du solde + événement d'historique avec motif.
      await userRef.update({'points': newPoints});
      await userRef.collection('pointsEvents').add({
        'pointsAdded': delta,
        'reason': reason,
        'manual': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      widget.onDone('✅ ${delta > 0 ? '+' : ''}$delta points (${widget.doc.id.substring(0, 6)}…) — $reason');
      _amountController.clear();
      _reasonController.clear();
    } catch (e) {
      widget.onDone('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map?;
    final points = (data?['points'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doc.id.substring(0, 8),
                  style: const TextStyle(fontSize: 12),
                ),
                Text('$points pts',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Ajouter',
            onPressed: _applying ? null : () => _apply(1),
            icon: const Icon(Icons.add_circle, color: Colors.green),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: _applying ? null : () => _apply(-1),
            icon: const Icon(Icons.remove_circle, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
