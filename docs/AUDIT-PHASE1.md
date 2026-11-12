# Ultimate Rogue Assistant — Phase 1 : audit technique de WoW: Forever

Date : 12 novembre 2026. Statut : **en attente de validation avant toute implémentation.**

## 0. Méthode et niveau de confiance

Je n'ai pas accès à un client de jeu : rien n'a été exécuté en jeu. L'audit repose sur la
lecture du code d'interface officiel de Blizzard, extrait du client et publié dans le dépôt
`Gethe/wow-ui-source`, branche `forever`, commit `4cd0ab7` du 10 novembre 2026
(`version.txt` = `1.60.1.70888`). Ce code contient la documentation d'API générée par Blizzard
(`Blizzard_APIDocumentationGenerated`, 643 fichiers) et l'interface par défaut, qui montre
comment Blizzard utilise lui-même ces API sur ce client.

Chaque constat porte une étiquette :

- **[Source]** : lu dans le code ou la documentation d'API de la build 1.60.1.70888.
- **[En jeu]** : dépend d'un réglage décidé par le serveur ou de données absentes du code
  d'interface ; à confirmer par une commande en jeu (section 8).
- **[Tiers]** : rapporté par des sites tiers, non vérifiable depuis le code.

## 1. Version exacte du client

| Élément | Valeur | Confiance |
|---|---|---|
| Version / build | 1.60.1, build 70888 | [Source] |
| Nom interne | « Camelot » (`WOW_PROJECT_CAMELOT = 18`, type de jeu `camelot`) | [Source] |
| Famille de code | « Mainline » (Retail), pas Classic : les fichiers Forever sont des surcharges posées sur l'interface Retail 12.x | [Source] |
| Numéro d'interface TOC | `16001` (dérivé de 1.60.1 ; les TOC de Blizzard indiquent `0`) | [Tiers], cohérent avec la version |
| Suffixe TOC | `_Camelot.toc` utilisé par des addons publiés ; `_Forever.toc` rapporté mais contesté | [Tiers] |
| Dossier AddOns | `_forever_` ou `_classic_era_` selon les sources | [Tiers], contradictoire |

Décision : un seul fichier `UltimateRogueAssistant.toc` sans suffixe, avec `## Interface: 16001`.
C'est la seule forme qui ne dépend d'aucune information non vérifiée.

## 2. Le point qui change tout : les « valeurs secrètes »

Forever n'utilise pas l'API de Classic Era. Il embarque le système de restrictions introduit
par Retail 12.0 (Midnight) : `C_Secrets`, `C_RestrictedActions`, `issecretvalue`,
`ADDON_RESTRICTION_STATE_CHANGED`. [Source]

Principe : quand une restriction est active (type `Combat`, `Encounter`, `PvPMatch`, `Map`…),
certaines API renvoient une valeur **secrète**. Un addon peut la **transmettre à un widget**
(barre, texte, cooldown), mais ne peut ni la comparer, ni la calculer, ni s'en servir comme
clé de table. Toute tentative provoque une erreur Lua.

API concernées d'après la documentation de la build [Source] :

| Donnée | API | Marquage |
|---|---|---|
| Cooldown d'un sort | `C_Spell.GetSpellCooldown` | secret si cooldowns restreints ; `isActive`, `isEnabled`, `isOnGCD` **jamais secrets** |
| Charges | `C_Spell.GetSpellCharges` | secret ; `maxCharges` et `isActive` jamais secrets |
| Durée de cooldown (objet) | `C_Spell.GetSpellCooldownDuration`, `GetSpellChargeDuration` | renvoie un objet de durée utilisable par les widgets |
| Énergie | `UnitPower`, `UnitPowerPercent` | secret si puissance restreinte |
| Points de combo | `GetComboPoints("player","target")` | secret si puissance restreinte |
| Buffs / debuffs | `C_UnitAuras.*` | secret si auras restreintes ; les recherches par ID de sort exigent une aura non secrète |
| Incantations | `UnitCastingInfo`, `UNIT_SPELLCAST_SUCCEEDED` | secret si incantations restreintes |
| Journal de combat | `COMBAT_LOG_EVENT_UNFILTERED` | marqué `HasRestrictions` : inutilisable par un addon |
| Utilisabilité | `C_Spell.IsSpellUsable` | **non secret** |
| Enchantements d'arme | `C_Item.GetWeaponEnchantInfo` | **non secret** |
| Talents | `C_Traits.*`, `C_SpecializationInfo.*` | non secret |

