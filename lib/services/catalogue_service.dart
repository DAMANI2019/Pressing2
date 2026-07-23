import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class CatalogueService {
  CatalogueService(this._client);
  final SupabaseClient _client;

  static const categories = [
    'lavage',
    'repassage',
    'lavage_repassage',
    'nettoyage',
    'autre',
  ];

  Future<List<CatalogueItem>> lister(String pressingId, {bool actifsSeulement = false}) async {
    var query = _client.from('pressing_catalogue').select().eq('pressing_id', pressingId);
    if (actifsSeulement) query = query.eq('actif', true);
    final data = await query.order('categorie').order('libelle');
    final items = (data as List)
        .map((e) => CatalogueItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (items.isNotEmpty) return items;
    await semerDefauts(pressingId);
    return lister(pressingId, actifsSeulement: actifsSeulement);
  }

  Future<void> semerDefauts(String pressingId) async {
    final existants = await _client
        .from('pressing_catalogue')
        .select('id')
        .eq('pressing_id', pressingId)
        .limit(1);
    if ((existants as List).isNotEmpty) return;
    await _client.from('pressing_catalogue').insert([
      {'pressing_id': pressingId, 'libelle': 'Chemise', 'categorie': 'lavage_repassage', 'prix_defaut': 1000, 'actif': true},
      {'pressing_id': pressingId, 'libelle': 'Pantalon', 'categorie': 'lavage_repassage', 'prix_defaut': 1200, 'actif': true},
      {'pressing_id': pressingId, 'libelle': 'Robe', 'categorie': 'lavage_repassage', 'prix_defaut': 2000, 'actif': true},
      {'pressing_id': pressingId, 'libelle': 'Costume', 'categorie': 'nettoyage', 'prix_defaut': 3500, 'actif': true},
      {'pressing_id': pressingId, 'libelle': 'Repassage simple', 'categorie': 'repassage', 'prix_defaut': 500, 'actif': true},
    ]);
  }

  Future<CatalogueItem> creer({
    required String pressingId,
    required String libelle,
    required String categorie,
    required double prixDefaut,
  }) async {
    final data = await _client.from('pressing_catalogue').insert({
      'pressing_id': pressingId, 'libelle': libelle.trim(), 'categorie': categorie,
      'prix_defaut': prixDefaut, 'actif': true,
    }).select().single();
    return CatalogueItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> modifier(CatalogueItem item) => _client.from('pressing_catalogue').update({
    'libelle': item.libelle.trim(), 'categorie': item.categorie,
    'prix_defaut': item.prixDefaut, 'actif': item.actif,
  }).eq('id', item.id);

  Future<void> basculer(CatalogueItem item) =>
      _client.from('pressing_catalogue').update({'actif': !item.actif}).eq('id', item.id);

  Future<void> supprimer(String id) =>
      _client.from('pressing_catalogue').delete().eq('id', id);
}
