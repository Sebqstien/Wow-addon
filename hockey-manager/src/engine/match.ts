import { createRng, type Rng } from './rng';
import { playerLabel, type Player, type Team } from './team';

/**
 * Moteur de match. Aucune dépendance à l'affichage : `step` fait avancer la
 * simulation, `simulateMatch` joue un match complet sans rendu.
 *
 * Repère : x en largeur (0..W), y en longueur (0..L). L'équipe 0 (domicile)
 * défend la cage du bas et attaque vers le haut.
 */
export const RINK = {
  W: 85,
  L: 100,
  GY_TOP: 8,
  GY_BOT: 92,
  CX: 42.5,
  NET_HALF: 3.2,
  CORNER: 18,
  BLUE_TOP: 36,
  BLUE_BOT: 64,
} as const;

const { W, L, GY_TOP, GY_BOT, CX, NET_HALF, CORNER } = RINK;

/** Secondes d'horloge de jeu écoulées par seconde réelle : une période dure 60 s. */
const CLOCK_RATE = 20;
const PERIOD_CLOCK = 1200;
const OVERTIME_CLOCK = 300;
const PASS_SPEED = 50;
const SHOT_SPEED = 78;
const BOOST_DURATION = 7;

export type TeamIndex = 0 | 1;
export type Tactic = 'repli' | 'equilibre' | 'pressing';
export type Phase = 'faceoff' | 'play' | 'goal' | 'break' | 'over';

export interface Skater {
  team: TeamIndex;
  /** 0..4 : AG, C, AD, DG, DD. 5 : gardien. */
  slot: number;
  player: Player;
  x: number;
  y: number;
  vx: number;
  vy: number;
  seed: number;
}

export interface Puck {
  x: number;
  y: number;
  vx: number;
  vy: number;
  mode: 'carried' | 'pass' | 'shot' | 'loose';
  carrier: Skater | null;
  target: Skater | null;
  shooter: Skater | null;
  passer: Skater | null;
  assist: Skater | null;
  lastTeam: TeamIndex;
  age: number;
  maxAge: number;
  shotQuality: number;
  shotSkill: number;
}

export interface TeamState {
  team: Team;
  line: number;
  lineTime: number;
  energy: number[];
  tactic: Tactic;
  /** Jauge de boost, de 0 à 1. */
  boost: number;
  /** Secondes de boost restantes. */
  boostActive: number;
  timeoutsLeft: number;
  timeoutQueued: boolean;
  goaliePulled: boolean;
  score: number;
  shots: number;
  cpu: boolean;
}

export interface MatchEvent {
  period: number;
  clock: number;
  team: TeamIndex | null;
  kind: 'goal' | 'shot' | 'save' | 'info';
  text: string;
}

export interface MatchState {
  rng: Rng;
  teams: [TeamState, TeamState];
  skaters: Skater[];
  puck: Puck;
  phase: Phase;
  phaseTimer: number;
  /** 1 à 3, puis 4 pour la prolongation. */
  period: number;
  clock: number;
  t: number;
  looseTime: number;
  immunity: number;
  decisionTimer: number;
  spot: { x: number; y: number };
  events: MatchEvent[];
  winner: TeamIndex | null;
  decidedBy: 'temps' | 'prolongation' | 'tirs au but';
}

const clamp = (v: number, min: number, max: number) => Math.max(min, Math.min(max, v));
const dist = (ax: number, ay: number, bx: number, by: number) => Math.hypot(ax - bx, ay - by);
const other = (t: TeamIndex): TeamIndex => (t === 0 ? 1 : 0);

const ownGoalY = (t: TeamIndex) => (t === 0 ? GY_BOT : GY_TOP);
const oppGoalY = (t: TeamIndex) => (t === 0 ? GY_TOP : GY_BOT);
/** Distance parcourue vers l'avant depuis sa propre ligne de but (0..84). */
const fwdOf = (t: TeamIndex, y: number) => (t === 0 ? GY_BOT - y : y - GY_TOP);
const yOf = (t: TeamIndex, fwd: number) => (t === 0 ? GY_BOT - fwd : GY_TOP + fwd);
const xOf = (t: TeamIndex, lat: number) => (t === 0 ? lat : W - lat);

/** Placement [latéral, avance par rapport au palet] en possession, par poste. */
const OFFENSE = [[16, 6], [42.5, 2], [69, 6], [27, -20], [58, -20], [42.5, -6]];
const DEFENSE = [[20, -4], [42.5, -7], [65, -4], [33, -15], [52, -15], [42.5, -10]];
const FACEOFF = [[-13, -2], [0, -1.5], [13, -2], [-7, -11], [7, -11], [0, -6]];

