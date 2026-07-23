import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/format.dart';

class IndicateursDashboard {
  IndicateursDashboard({
    required this.chiffreAffaires,
    required this.nombrePrestations,
    required this.nombreArticles,
    required this.panierMoyen,
  });

  final double chiffreAffaires;
  final int nombrePrestations;
  final int nombreArticles;
  final double panierMoyen;
}

class DonneesDashboard {
  DonneesDashboard({required this.indicateurs, required this.prestations});
  final IndicateursDashboard indicateurs;
  final List<Prestation> prestations;
}

class DashboardService {
  DashboardService(this._client);
  final SupabaseClient _client;

  Future<DonneesDashboard> charger({
    required String pressingId,
    required IntervalleDates intervalle,
  }) async {
    final data = await _client
        .from('prestations')
        .select('*, articles_prestation(*)')
        .eq('pressing_id', pressingId)
        .gte('date_depot', intervalle.debut.toIso8601String())
        .lte('date_depot', intervalle.fin.toIso8601String())
        .neq('statut', 'annule')
        .order('date_depot', ascending: false);

    final prestations = (data as List)
        .map((e) => Prestation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final ca = prestations.fold<double>(0, (s, p) => s + p.montantTotal);
    final nArticles = prestations.fold<int>(
      0,
      (s, p) => s + p.articles.fold<int>(0, (a, art) => a + art.quantite),
    );

    return DonneesDashboard(
      indicateurs: IndicateursDashboard(
        chiffreAffaires: ca,
        nombrePrestations: prestations.length,
        nombreArticles: nArticles,
        panierMoyen: prestations.isEmpty ? 0 : ca / prestations.length,
      ),
      prestations: prestations,
    );
  }

  StatutPrestation? prochainStatut(StatutPrestation statut) {
    if (statut == StatutPrestation.enAttente ||
        statut == StatutPrestation.enCours) {
      return StatutPrestation.termine;
    }
    if (statut == StatutPrestation.termine) return StatutPrestation.livre;
    return null;
  }

  String libelleStatut(StatutPrestation statut) {
    switch (statut) {
      case StatutPrestation.enAttente:
        return 'En attente';
      case StatutPrestation.enCours:
        return 'En cours';
      case StatutPrestation.termine:
        return 'Prêt';
      case StatutPrestation.livre:
        return 'Livré';
      case StatutPrestation.annule:
        return 'Annulé';
    }
  }

  Future<void> mettreAJourStatut({
    required String prestationId,
    required StatutPrestation nouveauStatut,
  }) async {
    final patch = <String, dynamic>{
      'statut': statutPrestationToDb(nouveauStatut),
    };
    if (nouveauStatut == StatutPrestation.livre) {
      patch['date_livraison'] = DateTime.now().toIso8601String();
    }
    await _client.from('prestations').update(patch).eq('id', prestationId);
  }

  List<String> extraireUrlsPhotos(String? photoUrl) {
    if (photoUrl == null || photoUrl.trim().isEmpty) return [];
    final trim = photoUrl.trim();
    if (trim.startsWith('[')) {
      try {
        final parsed = jsonDecode(trim);
        if (parsed is List) {
          return parsed.whereType<String>().toList();
        }
      } catch (_) {
        return [trim];
      }
    }
    return [trim];
  }
}
