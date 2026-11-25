import { describe, expect, it } from 'vitest';
import { createRng } from './rng';
import { simulateMatch } from './match';
import { CLUBS, generateTeam } from './team';

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
});