const energyFactor = (ts: TeamState) => 0.8 + 0.2 * ts.energy[ts.line];
const inNet = (m: MatchState, s: Skater) => s.slot === 5 && !m.teams[s.team].goaliePulled;
const goalieOf = (m: MatchState, t: TeamIndex) => m.skaters.find((s) => s.team === t && s.slot === 5)!;

type SkillKey = 'skating' | 'shooting' | 'passing' | 'physical' | 'defense' | 'mental';
const skill = (m: MatchState, s: Skater, key: SkillKey) => s.player[key] * energyFactor(m.teams[s.team]);

function pushEvent(m: MatchState, team: TeamIndex | null, kind: MatchEvent['kind'], text: string) {
  m.events.push({ period: m.period, clock: Math.max(0, m.clock), team, kind, text });
}

export interface MatchOptions {
  /** L'équipe à domicile est-elle pilotée par l'ordinateur ? */
  cpuHome?: boolean;
}

export function createMatch(home: Team, away: Team, seed: number, options: MatchOptions = {}): MatchState {
  const rng = createRng(seed);
  const teamState = (team: Team, cpu: boolean): TeamState => ({
    team,
    line: 0,
    lineTime: 0,
    energy: [1, 1, 1],
    tactic: 'equilibre',
    boost: 0,
    boostActive: 0,
    timeoutsLeft: 1,
    timeoutQueued: false,
    goaliePulled: false,
    score: 0,
    shots: 0,
    cpu,
  });
  const skaters: Skater[] = [];
  ([0, 1] as TeamIndex[]).forEach((t) => {
    const team = t === 0 ? home : away;
    for (let slot = 0; slot < 6; slot++) {
      skaters.push({
        team: t,
        slot,
        player: slot === 5 ? team.goalie : team.lines[0][slot],
        x: CX,
        y: yOf(t, 20),
        vx: 0,
        vy: 0,
        seed: rng.range(0, 100),
      });
    }
  });
  const m: MatchState = {
    rng,
    teams: [teamState(home, options.cpuHome ?? false), teamState(away, true)],
    skaters,
    puck: {
      x: CX, y: L / 2, vx: 0, vy: 0, mode: 'loose', carrier: null, target: null, shooter: null,
      passer: null, assist: null, lastTeam: 0, age: 0, maxAge: 0, shotQuality: 0, shotSkill: 0,
    },
    phase: 'faceoff',
    phaseTimer: 0,
    period: 1,
    clock: PERIOD_CLOCK,
    t: 0,
    looseTime: 0,
    immunity: 0,
    decisionTimer: 0,
    spot: { x: CX, y: L / 2 },
    events: [],
    winner: null,
    decidedBy: 'temps',
  };
  setupFaceoff(m, CX, L / 2, 1.6);
  for (const s of m.skaters) {
    const p = faceoffPosition(m, s);
    s.x = p.x;
    s.y = p.y;
  }
  return m;
}

/* ------------------------------------------------------------------ */
/* Actions du joueur                                                    */
/* ------------------------------------------------------------------ */

export function setLine(m: MatchState, t: TeamIndex, line: number) {
  const ts = m.teams[t];
  if (ts.line === line || m.phase === 'over') return;
  ts.line = line;
  ts.lineTime = 0;
  for (const s of m.skaters) {
    if (s.team === t && s.slot < 5) s.player = ts.team.lines[line][s.slot];
  }
}

export function setTactic(m: MatchState, t: TeamIndex, tactic: Tactic) {
  m.teams[t].tactic = tactic;
}

export function activateBoost(m: MatchState, t: TeamIndex): boolean {
  const ts = m.teams[t];
  if (ts.boost < 1 || ts.boostActive > 0 || m.phase === 'over') return false;
  ts.boost = 0;
  ts.boostActive = BOOST_DURATION;
  pushEvent(m, t, 'info', `Boost activé pour ${ts.team.short}`);
  return true;
}

/** Le temps mort est pris au prochain arrêt de jeu. */
export function requestTimeout(m: MatchState, t: TeamIndex): boolean {
  const ts = m.teams[t];
  if (ts.timeoutsLeft <= 0 || ts.timeoutQueued || m.phase === 'over') return false;
  ts.timeoutQueued = true;
  return true;
}

