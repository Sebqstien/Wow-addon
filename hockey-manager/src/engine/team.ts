import type { Rng } from './rng';

/** Ordre des postes dans une ligne : ailier gauche, centre, ailier droit, défenseur gauche, défenseur droit. */
export const SLOT_LABELS = ['AG', 'C', 'AD', 'DG', 'DD', 'G'] as const;

export type Role = 'F' | 'D' | 'G';

export interface Player {
  id: number;
  /** Poste naturel : attaquant, défenseur ou gardien. */
  role: Role;
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
  /** Remplaçants : patineurs hors des trois lignes. */
  bench: Player[];
  backupGoalie: Player;
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
    role: isGoalie ? 'G' : isForward ? 'F' : 'D',
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
export const slotRole = (slot: number): Role => (slot === 5 ? 'G' : slot <= 2 ? 'F' : 'D');

/** Un joueur aligné hors de son poste naturel perd une partie de son niveau. */
export const OUT_OF_POSITION = 0.88;

export function overall(p: Player, slot: number): number {
  if (slot === 5) return p.goalie;
  if (p.role !== slotRole(slot)) return Math.round(rawOverall(p, slot) * OUT_OF_POSITION);
  return rawOverall(p, slot);
}

function rawOverall(p: Player, slot: number): number {
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
  const goalie = makePlayer(rng, id++, 5, level, used);
  const bench = [1, 0, 3, 4].map((slot) => makePlayer(rng, id++, slot, level - 7, used));
  const backupGoalie = makePlayer(rng, id++, 5, level - 6, used);
  return { ...spec, lines, goalie, bench, backupGoalie };
}

/* ------------------------------------------------------------------ */
/* Entente d'une ligne                                                  */
/* ------------------------------------------------------------------ */

export interface Chemistry {
  /** De 0 à 1. */
  value: number;
  notes: string[];
}

export function lineChemistry(line: Player[]): Chemistry {
  const forwards = line.slice(0, 3);
  const defense = line.slice(3, 5);
  const has = (group: Player[], trait: string) => group.some((p) => p.trait === trait);
  const notes: string[] = [];
  let value = 0.55;
  if (has(forwards, 'Sniper') && has(forwards, 'Passeur')) {
    value += 0.17;
    notes.push('Sniper + Passeur : le trio se trouve les yeux fermés');
  }
  if (has(forwards, 'Rapide')) {
    value += 0.08;
    notes.push('Un attaquant rapide étire la défense');
  }
  if (has(defense, 'Mur')) {
    value += 0.1;
    notes.push('Un défenseur « Mur » sécurise la ligne');
  }
  if (line.reduce((sum, p) => sum + p.mental, 0) / line.length >= 68) {
    value += 0.1;
    notes.push('Ligne solide mentalement');
  }
  const misplaced = line.filter((p, slot) => p.role !== slotRole(slot)).length;
  if (misplaced > 0) {
    value -= 0.2 * misplaced;
    notes.unshift(`${misplaced} joueur${misplaced > 1 ? 's' : ''} hors de son poste`);
  }
  if (notes.length === 0) notes.push('Aucune complémentarité particulière');
  return { value: Math.max(0, Math.min(1, value)), notes };
}

/* ------------------------------------------------------------------ */
/* Composition                                                          */
/* ------------------------------------------------------------------ */

export type PlayerRef =
  | { zone: 'line'; line: number; slot: number }
  | { zone: 'bench'; index: number }
  | { zone: 'goalie' }
  | { zone: 'backup' };

export function playerAt(team: Team, ref: PlayerRef): Player {
  switch (ref.zone) {
    case 'line': return team.lines[ref.line][ref.slot];
    case 'bench': return team.bench[ref.index];
    case 'goalie': return team.goalie;
    case 'backup': return team.backupGoalie;
  }
}

const isGoalieRef = (ref: PlayerRef) => ref.zone === 'goalie' || ref.zone === 'backup';

/** Deux places sont échangeables si elles sont toutes deux des places de gardien, ou toutes deux de patineur. */
export const canSwap = (a: PlayerRef, b: PlayerRef) => isGoalieRef(a) === isGoalieRef(b);

/** Échange deux joueurs et renvoie une nouvelle équipe (l'originale n'est pas modifiée). */
export function swapPlayers(team: Team, a: PlayerRef, b: PlayerRef): Team {
  if (!canSwap(a, b)) return team;
  const next: Team = { ...team, lines: team.lines.map((line) => [...line]), bench: [...team.bench] };
  const pa = playerAt(team, a);
  const pb = playerAt(team, b);
  const put = (ref: PlayerRef, p: Player) => {
    if (ref.zone === 'line') next.lines[ref.line][ref.slot] = p;
    else if (ref.zone === 'bench') next.bench[ref.index] = p;
    else if (ref.zone === 'goalie') next.goalie = p;
    else next.backupGoalie = p;
  };
  put(a, pb);
  put(b, pa);
  return next;
}

/** Composition automatique : les meilleurs à leur poste naturel, en ligne 1 d'abord. */
export function autoLineup(team: Team): Team {
  const skaters = [...team.lines.flat(), ...team.bench];
  const byLevel = (slot: number) => (a: Player, b: Player) => rawOverall(b, slot) - rawOverall(a, slot);
  const forwards = skaters.filter((p) => p.role === 'F').sort(byLevel(1));
  const defense = skaters.filter((p) => p.role === 'D').sort(byLevel(3));
  const lines = [0, 1, 2].map((i) => {
    const trio = forwards.slice(i * 3, i * 3 + 3);
    // Le meilleur passeur du trio joue au centre.
    const center = [...trio].sort((a, b) => b.passing - a.passing)[0];
    const wings = trio.filter((p) => p !== center);
    return [wings[0], center, wings[1], ...defense.slice(i * 2, i * 2 + 2)];
  });
  const bench = [...forwards.slice(9), ...defense.slice(6)];
  const [goalie, backupGoalie] = [team.goalie, team.backupGoalie].sort((a, b) => b.goalie - a.goalie);
  return { ...team, lines, bench, goalie, backupGoalie };
}

export const playerLabel = (p: Player) => `#${p.number} ${p.firstName} ${p.lastName}`;
