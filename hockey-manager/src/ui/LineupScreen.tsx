import { useState } from 'react';
import type { Tactic } from '../engine/match';
import {
  SLOT_LABELS,
  autoLineup,
  canSwap,
  lineChemistry,
  overall,
  playerAt,
  slotRole,
  swapPlayers,
  type Player,
  type PlayerRef,
  type Team,
} from '../engine/team';

const TACTICS: { id: Tactic; label: string; hint: string }[] = [
  { id: 'repli', label: 'Repli', hint: 'Bloc bas, moins de fatigue, moins de récupérations.' },
  { id: 'equilibre', label: 'Équilibré', hint: 'Aucun bonus ni malus.' },
  { id: 'pressing', label: 'Pressing', hint: 'Deux joueurs chassent le palet, mais la ligne fatigue vite.' },
];

const ATTRIBUTES: { key: 'shooting' | 'skating' | 'passing' | 'physical' | 'defense' | 'mental'; label: string }[] = [
  { key: 'shooting', label: 'Tir' },
  { key: 'skating', label: 'Patinage' },
  { key: 'passing', label: 'Passe' },
  { key: 'physical', label: 'Physique' },
  { key: 'defense', label: 'Défense' },
  { key: 'mental', label: 'Mental' },
];

const sameRef = (a: PlayerRef | null, b: PlayerRef) => a !== null && JSON.stringify(a) === JSON.stringify(b);
/** Poste occupé par une place : celui de la ligne, ou le poste naturel pour un remplaçant. */
const slotOf = (ref: PlayerRef, p: Player) =>
  ref.zone === 'line' ? ref.slot : ref.zone === 'bench' ? (p.role === 'F' ? 1 : 3) : 5;

interface Props {
  team: Team;
  tactic: Tactic;
  onChange: (team: Team) => void;
  onTactic: (tactic: Tactic) => void;
  onBack: () => void;
}

