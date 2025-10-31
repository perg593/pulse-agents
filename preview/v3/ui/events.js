import { log } from './log.js';
import { toast } from './toast.js';
import { sinks } from './telemetry.js';
import { publicError } from './logging/sanitize.js';

export function emit(evt) {
  if (!evt || typeof evt !== 'object') return;
  const event = { ...evt };
  event.ts = typeof event.ts === 'number' ? event.ts : Date.now();

  switch (event.type) {
    case 'bridge_state':
      log('bridge', 'event', `Bridge ${event.prev} → ${event.next}`, {
        reason: event.reason,
        data: event.data
      });
      break;
    case 'bridge_event':
      log('bridge', 'event', event.event || 'bridge-event', event.data);
      break;
    case 'init':
      log('ui', 'event', 'Init', event.data);
      break;
    case 'tag_ready':
      log('tag', 'event', event.ready ? 'Tag ready' : 'Tag not found');
      break;
    case 'present':
      log('tag', 'event', `Presented ${event.surveyId}`, { force: !!event.force });
      break;
    case 'trigger':
      log('trigger', 'event', `Trigger ${event.triggerId}`);
      break;
    case 'theme_applied':
      log('theme', 'event', `Applied theme ${event.themeId}`, { origin: event.origin });
      break;
    case 'theme_revoked':
      log('theme', 'event', `Revoked ${event.count} generated assets`);
      break;
    case 'error': {
      const sanitized = publicError(event);
      log('ui', 'error', `${sanitized.code}: ${sanitized.message}`, {
        recoverable: sanitized.recoverable,
        hint: sanitized.hint
      });
      break;
    }
    default:
      break;
  }

  switch (event.type) {
    case 'bridge_state':
      if (event.reason === 'present-start') {
        toast.info?.('Presenting agent…');
      } else if (event.reason === 'present-complete' || event.reason === 'implicit-ack') {
        toast.success?.('Agent presentation acknowledged.');
      } else if (event.reason === 'heartbeat-missed-2') {
        toast.info?.('Player inactive — will retry on next command.');
      } else if (event.next === 'ERROR') {
        toast.error?.('Bridge reported an error.');
      }
      break;
    case 'bridge_event':
      if (event.event === 'player-inactive') {
        toast.info?.('Player inactive — waiting for heartbeat.');
      }
      break;
    case 'tag_ready':
      toast.info(event.ready ? 'Tag ready.' : 'Tag not found — using demo mode.');
      break;
    case 'present':
      toast.success('Agent presented.');
      break;
    case 'theme_applied':
      toast.success('Theme applied.');
      break;
    case 'theme_revoked':
      toast.info('Cleaned up generated assets.');
      break;
    case 'error': {
      const sanitized = publicError(event);
      toast.error(sanitized.message || 'Something went wrong.');
      break;
    }
    default:
      break;
  }

  sinks.forEach((sink) => {
    try {
      sink(event);
    } catch {
      // ignore sink errors
    }
  });
}
