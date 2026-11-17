# Ultimate Priest Assistant

Assistant de combat pour le prêtre sur **WoW: Forever** (client 1.60.1, interface 16001).
Il reprend le socle d'Ultimate Rogue Assistant : mêmes principes, mêmes réglages, même
respect des restrictions du client. Il ne lance aucun sort sans un clic du joueur.

> **État : non testé en jeu.** Cet addon a été écrit sans personnage prêtre pour le
> vérifier. Sa syntaxe est validée et il réutilise un socle éprouvé sur le voleur, mais
> les parties propres au prêtre (voir « À vérifier ») n'ont jamais tourné.

## Installation

Copier le dossier `UltimatePriestAssistant` dans `Interface/AddOns`, puis relancer le jeu.
L'addon reste inactif sur un personnage qui n'est pas prêtre.

## Ce que l'addon affiche

| Groupe | Contenu |
|---|---|
| Mana | Barre de mana avec valeur et couleur par seuil |
| Afflictions sur la cible | Vos afflictions sur la cible (Mot de l'ombre : Douleur, Peste dévorante…) avec leur durée |
| Sorts principaux | Icônes des sorts de dégâts ou de soins, avec balayage et temps de recharge |
| Défensifs | Mot de pouvoir : Bouclier, Oubli, Prière du désespoir, Gardien de peur… |
| Temps forts | Focalisation améliorée, Infusion de puissance… |
| Barres de recharge | Une barre par recharge en cours |
| Améliorations | Rappels de Feu intérieur, Robustesse, Esprit divin, Forme d'Ombre… |

États d'une icône : contour doré (prête), balayage et chiffres (en recharge), assombrie avec
liseré bleu (mana insuffisant), assombrie (une condition manque).

### Améliorations

Chaque tuile surveille une amélioration que vous entretenez sur vous-même.

- Contour **rouge** : absente. **Orange** : expiration proche.
- **Clic gauche** : la lance sur vous.
- En combat, le jeu ne laisse pas lire les auras : la tuile s'atténue et garde le dernier
  état connu, sans rien affirmer.

### Afflictions sur la cible

En combat, un addon ne peut pas lire les auras. Ce groupe utilise donc le conteneur d'auras
fourni par le client : c'est le jeu qui choisit les afflictions et remplit les icônes. Si ce
conteneur ne fonctionne pas sur votre client, le groupe reste vide, un message le signale et
le reste de l'addon continue de fonctionner.

## Réglages

`/upa` ouvre la fenêtre de réglages (Général, Groupes, Sorts, Améliorations).
`/upa unlock` déverrouille les groupes : glisser pour déplacer, molette ou coin pour la taille.

| Commande | Effet |
|---|---|
| `/upa` | Ouvre ou ferme la fenêtre de réglages |
| `/upa help` | Liste des commandes |
| `/upa unlock` / `/upa lock` | Déverrouille ou verrouille les groupes |
| `/upa profile [nom]` | Profil : PvE, PvP, Leveling, Custom |
| `/upa spec [auto\|discipline\|sacre\|ombre]` | Affiche ou choisit la spécialisation |
| `/upa spells` | Liste les sorts appris et ceux qui sont suivis |
| `/upa track <nom>` / `/upa untrack <nom>` | Suit ou cesse de suivre un sort |
| `/upa add <principaux\|defensifs\|offensifs> <nom>` | Ajoute un sort du grimoire |
| `/upa remove <nom>` | Retire un sort ajouté à la main |
| `/upa reset` | Réinitialise le profil actif, après confirmation |
| `/upa debug` | État interne, dont l'état du groupe des afflictions |

## À vérifier en jeu

1. **Chargement** sans erreur Lua, message « version 1.0.0 chargée ».
2. **Barre de mana** : suit le mana en combat, change de couleur aux seuils.
3. **Spécialisation** : `/upa spec` doit afficher les bons points par arbre. L'ordre des
   arbres (Discipline, Sacré, Ombre) est supposé identique à Classic ; s'il est faux, la
   détection désigne le mauvais préréglage et il faut choisir à la main.
4. **Sorts** : `/upa spells` liste votre grimoire. Les identifiants viennent de Classic ; un
   sort absent s'ajoute avec `/upa add`.
5. **Améliorations** : les tuiles reflètent vos améliorations hors combat ; le clic les lance.
6. **Afflictions sur la cible** : c'est la partie la plus incertaine. `/upa debug` indique
   « actif » ou la raison de l'échec.

## Limites

- Le mana est traité comme une valeur secrète : aucun son ni animation sur un seuil.
- Le temps de recharge est secret en combat : pas de tri des barres par temps restant.
- Les améliorations ne sont lisibles que hors combat.
- Le journal de combat est inaccessible : aucun suivi des sorts ennemis.
- L'âme affaiblie et les autres affaiblissements sur vos alliés ne sont pas suivis.
