class DesignationHabit {
  const DesignationHabit(this.libelle, this.prixDefaut);
  final String libelle;
  final int prixDefaut;
}

const bucketPhotosHabits = 'photos-habits';
const indicatifTelephoneDefaut = '225';
const prixAbonnementMensuelFcfa = 25000;

const designationsHabits = <DesignationHabit>[
  DesignationHabit('Chemise', 1500),
  DesignationHabit('Pantalon', 2000),
  DesignationHabit('Costume', 5000),
  DesignationHabit('Robe', 3000),
  DesignationHabit('Jupe', 2000),
  DesignationHabit('Veste', 2500),
  DesignationHabit('Manteau', 4000),
  DesignationHabit('T-shirt', 1000),
  DesignationHabit('Pull', 2000),
  DesignationHabit('Cravate', 800),
  DesignationHabit('Autre', 1500),
];

const dureesAbonnement = <({int mois, String libelle})>[
  (mois: 1, libelle: '1 mois'),
  (mois: 3, libelle: '3 mois'),
  (mois: 6, libelle: '6 mois'),
  (mois: 12, libelle: '1 an'),
];
