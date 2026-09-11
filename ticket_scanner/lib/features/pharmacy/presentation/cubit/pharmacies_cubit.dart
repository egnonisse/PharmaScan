import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/firebase_pharmacy_repository.dart';
import '../../domain/entities/pharmacy.dart';
import '../../domain/repositories/pharmacy_repository.dart';

/// États de la vue pharmacies.
sealed class PharmaciesState {
  const PharmaciesState();
}

class PharmaciesLoading extends PharmaciesState {
  const PharmaciesLoading();
}

class PharmaciesReady extends PharmaciesState {
  const PharmaciesReady({
    required this.pharmacies,
    required this.userLat,
    required this.userLng,
    this.errorMessage,
    this.gpsMessage,
    this.gpsBlocked = false,
  });

  final List<Pharmacy> pharmacies;
  final double? userLat;
  final double? userLng;
  final String? errorMessage;

  /// null = position OK. Sinon : raison lisible + action possible.
  final String? gpsMessage;

  /// true = permission refusée définitivement → bouton « Ouvrir réglages ».
  final bool gpsBlocked;

  /// Pharmacies triées par distance croissante (les sans GPS en dernier).
  List<Pharmacy> sortedByDistance() {
    if (userLat == null || userLng == null) {
      return List.of(pharmacies)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final list = List.of(pharmacies);
    list.sort((a, b) {
      final da = a.distanceKmFrom(userLat!, userLng!);
      final db = b.distanceKmFrom(userLat!, userLng!);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return list;
  }
}

class PharmaciesCubit extends Cubit<PharmaciesState> {
  PharmaciesCubit({PharmacyRepository? repository})
      : _repository = repository ?? const FirebasePharmacyRepository(),
        super(const PharmaciesLoading());

  final PharmacyRepository _repository;
  StreamSubscription<List<Pharmacy>>? _sub;
  List<Pharmacy>? _lastPharmacies;

  /// Demande la position une fois et retourne (lat, lng, raison échec).
  Future<(double?, double?, String?, bool)> _getPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (null, null, 'Active le GPS de ton téléphone pour le tri par distance.', false);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return (null, null,
            'Localisation bloquée — autorise-la dans les réglages.', true);
      }
      if (permission == LocationPermission.denied) {
        return (null, null, 'Localisation refusée — pharmacies triées par nom.', false);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (pos.latitude, pos.longitude, null, false);
    } catch (_) {
      return (null, null, 'Position introuvable — vérifie ton GPS puis réessaie.', false);
    }
  }

  void _emit(double? lat, double? lng, String? gpsMessage, bool gpsBlocked) {
    final pharmacies = _lastPharmacies ?? const <Pharmacy>[];
    emit(PharmaciesReady(
      pharmacies: pharmacies,
      userLat: lat,
      userLng: lng,
      gpsMessage: gpsMessage,
      gpsBlocked: gpsBlocked,
    ));
  }

  /// Re-tente la localisation (bouton « Réessayer » de la page).
  Future<void> refreshPosition() async {
    final (lat, lng, msg, blocked) = await _getPosition();
    if (isClosed) return;
    _emit(lat, lng, msg, blocked);
  }

  /// Demande la permission de localisation (avec dialogue explicatif géré
  /// par la page — conformité stores) puis charge les pharmacies.
  Future<void> start() async {
    final (lat, lng, msg, blocked) = await _getPosition();

    _sub ??= _repository.watchPharmacies().listen((pharmacies) {
      if (isClosed) return; // navigation pendant le chargement
      _lastPharmacies = pharmacies;
      _emit(lat, lng, msg, blocked);
    });
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
