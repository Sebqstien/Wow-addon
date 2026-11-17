# Ultimate Rogue Assistant

Assistant de combat pour le voleur sur **WoW: Forever** (client 1.60.1, interface 16001).
Il affiche l'énergie, les points de combo, les techniques et leurs recharges, et gère les
poisons des deux armes. C'est un assistant visuel : il ne lance aucun sort et n'applique
aucun poison sans un clic du joueur.

Le dépôt contient aussi **Ultimate Priest Assistant**, la version pour le prêtre, dans
`UltimatePriestAssistant/` (voir son `README.md`). Elle n'a pas encore été testée en jeu.

## Installation

1. Copier le dossier `UltimateRogueAssistant` dans `Interface/AddOns` du client Forever.
2. Relancer le jeu et vérifier que l'addon est coché dans la liste des addons.
3. En jeu, le message « version 1.0.0 chargée » confirme le chargement.

L'addon reste inactif sur un personnage qui n'est pas voleur.

Le dossier `UltimateRogueAssistant_Diag` est un outil de diagnostic séparé et facultatif. Il
mesure ce que le client autorise (voir `docs/AUDIT-PHASE1.md`) et n'est pas nécessaire au
fonctionnement de l'addon.

## Ce que l'addon affiche

Six groupes indépendants, placés par défaut au centre inférieur de l'écran :

| Groupe | Contenu |
|---|---|
| Énergie et combo | Barre d'énergie avec valeur et couleur par seuil ; cinq pastilles de combo et leur nombre |
| Sorts principaux | Icônes des techniques de base, avec balayage et temps de recharge |
| Défensifs | Évasion, Disparition, Sprint… |
| Offensifs | Déluge de lames, Poussée d'adrénaline… |
| Barres de recharge | Une barre par recharge en cours, avec compteur |
| Poisons | Une tuile par arme : poison actif, durée, charges, poison choisi et quantité en sac |

États d'une icône de technique :

- **contour doré** : prête et utilisable, avec un éclat au moment où elle redevient disponible ;
- **balayage et chiffres** : en recharge ;
- **assombrie, liseré bleu** : prête, mais énergie insuffisante ;
- **assombrie** : prête, mais une condition manque (camouflage, cible, points de combo…).

Hors combat et sans cible, l'interface s'estompe.

## Poisons

- **Clic droit** sur une arme : choisit le poison parmi ceux des sacs (hors combat).
- **Clic gauche** : applique le poison choisi sur cette arme.
- Contour **rouge** : aucun poison. **Orange** : expiration proche. **Bleu** : poison différent
  de celui choisi dans le profil.
- Chaque profil mémorise son poison par arme. Changer de profil ne fait que préparer les
  boutons : rien n'est appliqué automatiquement.

Le jeu ne fournit pas le nom d'un poison posé sur une arme. L'addon l'apprend la première
fois que le poison est appliqué avec ses boutons ; avant cela, il affiche « Poison appliqué ».

## Réglages

`/ura` ouvre la fenêtre de réglages :

- **Général** : profil, spécialisation, verrouillage, animations, alertes de poison, seuils et
  couleurs de l'énergie, couleurs des points de combo, opacité hors combat.
- **Groupes** : affichage, taille et opacité de chaque groupe.
- **Techniques** : techniques suivies et leur ordre dans chaque groupe.

Pour déplacer les groupes : décocher « Verrouiller les groupes » (ou `/ura unlock`), puis
glisser chaque groupe. La molette ou le coin inférieur droit change sa taille.

### Profils et spécialisations

- Quatre profils : **PvE**, **PvP**, **Leveling**, **Custom**. Chacun garde sa disposition, ses
  seuils, ses couleurs, ses poisons et ses techniques. Le profil actif est mémorisé par personnage.
- La spécialisation (**Assassinat**, **Combat**, **Finesse**) est détectée d'après les points de
  talents : c'est l'arbre le plus investi. Elle peut aussi être choisie à la main.
- Chaque spécialisation a un préréglage de techniques. Les choix du joueur sont enregistrés
  par profil et par spécialisation.

