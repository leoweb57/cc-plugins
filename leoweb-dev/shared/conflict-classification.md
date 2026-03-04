# Classification des conflits

Ressource partagée utilisée par les commandes `/resolve-conflicts` et `/merge`.
Table de classification pour catégoriser chaque conflit (réel ou anticipé) et déterminer l'action appropriée.

| Classification | Critère | Action |
|---|---|---|
| **ADDITIF** | Les deux côtés ajoutent des choses différentes, non contradictoires | Fusionner les deux ajouts |
| **CONTRADICTOIRE** | Même logique modifiée différemment par les deux côtés | Choisir un côté en argumentant |
| **SUPERSÉDANT** | Un côté remplace fonctionnellement ce que l'autre modifie | Intégrer la version qui supersède |
| **STRUCTUREL** | Imports, formatage, ordre des déclarations | Résolution mécanique |
| **DÉCISION REQUISE** | Ambiguïté — impossible de trancher sans l'utilisateur | Présenter 2 options argumentées |
