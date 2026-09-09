import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'ai_settings_page.dart';
import 'analytics_page.dart';
import 'campaigns_page.dart';
import 'guardes_page.dart';
import 'legal_pages_page.dart';
import 'medicaments_page.dart';
import 'merges_page.dart';
import 'notifications_page.dart';
import 'pharmacies_page.dart';
import 'points_page.dart';
import 'receipts_page.dart';
import 'security_questions_page.dart';
import 'users_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _service = FirestoreService();
  int _selectedIndex = 0;

  Future<Map<String, int>> _loadStats() async {
    final pharmacies = await _service.countPharmacies();
    final receipts = await _service.countReceipts();
    final prices = await _service.countPriceEntries();
    return {'pharmacies': pharmacies, 'receipts': receipts, 'prices': prices};
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _StatsView(loadStats: _loadStats),
      const PharmaciesPage(),
      const GuardesPage(),
      const MergesPage(),
      const MedicamentsPage(),
      const UsersPage(),
      const PointsPage(),
      const SecurityQuestionsPage(),
      const AnalyticsPage(),
      const AiSettingsPage(),
      const CampaignsPage(),
      const NotificationsPage(),
      const LegalPagesPage(),
      const ReceiptsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmascan Admin'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Stats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_pharmacy),
                label: Text('Pharmacies'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_hospital),
                label: Text('Gardes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.merge),
                label: Text('Fusions'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.medication),
                label: Text('Prix'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Utilisateurs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.stars),
                label: Text('Points'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.lock_outline),
                label: Text('Questions secrètes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.insights),
                label: Text('Analytics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.smart_toy),
                label: Text('Paramètres IA'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.campaign),
                label: Text('Campagnes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications),
                label: Text('Notifications'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.gavel),
                label: Text('Pages légales'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long),
                label: Text('Reçus'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.loadStats});

  final Future<Map<String, int>> Function() loadStats;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: loadStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data ?? const {};
        return GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _StatCard(
              icon: Icons.local_pharmacy,
              label: 'Pharmacies',
              value: stats['pharmacies'] ?? 0,
            ),
            _StatCard(
              icon: Icons.receipt_long,
              label: 'Reçus soumis',
              value: stats['receipts'] ?? 0,
            ),
            _StatCard(
              icon: Icons.price_check,
              label: 'Prix collectés',
              value: stats['prices'] ?? 0,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