export function setGoaliePulled(m: MatchState, t: TeamIndex, pulled: boolean) {
  const ts = m.teams[t];
  if (ts.goaliePulled === pulled || m.phase === 'over') return;
  ts.goaliePulled = pulled;
  pushEvent(m, t, 'info', pulled ? `${ts.team.short} sort son gardien` : `Le gardien de ${ts.team.short} revient`);
}

/* ------------------------------------------------------------------ */
/* Arrêts de jeu                                                        */
/* ------------------------------------------------------------------ */

function setupFaceoff(m: MatchState, x: number, y: number, delay: number) {
  m.phase = 'faceoff';
  m.phaseTimer = delay;
  m.spot = { x, y };
  const p = m.puck;
  p.x = x;
  p.y = y;
  p.vx = 0;
  p.vy = 0;
  p.mode = 'loose';
  p.carrier = p.target = p.shooter = p.passer = p.assist = null;
  m.looseTime = 0;
  for (const t of [0, 1] as TeamIndex[]) {
    const ts = m.teams[t];
    if (ts.timeoutQueued && ts.timeoutsLeft > 0) {
      ts.timeoutQueued = false;
      ts.timeoutsLeft--;
      ts.energy = [1, 1, 1];
      m.phaseTimer += 1.5;
      pushEvent(m, t, 'info', `Temps mort ${ts.team.short} : les lignes récupèrent`);
    }
  }
}

function faceoffPosition(m: MatchState, s: Skater) {
  if (inNet(m, s)) return { x: CX, y: yOf(s.team, 1.5) };
  const [lat, fwd] = FACEOFF[s.slot];
  const sign = s.team === 0 ? 1 : -1;
  return {
    x: clamp(m.spot.x + sign * lat, 3, W - 3),
    y: clamp(m.spot.y + (s.team === 0 ? -fwd : fwd), 3, L - 3),
  };
}

function dropPuck(m: MatchState) {
  const centers = [0, 1].map((t) => m.skaters.find((s) => s.team === t && s.slot === 1)!);
  const rating = (s: Skater) => skill(m, s, 'mental') + skill(m, s, 'physical') + m.rng.range(0, 60);
  const winner: TeamIndex = rating(centers[0]) >= rating(centers[1]) ? 0 : 1;
  const slot = m.rng.chance(0.5) ? 3 : 4;
  const target = m.skaters.find((s) => s.team === winner && s.slot === slot)!;
  const p = m.puck;
  const d = Math.max(1, dist(p.x, p.y, target.x, target.y));
  p.vx = ((target.x - p.x) / d) * 34;
  p.vy = ((target.y - p.y) / d) * 34;
  p.mode = 'pass';
  p.target = target;
  p.passer = null;
  p.assist = null;
  p.lastTeam = winner;
  p.age = 0;
  p.maxAge = d / 34 + 0.8;
  m.phase = 'play';
}

function endZoneSpot(puckX: number, goalY: number) {
  return { x: puckX < CX ? 22 : 63, y: goalY === GY_TOP ? 22 : 78 };
}

function endPeriod(m: MatchState) {
  const [a, b] = m.teams;
  if (m.period < 3) {
    pushEvent(m, null, 'info', `Fin de la période ${m.period}`);
    m.period++;
    m.clock = PERIOD_CLOCK;
    m.phase = 'break';
    m.phaseTimer = 1.6;
    return;
  }
  if (a.score !== b.score) return finish(m, a.score > b.score ? 0 : 1, m.period === 3 ? 'temps' : 'prolongation');
  if (m.period === 3) {
    pushEvent(m, null, 'info', 'Égalité : prolongation en mort subite');
    m.period = 4;
    m.clock = OVERTIME_CLOCK;
    m.phase = 'break';
    m.phaseTimer = 1.6;
    return;
  }
  shootout(m);
}

function shootout(m: MatchState) {
  pushEvent(m, null, 'info', 'Séance de tirs au but');
  const made = [0, 0];
  const attempt = (t: TeamIndex, round: number) => {
    const line = m.teams[t].team.lines[round % 3];
    const shooter = line[round % 3];
    const keeper = m.teams[other(t)].team.goalie;
    if (m.rng.chance(clamp(0.32 + (shooter.shooting - keeper.goalie) / 250, 0.1, 0.6))) {
      made[t]++;
      pushEvent(m, t, 'info', `Tir au but réussi : ${playerLabel(shooter)}`);
    }
  };
  for (let round = 0; round < 3 || made[0] === made[1]; round++) {
    attempt(0, round);
    attempt(1, round);
    if (round > 40) made[m.rng.chance(0.5) ? 0 : 1]++;
  }
  const winner: TeamIndex = made[0] > made[1] ? 0 : 1;
  m.teams[winner].score++;
  finish(m, winner, 'tirs au but');
}

