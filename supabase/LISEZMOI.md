# La base de SNT 1er jour : fermer la lecture publique

Avant, la page lisait toutes les réponses (`select('*')`) pour dessiner le nuage : avec la clé publique écrite dans la page, n'importe qui pouvait lire le prénom et le nom de chaque élève, sa question et ses goûts.

Après ces deux fichiers :
- la page appelle la fonction `snt_nuage()`, qui ne renvoie que **les mots-clés comptés par classe** ;
- les élèves peuvent seulement **ajouter** une réponse ;
- toi seul·e lis les réponses complètes, dans le tableau de bord de Supabase.

Les deux fichiers ne touchent qu'à la table `snt_responses` (le projet est partagé avec Alien Python et Gombessa). Chacun se colle d'un bloc dans **SQL Editor**, puis **Run**. Chacun peut être relancé sans dommage. Le troisième, `0-table.sql`, ne sert qu'à une copie (voir la fin).

## L'ordre d'application

1. **`1-nuage.sql`** : la fonction du nuage et la taille des champs. La page actuelle continue de marcher.
2. **La nouvelle `index.html` en ligne** : vérifie que le nuage s'affiche, puis attends 10 minutes, le temps que les navigateurs oublient l'ancienne page (GitHub Pages la garde 10 minutes en cache).
3. **`2-fermer-lecture.sql`** : plus de lecture publique.
4. **Vérifie** :
   - la page dessine toujours le nuage, et une réponse d'essai s'envoie (efface-la ensuite) ;
   - dans la console du navigateur, sur la page : `await db.from('snt_responses').select('*')` renvoie l'erreur `42501` (« permission denied ») ;
   - dans SQL Editor :

     ```sql
     select policyname, cmd, roles from pg_policies where tablename = 'snt_responses';
     select grantee, privilege_type from information_schema.role_table_grants
     where table_name = 'snt_responses' and grantee in ('anon', 'authenticated');
     ```

     attendu : une seule règle, « Ajout d'une réponse », INSERT, `{anon,authenticated}` ; un seul droit par rôle, INSERT.

## Revenir en arrière

Dans l'ordre inverse : d'abord l'étape 2, puis, seulement quand l'ancienne page est revenue en ligne, l'étape 1 (sans elle, la nouvelle page n'a plus de nuage).

```sql
-- Annuler l'étape 2 : rouvrir la lecture publique, comme avant le 08/11.
begin;
drop policy if exists "Ajout d'une réponse" on public.snt_responses;
drop policy if exists "Accès lecture public" on public.snt_responses;
drop policy if exists "Accès écriture public" on public.snt_responses;
create policy "Accès lecture public" on public.snt_responses
  for select to public using (true);
create policy "Accès écriture public" on public.snt_responses
  for insert to public with check (true);
grant select, update, delete, truncate, references, trigger, maintain
  on table public.snt_responses to anon, authenticated;
commit;
```

```sql
-- Annuler l'étape 1 : retirer la fonction du nuage et les contraintes de taille.
begin;
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
drop function if exists public.snt_taille_max(text[]);
drop function if exists public.snt_nuage();
commit;
```

## Lire les réponses

Dans le tableau de bord de Supabase, projet « SNT-1er Jour » : **Table Editor**, puis la table `snt_responses`. Tu vois toutes les colonnes, comme avant : le tableau de bord n'est pas soumis aux règles d'accès.

Pour préparer le cours suivant, une requête dans **SQL Editor** ; son résultat s'exporte en CSV :

```sql
select student_class, student_name, question
from public.snt_responses
order by student_class, created_at;
```

## Effacer les réponses après usage

Moins on garde de données, moins il y a de risques. Une fois les questions traitées :
- dans **Table Editor**, coche les lignes, puis supprime-les ;
- ou dans **SQL Editor**, une classe : `delete from public.snt_responses where student_class = '209';`, ou tout : `delete from public.snt_responses;`.

Le nuage se vide avec les réponses.

## Bon à savoir

- **Les limites de taille**, les mêmes que les `maxlength` du formulaire : prénom et nom, 80 caractères ; classe, 20 ; mots-clés, 10 au plus, de 40 caractères chacun ; citations, 4 au plus ; question, 500 ; lien de la musique, 300 ; livre et film, 100. Les réponses déjà enregistrées ne sont pas contrôlées (`NOT VALID`) ; mais si tu modifies à la main une ancienne réponse trop longue, la modification est refusée.
- **`snt_taille_max(text[])`** sert aux contraintes : elle donne la longueur du plus long mot-clé. Elle ne lit aucune table ; `anon` et `authenticated` doivent pouvoir l'exécuter, sinon plus personne ne peut ajouter de réponse.
- **Les avertissements de Supabase** (Advisors, Security) peuvent signaler que `snt_nuage()` est « security definer » et exécutable par `anon`, ou que la règle d'ajout accepte tout (`with check (true)`). C'est voulu : la fonction ne renvoie que les mots comptés, et chaque élève doit pouvoir répondre sans compte.
- **La limite de l'API** (1 000 lignes par réponse, réglage par défaut) vaut aussi pour le nuage : au-delà de 1 000 couples classe et mot, les mots les plus rares ne s'affichent plus.

## Pour une copie de la page

1. Dans un projet Supabase neuf, dans **SQL Editor** : `0-table.sql`, `1-nuage.sql`, puis `2-fermer-lecture.sql`, à la suite (aucune page ne lit encore la table).
2. Dans `index.html` : l'adresse de ton projet (`SUPABASE_URL`) et sa clé publique (`SUPABASE_ANON_KEY` : la clé « anon » ou « publishable », jamais la clé « service_role » ou « secret ») ; puis tes classes, dans les deux listes : le formulaire (`studentClass`) et le filtre du nuage (`filterClass`).
