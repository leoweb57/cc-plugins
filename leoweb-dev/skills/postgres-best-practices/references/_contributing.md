# Guide de rédaction des références Postgres

Ce document fournit des consignes pour créer des références de bonnes pratiques
Postgres efficaces, qui fonctionnent bien avec les agents IA et les LLM.

## Principes clés

### 1. Des patterns de transformation concrets

Montre les réécritures SQL exactes. Évite les conseils philosophiques.

**Bien :** "Utilise `WHERE id = ANY(ARRAY[...])` au lieu de
`WHERE id IN (SELECT ...)`" **Mal :** "Conçois de bons schémas"

### 2. Structure erreur d'abord

Montre toujours le pattern problématique en premier, puis la solution. Cela
entraîne les agents à reconnaître les anti-patterns.

```markdown
**Incorrect (sequential queries):** [bad example]

**Correct (batched query):** [good example]
```

### 3. Impact quantifié

Inclus des métriques précises. Cela aide les agents à prioriser les corrections.

**Bien :** "requêtes 10x plus rapides", "index 50 % plus petit", "élimine le N+1" 
**Mal :** "Plus rapide", "Mieux", "Plus efficace"

### 4. Exemples autonomes

Les exemples doivent être complets et exécutables (ou presque). Inclus le `CREATE TABLE`
si le contexte l'exige.

```sql
-- Include table definition when needed for clarity
CREATE TABLE users (
  id bigint PRIMARY KEY,
  email text NOT NULL,
  deleted_at timestamptz
);

-- Now show the index
CREATE INDEX users_active_email_idx ON users(email) WHERE deleted_at IS NULL;
```

### 5. Nommage sémantique

Utilise des noms de tables/colonnes explicites. Les noms portent l'intention pour les LLM.

**Bien :** `users`, `email`, `created_at`, `is_active`
**Mal :** `table1`, `col1`, `field`, `flag`

---

## Standards des exemples de code

### Formatage SQL

```sql
-- Use lowercase keywords, clear formatting
CREATE INDEX CONCURRENTLY users_email_idx
  ON users(email)
  WHERE deleted_at IS NULL;

-- Not cramped or ALL CAPS
CREATE INDEX CONCURRENTLY USERS_EMAIL_IDX ON USERS(EMAIL) WHERE DELETED_AT IS NULL;
```

### Commentaires

- Explique le _pourquoi_, pas le _quoi_
- Souligne les implications sur les performances
- Signale les pièges courants

### Tags de langage

- `sql` - Requêtes SQL standard
- `plpgsql` - Procédures/fonctions stockées
- `typescript` - Code applicatif (si nécessaire)
- `python` - Code applicatif (si nécessaire)

---

## Quand inclure du code applicatif

**Par défaut : SQL uniquement**

La plupart des références doivent se concentrer sur des patterns SQL purs. Cela garde les exemples portables.

**Inclus du code applicatif quand il s'agit de :**

- Configuration du connection pooling
- Gestion des transactions dans un contexte applicatif
- Anti-patterns d'ORM (N+1 dans Prisma/TypeORM)
- Utilisation des prepared statements

**Format pour les exemples mixtes :**

````markdown
**Incorrect (N+1 in application):**

```typescript
for (const user of users) {
  const posts = await db.query("SELECT * FROM posts WHERE user_id = $1", [
    user.id,
  ]);
}
```
````

**Correct (batch query):**

```typescript
const posts = await db.query("SELECT * FROM posts WHERE user_id = ANY($1)", [
  userIds,
]);
```

---

## Niveaux d'impact

| Niveau | Amélioration | À utiliser quand |
|--------|--------------|------------------|
| **CRITICAL** | 10-100x | Index manquants, saturation des connexions, scans séquentiels sur de grandes tables |
| **HIGH** | 5-20x | Mauvais types d'index, partitionnement inadapté, covering indexes manquants |
| **MEDIUM-HIGH** | 2-5x | Requêtes N+1, pagination inefficace, optimisation RLS |
| **MEDIUM** | 1.5-3x | Index redondants, instabilité des plans de requête |
| **LOW-MEDIUM** | 1.2-2x | Tuning de VACUUM, ajustements de configuration |
| **LOW** | Incrémental | Patterns avancés, cas limites |

---

## Standards de référence

**Sources principales :**

- Documentation officielle de Postgres
- Documentation Supabase
- Wiki Postgres
- Blogs reconnus (2ndQuadrant, Crunchy Data)

**Format :**

```markdown
Reference:
[Postgres Indexes](https://www.postgresql.org/docs/current/indexes.html)
```

---

## Checklist de relecture

Avant de soumettre une référence :

- [ ] Le titre est clair et orienté action
- [ ] Le niveau d'impact correspond au gain de performance
- [ ] impactDescription inclut une quantification
- [ ] L'explication est concise (1-2 phrases)
- [ ] Contient au moins 1 exemple SQL **Incorrect**
- [ ] Contient au moins 1 exemple SQL **Correct**
- [ ] Le SQL utilise un nommage sémantique
- [ ] Les commentaires expliquent le _pourquoi_, pas le _quoi_
- [ ] Les compromis sont mentionnés le cas échéant
- [ ] Les liens de référence sont inclus
- [ ] `pnpm test` passe
