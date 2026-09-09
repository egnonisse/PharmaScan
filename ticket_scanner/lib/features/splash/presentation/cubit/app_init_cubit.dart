import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/push/push_notification_service.dart';
import '../../../../core/offline/offline_queue_flusher.dart';
import '../../../../firebase_options.dart';
import '../../../scanner/data/repositories/firebase_receipt_repository.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import 'app_init_state.dart';

class AppInitCubit extends Cubit<AppInitState> {
  AppInitCubit({required SettingsCubit settingsCubit})
      : _settingsCubit = settingsCubit,
        super(const AppInitState.initial());

  final SettingsCubit _settingsCubit;

  bool _hasPhone = false;

  /// Code de parrainage (généré une fois, même alphabet sans ambiguïtés).
  String _newReferralCode() {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => alphabet[rand.nextInt(alphabet.length)])
        .join();
  }

  Future<void> init() async {
    emit(state.copyWith(status: AppInitStatus.loading, errorMessage: null));

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Mode hors ligne : cache Firestore persistant — les données déjà
      // chargées (médicaments, pharmacies, gardes) restent lisibles sans
      // réseau. Doit être posé AVANT le premier accès Firestore.
      try {
        FirebaseFirestore.instance.settings =
            const Settings(persistenceEnabled: true);
      } catch (_) {
        // Déjà configuré ailleurs : ignorer.
      }

      final auth = FirebaseAuth.instance;
      // NB : la session Firebase Auth survit hors ligne (persistée
      // localement). Le premier lancement exige le réseau (création du
      // compte anonyme) ; les lancements suivants non.
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }

      final user = auth.currentUser;
      if (user == null) {
        throw StateError('Utilisateur Firebase absent après authentification.');
      }

      // Création/migration du doc utilisateur. TOLÉRANT : hors ligne la
      // transaction échoue → on continue quand même (le doc existe déjà en
      // cache local et sera resynchronisé au retour du réseau).
      try {
        final users = FirebaseFirestore.instance.collection('users');
        final userRef = users.doc(user.uid);

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snapshot = await tx.get(userRef);
          if (!snapshot.exists) {
            tx.set(userRef, {
              'points': 0,
              'currencyCode': _settingsCubit.state.currencyCode,
              'createdAt': FieldValue.serverTimestamp(),
              'referralCode': _newReferralCode(),
            });
            _hasPhone = false;
            return;
          }

          final data = snapshot.data() ?? <String, dynamic>{};
          _hasPhone = (data['phone'] as String? ?? '').isNotEmpty;
          if (!data.containsKey('currencyCode')) {
            tx.update(userRef,
                {'currencyCode': _settingsCubit.state.currencyCode});
          }
          if (!data.containsKey('points')) {
            tx.update(userRef, {'points': 0});
          }
          if ((data['referralCode'] as String? ?? '').isEmpty) {
            tx.update(userRef, {'referralCode': _newReferralCode()});
          }
        });
      } on FirebaseException {
        // Hors ligne : toléré. Le doc sera créé/migré au prochain
        // lancement en ligne.
      }

      // La devise cloud a priorité sur la devise locale. Hors ligne :
      // silencieux (on garde la devise locale).
      try {
        await _settingsCubit.syncWithCloud();
      } catch (_) {
        // Pas de réseau : devise locale conservée.
      }

      // Notifications push : token FCM (non bloquant, silencieux si échec).
      unawaited(PushNotificationService().init());

      // File d'attente hors ligne : soumet les reçus scannés sans réseau
      // dès que la connexion est revenue (non bloquant).
      unawaited(OfflineQueueFlusher(
        repository: const FirebaseReceiptRepository(),
      ).flush());

      emit(state.copyWith(status: AppInitStatus.ready, hasPhone: _hasPhone));
    } on FirebaseAuthException catch (e) {
      final hint = switch (e.code) {
        'admin-restricted-operation' ||
        'operation-not-allowed' ||
        'auth/admin-restricted-operation' ||
        'auth/operation-not-allowed' =>
          "Action requise dans Firebase Console :\n"
              "- Authentication → Sign-in method\n"
              "- Activer le provider **Anonymous**\n\n"
              "Ensuite, relance l’app.",
        _ => null,
      };

      emit(
        state.copyWith(
          status: AppInitStatus.error,
          errorMessage: [
            'Initialisation Firebase impossible (Auth).',
            if (hint != null) hint,
            'Détail: [${e.code}] ${e.message ?? ''}'.trim(),
          ].where((s) => s.trim().isNotEmpty).join('\n\n'),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AppInitStatus.error,
          errorMessage:
              'Initialisation Firebase impossible. Vérifie la configuration (FlutterFire) puis relance.\n\nDétail: $e',
        ),
      );
    }
  }
}
