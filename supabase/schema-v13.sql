-- =====================================================================
-- Yiriclick – base v13 : formulaires pré-remplis pour le vendeur connecté
-- Le vendeur ne retape plus ce que Yiriclick sait déjà (nom, téléphone, pays, boutique…)
-- quand il crée sa boutique ou passe de l'essai à une formule payante.
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v12. Peut être relancé sans risque.
-- =====================================================================

-- Renvoie uniquement les informations du vendeur connecté, et seulement si son adresse e-mail
-- est confirmée (personne ne peut lire les données d'une autre adresse).
-- Les fichiers de pièce d'identité, le numéro de la pièce et l'IBAN ne sont jamais renvoyés.
create or replace function public.mon_profil()
returns jsonb language sql stable security definer set search_path = public as $$
  with moi as (
    select lower(u.email) as email from auth.users u
    where u.id = auth.uid() and u.email_confirmed_at is not null
  )
  select case when not exists (select 1 from moi) then null else jsonb_build_object(
    'email', (select email from moi),
    'inscription', (select jsonb_build_object('nom', i.nom, 'boutique', i.boutique, 'pays', i.pays, 'whatsapp', i.whatsapp)
                    from public.inscriptions i, moi where lower(i.email) = moi.email order by i.created_at desc limit 1),
    'boutique', (select jsonb_build_object('nom', b.nom, 'whatsapp', b.whatsapp, 'pays', b.pays, 'ville', b.ville, 'adresse', b.adresse)
                 from public.boutiques b where b.owner = auth.uid() order by b.created_at limit 1),
    'dossier', (select jsonb_build_object(
                  'nom', d.nom, 'whatsapp', d.whatsapp, 'pays', d.pays, 'pays_code', d.pays_code,
                  'statut_juridique', d.statut_juridique, 'nom_legal', d.nom_legal, 'boutique', d.boutique, 'categorie', d.categorie,
                  'produits', d.produits, 'immatriculation', d.immatriculation, 'numero_fiscal', d.numero_fiscal,
                  'adresse', d.adresse, 'ville', d.ville, 'representant', d.representant, 'date_naissance', d.date_naissance,
                  'nationalite', d.nationalite, 'nationalite_code', d.nationalite_code, 'piece_type', d.piece_type,
                  'versement', d.versement, 'operateur', d.operateur, 'numero_mobile', d.numero_mobile, 'titulaire', d.titulaire)
                from public.dossiers d, moi where lower(d.email) = moi.email order by d.created_at desc limit 1)
  ) end;
$$;
revoke all on function public.mon_profil() from public;
grant execute on function public.mon_profil() to authenticated;
