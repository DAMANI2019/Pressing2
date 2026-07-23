-- =============================================================================
-- Migration fonctionnalités Pressing
-- Catalogue services, entête facture, invitations, RLS patron
-- =============================================================================

-- Entête / params facture sur pressings
ALTER TABLE public.pressings
  ADD COLUMN IF NOT EXISTS facture_raison_sociale TEXT,
  ADD COLUMN IF NOT EXISTS facture_adresse TEXT,
  ADD COLUMN IF NOT EXISTS facture_telephone TEXT,
  ADD COLUMN IF NOT EXISTS facture_email TEXT,
  ADD COLUMN IF NOT EXISTS facture_pied_page TEXT,
  ADD COLUMN IF NOT EXISTS facture_logo_url TEXT,
  ADD COLUMN IF NOT EXISTS gerant_nom TEXT,
  ADD COLUMN IF NOT EXISTS code_pin TEXT;

-- Catalogue d'articles / prestations (lavage, repassage, etc.)
CREATE TABLE IF NOT EXISTS public.pressing_catalogue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pressing_id UUID NOT NULL REFERENCES public.pressings (id) ON DELETE CASCADE,
  libelle TEXT NOT NULL,
  categorie TEXT NOT NULL DEFAULT 'autre',
  prix_defaut NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (prix_defaut >= 0),
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (pressing_id, libelle)
);

CREATE INDEX IF NOT EXISTS idx_pressing_catalogue_pressing
  ON public.pressing_catalogue (pressing_id);

-- Colonne optionnelle lien catalogue sur articles
ALTER TABLE public.articles_prestation
  ADD COLUMN IF NOT EXISTS catalogue_id UUID REFERENCES public.pressing_catalogue (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS categorie TEXT;

-- Assouplir : profil sans pressing uniquement pour super_admin (déjà en place)
-- Permettre un utilisateur « en attente » : role employe + pressing null temporairement
ALTER TABLE public.pressing_utilisateurs
  DROP CONSTRAINT IF EXISTS pressing_utilisateurs_pressing_selon_role;

ALTER TABLE public.pressing_utilisateurs
  ADD CONSTRAINT pressing_utilisateurs_pressing_selon_role CHECK (
    (role = 'super_admin' AND pressing_id IS NULL)
    OR (role IN ('patron', 'employe'))
  );

-- Invitations / rattachement
CREATE TABLE IF NOT EXISTS public.pressing_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pressing_id UUID NOT NULL REFERENCES public.pressings (id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role public.role_utilisateur_pressing NOT NULL CHECK (role IN ('patron', 'employe')),
  nom_complet TEXT NOT NULL,
  utilisee BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES public.pressing_utilisateurs (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pressing_invitations_email
  ON public.pressing_invitations (lower(email));

ALTER TABLE public.pressing_catalogue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pressing_invitations ENABLE ROW LEVEL SECURITY;

-- Catalogue RLS
DROP POLICY IF EXISTS "Catalogue lecture pressing" ON public.pressing_catalogue;
CREATE POLICY "Catalogue lecture pressing"
  ON public.pressing_catalogue FOR SELECT TO authenticated
  USING (
    public.pressing_est_super_admin()
    OR pressing_id = public.pressing_mon_pressing_id()
  );

DROP POLICY IF EXISTS "Catalogue ecriture patron" ON public.pressing_catalogue;
CREATE POLICY "Catalogue ecriture patron"
  ON public.pressing_catalogue FOR ALL TO authenticated
  USING (
    public.pressing_est_super_admin()
    OR (
      pressing_id = public.pressing_mon_pressing_id()
      AND public.pressing_mon_role() = 'patron'
    )
  )
  WITH CHECK (
    public.pressing_est_super_admin()
    OR (
      pressing_id = public.pressing_mon_pressing_id()
      AND public.pressing_mon_role() = 'patron'
    )
  );

-- Invitations RLS
DROP POLICY IF EXISTS "Invitations patron" ON public.pressing_invitations;
CREATE POLICY "Invitations patron"
  ON public.pressing_invitations FOR ALL TO authenticated
  USING (
    public.pressing_est_super_admin()
    OR (
      pressing_id = public.pressing_mon_pressing_id()
      AND public.pressing_mon_role() = 'patron'
    )
  )
  WITH CHECK (
    public.pressing_est_super_admin()
    OR (
      pressing_id = public.pressing_mon_pressing_id()
      AND public.pressing_mon_role() = 'patron'
    )
  );

-- Patron : insert/update utilisateurs de son pressing
DROP POLICY IF EXISTS "Pressing Patron : gestion utilisateurs" ON public.pressing_utilisateurs;
CREATE POLICY "Pressing Patron : gestion utilisateurs"
  ON public.pressing_utilisateurs
  FOR ALL
  TO authenticated
  USING (
    public.pressing_est_super_admin()
    OR (
      public.pressing_mon_role() = 'patron'
      AND pressing_id = public.pressing_mon_pressing_id()
    )
    OR id = auth.uid()
  )
  WITH CHECK (
    public.pressing_est_super_admin()
    OR (
      public.pressing_mon_role() = 'patron'
      AND pressing_id = public.pressing_mon_pressing_id()
      AND role IN ('patron', 'employe')
    )
    OR id = auth.uid()
  );

-- Lecture pressings actifs (pour choix 1ère connexion)
DROP POLICY IF EXISTS "Pressings lecture authentifiee liste" ON public.pressings;
CREATE POLICY "Pressings lecture authentifiee liste"
  ON public.pressings FOR SELECT TO authenticated
  USING (
    public.pressing_est_super_admin()
    OR id = public.pressing_mon_pressing_id()
    OR statut_abonnement = 'actif'
  );

-- Patron met à jour son pressing (entête facture)
DROP POLICY IF EXISTS "Pressing Patron : update son pressing" ON public.pressings;
CREATE POLICY "Pressing Patron : update son pressing"
  ON public.pressings FOR UPDATE TO authenticated
  USING (
    public.pressing_est_super_admin()
    OR (
      id = public.pressing_mon_pressing_id()
      AND public.pressing_mon_role() = 'patron'
    )
  )
  WITH CHECK (
    public.pressing_est_super_admin()
    OR (
      id = public.pressing_mon_pressing_id()
      AND public.pressing_mon_role() = 'patron'
    )
  );

-- Seed catalogue par défaut pour pressings existants sans catalogue
INSERT INTO public.pressing_catalogue (pressing_id, libelle, categorie, prix_defaut)
SELECT p.id, v.libelle, v.categorie, v.prix
FROM public.pressings p
CROSS JOIN (
  VALUES
    ('Lavage chemise', 'lavage', 1500),
    ('Lavage pantalon', 'lavage', 2000),
    ('Repassage chemise', 'repassage', 1000),
    ('Repassage pantalon', 'repassage', 1500),
    ('Lavage + repassage costume', 'lavage_repassage', 5000),
    ('Nettoyage à sec robe', 'nettoyage', 3500),
    ('Autre', 'autre', 1500)
) AS v(libelle, categorie, prix)
WHERE NOT EXISTS (
  SELECT 1 FROM public.pressing_catalogue c WHERE c.pressing_id = p.id
);
