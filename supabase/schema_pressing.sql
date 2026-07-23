-- =============================================================================
-- Pressing Multi-Tenant — Schéma à appliquer sur la BDD MartistoreProject
-- Projet Supabase : pjtvgsklyzbjypnmasid (partagé avec martistoremarket)
--
-- IMPORTANT — Conflit de nommage :
--   La table public.utilisateurs existe DÉJÀ (Prisma / martistoremarket).
--   Les profils Pressing sont donc dans public.pressing_utilisateurs.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- ENUMS (idempotents)
-- =============================================================================

DO $$ BEGIN
  CREATE TYPE public.role_utilisateur_pressing AS ENUM (
    'super_admin',
    'patron',
    'employe'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.statut_abonnement AS ENUM (
    'actif',
    'suspendu',
    'expire'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.statut_prestation AS ENUM (
    'en_attente',
    'en_cours',
    'termine',
    'livre',
    'annule'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.pressings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  adresse TEXT,
  telephone TEXT,
  email TEXT,
  logo_url TEXT,
  statut_abonnement public.statut_abonnement NOT NULL DEFAULT 'actif',
  date_debut_abonnement DATE NOT NULL DEFAULT CURRENT_DATE,
  date_expiration DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pressings_dates_coherentes
    CHECK (date_expiration >= date_debut_abonnement)
);

-- Profils app Pressing (lié à auth.users) — NE PAS confondre avec public.utilisateurs (Martistore)
CREATE TABLE IF NOT EXISTS public.pressing_utilisateurs (
  id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  pressing_id UUID REFERENCES public.pressings (id) ON DELETE CASCADE,
  role public.role_utilisateur_pressing NOT NULL,
  nom_complet TEXT NOT NULL,
  telephone TEXT,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pressing_utilisateurs_pressing_selon_role CHECK (
    (role = 'super_admin' AND pressing_id IS NULL)
    OR (role IN ('patron', 'employe') AND pressing_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_pressing_utilisateurs_pressing_id
  ON public.pressing_utilisateurs (pressing_id);
CREATE INDEX IF NOT EXISTS idx_pressing_utilisateurs_role
  ON public.pressing_utilisateurs (role);

CREATE TABLE IF NOT EXISTS public.prestations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pressing_id UUID NOT NULL REFERENCES public.pressings (id) ON DELETE CASCADE,
  employe_id UUID NOT NULL REFERENCES public.pressing_utilisateurs (id) ON DELETE RESTRICT,
  client_nom TEXT NOT NULL,
  client_telephone TEXT NOT NULL,
  numero_ticket TEXT NOT NULL,
  statut public.statut_prestation NOT NULL DEFAULT 'en_attente',
  montant_total NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (montant_total >= 0),
  notes TEXT,
  date_depot TIMESTAMPTZ NOT NULL DEFAULT now(),
  date_retrait_prevue DATE,
  date_livraison TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (pressing_id, numero_ticket)
);

CREATE INDEX IF NOT EXISTS idx_prestations_pressing_id
  ON public.prestations (pressing_id);
CREATE INDEX IF NOT EXISTS idx_prestations_employe_id
  ON public.prestations (employe_id);
CREATE INDEX IF NOT EXISTS idx_prestations_date_depot
  ON public.prestations (pressing_id, date_depot DESC);
CREATE INDEX IF NOT EXISTS idx_prestations_client_telephone
  ON public.prestations (pressing_id, client_telephone);

CREATE TABLE IF NOT EXISTS public.articles_prestation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestation_id UUID NOT NULL REFERENCES public.prestations (id) ON DELETE CASCADE,
  pressing_id UUID NOT NULL REFERENCES public.pressings (id) ON DELETE CASCADE,
  type_habit TEXT NOT NULL,
  description TEXT,
  defauts TEXT,
  photo_url TEXT,
  prix_unitaire NUMERIC(12, 2) NOT NULL CHECK (prix_unitaire >= 0),
  quantite INTEGER NOT NULL DEFAULT 1 CHECK (quantite > 0),
  sous_total NUMERIC(12, 2) GENERATED ALWAYS AS (prix_unitaire * quantite) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_articles_prestation_id
  ON public.articles_prestation (prestation_id);
CREATE INDEX IF NOT EXISTS idx_articles_pressing_id
  ON public.articles_prestation (pressing_id);

-- =============================================================================
-- FONCTIONS / TRIGGERS (préfixe pressing_ pour ne pas écraser Martistore)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pressing_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pressings_updated_at ON public.pressings;
CREATE TRIGGER trg_pressings_updated_at
  BEFORE UPDATE ON public.pressings
  FOR EACH ROW EXECUTE FUNCTION public.pressing_set_updated_at();

DROP TRIGGER IF EXISTS trg_pressing_utilisateurs_updated_at ON public.pressing_utilisateurs;
CREATE TRIGGER trg_pressing_utilisateurs_updated_at
  BEFORE UPDATE ON public.pressing_utilisateurs
  FOR EACH ROW EXECUTE FUNCTION public.pressing_set_updated_at();

DROP TRIGGER IF EXISTS trg_prestations_updated_at ON public.prestations;
CREATE TRIGGER trg_prestations_updated_at
  BEFORE UPDATE ON public.prestations
  FOR EACH ROW EXECUTE FUNCTION public.pressing_set_updated_at();

DROP TRIGGER IF EXISTS trg_articles_updated_at ON public.articles_prestation;
CREATE TRIGGER trg_articles_updated_at
  BEFORE UPDATE ON public.articles_prestation
  FOR EACH ROW EXECUTE FUNCTION public.pressing_set_updated_at();

CREATE OR REPLACE FUNCTION public.recalculer_montant_prestation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prestation_id UUID;
BEGIN
  v_prestation_id := COALESCE(NEW.prestation_id, OLD.prestation_id);

  UPDATE public.prestations p
  SET montant_total = COALESCE((
    SELECT SUM(a.prix_unitaire * a.quantite)
    FROM public.articles_prestation a
    WHERE a.prestation_id = v_prestation_id
  ), 0)
  WHERE p.id = v_prestation_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_articles_recalcul_total ON public.articles_prestation;
CREATE TRIGGER trg_articles_recalcul_total
  AFTER INSERT OR UPDATE OR DELETE ON public.articles_prestation
  FOR EACH ROW EXECUTE FUNCTION public.recalculer_montant_prestation();

CREATE OR REPLACE FUNCTION public.pressing_mon_role()
RETURNS public.role_utilisateur_pressing
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.pressing_utilisateurs WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.pressing_mon_pressing_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT pressing_id FROM public.pressing_utilisateurs WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.pressing_est_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.pressing_utilisateurs
    WHERE id = auth.uid() AND role = 'super_admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.pressing_abonnement_valide(p_pressing_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.pressings pr
    WHERE pr.id = p_pressing_id
      AND pr.statut_abonnement = 'actif'
      AND pr.date_expiration >= CURRENT_DATE
  );
$$;

-- =============================================================================
-- RLS
-- =============================================================================

ALTER TABLE public.pressings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pressing_utilisateurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prestations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles_prestation ENABLE ROW LEVEL SECURITY;

-- pressings
DROP POLICY IF EXISTS "Pressing Super Admin : tout sur pressings" ON public.pressings;
CREATE POLICY "Pressing Super Admin : tout sur pressings"
  ON public.pressings
  FOR ALL
  TO authenticated
  USING (public.pressing_est_super_admin())
  WITH CHECK (public.pressing_est_super_admin());

DROP POLICY IF EXISTS "Pressing Membres : lecture de leur pressing" ON public.pressings;
CREATE POLICY "Pressing Membres : lecture de leur pressing"
  ON public.pressings
  FOR SELECT
  TO authenticated
  USING (id = public.pressing_mon_pressing_id());

-- pressing_utilisateurs
DROP POLICY IF EXISTS "Pressing Super Admin : tout sur pressing_utilisateurs" ON public.pressing_utilisateurs;
CREATE POLICY "Pressing Super Admin : tout sur pressing_utilisateurs"
  ON public.pressing_utilisateurs
  FOR ALL
  TO authenticated
  USING (public.pressing_est_super_admin())
  WITH CHECK (public.pressing_est_super_admin());

DROP POLICY IF EXISTS "Pressing Utilisateur : lecture de son profil" ON public.pressing_utilisateurs;
CREATE POLICY "Pressing Utilisateur : lecture de son profil"
  ON public.pressing_utilisateurs
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "Pressing Patron : lecture utilisateurs du pressing" ON public.pressing_utilisateurs;
CREATE POLICY "Pressing Patron : lecture utilisateurs du pressing"
  ON public.pressing_utilisateurs
  FOR SELECT
  TO authenticated
  USING (
    public.pressing_mon_role() = 'patron'
    AND pressing_id = public.pressing_mon_pressing_id()
  );

DROP POLICY IF EXISTS "Pressing Utilisateur : update profil limité" ON public.pressing_utilisateurs;
CREATE POLICY "Pressing Utilisateur : update profil limité"
  ON public.pressing_utilisateurs
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND role = (SELECT u.role FROM public.pressing_utilisateurs u WHERE u.id = auth.uid())
    AND pressing_id IS NOT DISTINCT FROM (
      SELECT u.pressing_id FROM public.pressing_utilisateurs u WHERE u.id = auth.uid()
    )
  );

-- prestations
DROP POLICY IF EXISTS "Pressing Super Admin : lecture prestations" ON public.prestations;
CREATE POLICY "Pressing Super Admin : lecture prestations"
  ON public.prestations
  FOR SELECT
  TO authenticated
  USING (public.pressing_est_super_admin());

DROP POLICY IF EXISTS "Pressing Membres : lecture prestations" ON public.prestations;
CREATE POLICY "Pressing Membres : lecture prestations"
  ON public.prestations
  FOR SELECT
  TO authenticated
  USING (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_abonnement_valide(pressing_id)
  );

DROP POLICY IF EXISTS "Pressing Employé/Patron : insert prestations" ON public.prestations;
CREATE POLICY "Pressing Employé/Patron : insert prestations"
  ON public.prestations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(pressing_id)
    AND employe_id = auth.uid()
  );

DROP POLICY IF EXISTS "Pressing Employé/Patron : update prestations" ON public.prestations;
CREATE POLICY "Pressing Employé/Patron : update prestations"
  ON public.prestations
  FOR UPDATE
  TO authenticated
  USING (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(pressing_id)
  )
  WITH CHECK (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_abonnement_valide(pressing_id)
  );

-- articles_prestation
DROP POLICY IF EXISTS "Pressing Super Admin : lecture articles" ON public.articles_prestation;
CREATE POLICY "Pressing Super Admin : lecture articles"
  ON public.articles_prestation
  FOR SELECT
  TO authenticated
  USING (public.pressing_est_super_admin());

DROP POLICY IF EXISTS "Pressing Membres : lecture articles" ON public.articles_prestation;
CREATE POLICY "Pressing Membres : lecture articles"
  ON public.articles_prestation
  FOR SELECT
  TO authenticated
  USING (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_abonnement_valide(pressing_id)
  );

DROP POLICY IF EXISTS "Pressing Employé/Patron : insert articles" ON public.articles_prestation;
CREATE POLICY "Pressing Employé/Patron : insert articles"
  ON public.articles_prestation
  FOR INSERT
  TO authenticated
  WITH CHECK (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(pressing_id)
  );

DROP POLICY IF EXISTS "Pressing Employé/Patron : update articles" ON public.articles_prestation;
CREATE POLICY "Pressing Employé/Patron : update articles"
  ON public.articles_prestation
  FOR UPDATE
  TO authenticated
  USING (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(pressing_id)
  )
  WITH CHECK (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_abonnement_valide(pressing_id)
  );

DROP POLICY IF EXISTS "Pressing Employé/Patron : delete articles" ON public.articles_prestation;
CREATE POLICY "Pressing Employé/Patron : delete articles"
  ON public.articles_prestation
  FOR DELETE
  TO authenticated
  USING (
    pressing_id = public.pressing_mon_pressing_id()
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(pressing_id)
  );

-- =============================================================================
-- STORAGE : bucket photos-habits
-- =============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'photos-habits',
  'photos-habits',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Lecture publique photos-habits" ON storage.objects;
CREATE POLICY "Lecture publique photos-habits"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'photos-habits');

