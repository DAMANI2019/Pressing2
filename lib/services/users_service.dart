import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class UsersService {
  UsersService(this._client);
  final SupabaseClient _client;

  Future<List<Utilisateur>> listUsers(String pressingId) async {
    final data = await _client
        .from('pressing_utilisateurs')
        .select()
        .eq('pressing_id', pressingId)
        .order('nom_complet');
    return (data as List)
        .map((e) => Utilisateur.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createUserViaSignUp({
    required String pressingId,
    required String email,
    required String password,
    required String nomComplet,
    required RoleUtilisateur role,
  }) async {
    if (role == RoleUtilisateur.superAdmin) {
      throw ArgumentError('Le rôle super administrateur ne peut pas être attribué ici.');
    }
    final sessionPatron = _client.auth.currentSession;
    final refreshToken = sessionPatron?.refreshToken;
    if (refreshToken == null) throw StateError('Session patron expirée. Reconnectez-vous.');
    final response = await _client.auth.signUp(email: email.trim(), password: password);
    final userId = response.user?.id;
    if (userId == null) throw StateError('Création du compte impossible.');
    await _client.auth.setSession(refreshToken);
    await _client.from('pressing_utilisateurs').upsert({
      'id': userId,
      'pressing_id': pressingId,
      'nom_complet': nomComplet.trim(),
      'role': roleToDb(role),
      'actif': true,
    });
  }

  Future<void> deactivateUser(String userId) =>
      _client.from('pressing_utilisateurs').update({'actif': false}).eq('id', userId);

  Future<void> updateRole(String userId, RoleUtilisateur role) {
    if (role == RoleUtilisateur.superAdmin) {
      throw ArgumentError('Rôle non autorisé.');
    }
    return _client
        .from('pressing_utilisateurs')
        .update({'role': roleToDb(role)})
        .eq('id', userId);
  }

  Future<List<Pressing>> listPressingsForChoix() async {
    final data = await _client.from('pressings').select().order('nom');
    return (data as List)
        .map((e) => Pressing.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> rattacherPressing({
    required String userId,
    required String pressingId,
    required String nomComplet,
  }) => _client.from('pressing_utilisateurs').upsert({
        'id': userId,
        'pressing_id': pressingId,
        'nom_complet': nomComplet.trim(),
        'role': 'employe',
        'actif': true,
      });
}