function finish(m: MatchState, winner: TeamIndex, decidedBy: MatchState['decidedBy']) {
  m.winner = winner;
  m.decidedBy = decidedBy;
  m.phase = 'over';
  m.clock = 0;
  pushEvent(m, winner, 'info', `Victoire de ${m.teams[winner].team.name}`);
}

/* ------------------------------------------------------------------ */
/* Palet                                                                */
/* ------------------------------------------------------------------ */

function giveTo(m: MatchState, s: Skater, viaPass: boolean) {
  const p = m.puck;
  const sameTeam = p.lastTeam === s.team;
  p.assist = viaPass && sameTeam && p.passer !== s ? p.passer : sameTeam ? p.assist : null;
  p.mode = 'carried';
  p.carrier = s;
  p.target = p.shooter = p.passer = null;
  p.lastTeam = s.team;
  p.vx = 0;
  p.vy = 0;
  m.immunity = 0.4;
  m.decisionTimer = 0.25;
  m.looseTime = 0;
}

function makeLoose(m: MatchState, vx: number, vy: number) {
  const p = m.puck;
  p.mode = 'loose';
  p.carrier = p.target = p.shooter = null;
  p.vx = vx;
  p.vy = vy;
  m.looseTime = 0;
}

function constrain(o: { x: number; y: number; vx: number; vy: number }, bounce: number, margin: number) {
  if (o.x < margin) { o.x = margin; o.vx = Math.abs(o.vx) * bounce; }
  if (o.x > W - margin) { o.x = W - margin; o.vx = -Math.abs(o.vx) * bounce; }
  if (o.y < margin) { o.y = margin; o.vy = Math.abs(o.vy) * bounce; }
  if (o.y > L - margin) { o.y = L - margin; o.vy = -Math.abs(o.vy) * bounce; }
  // Coins arrondis : on ramène l'objet sur l'arc et on renvoie sa vitesse vers l'intérieur.
  const cx = o.x < CORNER ? CORNER : o.x > W - CORNER ? W - CORNER : null;
  const cy = o.y < CORNER ? CORNER : o.y > L - CORNER ? L - CORNER : null;
  if (cx === null || cy === null) return;
  const dx = o.x - cx;
  const dy = o.y - cy;
  const d = Math.hypot(dx, dy);
  const r = CORNER - margin;
  if (d <= r) return;
  const nx = dx / d;
  const ny = dy / d;
  o.x = cx + nx * r;
  o.y = cy + ny * r;
  const dot = o.vx * nx + o.vy * ny;
  if (dot > 0) {
    o.vx -= (1 + bounce) * dot * nx;
    o.vy -= (1 + bounce) * dot * ny;
  }
}

function shoot(m: MatchState, c: Skater) {
  const p = m.puck;
  const gy = oppGoalY(c.team);
  const d = Math.max(1, dist(c.x, c.y, CX, gy));
  const sh = skill(m, c, 'shooting');
  const spread = d * 0.085 * (1.4 - (0.6 * sh) / 100);
  const aimX = CX + m.rng.gauss() * spread + m.rng.range(-1.2, 1.2);
  const angle = Math.abs(c.x - CX) / d;
  p.shotQuality = clamp(1 - d / 40, 0.08, 1) * (1 - 0.55 * angle);
  p.shotSkill = sh;
  const dx = aimX - p.x;
  const dy = gy - p.y;
  const n = Math.max(0.01, Math.hypot(dx, dy));
  p.vx = (dx / n) * SHOT_SPEED;
  p.vy = (dy / n) * SHOT_SPEED;
  p.mode = 'shot';
  p.shooter = c;
  p.carrier = null;
  p.age = 0;
}

function pass(m: MatchState, c: Skater, mate: Skater) {
  const p = m.puck;
  const d = dist(c.x, c.y, mate.x, mate.y);
  const lead = d / PASS_SPEED;
  const error = (1.3 - skill(m, c, 'passing') / 100) * 2.2;
  const tx = mate.x + mate.vx * lead * 0.8 + m.rng.gauss() * error;
  const ty = mate.y + mate.vy * lead * 0.8 + m.rng.gauss() * error;
  const n = Math.max(0.01, dist(p.x, p.y, tx, ty));
  p.vx = ((tx - p.x) / n) * PASS_SPEED;
  p.vy = ((ty - p.y) / n) * PASS_SPEED;
  p.mode = 'pass';
  p.target = mate;
  p.passer = c;
  p.carrier = null;
  p.age = 0;
  p.maxAge = (n / PASS_SPEED) * 1.5 + 0.35;
}

