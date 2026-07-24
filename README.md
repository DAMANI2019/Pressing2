# Pressing (Flutter)

Application multi-tenant de gestion de pressing — **Flutter** + **Supabase**.

## Fonctionnalités

- **Employé / utilisateur** : prestations, catalogue, opérations, marquer livré, facture PDF
- **Patron (admin pressing)** : stats période, utilisateurs (admin/utilisateur), catalogue, entête facture, PDF
- **Super Admin** : ajouter / prolonger / suspendre / **supprimer** pressings
- **1ʳᵉ connexion** : choix du pressing si non rattaché
- Facture PDF (aperçu / partage / envoi)
- Garde-fou abonnement + WhatsApp

## Comptes démo

| Rôle | Email | Mot de passe |
|------|-------|--------------|
| Super Admin | `admin@pressing.app` | `PressingAdmin2026!` |
| Patron | `patron@pressing.app` | `PressingPatron2026!` |
| Employé | `employe@pressing.app` | `PressingEmploye2026!` |

## Configuration

1. `.env` : `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TELEPHONE_ADMIN`
2. SQL : `supabase/schema_pressing.sql` puis `supabase/migration_features.sql`
3. Auth Supabase : désactiver la confirmation email pour la création d’utilisateurs par le patron

```bash
flutter pub get
flutter run
```

## Repo

https://github.com/DAMANI2019/Pressing2
