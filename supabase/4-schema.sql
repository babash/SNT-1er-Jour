begin;
-- =============================================================================
--  SNT 1er jour, n° 3 du plan de la base unique, second temps : la table dans son schéma
--  Projet Supabase cukahpyqkljiddmimpyi (« Babash - applications »)
--  Nom de migration : snt_1er_jour_4_schema
-- =============================================================================
--  À appliquer SEULEMENT quand la nouvelle page (celle qui appelle
--  snt_repondre()) est en ligne depuis au moins 10 minutes : l'ancienne page,
--  qui ajoute directement dans la table, ne pourrait plus envoyer de réponse.
--
--  Ce que ce fichier fait, dans une seule transaction :
--   1. il crée le schéma snt_premier_jour, que l'API ne voit pas, sans aucun
--      droit pour anon ni pour authenticated ;
--   2. il ferme l'ajout direct : la règle « Ajout d'une réponse » est
--      supprimée, et anon et authenticated perdent leur droit INSERT. C'était
--      la dernière exception aux règles des bases (P2). service_role perd aussi
--      ses droits sur la table et sa séquence : aucun rôle de l'API n'a de droit
--      dans le schéma, comme pour commun ;
--   3. il DÉPLACE la table public.snt_responses dans ce schéma, sous le nom
--      reponses, avec ses colonnes en français. Les lignes ne sont ni copiées
--      ni lues : la table change seulement de nom et de place, avec ses lignes,
--      son index, sa RLS et ses 9 contraintes de taille, renommées aussi ;
--   4. la fonction de la contrainte de taille, public.snt_taille_max, va dans
--      le schéma sous le nom taille_max, sans aucun droit ;
--   5. il récrit snt_nuage() et snt_repondre() pour la nouvelle table, avec
--      search_path vide et des noms complets. Mêmes noms, mêmes paramètres,
--      mêmes résultats : la page ne voit aucun changement ;
--   6. il commente le schéma, la table et chaque colonne.
--
--  Ce que ce fichier ne change pas : aucune ligne, aucune autre application.
--
--  Il ne peut pas être relancé : une seconde fois, le garde-fou s'arrête et
--  dit que c'est déjà fait. S'il s'arrête en route, rien n'est appliqué.
--  Retour en arrière : 4-schema-inverse.sql.
--  Mode d'emploi : LISEZMOI.md.
-- =============================================================================

-- Garde-fou : le bon rôle, le bon projet, 3 appliqué, la table telle qu'attendue, un schéma libre.
do $$
declare c text;
begin
  if current_user <> 'postgres' then
    raise exception 'À lancer en postgres (éditeur SQL de Supabase ou apply_migration), pas en % : arrêt, rien n''a été modifié.', current_user;
  end if;
  if to_regclass('snt_premier_jour.reponses') is not null and to_regclass('public.snt_responses') is null then
    raise exception '4-schema.sql est déjà appliqué : la table est dans snt_premier_jour.reponses. Rien n''a été modifié.';
  end if;
  if to_regclass('public.snt_responses') is null or to_regclass('public.gb_eleves') is null then
    raise exception 'Ce fichier est pour le projet cukahpyqkljiddmimpyi (public.snt_responses ou public.gb_eleves manque) : arrêt, rien n''a été modifié.';
  end if;
  if to_regprocedure('public.snt_repondre(text, text, text[], integer[], text, text, text, text)') is null then
    raise exception 'Appliquer d''abord 3-fonction-ajout.sql, puis publier la page qui appelle snt_repondre() : arrêt, rien n''a été modifié.';
  end if;
  if to_regprocedure('public.snt_taille_max(text[])') is null then
    raise exception 'public.snt_taille_max(text[]) manque : arrêt, rien n''a été modifié.';
  end if;
  foreach c in array array['id', 'created_at', 'student_name', 'student_class', 'keywords', 'favorite_quotes',
                           'question', 'fav_music', 'fav_book', 'fav_movie'] loop
    if not exists (select 1 from pg_catalog.pg_attribute a
                   where a.attrelid = 'public.snt_responses'::regclass and a.attname = c and not a.attisdropped) then
      raise exception 'La colonne public.snt_responses.% manque : la table n''est pas celle attendue. Arrêt, rien n''a été modifié.', c;
    end if;
  end loop;
  if to_regnamespace('snt_premier_jour') is not null
     and (exists (select 1 from pg_catalog.pg_class where relnamespace = to_regnamespace('snt_premier_jour'))
          or exists (select 1 from pg_catalog.pg_proc where pronamespace = to_regnamespace('snt_premier_jour'))) then
    raise exception 'Le schéma snt_premier_jour existe déjà et n''est pas vide : arrêt, rien n''a été modifié.';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 1. Le schéma
