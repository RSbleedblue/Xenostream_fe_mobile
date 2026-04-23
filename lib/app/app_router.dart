import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/session/active_voice_profile_store.dart';
import '../features/home/presentation/home_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/voice_enrollment/data/voice_enrollment_repository.dart';
import '../features/voice_enrollment/presentation/bloc/enrollment_bloc.dart';
import '../features/voice_enrollment/presentation/enrollment_page.dart';
import '../features/voice_synthesis/presentation/synthesis_page.dart';
import 'widgets/app_shell.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/',
        redirect: (BuildContext context, GoRouterState state) => '/home',
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return const NoTransitionPage<void>(child: HomePage());
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/record',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return NoTransitionPage<void>(
                    child: BlocProvider(
                      create: (BuildContext ctx) => EnrollmentBloc(
                        repository: ctx.read<VoiceEnrollmentRepository>(),
                        activeVoiceProfileStore: ctx.read<ActiveVoiceProfileStore>(),
                      ),
                      child: const EnrollmentPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return const NoTransitionPage<void>(child: SynthesisPage());
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return const NoTransitionPage<void>(child: SettingsPage());
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
