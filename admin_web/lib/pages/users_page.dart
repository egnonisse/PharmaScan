import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page Utilisateurs — profils complets : numéro, profil, points,
/// contributions, parrainage (code + filleuls), statut.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query _baseQuery() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(200);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Filtrer par numéro (ex : 0745…, 07, +225)…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _query.isEmpty
                ? _baseQuery().snapshots()
                : FirebaseFirestore.instance
                    .collection('users')
                    .where('phone', isGreaterThanOrEqualTo: _query)
                    .where('phone', isLessThanOrEqualTo: '$_query\uf8ff')
                    .limit(50)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur : ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('Aucun utilisateur.'));
              }

              final totalPoints = docs.fold<int>(0, (total, d) {
                final pts = (d.data() as Map?)?['points'] as num?;
                return total + (pts?.toInt() ?? 0);
              });
              final withPhone = docs.where((d) =>
                  ((d.data() as Map?)?['phone'] as String? ?? '')
                      .isNotEmpty).length;
              final withProfile = docs.where((d) =>
                  (d.data() as Map?)?['profileCompleted'] == true).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(
                    children: [
                      Text('Utilisateurs (${docs.length})',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      Text('$totalPoints pts · $withPhone avec numéro · '
                          '$withProfile profils complétés',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...docs.map((doc) {
                    final data = (doc.data() as Map?) ?? const {};
                    return _UserTile(doc: doc, data: data);
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.doc, required this.data});

  final QueryDocumentSnapshot doc;
  final Map data;

  String _niveau(int points) {
    if (points >= 500) return 'Or';
    if (points >= 200) return 'Argent';
    if (points >= 50) return 'Bronze';
    return 'Contributeur';
  }

  Color _niveauColor(String niveau) {
    switch (niveau) {
      case 'Or':
        return const Color(0xFFD4AF37);
      case 'Argent':
        return const Color(0xFF8E9AAF);
      case 'Bronze':
        return const Color(0xFF9C6B30);
      default:
        return Colors.grey;
    }
  }

  String _displayName() {
    final firstName = (data['firstName'] as String?) ?? '';
    final lastName = (data['lastName'] as String?) ?? '';
    if (firstName.isNotEmpty) {
      return [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    }
    final phone = (data['phone'] as String?) ?? '';
    if (phone.isNotEmpty) return phone;
    return 'Anonyme';
  }

  @override
  Widget build(BuildContext context) {
    final points = (data['points'] as num?)?.toInt() ?? 0;
    final contributions = (data['contributions'] as num?)?.toInt() ?? 0;
    final currency = data['currencyCode'] ?? 'XOF';
    final createdAt = data['createdAt'] as Timestamp?;
    final niveau = _niveau(points);
    final phone = (data['phone'] as String?) ?? '';
    final referralCode = (data['referralCode'] as String?) ?? '';
    final referredByName = (data['referredByName'] as String?) ?? '';
    final referralActivated = data['referralActivated'] == true;
    final profileCompleted = data['profileCompleted'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _niveauColor(niveau).withValues(alpha: 0.15),
          child: Icon(
            profileCompleted ? Icons.person : Icons.person_outline,
            color: _niveauColor(niveau),
          ),
        ),
        title: Text(
          _displayName(),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            'Niveau : $niveau',
            'Contributions : $contributions',
            if (profileCompleted) 'Profil ✓',
          ].join('  ·  '),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$points pts',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              tooltip: 'Corriger les points',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editPoints(context),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Identifiant', value: doc.id),
                if (phone.isNotEmpty) _InfoRow(label: 'Téléphone', value: phone),
                _InfoRow(label: 'Devise', value: currency),
                if (createdAt != null)
                  _InfoRow(
                    label: 'Inscrit',
                    value: createdAt.toDate().toLocal().toString().substring(0, 10),
                  ),
                if (referralCode.isNotEmpty)
                  _InfoRow(label: 'Code parrain', value: referralCode),
                if (referredByName.isNotEmpty)
                  _InfoRow(
                    label: 'Parrainé par',
                    value: '$referredByName${referralActivated ? ' (activé)' : ' (en attente du 1er scan)'}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPoints(BuildContext context) async {
    final controller = TextEditingController(
        text: ((data['points'] as num?)?.toInt() ?? 0).toString());
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Corriger les points'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Points', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    final value = int.tryParse(saved);
    if (value == null) return;
    await doc.reference.update({'points': value});
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
