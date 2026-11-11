begin;
-- =============================================================================
--  SNT 1er jour, n° 3 du plan de la base unique, premier temps : la fonction d'ajout
--  Projet Supabase cukahpyqkljiddmimpyi (« Babash - applications »)
--  Nom de migration : snt_1er_jour_3_fonction_ajout
-- =============================================================================
--  Pourquoi : la page ajoute aujourd'hui ses réponses directement dans la
--  table (l'exception P2 des règles des bases). Pour que la table puisse aller
--  dans son schéma, que l'API ne voit pas (4-schema.sql), la page doit d'abord
--  passer par une fonction.
--
--  Ce que ce fichier crée, et rien d'autre : la fonction d'entrée
--  public.snt_repondre(…), qui ajoute une réponse dans public.snt_responses :
--   - security definer, propriété de postgres, search_path vide ;
--   - appelable par anon seulement ;
--   - les mêmes limites de taille que T36 (1-nuage.sql), vérifiées avant
--     l'ajout : une réponse trop longue reçoit { "ok": false } et un message ;
--   - 150 réponses au plus par heure et par réseau (le compteur commun,
--     commun.essais, type « creation ») : au-delà, { "ok": false } et un message.
--
--  Ce que ce fichier ne change pas : la table, ses lignes, sa règle d'ajout et
--  ses droits, snt_nuage(), la page. L'ancienne page continue d'ajouter ses
--  réponses directement ; la nouvelle page appelle snt_repondre(). Les deux
--  marchent en même temps, et le nuage compte les deux.
--
--  Le fichier peut être relancé sans dommage.
--  Retour en arrière : 3-fonction-ajout-inverse.sql.
--  Mode d'emploi : LISEZMOI.md.
-- =============================================================================

-- Garde-fou : le bon rôle, le bon projet, le socle commun, et 4-schema.sql pas encore appliqué.
do $$
begin
  if current_user <> 'postgres' then
    raise exception 'À lancer en postgres (éditeur SQL de Supabase ou apply_migration), pas en % : arrêt, rien n''a été modifié.', current_user;
  end if;
  if to_regclass('snt_premier_jour.reponses') is not null then
    raise exception '4-schema.sql est déjà appliqué (la table est dans le schéma snt_premier_jour) : ce fichier ne sert plus. Arrêt, rien n''a été modifié.';
  end if;
  if to_regclass('public.snt_responses') is null or to_regclass('public.gb_eleves') is null then
    raise exception 'Ce fichier est pour le projet cukahpyqkljiddmimpyi (public.snt_responses ou public.gb_eleves manque) : arrêt, rien n''a été modifié.';
  end if;
  if to_regprocedure('commun.essai_permis(text, text, integer)') is null or to_regprocedure('commun.noter_echec(text, text)') is null then
    raise exception 'Le socle commun manque (commun.essai_permis, commun.noter_echec) : appliquer d''abord 0003-schema-commun.sql du dépôt du site. Arrêt, rien n''a été modifié.';
  end if;
end $$;

-- La fonction d'entrée de la page : ajouter une réponse.
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

revoke all on function public.snt_repondre(text, text, text[], integer[], text, text, text, text) from public, anon, authenticated;
grant execute on function public.snt_repondre(text, text, text[], integer[], text, text, text, text) to anon;
comment on function public.snt_repondre(text, text, text[], integer[], text, text, text, text) is
  'SNT 1er jour, élève : envoyer sa réponse au questionnaire (la page index.html). Vérifie les limites de taille et le compteur (150 réponses par heure et par réseau). Renvoie { "ok": true }, ou { "ok": false, "champ", "message" }. Ne renvoie jamais une réponse.';

-- Contrôle : la fonction est ouverte à anon, et à lui seul.
do $$
declare f regprocedure := 'public.snt_repondre(text, text, text[], integer[], text, text, text, text)'::regprocedure;
begin
  if not has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute')
     or exists (select 1 from pg_catalog.pg_proc p, aclexplode(p.proacl) a where p.oid = f and a.grantee = 0) then
    raise exception 'Droits inattendus sur public.snt_repondre : arrêt, rien n''a été modifié.';
  end if;
end $$;

-- Demande à l'API de recharger sa liste des fonctions.
notify pgrst, 'reload schema';

commit;
