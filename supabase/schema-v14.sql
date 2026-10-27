-- =====================================================================
-- Yiriclick – base v14 : avis clients complets
--   - avis sur la boutique ET avis sur Yiriclick (une fois par commande livrée)
--   - notes par critère, causes d'insatisfaction, demande de rappel, recommandation 0 à 10
--   - mise en avant et masquage avec motif obligatoire (journal des décisions)
--   - analyse automatique de chaque avis : par règles (gratuite) et par IA (facultative)
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v13 (v7 pour les avis, v9 pour les e-mails, v12 pour les tâches planifiées).
-- Peut être relancé sans risque.
-- =====================================================================

-- 1. Avis publics : nouvelles colonnes ----------------------------------------------------
alter table public.avis add column if not exists cible text not null default 'boutique';
alter table public.avis drop constraint if exists avis_cible_check;
alter table public.avis add constraint avis_cible_check check (cible in ('boutique', 'yiriclick'));
alter table public.avis add column if not exists criteres jsonb not null default '{}'::jsonb;
alter table public.avis add column if not exists mis_en_avant boolean not null default false;
alter table public.avis add column if not exists langue text;

-- Un avis boutique + un avis Yiriclick possibles par commande
alter table public.avis drop constraint if exists avis_commande_id_key;
create unique index if not exists avis_commande_cible_uniq on public.avis (commande_id, cible);
create index if not exists avis_cible_idx on public.avis (cible, created_at desc);

-- Le vendeur peut seulement répondre ou signaler ; l'admin passe par les fonctions de modération
create or replace function public.avis_controle()
returns trigger language plpgsql security definer set search_path = public as $$
declare rep text := new.reponse; sig boolean := new.signale; mas boolean := new.masque;
begin
  if current_setting('yc.avis_admin', true) = '1' then return new; end if;
  new := old;
  new.signale := sig;
  if rep is distinct from old.reponse then new.reponse := nullif(trim(coalesce(rep, '')), ''); new.reponse_at := now(); end if;
  if public.is_admin() then
    new.masque := mas;
    if mas then new.mis_en_avant := false; end if;
  end if;
  return new;
end $$;

