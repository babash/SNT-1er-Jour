-- SNT 1er jour : fermer la lecture publique des réponses, étape 2 sur 2.
--
-- À appliquer SEULEMENT quand la nouvelle page (celle qui appelle snt_nuage())
-- est en ligne : l'ancienne page ne pourrait plus dessiner le nuage.
-- À coller d'un bloc dans SQL Editor (projet Supabase « SNT-1er Jour »), puis Run.
-- Ce fichier ne touche qu'à la table public.snt_responses.
-- Il peut être relancé sans dommage. Ordre et retour en arrière : LISEZMOI.md.

begin;

-- 1. Plus de lecture publique.
drop policy if exists "Accès lecture public" on public.snt_responses;

-- 2. L'ajout d'une réponse, réservé aux rôles de l'API (anon : la page ;
--    authenticated : une personne connectée), au lieu du rôle public.
drop policy if exists "Accès écriture public" on public.snt_responses;
drop policy if exists "Ajout d'une réponse" on public.snt_responses;
create policy "Ajout d'une réponse"
  on public.snt_responses
  as permissive
  for insert
  to anon, authenticated
  with check (true);

-- 3. Les droits : anon et authenticated gardent seulement INSERT.
--    MAINTAIN existe depuis PostgreSQL 17 (version du projet : 17).
revoke select, update, delete, truncate, references, trigger, maintain
  on table public.snt_responses
  from anon, authenticated;
grant insert on table public.snt_responses to anon, authenticated;

commit;
