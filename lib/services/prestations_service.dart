import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/format.dart';
import 'storage_service.dart';

class ArticleDraft {
  ArticleDraft({
    required this.typeHabit,
    required this.prixUnitaire,
    this.quantite = 1,
    this.description,
    this.defauts,
    this.photos = const [],
  });

  String typeHabit;
  double prixUnitaire;
  int quantite;
  String? description;
  String? defauts;
  List<Uint8List> photos;
}

class PrestationsService {
  PrestationsService(this._client) : _storage = StorageService(_client);

  final SupabaseClient _client;
  final StorageService _storage;

  Future<Prestation> creerPrestationAvecPhotos({
    required String pressingId,
    required String employeId,
    required String clientNom,
    required String clientTelephone,
    String? notes,
    required List<ArticleDraft> articles,
  }) async {
    final numeroTicket = genererNumeroTicket();

    final created = await _client
        .from('prestations')
        .insert({
          'pressing_id': pressingId,
          'employe_id': employeId,
          'client_nom': clientNom,
          'client_telephone': clientTelephone,
          'numero_ticket': numeroTicket,
          'notes': notes,
        })
        .select()
        .single();

    final prestationId = created['id'] as String;
    final lignes = <Map<String, dynamic>>[];

    for (var i = 0; i < articles.length; i++) {
      final article = articles[i];
      final urls = <String>[];
      for (final bytes in article.photos) {
        final url = await _storage.uploaderPhotoHabit(
          pressingId: pressingId,
          prestationId: prestationId,
          bytes: bytes,
        );
        urls.add(url);
      }

      String? photoUrl;
      if (urls.length == 1) {
        photoUrl = urls.first;
      } else if (urls.length > 1) {
        photoUrl = jsonEncode(urls);
      }

      lignes.add({
        'prestation_id': prestationId,
        'pressing_id': pressingId,
        'type_habit': article.typeHabit,
        'description': article.description,
        'defauts': article.defauts,
        'photo_url': photoUrl,
        'prix_unitaire': article.prixUnitaire,
        'quantite': article.quantite,
      });
    }

    if (lignes.isNotEmpty) {
      await _client.from('articles_prestation').insert(lignes);
    }

    final finale = await _client
        .from('prestations')
        .select('*, articles_prestation(*)')
        .eq('id', prestationId)
        .single();

    return Prestation.fromJson(Map<String, dynamic>.from(finale));
  }

  Future<List<ArticlePrestation>> listerArticles(String prestationId) async {
    final data = await _client
        .from('articles_prestation')
        .select()
        .eq('prestation_id', prestationId)
        .order('created_at');

    return (data as List)
        .map((e) => ArticlePrestation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Prestation>> lister({
    required String pressingId,
    required IntervalleDates intervalle,
  }) async {
    final data = await _client
        .from('prestations')
        .select('*, articles_prestation(*)')
        .eq('pressing_id', pressingId)
        .gte('date_depot', intervalle.debut.toIso8601String())
        .lte('date_depot', intervalle.fin.toIso8601String())
        .order('date_depot', ascending: false);
    return (data as List)
        .map((e) => Prestation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> marquerLivre(String prestationId) => _client
      .from('prestations')
      .update({'statut': 'livre', 'date_livraison': DateTime.now().toIso8601String()})
      .eq('id', prestationId);
}
