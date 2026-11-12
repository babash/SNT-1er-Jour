begin;
-- =============================================================================
--  SQL inverse de 4-schema.sql
--  Projet Supabase cukahpyqkljiddmimpyi (« Babash - applications »)
--  Nom de migration : snt_1er_jour_4_schema_inverse
-- =============================================================================
--  Rend l'état d'après 3-fonction-ajout.sql, sans copier ni lire aucune ligne :
--   - la table revient dans public sous son ancien nom, public.snt_responses,
--     avec ses anciennes colonnes et ses anciens noms de contraintes ;
--   - la règle « Ajout d'une réponse » et le droit INSERT d'anon et
--     d'authenticated reviennent : l'ancienne page peut de nouveau ajouter ;
--   - public.snt_taille_max revient, avec ses droits d'avant ; service_role
--     retrouve aussi les siens sur la table et sa séquence ;
--   - snt_nuage() reprend le texte de 1-nuage.sql, et snt_repondre() celui de
--     3-fonction-ajout.sql ;
--   - le schéma snt_premier_jour, vide, est supprimé.
--  Les réponses ajoutées entre-temps restent dans la table.
--  S'arrête, sans rien modifier, si le schéma contient autre chose.
-- =============================================================================

do $$
begin
  if current_user <> 'postgres' then
    raise exception 'À lancer en postgres (éditeur SQL de Supabase ou apply_migration), pas en % : arrêt, rien n''a été modifié.', current_user;
  end if;
  if to_regclass('snt_premier_jour.reponses') is null or to_regclass('public.snt_responses') is not null then
    raise exception '4-schema.sql n''est pas appliqué (snt_premier_jour.reponses manque, ou public.snt_responses existe) : rien à défaire.';
  end if;
  if to_regclass('public.gb_eleves') is null then
    raise exception 'Ce fichier est pour le projet cukahpyqkljiddmimpyi (public.gb_eleves manque) : arrêt, rien n''a été modifié.';
  end if;
  if exists (select 1 from pg_catalog.pg_class c where c.relnamespace = 'snt_premier_jour'::regnamespace
             and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S') and c.relname not in ('reponses', 'reponses_id_seq'))
     or exists (select 1 from pg_catalog.pg_proc p where p.pronamespace = 'snt_premier_jour'::regnamespace and p.proname <> 'taille_max') then
    raise exception 'Le schéma snt_premier_jour contient d''autres objets que ceux de 4-schema.sql : arrêt, rien n''a été modifié.';
  end if;
end $$;

-- 1. La table revient dans public, sous ses anciens noms.
alter table snt_premier_jour.reponses rename constraint reponses_pkey to snt_responses_pkey;
alter table snt_premier_jour.reponses rename constraint reponses_prenom_nom_taille to snt_responses_student_name_taille;
alter table snt_premier_jour.reponses rename constraint reponses_classe_taille to snt_responses_student_class_taille;
alter table snt_premier_jour.reponses rename constraint reponses_mots_cles_nombre to snt_responses_keywords_nombre;
alter table snt_premier_jour.reponses rename constraint reponses_mots_cles_taille to snt_responses_keywords_taille;
alter table snt_premier_jour.reponses rename constraint reponses_citations_nombre to snt_responses_favorite_quotes_nombre;
alter table snt_premier_jour.reponses rename constraint reponses_question_taille to snt_responses_question_taille;
alter table snt_premier_jour.reponses rename constraint reponses_musique_taille to snt_responses_fav_music_taille;
alter table snt_premier_jour.reponses rename constraint reponses_livre_taille to snt_responses_fav_book_taille;
alter table snt_premier_jour.reponses rename constraint reponses_film_taille to snt_responses_fav_movie_taille;

alter table snt_premier_jour.reponses rename column cree_le to created_at;
alter table snt_premier_jour.reponses rename column prenom_nom to student_name;
alter table snt_premier_jour.reponses rename column classe to student_class;
alter table snt_premier_jour.reponses rename column mots_cles to keywords;
alter table snt_premier_jour.reponses rename column citations to favorite_quotes;
alter table snt_premier_jour.reponses rename column musique to fav_music;
alter table snt_premier_jour.reponses rename column livre to fav_book;
alter table snt_premier_jour.reponses rename column film to fav_movie;

comment on table snt_premier_jour.reponses is null;
comment on column snt_premier_jour.reponses.id is null;
comment on column snt_premier_jour.reponses.created_at is null;
comment on column snt_premier_jour.reponses.student_name is null;
comment on column snt_premier_jour.reponses.student_class is null;
comment on column snt_premier_jour.reponses.keywords is null;
comment on column snt_premier_jour.reponses.favorite_quotes is null;
comment on column snt_premier_jour.reponses.question is null;
comment on column snt_premier_jour.reponses.fav_music is null;
comment on column snt_premier_jour.reponses.fav_book is null;
comment on column snt_premier_jour.reponses.fav_movie is null;

alter sequence snt_premier_jour.reponses_id_seq rename to snt_responses_id_seq;
alter table snt_premier_jour.reponses rename to snt_responses;
alter table snt_premier_jour.snt_responses set schema public;

-- 2. La fonction de la contrainte de taille revient, avec ses droits d'avant.
comment on function snt_premier_jour.taille_max(text[]) is null;
alter function snt_premier_jour.taille_max(text[]) set search_path = public;
alter function snt_premier_jour.taille_max(text[]) rename to snt_taille_max;
alter function snt_premier_jour.snt_taille_max(text[]) set schema public;
grant execute on function public.snt_taille_max(text[]) to public, anon, authenticated, service_role;

-- 3. L'ajout direct revient : la règle et le droit INSERT (état accepté avec T36).
create policy "Ajout d'une réponse"
  on public.snt_responses
  as permissive
  for insert
  to anon, authenticated
  with check (true);
grant insert on table public.snt_responses to anon, authenticated;
grant all on table public.snt_responses to service_role;
grant usage, select, update on sequence public.snt_responses_id_seq to service_role;

-- 4. Les fonctions d'entrée reprennent leur texte d'avant.
create or replace function public.snt_nuage()
returns table (classe text, mot text, nombre bigint)
language sql
stable
security definer
set search_path = public
as $$
  with blancs as (
    select string_agg(chr(code), '') as liste
    from unnest(array[9, 10, 11, 12, 13, 32, 160, 5760,
                      8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202,
                      8232, 8233, 8239, 8287, 12288, 65279]) as code
  ),
  mots as (
    select r.student_class as classe,
           btrim(lower(k.brut), b.liste) as mot
    from public.snt_responses as r
    cross join lateral unnest(r.keywords) as k(brut)
    cross join blancs as b
  )
  select mots.classe, mots.mot, count(*) as nombre
  from mots
  where mots.mot <> ''
  group by mots.classe, mots.mot
  order by nombre desc, mots.classe, mots.mot;
$$;
comment on function public.snt_nuage() is null;

create or replace function public.snt_repondre(
  p_prenom_nom text,
  p_classe     text,
  p_mots_cles  text[]    default null,
  p_citations  integer[] default null,
  p_question   text      default null,
  p_musique    text      default null,
  p_livre      text      default null,
  p_film       text      default null)
returns json
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  -- 1. Le compteur : 150 réponses au plus par heure et par réseau.
  if not commun.essai_permis('snt_premier_jour', 'creation', 150) then
    return json_build_object('ok', false, 'champ', null,
      'message', 'Beaucoup de réponses sont parties de ce réseau en une heure. Réessaie un peu plus tard, ou préviens le professeur.');
  end if;
  -- 2. Les limites de T36 (les mêmes que les maxlength du formulaire).
  if p_prenom_nom is null or btrim(p_prenom_nom) = '' or char_length(p_prenom_nom) > 80 then
    return json_build_object('ok', false, 'champ', 'prenom_nom', 'message', 'Étape 1 : ton prénom et ton nom, 80 caractères au plus.');
  end if;
  if p_classe is null or btrim(p_classe) = '' or char_length(p_classe) > 20 then
    return json_build_object('ok', false, 'champ', 'classe', 'message', 'Étape 1 : choisis ta classe dans la liste.');
  end if;
  if cardinality(p_mots_cles) > 10
     or exists (select 1 from unnest(p_mots_cles) as m where char_length(m) > 40) then
    return json_build_object('ok', false, 'champ', 'mots_cles', 'message', 'Étape 2 : 10 mots au plus, de 40 caractères au plus chacun.');
  end if;
  if cardinality(p_citations) > 4 then
    return json_build_object('ok', false, 'champ', 'citations', 'message', 'Étape 4 : choisis une seule citation.');
  end if;
  if char_length(p_musique) > 300 then
    return json_build_object('ok', false, 'champ', 'musique', 'message', 'Étape 3 : le lien de la musique, 300 caractères au plus.');
  end if;
  if char_length(p_livre) > 100 or char_length(p_film) > 100 then
    return json_build_object('ok', false, 'champ', case when char_length(p_livre) > 100 then 'livre' else 'film' end,
      'message', 'Étape 3 : le livre et le film, 100 caractères au plus chacun.');
  end if;
  if char_length(p_question) > 500 then
    return json_build_object('ok', false, 'champ', 'question', 'message', 'Étape 5 : ta question, 500 caractères au plus.');
  end if;
  -- 3. L'ajout, puis le compteur.
  insert into public.snt_responses (student_name, student_class, keywords, favorite_quotes, question, fav_music, fav_book, fav_movie)
  values (p_prenom_nom, p_classe, p_mots_cles, p_citations, p_question, p_musique, p_livre, p_film);
  perform commun.noter_echec('snt_premier_jour', 'creation');
  return json_build_object('ok', true);
end $$;

-- 5. Le schéma, vide, est supprimé.
drop schema snt_premier_jour;

notify pgrst, 'reload schema';

commit;
