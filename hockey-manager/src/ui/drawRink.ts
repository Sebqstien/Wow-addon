import { RINK, type MatchState } from '../engine/match';

const { W, L, GY_TOP, GY_BOT, CX, NET_HALF, CORNER, BLUE_TOP, BLUE_BOT } = RINK;

export interface TrailPoint {
  x: number;
  y: number;
}

/** Dessine la patinoire, les joueurs et le palet. `scale` = pixels par unité de jeu. */
export function drawRink(ctx: CanvasRenderingContext2D, m: MatchState, scale: number, trail: TrailPoint[]) {
  const px = (v: number) => v * scale;
  ctx.clearRect(0, 0, px(W), px(L));

  // Glace.
  ctx.beginPath();
  ctx.roundRect(px(0.5), px(0.5), px(W - 1), px(L - 1), px(CORNER));
  ctx.fillStyle = '#162230';
  ctx.fill();
  ctx.lineWidth = 2;
  ctx.strokeStyle = '#33445A';
  ctx.stroke();
  ctx.save();
  ctx.clip();

  const line = (y: number, color: string, width: number, alpha: number, x0 = 0, x1: number = W) => {
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.beginPath();
    ctx.moveTo(px(x0), px(y));
    ctx.lineTo(px(x1), px(y));
    ctx.stroke();
    ctx.globalAlpha = 1;
  };
  const circle = (x: number, y: number, r: number, color: string, alpha: number) => {
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(px(x), px(y), px(r), 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
  };

  line(L / 2, '#E5484D', 3, 0.75);
  line(BLUE_TOP, '#3B82F6', 3, 0.7);
  line(BLUE_BOT, '#3B82F6', 3, 0.7);
  line(GY_TOP, '#E5484D', 1.5, 0.6, 6, W - 6);
  line(GY_BOT, '#E5484D', 1.5, 0.6, 6, W - 6);
  circle(CX, L / 2, 9, '#3B82F6', 0.6);
  for (const x of [22, 63]) for (const y of [22, 78]) circle(x, y, 7, '#E5484D', 0.5);

  // Zones de but et cages.
  for (const [gy, sign] of [[GY_TOP, 1], [GY_BOT, -1]] as const) {
    ctx.beginPath();
    ctx.arc(px(CX), px(gy), px(5.2), sign === 1 ? 0 : Math.PI, sign === 1 ? Math.PI : Math.PI * 2);
    ctx.closePath();
    ctx.fillStyle = '#1D3A55';
    ctx.fill();
    ctx.strokeStyle = '#3B82F6';
    ctx.lineWidth = 1.5;
    ctx.stroke();
    ctx.strokeStyle = '#DDE4EC';
    ctx.lineWidth = 2;
    ctx.strokeRect(px(CX - NET_HALF), px(sign === 1 ? gy - 2.6 : gy), px(NET_HALF * 2), px(2.6));
  }
  ctx.restore();

  // Traînée du palet.
  if (trail.length > 1) {
    ctx.lineCap = 'round';
    for (let i = 1; i < trail.length; i++) {
      ctx.globalAlpha = (i / trail.length) * 0.5;
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(px(trail[i - 1].x), px(trail[i - 1].y));
      ctx.lineTo(px(trail[i].x), px(trail[i].y));
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  // Joueurs.
  const radius = Math.max(9, px(2.9));
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = `700 ${Math.round(radius * 1.05)}px "Barlow Condensed", sans-serif`;
  for (const s of m.skaters) {
    const ts = m.teams[s.team];
    const x = px(s.x);
    const y = px(s.y);
    if (m.puck.carrier === s || (ts.boostActive > 0 && s.slot < 5)) {
      ctx.beginPath();
      ctx.arc(x, y, radius + 4, 0, Math.PI * 2);
      ctx.strokeStyle = ts.team.color;
      ctx.globalAlpha = 0.6;
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fillStyle = ts.team.color;
    ctx.fill();
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = '#0B0F14';
    ctx.stroke();
    ctx.fillStyle = ts.team.ink;
    ctx.fillText(String(s.player.number), x, y + 1);
  }

  // Palet.
  ctx.beginPath();
  ctx.arc(px(m.puck.x), px(m.puck.y), Math.max(3.5, px(1.1)), 0, Math.PI * 2);
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();
  ctx.lineWidth = 1;
  ctx.strokeStyle = '#0B0F14';
  ctx.stroke();
}