function laneBlocked(m: MatchState, a: Skater, b: Skater): boolean {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len2 = dx * dx + dy * dy || 1;
  return m.skaters.some((o) => {
    if (o.team === a.team || inNet(m, o)) return false;
    const k = clamp(((o.x - a.x) * dx + (o.y - a.y) * dy) / len2, 0, 1);
    return k > 0.1 && dist(o.x, o.y, a.x + dx * k, a.y + dy * k) < 2.6;
  });
}

function nearestOpponent(m: MatchState, s: Skater): number {
  let best = Infinity;
  for (const o of m.skaters) {
    if (o.team !== s.team && !inNet(m, o)) best = Math.min(best, dist(o.x, o.y, s.x, s.y));
  }
  return best;
}

/** Décision du porteur du palet : tirer, passer ou continuer. */
function decide(m: MatchState, c: Skater) {
  const ts = m.teams[c.team];
  const fwd = fwdOf(c.team, c.y);
  const d = dist(c.x, c.y, CX, oppGoalY(c.team));
  const pressure = nearestOpponent(m, c);

  if (fwd < 82.5 && d < 34) {
    let pShot = d < 13 ? 0.6 : d < 22 ? 0.36 : 0.2;
    if (pressure < 4) pShot *= 1.3;
    if (ts.boostActive > 0) pShot *= 1.25;
    if (m.rng.chance(pShot)) return shoot(m, c);
  }

  const pPass = 0.035 + (pressure < 5 ? 0.2 : 0) + (fwd < 28 ? 0.04 : 0);
  if (!m.rng.chance(pPass)) return;
  let best: Skater | null = null;
  let bestScore = 5;
  for (const mate of m.skaters) {
    if (mate.team !== c.team || mate === c || inNet(m, mate)) continue;
    const dm = dist(c.x, c.y, mate.x, mate.y);
    if (dm < 8 || dm > 50) continue;
    const score =
      (fwdOf(c.team, mate.y) - fwd) * 0.8 +
      Math.min(nearestOpponent(m, mate), 12) * 1.5 -
      (laneBlocked(m, c, mate) ? 14 : 0) +
      m.rng.range(0, 6);
    if (score > bestScore) {
      bestScore = score;
      best = mate;
    }
  }
  if (best) pass(m, c, best);
}

function resolveShotOnGoal(m: MatchState) {
  const p = m.puck;
  const shooter = p.shooter!;
  const t = shooter.team;
  const attack = m.teams[t];
  const defend = m.teams[other(t)];
  const keeper = goalieOf(m, other(t));
  attack.shots++;
  attack.boost = Math.min(1, attack.boost + 0.05);

  let pGoal = (0.03 + 0.24 * p.shotQuality) * (1 + (p.shotSkill - 70) / 90) * (1 - (keeper.player.goalie - 70) / 70);
  if (attack.boostActive > 0) pGoal *= 1.3;
  if (defend.goaliePulled) pGoal = 0.97;

  if (m.rng.chance(clamp(pGoal, 0.01, 0.97))) {
    attack.score++;
    const assist = p.assist && p.assist !== shooter ? ` (passe de ${playerLabel(p.assist.player)})` : '';
    pushEvent(m, t, 'goal', `BUT de ${playerLabel(shooter.player)}${assist}`);
    m.phase = 'goal';
    m.phaseTimer = 1.9;
    p.vx = 0;
    p.vy = 0;
    p.x = clamp(p.x, CX - NET_HALF, CX + NET_HALF);
    p.y = oppGoalY(t) + (t === 0 ? -1.5 : 1.5);
    p.mode = 'loose';
    p.carrier = p.target = null;
    return;
  }

  pushEvent(m, other(t), 'save', `Arrêt de ${playerLabel(keeper.player)}`);
  const gy = oppGoalY(t);
  if (m.rng.chance(0.5)) {
    const spot = endZoneSpot(p.x, gy);
    return setupFaceoff(m, spot.x, spot.y, 1.2);
  }
  p.y = gy + (t === 0 ? 1.5 : -1.5);
  p.lastTeam = other(t);
  makeLoose(m, m.rng.range(-26, 26), (t === 0 ? 1 : -1) * m.rng.range(14, 34));
}

