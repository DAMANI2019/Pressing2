import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/catalogue_service.dart';
import '../../utils/format.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});
  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  late final CatalogueService _service;
  List<CatalogueItem> _items = [];
  bool _chargement = true;
  @override
  void initState() { super.initState(); _service = CatalogueService(Supabase.instance.client); WidgetsBinding.instance.addPostFrameCallback((_) => _charger()); }
  Future<void> _charger() async {
    final id = context.read<AuthProvider>().profil?.pressingId; if (id == null) return;
    try { final items = await _service.lister(id); if (mounted) setState(() { _items = items; _chargement = false; }); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> _editer([CatalogueItem? item]) async {
    final libelle = TextEditingController(text: item?.libelle); final prix = TextEditingController(text: item?.prixDefaut.toString() ?? '');
    var categorie = item?.categorie ?? CatalogueService.categories.first;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(item == null ? 'Ajouter au catalogue' : 'Modifier l’article'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: libelle, decoration: const InputDecoration(labelText: 'Libellé')),
        TextField(controller: prix, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix par défaut (FCFA)')),
        DropdownButtonFormField(value: categorie, decoration: const InputDecoration(labelText: 'Catégorie'), items: CatalogueService.categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))).toList(), onChanged: (v) => setDialog(() => categorie = v ?? categorie)),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer'))],
    )));
    if (ok == true && libelle.text.trim().isNotEmpty) {
      final prixDefaut = double.tryParse(prix.text.replaceAll(',', '.')) ?? 0;
      if (item == null) await _service.creer(pressingId: context.read<AuthProvider>().profil!.pressingId!, libelle: libelle.text, categorie: categorie, prixDefaut: prixDefaut);
      else await _service.modifier(CatalogueItem(id: item.id, pressingId: item.pressingId, libelle: libelle.text, categorie: categorie, prixDefaut: prixDefaut, actif: item.actif));
      _charger();
    }
    libelle.dispose(); prix.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Catalogue')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _editer(), icon: const Icon(Icons.add), label: const Text('Article')),
    body: _chargement ? const Center(child: CircularProgressIndicator()) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _items.length, itemBuilder: (_, i) {
      final item = _items[i]; return Card(child: ListTile(
        title: Text(item.libelle), subtitle: Text('${item.categorie.replaceAll('_', ' ')} · ${formaterMontant(item.prixDefaut)}'),
        leading: Switch(value: item.actif, onChanged: (_) async { await _service.basculer(item); _charger(); }),
        onTap: () => _editer(item),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await _service.supprimer(item.id); _charger(); }),
      ));
    }),
  );
}