-- 2. Données privées de chaque avis (lisibles par l'admin seulement) ----------------------
create table if not exists public.avis_prive (
  avis_id          uuid primary key references public.avis (id) on delete cascade,
  causes           text[] not null default '{}',
  recontact        boolean not null default false,
  recommande       smallint check (recommande between 0 and 10),
  sentiment        text,
  cause_principale text,
  urgence          text,
  responsabilite   text,
  drapeaux         text[] not null default '{}',
  analyse_regles   jsonb,
  analyse_at       timestamptz,
  ia_statut        text not null default 'aucune' check (ia_statut in ('aucune', 'en_cours', 'fait', 'erreur')),
  ia_req           bigint,
  ia_demande_at    timestamptz,
  analyse_ia       jsonb,
  ia_at            timestamptz,
  ia_erreur        text,
  statut           text not null default 'a_traiter' check (statut in ('a_traiter', 'en_cours', 'traite')),
  note_admin       text check (char_length(note_admin) <= 2000),
  masque_motif     text,
  masque_at        timestamptz
);
create index if not exists avis_prive_statut_idx on public.avis_prive (statut, urgence);
alter table public.avis_prive enable row level security;
revoke all on table public.avis_prive from anon, authenticated;
grant select on table public.avis_prive to authenticated;
drop policy if exists "Admin lit avis prive" on public.avis_prive;
create policy "Admin lit avis prive" on public.avis_prive for select to authenticated using (public.is_admin());

-- Journal : qui a fait quoi, quand, et pourquoi (exigé pour justifier un masquage)
create table if not exists public.avis_journal (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  avis_id    uuid not null references public.avis (id) on delete cascade,
  admin      uuid default auth.uid(),
  action     text not null,
  motif      text
);
create index if not exists avis_journal_idx on public.avis_journal (avis_id, created_at desc);
alter table public.avis_journal enable row level security;
revoke all on table public.avis_journal from anon, authenticated;
grant select on table public.avis_journal to authenticated;
drop policy if exists "Admin lit journal avis" on public.avis_journal;
create policy "Admin lit journal avis" on public.avis_journal for select to authenticated using (public.is_admin());

-- Réglages (une ligne)
create table if not exists public.reglages_avis (
  id           int primary key default 1 check (id = 1),
  ia_auto      boolean not null default false,
  modele       text not null default 'claude-haiku-5-5',
  alerte_email boolean not null default true
);
insert into public.reglages_avis (id) values (1) on conflict (id) do nothing;
alter table public.reglages_avis enable row level security;
revoke all on table public.reglages_avis from anon, authenticated;
grant select, update on table public.reglages_avis to authenticated;
drop policy if exists "Admin lit reglages avis" on public.reglages_avis;
create policy "Admin lit reglages avis" on public.reglages_avis for select to authenticated using (public.is_admin());
drop policy if exists "Admin modifie reglages avis" on public.reglages_avis;
create policy "Admin modifie reglages avis" on public.reglages_avis for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 3. Libellés ----------------------------------------------------------------------------
create or replace function public.avis_cause_label(c text)
returns text language sql immutable as $$
  select case c
    when 'abime' then 'produit abîmé' when 'non_conforme' then 'produit différent de la description'
    when 'qualite' then 'qualité décevante' when 'taille' then 'problème de taille'
    when 'manquant' then 'article manquant' when 'retard' then 'livraison en retard'
    when 'vendeur_injoignable' then 'vendeur difficile à joindre' when 'vendeur_impoli' then 'vendeur peu aimable'
    when 'prix' then 'prix trop élevé' when 'emballage' then 'emballage insuffisant'
    when 'paiement' then 'problème de paiement ou de remboursement' when 'fraude' then 'soupçon d’arnaque'
    when 'site_difficile' then 'site difficile à utiliser' when 'suivi_commande' then 'suivi de commande insuffisant'
    when 'autre' then 'autre cause' else c end;
$$;
create or replace function public.avis_critere_label(k text)
returns text language sql immutable as $$
  select case k
    when 'produit' then 'conformité du produit' when 'qualite' then 'qualité'
    when 'livraison' then 'délai de livraison' when 'emballage' then 'emballage'
    when 'vendeur' then 'communication du vendeur' when 'prix' then 'rapport qualité-prix'
    when 'facilite' then 'facilité de commande' when 'confiance' then 'confiance' when 'suivi' then 'suivi de commande'
    else k end;
$$;

-- 4. Analyse par règles -------------------------------------------------------------------
-- Lit la note, les critères, les causes cochées et le commentaire (français, anglais, espagnol),
-- puis écrit : sentiment, causes, cause principale, urgence, responsable probable, actions,
-- résumé et réponse proposée. p_premiere = première analyse (alertes et clôture automatique).
create or replace function public.avis_analyser(p_id uuid, p_premiere boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare
  a record; p record; bnom text; lang text := 'fr'; prenom text := ''; txt text;
  det text[] := '{}'; drap text[] := '{}'; tout text[]; pos int; neg int; score int;
  sent text; cp text; urg text; resp text; faibles text[] := '{}'; forts text[] := '{}';
  k text; v int; minv int := 6; mink text; actions jsonb := '[]'::jsonb; resume text; reponse text;
  ordre text[] := array['fraude','abime','manquant','non_conforme','vendeur_injoignable','qualite','retard','taille',
                        'vendeur_impoli','emballage','paiement','site_difficile','suivi_commande','prix','autre'];
  c text; reg record; destinataire text; corps text;
begin
  select * into a from public.avis where id = p_id;
  if not found then return; end if;
  insert into public.avis_prive (avis_id) values (p_id) on conflict (avis_id) do nothing;
  select * into p from public.avis_prive where avis_id = p_id;
  select nom into bnom from public.boutiques where id = a.boutique_id;
  select coalesce(left(langue, 2), 'fr'), split_part(trim(client_nom), ' ', 1) into lang, prenom
    from public.commandes where id = a.commande_id;
  lang := coalesce(a.langue, lang, 'fr'); if lang not in ('fr', 'en', 'es') then lang := 'fr'; end if;
  prenom := coalesce(nullif(prenom, ''), split_part(a.nom, ' ', 1));

  -- texte en minuscules, sans accents
  txt := ' ' || translate(lower(coalesce(a.commentaire, '')), 'àâäáãåéèêëíìîïóòôöõúùûüçñœ', 'aaaaaaeeeeiiiiooooouuuucno') || ' ';

  -- causes détectées dans le commentaire
  if txt ~ '\m(casse|abime|endommag|ecrase|dechir|broken|damaged|cracked|roto|rota|danad)' then det := array_append(det, 'abime'); end if;
  if txt ~ '(pas comme (sur )?(la |les )?photo|different de|differente de|ne correspond pas|pas conforme|not as described|not what i ordered|different from|no corresponde|no es lo que)' then det := array_append(det, 'non_conforme'); end if;
  if txt ~ '(mauvaise qualite|qualite mediocre|bas de gamme|se decoud|decousu|deteint|poor quality|low quality|cheap quality|mala calidad|baja calidad)' then det := array_append(det, 'qualite'); end if;
  if txt ~ '(trop petit|trop grand|mauvaise taille|pas la bonne taille|too small|too big|wrong size|talla)' then det := array_append(det, 'taille'); end if;
  if txt ~ '\m(manquant|il manque|manque un|incomplet|missing|incomplete|faltaba|falta)' then det := array_append(det, 'manquant'); end if;
  if txt ~ '\m(retard|trop long|tres long|attendu|late|delay|took too long|tarde|retraso|demora)' then det := array_append(det, 'retard'); end if;
  if txt ~ '(ne repond|pas de reponse|aucune reponse|injoignable|jamais repondu|no answer|did not answer|didn.t answer|no response|unreachable|no contesta|no responde)' then det := array_append(det, 'vendeur_injoignable'); end if;
  if txt ~ '\m(impoli|malpoli|irrespectueu|agressi|rude|impolite|disrespectful|grosero|maleducado)' then det := array_append(det, 'vendeur_impoli'); end if;
  if txt ~ '(trop cher|prix eleve|hors de prix|expensive|overpriced|demasiado caro|muy caro)' then det := array_append(det, 'prix'); end if;
  if txt ~ '\m(emballage|mal emball|packaging|badly packed|embalaje|empaque)' then det := array_append(det, 'emballage'); end if;
  if txt ~ '\m(paiement|rembours|payment|refund|pago|reembolso)' then det := array_append(det, 'paiement'); end if;
  if txt ~ '\m(arnaque|escroc|voleur|faux produit|contrefa|scam|fraud|fake|estafa|falsificado)' then det := array_append(det, 'fraude'); end if;
  if a.cible = 'yiriclick' and txt ~ '(difficile|complique|bug|ne marche pas|ne fonctionne pas|confusing|hard to|doesn.t work|dificil|no funciona)' then det := array_append(det, 'site_difficile'); end if;

  -- points de vigilance pour la modération (motifs légitimes de masquage)
  if txt ~ '\m(connard|connasse|salop|pute|encule|merde|batard|abruti|fuck|shit|bitch|asshole|bastard|idiota|mierda|puta|cabron|pendejo)' then drap := array_append(drap, 'langage'); end if;
  if txt ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' or txt ~ '\+?\d[\d .-]{7,}\d' or txt ~ '(https?://|www\.)' then drap := array_append(drap, 'donnees_perso'); end if;
  if a.note <= 3 and char_length(trim(coalesce(a.commentaire, ''))) < 15 then drap := array_append(drap, 'sans_detail'); end if;

  -- sentiment : note + mots positifs / négatifs
  select count(*) into pos from regexp_matches(txt, '\m(parfait|excellent|super|genial|top|merci|rapide|ravi|satisfait|recommande|bravo|impeccable|perfect|great|amazing|fast|thank|love|recommend|happy|perfecto|excelente|rapido|gracias|encanta|recomiendo)', 'g');
  select count(*) into neg from regexp_matches(txt, '\m(decu|deception|nul|horrible|mauvais|insatisfait|jamais plus|a eviter|bad|terrible|awful|disappointed|worst|never again|avoid|malo|pesimo|decepcion|nunca mas)', 'g');
  score := (a.note - 3) * 2 + least(pos, 3) - least(neg, 3);
  sent := case when pos > 0 and neg > 0 then 'mixte' when score >= 2 then 'positif' when score <= -2 then 'negatif' else 'neutre' end;

  -- critères : points faibles et points forts
  for k, v in select x.key, (x.value #>> '{}')::int from jsonb_each(a.criteres) x where (x.value #>> '{}') ~ '^[1-5]$' loop
    if v <= 2 then faibles := faibles || (public.avis_critere_label(k) || ' (' || v || '/5)'); end if;
    if v = 5 then forts := forts || (public.avis_critere_label(k) || ' (5/5)'); end if;
    if v < minv then minv := v; mink := k; end if;
  end loop;

  -- causes : cochées par le client + détectées
  select coalesce(array_agg(distinct x), '{}') into tout from unnest(coalesce(p.causes, '{}') || det) x;
  cp := null;
  foreach c in array ordre loop
    if c = any (tout) then cp := c; exit; end if;
  end loop;
  if cp is null and a.note <= 3 and minv <= 3 then
    cp := case mink when 'produit' then 'non_conforme' when 'qualite' then 'qualite' when 'livraison' then 'retard'
      when 'emballage' then 'emballage' when 'vendeur' then 'vendeur_injoignable' when 'prix' then 'prix'
      when 'facilite' then 'site_difficile' when 'suivi' then 'suivi_commande' else null end;
  end if;
  if cp is null and a.note <= 3 then cp := 'autre'; end if;

  -- urgence
  urg := case
    when 'fraude' = any (tout) then 'haute'
    when a.note = 1 then 'haute'
    when a.note <= 2 and (p.recontact or tout && array['abime','manquant','non_conforme','vendeur_injoignable','paiement']) then 'haute'
    when a.note <= 3 or p.recontact or minv <= 2 or 'langage' = any (drap) or 'donnees_perso' = any (drap) then 'moyenne'
    else 'basse' end;

  -- responsable probable
  resp := case
    when a.cible = 'yiriclick' and cp is null then 'yiriclick'
    when cp in ('site_difficile', 'suivi_commande') then 'yiriclick'
    when cp in ('abime', 'emballage', 'retard') then 'vendeur ou transporteur'
    when cp in ('non_conforme', 'qualite', 'taille', 'manquant', 'vendeur_injoignable', 'vendeur_impoli', 'prix', 'fraude') then 'vendeur'
    when cp = 'paiement' then 'à vérifier'
    when cp is null then 'aucun'
    else 'à vérifier' end;

  -- actions recommandées
  if 'fraude' = any (tout) then actions := actions || to_jsonb('Priorité : vérifier la commande et la boutique. Suspendre la boutique si les faits sont confirmés.'::text); end if;
  if 'abime' = any (tout) then actions := actions || to_jsonb('Demander une photo au client et faire proposer un échange ou un remboursement par le vendeur.'::text); end if;
  if 'manquant' = any (tout) then actions := actions || to_jsonb('Vérifier la commande avec le vendeur et faire envoyer l’article manquant.'::text); end if;
  if 'non_conforme' = any (tout) then actions := actions || to_jsonb('Comparer la fiche produit avec l’article reçu ; demander au vendeur de corriger photos et description.'::text); end if;
  if 'qualite' = any (tout) then actions := actions || to_jsonb('Regarder les autres avis sur ce vendeur ; si le problème se répète, en parler avec lui.'::text); end if;
  if 'taille' = any (tout) then actions := actions || to_jsonb('Faire proposer un échange ; demander au vendeur d’ajouter un guide des tailles.'::text); end if;
  if 'retard' = any (tout) then actions := actions || to_jsonb('Demander au vendeur d’afficher un délai de livraison réaliste.'::text); end if;
  if 'vendeur_injoignable' = any (tout) then actions := actions || to_jsonb('Contacter le vendeur ; s’il ne répond pas sous 48 h, lui envoyer un avertissement.'::text); end if;
  if 'vendeur_impoli' = any (tout) then actions := actions || to_jsonb('Rappeler au vendeur les règles de courtoisie et suivre les prochains avis.'::text); end if;
  if 'emballage' = any (tout) then actions := actions || to_jsonb('Conseiller au vendeur un emballage plus solide.'::text); end if;
  if 'paiement' = any (tout) then actions := actions || to_jsonb('Vérifier le paiement ou le remboursement avec le vendeur.'::text); end if;
  if 'prix' = any (tout) then actions := actions || to_jsonb('Information utile pour le vendeur ; pas d’action urgente.'::text); end if;
  if tout && array['site_difficile', 'suivi_commande'] then actions := actions || to_jsonb('Amélioration à prévoir sur Yiriclick : noter la remarque dans la liste des améliorations.'::text); end if;
  if cp = 'autre' then actions := actions || to_jsonb('Lire le commentaire et noter la cause à la main.'::text); end if;
  if p.recontact then actions := actions || to_jsonb('Le client veut être recontacté : lui écrire sur WhatsApp sous 48 h.'::text); end if;
  if 'langage' = any (drap) then actions := actions || to_jsonb('Langage injurieux possible : vérifier, et masquer avec le motif « propos injurieux » si c’est confirmé.'::text); end if;
  if 'donnees_perso' = any (drap) then actions := actions || to_jsonb('Le commentaire contient un numéro, un e-mail ou un lien : masquer avec le motif « données personnelles ».'::text); end if;
  if sent = 'positif' and a.note >= 4 and char_length(coalesce(a.commentaire, '')) >= 60 and cardinality(drap) = 0 then
    actions := actions || to_jsonb('Avis positif et détaillé : vous pouvez le mettre en avant.'::text);
  elsif jsonb_array_length(actions) = 0 then
    actions := actions || to_jsonb('Aucune action nécessaire.'::text);
  end if;

  -- résumé
  resume := 'Note ' || a.note || '/5 pour ' || case when a.cible = 'yiriclick' then 'Yiriclick' else coalesce(bnom, 'la boutique') end || '. ';
  if cardinality(faibles) > 0 then resume := resume || 'Points faibles : ' || array_to_string(faibles, ', ') || '. '; end if;
  if cardinality(forts) > 0 then resume := resume || 'Points forts : ' || array_to_string(forts, ', ') || '. '; end if;
  if cp is not null then resume := resume || 'Cause principale : ' || public.avis_cause_label(cp) || '. '; end if;
  if cardinality(tout) > 1 then resume := resume || coalesce('Autres causes : ' || (select string_agg(public.avis_cause_label(x), ', ') from unnest(tout) x where x is distinct from cp) || '. ', ''); end if;
  if p.recontact then resume := resume || 'Le client souhaite être recontacté. '; end if;
  if p.recommande is not null then resume := resume || 'Recommande Yiriclick : ' || p.recommande || '/10. '; end if;
  if char_length(trim(coalesce(a.commentaire, ''))) = 0 then resume := resume || 'Pas de commentaire écrit.'; end if;
  resume := trim(resume);

  -- réponse proposée (message privé au client, dans sa langue)
  reponse := case lang
    when 'en' then case when sent in ('positif') then 'Thank you ' || prenom || ' for your review! We are glad you are happy with your order and we hope to see you again soon on Yiriclick.'
      when sent = 'neutre' then 'Thank you ' || prenom || ' for your feedback. We take it into account to keep improving Yiriclick.'
      else 'Hello ' || prenom || ', thank you for taking the time to tell us. We are sorry about ' || case when cp is null then 'this experience' else 'this problem' end || '. We have passed your review on to ' || coalesce(bnom, 'the seller') || ' and we will get back to you quickly to find a solution.' end
    when 'es' then case when sent in ('positif') then '¡Gracias ' || prenom || ' por tu opinión! Nos alegra que estés contento con tu pedido y esperamos verte pronto en Yiriclick.'
      when sent = 'neutre' then 'Gracias ' || prenom || ' por tu comentario. Lo tenemos en cuenta para seguir mejorando Yiriclick.'
      else 'Hola ' || prenom || ', gracias por contárnoslo. Lamentamos ' || case when cp is null then 'esta experiencia' else 'este problema' end || '. Hemos transmitido tu opinión a ' || coalesce(bnom, 'el vendedor') || ' y te contactaremos pronto para encontrar una solución.' end
    else case when sent in ('positif') then 'Merci ' || prenom || ' pour ton avis ! Nous sommes ravis que ta commande t’ait plu, et à bientôt sur Yiriclick.'
      when sent = 'neutre' then 'Merci ' || prenom || ' pour ton retour. Nous en tenons compte pour améliorer Yiriclick.'
      else 'Bonjour ' || prenom || ', merci d’avoir pris le temps de nous écrire. Nous sommes désolés pour ce problème' || case when cp is null or cp = 'autre' then '' else ' (' || public.avis_cause_label(cp) || ')' end || '. Nous avons transmis ton avis à ' || coalesce(bnom, 'la boutique') || ' et nous revenons vers toi rapidement pour trouver une solution.' end
  end;

  update public.avis_prive set
    sentiment = sent, cause_principale = cp, urgence = urg, responsabilite = resp, drapeaux = drap,
    analyse_regles = jsonb_build_object('resume', resume, 'sentiment', sent, 'causes', to_jsonb(tout), 'causes_detectees', to_jsonb(det),
      'cause_principale', cp, 'urgence', urg, 'responsabilite', resp, 'points_faibles', to_jsonb(faibles), 'points_forts', to_jsonb(forts),
      'actions', actions, 'reponse_proposee', reponse, 'langue', lang, 'drapeaux', to_jsonb(drap), 'version', 1),
    analyse_at = now(),
    -- 90 % du tri : un avis positif, sans alerte ni rappel, est classé « traité » tout seul
    statut = case when p_premiere and urg = 'basse' and sent = 'positif' and cardinality(drap) = 0 and not p.recontact then 'traite' else statut end
  where avis_id = p_id;

  if p_premiere then
    -- alerte e-mail à l'admin pour les avis urgents (si les e-mails de la base v9 sont configurés)
    begin
      select r.admin_email, r.alertes_admin, coalesce(ra.alerte_email, true) as alerte into reg
        from public.reglages_email r left join public.reglages_avis ra on ra.id = 1 where r.id = 1;
      if urg = 'haute' and reg.alerte and reg.alertes_admin and reg.admin_email is not null then
        corps := '<p style="margin:0 0 12px;font-size:15px">' || public.html_esc(resume) || '</p>'
          || case when a.commentaire is not null then '<p style="margin:0 0 12px;padding:10px;background:#F3F6F7;font-size:14px">« ' || public.html_esc(a.commentaire) || ' »</p>' else '' end;
        perform public.envoyer_email(reg.admin_email, 'Avis urgent ' || a.note || '/5 · ' || coalesce(bnom, 'Yiriclick'),
          public.email_cadre('Un avis demande ton attention', corps,
            (select site_url from public.reglages_email where id = 1) || 'avis-admin.html?id=' || p_id, 'Ouvrir l’analyse'), 'avis_urgent');
      end if;
    exception when others then null;
    end;
    -- analyse IA automatique si elle est activée
    begin
      if (select ia_auto from public.reglages_avis where id = 1) then perform public.avis_ia_demander(p_id); end if;
    exception when others then null;
    end;
  end if;
end $$;
revoke all on function public.avis_analyser(uuid, boolean) from public, anon, authenticated;

-- 5. Dépôt d'un avis complet par le client -------------------------------------------------
-- p_data = { note, commentaire, criteres:{produit,qualite,livraison,emballage,vendeur,prix}, causes:[...], recontact,
--            langue, yc:{ note, commentaire, criteres:{facilite,confiance,suivi}, recommande } }
create or replace function public.laisser_avis_v2(p_commande uuid, p_data jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  c record; n text; note int; crit jsonb; causes text[]; rec boolean; lang text; yc jsonb; ync int; ycrit jsonb; reco int;
  id_b uuid; id_y uuid;
  ok_crit text[] := array['produit','qualite','livraison','emballage','vendeur','prix'];
  ok_ycrit text[] := array['facilite','confiance','suivi'];
  ok_causes text[] := array['abime','non_conforme','qualite','taille','manquant','retard','vendeur_injoignable','vendeur_impoli',
                            'prix','emballage','paiement','site_difficile','suivi_commande','autre'];
begin
  select * into c from public.commandes where id = p_commande;
  if not found then raise exception 'Commande introuvable.'; end if;
  if c.statut <> 'livree' then raise exception 'Tu pourras donner ton avis une fois la commande livrée.'; end if;
  if exists (select 1 from public.avis where commande_id = p_commande and cible = 'boutique') then raise exception 'Tu as déjà donné ton avis pour cette commande.'; end if;
  note := case when (p_data ->> 'note') ~ '^[1-5]$' then (p_data ->> 'note')::int else null end;
  if note is null then raise exception 'Choisis une note de 1 à 5 étoiles.'; end if;

  select coalesce(jsonb_object_agg(x.key, (x.value #>> '{}')::int), '{}'::jsonb) into crit
    from jsonb_each(coalesce(p_data -> 'criteres', '{}'::jsonb)) x where x.key = any (ok_crit) and (x.value #>> '{}') ~ '^[1-5]$';
  select coalesce(array_agg(distinct x), '{}') into causes
    from jsonb_array_elements_text(case when jsonb_typeof(p_data -> 'causes') = 'array' then p_data -> 'causes' else '[]'::jsonb end) x where x = any (ok_causes);
  rec := coalesce((p_data ->> 'recontact')::boolean, false);
  lang := left(coalesce(p_data ->> 'langue', c.langue, 'fr'), 2); if lang not in ('fr', 'en', 'es') then lang := 'fr'; end if;

  -- prénom + initiale du nom, pour la discrétion
  n := split_part(trim(c.client_nom), ' ', 1);
  if split_part(trim(c.client_nom), ' ', 2) <> '' then n := n || ' ' || upper(left(split_part(trim(c.client_nom), ' ', 2), 1)) || '.'; end if;

  insert into public.avis (boutique_id, commande_id, note, commentaire, nom, cible, criteres, langue)
  values (c.boutique_id, c.id, note, nullif(left(trim(coalesce(p_data ->> 'commentaire', '')), 1000), ''), left(n, 40), 'boutique', crit, lang)
  returning id into id_b;
  insert into public.avis_prive (avis_id, causes, recontact) values (id_b, causes, rec);

  -- partie Yiriclick (facultative)
  yc := case when jsonb_typeof(p_data -> 'yc') = 'object' then p_data -> 'yc' else '{}'::jsonb end;
  reco := case when (yc ->> 'recommande') ~ '^([0-9]|10)$' then (yc ->> 'recommande')::int else null end;
  ync := case when (yc ->> 'note') ~ '^[1-5]$' then (yc ->> 'note')::int else null end;
  if ync is not null and not exists (select 1 from public.avis where commande_id = p_commande and cible = 'yiriclick') then
    select coalesce(jsonb_object_agg(x.key, (x.value #>> '{}')::int), '{}'::jsonb) into ycrit
      from jsonb_each(coalesce(yc -> 'criteres', '{}'::jsonb)) x where x.key = any (ok_ycrit) and (x.value #>> '{}') ~ '^[1-5]$';
    insert into public.avis (boutique_id, commande_id, note, commentaire, nom, cible, criteres, langue)
    values (c.boutique_id, c.id, ync, nullif(left(trim(coalesce(yc ->> 'commentaire', '')), 1000), ''), left(n, 40), 'yiriclick', ycrit, lang)
    returning id into id_y;
    insert into public.avis_prive (avis_id, recommande) values (id_y, reco);
  elsif reco is not null then
    update public.avis_prive set recommande = reco where avis_id = id_b;
  end if;

  perform public.avis_analyser(id_b, true);
  if id_y is not null then perform public.avis_analyser(id_y, true); end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.laisser_avis_v2(uuid, jsonb) from public;
grant execute on function public.laisser_avis_v2(uuid, jsonb) to anon, authenticated;

-- L'ancien formulaire (anciennes pages en cache) passe par le nouveau circuit
create or replace function public.laisser_avis(p_commande uuid, p_note integer, p_commentaire text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.laisser_avis_v2(p_commande, jsonb_build_object('note', p_note, 'commentaire', p_commentaire));
end $$;
revoke all on function public.laisser_avis(uuid, integer, text) from public;
grant execute on function public.laisser_avis(uuid, integer, text) to anon, authenticated;

-- « Avis déjà donné » = avis sur la boutique
create or replace function public.suivi_commandes(ids uuid[])
returns table (id uuid, numero text, statut text, updated_at timestamptz, a_avis boolean)
language sql stable security definer set search_path = public as $$
  select c.id, c.numero, c.statut, c.updated_at, exists (select 1 from public.avis v where v.commande_id = c.id and v.cible = 'boutique')
  from public.commandes c where c.id = any (ids[1:20]);
$$;
revoke all on function public.suivi_commandes(uuid[]) from public;
grant execute on function public.suivi_commandes(uuid[]) to anon, authenticated;

-- 6. Analyse par IA (Claude, d'Anthropic) ------------------------------------------------
-- La clé se range dans le coffre de Supabase (Vault) sous le nom anthropic_api_key (voir le guide).
-- Seules la note, les critères, les causes et le commentaire sont envoyés : jamais le nom ni le téléphone.
create or replace function public.avis_ia_demander(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare k text; a record; p record; bnom text; v_modele text; entree jsonb; sys text; rid bigint;
begin
  begin
    select decrypted_secret into k from vault.decrypted_secrets where name = 'anthropic_api_key' limit 1;
  exception when others then k := null;
  end;
  insert into public.avis_prive (avis_id) values (p_id) on conflict (avis_id) do nothing;
  if k is null then
    update public.avis_prive set ia_statut = 'erreur', ia_erreur = 'Clé API manquante : ajoute le secret anthropic_api_key dans Supabase (étape 3 du guide).' where avis_id = p_id;
    return 'cle_manquante';
  end if;
  select * into a from public.avis where id = p_id;
  if not found then return 'introuvable'; end if;
  select * into p from public.avis_prive where avis_id = p_id;
  select nom into bnom from public.boutiques where id = a.boutique_id;
  select coalesce(nullif(trim(r.modele), ''), 'claude-haiku-5-5') into v_modele from public.reglages_avis r where r.id = 1;
  v_modele := coalesce(v_modele, 'claude-haiku-5-5');

  entree := jsonb_build_object(
    'avis_sur', case when a.cible = 'yiriclick' then 'la plateforme Yiriclick' else 'la boutique ' || coalesce(bnom, '') end,
    'note_sur_5', a.note, 'notes_par_critere', a.criteres, 'causes_cochees_par_le_client', to_jsonb(p.causes),
    'veut_etre_recontacte', p.recontact, 'recommande_yiriclick_sur_10', p.recommande,
    'commentaire', coalesce(a.commentaire, ''), 'reponse_publique_du_vendeur', a.reponse, 'langue_du_client', coalesce(a.langue, 'fr'));
  sys := 'Tu es analyste de la satisfaction client pour Yiriclick, une place de marché de petits vendeurs (commandes via WhatsApp). '
    || 'On te donne un avis client en JSON. Réponds UNIQUEMENT avec un objet JSON valide, sans texte autour, avec ces clés : '
    || '"resume" (2 à 3 phrases en français), "sentiment" ("positif","neutre","negatif" ou "mixte"), '
    || '"causes" (liste parmi : abime, non_conforme, qualite, taille, manquant, retard, vendeur_injoignable, vendeur_impoli, prix, emballage, paiement, fraude, site_difficile, suivi_commande, autre), '
    || '"cause_principale" (une de ces valeurs, ou null si le client est satisfait), '
    || '"cause_racine" (1 phrase en français : la raison probable derrière le problème), '
    || '"urgence" ("haute","moyenne" ou "basse"), "responsabilite" ("vendeur","transporteur","yiriclick","client","inconnue" ou "aucune"), '
    || '"actions" (2 à 4 actions concrètes en français pour l’équipe Yiriclick), '
    || '"reponse_proposee" (message privé, court et chaleureux, au client, dans sa langue, sans promettre de remboursement), '
    || '"moderation" (objet {"a_verifier": true/false, "raison": texte ou null} : true seulement si l’avis contient des insultes, des données personnelles, du hors-sujet ou semble faux ; un avis négatif honnête n’est JAMAIS à masquer), '
    || '"confiance" (nombre entre 0 et 1). Ne invente aucun fait absent de l’avis.';

  select net.http_post(
    url := 'https://api.anthropic.com/v1/messages',
    headers := jsonb_build_object('x-api-key', k, 'anthropic-version', '2023-06-01', 'content-type', 'application/json'),
    body := jsonb_build_object('model', v_modele, 'max_tokens', 1200, 'system', sys,
      'messages', jsonb_build_array(jsonb_build_object('role', 'user', 'content', entree::text))),
    timeout_milliseconds := 60000) into rid;
  update public.avis_prive set ia_statut = 'en_cours', ia_req = rid, ia_demande_at = now(), ia_erreur = null where avis_id = p_id;
  return 'en_cours';
end $$;
revoke all on function public.avis_ia_demander(uuid) from public, anon, authenticated;

-- Lit les réponses arrivées (lancé chaque minute, et à l'ouverture de la page admin)
create or replace function public.avis_ia_lire()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; txt text; j jsonb; n int := 0; msg text;
begin
  if auth.uid() is not null and not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  for r in
    select p.avis_id, p.ia_demande_at, resp.status_code, resp.content, resp.error_msg, resp.timed_out
    from public.avis_prive p left join net._http_response resp on resp.id = p.ia_req
    where p.ia_statut = 'en_cours'
  loop
    if r.status_code is null and r.error_msg is null and not coalesce(r.timed_out, false) then
      if r.ia_demande_at < now() - interval '30 minutes' then
        update public.avis_prive set ia_statut = 'erreur', ia_erreur = 'Pas de réponse de l’IA. Relance l’analyse.' where avis_id = r.avis_id;
      end if;
      continue;
    end if;
    j := null;
    if r.status_code = 200 then
      begin
        txt := r.content::jsonb -> 'content' -> 0 ->> 'text';
        begin
          j := txt::jsonb;
        exception when others then
          j := substring(txt from '\{.*\}')::jsonb;
        end;
      exception when others then j := null;
      end;
    end if;
    if j is not null and jsonb_typeof(j) = 'object' then
      update public.avis_prive set ia_statut = 'fait', analyse_ia = j, ia_at = now(), ia_erreur = null where avis_id = r.avis_id;
      n := n + 1;
    else
      begin msg := r.content::jsonb -> 'error' ->> 'message'; exception when others then msg := null; end;
      update public.avis_prive set ia_statut = 'erreur',
        ia_erreur = left(case when r.status_code = 200 then 'Réponse de l’IA illisible. Relance l’analyse.'
          else 'Erreur de l’IA' || coalesce(' (' || r.status_code || ')', '') || ' : ' || coalesce(msg, r.error_msg, 'délai dépassé') end, 300)
      where avis_id = r.avis_id;
    end if;
  end loop;
  return n;
end $$;
revoke all on function public.avis_ia_lire() from public, anon;
grant execute on function public.avis_ia_lire() to authenticated;

-- Lecture automatique chaque minute
do $$ begin perform cron.unschedule('yiriclick-avis-ia'); exception when others then null; end $$;
select cron.schedule('yiriclick-avis-ia', '* * * * *', 'select public.avis_ia_lire()');

-- 7. Fonctions de l'espace admin ----------------------------------------------------------
create or replace function public.avis_moderer(p_id uuid, p_action text, p_motif text default null)
returns void language plpgsql security definer set search_path = public as $$
declare a record;
  motifs text[] := array['injurieux','donnees_perso','hors_sujet','faux','spam','sans_achat','illegal'];
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  select * into a from public.avis where id = p_id;
  if not found then raise exception 'Avis introuvable.'; end if;
  insert into public.avis_prive (avis_id) values (p_id) on conflict (avis_id) do nothing;
  perform set_config('yc.avis_admin', '1', true);
  if p_action = 'masquer' then
    if p_motif is null or not (p_motif = any (motifs)) then
      raise exception 'Choisis un motif de masquage autorisé. Un avis négatif mais honnête doit rester visible.';
    end if;
    update public.avis set masque = true, mis_en_avant = false where id = p_id;
    update public.avis_prive set masque_motif = p_motif, masque_at = now(), statut = 'traite' where avis_id = p_id;
  elsif p_action = 'reafficher' then
    update public.avis set masque = false, signale = false where id = p_id;
    update public.avis_prive set masque_motif = null, masque_at = null where avis_id = p_id;
  elsif p_action = 'mettre_en_avant' then
    if a.masque then raise exception 'Réaffiche l’avis avant de le mettre en avant.'; end if;
    update public.avis set mis_en_avant = true where id = p_id;
  elsif p_action = 'retirer_avant' then
    update public.avis set mis_en_avant = false where id = p_id;
  elsif p_action = 'garder' then
    update public.avis set signale = false where id = p_id;
  elsif p_action in ('a_traiter', 'en_cours', 'traite') then
    update public.avis_prive set statut = p_action where avis_id = p_id;
  else
    raise exception 'Action inconnue.';
  end if;
  insert into public.avis_journal (avis_id, action, motif) values (p_id, p_action, p_motif);
end $$;
revoke all on function public.avis_moderer(uuid, text, text) from public, anon;
grant execute on function public.avis_moderer(uuid, text, text) to authenticated;

create or replace function public.avis_note_admin(p_id uuid, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  insert into public.avis_prive (avis_id) values (p_id) on conflict (avis_id) do nothing;
  update public.avis_prive set note_admin = nullif(left(trim(coalesce(p_note, '')), 2000), '') where avis_id = p_id;
end $$;
revoke all on function public.avis_note_admin(uuid, text) from public, anon;
grant execute on function public.avis_note_admin(uuid, text) to authenticated;

create or replace function public.avis_reanalyser(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  perform public.avis_analyser(p_id, false);
end $$;
revoke all on function public.avis_reanalyser(uuid) from public, anon;
grant execute on function public.avis_reanalyser(uuid) to authenticated;

create or replace function public.avis_ia_lancer(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  return public.avis_ia_demander(p_id);
end $$;
revoke all on function public.avis_ia_lancer(uuid) from public, anon;
grant execute on function public.avis_ia_lancer(uuid) to authenticated;

-- Fiche complète d'un avis : avis, analyse, boutique, commande (avec téléphone du client) et journal
create or replace function public.avis_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  select jsonb_build_object(
    'avis', to_jsonb(a),
    'prive', to_jsonb(p),
    'boutique', jsonb_build_object('nom', b.nom, 'slug', b.slug, 'whatsapp', b.whatsapp),
    'commande', jsonb_build_object('numero', c.numero, 'client_nom', c.client_nom, 'client_tel', c.client_tel, 'articles', c.articles,
                                   'total', c.total, 'devise', c.devise, 'created_at', c.created_at, 'updated_at', c.updated_at),
    'autre', (select to_jsonb(o) from public.avis o where o.commande_id = a.commande_id and o.id <> a.id limit 1),
    'boutique_stats', (select jsonb_build_object('n', count(*), 'moyenne', round(avg(x.note)::numeric, 2), 'negatifs', count(*) filter (where x.note <= 2))
                       from public.avis x where x.boutique_id = a.boutique_id and x.cible = 'boutique'),
    'journal', coalesce((select jsonb_agg(jsonb_build_object('at', j.created_at, 'action', j.action, 'motif', j.motif) order by j.created_at desc)
                         from public.avis_journal j where j.avis_id = a.id), '[]'::jsonb))
  into res
  from public.avis a
  left join public.avis_prive p on p.avis_id = a.id
  left join public.boutiques b on b.id = a.boutique_id
  left join public.commandes c on c.id = a.commande_id
  where a.id = p_id;
  return res;
end $$;
revoke all on function public.avis_detail(uuid) from public, anon;
grant execute on function public.avis_detail(uuid) to authenticated;

-- 8. Analyse des avis déjà existants (sans alerte ni IA) ------------------------------------
do $$ declare r record; begin
  for r in select a.id from public.avis a left join public.avis_prive p on p.avis_id = a.id where p.analyse_regles is null loop
    perform public.avis_analyser(r.id, false);
    update public.avis_prive set statut = 'traite'
      where avis_id = r.id and sentiment = 'positif' and urgence = 'basse' and cardinality(drapeaux) = 0 and not recontact;
  end loop;
end $$;
