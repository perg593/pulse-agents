export function createScrollDepthEngine({
  target = null,
  logEvery = 10,
  bus = typeof window !== 'undefined' ? window.__PI_BEHAVIOR_BUS__ : null,
  log = (message) => console.debug(message)
} = {}) {
  let element =
    target ||
    (typeof document !== 'undefined' && document.querySelector('#behavior-stage')) ||
    (typeof document !== 'undefined' ? document.scrollingElement : null);
  const fired = new Set();
  let ticking = false;

  const computePercent = (node) => {
    if (!node) return 0;
    const top = node.scrollTop;
    const denom = Math.max(1, node.scrollHeight - node.clientHeight);
    return Math.min(100, Math.max(0, Math.round((top / denom) * 100)));
  };

  const getPercent = () => computePercent(element);

  const emitDepth = (percent) => {
    if (!bus) return;
    bus.dispatchEvent(new CustomEvent('behavior:scroll-depth', { detail: { percent } }));
  };

  const handleScroll = () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      ticking = false;
      if (!element) return;
      const percent = getPercent();
      const bucket = Math.floor(percent / logEvery) * logEvery;
      if (bucket > 0 && bucket <= 100 && !fired.has(bucket)) {
        fired.add(bucket);
        log(`scroll-depth ${bucket}%`);
        emitDepth(bucket);
      }
    });
  };

  const start = () => {
    if (!element) return;
    element.addEventListener('scroll', handleScroll, { passive: true });
    if (typeof window !== 'undefined') {
      window.addEventListener('resize', handleScroll);
    }
    handleScroll();
  };

  const stop = () => {
    if (!element) return;
    element.removeEventListener('scroll', handleScroll);
    if (typeof window !== 'undefined') {
      window.removeEventListener('resize', handleScroll);
    }
  };

  const retarget = (next) => {
    if (!next || next === element) return;
    stop();
    element = next;
    fired.clear();
    start();
  };

  return { start, stop, retarget, getPercent };
}
