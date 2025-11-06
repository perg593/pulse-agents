/* player-skeleton.ts — optional helper for the Player iframe (protocol v1)
   This is NOT required if you already have a Player; it shows the handshake shape.

   Usage:
     const player = new PlayerSkeleton();
     player.mount(); // sends 'hello' and waits for 'init', then posts 'ready'
     player.on('present', ({ surveyId, force }) => { /* call tag present */ });
     player.on('applyTheme', ({ href, css, tokens }) => { /* apply theme */ });
     player.on('trigger', ({ command, args }) => { /* pi('command', ...) */ });
*/

/* eslint-disable @typescript-eslint/no-explicit-any */
type MessageType =
  | 'hello' | 'init' | 'ready'
  | 'present' | 'dismiss' | 'applyTheme' | 'trigger' | 'setPlacement' | 'setTokens'
  | 'status' | 'error' | 'ping' | 'pong';

type Envelope<T=any> = { v:1; id:string; type:MessageType; payload?:T; origin?:'bridge'|'player' };

type Placement = 'BR'|'BL'|'TR'|'TL';

export class PlayerSkeleton {
  private bridgeOrigin = '*';               // Will be locked after first message
  private listeners = new Map<string, Set<(p:any, id:string)=>void>>();
  private placement: Placement = 'BR';
  private density: -1|0|1 = 0;
  private tokens: { brand?: string; radius?: number; density?: -1|0|1 } = {};

  constructor(private debug=false) {}

  mount() {
    window.addEventListener('message', this.onMessage, false);
    this.post({ type:'hello', payload:{ playerVersion:'1.0.0', supports:['applyTheme','trigger'] }});
  }

  on(event: 'present'|'dismiss'|'applyTheme'|'trigger'|'setPlacement'|'setTokens', cb:(p:any,id:string)=>void) {
    if (!this.listeners.has(event)) this.listeners.set(event, new Set());
    this.listeners.get(event)!.add(cb);
  }

  private emit(event: string, payload: any, id: string) {
    this.listeners.get(event)?.forEach(fn => { try { fn(payload, id); } catch {} });
  }

  private onMessage = (ev: MessageEvent<any>) => {
    const m = ev.data as Envelope<any>;
    if (!m || m.v !== 1) return;

    if (this.bridgeOrigin === '*') this.bridgeOrigin = ev.origin; // lock
    if (ev.origin !== this.bridgeOrigin) return;

    if (this.debug) console.debug('[Player <-]', m);

    switch (m.type) {
      case 'init': {
        const { placement, density, tokens } = m.payload || {};
        if (placement) this.placement = placement;
        if (typeof density === 'number') this.density = density;
        if (tokens) this.tokens = tokens;
        this.ack(m.id, { ok:true });
        this.post({ type:'ready', id:m.id }); // ack init with ready
        break;
      }
      case 'ping': this.ack(m.id, { type: 'pong' }); break;
      case 'present':
      case 'dismiss':
      case 'applyTheme':
      case 'trigger':
      case 'setPlacement':
      case 'setTokens':
        this.emit(m.type, m.payload, m.id);
        // The handler should call ack()/nack() when finished
        break;
      default:
        this.nack(m.id, { code:'unknown_cmd' });
    }
  };

  /** Call to acknowledge a command. */
  ack(id: string, payload: any = { ok:true }) {
    this.post({ type:'status', id, payload });
  }
  /** Call to reject a command. */
  nack(id: string, payload: any) {
    this.post({ type:'error', id, payload });
  }

  private post(msg: Partial<Envelope<any>>) {
    const out: Envelope = { v:1, id: msg.id || Math.random().toString(36).slice(2,8), type: msg.type!, payload: msg.payload, origin:'player' };
    if (this.debug) console.debug('[Player ->]', out);
    window.parent.postMessage(out, this.bridgeOrigin);
  }
}
