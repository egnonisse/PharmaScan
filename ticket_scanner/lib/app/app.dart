import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/profile_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/legal/presentation/pages/legal_page_view.dart';
import '../features/legal/presentation/widgets/legal_section.dart';
import '../features/notification/presentation/pages/notifications_page.dart';
import '../features/scanner/presentation/pages/confirmation_page.dart';
import '../features/scanner/presentation/pages/scanner_page.dart';
import '../features/search/presentation/pages/medication_detail_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/splash/presentation/pages/splash_page.dart';

/// Textes par défaut des pages légales (clé → titre, contenu).
const _legalDefaults = {
  'privacy': ('Politique de confidentialité', DefaultLegalContent.privacy),
  'consent': ('Consentement scan reçus', DefaultLegalContent.consent),
  'medical': ('Avertissement médical', DefaultLegalContent.medical),
  'terms': ('Conditions d\'utilisation', DefaultLegalContent.terms),
  'legal': ('Mentions légales', DefaultLegalContent.legal),
};

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    // Routes racines (pas de sous-route du splash) : le back depuis la home
    // quitte l'app au lieu de revenir au splash et relancer l'init Firebase.
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const ScannerPage(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) =>
          SearchPage(initialQuery: state.uri.queryParameters['q'] ?? ''),
    ),
    GoRoute(
      path: '/medication',
      builder: (context, state) => MedicationDetailPage(
        name: state.uri.queryParameters['name'] ?? '',
        title: state.uri.queryParameters['title'],
      ),
    ),
    GoRoute(
      path: '/confirmation',
      builder: (context, state) => const ConfirmationPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/legal/:key',
      builder: (context, state) {
        final key = state.pathParameters['key'] ?? 'legal';
        final defaults = _legalDefaults[key] ?? _legalDefaults['legal']!;
        return LegalPageView(
          pageKey: key,
          defaultTitle: defaults.$1,
          defaultContent: defaults.$2,
        );
      },
    ),
  ],
);

class TicketScannerApp extends StatelessWidget {
  const TicketScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pharmascan',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
