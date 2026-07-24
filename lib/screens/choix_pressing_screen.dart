import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/users_service.dart';

/// 1ʳᵉ connexion : créer son pressing (patron) ou rejoindre un pressing existant.
class ChoixPressingScreen extends StatefulWidget {
  const ChoixPressingScreen({super.key});

  @override
  State<ChoixPressingScreen> createState() => _ChoixPressingScreenState();
}

class _ChoixPressingScreenState extends State<ChoixPressingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final UsersService _service;

  final _nomComplet = TextEditingController();
  final _nomPressing = TextEditingController();
  List<Pressing> _pressings = [];
  String? _choix;
  String? _erreur;
  bool _chargement = true;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _service = UsersService(Supabase.instance.client);
    _charger();
  }

  Future<void> _charger() async {
    try {
      final liste = await _service.listPressingsForChoix();
      if (mounted) {
        setState(() {
          _pressings = liste;
          _chargement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = '$e';
          _chargement = false;
        });
      }
    }
  }

  Future<void> _creerPressing() async {
    if (_nomPressing.text.trim().isEmpty || _nomComplet.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez le nom du pressing et votre nom.')),
      );
      return;
    }
    setState(() => _envoi = true);
    try {
      await context.read<AuthProvider>().creerMonPressing(
            nomPressing: _nomPressing.text,
            nomComplet: _nomComplet.text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _rejoindre() async {
    if (_choix == null || _nomComplet.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un pressing et indiquez votre nom.')),
      );
      return;
    }
    setState(() => _envoi = true);
    try {
      await context.read<AuthProvider>().rattacherAuPressing(
            pressingId: _choix!,
            nomComplet: _nomComplet.text,
          );
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
    _tabs.dispose();
    _nomComplet.dispose();
    _nomPressing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Votre pressing'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Créer mon pressing'),
            Tab(text: 'Rejoindre'),
          ],
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? Center(child: Text(_erreur!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: TextField(
                        controller: _nomComplet,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Votre nom complet'),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'En tant que patron / admin, donnez le nom de votre établissement.',
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _nomPressing,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Nom du pressing',
                                    hintText: 'Ex. Pressing Excellence',
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: _envoi ? null : _creerPressing,
                                  child: Text(_envoi ? 'Création…' : 'Créer et continuer'),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Rejoindre un pressing déjà créé (utilisateur simple).',
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _choix,
                                  decoration: const InputDecoration(labelText: 'Pressing'),
                                  items: _pressings
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p.id,
                                          child: Text(p.nom),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() => _choix = v),
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: _envoi ? null : _rejoindre,
                                  child: Text(_envoi ? 'Enregistrement…' : 'Rejoindre'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
