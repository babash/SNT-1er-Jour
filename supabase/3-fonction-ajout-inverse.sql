begin;
-- =============================================================================
--  SQL inverse de 3-fonction-ajout.sql
--  Projet Supabase cukahpyqkljiddmimpyi (« Babash - applications »)
--  Nom de migration : snt_1er_jour_3_fonction_ajout_inverse
-- =============================================================================
--  Supprime la fonction public.snt_repondre(…). Rien d'autre : la table, ses
--  lignes, sa règle et ses droits ne bougent pas.
--
--  **Seulement quand l'ancienne page est de retour en ligne** : la nouvelle
--  page appelle snt_repondre(), et ne pourrait plus envoyer de réponse.
--  Si 4-schema.sql est appliqué, défaire d'abord 4-schema-inverse.sql.
--  Les compteurs de commun.essais pour SNT 1er jour s'effacent seuls en 24 h.
-- =============================================================================

do $$
begin
  if current_user <> 'postgres' then
    raise exception 'À lancer en postgres (éditeur SQL de Supabase ou apply_migration), pas en % : arrêt, rien n''a été modifié.', current_user;
  end if;
  if to_regclass('snt_premier_jour.reponses') is not null then
    raise exception '4-schema.sql est appliqué : défaire d''abord 4-schema-inverse.sql. Arrêt, rien n''a été modifié.';
  end if;
  if to_regclass('public.snt_responses') is null or to_regclass('public.gb_eleves') is null then
    raise exception 'Ce fichier est pour le projet cukahpyqkljiddmimpyi (public.snt_responses ou public.gb_eleves manque) : arrêt, rien n''a été modifié.';
  end if;
end $$;

drop function if exists public.snt_repondre(text, text, text[], integer[], text, text, text, text);

notify pgrst, 'reload schema';

commit;
