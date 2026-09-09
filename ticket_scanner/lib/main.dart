import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

/// DSN Sentry (clé publique client — visible dans l'APK par nature,
/// ce n'est pas un secret serveur). Projet : softhubapp.sentry.io/pharmascan.
const _sentryDsn =
    'https://8105111e0328f355a2a383a46e853f28'
    '@o4509831848853504.ingest.de.sentry.io/4512055943626832';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Monitoring des crashs AVANT tout : Sentry capture tout ce qui échoue
  // pendant l'init aussi (Firebase, splash, etc.).
  await SentryFlutter.init(
    (options) {
      options
        ..dsn = _sentryDsn
        ..tracesSampleRate = 0.2
        // Les environnements séparent les crashs de test (interne/fermé)
        // de ceux des vrais utilisateurs (production).
        ..environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () => runZonedGuarded(() async {
      final settingsCubit = SettingsCubit();
      // Attend la détection de devise (zone XOF) AVANT le lancement : le
      // doc utilisateur créé au splash portera la bonne devise.
      await settingsCubit.load();

      // La release Sentry suit la version de l'app (ex : 1.0.11+15).
      final info = await PackageInfo.fromPlatform();
      await Sentry.configureScope((scope) {
        scope.setTag('app_version', '${info.version}+${info.buildNumber}');
      });

      runApp(
        BlocProvider.value(
          value: settingsCubit,
          child: const TicketScannerApp(),
        ),
      );
    }, (error, stack) {
      // Filet de sécurité : toute erreur asynchrone non capturée remonte
      // à Sentry au lieu de planter silencieusement.
      Sentry.captureException(error, stackTrace: stack);
    }),
  );
}
