import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/app_init_cubit.dart';
import '../cubit/app_init_state.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppInitCubit(settingsCubit: context.read<SettingsCubit>())
        ..init(),
      child: BlocListener<AppInitCubit, AppInitState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == AppInitStatus.ready,
        listener: (context, state) => context.go(
          state.hasPhone ? '/home' : '/login',
        ),
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Splash officiel (design fourni par LEO : logo + slogan +
              // décorations, ratio portrait téléphone → cover parfait).
              Image.asset(
                'assets/images/splash_full.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.white,
                ),
              ),
              if (true)
                BlocBuilder<AppInitCubit, AppInitState>(
                  builder: (context, state) {
                    if (state.status == AppInitStatus.error) {
                      return SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Erreur au démarrage',
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  state.errorMessage ?? 'Erreur inconnue',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () =>
                                      context.read<AppInitCubit>().init(),
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    // Spinner discret en bas pendant l'initialisation.
                    return const Align(
                      alignment: Alignment(0, 0.82),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

