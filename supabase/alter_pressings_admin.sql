-- Colonnes optionnelles pour le pilotage Super Admin
ALTER TABLE public.pressings
  ADD COLUMN IF NOT EXISTS gerant_nom TEXT,
  ADD COLUMN IF NOT EXISTS code_pin TEXT;
