import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/whatsapp_service.dart';

class AbonnementExpireScreen extends StatelessWidget {
  const AbonnementExpireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final telAdmin = dotenv.env['TELEPHONE_ADMIN'] ?? '2250700000000';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonnement'),
        actions: [
          IconButton(
            onPressed: () => auth.seDeconnecter(),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_clock, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              auth.raisonBlocage ??
                  'Votre abonnement n’est plus actif.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                final nom = auth.pressing?.nom ?? 'mon pressing';
                ouvrirConversationWhatsApp(
                  telAdmin,
                  'Bonjour, je souhaite renouveler l’abonnement de $nom.',
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Contacter l’administrateur (WhatsApp)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => auth.rafraichir(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
