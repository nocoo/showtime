import React from 'react';
import {createRoot} from 'react-dom/client';
import {flushSync} from 'react-dom';

const root = createRoot(document.getElementById('root'));
const clamp = value => Math.max(0, Math.min(1, value));

function Like({frame, fps, width, height, duration, props}) {
  if (props.visible === false) return null;
  const time = frame / fps;
  const spring = 1 - Math.exp(-10 * time) * Math.cos(18 * time);
  const opacity = clamp(time / 0.15) * (duration == null ? 1 : clamp((duration - time) / 0.35));
  const burst = clamp(time / 1.1);
  const color = props.color ?? '#ED4E80';
  return <div style={{position: 'absolute', left: props.x ?? width * 0.8, top: props.y ?? height * 0.7,
    transform: `translate(-50%, -50%) translateY(${(1 - spring) * 35}px) scale(${0.8 + spring * 0.2})`, opacity}}>
    {Array.from({length: 8}, (_, i) => {
      const angle = i * Math.PI / 4;
      const radius = 65 + burst * 110;
      return <span key={i} style={{position: 'absolute', left: '50%', top: '50%', width: 9, height: 9,
        borderRadius: '50%', background: color, opacity: (1 - burst) ** 2,
        transform: `translate(${Math.cos(angle) * radius}px, ${Math.sin(angle) * radius}px) scale(${1 - burst / 2})`}}/>;
    })}
    <div style={{display: 'flex', alignItems: 'center', gap: 18, padding: '24px 30px', borderRadius: 28,
      background: 'rgba(255,255,255,.96)', boxShadow: '0 16px 60px rgba(28,35,45,.18)',
      border: '1px solid rgba(255,255,255,.9)', whiteSpace: 'nowrap'}}>
      <svg width="62" height="62" viewBox="0 0 24 24" style={{color, transform: `rotate(${(1 - spring) * -25}deg)`}}>
        <path fill="currentColor" d="M3 10h4v11H3a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1Zm6 0 4-8c3 0 3 3 2 6h5a2 2 0 0 1 2 2.5l-2 8a3 3 0 0 1-3 2.5H9Z"/>
      </svg>
      <div>
        <div style={{fontSize: 29, fontWeight: 750, letterSpacing: '-.8px', color: '#242A35'}}>{props.label ?? 'Love this!'}</div>
        <div style={{fontSize: 17, marginTop: 5, color: '#737B8A'}}>{props.count ?? 128} likes</div>
      </div>
    </div>
  </div>;
}

// Complete the React DOM commit before Showtime snapshots this exact frame.
window.showtimeOverlay = context => flushSync(() => root.render(<Like {...context}/>));
