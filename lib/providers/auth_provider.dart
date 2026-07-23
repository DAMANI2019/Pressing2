import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;

  bool chargement = true;
  Session? session;
  Utilisateur? profil;
  Pressing? pressing;
  bool abonnementActif = false;
  String? raisonBlocage;

  bool get estConnecte => session != null && profil != null;

  Future<void> initialiser() async {
    _client.auth.onAuthStateChange.listen((data) async {
      session = data.session;
      if (session?.user == null) {
        profil = null;
        pressing = null;
        abonnementActif = false;
        raisonBlocage = null;
        chargement = false;
        notifyListeners();
        return;
      }
      await _chargerProfilEtAbonnement(session!.user.id);
    });

    session = _client.auth.currentSession;
    if (session?.user == null) {
      chargement = false;
      notifyListeners();
      return;
    }
    await _chargerProfilEtAbonnement(session!.user.id);
  }

  Future<void> _chargerProfilEtAbonnement(String userId) async {
    chargement = true;
    notifyListeners();

    try {
      final data = await _client
          .from('pressing_utilisateurs')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        profil = null;
        abonnementActif = false;
        raisonBlocage = 'Profil utilisateur introuvable.';
        chargement = false;
        notifyListeners();
        return;
      }

      profil = Utilisateur.fromJson(Map<String, dynamic>.from(data));

      if (profil!.role == RoleUtilisateur.superAdmin) {
        pressing = null;
        abonnementActif = true;
        raisonBlocage = null;
        chargement = false;
        notifyListeners();
        return;
      }

      final pressingId = profil!.pressingId;
      if (pressingId == null) {
        pressing = null;
        abonnementActif = false;
        raisonBlocage = 'Aucun pressing associé à ce compte.';
        chargement = false;
        notifyListeners();
        return;
      }

      final pData = await _client
          .from('pressings')
          .select()
          .eq('id', pressingId)
          .maybeSingle();

      if (pData == null) {
        pressing = null;
        abonnementActif = false;
        raisonBlocage = 'Impossible de vérifier l’abonnement.';
        chargement = false;
        notifyListeners();
        return;
      }

      pressing = Pressing.fromJson(Map<String, dynamic>.from(pData));
      final eval = _evaluerAbonnement(pressing!);
      abonnementActif = eval.$1;
      raisonBlocage = eval.$2;
    } catch (e) {
      raisonBlocage = 'Erreur de chargement : $e';
      abonnementActif = false;
    }

    chargement = false;
    notifyListeners();
  }

  (bool, String?) _evaluerAbonnement(Pressing p) {
    final expiration = DateTime.tryParse('${p.dateExpiration}T23:59:59');
    if (p.statutAbonnement != StatutAbonnement.actif) {
      if (p.statutAbonnement == StatutAbonnement.suspendu) {
        return (
          false,
          'Votre abonnement est suspendu. Contactez l’administrateur pour le réactiver.'
        );
      }
      return (
        false,
        'Votre abonnement n’est plus actif. Contactez l’administrateur pour le renouveler.'
      );
    }
    if (expiration != null && expiration.isBefore(DateTime.now())) {
      return (
        false,
        'La date d’expiration de votre abonnement est dépassée. Renouvelez pour retrouver l’accès.'
      );
    }
    return (true, null);
  }

  Future<String?> seConnecter(String email, String motDePasse) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: motDePasse,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Connexion impossible : $e';
    }
  }

  Future<void> seDeconnecter() async {
    await _client.auth.signOut();
  }

  Future<void> rafraichir() async {
    final id = session?.user.id;
    if (id != null) await _chargerProfilEtAbonnement(id);
  }
}
