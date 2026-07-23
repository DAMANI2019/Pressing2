import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/users_service.dart';

class ChoixPressingScreen extends StatefulWidget {
  const ChoixPressingScreen({super.key});
  @override
  State<ChoixPressingScreen> createState() => _ChoixPressingScreenState();
}

class _ChoixPressingScreenState extends State<ChoixPressingScreen> {
  final _nom = TextEditingController();
  late final UsersService _service;
  List<Pressing> _pressings = [];
  String? _choix;
  String? _erreur;
  bool _chargement = true;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _service = UsersService(Supabase.instance.client);
    _charger();
  }

  Future<void> _charger() async {
    try {
      final liste = await _service.listPressingsForChoix();
      if (mounted) setState(() { _pressings = liste; _chargement = false; });
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _chargement = false; });
    }
  }

  Future<void> _valider() async {
    if (_choix == null || _nom.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez un pressing et indiquez votre nom.')));
      return;
    }
    setState(() => _envoi = true);
    try {
      await context.read<AuthProvider>().rattacherAuPressing(
        pressingId: _choix!, nomComplet: _nom.text,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  void dispose() { _nom.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choisir votre pressing')),
    body: _chargement ? const Center(child: CircularProgressIndicator()) : Padding(
      padding: const EdgeInsets.all(20),
      child: _erreur != null ? Center(child: Text(_erreur!)) : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Votre compte doit être rattaché à un établissement.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _choix,
            decoration: const InputDecoration(labelText: 'Pressing'),
            items: _pressings.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nom))).toList(),
            onChanged: (v) => setState(() => _choix = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _nom, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom complet')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _envoi ? null : _valider, child: Text(_envoi ? 'Enregistrement…' : 'Continuer')),
        ],
      ),
    ),
  );
}
