import { describe, expect, it } from 'vitest';
import { createRng } from './rng';
import { simulateMatch } from './match';
import { CLUBS, autoLineup, generateTeam, lineChemistry, overall, swapPlayers } from './team';

function teams(seed: number) {
  const rng = createRng(seed);
  return [generateTeam(rng, CLUBS[0], 68, 0), generateTeam(rng, CLUBS[1], 68, 100)] as const;
}

describe('moteur de match', () => {
  it('rejoue exactement le même match avec la même graine', () => {
    const [home, away] = teams(1);
    const a = simulateMatch(home, away, 42);
    const b = simulateMatch(home, away, 42);
    expect(a.teams.map((t) => t.score)).toEqual(b.teams.map((t) => t.score));
    expect(a.events.length).toBe(b.events.length);
  });

  it('produit des matchs terminés avec des scores et des tirs plausibles', () => {
    const N = 60;
    let goals = 0;
    let shots = 0;
    let overtime = 0;
    for (let i = 0; i < N; i++) {
      const [home, away] = teams(i + 1);
      const m = simulateMatch(home, away, 1000 + i);
      expect(m.phase).toBe('over');
      expect(m.winner).not.toBeNull();
      expect(m.teams[0].score).not.toBe(m.teams[1].score);
      for (const s of m.skaters) expect(Number.isFinite(s.x + s.y)).toBe(true);
      goals += m.teams[0].score + m.teams[1].score;
      shots += m.teams[0].shots + m.teams[1].shots;
      if (m.decidedBy !== 'temps') overtime++;
    }
    console.log(`moyennes sur ${N} matchs : ${(goals / N).toFixed(1)} buts, ${(shots / N).toFixed(1)} tirs cadrés, ${overtime} prolongations`);
    expect(goals / N).toBeGreaterThan(3.5);
    expect(goals / N).toBeLessThan(8.5);
    expect(shots / N).toBeGreaterThan(25);
    expect(shots / N).toBeLessThan(75);
  });

  it('échange deux joueurs sans modifier l\'équipe d\'origine', () => {
    const [home] = teams(3);
    const a = home.lines[0][1];
    const b = home.bench[0];
    const next = swapPlayers(home, { zone: 'line', line: 0, slot: 1 }, { zone: 'bench', index: 0 });
    expect(next.lines[0][1]).toBe(b);
    expect(next.bench[0]).toBe(a);
    expect(home.lines[0][1]).toBe(a);
    // Un gardien ne s'échange pas avec un patineur.
    expect(swapPlayers(home, { zone: 'goalie' }, { zone: 'bench', index: 0 })).toBe(home);
  });

  it('pénalise un joueur hors de son poste', () => {
    const [home] = teams(4);
    const forward = home.lines[0][0];
    expect(overall(forward, 3)).toBeLessThan(overall(forward, 0) + 20);
    const mixed = swapPlayers(home, { zone: 'line', line: 0, slot: 0 }, { zone: 'line', line: 0, slot: 3 });
    expect(lineChemistry(mixed.lines[0]).value).toBeLessThan(lineChemistry(home.lines[0]).value);
  });

  it('la composition automatique garde 15 patineurs à leur poste et la ligne 1 la plus forte', () => {
    const [home] = teams(5);
    const auto = autoLineup(home);
    const ids = [...auto.lines.flat(), ...auto.bench].map((p) => p.id);
    expect(new Set(ids).size).toBe(19);
    auto.lines.forEach((line) => line.forEach((p, slot) => expect(p.role).toBe(slot <= 2 ? 'F' : 'D')));
    const level = (line: typeof auto.lines[0]) => line.reduce((sum, p, slot) => sum + overall(p, slot), 0);
    expect(level(auto.lines[0])).toBeGreaterThanOrEqual(level(auto.lines[2]));
  });
});
