import { useEffect, useRef, useState } from 'react';
import {
  RINK,
  activateBoost,
  createMatch,
  formatClock,
  periodLabel,
  requestTimeout,
  setGoaliePulled,
  setLine,
  setTactic,
  step,
  type MatchState,
  type Tactic,
} from '../engine/match';
import type { Team } from '../engine/team';
import { drawRink, type TrailPoint } from './drawRink';

const TACTICS: { id: Tactic; label: string }[] = [
  { id: 'repli', label: 'Repli' },
  { id: 'equilibre', label: 'Équilibré' },
  { id: 'pressing', label: 'Pressing' },
];

interface Props {
  home: Team;
  away: Team;
  seed: number;
  onFinish: (m: MatchState) => void;
}

export function MatchScreen({ home, away, seed, onFinish }: Props) {
  const matchRef = useRef<MatchState>();
  if (!matchRef.current) matchRef.current = createMatch(home, away, seed);
  const m = matchRef.current;

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const pausedRef = useRef(false);
  const speedRef = useRef(1);
  const [, setTick] = useState(0);
  const [paused, setPaused] = useState(false);
  const [speed, setSpeed] = useState(1);
  const refresh = () => setTick((n) => n + 1);

  useEffect(() => {
    const canvas = canvasRef.current!;
    const wrap = wrapRef.current!;
    const ctx = canvas.getContext('2d')!;
    const trail: TrailPoint[] = [];
    let scale = 1;
    let raf = 0;
    let last = performance.now();
    let acc = 0;
    let hud = 0;
    let finished = false;

    const resize = () => {
      const dpr = window.devicePixelRatio || 1;
      // La patinoire tient dans la largeur et dans la hauteur disponibles.
      scale = Math.min(wrap.clientWidth / RINK.W, wrap.clientHeight / RINK.L);
      canvas.style.width = `${RINK.W * scale}px`;
      canvas.style.height = `${RINK.L * scale}px`;
      canvas.width = Math.round(RINK.W * scale * dpr);
      canvas.height = Math.round(RINK.L * scale * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(wrap);

    const frame = (now: number) => {
      const elapsed = Math.min(0.1, (now - last) / 1000);
      last = now;
      if (!pausedRef.current) {
        acc += elapsed * speedRef.current;
        while (acc >= 1 / 60) {
          step(m, 1 / 60);
          acc -= 1 / 60;
          if (m.phase === 'play') {
            trail.push({ x: m.puck.x, y: m.puck.y });
            if (trail.length > 14) trail.shift();
          } else {
            trail.length = 0;
          }
        }
      }
      drawRink(ctx, m, scale, trail);
      hud += elapsed;
      if (hud > 0.1) {
        hud = 0;
        refresh();
      }
      if (m.phase === 'over' && !finished) {
        finished = true;
        window.setTimeout(() => onFinish(m), 1800);
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => {
      cancelAnimationFrame(raf);
      observer.disconnect();
    };
    // Le match est créé une seule fois pour ce composant.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const [us, them] = m.teams;
  const lastEvent = m.events[m.events.length - 1];
  const isGoal = m.phase === 'goal';
  const boostReady = us.boost >= 1 && us.boostActive <= 0;
  const boostFill = us.boostActive > 0 ? us.boostActive / 7 : us.boost;

  const togglePause = () => {
    pausedRef.current = !pausedRef.current;
    setPaused(pausedRef.current);
  };
  const toggleSpeed = () => {
    speedRef.current = speedRef.current === 1 ? 2 : 1;
    setSpeed(speedRef.current);
  };

  return (
    <main className="screen match">
      <header className="match-top">
        <div className="eyebrow">MATCH AMICAL</div>
        <div className="top-actions">
          <button className="btn-icon" onClick={toggleSpeed} aria-label="Changer la vitesse du match">
            ×{speed}
          </button>
          <button className="btn-icon" onClick={togglePause} aria-label={paused ? 'Reprendre le match' : 'Mettre en pause'}>
            {paused ? (
              <svg aria-hidden="true" width="18" height="18" viewBox="0 0 18 18" fill="currentColor">
                <path d="M5 3l10 6-10 6z" />
              </svg>
            ) : (
              <svg aria-hidden="true" width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
                <path d="M6 3v12M12 3v12" />
              </svg>
            )}
          </button>
        </div>
      </header>

      <section className={isGoal ? 'scoreboard goal' : 'scoreboard'}>
        <div className="sb-team">
          <div className="crest" style={{ background: us.team.color }} />
          <div className="team-name">{us.team.short}</div>
          <div className="muted tiny">{us.shots} tirs</div>
        </div>
        <div className="sb-center">
          <div className="score">
            {us.score}
            <span>:</span>
            {them.score}
          </div>
          <div className="sb-clock">
            <span className="period">{m.phase === 'over' ? 'FIN' : periodLabel(m.period)}</span>
            <span className="clock">{formatClock(m.clock)}</span>
          </div>
        </div>
        <div className="sb-team right">
          <div className="crest" style={{ background: them.team.color }} />
          <div className="team-name">{them.team.short}</div>
          <div className="muted tiny">{them.shots} tirs</div>
        </div>
      </section>

      <section className="rink-wrap" ref={wrapRef}>
        <canvas ref={canvasRef} role="img" aria-label="Patinoire vue de dessus avec les joueurs et le palet" />
        {lastEvent && (
          <div className={lastEvent.kind === 'goal' ? 'ticker goal' : 'ticker'} aria-live="polite">
            <span className="ticker-time">{formatClock(lastEvent.clock)}</span>
            <span>{lastEvent.text}</span>
          </div>
        )}
        {paused && <div className="overlay">PAUSE</div>}
      </section>

      <section className="controls">
        <div className="lines">
          {[0, 1, 2].map((i) => (
            <button
              key={i}
              className={us.line === i ? 'line-btn active' : 'line-btn'}
              aria-pressed={us.line === i}
              onClick={() => {
                setLine(m, 0, i);
                refresh();
              }}
            >
              <span>LIGNE {i + 1}</span>
              <span className="energy" aria-label={`Énergie ${Math.round(us.energy[i] * 100)} %`}>
                <span
                  style={{
                    width: `${us.energy[i] * 100}%`,
                    background: us.energy[i] > 0.6 ? '#4ADE80' : us.energy[i] > 0.35 ? '#FACC15' : '#F87171',
                  }}
                />
              </span>
            </button>
          ))}
        </div>

        <div className="segmented" role="group" aria-label="Tactique">
          {TACTICS.map((t) => (
            <button
              key={t.id}
              className={us.tactic === t.id ? 'active' : ''}
              aria-pressed={us.tactic === t.id}
              onClick={() => {
                setTactic(m, 0, t.id);
                refresh();
              }}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="actions">
          <button
            className={us.boostActive > 0 ? 'boost on' : 'boost'}
            disabled={!boostReady}
            onClick={() => {
              activateBoost(m, 0);
              refresh();
            }}
          >
            <span className="boost-label">{us.boostActive > 0 ? 'BOOST ACTIF' : 'BOOST'}</span>
            <span className="gauge">
              <span style={{ width: `${boostFill * 100}%` }} />
            </span>
          </button>
          <button
            className="btn-secondary"
            disabled={us.timeoutsLeft <= 0 || us.timeoutQueued}
            onClick={() => {
              requestTimeout(m, 0);
              refresh();
            }}
          >
            {us.timeoutQueued ? 'Temps mort demandé' : us.timeoutsLeft > 0 ? 'Temps mort' : 'Temps mort utilisé'}
          </button>
          <button
            className={us.goaliePulled ? 'btn-secondary warn' : 'btn-secondary'}
            aria-pressed={us.goaliePulled}
            onClick={() => {
              setGoaliePulled(m, 0, !us.goaliePulled);
              refresh();
            }}
          >
            {us.goaliePulled ? 'Remettre le gardien' : 'Sortir le gardien'}
          </button>
        </div>
      </section>
    </main>
  );
}
