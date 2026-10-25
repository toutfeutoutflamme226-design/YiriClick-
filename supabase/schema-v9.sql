-- =====================================================================
-- Yiriclick – base v9 : e-mails automatiques (nouvelle commande, nouvelles inscriptions)
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v8 déjà exécutés. Peut être relancé sans risque.
--
-- Les e-mails partent par Resend (https://resend.com). Tant que la clé n'est pas
-- enregistrée (étape 2 du README), rien n'est envoyé et les commandes marchent normalement.
-- =====================================================================

-- 1. Extension réseau de Supabase (envoie les appels après l'enregistrement, sans ralentir)
create extension if not exists pg_net with schema extensions;

-- 2. Réglages (une seule ligne). Modifiables dans Table Editor > reglages_email.
create table if not exists public.reglages_email (
  id                int primary key default 1 check (id = 1),
  expediteur        text not null default 'Yiriclick <onboarding@resend.dev>',
  admin_email       text,
  site_url          text not null default 'https://toutfeutoutflamme226-design.github.io/YiriClick-/',
  commandes_vendeur boolean not null default true,
  copie_admin       boolean not null default false,
  alertes_admin     boolean not null default true
);
insert into public.reglages_email (id) values (1) on conflict (id) do nothing;
alter table public.reglages_email enable row level security;
revoke all on table public.reglages_email from anon, authenticated;
grant select, update on table public.reglages_email to authenticated;
drop policy if exists "Admin lit reglages email" on public.reglages_email;
create policy "Admin lit reglages email" on public.reglages_email for select to authenticated using (public.is_admin());
drop policy if exists "Admin modifie reglages email" on public.reglages_email;
create policy "Admin modifie reglages email" on public.reglages_email for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Le vendeur peut couper les e-mails de commande (case dans « Ma boutique »)
alter table public.boutiques add column if not exists notif_email boolean not null default true;

-- 3. Journal des envois (pour vérifier que tout part bien)
create table if not exists public.emails_journal (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  type         text not null,
  destinataire text not null,
  sujet        text not null,
  request_id   bigint
);
alter table public.emails_journal enable row level security;
revoke all on table public.emails_journal from anon, authenticated;
grant select on table public.emails_journal to authenticated;
drop policy if exists "Admin lit journal" on public.emails_journal;
create policy "Admin lit journal" on public.emails_journal for select to authenticated using (public.is_admin());

-- 4. Outils
create or replace function public.html_esc(t text)
returns text language sql immutable as $$
  select replace(replace(replace(replace(coalesce(t, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

create or replace function public.prix_txt(v numeric, d text)
returns text language sql immutable as $$
  select case
    when v is null then ''
    when d = 'XOF' then replace(to_char(round(v), 'FM999,999,999,990'), ',', ' ') || ' FCFA'
    when d = 'USD' then '$' || to_char(v, 'FM999,999,990.00')
    else replace(replace(replace(to_char(v, 'FM999,999,990.00'), ',', '#'), '.', ','), '#', ' ') || ' €'
  end;
$$;

-- Mise en page commune : bandeau Yiriclick, contenu, bouton
create or replace function public.email_cadre(titre text, corps text, lien text, bouton text)
returns text language sql immutable as $$
  select '<!doctype html><html><body style="margin:0;background:#F3F6F7;font-family:Arial,Helvetica,sans-serif;color:#10232A">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F3F6F7;padding:20px 0"><tr><td align="center">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#FFFFFF">'
    || '<tr><td style="background:#10232A;padding:16px 22px;font-size:22px;font-weight:bold"><span style="color:#FF7A2E">yiri</span><span style="color:#4FC7CF">click</span></td></tr>'
    || '<tr><td style="padding:24px 22px 8px"><h1 style="margin:0 0 14px;font-size:22px;line-height:1.25">' || public.html_esc(titre) || '</h1>' || corps || '</td></tr>'
    || case when lien is null then '' else
         '<tr><td style="padding:8px 22px 26px"><a href="' || public.html_esc(lien) || '" style="display:inline-block;background:#FF7A2E;color:#10232A;font-weight:bold;text-decoration:none;padding:13px 22px">' || public.html_esc(bouton) || '</a></td></tr>' end
    || '<tr><td style="padding:14px 22px;border-top:1px solid #D5DEE0;font-size:12px;color:#4A5A5F">E-mail automatique de Yiriclick, la place de marché des petits vendeurs.</td></tr>'
    || '</table></td></tr></table></body></html>';
$$;

-- Envoi : ne bloque jamais la commande, même si Resend ne répond pas
create or replace function public.envoyer_email(p_to text, p_sujet text, p_html text, p_type text)
returns void language plpgsql security definer set search_path = public as $$
declare k text; r record; rid bigint;
begin
  if p_to is null or position('@' in p_to) = 0 then return; end if;
  select * into r from public.reglages_email where id = 1;
  begin
    select decrypted_secret into k from vault.decrypted_secrets where name = 'resend_api_key' limit 1;
  exception when others then k := null;
  end;
  if k is null or r is null then return; end if;
  select net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || k, 'Content-Type', 'application/json'),
    body := jsonb_build_object('from', r.expediteur, 'to', jsonb_build_array(p_to), 'subject', left(p_sujet, 200), 'html', p_html),
    timeout_milliseconds := 8000) into rid;
  insert into public.emails_journal (type, destinataire, sujet, request_id) values (p_type, p_to, left(p_sujet, 200), rid);
exception when others then
  raise warning 'Yiriclick : e-mail non envoyé (%): %', p_type, sqlerrm;
end $$;
revoke all on function public.envoyer_email(text, text, text, text) from public, anon, authenticated;

-- 5. Nouvelle commande -> e-mail au vendeur (et copie à l'admin si activée)
create or replace function public.commandes_email()
returns trigger language plpgsql security definer set search_path = public as $$
declare b record; r record; dest text; a jsonb; lignes text := ''; n integer := 0; corps text; lien text; wa text;
begin
  select * into r from public.reglages_email where id = 1;
  if r is null then return new; end if;
  select bo.nom, bo.notif_email, u.email into b from public.boutiques bo join auth.users u on u.id = bo.owner where bo.id = new.boutique_id;
  for a in select * from jsonb_array_elements(new.articles) loop
    n := n + (a ->> 'qty')::integer;
    lignes := lignes || '<tr><td style="padding:6px 0;border-bottom:1px solid #EEF2F3">' || (a ->> 'qty') || ' × ' || public.html_esc(a ->> 'nom')
      || case when jsonb_typeof(a -> 'v') = 'array' then ' <span style="color:#4A5A5F">(' || public.html_esc((select string_agg(x, ' / ') from jsonb_array_elements_text(a -> 'v') x)) || ')</span>' else '' end
      || '</td><td align="right" style="padding:6px 0;border-bottom:1px solid #EEF2F3;white-space:nowrap">' || public.prix_txt((a ->> 'prix')::numeric * (a ->> 'qty')::integer, a ->> 'devise') || '</td></tr>';
  end loop;
  wa := regexp_replace(new.client_tel, '\D', '', 'g');
  lien := r.site_url || 'vendeur.html#orders';
  corps := '<p style="margin:0 0 14px;font-size:15px">Commande <b>' || new.numero || '</b> reçue le ' || to_char(new.created_at at time zone 'Europe/Amsterdam', 'DD/MM/YYYY à HH24:MI') || ' (heure d’Amsterdam).</p>'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-size:15px">' || lignes
    || case when coalesce(new.remise, 0) > 0 then '<tr><td style="padding:6px 0;color:#1E7F4F">Code ' || public.html_esc(new.code_promo) || '</td><td align="right" style="padding:6px 0;color:#1E7F4F">− ' || public.prix_txt(new.remise, new.devise) || '</td></tr>' else '' end
    || case when new.total is not null then '<tr><td style="padding:10px 0;font-weight:bold">Total</td><td align="right" style="padding:10px 0;font-weight:bold">' || public.prix_txt(new.total, new.devise) || '</td></tr>' else '' end
    || '</table>'
    || '<p style="margin:16px 0 4px;font-size:15px"><b>' || public.html_esc(new.client_nom) || '</b><br>' || public.html_esc(new.client_tel) || '<br>' || public.html_esc(new.client_adresse) || '</p>'
    || case when new.client_note is not null then '<p style="margin:10px 0;padding:10px;background:#F3F6F7;font-size:14px">Message du client : ' || public.html_esc(new.client_note) || '</p>' else '' end
    || '<p style="margin:14px 0 0;font-size:14px"><a href="https://wa.me/' || wa || '" style="color:#0E6E78;font-weight:bold">Écrire au client sur WhatsApp</a></p>'
    || '<p style="margin:14px 0 0;font-size:14px;color:#4A5A5F">Confirme la commande dans ton espace vendeur : le stock se met à jour et le client voit le suivi.</p>';
  if r.commandes_vendeur and b.notif_email then
    perform public.envoyer_email(b.email, 'Nouvelle commande ' || new.numero || ' · ' || n || ' article(s)' || case when new.total is not null then ' · ' || public.prix_txt(new.total, new.devise) else '' end,
      public.email_cadre('Nouvelle commande pour ' || b.nom, corps, lien, 'Voir la commande'), 'commande');
  end if;
  if r.copie_admin and r.admin_email is not null then
    perform public.envoyer_email(r.admin_email, '[Admin] Commande ' || new.numero || ' · ' || b.nom, public.email_cadre('Commande chez ' || b.nom, corps, null, null), 'commande_admin');
  end if;
  return new;
exception when others then
  raise warning 'Yiriclick : e-mail de commande non préparé : %', sqlerrm;
  return new;
end $$;
drop trigger if exists commandes_email on public.commandes;
create trigger commandes_email after insert on public.commandes
  for each row execute function public.commandes_email();

-- 6. Nouvelle inscription (essai) ou nouveau dossier -> alerte à l'admin
create or replace function public.inscriptions_email()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; t text; corps text;
begin
  select * into r from public.reglages_email where id = 1;
  if r is null or not r.alertes_admin or r.admin_email is null then return new; end if;
  t := case when tg_table_name = 'dossiers' then 'Nouveau dossier ' || upper(new.formule) else 'Nouvel essai gratuit' end;
  corps := '<p style="margin:0;font-size:15px;line-height:1.6"><b>' || public.html_esc(new.nom) || '</b><br>Boutique : ' || public.html_esc(new.boutique)
    || '<br>Pays : ' || public.html_esc(new.pays) || '<br>E-mail : ' || public.html_esc(new.email) || '<br>WhatsApp : ' || public.html_esc(new.whatsapp) || '</p>';
  perform public.envoyer_email(r.admin_email, '[Yiriclick] ' || t || ' · ' || new.boutique, public.email_cadre(t, corps, r.site_url || 'admin.html', 'Ouvrir l’admin'), 'admin_' || tg_table_name);
  return new;
exception when others then
  raise warning 'Yiriclick : alerte admin non préparée : %', sqlerrm;
  return new;
end $$;
drop trigger if exists inscriptions_email on public.inscriptions;
create trigger inscriptions_email after insert on public.inscriptions for each row execute function public.inscriptions_email();
drop trigger if exists dossiers_email on public.dossiers;
create trigger dossiers_email after insert on public.dossiers for each row execute function public.inscriptions_email();
