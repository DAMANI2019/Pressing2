import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/users_service.dart';

class FactureParamsScreen extends StatefulWidget {
  const FactureParamsScreen({super.key});

  @override
  State<FactureParamsScreen> createState() => _FactureParamsScreenState();
}

class _FactureParamsScreenState extends State<FactureParamsScreen> {
  final _nomPressing = TextEditingController();
  final _raison = TextEditingController();
  final _adresse = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  final _pied = TextEditingController();
  final _logo = TextEditingController();
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pressing = context.read<AuthProvider>().pressing;
      if (pressing == null) return;
      _nomPressing.text = pressing.nom;
      _raison.text = pressing.factureRaisonSociale ?? pressing.nom;
      _adresse.text = pressing.factureAdresse ?? pressing.adresse ?? '';
      _telephone.text = pressing.factureTelephone ?? pressing.telephone ?? '';
      _email.text = pressing.factureEmail ?? pressing.email ?? '';
      _pied.text = pressing.facturePiedPage ?? '';
      _logo.text = pressing.factureLogoUrl ?? '';
    });
  }

  Future<void> _sauvegarder() async {
    final auth = context.read<AuthProvider>();
    final id = auth.pressing?.id;
    if (id == null) return;
    setState(() => _envoi = true);
    try {
      final users = UsersService(Supabase.instance.client);
      if (_nomPressing.text.trim().isNotEmpty) {
        await users.renommerPressing(pressingId: id, nom: _nomPressing.text);
      }
      await Supabase.instance.client.from('pressings').update({
        'facture_raison_sociale': _raison.text.trim(),
        'facture_adresse': _adresse.text.trim(),
        'facture_telephone': _telephone.text.trim(),
        'facture_email': _email.text.trim(),
        'facture_pied_page': _pied.text.trim(),
        'facture_logo_url': _logo.text.trim(),
      }).eq('id', id);
      await auth.rafraichir();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En-tête de facture enregistré.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_nomPressing, _raison, _adresse, _telephone, _email, _pied, _logo]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('En-tête des factures')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ces informations apparaissent en haut de chaque facture PDF.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomPressing,
            decoration: const InputDecoration(labelText: 'Nom du pressing'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _raison,
            decoration: const InputDecoration(labelText: 'Raison sociale (facture)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _adresse,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Adresse'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _telephone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _logo,
            decoration: const InputDecoration(labelText: 'URL du logo (optionnel)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pied,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Pied de page'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _envoi ? null : _sauvegarder,
            child: Text(_envoi ? 'Enregistrement…' : 'Enregistrer l’en-tête'),
          ),
        ],
      ),
    );
  }
}