function updatePuck(m: MatchState, dt: number) {
  const p = m.puck;
  if (p.mode === 'carried') {
    const c = p.carrier!;
    p.x = c.x;
    p.y = c.y + (c.team === 0 ? -1.3 : 1.3);
    m.decisionTimer -= dt;
    if (m.decisionTimer <= 0) {
      m.decisionTimer = 0.3;
      decide(m, c);
    }
    return;
  }

  const prevY = p.y;
  const prevX = p.x;
  p.x += p.vx * dt;
  p.y += p.vy * dt;
  p.age += dt;

  if (p.mode === 'shot') {
    const shooter = p.shooter!;
    const gy = oppGoalY(shooter.team);
    if ((prevY - gy) * (p.y - gy) <= 0 && prevY !== p.y) {
      const k = (gy - prevY) / (p.y - prevY);
      const crossX = prevX + (p.x - prevX) * k;
      if (Math.abs(crossX - CX) <= NET_HALF) {
        p.x = crossX;
        return resolveShotOnGoal(m);
      }
      p.lastTeam = shooter.team;
      makeLoose(m, p.vx * 0.6, p.vy * 0.6);
      return;
    }
    if (p.age > 0.08) {
      for (const o of m.skaters) {
        if (o.team === shooter.team || inNet(m, o)) continue;
        if (dist(o.x, o.y, p.x, p.y) < 1.6 && m.rng.chance(dt * 4)) {
          makeLoose(m, m.rng.range(-20, 20), m.rng.range(-20, 20));
          return;
        }
      }
    }
    return;
  }

  if (p.mode === 'pass') {
    const target = p.target!;
    if (dist(target.x, target.y, p.x, p.y) < 2.4) return giveTo(m, target, true);
    if (p.age > 0.12) {
      for (const o of m.skaters) {
        if (o.team === target.team || inNet(m, o)) continue;
        if (dist(o.x, o.y, p.x, p.y) < 1.8 && m.rng.chance((dt * 5 * skill(m, o, 'defense')) / 100)) {
          return giveTo(m, o, false);
        }
      }
    }
    if (p.age > p.maxAge) makeLoose(m, p.vx * 0.7, p.vy * 0.7);
    constrain(p, 0.6, 1);
    return;
  }

  // Palet libre.
  const friction = Math.max(0, 1 - 0.9 * dt);
  p.vx *= friction;
  p.vy *= friction;
  constrain(p, 0.65, 1);
  m.looseTime += dt;

  let nearest: Skater | null = null;
  let nearestD = 2.3;
  for (const s of m.skaters) {
    const d = dist(s.x, s.y, p.x, p.y);
    if (inNet(m, s)) {
      if (d < 3.4 && Math.hypot(p.vx, p.vy) < 26 && m.looseTime > 0.25) {
        const spot = endZoneSpot(p.x, ownGoalY(s.team));
        pushEvent(m, s.team, 'info', `${playerLabel(s.player)} bloque le palet`);
        return setupFaceoff(m, spot.x, spot.y, 1.2);
      }
      continue;
    }
    if (d < nearestD) {
      nearestD = d;
      nearest = s;
    }
  }
  if (nearest) return giveTo(m, nearest, false);
  if (m.looseTime > 7) setupFaceoff(m, p.x < CX ? 22 : 63, clamp(p.y, 22, 78), 1.1);
}

/* ------------------------------------------------------------------ */
/* Patineurs                                                            */
/* ------------------------------------------------------------------ */

function anchor(m: MatchState, s: Skater, mode: 'off' | 'def' | 'neutral') {
  const ts = m.teams[s.team];
  const pf = fwdOf(s.team, m.puck.y);
  const puckLat = s.team === 0 ? m.puck.x : W - m.puck.x;
  const shift = ts.tactic === 'pressing' ? 5 : ts.tactic === 'repli' ? -5 : 0;
  let lat: number;
  let fwd: number;
  if (mode === 'off') {
    const [baseLat, baseFwd] = OFFENSE[s.slot];
    lat = baseLat + (puckLat - CX) * 0.25;
    fwd = clamp(pf + baseFwd + shift * 0.6, 8, s.slot === 3 || s.slot === 4 ? 56 : 78);
  } else {
    const [baseLat, baseFwd] = DEFENSE[s.slot];
    lat = baseLat + (puckLat - CX) * 0.35;
    fwd = clamp(pf + baseFwd + shift + (mode === 'neutral' ? 5 : 0), 5, 70);
  }
  lat += Math.sin(m.t * 0.9 + s.seed) * 3;
  fwd += Math.cos(m.t * 0.7 + s.seed * 1.7) * 2.5;
  return { x: clamp(xOf(s.team, lat), 3, W - 3), y: clamp(yOf(s.team, fwd), 3, L - 3) };
}

