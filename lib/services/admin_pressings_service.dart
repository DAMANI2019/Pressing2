import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/format.dart';

class IndicateursAdmin {
  IndicateursAdmin({
    required this.totalPressings,
    required this.actifs,
    required this.expiresOuSuspendus,
    required this.caRecurrentEstime,
  });

  final int totalPressings;
  final int actifs;
  final int expiresOuSuspendus;
  final int caRecurrentEstime;
}

class AdminPressingsService {
  AdminPressingsService(this._client);
  final SupabaseClient _client;

  StatutAbonnement statutAffiche(Pressing pressing) {
    if (pressing.statutAbonnement == StatutAbonnement.suspendu) {
      return StatutAbonnement.suspendu;
    }
    if (pressing.statutAbonnement == StatutAbonnement.expire) {
      return StatutAbonnement.expire;
    }
    if (joursRestants(pressing.dateExpiration) < 0) {
      return StatutAbonnement.expire;
    }
    return StatutAbonnement.actif;
  }

  IndicateursAdmin calculerIndicateurs(List<Pressing> pressings, int prixMensuel) {
    var actifs = 0;
    var expires = 0;
    for (final p in pressings) {
      if (statutAffiche(p) == StatutAbonnement.actif) {
        actifs++;
      } else {
        expires++;
      }
    }
    return IndicateursAdmin(
      totalPressings: pressings.length,
      actifs: actifs,
      expiresOuSuspendus: expires,
      caRecurrentEstime: actifs * prixMensuel,
    );
  }

  Future<List<Pressing>> lister() async {
    final data = await _client
        .from('pressings')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Pressing.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<({Pressing pressing, String codePin})> creer({
    required String nom,
    required String gerantNom,
    required String gerantTelephone,
    required int dureeMois,
    String? codePin,
  }) async {
    final debut = aujourdhuiIsoDate();
    final expiration = ajouterMois(debut, dureeMois);
    final pin = (codePin != null && codePin.trim().isNotEmpty)
        ? codePin.trim()
        : genererCodePin();

    try {
      final data = await _client
          .from('pressings')
          .insert({
            'nom': nom.trim(),
            'telephone': gerantTelephone.trim(),
            'adresse': 'Gérant: ${gerantNom.trim()}',
            'statut_abonnement': 'actif',
            'date_debut_abonnement': debut,
            'date_expiration': expiration,
            'gerant_nom': gerantNom.trim(),
            'code_pin': pin,
          })
          .select()
          .single();
      return (
        pressing: Pressing.fromJson(Map<String, dynamic>.from(data)),
        codePin: pin,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('gerant_nom') || msg.contains('code_pin')) {
        final data = await _client
            .from('pressings')
            .insert({
              'nom': nom.trim(),
              'telephone': gerantTelephone.trim(),
              'adresse': 'Gérant: ${gerantNom.trim()} | PIN: $pin',
              'statut_abonnement': 'actif',
              'date_debut_abonnement': debut,
              'date_expiration': expiration,
            })
            .select()
            .single();
        return (
          pressing: Pressing.fromJson(Map<String, dynamic>.from(data)),
          codePin: pin,
        );
      }
      rethrow;
    }
  }

  Future<Pressing> prolonger({
    required String pressingId,
    required String dateExpirationActuelle,
    required int mois,
  }) async {
    final base = joursRestants(dateExpirationActuelle) >= 0
        ? dateExpirationActuelle
        : aujourdhuiIsoDate();
    final nouvelle = ajouterMois(base, mois);
    final data = await _client
        .from('pressings')
        .update({
          'date_expiration': nouvelle,
          'statut_abonnement': 'actif',
        })
        .eq('id', pressingId)
        .select()
        .single();
    return Pressing.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Pressing> changerStatut({
    required String pressingId,
    required StatutAbonnement statut,
  }) async {
    final data = await _client
        .from('pressings')
        .update({'statut_abonnement': statutAbonnementToDb(statut)})
        .eq('id', pressingId)
        .select()
        .single();
    return Pressing.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> supprimer(String pressingId) =>
      _client.from('pressings').delete().eq('id', pressingId);
}
