# Agents d'analyse contextuelle

Ressource partagée utilisée par les commandes `/resolve-conflicts` et `/merge`.
Trois agents spécialisés lancés en parallèle pour comprendre le contexte des modifications.

## Agent A — Documentation

a. Recherche dans **tous les fichiers markdown du projet** via `**/*.md` ceux qui mentionnent les fonctionnalités, modules ou fichiers impactés
b. Inclut explicitement `CLAUDE.md`, `README.md`, `docs/specs/`, `docs/adr/`, et tout fichier de doc trouvé ailleurs dans l'arborescence
c. Extrait les informations pertinentes :
   - Décisions architecturales (ADR) qui s'appliquent aux zones analysées
   - Specs qui décrivent le comportement attendu
   - Conventions et patterns documentés
d. Si peu ou pas de documentation pertinente trouvée : le signale explicitement pour que les autres agents compensent

## Agent B — Historique git

a. `git log <ancêtre>..<branche-1>` et `git log <ancêtre>..<branche-2>` sur les fichiers analysés
b. `git diff <ancêtre>..<branche-1>` et `git diff <ancêtre>..<branche-2>` pour comprendre l'évolution complète
c. Reconstruit l'intention de chaque branche :
   - Quel problème chaque série de commits résout
   - Dans quel ordre les modifications ont été faites
   - Si une modification en remplace explicitement une autre
d. Compense le manque éventuel de documentation signalé par l'Agent A

## Agent C — Dépendances codebase

a. Analyse les imports, exports et signatures qui changent dans les modifications analysées
b. Identifie les fichiers qui dépendent du code modifié :
   - Qui importe les modules modifiés
   - Qui appelle les fonctions/méthodes dont la signature change
   - Qui utilise les types/interfaces modifiés
c. Anticipe les incohérences potentielles :
   - Import ajouté d'un côté mais pas de l'autre
   - Signature modifiée d'un côté, appelants non mis à jour de l'autre
   - Type renommé ou restructuré