### Commandes

| Commande | Effet |
|---|---|
| `/ura` | Ouvre ou ferme la fenêtre de réglages |
| `/ura help` | Liste des commandes |
| `/ura unlock` / `/ura lock` | Déverrouille ou verrouille les groupes |
| `/ura profile [nom]` | Affiche ou change le profil |
| `/ura spec [auto\|assassinat\|combat\|finesse]` | Affiche ou choisit la spécialisation |
| `/ura spells` | Liste les techniques apprises et celles qui sont suivies |
| `/ura track <nom>` / `/ura untrack <nom>` | Suit ou cesse de suivre une technique |
| `/ura add <principaux\|defensifs\|offensifs> <nom>` | Ajoute un sort du grimoire |
| `/ura remove <nom>` | Retire un sort ajouté à la main |
| `/ura scale <groupe> <0.5-2.5>` | Taille d'un groupe |
| `/ura alpha <groupe> <0.1-1>` | Opacité d'un groupe |
| `/ura reset` | Réinitialise le profil actif, après confirmation |
| `/ura debug` | État interne : version, restrictions, spécialisation, techniques suivies |

## Limites imposées par le client

WoW: Forever reprend le système de « valeurs secrètes » de Retail 12 : certaines données
peuvent être affichées par un addon, mais pas lues. Mesuré en jeu sur le build 70888 :

| Donnée | Situation | Conséquence |
|---|---|---|
| Énergie | Secrète en permanence | Barre, valeur et couleur par seuil fonctionnent. Aucun son ni animation ne peut se déclencher sur un seuil. |
| Temps de recharge | Secret en combat | Balayage, barre et compteur sont dessinés par le jeu. Impossible de trier les barres par temps restant ou d'alerter « plus que X secondes ». |
| État prêt / en recharge | Lisible | Les alertes de disponibilité sont fiables. |
| Points de combo | Jamais secrets | Toutes les fonctions sont disponibles. |
| Poisons des armes | Lisibles | Durée, charges et alertes fonctionnent. |
| Buffs et debuffs | Secrets en combat | Non suivis par l'addon. |
| Journal de combat | Inaccessible aux addons | Aucun suivi des recharges ennemies. |

Autres limites :

- Le panneau de poisons ne se déplace, ne se redimensionne et ne se règle que **hors combat** :
  ses boutons sont des boutons sécurisés.
- Les préréglages Assassinat et Finesse n'ont pas été testés en jeu sur un personnage de cette
  spécialisation.
- Les identifiants des techniques non encore apprises par le personnage de test viennent de
  la numérotation Classic et ne sont pas vérifiés sur Forever. `/ura add` permet de suivre
  n'importe quel sort du grimoire par son nom.
- Les nouvelles techniques de Forever (Mutilation, Marque de mort…) ne sont pas dans la base.

## Structure

```
UltimateRogueAssistant/
├── UltimateRogueAssistant.toc
├── Core.lua            espace de noms, modules, cycle de vie
├── Locales.lua         textes de l'interface (frFR, enUS)
├── Config.lua          valeurs par défaut, schéma de la sauvegarde
├── Commands.lua        commande /ura
├── Utils/              Events (répartiteur unique), API (appels au jeu), Secrets, Helpers
├── Data/               Spells, Poisons, Talents (préréglages par spécialisation)
├── Modules/            logique : Profiles, Energy, ComboPoints, Specialization,
│                       SpellAvailability, Cooldowns, PoisonManager
└── UI/                 affichage : Style, Animations, Movers, MainFrame, EnergyBar,
                        ComboPoints, SpellIcons, CooldownBars, PoisonPanel, ConfigFrame
```

Principes : les modules ne créent aucun cadre et l'interface ne contient aucune logique de
jeu ; tout est piloté par les événements du client, sans boucle de mise à jour pour les
recharges, l'énergie ou les points de combo ; aucune bibliothèque externe.

## Sauvegarde

Les réglages sont enregistrés dans `URA_DB` (SavedVariables) et conservés entre les sessions.
