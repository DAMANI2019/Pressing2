import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/users_service.dart';

class UtilisateursScreen extends StatefulWidget {
  const UtilisateursScreen({super.key});
  @override
  State<UtilisateursScreen> createState() => _UtilisateursScreenState();
}

class _UtilisateursScreenState extends State<UtilisateursScreen> {
  late final UsersService _service;
  List<Utilisateur> _users = [];
  bool _chargement = true;
  @override
  void initState() { super.initState(); _service = UsersService(Supabase.instance.client); WidgetsBinding.instance.addPostFrameCallback((_) => _charger()); }
  Future<void> _charger() async {
    final id = context.read<AuthProvider>().profil?.pressingId;
    if (id == null) return;
    try { final users = await _service.listUsers(id); if (mounted) setState(() { _users = users; _chargement = false; }); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> _ajouter() async {
    final email = TextEditingController(); final motDePasse = TextEditingController(); final nom = TextEditingController();
    var role = RoleUtilisateur.employe;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('Ajouter un utilisateur'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom complet')),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
        TextField(controller: motDePasse, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe (6 caractères minimum)')),
        DropdownButtonFormField<RoleUtilisateur>(value: role, decoration: const InputDecoration(labelText: 'Rôle'), items: const [
          DropdownMenuItem(value: RoleUtilisateur.patron, child: Text('Admin')),
          DropdownMenuItem(value: RoleUtilisateur.employe, child: Text('Utilisateur')),
        ], onChanged: (v) => setDialog(() => role = v ?? role)),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer'))],
    )));
    if (ok == true) {
      final pressingId = context.read<AuthProvider>().profil!.pressingId!;
      try { await _service.createUserViaSignUp(pressingId: pressingId, email: email.text, password: motDePasse.text, nomComplet: nom.text, role: role); await _charger(); }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'))); }
    }
    email.dispose(); motDePasse.dispose(); nom.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Utilisateurs')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _ajouter, icon: const Icon(Icons.person_add), label: const Text('Ajouter')),
    body: _chargement ? const Center(child: CircularProgressIndicator()) : ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: _users.length,
      itemBuilder: (_, i) { final u = _users[i]; return Card(child: ListTile(
        title: Text(u.nomComplet), subtitle: Text('${u.role == RoleUtilisateur.patron ? 'Admin' : 'Utilisateur'} · ${u.actif ? 'Actif' : 'Désactivé'}'),
        trailing: u.actif ? IconButton(icon: const Icon(Icons.person_off_outlined), tooltip: 'Désactiver', onPressed: () async { await _service.deactivateUser(u.id); _charger(); }) : null,
      )); },
    ),
  );
}