function moveToward(m: MatchState, s: Skater, tx: number, ty: number, dt: number, mul: number) {
  const ts = m.teams[s.team];
  const max = (13 + s.player.skating * 0.09) * energyFactor(ts) * (ts.boostActive > 0 ? 1.18 : 1) * mul;
  const dx = tx - s.x;
  const dy = ty - s.y;
  const d = Math.hypot(dx, dy);
  const speed = Math.min(max, d * 4);
  const k = Math.min(1, 7 * dt);
  s.vx += ((d > 0.01 ? (dx / d) * speed : 0) - s.vx) * k;
  s.vy += ((d > 0.01 ? (dy / d) * speed : 0) - s.vy) * k;
  s.x += s.vx * dt;
  s.y += s.vy * dt;
  constrain(s, 0, 2);
}

function carrierTarget(m: MatchState, c: Skater) {
  const fwd = fwdOf(c.team, c.y);
  if (fwd >= 58) {
    const side = c.x < CX ? -1 : 1;
    return { x: CX + side * 5, y: yOf(c.team, 76) };
  }
  let x = c.x + Math.sin(m.t * 1.3 + c.seed) * 10;
  // Évite le défenseur le plus proche situé devant lui.
  for (const o of m.skaters) {
    if (o.team === c.team || inNet(m, o)) continue;
    if (fwdOf(c.team, o.y) > fwd && dist(o.x, o.y, c.x, c.y) < 7) x += o.x < c.x ? 9 : -9;
  }
  return { x: clamp(x, 8, W - 8), y: yOf(c.team, fwd + 18) };
}

function nearestSkaters(m: MatchState, t: TeamIndex, x: number, y: number, count: number): Skater[] {
  return m.skaters
    .filter((s) => s.team === t && !inNet(m, s))
    .sort((a, b) => dist(a.x, a.y, x, y) - dist(b.x, b.y, x, y))
    .slice(0, count);
}

function updateSkaters(m: MatchState, dt: number) {
  const p = m.puck;
  const owner: TeamIndex | null =
    p.mode === 'carried' ? p.carrier!.team : p.mode === 'pass' ? p.target!.team : null;
  const chasers = new Set<Skater>();
  for (const t of [0, 1] as TeamIndex[]) {
    if (owner === t) continue;
    const count = m.teams[t].tactic === 'pressing' ? 2 : 1;
    nearestSkaters(m, t, p.x, p.y, count).forEach((s) => chasers.add(s));
  }

  for (const s of m.skaters) {
    if (inNet(m, s)) {
      const gx = clamp(p.x, CX - 2.8, CX + 2.8);
      moveToward(m, s, gx, yOf(s.team, 1.5), dt, 1.5);
      continue;
    }
    if (p.carrier === s) {
      const target = carrierTarget(m, s);
      moveToward(m, s, target.x, target.y, dt, 0.92);
      continue;
    }
    if (p.mode === 'pass' && p.target === s) {
      moveToward(m, s, p.x, p.y, dt, 1);
      continue;
    }
    if (chasers.has(s)) {
      moveToward(m, s, p.x + p.vx * 0.25, p.y + p.vy * 0.25, dt, 1.04);
      continue;
    }
    const mode = owner === s.team ? 'off' : owner === null ? (p.mode === 'shot' && p.lastTeam === s.team ? 'off' : 'neutral') : 'def';
    const a = anchor(m, s, mode);
    moveToward(m, s, a.x, a.y, dt, 0.9);
  }

  // Les patineurs ne se superposent pas.
  for (let i = 0; i < m.skaters.length; i++) {
    for (let j = i + 1; j < m.skaters.length; j++) {
      const a = m.skaters[i];
      const b = m.skaters[j];
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const d = Math.hypot(dx, dy);
      if (d > 0.01 && d < 2.6) {
        const push = ((2.6 - d) / 2) * 0.5;
        a.x -= (dx / d) * push;
        a.y -= (dy / d) * push;
        b.x += (dx / d) * push;
        b.y += (dy / d) * push;
      }
    }
  }

  // Mises en échec : un défenseur proche peut récupérer le palet.
  const c = p.carrier;
  if (p.mode !== 'carried' || !c || m.immunity > 0) return;
  for (const o of m.skaters) {
    if (o.team === c.team || inNet(m, o) || dist(o.x, o.y, c.x, c.y) > 3) continue;
    const tactic = m.teams[o.team].tactic;
    const attack = skill(m, o, 'defense') * 0.6 + skill(m, o, 'physical') * 0.4;
    const hold = skill(m, c, 'skating') * 0.4 + skill(m, c, 'physical') * 0.3 + skill(m, c, 'passing') * 0.3;
    const mul = tactic === 'pressing' ? 1.3 : tactic === 'repli' ? 0.85 : 1;
    if (m.rng.chance(dt * 0.95 * (attack / hold) * mul)) {
      if (m.rng.chance(0.6)) giveTo(m, o, false);
      else makeLoose(m, m.rng.range(-18, 18), m.rng.range(-18, 18));
      return;
    }
  }
}