-- -----------------------------------------------------------------------------
create schema if not exists snt_premier_jour authorization postgres;
revoke all on schema snt_premier_jour from public, anon, authenticated;
comment on schema snt_premier_jour is
  'SNT 1er jour : le questionnaire du premier jour de SNT (seconde). Jamais exposé à l''API ; aucun droit pour anon ni pour authenticated. La page passe par public.snt_repondre et public.snt_nuage.';

-- -----------------------------------------------------------------------------
-- 2. L'ajout direct se ferme : plus de règle, plus de droit
-- -----------------------------------------------------------------------------
drop policy if exists "Ajout d'une réponse" on public.snt_responses;
revoke all on table public.snt_responses from anon, authenticated;
-- service_role non plus : aucun rôle de l'API n'a de droit dans le schéma (comme pour commun).
revoke all on table public.snt_responses from service_role;
revoke all on sequence public.snt_responses_id_seq from anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. La fonction de la contrainte de taille : dans le schéma, sans droits
-- -----------------------------------------------------------------------------
alter function public.snt_taille_max(text[]) set schema snt_premier_jour;
alter function snt_premier_jour.snt_taille_max(text[]) rename to taille_max;
alter function snt_premier_jour.taille_max(text[]) set search_path = '';
revoke all on function snt_premier_jour.taille_max(text[]) from public, anon, authenticated, service_role;
comment on function snt_premier_jour.taille_max(text[]) is
  'SNT 1er jour, interne. La longueur du plus long élément d''un tableau de textes (0 s''il est vide) : la contrainte reponses_mots_cles_taille s''en sert. Ne lit aucune table.';

-- -----------------------------------------------------------------------------
-- 4. La table : déplacée et renommée, sans copie
-- -----------------------------------------------------------------------------
alter table public.snt_responses set schema snt_premier_jour;
alter table snt_premier_jour.snt_responses rename to reponses;
alter sequence snt_premier_jour.snt_responses_id_seq rename to reponses_id_seq;

alter table snt_premier_jour.reponses rename column created_at to cree_le;
alter table snt_premier_jour.reponses rename column student_name to prenom_nom;
alter table snt_premier_jour.reponses rename column student_class to classe;
alter table snt_premier_jour.reponses rename column keywords to mots_cles;
alter table snt_premier_jour.reponses rename column favorite_quotes to citations;
alter table snt_premier_jour.reponses rename column fav_music to musique;
alter table snt_premier_jour.reponses rename column fav_book to livre;
alter table snt_premier_jour.reponses rename column fav_movie to film;

alter table snt_premier_jour.reponses rename constraint snt_responses_pkey to reponses_pkey;
alter table snt_premier_jour.reponses rename constraint snt_responses_student_name_taille to reponses_prenom_nom_taille;
alter table snt_premier_jour.reponses rename constraint snt_responses_student_class_taille to reponses_classe_taille;
alter table snt_premier_jour.reponses rename constraint snt_responses_keywords_nombre to reponses_mots_cles_nombre;
alter table snt_premier_jour.reponses rename constraint snt_responses_keywords_taille to reponses_mots_cles_taille;
alter table snt_premier_jour.reponses rename constraint snt_responses_favorite_quotes_nombre to reponses_citations_nombre;
alter table snt_premier_jour.reponses rename constraint snt_responses_question_taille to reponses_question_taille;
alter table snt_premier_jour.reponses rename constraint snt_responses_fav_music_taille to reponses_musique_taille;
alter table snt_premier_jour.reponses rename constraint snt_responses_fav_book_taille to reponses_livre_taille;
alter table snt_premier_jour.reponses rename constraint snt_responses_fav_movie_taille to reponses_film_taille;

alter table snt_premier_jour.reponses enable row level security;
revoke all on table snt_premier_jour.reponses from public, anon, authenticated;

comment on table snt_premier_jour.reponses is
  'SNT 1er jour. Les réponses au questionnaire du premier jour : prénom et nom, classe, mots-clés, citation choisie, question au professeur, goûts (musique, livre, film), date. Lues seulement dans le tableau de bord ; la page n''en voit que le nuage (snt_nuage). Données d''élèves : oui (prénom et nom : exception décidée).';
comment on column snt_premier_jour.reponses.id is 'Le numéro de la réponse (identité).';
comment on column snt_premier_jour.reponses.cree_le is 'La date d''envoi (UTC).';
comment on column snt_premier_jour.reponses.prenom_nom is 'Le prénom et le nom de l''élève, 80 caractères au plus. Donnée d''élève : le nom de famille est une exception décidée pour cette ressource.';
comment on column snt_premier_jour.reponses.classe is 'La classe choisie dans la liste du formulaire, 20 caractères au plus.';
comment on column snt_premier_jour.reponses.mots_cles is 'Les mots-clés de l''élève, pour le nuage de mots : 10 au plus, de 40 caractères au plus chacun.';
comment on column snt_premier_jour.reponses.citations is 'Le numéro de la citation choisie (de 1 à 4) ; 4 au plus dans le tableau.';
comment on column snt_premier_jour.reponses.question is 'La question de l''élève au professeur, 500 caractères au plus.';
comment on column snt_premier_jour.reponses.musique is 'Un lien vers une musique (YouTube), 300 caractères au plus.';
comment on column snt_premier_jour.reponses.livre is 'Un livre ou un manga, 100 caractères au plus.';
comment on column snt_premier_jour.reponses.film is 'Une série ou un film, 100 caractères au plus.';

