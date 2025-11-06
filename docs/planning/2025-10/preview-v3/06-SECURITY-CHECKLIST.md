# Security Checklist — Bridge/Player

- [ ] **postMessage targetOrigin** is the exact origin derived from iframe `src` (never `"*"`).  
- [ ] **event.origin** validated for every incoming message on both Bridge and Player.  
- [ ] Player locks **bridgeOrigin** on first message and uses it for all replies.  
- [ ] Player iframe has minimal **sandbox** rights (`allow-scripts allow-same-origin`; add others only if needed).  
- [ ] No dynamic `eval` on received payloads; CSS applied via `<link>` or inert `<style>`.  
- [ ] Content Security Policy set in `_headers` (Pages): `frame-ancestors 'none'; default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'`. Tune as needed for Tag.  
- [ ] Logs redact PII and do not include full CSS or raw HTML payloads.  
- [ ] Heartbeat timeouts do not leak internal stack traces to the UI (friendly messages only).  