/* ------------------------------------------------------------------ */
/* Gestion des équipes                                                  */
/* ------------------------------------------------------------------ */

function freshestLine(ts: TeamState): number {
  let best = ts.line;
  ts.energy.forEach((e, i) => { if (e > ts.energy[best]) best = i; });
  return best;
}

function updateTeams(m: MatchState, dt: number) {
  for (const t of [0, 1] as TeamIndex[]) {
    const ts = m.teams[t];
    if (m.phase === 'play') {
      ts.lineTime += dt;
      const drain = (ts.tactic === 'pressing' ? 1.35 : ts.tactic === 'repli' ? 0.9 : 1) * (ts.boostActive > 0 ? 1.2 : 1);
      ts.energy = ts.energy.map((e, i) => clamp(i === ts.line ? e - (dt * drain) / 34 : e + dt / 42, 0, 1));
      if (ts.boostActive > 0) ts.boostActive = Math.max(0, ts.boostActive - dt);
      else ts.boost = Math.min(1, ts.boost + dt / 38);
    }
    if (!ts.cpu) {
      // Filet de sécurité : une ligne épuisée sort d'elle-même.
      if (ts.energy[ts.line] < 0.1) setLine(m, t, freshestLine(ts));
      continue;
    }

    // Ordinateur : rotation des lignes et tactique selon le score.
    if (ts.energy[ts.line] < 0.45 && ts.lineTime > 5) {
      setLine(m, t, freshestLine(ts));
    }
    const diff = ts.score - m.teams[other(t)].score;
    const late = m.period === 3 && m.clock < 400;
    setTactic(m, t, diff < 0 && late ? 'pressing' : diff >= 2 ? 'repli' : 'equilibre');
    const desperate = m.period === 3 && m.clock < 90 && (diff === -1 || diff === -2);
    if (ts.goaliePulled !== desperate) setGoaliePulled(m, t, desperate);
    if (ts.boost >= 1 && m.puck.mode === 'carried' && m.puck.carrier!.team === t && fwdOf(t, m.puck.y) > 50) {
      activateBoost(m, t);
    }
  }
}

/* ------------------------------------------------------------------ */
/* Boucle principale                                                    */
/* ------------------------------------------------------------------ */

export function step(m: MatchState, dt: number) {
  if (m.phase === 'over') return;
  m.t += dt;
  m.immunity = Math.max(0, m.immunity - dt);
  updateTeams(m, dt);

  if (m.phase === 'faceoff') {
    for (const s of m.skaters) {
      const pos = faceoffPosition(m, s);
      moveToward(m, s, pos.x, pos.y, dt, 1.7);
    }
    m.phaseTimer -= dt;
    if (m.phaseTimer <= 0) dropPuck(m);
    return;
  }

  if (m.phase === 'goal' || m.phase === 'break') {
    for (const s of m.skaters) moveToward(m, s, s.x, s.y, dt, 1);
    m.phaseTimer -= dt;
    if (m.phaseTimer > 0) return;
    if (m.phase === 'goal' && m.period === 4) {
      const [a, b] = m.teams;
      return finish(m, a.score > b.score ? 0 : 1, 'prolongation');
    }
    return setupFaceoff(m, CX, L / 2, 1.2);
  }

  m.clock -= dt * CLOCK_RATE;
  updatePuck(m, dt);
  if (m.phase !== 'play') return;
  updateSkaters(m, dt);
  if (m.clock <= 0) {
    m.clock = 0;
    endPeriod(m);
  }
}

/** Joue un match complet sans affichage (tests, et plus tard les autres matchs de la ligue). */
export function simulateMatch(home: Team, away: Team, seed: number): MatchState {
  const m = createMatch(home, away, seed, { cpuHome: true });
  for (let i = 0; i < 200000 && m.phase !== 'over'; i++) step(m, 1 / 30);
  return m;
}

export function formatClock(clock: number): string {
  const s = Math.max(0, Math.ceil(clock));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export const periodLabel = (period: number) => (period === 4 ? 'PR' : `P${period}`);
