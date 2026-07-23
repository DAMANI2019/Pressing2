# Pressing (Flutter)

Application multi-tenant de gestion de pressing — **Flutter** + **Supabase**.

## Fonctionnalités

- **Employé** : création de prestations, photos, envoi facture WhatsApp
- **Patron** : tableau de bord CA / prestations, changement de statut
- **Super Admin** : CRUD pressings, prolonger / suspendre abonnements
- Garde-fou abonnement (`actif` + `date_expiration`)
- Isolation multi-tenant via `pressing_id` + RLS Supabase

## Stack

- Flutter 3.38+ / Dart 3.10+
- `supabase_flutter`, `go_router`, `provider`, `image_picker`, `url_launcher`

## Configuration

1. Copier `.env.example` vers `.env` et renseigner :
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `TELEPHONE_ADMIN` (WhatsApp renouvellement)
2. Appliquer le SQL dans `supabase/schema_pressing.sql` sur votre projet Supabase.
3. Bucket Storage : `photos-habits`

```bash
flutter pub get
flutter run
```

## Rôles (table `pressing_utilisateurs`)

| Rôle          | Accès                          |
|---------------|--------------------------------|
| `super_admin` | Gestion globale des pressings  |
| `patron`      | Stats / CA de son pressing     |
| `employe`     | Réception & WhatsApp           |

## Repo

https://github.com/DAMANI2019/Pressing2