-- -----------------------------------------------------------------------------
-- 5. Les fonctions d'entrée, récrites pour la nouvelle table
-- -----------------------------------------------------------------------------
-- Le nuage : le même nettoyage que dans 1-nuage.sql (voir ses commentaires),
-- sur la nouvelle table. Mêmes colonnes de résultat : classe, mot, nombre.
create or replace function public.snt_nuage()
returns table (classe text, mot text, nombre bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with blancs as (
    select string_agg(chr(code), '') as liste
    from unnest(array[9, 10, 11, 12, 13, 32, 160, 5760,
                      8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202,
                      8232, 8233, 8239, 8287, 12288, 65279]) as code
  ),
  mots as (
    select r.classe as classe,
           btrim(lower(k.brut), b.liste) as mot
    from snt_premier_jour.reponses as r
    cross join lateral unnest(r.mots_cles) as k(brut)
    cross join blancs as b
  )
  select mots.classe, mots.mot, count(*) as nombre
  from mots
  where mots.mot <> ''
  group by mots.classe, mots.mot
  order by nombre desc, mots.classe, mots.mot;
$$;
comment on function public.snt_nuage() is
  'SNT 1er jour, élève et enseignant·e : le nuage de mots (la page index.html). Renvoie, pour chaque classe, chaque mot-clé et le nombre de fois où il a été donné. Jamais une réponse entière.';

-- L'envoi d'une réponse : le même texte que dans 3-fonction-ajout.sql, sauf la table.
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
  insert into snt_premier_jour.reponses (prenom_nom, classe, mots_cles, citations, question, musique, livre, film)
  values (p_prenom_nom, p_classe, p_mots_cles, p_citations, p_question, p_musique, p_livre, p_film);
  perform commun.noter_echec('snt_premier_jour', 'creation');
  return json_build_object('ok', true);
end $$;

-- -----------------------------------------------------------------------------
-- 6. Contrôle : rien d'ouvert à l'API. Sinon, arrêt : rien n'est appliqué.
-- -----------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.snt_responses') is not null then
    raise exception 'public.snt_responses existe encore : arrêt, rien n''a été modifié.';
  end if;
  if has_schema_privilege('anon', 'snt_premier_jour', 'usage') or has_schema_privilege('authenticated', 'snt_premier_jour', 'usage') then
    raise exception 'Le schéma snt_premier_jour est ouvert à anon ou à authenticated : arrêt, rien n''a été modifié.';
  end if;
  if has_table_privilege('anon', 'snt_premier_jour.reponses', 'select, insert, update, delete, truncate, references, trigger, maintain')
     or has_table_privilege('authenticated', 'snt_premier_jour.reponses', 'select, insert, update, delete, truncate, references, trigger, maintain') then
    raise exception 'La table snt_premier_jour.reponses est ouverte à anon ou à authenticated : arrêt, rien n''a été modifié.';
  end if;
  if exists (select 1 from pg_catalog.pg_policies where schemaname = 'snt_premier_jour')
     or not (select relrowsecurity from pg_catalog.pg_class where oid = 'snt_premier_jour.reponses'::regclass) then
    raise exception 'La table snt_premier_jour.reponses a une règle d''accès, ou n''a pas la RLS : arrêt, rien n''a été modifié.';
  end if;
  if has_function_privilege('anon', 'snt_premier_jour.taille_max(text[])', 'execute')
     or has_function_privilege('authenticated', 'snt_premier_jour.taille_max(text[])', 'execute') then
    raise exception 'snt_premier_jour.taille_max est appelable par anon ou authenticated : arrêt, rien n''a été modifié.';
  end if;
  if not has_function_privilege('anon', 'public.snt_nuage()', 'execute')
     or not has_function_privilege('anon', 'public.snt_repondre(text, text, text[], integer[], text, text, text, text)', 'execute')
     or has_function_privilege('authenticated', 'public.snt_repondre(text, text, text[], integer[], text, text, text, text)', 'execute') then
    raise exception 'snt_nuage ou snt_repondre n''a pas les droits attendus : arrêt, rien n''a été modifié.';
  end if;
end $$;

-- Demande à l'API de recharger sa liste des tables et des fonctions.
notify pgrst, 'reload schema';

commit;
