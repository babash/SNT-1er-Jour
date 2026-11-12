# La base de SNT 1er jour

Les réponses des élèves sont gardées en ligne, dans le projet Supabase partagé `cukahpyqkljiddmimpyi` (« Babash - applications », anciennement « SNT-1er Jour »).
- La page n'en voit que le **nuage des mots-clés**, compté par classe (`snt_nuage()`).
- Toi seul·e lis les réponses complètes, dans le tableau de bord de Supabase.

## Où en est la base (12/11/2026)

- **La lecture publique est fermée depuis le 10/11** (T36) : `1-nuage.sql` puis `2-fermer-lecture.sql`. La table s'appelle encore `public.snt_responses`, et la page y ajoute ses réponses directement : c'est la dernière exception aux règles des bases.
- **Le n° 3 du plan de la base unique** est écrit et essayé en local : `3-fonction-ajout.sql`, puis `4-schema.sql`. Il range la table dans son propre schéma, `snt_premier_jour`, sous le nom `reponses`, et la page passe désormais par une fonction. **Rien n'est encore appliqué.**

## Les fichiers

| Fichier | Nom de migration | Ce qu'il fait | État |
|---|---|---|---|
| `0-table.sql` | — | Crée l'ancienne table, pour une ancienne copie. Remplacé par `schema.sql`. | historique |
| `1-nuage.sql` | `snt_1er_jour_1_nuage` | La fonction du nuage et la taille des champs (T36). | appliqué le 10/11 |
| `2-fermer-lecture.sql` | `snt_1er_jour_2_fermer_lecture` | Plus de lecture publique ; seulement l'ajout (T36). | appliqué le 10/11 |
| `3-fonction-ajout.sql` | `snt_1er_jour_3_fonction_ajout` | Ajoute la fonction d'envoi `snt_repondre()`. | à appliquer |
| `4-schema.sql` | `snt_1er_jour_4_schema` | Range la table dans `snt_premier_jour.reponses` et ferme l'ajout direct. | à appliquer, après la nouvelle page |
| `3-…-inverse.sql`, `4-…-inverse.sql` | `…_inverse` | Le SQL inverse de chacun. | — |
| `schema.sql` | — | Le script complet, pour installer ta copie. | — |

Chaque nouveau fichier commence par `begin;` et finit par `commit;`, chacun sur sa ligne, et commence par un garde-fou : le bon rôle, le bon projet. Il se colle d'un bloc dans **SQL Editor**, puis **Run**. Par `apply_migration`, on retire seulement ces deux lignes.

## Le n° 3 : la table dans son schéma

### En bref, pour l'enseignant

- **`3-fonction-ajout.sql` ajoute une porte d'entrée,** la fonction `snt_repondre()`. Elle enregistre une réponse après avoir vérifié :
  - les mêmes limites de taille qu'aujourd'hui ;
  - qu'il ne part pas plus de 150 réponses en une heure depuis un même réseau, pour éviter qu'un script remplisse la base.

  Elle ne change rien d'autre : l'ancienne page continue de marcher.
- **La nouvelle page** envoie ses réponses par cette fonction. Elle est publiée entre les deux fichiers.
- **`4-schema.sql` range la table à sa place,** dans le schéma `snt_premier_jour`, que l'API ne voit pas :
  - la table devient `reponses`, avec des colonnes en français (`prenom_nom`, `classe`, `mots_cles`…) ;
  - les réponses ne sont ni copiées ni lues : la table change seulement de nom et de place ;
  - l'ajout direct est fermé.

  C'était la dernière exception aux règles des bases.
- **Pour toi :**
  1. tu lis et acceptes le SQL ;
  2. tu acceptes la confirmation de Supabase quand le chef d'orchestre applique ;
  3. tu fais une réponse d'essai après chaque temps ;
  4. ensuite, tu lis les réponses à leur nouvelle place : **Table Editor**, schéma `snt_premier_jour`, table `reponses`.

### L'ordre

1. **`3-fonction-ajout.sql`**, par le chef d'orchestre : `apply_migration`, nom `snt_1er_jour_3_fonction_ajout`.
   - Il faut que le socle commun soit déjà là (`0003-schema-commun.sql` du dépôt du site, appliqué le 11/11).
   - La page actuelle marche encore.
