import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/price_entry.dart';
import '../../domain/repositories/price_repository.dart';

class FirebasePriceRepository implements PriceRepository {
  const FirebasePriceRepository();

  /// Filtres de visibilité chargés depuis contentConfig/default.
  Future<_ContentFilters> _loadFilters() async {
    Map<String, dynamic> data;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('contentConfig')
          .doc('default')
          .get();
      data = doc.data() ?? <String, dynamic>{};
    } catch (_) {
      // Hors ligne : aucun filtre (tout reste visible) — pas de crash.
      data = <String, dynamic>{};
    }
    return _ContentFilters(
      hiddenMedications: (data['hiddenMedications'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const {},
      disabledCategories: (data['disabledCategories'] as List?)
              ?.map((e) => e.toString().toUpperCase())
              .toSet() ??
          const {},
    );
  }

  /// Normalise un nom (minuscules, sans accents) — même règle que la
  /// Cloud Function à la soumission.
  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  @override
  Stream<List<PriceEntry>> searchByMedication(String query) {
    final normalized = normalize(query);
    if (normalized.isEmpty) return Stream.value(const []);

    final ref = FirebaseFirestore.instance
        .collection('priceEntries')
        .where('medicationName', isGreaterThanOrEqualTo: normalized)
        .where('medicationName', isLessThanOrEqualTo: '$normalized\uf8ff')
        .orderBy('medicationName')
        .orderBy('price')
        .limit(30);

    return ref.snapshots().asyncMap(
      (snapshot) async {
        final filters = await _loadFilters();
        return snapshot.docs
            .map((doc) => PriceEntryModel.fromDoc(doc))
            .where((m) => !filters.hiddenMedications.contains(m.medicationName))
            .where((m) =>
                m.therapeuticGroup == null ||
                !filters.disabledCategories
                    .contains(m.therapeuticGroup!.toUpperCase()))
            .map((m) => m.toEntity())
            .toList(growable: false);
      },
    );
  }

  @override
  Stream<List<PriceEntry>> watchPopularMeds() {
    final ref = FirebaseFirestore.instance
        .collection('priceEntries')
        .orderBy('scannedAt', descending: true)
        .limit(120);
    return ref.snapshots().asyncMap(
      (snapshot) async {
        final filters = await _loadFilters();
        final seen = <String>{};
        final popular = <PriceEntry>[];
        for (final doc in snapshot.docs) {
          final model = PriceEntryModel.fromDoc(doc);
          if (filters.hiddenMedications.contains(model.medicationName)) {
            continue;
          }
          if (model.therapeuticGroup != null &&
              filters.disabledCategories
                  .contains(model.therapeuticGroup!.toUpperCase())) {
            continue;
          }
          if (seen.add(model.medicationName)) {
            popular.add(model.toEntity());
          }
          if (popular.length >= 20) break;
        }
        return popular;
      },
    );
  }
}

class _ContentFilters {
  const _ContentFilters({
    required this.hiddenMedications,
    required this.disabledCategories,
  });

  final Set<String> hiddenMedications;
  final Set<String> disabledCategories;
}

class PriceEntryModel {
  const PriceEntryModel({
    required this.id,
    required this.medicationName,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.price,
    required this.quantity,
    required this.scannedAt,
    this.therapeuticGroup,
  });

  final String id;
  final String medicationName;
  final String pharmacyId;
  final String? pharmacyName;
  final num price;
  final num quantity;
  final Timestamp? scannedAt;
  final String? therapeuticGroup;

  PriceEntry toEntity() {
    return PriceEntry(
      id: id,
      medicationName: medicationName,
      pharmacyId: pharmacyId,
      pharmacyName: pharmacyName,
      price: price.toDouble(),
      quantity: quantity.toInt(),
      scannedAt: scannedAt?.toDate(),
    );
  }

  static PriceEntryModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PriceEntryModel(
      id: doc.id,
      medicationName: data['medicationName'] as String? ?? '',
      pharmacyId: data['pharmacyId'] as String? ?? '',
      pharmacyName: data['pharmacyName'] as String?,
      price: data['price'] as num? ?? 0,
      quantity: data['quantity'] as num? ?? 1,
      scannedAt: data['scannedAt'] as Timestamp?,
      therapeuticGroup: data['therapeuticGroup'] as String?,
    );
  }
}
