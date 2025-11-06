function parseWhen(when) {
  const match = /^scroll\s*(>=)\s*(\d{1,3})$/.exec(when || '');
  if (!match) return null;
  const value = Math.max(0, Math.min(100, parseInt(match[2], 10)));
  return { op: match[1], value };
}

export function attachResponses({ presenter, rules, bus = typeof window !== 'undefined' ? window.__PI_BEHAVIOR_BUS__ : null, getPercent = () => 0 } = {}) {
  if (!bus) return () => {};
  const fired = new Set();

  const evaluate = (reason = 'event', percent = 0) => {
    const list = (typeof rules === 'function' ? rules() : []) || [];
    for (const rule of list) {
      const key = `${rule.when}|${rule.do}|${rule.arg}`;
      if (fired.has(key)) continue;

      const condition = parseWhen(rule.when);
      if (!condition) continue;

      if (condition.op === '>=' && percent >= condition.value && rule.do === 'present' && rule.arg) {
        const meta = { when: rule.when, percent, reason, allowDuplicate: true };
        const runner =
          presenter && typeof presenter.presentAuto === 'function'
            ? () => presenter.presentAuto(rule.arg, meta)
            : () => presenter.present(rule.arg, meta);
        runner()
          .then(() => fired.add(key))
          .catch(() => {});
      }
    }
  };

  const handleCatalog = () => {
    fired.clear();
    const current = typeof getPercent === 'function' ? getPercent() : 0;
    evaluate('catalog-loaded', current);
  };

  const handleScroll = (event) => {
    const percent = event.detail?.percent ?? 0;
    evaluate('scroll', percent);
  };

  bus.addEventListener('catalog:loaded', handleCatalog);
  bus.addEventListener('behavior:scroll-depth', handleScroll);

  return () => {
    bus.removeEventListener('catalog:loaded', handleCatalog);
    bus.removeEventListener('behavior:scroll-depth', handleScroll);
  };
}
