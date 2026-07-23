import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/models.dart';
import 'providers/auth_provider.dart';
import 'screens/abonnement_expire_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/choix_pressing_screen.dart';
import 'screens/employe/nouvelle_prestation_screen.dart';
import 'screens/employe/operations_screen.dart';
import 'screens/login_screen.dart';
import 'screens/patron/patron_dashboard_screen.dart';
import 'screens/patron/catalogue_screen.dart';
import 'screens/patron/facture_params_screen.dart';
import 'screens/patron/utilisateurs_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class PressingApp extends StatelessWidget {
  const PressingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final router = GoRouter(
      refreshListenable: auth,
      initialLocation: '/',
      redirect: (context, state) {
        final loc = state.matchedLocation;
        if (auth.chargement) return loc == '/' ? null : '/';

        if (!auth.estConnecte) {
          return loc == '/login' ? null : '/login';
        }

        if (auth.besoinChoixPressing) {
          return loc == '/choix-pressing' ? null : '/choix-pressing';
        }
        final role = auth.profil?.role;
        if (role == null) return '/choix-pressing';

        if (role != RoleUtilisateur.superAdmin && !auth.abonnementActif) {
          return loc == '/abonnement-expire' ? null : '/abonnement-expire';
        }

        if (loc == '/' || loc == '/login') {
          switch (role) {
            case RoleUtilisateur.superAdmin:
              return '/admin';
            case RoleUtilisateur.patron:
              return '/patron';
            case RoleUtilisateur.employe:
              return '/employe';
          }
        }

        if (role == RoleUtilisateur.superAdmin && !loc.startsWith('/admin')) {
          return '/admin';
        }
        if (role == RoleUtilisateur.patron && !loc.startsWith('/patron')) {
          return '/patron';
        }
        if (role == RoleUtilisateur.employe && !loc.startsWith('/employe')) {
          return '/employe';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: '/abonnement-expire',
          builder: (context, state) => const AbonnementExpireScreen(),
        ),
        GoRoute(
          path: '/choix-pressing',
          builder: (context, state) => const ChoixPressingScreen(),
        ),
        GoRoute(
          path: '/employe',
          builder: (context, state) => const NouvellePrestationScreen(),
        ),
        GoRoute(
          path: '/employe/operations',
          builder: (context, state) => const OperationsScreen(),
        ),
        GoRoute(
          path: '/patron',
          builder: (context, state) => const PatronDashboardScreen(),
        ),
        GoRoute(
          path: '/patron/utilisateurs',
          builder: (context, state) => const UtilisateursScreen(),
        ),
        GoRoute(
          path: '/patron/catalogue',
          builder: (context, state) => const CatalogueScreen(),
        ),
        GoRoute(
          path: '/patron/facture',
          builder: (context, state) => const FactureParamsScreen(),
        ),
        GoRoute(
          path: '/patron/operations',
          builder: (context, state) => const OperationsScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Pressing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.clair,
      routerConfig: router,
    );
  }
}
