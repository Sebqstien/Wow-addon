import type { Rng } from './rng';

/** Ordre des postes dans une ligne : ailier gauche, centre, ailier droit, défenseur gauche, défenseur droit. */
export const SLOT_LABELS = ['AG', 'C', 'AD', 'DG', 'DD', 'G'] as const;

export interface Player {
  id: number;
  firstName: string;
  lastName: string;
  number: number;
  age: number;
  trait: string;
  skating: number;
  shooting: number;
  passing: number;
  physical: number;
  defense: number;
  mental: number;
  /** Niveau de gardien, utilisé seulement dans les cages. */
  goalie: number;
}

export interface Team {
  name: string;
  short: string;
  color: string;
  ink: string;
  /** Trois lignes de cinq patineurs. */
  lines: Player[][];
  goalie: Player;
}

export interface ClubSpec {
  name: string;
  short: string;
  color: string;
  ink: string;
}

/** Clubs entièrement fictifs. */
export const CLUBS: ClubSpec[] = [
  { name: 'Aigles de Valmont', short: 'VALMONT', color: '#FF7A1A', ink: '#1A0E04' },
  { name: 'Loups de Brenac', short: 'BRENAC', color: '#DDE4EC', ink: '#0B0F14' },
  { name: 'Lynx de Serrac', short: 'SERRAC', color: '#A78BFA', ink: '#160B33' },
  { name: 'Ours de Kervan', short: 'KERVAN', color: '#4ADE80', ink: '#052911' },
  { name: 'Faucons de Morlane', short: 'MORLANE', color: '#3DD6F5', ink: '#06222B' },
  { name: 'Béliers de Tarsac', short: 'TARSAC', color: '#FACC15', ink: '#231A02' },
];

const FIRST_NAMES = [
  'Marek', 'Timo', 'Jonas', 'Elias', 'Lukas', 'Anton', 'Milan', 'Petr', 'Nils', 'Oskar',
  'Hugo', 'Léo', 'Arno', 'Sven', 'Mats', 'Ivo', 'Rémi', 'Théo', 'Yanis', 'Karl',
  'Emil', 'Viktor', 'Bastien', 'Loïc', 'Dario', 'Aksel', 'Tomas', 'Joni', 'Radek', 'Noé',
];

const LAST_NAMES = [
  'Dolan', 'Varga', 'Riedl', 'Brassard', 'Kowal', 'Ferrand', 'Nyberg', 'Vasseur', 'Holmek', 'Sorvino',
  'Castagne', 'Lindqvar', 'Morvan', 'Petrak', 'Halvorsen', 'Delorme', 'Zubrik', 'Aubrac', 'Kessler', 'Marchetto',
  'Tervonen', 'Blanchard', 'Novotek', 'Guérin', 'Strandel', 'Bergamo', 'Rouvière', 'Jankov', 'Lemaire', 'Odermann',
  'Vauclair', 'Sandrik', 'Peltier', 'Hrubec', 'Maillard', 'Ekdal', 'Fontanel', 'Brodar', 'Chastain', 'Lundmark',
];

const clampAttr = (v: number) => Math.max(35, Math.min(99, Math.round(v)));

function makePlayer(rng: Rng, id: number, slot: number, level: number, used: Set<number>): Player {
  const isForward = slot <= 2;
  const isGoalie = slot === 5;
  const roll = (bias: number) => clampAttr(level + bias + rng.gauss() * 6);
  let number = rng.int(2, 97);
  while (used.has(number)) number = rng.int(2, 97);
  if (isGoalie) number = rng.pick([1, 30, 31, 33, 35]);
  used.add(number);

  const p: Player = {
    id,
    firstName: rng.pick(FIRST_NAMES),
    lastName: rng.pick(LAST_NAMES),
    number,
    age: rng.int(18, 34),
    trait: '',
    skating: roll(isForward ? 3 : -1),
    shooting: roll(isForward ? 5 : -7),
    passing: roll(slot === 1 ? 5 : 0),
    physical: roll(isForward ? -3 : 5),
    defense: roll(isForward ? -8 : 7),
    mental: roll(0),
    goalie: isGoalie ? roll(4) : 30,
  };
  if (isGoalie) {
    p.skating = clampAttr(p.skating - 12);
    p.shooting = clampAttr(p.shooting - 20);
    p.trait = 'Réflexes';
    return p;
  }
  const best = Math.max(p.skating, p.shooting, p.passing, p.physical, p.defense);
  p.trait =
    best === p.shooting ? 'Sniper'
    : best === p.passing ? 'Passeur'
    : best === p.skating ? 'Rapide'
    : best === p.physical ? 'Bagarreur'
    : 'Mur';
  return p;
}

/** Note globale d'un joueur, pondérée selon son poste. */
export function overall(p: Player, slot: number): number {
  if (slot === 5) return p.goalie;
  const w = slot <= 2
    ? [0.24, 0.28, 0.2, 0.1, 0.06, 0.12]
    : [0.2, 0.08, 0.16, 0.2, 0.26, 0.1];
  const v = [p.skating, p.shooting, p.passing, p.physical, p.defense, p.mental];
  return Math.round(v.reduce((sum, x, i) => sum + x * w[i], 0));
}

export function generateTeam(rng: Rng, spec: ClubSpec, level: number, idBase: number): Team {
  const used = new Set<number>();
  let id = idBase;
  const lineBias = [5, 0, -5];
  const lines = lineBias.map((bias) =>
    [0, 1, 2, 3, 4].map((slot) => makePlayer(rng, id++, slot, level + bias, used)),
  );
  return { ...spec, lines, goalie: makePlayer(rng, id++, 5, level, used) };
}

export const playerLabel = (p: Player) => `#${p.number} ${p.firstName} ${p.lastName}`;
