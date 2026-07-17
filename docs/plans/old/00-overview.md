# Vue d'ensemble — helloNixShebang 100x

Objectif global : transformer une collection de scripts shebang figée (2022) en
**matrice de comparaison vivante des mécanismes de scripts autosuffisants**,
vérifiée en continu par CI.

## Ordre d'exécution (strict)

| # | Plan | Dépend de | Livrable |
|---|------|-----------|----------|
| 1 | [01-menage-baseline](01-menage-baseline.md) | — | Arbre propre, diff en attente commité |
| 2 | [02-harnais-ci](02-harnais-ci.md) | 01 | `check.sh` + GitHub Actions + cron hebdo |
| 3 | [03-pins-reifies](03-pins-reifies.md) | 02 | Pins par hash, résolveurs récents, shebang `nix` natif |
| 4 | [04-matrice-elargie](04-matrice-elargie.md) | 03 | Mécanismes hors Nix (uv/PEP 723, deno, babashka) |
| 5 | [05-readme-genere](05-readme-genere.md) | 04 | README généré depuis les fichiers |

L'ordre n'est pas négociable : le harnais (02) est ce qui rend les plans 03–05
vérifiables. Sans lui, toute modification de pin est un gist neuf qui pourrira
comme l'ancien.

## Conventions communes à tous les plans

- **Git** : une branche par plan (`plan-01-menage`, etc.), partir de `master`
  à jour. PR vers `master`, merge avec `merge_method: "merge"` (pas squash).
  Ne pas supprimer la branche. CI verte ⇒ merger sans demander.
- **Vérification** : chaque script modifié doit être **exécuté** avant commit.
  Un script qui télécharge (nix, stack) est lent au premier run — c'est
  attendu ; utiliser un timeout large (600 s) et rediriger la sortie complète
  vers un fichier, ne montrer que ~10 lignes en conversation.
- **Portée** : ne toucher aucune ligne hors du périmètre du plan. Les
  améliorations opportunistes repérées en route se notent dans la description
  de PR, elles ne s'exécutent pas.
- **Environnement** : Mac local, Determinate Nix ≥ 2.30 disponible (`nix
  --version` pour confirmer). Aucune exécution nix sur un serveur distant.
- **Réalité avant hypothèse** : quand un plan donne une syntaxe (shebang `nix`
  natif, PEP 723…), la vérité est `nix --help` / la doc de l'outil / un run
  réel — pas le texte du plan. Si la syntaxe du plan est fausse, corriger et
  le signaler dans la PR.

## Critère de fin (tous plans mergés)

`./check.sh` passe localement ; le workflow GitHub Actions passe sur push et
en cron ; le README est généré et affiche la matrice mécanisme × langage ×
pinning × statut ; plus aucune référence à `channel:nixos-21.11`.
