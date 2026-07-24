-- RPC : créer son pressing à la 1ʳᵉ connexion (patron)
CREATE OR REPLACE FUNCTION public.pressing_creer_etablissement(
  p_nom TEXT,
  p_nom_complet TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_id UUID;
  v_role public.role_utilisateur_pressing;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  IF trim(p_nom) = '' THEN
    RAISE EXCEPTION 'Le nom du pressing est obligatoire';
  END IF;

  SELECT role INTO v_role FROM public.pressing_utilisateurs WHERE id = v_uid;
  IF FOUND AND v_role = 'super_admin' THEN
    RAISE EXCEPTION 'Un super admin ne crée pas d’établissement ici';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pressing_utilisateurs
    WHERE id = v_uid AND pressing_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Compte déjà rattaché à un pressing';
  END IF;

  INSERT INTO public.pressings (
    nom,
    statut_abonnement,
    date_debut_abonnement,
    date_expiration,
    facture_raison_sociale
  ) VALUES (
    trim(p_nom),
    'actif',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '30 days',
    trim(p_nom)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.pressing_utilisateurs (id, pressing_id, role, nom_complet, actif)
  VALUES (v_uid, v_id, 'patron', COALESCE(NULLIF(trim(p_nom_complet), ''), 'Patron'), true)
  ON CONFLICT (id) DO UPDATE
    SET pressing_id = EXCLUDED.pressing_id,
        role = 'patron',
        nom_complet = EXCLUDED.nom_complet,
        actif = true;

  INSERT INTO public.pressing_catalogue (pressing_id, libelle, categorie, prix_defaut, actif)
  VALUES
    (v_id, 'Lavage à sec', 'lavage_a_sec', 2500, true),
    (v_id, 'Lavage classique', 'lavage', 1500, true),
    (v_id, 'Repassage', 'repassage', 1000, true),
    (v_id, 'Lavage + repassage', 'lavage_repassage', 2000, true),
    (v_id, 'Nettoyage délicat', 'nettoyage', 3000, true),
    (v_id, 'Autre travail', 'autre', 1500, true);

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pressing_creer_etablissement(TEXT, TEXT) TO authenticated;

-- Patron peut renommer son pressing
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