2. **La nouvelle `index.html` en ligne** (voir « La page », plus bas), publiée par le Gardien.
   - Tu fais une réponse d'essai : le message de réussite s'affiche, et ton mot apparaît dans le nuage.
3. **Attendre au moins 10 minutes**, le temps que les navigateurs oublient l'ancienne page (GitHub Pages la garde 10 minutes en cache).
   - Mieux : appliquer la suite un jour sans cours de SNT 1er jour.
4. **`4-schema.sql`** : `apply_migration`, nom `snt_1er_jour_4_schema`.
5. **Vérifier** (ci-dessous). Tu fais une seconde réponse d'essai, puis tu effaces tes deux réponses d'essai.

**Pas d'interruption** :
- pendant la transition, l'ancienne et la nouvelle page marchent toutes les deux, et le nuage compte les deux ;
- après `4-schema.sql`, seule la nouvelle page peut envoyer.

### Ce que fait chaque fichier

**`3-fonction-ajout.sql` crée seulement `public.snt_repondre(p_prenom_nom, p_classe, p_mots_cles, p_citations, p_question, p_musique, p_livre, p_film)`.**
- Elle est `security definer`, appartient à `postgres`, a `search_path` vide, et seul `anon` peut l'appeler.
- **Les limites de T36**, vérifiées avant l'ajout :

  | Champ | Limite |
  |---|---|
  | prénom et nom | 80 caractères, non vide |
  | classe | 20 caractères, non vide |
  | mots-clés | 10 au plus, de 40 caractères chacun |
  | citations | 4 au plus |
  | question | 500 caractères |
  | lien de la musique | 300 caractères |
  | livre et film | 100 caractères chacun |

  Une réponse hors limites reçoit `{ "ok": false, "champ": …, "message": … }`, et rien n'est enregistré.
- **Le compteur :** 150 réponses par heure et par réseau, dans `commun.essais` (type `creation`). Au-delà, `{ "ok": false, "message": … }`. Une réponse refusée pour sa taille ne compte pas.
- **La réponse :** `{ "ok": true }`. La fonction ne renvoie jamais une réponse enregistrée.
- **La table, ses lignes, sa règle et ses droits ne changent pas.** Le fichier peut être relancé.

**`4-schema.sql`, dans une seule transaction :**
1. **Le schéma `snt_premier_jour`**, sans aucun droit pour `anon`, `authenticated` ni `service_role`.
2. **L'ajout direct se ferme :**
   - la règle « Ajout d'une réponse » est supprimée, et `anon` et `authenticated` perdent INSERT ;
   - `service_role` perd aussi ses droits sur la table et sa séquence, comme pour le schéma `commun`.
3. **La contrainte de taille des mots-clés :** `public.snt_taille_max` devient `snt_premier_jour.taille_max`, sans droits. La contrainte la retrouve seule.
4. **La table est déplacée et renommée, sans copie :**

   | Avant (`public.snt_responses`) | Après (`snt_premier_jour.reponses`) |
   |---|---|
   | `created_at` | `cree_le` |
   | `student_name` | `prenom_nom` |
   | `student_class` | `classe` |
   | `keywords` | `mots_cles` |
   | `favorite_quotes` | `citations` |
   | `question` | `question` |
   | `fav_music` | `musique` |
   | `fav_book` | `livre` |
   | `fav_movie` | `film` |

   - Ses lignes, son index, sa RLS et ses 9 contraintes de taille suivent ; les contraintes sont renommées (`reponses_prenom_nom_taille`…).
   - La séquence d'identité devient `snt_premier_jour.reponses_id_seq`.