DROP POLICY IF EXISTS "Upload photos-habits (membres du pressing)" ON storage.objects;
CREATE POLICY "Upload photos-habits (membres du pressing)"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'photos-habits'
    AND (storage.foldername(name))[1] = public.pressing_mon_pressing_id()::text
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(public.pressing_mon_pressing_id())
  );

DROP POLICY IF EXISTS "Update photos-habits (membres du pressing)" ON storage.objects;
CREATE POLICY "Update photos-habits (membres du pressing)"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'photos-habits'
    AND (storage.foldername(name))[1] = public.pressing_mon_pressing_id()::text
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(public.pressing_mon_pressing_id())
  )
  WITH CHECK (
    bucket_id = 'photos-habits'
    AND (storage.foldername(name))[1] = public.pressing_mon_pressing_id()::text
  );

DROP POLICY IF EXISTS "Delete photos-habits (membres du pressing)" ON storage.objects;
CREATE POLICY "Delete photos-habits (membres du pressing)"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'photos-habits'
    AND (storage.foldername(name))[1] = public.pressing_mon_pressing_id()::text
    AND public.pressing_mon_role() IN ('employe', 'patron')
    AND public.pressing_abonnement_valide(public.pressing_mon_pressing_id())
  );

DROP POLICY IF EXISTS "Super Admin : gestion photos-habits" ON storage.objects;
CREATE POLICY "Super Admin : gestion photos-habits"
  ON storage.objects
  FOR ALL
  TO authenticated
  USING (
    bucket_id = 'photos-habits'
    AND public.pressing_est_super_admin()
  )
  WITH CHECK (
    bucket_id = 'photos-habits'
    AND public.pressing_est_super_admin()
  );

-- =============================================================================
-- POST-INSTALLATION
-- =============================================================================
-- 1. Créer un user Auth (Dashboard Supabase).
-- 2. Insérer le Super Admin Pressing :
--    INSERT INTO public.pressing_utilisateurs (id, pressing_id, role, nom_complet)
--    VALUES ('<UUID_AUTH_USER>', NULL, 'super_admin', 'Super Admin');
-- =============================================================================
