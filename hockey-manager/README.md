# Hockey Manager Arcade

Jeu de gestion de hockey solo, joueurs et clubs fictifs. Étape 1 : un match jouable.

```bash
npm install
npm run dev      # lance le jeu en local
npm test         # tests du moteur de match
npm run build    # vérification des types et build de production
```

- `src/engine/` : moteur de match sans affichage (`step`, `simulateMatch`), génération des équipes, aléatoire à graine.
- `src/ui/` : écrans React et rendu Canvas de la patinoire.