5. **`snt_nuage()` et `snt_repondre()` sont récrites** pour la nouvelle table, avec `search_path` vide. Elles gardent les mêmes noms, les mêmes paramètres et les mêmes résultats.
6. **Tout est commenté :** le schéma, la table (« Données d'élèves : oui »), chaque colonne et chaque fonction.
7. **Un contrôle à la fin** arrête tout si quelque chose reste ouvert à l'API.

- **S'il s'arrête en route, rien n'est appliqué.** On le relance tel quel.
- **Une seconde fois**, le garde-fou dit que c'est déjà fait, et ne change rien.

### Vérifier (métadonnées seulement)

```sql
-- la table est à sa place (attendu : snt_premier_jour.reponses, puis vide)
select to_regclass('snt_premier_jour.reponses'), to_regclass('public.snt_responses');
-- plus aucune règle ni aucun droit direct (attendu : aucune ligne pour chacune)
select schemaname, tablename, policyname from pg_policies where schemaname in ('public', 'snt_premier_jour');
select table_schema, table_name, grantee, privilege_type from information_schema.role_table_grants
where grantee in ('anon', 'authenticated') and table_schema in ('public', 'snt_premier_jour');
-- le schéma est fermé à anon (attendu : false)
select has_schema_privilege('anon', 'snt_premier_jour', 'usage');
-- les deux fonctions de la page : appelables par anon, pas par authenticated (attendu : true, false deux fois)
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated
from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('snt_nuage', 'snt_repondre');
```

**Après ta réponse d'essai depuis la page (le même jour), l'adresse du réseau est-elle bien lue ?**

C'est le premier essai en ligne du compteur commun :
- dans l'éditeur SQL, sans en-tête, `commun.reseau()` donne l'empreinte d'un réseau « inconnu » ;
- si la ligne de ta réponse portait cette empreinte, c'est que l'API n'a transmis ni `cf-connecting-ip` ni `x-forwarded-for`, et que tous les élèves partageraient le même compteur.

La requête ne lit aucune valeur ; elle compte.

```sql
-- attendu : 0 (l'empreinte vient d'une vraie adresse)
select count(*) from commun.essais where application = 'snt_premier_jour' and reseau = commun.reseau();
-- attendu : au moins 1 (ta réponse d'essai a bien été comptée)
select count(*) from commun.essais where application = 'snt_premier_jour';
```

- **Les conseillers :** « security definer appelable par anon » compte `snt_repondre` en plus (32). C'est voulu : c'est une fonction d'entrée.
- **On ne fait jamais d'essai sur la table en ligne** : seule ta réponse d'essai, depuis la page, sert de vérification.

### Revenir en arrière

- **Défaire `4-schema.sql`** : `4-schema-inverse.sql`.
  - La table revient dans `public` sous son ancien nom et avec ses anciennes colonnes, sans copie.
  - La règle d'ajout et les droits reviennent, `snt_taille_max` aussi, et les fonctions reprennent leur texte d'avant.
  - L'ancienne page peut de nouveau envoyer ; la nouvelle aussi. Les réponses ajoutées entre-temps restent.
- **Défaire `3-fonction-ajout.sql`** : `3-fonction-ajout-inverse.sql`, seulement quand l'ancienne page est de nouveau en ligne (la nouvelle ne pourrait plus envoyer), et seulement après `4-schema-inverse.sql`.
- Les deux inverses ont été essayés : ils rendent exactement l'état d'avant (voir « L'essai local »).

### La page

Le changement de `index.html` (fait par l'Atelier, publié entre `3` et `4`) :
- **L'envoi :** l'ajout direct `db.from('snt_responses').insert([...])` devient un appel de la fonction. La page lit sa réponse :

  ```js
  const { data, error } = await db.rpc('snt_repondre', {
    p_prenom_nom: name,
    p_classe: studentClass,
    p_mots_cles: keywords,
    p_citations: [parseInt(selectedQuote)],
    p_question: teacherQuestion,
    p_musique: favMusic,
    p_livre: favBook,
    p_film: favMovie
  });
  if (error) throw error;
  if (!data || !data.ok) {
    // le message de la base, en rose, à la place de « Erreur d'envoi »
    statusMsg.textContent = "❌ " + ((data && data.message) || "Erreur d'envoi. Préviens le professeur.");
    statusMsg.className = "mt-3 text-sm font-semibold text-rose-400";
    return;
  }
  ```

- **Le commentaire** « Les mêmes limites que la base (supabase/1-nuage.sql) » renvoie à `supabase/3-fonction-ajout.sql`.
- **Le nuage** ne change pas : `db.rpc('snt_nuage')`.

## Lire les réponses

Dans le tableau de bord de Supabase : **Table Editor**, puis :
- après `4-schema.sql` : le schéma `snt_premier_jour`, puis la table `reponses` ;
- avant : le schéma `public`, puis la table `snt_responses`.

Tu vois toutes les colonnes : le tableau de bord n'est pas soumis aux règles d'accès.

Pour préparer le cours suivant, une requête dans **SQL Editor**. Son résultat s'exporte en CSV.

```sql
-- après 4-schema.sql
select classe, prenom_nom, question from snt_premier_jour.reponses order by classe, cree_le;
-- avant 4-schema.sql
select student_class, student_name, question from public.snt_responses order by student_class, created_at;
```

## Effacer les réponses après usage

Moins on garde de données, moins il y a de risques. Une fois les questions traitées :
- dans **Table Editor**, coche les lignes, puis supprime-les ;
- ou dans **SQL Editor** :
  - une classe : `delete from snt_premier_jour.reponses where classe = '209';` ;
  - tout : `delete from snt_premier_jour.reponses;`.

  Avant `4-schema.sql`, c'est `public.snt_responses` et `student_class`.

Le nuage se vide avec les réponses.

## Bon à savoir

- **Les limites de taille** sont les mêmes que les `maxlength` du formulaire (tableau plus haut).
  - Elles sont vérifiées deux fois : par `snt_repondre()`, qui répond par un message, et par les contraintes de la table, qui refusent tout le reste.
  - Les réponses enregistrées avant le 10/11 ne sont pas contrôlées (`NOT VALID`). Mais si tu modifies à la main une ancienne réponse trop longue, la modification est refusée.
- **Le compteur** (150 réponses par heure et par réseau) laisse passer deux ou trois classes de suite dans la même heure, derrière le réseau du lycée, où toutes les classes sortent par la même adresse.
  - Il compte par heure pleine (de 9 h à 10 h, puis de 10 h à 11 h).
  - Au-delà de 150 réponses dans la même heure, la page dit d'attendre un peu. Les compteurs s'effacent seuls après 24 h.
  - Le seuil est haut exprès : une réponse d'élève refusée le premier jour coûte plus cher qu'un peu de réponses indésirables, que tu effaces dans le tableau de bord.
- **La limite de l'API** (1 000 lignes par réponse) vaut aussi pour le nuage : au-delà de 1 000 couples classe et mot, les mots les plus rares ne s'affichent plus.

## Pour une copie de la page

1. **Le projet :** crée un projet Supabase neuf. Dans **SQL Editor** :
   - d'abord le socle commun : `supabase/schema.sql` du dépôt du site [Babash-NSI-SNT](https://github.com/babash/Babash-NSI-SNT) ;
   - puis `supabase/schema.sql` de ce dépôt.
2. **La page :** dans `index.html`, mets l'adresse de ton projet (`SUPABASE_URL`) et sa clé publique (`SUPABASE_ANON_KEY`).
   - C'est la clé « anon » ou « publishable », jamais la clé « service_role » ou « secret ».
   - Mets ensuite tes classes dans les deux listes : le formulaire (`studentClass`) et le filtre du nuage (`filterClass`).

## Historique : la fermeture de la lecture (T36, 10/11)

Avant T36, la page lisait toutes les réponses (`select('*')`) pour dessiner le nuage. Avec la clé publique écrite dans la page, n'importe qui pouvait lire le prénom et le nom de chaque élève, sa question et ses goûts. Deux fichiers ont fermé cette lecture :
1. `1-nuage.sql` : la fonction du nuage et la taille des champs ;
2. la nouvelle page ;
3. `2-fermer-lecture.sql` : plus de lecture publique.

<details>
<summary>Le SQL inverse de T36 (seulement après avoir défait le n° 3, dans l'ordre inverse)</summary>

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

</details>

## L'essai local (11 et 12/11/2026)

- **Sur un PostgreSQL 17.11 local qui reproduit la base en ligne du 11/11 :**
  - structure, fonctions, droits et droits par défaut ;
  - l'empreinte de ses métadonnées est identique à celle relevée en ligne, dans les 10 catégories ;
  - aucune donnée réelle : des réponses inventées.
- **Les essais :**
  - l'aller, comme `apply_migration` et comme l'éditeur SQL ;
  - la transition, avec l'ancienne et la nouvelle page en même temps ;
  - les limites et le compteur ;
  - un arrêt en route de chaque fichier, puis la reprise ;
  - les inverses : retour exact à l'état d'avant, réponses intactes valeur par valeur ;
  - une nouvelle application ;
  - les garde-fous : mauvais ordre, mauvais rôle, mauvais projet, schéma occupé, socle commun absent ;
  - `schema.sql` dans un projet neuf : les mêmes objets.
- **Le résultat :** 174 contrôles, 0 échec.
