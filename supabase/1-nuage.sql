-- SNT 1er jour : fermer la lecture publique des réponses, étape 1 sur 2.
--
-- Sans effet sur la page actuelle, qui continue de lire la table.
-- À coller d'un bloc dans SQL Editor (projet Supabase « SNT-1er Jour »), puis Run.
-- Le projet est partagé avec Alien Python et Gombessa : ce fichier ne touche
-- qu'à la table public.snt_responses et crée deux fonctions, public.snt_nuage()
-- et public.snt_taille_max(text[]).
-- Il peut être relancé sans dommage. Ordre et retour en arrière : LISEZMOI.md.

begin;

-- 1. Le nuage de mots, et rien d'autre.
-- Pour chaque classe, chaque mot-clé et le nombre de fois où il a été donné.
-- Le nettoyage est celui que faisait la page (word.toLowerCase().trim(),
-- puis les mots vides ignorés) :
--   - lower() suit la casse Unicode, comme toLowerCase() (base en ICU, en-US) ;
--   - btrim() retire les mêmes blancs que trim() en JavaScript, donnés ici par
--     leur code Unicode : tabulation (9), saut de ligne (10), tabulation verticale (11),
--     saut de page (12), retour chariot (13), espace (32), espace insécable (160),
--     espace ogham (5760), espaces typographiques U+2000 à U+200A (8192 à 8202),
--     séparateurs de ligne et de paragraphe (8232, 8233), espace fine insécable (8239),
--     espace moyenne mathématique (8287), espace idéographique (12288),
--     indicateur d'ordre des octets (65279) ;
--   - une réponse sans mots-clés (null) ou un mot-clé null ne compte pas.
-- « security definer » : la fonction lit la table avec les droits de son propriétaire,
-- mais ne renvoie que ces trois colonnes. Les élèves n'ont plus besoin de lire la table.
-- Les mots les plus fréquents d'abord : si l'API coupe la réponse (1 000 lignes par
-- défaut), ce sont les mots les plus rares qui manquent, pas une classe entière.
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

revoke execute on function public.snt_nuage() from public;
grant execute on function public.snt_nuage() to anon, authenticated;

-- 2. La longueur du plus long élément d'un tableau de textes (0 s'il est vide).
-- Une contrainte CHECK ne peut pas parcourir un tableau elle-même : elle appelle
-- cette fonction. Elle est évaluée avec les droits de qui ajoute la réponse :
-- anon et authenticated doivent donc pouvoir l'exécuter. Elle ne lit aucune table.
create or replace function public.snt_taille_max(t text[])
returns integer
language sql
immutable
set search_path = public
as $$
  select coalesce(max(char_length(x)), 0) from unnest(t) as x;
$$;

grant execute on function public.snt_taille_max(text[]) to anon, authenticated;

-- 3. La taille de chaque champ, comme les maxlength du formulaire.
-- NOT VALID : seules les nouvelles réponses sont contrôlées, pas celles déjà enregistrées.
alter table public.snt_responses
  drop constraint if exists snt_responses_student_name_taille,
  drop constraint if exists snt_responses_student_class_taille,
  drop constraint if exists snt_responses_keywords_nombre,
  drop constraint if exists snt_responses_keywords_taille,
  drop constraint if exists snt_responses_favorite_quotes_nombre,
  drop constraint if exists snt_responses_question_taille,
  drop constraint if exists snt_responses_fav_music_taille,
  drop constraint if exists snt_responses_fav_book_taille,
  drop constraint if exists snt_responses_fav_movie_taille;

alter table public.snt_responses
  -- Étape 1 : « Prénom & Nom » (80 caractères) et la classe (la liste du formulaire).
  add constraint snt_responses_student_name_taille
    check (char_length(student_name) <= 80) not valid,
  add constraint snt_responses_student_class_taille
    check (char_length(student_class) <= 20) not valid,
  -- Étape 2 : 10 mots-clés au plus, de 40 caractères au plus chacun.
  add constraint snt_responses_keywords_nombre
    check (cardinality(keywords) <= 10) not valid,
  add constraint snt_responses_keywords_taille
    check (public.snt_taille_max(keywords) <= 40) not valid,
  -- Étape 4 : la citation choisie (une sur quatre ; le tableau en garde 4 au plus).
  add constraint snt_responses_favorite_quotes_nombre
    check (cardinality(favorite_quotes) <= 4) not valid,
  -- Étape 5 : la question au prof (500 caractères).
  add constraint snt_responses_question_taille
    check (char_length(question) <= 500) not valid,
  -- Étape 3 : le lien de la musique (300 caractères), le livre et le film (100).
  add constraint snt_responses_fav_music_taille
    check (char_length(fav_music) <= 300) not valid,
  add constraint snt_responses_fav_book_taille
    check (char_length(fav_book) <= 100) not valid,
  add constraint snt_responses_fav_movie_taille
    check (char_length(fav_movie) <= 100) not valid;

commit;