Ce que le code ne dit pas [En jeu] : si les restrictions sont effectivement activées sur les
royaumes Forever (`C_Secrets.HasSecretRestrictions()`), et quel est le niveau de secret de
l'énergie et des points de combo (`C_Secrets.GetPowerTypeSecrecy`). Les sources tierces
affirment que Forever hérite des restrictions. L'interface Blizzard elle-même teste
`HasSecretRestrictions()`, ce qui montre que la réponse est décidée à l'exécution.

Décision de conception : **l'addon est écrit pour le cas le plus restrictif** (tout secret en
combat) et active les fonctions supplémentaires seulement quand le client déclare la donnée
lisible. Ainsi il ne peut ni planter ni afficher une information fausse, quel que soit le
réglage du serveur.

## 3. API disponibles par fonctionnalité

### Cooldowns [Source]
- `C_Spell.GetSpellCooldown(id)`, `C_Spell.GetSpellCharges(id)`, `C_Spell.GetSpellCooldownDuration(id)`.
- Événements : `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `SPELL_UPDATE_USABLE`, `SPELLS_CHANGED`.
- Affichage sans lecture : `Cooldown:SetCooldownFromDurationObject`, `StatusBar:SetTimerDuration`
  (barre animée par le client, sans `OnUpdate`), `C_DurationUtil.CreateDurationTextBinding`
  (texte du temps restant mis à jour par le client).
- Les fonctions globales de Classic (`GetSpellCooldown`, `UnitBuff`…) ne sont pas à utiliser :
  celles qui subsistent sont des béquilles de dépréciation désactivables par CVar.

### Énergie [Source]
- `UnitPower("player", Enum.PowerType.Energy)`, `UnitPowerMax`, `UnitPowerPercent(unit, type, unmodified, curve)`.
- Événements : `UNIT_POWER_FREQUENT`, `UNIT_POWER_UPDATE`, `UNIT_MAXPOWER`.
- `StatusBar:SetValue` et `FontString:SetText/SetFormattedText` acceptent une valeur secrète.
- Couleur par seuil : courbe de couleur à paliers (`C_CurveUtil`, type `Step`) évaluée par
  `UnitPowerPercent` ; le client choisit la couleur, l'addon ne lit jamais la valeur.

### Points de combo [Source]
- `GetComboPoints("player", "target")`. Le commentaire de Blizzard dans le code Forever :
  « Combo points are stored on the target ». Les points sont donc liés à la cible, comme en Vanilla.
- Événements : `UNIT_POWER_FREQUENT`, `UNIT_POWER_UPDATE`, `PLAYER_TARGET_CHANGED`, et
  `COMBO_TARGET_CHANGED` (déplacement des points vers une nouvelle cible sans événement de puissance).
- `UnitPowerMax("player", Enum.PowerType.ComboPoints)` pour le maximum.

### Poisons [Source]
- `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand | OffHand)` renvoie une **liste**
  d'enchantements par arme : `hasEnchant`, `enchantType` (`Temporary` ou `Imbue`), `timeLeft` (ms),
  `charges`, `enchantID`, `enchantIconID`. Une arme peut donc porter plusieurs enchantements
  temporaires, ce qui concorde avec les sources tierces (poison et pierre à aiguiser cumulables).
- Événements : `WEAPON_ENCHANT_CHANGED`, `WEAPON_SLOT_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`,
  `UNIT_INVENTORY_CHANGED`, `BAG_UPDATE_DELAYED`.
- Application : `SecureActionButtonTemplate` avec `type="item"` (ou `"spell"`) et
  `target-slot=16` (main droite) ou `17` (main gauche). Le code sécurisé de Forever gère bien
  `target-slot` : un clic du joueur utilise le poison puis le pose sur l'arme.

### Talents et spécialisation [Source]
- Forever n'a pas de spécialisation au sens Retail. Le voleur possède un arbre unique
  (ID 1488) divisé en trois groupes (Assassinat, Combat, Finesse) avec un compteur de points par groupe.
- Lecture : `C_Traits.GetGroupDisplayInfoByTreeID`, `C_Traits.GetGroupCurrencyInfo`.
- Double spécialisation : `C_SpecializationInfo.GetActiveSpecGroup()`.
- Événements : `TRAIT_CONFIG_UPDATED`, `ACTIVE_TALENT_GROUP_CHANGED`, `PLAYER_TALENT_UPDATE`.
- La « spécialisation » affichée par l'addon sera donc **déduite** : le groupe qui a reçu le plus de points.

### Sorts connus [Source]
- `C_SpellBook.IsSpellInSpellBook`, `C_SpellBook.IsSpellKnown`, parcours du grimoire par lignes de compétence.
- Noms et icônes fournis par le client (`C_Spell.GetSpellInfo`), donc aucune traduction à maintenir.

### Cible, combat, camouflage [Source]
- `PLAYER_TARGET_CHANGED`, `PLAYER_REGEN_DISABLED/ENABLED`, `UPDATE_STEALTH`, `IsStealthed()`.

## 4. Limitations techniques

1. **Temps de recharge illisible en combat.** L'addon peut afficher le temps restant (barre,
   balayage, texte), mais ne peut pas raisonner dessus. Conséquences : pas de tri des barres
   par temps restant, pas d'alerte « plus que 3 secondes », pas de format de texte calculé par
   l'addon. L'état prêt / en recharge reste fiable (`isActive` n'est jamais secret), tout comme
   la distinction avec le GCD (`isOnGCD`).
2. **Charges courantes** : affichables, non comparables. Le maximum est lisible.
3. **Énergie** probablement secrète en combat [En jeu]. Barre, valeur et pourcentage restent
   affichables ; couleurs par seuil possibles via courbe. Impossible si secret : alerte sonore
   ou animation déclenchée par un seuil. Les seuils s'expriment en pourcentage.
4. **Points de combo** : secret ou non selon le client [En jeu]. Les cinq pastilles sont
   réalisables dans les deux cas (une mini-barre par point, remplie par le client). Si la valeur
   est secrète : pas d'animation à chaque point gagné et pas de chiffre calculé, seulement
   l'affichage brut.
5. **Buffs et debuffs** (Débiter, Rupture, poisons sur la cible…) : en combat, les auras sont
   secrètes par défaut et les recherches par ID échouent. Le module Buffs ne peut pas être
   promis. Il sera limité aux auras que le client déclare non secrètes
   (`C_Secrets.ShouldSpellAuraBeSecret`), à mesurer en jeu.
6. **Journal de combat inaccessible** : aucun suivi des cooldowns ennemis, des rendements
   décroissants ou des interruptions réussies.
7. **Cadres sécurisés** : un bouton d'application de poison ne peut être ni affiché, ni masqué,
   ni déplacé, ni reconfiguré en combat. Le panneau de poisons sera donc un groupe séparé, et le
   Combat Center ne contiendra aucun bouton sécurisé afin de pouvoir apparaître et disparaître librement.
8. **Identité du poison** : l'API donne `enchantID` et l'icône, pas le nom. L'icône s'affiche
   sans table ; le nom demande une table `enchantID → poison` à relever en jeu.
9. **Identifiants de sorts** : le code d'interface ne contient pas la base de sorts de Forever.
   Les ID des sorts du voleur (et des nouveaux talents comme Mutilation ou Marque de mort,
   rapportés par des tiers) doivent être relevés en jeu.
10. **Mécanique d'application des poisons** (objet consommable ou sort) : non déterminable
    depuis le code. Le bouton sécurisé couvre les deux cas.

## 5. Fonctionnalités réalisables sans contournement

| Demande | Verdict |
|---|---|
| Icônes de sorts avec balayage de cooldown | Oui |
| Barres de progression fluides avec temps restant | Oui, animées par le client |
| État prêt / en recharge, masquage des cooldowns terminés | Oui |
| Contour lumineux quand un sort redevient prêt | Oui |
| Quatre niveaux de disponibilité (cooldown, ressource, conditions, utilisable) | Oui : `isActive` + `C_Spell.IsSpellUsable` (renvoie aussi « ressource insuffisante ») + portée |
| Charges | Affichage oui, logique non en combat |
| Ordre et regroupement des sorts choisis par le joueur | Oui |
| Tri automatique par temps restant | Non en combat |
| Barre d'énergie, valeur, pourcentage, couleurs par seuil | Oui |
| Alerte de seuil d'énergie (son, animation) | Seulement si l'énergie n'est pas secrète |
| Cinq pastilles de combo, effet à 5 points | Oui |
| Animation par point gagné, chiffre | Seulement si non secret |
| Suivi correct au changement de cible | Oui |
| Poisons : présence, durée, charges, icône, par arme | Oui |
| Alertes de poison absent ou expirant | Oui hors combat ; en combat à confirmer |
| Profils de poisons PvE / PvP | Oui, comme préférences |
| Détection de l'arbre dominant et des sorts appris | Oui |
| Profils, SavedVariables, `/ura`, verrouillage, redimensionnement | Oui |
| Buffs et debuffs utiles | Partiel, à mesurer en jeu |
| Suivi des cooldowns ennemis | Non |

## 6. Fonctionnalités exigeant une action manuelle du joueur

- **Appliquer un poison** : toujours un clic du joueur sur un bouton sécurisé, un clic par arme.
- **Changer le poison associé à un bouton** : hors combat uniquement.
- **Afficher, déplacer ou redimensionner le panneau de poisons** : hors combat uniquement.
- **Charger un profil qui modifie le panneau de poisons** : hors combat.
- Aucun lancement de sort, aucune rotation, aucune application automatique.

## 7. Architecture proposée

Votre arborescence est conservée, avec trois ajustements motivés par l'audit.

```
UltimateRogueAssistant/
├── UltimateRogueAssistant.toc      Interface 16001, SavedVariables: URA_DB
├── Core.lua                        namespace, cycle de vie, registre de modules, /ura
├── Config.lua                      valeurs par défaut, schéma et migration de la base
├── Locales.lua                     textes de l'interface (frFR, enUS)
├── Utils/
│   ├── Events.lua                  répartiteur d'événements unique
│   ├── API.lua                     seul fichier qui appelle les API Blizzard
│   ├── Secrets.lua                 détection des capacités : quoi est lisible, quand
│   └── Helpers.lua
├── Data/
│   ├── Spells.lua                  base extensible : id, catégorie, arbre, priorité, effet
│   ├── Poisons.lua                 objets ou sorts, enchantID
│   └── Talents.lua                 groupes de l'arbre 1488
├── Modules/                        logique, sans aucun cadre
│   ├── Specialization.lua  Cooldowns.lua  SpellAvailability.lua
│   ├── Energy.lua  ComboPoints.lua  PoisonManager.lua  Buffs.lua  Profiles.lua
└── UI/                             affichage, sans aucune logique de jeu
    ├── Animations.lua  MainFrame.lua  Movers.lua
    ├── EnergyBar.lua  ComboPoints.lua  SpellIcons.lua  CooldownBars.lua
    ├── PoisonPanel.lua             seul fichier contenant des cadres sécurisés
    └── ConfigFrame.lua
