# Instructions plugin leoweb-dev

## Vérification technologique obligatoire

Avant d'implémenter du code qui utilise une librairie, framework, SDK ou technologie externe, active le skill `check-deps` pour vérifier que tes connaissances sont à jour. Tes données de training ont un cutoff — les APIs changent, les versions majeures cassent la rétrocompatibilité. Ne fais jamais confiance à ta mémoire sur les APIs externes sans vérification.

## Dates et timestamps obligatoires via MCP Time

Ne JAMAIS inventer, deviner ou estimer une date, une heure ou un timestamp. Utilise systématiquement le MCP Time (`get_current_time`) chaque fois que tu as besoin de :
- Générer un timestamp (noms de fichiers de migration, logs, identifiants horodatés)
- Écrire une date dans du code, un fichier ou un document
- Savoir quel jour ou quelle heure il est
- Comparer des dates ou calculer des durées par rapport à maintenant

Tu n'as PAS de notion fiable du temps. Le contexte système peut contenir une date approximative mais elle ne suffit pas pour des timestamps précis. Le MCP Time est ta seule source de vérité temporelle.
