enum RoleUtilisateur { superAdmin, patron, employe }

enum StatutAbonnement { actif, suspendu, expire }

enum StatutPrestation { enAttente, enCours, termine, livre, annule }

RoleUtilisateur roleFromDb(String value) {
  switch (value) {
    case 'super_admin':
      return RoleUtilisateur.superAdmin;
    case 'patron':
      return RoleUtilisateur.patron;
    case 'employe':
      return RoleUtilisateur.employe;
    default:
      return RoleUtilisateur.employe;
  }
}

String roleToDb(RoleUtilisateur role) {
  switch (role) {
    case RoleUtilisateur.superAdmin:
      return 'super_admin';
    case RoleUtilisateur.patron:
      return 'patron';
    case RoleUtilisateur.employe:
      return 'employe';
  }
}

StatutAbonnement statutAbonnementFromDb(String value) {
  switch (value) {
    case 'suspendu':
      return StatutAbonnement.suspendu;
    case 'expire':
      return StatutAbonnement.expire;
    default:
      return StatutAbonnement.actif;
  }
}

String statutAbonnementToDb(StatutAbonnement s) {
  switch (s) {
    case StatutAbonnement.actif:
      return 'actif';
    case StatutAbonnement.suspendu:
      return 'suspendu';
    case StatutAbonnement.expire:
      return 'expire';
  }
}

StatutPrestation statutPrestationFromDb(String value) {
  switch (value) {
    case 'en_attente':
      return StatutPrestation.enAttente;
    case 'termine':
      return StatutPrestation.termine;
    case 'livre':
      return StatutPrestation.livre;
    case 'annule':
      return StatutPrestation.annule;
    default:
      return StatutPrestation.enCours;
  }
}

String statutPrestationToDb(StatutPrestation s) {
  switch (s) {
    case StatutPrestation.enAttente:
      return 'en_attente';
    case StatutPrestation.enCours:
      return 'en_cours';
    case StatutPrestation.termine:
      return 'termine';
    case StatutPrestation.livre:
      return 'livre';
    case StatutPrestation.annule:
      return 'annule';
  }
}

class Pressing {
  Pressing({
    required this.id,
    required this.nom,
    this.adresse,
    this.telephone,
    this.email,
    this.logoUrl,
    this.gerantNom,
    this.codePin,
    required this.statutAbonnement,
    required this.dateDebutAbonnement,
    required this.dateExpiration,
  });

  final String id;
  final String nom;
  final String? adresse;
  final String? telephone;
  final String? email;
  final String? logoUrl;
  final String? gerantNom;
  final String? codePin;
  final StatutAbonnement statutAbonnement;
  final String dateDebutAbonnement;
  final String dateExpiration;

  factory Pressing.fromJson(Map<String, dynamic> json) {
    return Pressing(
      id: json['id'] as String,
      nom: json['nom'] as String,
      adresse: json['adresse'] as String?,
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      logoUrl: json['logo_url'] as String?,
      gerantNom: json['gerant_nom'] as String?,
      codePin: json['code_pin'] as String?,
      statutAbonnement: statutAbonnementFromDb(
        json['statut_abonnement'] as String? ?? 'actif',
      ),
      dateDebutAbonnement: json['date_debut_abonnement'] as String? ?? '',
      dateExpiration: json['date_expiration'] as String? ?? '',
    );
  }
}

class Utilisateur {
  Utilisateur({
    required this.id,
    this.pressingId,
    required this.role,
    required this.nomComplet,
    this.telephone,
    required this.actif,
  });

  final String id;
  final String? pressingId;
  final RoleUtilisateur role;
  final String nomComplet;
  final String? telephone;
  final bool actif;

  String get roleDb => roleToDb(role);

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    return Utilisateur(
      id: json['id'] as String,
      pressingId: json['pressing_id'] as String?,
      role: roleFromDb(json['role'] as String? ?? 'employe'),
      nomComplet: json['nom_complet'] as String? ?? '',
      telephone: json['telephone'] as String?,
      actif: json['actif'] as bool? ?? true,
    );
  }
}

class Prestation {
  Prestation({
    required this.id,
    required this.pressingId,
    required this.employeId,
    required this.clientNom,
    required this.clientTelephone,
    required this.numeroTicket,
    required this.statut,
    required this.montantTotal,
    this.notes,
    required this.dateDepot,
    this.dateRetraitPrevue,
    this.dateLivraison,
    this.articles = const [],
  });

  final String id;
  final String pressingId;
  final String employeId;
  final String clientNom;
  final String clientTelephone;
  final String numeroTicket;
  final StatutPrestation statut;
  final double montantTotal;
  final String? notes;
  final String dateDepot;
  final String? dateRetraitPrevue;
  final String? dateLivraison;
  final List<ArticlePrestation> articles;

  factory Prestation.fromJson(Map<String, dynamic> json) {
    final rawArticles = json['articles_prestation'];
    final articles = rawArticles is List
        ? rawArticles
            .whereType<Map>()
            .map((e) => ArticlePrestation.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ArticlePrestation>[];

    return Prestation(
      id: json['id'] as String,
      pressingId: json['pressing_id'] as String,
      employeId: json['employe_id'] as String,
      clientNom: json['client_nom'] as String? ?? '',
      clientTelephone: json['client_telephone'] as String? ?? '',
      numeroTicket: json['numero_ticket'] as String? ?? '',
      statut: statutPrestationFromDb(json['statut'] as String? ?? 'en_cours'),
      montantTotal: (json['montant_total'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      dateDepot: json['date_depot'] as String? ?? '',
      dateRetraitPrevue: json['date_retrait_prevue'] as String?,
      dateLivraison: json['date_livraison'] as String?,
      articles: articles,
    );
  }
}

class ArticlePrestation {
  ArticlePrestation({
    required this.id,
    required this.prestationId,
    required this.pressingId,
    required this.typeHabit,
    this.description,
    this.defauts,
    this.photoUrl,
    required this.prixUnitaire,
    required this.quantite,
    required this.sousTotal,
  });

  final String id;
  final String prestationId;
  final String pressingId;
  final String typeHabit;
  final String? description;
  final String? defauts;
  final String? photoUrl;
  final double prixUnitaire;
  final int quantite;
  final double sousTotal;

  factory ArticlePrestation.fromJson(Map<String, dynamic> json) {
    return ArticlePrestation(
      id: json['id'] as String,
      prestationId: json['prestation_id'] as String,
      pressingId: json['pressing_id'] as String,
      typeHabit: json['type_habit'] as String? ?? '',
      description: json['description'] as String?,
      defauts: json['defauts'] as String?,
      photoUrl: json['photo_url'] as String?,
      prixUnitaire: (json['prix_unitaire'] as num?)?.toDouble() ?? 0,
      quantite: (json['quantite'] as num?)?.toInt() ?? 1,
      sousTotal: (json['sous_total'] as num?)?.toDouble() ?? 0,
    );
  }
}
