import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page Questions secrètes — liste paramétrable affichée dans le
/// dropdown d'inscription de l'app (connexion par numéro).
/// Champs : text, active, order.
class SecurityQuestionsPage extends StatefulWidget {
  const SecurityQuestionsPage({super.key});

  @override
  State<SecurityQuestionsPage> createState() => _SecurityQuestionsPageState();
}

class _SecurityQuestionsPageState extends State<SecurityQuestionsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('securityQuestions')
        .add({
      'text': text,
      'active': true,
      'order': DateTime.now().millisecondsSinceEpoch,
    });
    _controller.clear();
  }

  Future<void> _toggle(DocumentSnapshot doc) async {
    await doc.reference.update({
      'active': !(doc.data() as Map?)?['active'] == true,
    });
  }

  Future<void> _delete(DocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette question ?'),
        content: const Text(
            'Les comptes existants gardent leur question (copie texte) — '
            'elle ne sera plus proposée aux nouveaux.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Nouvelle question (ex : Nom de ta première '
                        'école ?)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('securityQuestions')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = (snapshot.data!.docs.toList())
                ..sort((a, b) => ((a.data() as Map?)?['order'] as num? ?? 0)
                    .compareTo((b.data() as Map?)?['order'] as num? ?? 0));
              if (docs.isEmpty) {
                return const Center(child: Text('Aucune question.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final active = (doc.data() as Map?)?['active'] == true;
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text(
                        (doc.data() as Map?)?['text'] as String? ?? '?',
                        style: TextStyle(
                          color: active ? null : Colors.grey,
                          decoration:
                              active ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: active,
                            onChanged: (_) => _toggle(doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Supprimer',
                            onPressed: () => _delete(doc),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