```

Ajustements :

1. **`Utils/Secrets.lua`** (nouveau). Répond à une seule question par donnée : lisible ou
   opaque, maintenant ? Il écoute `ADDON_RESTRICTION_STATE_CHANGED`. Les modules n'appellent
   jamais `issecretvalue` eux-mêmes.
2. **Contrat entre modules et interface.** Un module ne transmet pas des nombres mais des
   valeurs à afficher (éventuellement opaques) accompagnées de drapeaux toujours lisibles
   (`ready`, `onGCD`, `usable`, `noPower`). L'interface applique les valeurs aux widgets ; la
   logique ne s'appuie que sur les drapeaux. C'est ce qui garantit l'absence d'erreur Lua en combat.
3. **`UI/Movers.lua`** (nouveau) : déplacement, redimensionnement, verrouillage et mode
   configuration communs à tous les groupes.

Autres choix :

- **Aucun `OnUpdate`** pour les cooldowns, l'énergie ou les combos : le client anime barres et textes.
- **Base de sorts construite sur le grimoire** : `Data/Spells.lua` décrit les sorts, mais seuls
  ceux réellement présents dans le grimoire du personnage sont affichés. Un ID inconnu est
  ignoré et signalé par `/ura debug`, jamais affiché à tort.
- **Aucune bibliothèque externe** (ni Ace3 ni LibStub).
- **Profils** : PvE, PvP, Leveling, Personnalisé, par personnage, avec migration de schéma.

## 8. Vérifications à faire en jeu avant la phase 2

À coller dans le chat, puis m'envoyer les résultats :

```
/dump GetBuildInfo()
/dump C_Secrets.HasSecretRestrictions()
/dump C_Secrets.GetPowerTypeSecrecy(Enum.PowerType.Energy), C_Secrets.GetPowerTypeSecrecy(Enum.PowerType.ComboPoints)
/dump C_Item.GetWeaponEnchantInfo(0), C_Item.GetWeaponEnchantInfo(1)
```

La dernière commande est à lancer avec un poison sur chaque arme. Résultat attendu pour
`GetPowerTypeSecrecy` : 0 = jamais secret, 1 = toujours secret, 2 = selon le contexte.
Indiquer aussi le nom exact du dossier où le jeu range ses addons.

## 9. Découpage des phases

| Phase | Contenu | Validation en jeu |
|---|---|---|
| 1 | Audit et architecture (ce document) | Commandes de la section 8 |
| 2 | TOC, Core, Events, Secrets, SavedVariables, `/ura`, cadre principal, déplacement et verrouillage, `/ura debug` (relevé des sorts et enchantements) | Chargement sans erreur, persistance |
| 3 | Énergie, combos, icônes, cooldowns, barres, disponibilité | Test en combat, restrictions actives |
| 4 | Poisons : détection, durées, alertes, sélection, boutons sécurisés | Application sur les deux armes |
| 5 | Détection de l'arbre, sorts appris, profils | Test sur les trois arbres |
| 6 | Animations, configuration complète, performances, documentation | Recette des 13 critères |

Chaque phase se termine par une liste de tests à exécuter en jeu. Une fonctionnalité n'est
déclarée terminée qu'après votre retour.

## 10. Sources

- Code d'interface Blizzard, build 1.60.1.70888 : https://github.com/Gethe/wow-ui-source/tree/forever
- Sources tierces (numéro d'interface, suffixe TOC, héritage des restrictions, changements du voleur) :
  - https://wowforevertierlist.com/addons/restrictions
  - https://github.com/Shtian/bff-wow/issues/3
  - https://forevermeta.me/en/guides/wow-forever-addons-interface
  - https://conquestcapped.com/guides/wow-forever/wow-forever-addons/
  - https://classicwowforever.com/class-changes/rogue/
  - https://mobalytics.gg/wow-forever/guides/rogue-class-overview

Les pages tierces n'ont pas pu être ouvertes depuis cet environnement (accès réseau filtré) :
seuls leurs résumés de recherche ont été consultés. Elles ne fondent aucune décision technique.