export function LineupScreen({ team, tactic, onChange, onTactic, onBack }: Props) {
  const [line, setLine] = useState(0);
  const [selected, setSelected] = useState<PlayerRef | null>(null);

  const chemistry = lineChemistry(team.lines[line]);
  const selectedPlayer = selected ? playerAt(team, selected) : null;
  const chemColor = chemistry.value >= 0.7 ? '#4ADE80' : chemistry.value >= 0.45 ? '#FACC15' : '#F87171';

  const tap = (ref: PlayerRef) => {
    if (!selected) return setSelected(ref);
    if (sameRef(selected, ref)) return setSelected(null);
    if (!canSwap(selected, ref)) return setSelected(ref);
    onChange(swapPlayers(team, selected, ref));
    setSelected(null);
  };

  /** Variation de niveau si le joueur sélectionné prenait cette place, et inversement. */
  const delta = (ref: PlayerRef): number | null => {
    if (!selected || !selectedPlayer || sameRef(selected, ref) || !canSwap(selected, ref)) return null;
    if (selected.zone !== 'line' && selected.zone !== 'goalie') return null;
    const slot = slotOf(selected, selectedPlayer);
    return overall(playerAt(team, ref), slot) - overall(selectedPlayer, slot);
  };

  const card = (ref: PlayerRef, label: string) => {
    const p = playerAt(team, ref);
    const slot = slotOf(ref, p);
    const misplaced = ref.zone === 'line' && p.role !== slotRole(ref.slot);
    const isSelected = sameRef(selected, ref);
    return (
      <button
        key={label}
        className={`pcard${isSelected ? ' selected' : ''}${misplaced ? ' misplaced' : ''}`}
        aria-pressed={isSelected}
        onClick={() => tap(ref)}
      >
        <span className="pcard-top">
          <span className="pcard-pos">{label}</span>
          <span className="pcard-ovr">{overall(p, slot)}</span>
        </span>
        <span className="pcard-name">
          {p.firstName[0]}. {p.lastName}
        </span>
        <span className="pcard-trait">{misplaced ? 'Hors poste' : p.trait}</span>
      </button>
    );
  };

  const benchRow = (ref: PlayerRef, p: Player, role: string) => {
    const d = delta(ref);
    return (
      <button
        key={p.id}
        className={sameRef(selected, ref) ? 'bench-row selected' : 'bench-row'}
        aria-pressed={sameRef(selected, ref)}
        onClick={() => tap(ref)}
      >
        <span className="rating">{overall(p, slotOf(ref, p))}</span>
        <span className="row-text">
          <strong>
            {p.firstName} {p.lastName}
          </strong>
          <span className="muted small">
            {' '}
            · {role} · {p.age} ans · {p.trait}
          </span>
        </span>
        {d !== null && d !== 0 && <span className={d > 0 ? 'delta up' : 'delta down'}>{d > 0 ? `+${d}` : `−${-d}`}</span>}
      </button>
    );
  };

  return (
    <main className="screen">
      <header className="match-top">
        <button className="btn-icon" onClick={onBack} aria-label="Retour">
          <svg aria-hidden="true" width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M11 3L5 9l6 6" />
          </svg>
        </button>
        <h1 className="title lineup-title">LIGNES</h1>
        <button
          className="btn-chip"
          onClick={() => {
            onChange(autoLineup(team));
            setSelected(null);
          }}
        >
          Auto
        </button>
      </header>

      <div className="segmented" role="group" aria-label="Ligne affichée">
        {[0, 1, 2].map((i) => (
          <button key={i} className={line === i ? 'active accent' : ''} aria-pressed={line === i} onClick={() => setLine(i)}>
            LIGNE {i + 1}
          </button>
        ))}
      </div>

      <section className="formation">
        <div className="formation-row three">
          {[0, 1, 2].map((slot) => card({ zone: 'line', line, slot }, SLOT_LABELS[slot]))}
        </div>
        <div className="formation-row two">
          {[3, 4].map((slot) => card({ zone: 'line', line, slot }, SLOT_LABELS[slot]))}
        </div>
        <div className="formation-row one">{card({ zone: 'goalie' }, 'G')}</div>
      </section>

      <section className="card chem">
        <div className="chem-head">
          <span className="chem-label">Entente de la ligne {line + 1}</span>
          <span className="chem-value" style={{ color: chemColor }}>
            {Math.round(chemistry.value * 100)} %
          </span>
        </div>
        <div className="bar">
          <span style={{ width: `${chemistry.value * 100}%`, background: chemColor }} />
        </div>
        {chemistry.notes.map((note) => (
          <div className="muted small" key={note}>
            {note}
          </div>
        ))}
      </section>

      {selectedPlayer ? (
        <section className="card detail">
          <div className="chem-head">
            <span className="chem-label">
              #{selectedPlayer.number} {selectedPlayer.firstName} {selectedPlayer.lastName}
            </span>
            <span className="muted small">
              {selectedPlayer.age} ans · {selectedPlayer.trait}
            </span>
          </div>
          {selectedPlayer.role === 'G' ? (
            <div className="muted small">Niveau gardien : {selectedPlayer.goalie}</div>
          ) : (
            <div className="attrs">
              {ATTRIBUTES.map((a) => (
                <div className="attr" key={a.key}>
                  <span className="muted tiny">{a.label}</span>
                  <span className="attr-value">{selectedPlayer[a.key]}</span>
                </div>
              ))}
            </div>
          )}
          <div className="muted small">Touchez un autre joueur pour échanger leurs places.</div>
        </section>
      ) : (
        <p className="muted small help">Touchez un joueur, puis un autre, pour échanger leurs places.</p>
      )}

      <section>
        <div className="eyebrow section-title">REMPLAÇANTS</div>
        <div className="bench">
          {team.bench.map((p, index) => benchRow({ zone: 'bench', index }, p, p.role === 'F' ? 'Attaquant' : 'Défenseur'))}
          {benchRow({ zone: 'backup' }, team.backupGoalie, 'Gardien')}
        </div>
      </section>

      <section>
        <div className="eyebrow section-title">TACTIQUE DE DÉPART</div>
        <div className="segmented" role="group" aria-label="Tactique de départ">
          {TACTICS.map((t) => (
            <button key={t.id} className={tactic === t.id ? 'active' : ''} aria-pressed={tactic === t.id} onClick={() => onTactic(t.id)}>
              {t.label}
            </button>
          ))}
        </div>
        <p className="muted small help tactic-hint">{TACTICS.find((t) => t.id === tactic)!.hint}</p>
      </section>
    </main>
  );
}
