import { useMemo, useState } from 'react';
import { createRng } from '../engine/rng';
import { CLUBS, generateTeam, overall, type Team } from '../engine/team';
import type { MatchState } from '../engine/match';
import { MatchScreen } from './MatchScreen';

type Screen = 'pre' | 'match' | 'post';

function teamRating(team: Team): number {
  const all = team.lines.flatMap((line) => line.map((p, slot) => overall(p, slot)));
  return Math.round(all.reduce((a, b) => a + b, 0) / all.length);
}

function TeamBlock({ team, note }: { team: Team; note: string }) {
  return (
    <div className="team-block">
      <div className="crest crest-lg" style={{ background: team.color }} />
      <div className="team-name">{team.short}</div>
      <div className="muted small">{note}</div>
    </div>
  );
}

export function App() {
  const [seed, setSeed] = useState(() => Math.floor(Math.random() * 1e9));
  const [screen, setScreen] = useState<Screen>('pre');
  const [result, setResult] = useState<MatchState | null>(null);

  const [home, away] = useMemo(() => {
    const rng = createRng(seed);
    const opponent = CLUBS[1 + (seed % (CLUBS.length - 1))];
    return [generateTeam(rng, CLUBS[0], 68, 0), generateTeam(rng, opponent, 68, 100)];
  }, [seed]);

  if (screen === 'match') {
    return (
      <MatchScreen
        key={seed}
        home={home}
        away={away}
        seed={seed}
        onFinish={(m) => {
          setResult(m);
          setScreen('post');
        }}
      />
    );
  }

  if (screen === 'post' && result) {
    const [a, b] = result.teams;
    const won = result.winner === 0;
    const goals = result.events.filter((e) => e.kind === 'goal');
    return (
      <main className="screen">
        <div className="eyebrow">MATCH TERMINÉ</div>
        <h1 className={won ? 'title win' : 'title'}>{won ? 'VICTOIRE' : 'DÉFAITE'}</h1>
        <section className="card">
          <div className="versus">
            <TeamBlock team={a.team} note={`${a.shots} tirs cadrés`} />
            <div className="final-score">
              {a.score}
              <span>:</span>
              {b.score}
            </div>
            <TeamBlock team={b.team} note={`${b.shots} tirs cadrés`} />
          </div>
          {result.decidedBy !== 'temps' && <div className="muted small center">Décidé en {result.decidedBy}</div>}
        </section>
        <section className="card list">
          <div className="eyebrow">BUTS</div>
          {goals.length === 0 && <div className="muted small">Aucun but dans le temps de jeu.</div>}
          {goals.map((e, i) => (
            <div className="row" key={i}>
              <span className="dot" style={{ background: result.teams[e.team!].team.color }} />
              <span className="row-text">{e.text.replace('BUT de ', '')}</span>
              <span className="muted small">{e.period === 4 ? 'PR' : `P${e.period}`}</span>
            </div>
          ))}
        </section>
        <button
          className="btn-primary"
          onClick={() => {
            setSeed(Math.floor(Math.random() * 1e9));
            setScreen('pre');
          }}
        >
          NOUVEAU MATCH
        </button>
      </main>
    );
  }

  return (
    <main className="screen">
      <div className="eyebrow">MATCH AMICAL</div>
      <h1 className="title">HOCKEY MANAGER</h1>
      <section className="card">
        <div className="versus">
          <TeamBlock team={home} note={`Niveau ${teamRating(home)}`} />
          <div className="vs">VS</div>
          <TeamBlock team={away} note={`Niveau ${teamRating(away)}`} />
        </div>
      </section>
      <section className="card list">
        <div className="eyebrow">VOTRE LIGNE 1</div>
        {home.lines[0].map((p, slot) => (
          <div className="row" key={p.id}>
            <span className="rating">{overall(p, slot)}</span>
            <span className="row-text">
              {p.firstName} {p.lastName}
            </span>
            <span className="muted small">{p.trait}</span>
          </div>
        ))}
      </section>
      <p className="muted small help">
        Pendant le match : changez de ligne quand l'énergie baisse, ajustez la tactique et déclenchez le boost quand la
        jauge est pleine.
      </p>
      <button className="btn-primary" onClick={() => setScreen('match')}>
        COUP D'ENVOI
      </button>
    </main>
  );
}
