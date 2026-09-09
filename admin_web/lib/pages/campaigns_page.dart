import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/image_picker_field.dart';

/// Page Campagnes — CRUD des bannières affichées dans l'app (home, sous la
/// recherche). Usages : pub pharmacie, annonces de jeux, infos.
class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  static const _collection = 'campaigns';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_collection)
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('Campagnes (${docs.length})',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showEditDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle campagne'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Les bannières actives s\'affichent en carrousel dans l\'app, '
              'juste sous la barre de recherche de l\'accueil.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Aucune campagne. Crée la première !')),
              )
            else
              ...docs.map((doc) => _CampaignTile(
                    doc: doc,
                    onEdit: () => _showEditDialog(context, doc: doc),
                    onDelete: () => _confirmDelete(context, doc),
                    onToggle: (active) =>
                        doc.reference.update({'active': active}),
                  )),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context,
      {QueryDocumentSnapshot? doc}) async {
    final data = doc?.data() as Map<String, dynamic>? ?? const {};
    final formKey = GlobalKey<FormState>();
    final titleController =
        TextEditingController(text: data['title']?.toString() ?? '');
    final subtitleController =
        TextEditingController(text: data['subtitle']?.toString() ?? '');
    final urlController =
        TextEditingController(text: data['url']?.toString() ?? '');
    final colorController = TextEditingController(
        text: data['backgroundColor']?.toString() ?? '#0E7A5F');
    final orderController = TextEditingController(
        text: (data['sortOrder'] as num?)?.toString() ?? '0');
    var active = data['active'] as bool? ?? true;
    var imageUrl = data['imageUrl']?.toString();
    DateTime? startDate = (data['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (data['endDate'] as Timestamp?)?.toDate();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(doc == null ? 'Nouvelle campagne' : 'Modifier la campagne'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                          labelText: 'Titre *', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: subtitleController,
                      decoration: const InputDecoration(
                          labelText: 'Sous-titre',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: urlController,
                      decoration: const InputDecoration(
                          labelText: 'URL au clic (optionnel — sinon fiche pharmacie si choisie)',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: colorController,
                      decoration: const InputDecoration(
                          labelText: 'Couleur de fond (hex, ex : #0E7A5F)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: orderController,
                      decoration: const InputDecoration(
                          labelText: 'Ordre d\'affichage',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    ImagePickerField(
                      prefix: 'campaignImages',
                      initialUrl: imageUrl,
                      onChanged: (url) => imageUrl = url,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommandé : ratio 8:3, 1200×450 px, WebP/JPEG '
                      '< 200 Ko. Zone de sécurité : 5% de marge de chaque '
                      'côté (aperçu des slides voisins). Jamais de remise '
                      'sur médicaments (interdiction réglementaire).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: startDate != null,
                          onChanged: (v) => setDialogState(() {
                            startDate = v == true
                                ? (startDate ?? DateTime.now())
                                : null;
                          }),
                        ),
                        const Text('Date de début'),
                        const Spacer(),
                        if (startDate != null)
                          TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: dialogContext,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                                initialDate: startDate!,
                              );
                              if (d != null) {
                                setDialogState(() => startDate = d);
                              }
                            },
                            child: Text(
                                '${startDate!.day}/${startDate!.month}/${startDate!.year}'),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: endDate != null,
                          onChanged: (v) => setDialogState(() {
                            endDate =
                                v == true ? (endDate ?? DateTime.now()) : null;
                          }),
                        ),
                        const Text('Date de fin'),
                        const Spacer(),
                        if (endDate != null)
                          TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: dialogContext,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                                initialDate: endDate!,
                              );
                              if (d != null) {
                                setDialogState(() => endDate = d);
                              }
                            },
                            child: Text(
                                '${endDate!.day}/${endDate!.month}/${endDate!.year}'),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final colorHex = colorController.text.trim();
    // Validation du format : retombe sur le vert PharmaScan si invalide.
    _parseHex(colorHex);

    final payload = {
      'title': titleController.text.trim(),
      'subtitle': subtitleController.text.trim(),
      'url': urlController.text.trim().isEmpty
          ? null
          : urlController.text.trim(),
      'backgroundColor': colorHex.startsWith('#') ? colorHex : '#0E7A5F',
      'textColor': '#FFFFFF',
      'sortOrder': int.tryParse(orderController.text) ?? 0,
      'active': active,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (startDate != null)
        'startDate': Timestamp.fromDate(DateTime(
            startDate!.year, startDate!.month, startDate!.day)),
      if (endDate != null)
        'endDate': Timestamp.fromDate(
            DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59)),
    };

    if (doc == null) {
      await FirebaseFirestore.instance.collection(_collection).add(payload);
    } else {
      await doc.reference.update(payload);
    }
  }

  Color? _parseHex(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(value);
  }

  Future<void> _confirmDelete(
      BuildContext context, QueryDocumentSnapshot doc) async {
    final title = (doc.data() as Map?)?['title'] ?? '?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette campagne ?'),
        content: Text('« $title » disparaîtra de l\'app.'),
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
    if (ok == true) {
      await doc.reference.delete();
    }
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final QueryDocumentSnapshot doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final active = data['active'] as bool? ?? true;
    final colorHex = data['backgroundColor']?.toString() ?? '#0E7A5F';
    final color = _parseHexStatic(colorHex);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(Icons.campaign, color: Colors.white, size: 24),
        ),
        title: Text(data['title']?.toString() ?? '?'),
        subtitle: Text(
          [
            if ((data['subtitle']?.toString() ?? '').isNotEmpty)
              data['subtitle']!.toString(),
            'Ordre : ${data['sortOrder'] ?? 0}',
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: active, onChanged: onToggle),
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseHexStatic(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return const Color(0xFF0E7A5F);
    return Color(int.tryParse(h, radix: 16) ?? 0xFF0E7A5F);
  }
}
